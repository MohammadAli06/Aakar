"""Explicit provider selection for catalog, pricing vision and translation QA.

No automatic paid fallback. Groq business-text services are independent.
"""
import asyncio
import base64
import json
import logging
import random
from urllib.parse import quote

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)


class ProviderError(Exception):
    def __init__(self, message, status=502):
        super().__init__(message)
        self.status = status


def selected_provider():
    return {'openai': 'openai', 'cloudinary_openrouter': 'openrouter',
            'cloudinary_gemini': 'gemini'}[settings.AI_PROVIDER_PROFILE]


def background_provider():
    return 'openai' if settings.AI_PROVIDER_PROFILE == 'openai' else 'cloudinary'


def transport(task='vision'):
    if selected_provider() == 'gemini':
        return ('https://generativelanguage.googleapis.com/v1beta',
                settings.GEMINI_API_KEY, settings.GEMINI_MODEL)
    if selected_provider() == 'openrouter':
        return ('https://openrouter.ai/api/v1', settings.OPENROUTER_API_KEY,
                settings.OPENROUTER_VISION_MODEL)
    model = settings.OPENAI_TRANSLATION_MODEL if task == 'translation' else settings.OPENAI_VISION_MODEL
    return ('https://api.openai.com/v1', settings.OPENAI_API_KEY, model)


def parse_json(text):
    text = text.strip()
    if text.startswith('```') and text.endswith('```'):
        text = '\n'.join(text.splitlines()[1:-1])
    return json.loads(text)


def rate_limit_message(response, provider):
    """Classify safe hints without exposing provider bodies or credentials."""
    try:
        error = response.json().get('error', {})
        metadata = error.get('metadata') or {}
        message = str(error.get('message', '')).lower()
        upstream = isinstance(metadata, dict) and bool(metadata.get('provider_name'))
    except (ValueError, AttributeError, TypeError):
        message, upstream = '', False
    if upstream:
        detail = f'{provider}: the selected model\'s upstream provider is rate limited or at capacity. Retry later or choose another model in backend settings.'
    elif any(term in message for term in ('daily', 'per-day', 'per day', 'requests/day')):
        detail = f'{provider}: the daily free-model request limit was reached. Wait for the quota reset or review your provider account limits.'
    else:
        detail = f'{provider}: request rate limit reached. Wait before retrying; this does not by itself mean your daily quota is exhausted.'
    retry = response.headers.get('retry-after', '')
    if retry.isdigit() and 0 < int(retry) <= 86400:
        detail += f' Provider retry hint: {int(retry)} seconds.'
    return detail


def gemini_body(messages, json_mode, max_tokens):
    """Convert our internal messages to native Google text/inline image parts."""
    contents, instructions = [], []
    for message in messages:
        content = message['content']
        parts = []
        for item in ([{'type': 'text', 'text': content}] if isinstance(content, str) else content):
            if item['type'] == 'text':
                parts.append({'text': item['text']})
            elif item['type'] == 'image_url':
                header, encoded = item['image_url']['url'].split(',', 1)
                if header not in ('data:image/jpeg;base64', 'data:image/png;base64', 'data:image/webp;base64'):
                    raise ValueError('Unsupported inline image')
                if not base64.b64decode(encoded, validate=True):
                    raise ValueError('Empty image')
                parts.append({'inlineData': {'mimeType': header[5:].split(';')[0], 'data': encoded}})
            else:
                raise ValueError('Unsupported content')
        if message['role'] == 'system':
            instructions.extend(parts)
        else:
            contents.append({'role': 'model' if message['role'] == 'assistant' else 'user', 'parts': parts})
    config = {'maxOutputTokens': max(max_tokens, 8192)}
    if json_mode:
        config['responseMimeType'] = 'application/json'
    body = {'contents': contents, 'generationConfig': config}
    if instructions:
        body['systemInstruction'] = {'parts': instructions}
    return body


def gemini_text(payload):
    if payload.get('promptFeedback', {}).get('blockReason'):
        raise ProviderError('gemini: the photo request was blocked by the model. Try another photo or enter details manually.')
    candidate = payload['candidates'][0]
    if candidate.get('finishReason') != 'STOP':
        raise ProviderError('gemini: the response was blocked or incomplete. Retry or enter details manually.')
    return ''.join(part.get('text', '') for part in candidate['content']['parts'] if not part.get('thought'))


async def chat(messages, *, task='vision', json_mode=False, max_tokens=4096):
    base, key, model = transport(task)
    provider = selected_provider()
    if not key or not key.strip():
        raise ProviderError(f'{provider} is not configured. Set {provider.upper()}_API_KEY in backend/.env and restart.', 503)
    body = {'model': model, 'messages': messages, 'temperature': 0,
            'max_tokens': max_tokens, 'stream': False}
    if json_mode:
        body['response_format'] = {'type': 'json_object'}
    if provider == 'openrouter':
        body['provider'] = {'require_parameters': True}
    try:
        url = base + '/chat/completions'
        headers = {'Authorization': 'Bearer ' + key.strip()}
        if provider == 'gemini':
            url = base + '/models/' + quote(model.removeprefix('models/'), safe='') + ':generateContent'
            headers = {'x-goog-api-key': key.strip()}
            body = gemini_body(messages, json_mode, max_tokens)
            if model.removeprefix('models/').startswith('gemini-3'):
                body['generationConfig']['thinkingConfig'] = {'thinkingLevel': 'low'}
        async with asyncio.timeout(settings.AI_TIMEOUT_SECONDS):
            async with httpx.AsyncClient(timeout=settings.AI_TIMEOUT_SECONDS) as client:
                for attempt in range(3):
                    response = await client.post(url, headers=headers, json=body)
                    if provider != 'gemini' or response.status_code != 503 or attempt == 2:
                        break
                    retry = response.headers.get('retry-after')
                    # Don't retry before a long or unparseable provider deadline.
                    if retry is not None and (not retry.isdigit() or int(retry) > 10):
                        break
                    delay = max(2 ** attempt, int(retry or 0)) + random.uniform(0, .25)
                    await asyncio.sleep(delay)
        if response.is_error:
            # Never log headers, image bytes, artisan notes, or raw provider bodies.
            logger.warning('AI request failed: provider=%s task=%s upstream_http=%s',
                           provider, task, response.status_code)
        if response.status_code == 503:
            hint = response.headers.get('retry-after', '')
            wait = f' Wait at least {int(hint)} seconds.' if hint.isdigit() and 0 < int(hint) <= 86400 else ''
            raise ProviderError(f'{provider}: the model service is temporarily unavailable. Please retry later.{wait}', 503)
        if response.status_code == 429:
            raise ProviderError(rate_limit_message(response, provider), 429)
        if response.status_code == 402:
            raise ProviderError(f'{provider}: insufficient API credits or a key spending cap was reached. Check account billing and key limits.', 402)
        failures = {
            400: 'rejected the photo/text request format or generation settings',
            401: 'rejected the configured API credentials',
            403: 'denied permission for this request; check API/key restrictions and project access',
            404: 'could not find the configured model on this API endpoint',
        }
        if response.status_code in failures:
            raise ProviderError(f'{provider} upstream HTTP {response.status_code}: {failures[response.status_code]}.', 502)
        response.raise_for_status()
        if provider == 'gemini':
            content = gemini_text(response.json())
        else:
            choice = response.json()['choices'][0]
            if choice.get('finish_reason') != 'stop':
                raise ValueError('Incomplete response')
            content = choice['message']['content']
        if not isinstance(content, str) or not content.strip():
            raise ValueError('Empty response')
        return content
    except (TimeoutError, httpx.TimeoutException):
        raise ProviderError(f'{provider} took too long. Please retry.', 504) from None
    except (httpx.HTTPError, ValueError, KeyError, IndexError, TypeError, AttributeError):
        raise ProviderError(f'{provider} returned no usable result. Please retry or enter details manually.') from None
