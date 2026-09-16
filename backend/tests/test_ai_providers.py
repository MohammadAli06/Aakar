"""Provider migration contracts; synthetic images and HTTP mocks only."""
import os
os.environ['DEBUG'] = 'false'

import base64
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, patch

import httpx
from PIL import Image
from pydantic import ValidationError

from app.core.config import Settings, settings, free_tier
from app.services import ai_provider, cloudinary_service, studio_service, vision_pricing_service, translation_qa_service
from app.services.image_store import store_photo


def photo(alpha=False):
    im = Image.new('RGBA' if alpha else 'RGB', (32, 32), (120, 80, 30, 0) if alpha else 'brown')
    im.putpixel((16, 16), (120, 80, 30, 255) if alpha else (120, 80, 30))
    out = io.BytesIO()
    im.save(out, 'PNG')
    return out.getvalue()


def completion(value):
    return {'choices': [{'finish_reason': 'stop', 'message': {'content': json.dumps(value)}}]}


class ProviderTests(unittest.IsolatedAsyncioTestCase):
    def test_upstream_limit_does_not_claim_daily_quota_exhaustion(self):
        response = httpx.Response(429, json={'error': {'message': 'SECRET_PROVIDER_DETAIL',
            'metadata': {'provider_name': 'Google AI Studio', 'raw': 'SECRET'}}})
        message = ai_provider.rate_limit_message(response, 'openrouter')
        self.assertIn('upstream provider', message)
        self.assertNotIn('daily', message)
        self.assertNotIn('SECRET', message)

    def test_daily_limit_and_retry_hint_are_distinct(self):
        response = httpx.Response(429, headers={'Retry-After': '60'},
            json={'error': {'message': 'Free requests per day exceeded'}})
        message = ai_provider.rate_limit_message(response, 'openrouter')
        self.assertIn('daily free-model', message)
        self.assertIn('60 seconds', message)

    def test_malformed_limit_payload_still_reports_safe_error(self):
        for payload in [None, [], {'error': None}]:
            response = httpx.Response(429, json=payload)
            self.assertIn('request rate limit', ai_provider.rate_limit_message(response, 'openrouter'))

    def setUp(self):
        for name, value in [('AI_PROVIDER_PROFILE', 'cloudinary_openrouter'),
                            ('OPENROUTER_VISION_MODEL', 'google/gemma-4-26b-a4b-it:free'),
                            ('OPENROUTER_API_KEY', 'router-test'),
                            ('OPENAI_API_KEY', 'paid-must-not-be-used')]:
            item = patch.object(settings, name, value)
            item.start()
            self.addCleanup(item.stop)

    def test_profile_validation_and_groq_independence(self):
        with self.assertRaises(ValidationError):
            Settings(_env_file=None, AI_PROVIDER_PROFILE='typo')
        before = [free_tier(t) for t in ('extraction', 'generation', 'negotiation')]
        with patch.object(settings, 'AI_PROVIDER_PROFILE', 'openai'):
            self.assertEqual(before, [free_tier(t) for t in ('extraction', 'generation', 'negotiation')])

    async def test_catalog_uses_requested_gemma_with_image_and_local_validation(self):
        requests = []
        def handler(request):
            requests.append(request)
            return httpx.Response(200, json=completion({'suggestions': [
                {'field': 'title', 'value': 'Woven basket', 'confidence': 'high',
                 'source': 'image', 'evidence': 'Woven container'},
                {'field': 'price', 'value': '900', 'confidence': 'high',
                 'source': 'image', 'evidence': 'Guess'}], 'questions': []}))
        real = httpx.AsyncClient
        with patch.object(ai_provider.httpx, 'AsyncClient', side_effect=lambda **kw:
                real(transport=httpx.MockTransport(handler), **kw)):
            result = await studio_service.analyze(photo())
        self.assertEqual(result['fields'], {'title': 'Woven basket'})
        request, = requests
        self.assertEqual(request.url.host, 'openrouter.ai')
        self.assertEqual(request.headers['Authorization'], 'Bearer router-test')
        body = json.loads(request.content)
        self.assertEqual(body['model'], 'google/gemma-4-26b-a4b-it:free')
        self.assertEqual(body['response_format'], {'type': 'json_object'})
        self.assertTrue(body['messages'][1]['content'][1]['image_url']['url'].startswith('data:image/jpeg;base64,'))

    async def test_errors_and_truncated_responses_never_fall_back(self):
        for status, payload in [(429, {}), (402, {}), (200, {'choices': []}),
                                (200, {'choices': [{'finish_reason': 'length', 'message': {'content': '{}'}}]})]:
            seen = []
            def handler(request):
                seen.append(request.url.host)
                return httpx.Response(status, json=payload)
            real = httpx.AsyncClient
            with patch.object(ai_provider.httpx, 'AsyncClient', side_effect=lambda **kw:
                    real(transport=httpx.MockTransport(handler), **kw)):
                with self.assertRaises(ai_provider.ProviderError):
                    await ai_provider.chat([{'role': 'user', 'content': 'test'}])
            self.assertEqual(seen, ['openrouter.ai'])

    async def test_missing_router_key_does_not_use_openai(self):
        with patch.object(settings, 'OPENROUTER_API_KEY', None), patch.object(ai_provider.httpx, 'AsyncClient') as client:
            with self.assertRaises(ai_provider.ProviderError):
                await ai_provider.chat([])
            client.assert_not_called()

    async def test_pricing_routes_both_profiles_and_reports_model(self):
        for profile, host, model in [('openai', 'api.openai.com', settings.OPENAI_VISION_MODEL),
                                      ('cloudinary_openrouter', 'openrouter.ai', settings.OPENROUTER_VISION_MODEL)]:
            requests = []
            def handler(request):
                requests.append(request)
                return httpx.Response(200, json=completion({'complexity_score': .7,
                    'detected_category': 'weaving', 'material_tier': 'medium',
                    'reasoning_en': 'Detailed weave', 'reasoning_hi': 'बारीक बुनाई'}))
            real = httpx.AsyncClient
            with patch.object(settings, 'AI_PROVIDER_PROFILE', profile), patch.object(
                    ai_provider.httpx, 'AsyncClient', side_effect=lambda **kw:
                    real(transport=httpx.MockTransport(handler), **kw)):
                result = await vision_pricing_service.analyze_product_image(None, 'Basket')
            self.assertFalse(result['is_fallback'])
            self.assertEqual(result['model_used'], model)
            self.assertEqual(requests[0].url.host, host)


def native_completion(value):
    text = value if isinstance(value, str) else json.dumps(value)
    return {'candidates': [{'finishReason': 'STOP', 'content': {'parts': [{'text': text}]}}]}


class GeminiProfileTests(unittest.IsolatedAsyncioTestCase):
    async def test_upstream_failures_are_distinct_and_do_not_leak_bodies(self):
        for status, detail in [(400, 'format'), (401, 'credentials'),
                               (403, 'permission'), (404, 'model')]:
            real = httpx.AsyncClient
            with patch.object(ai_provider.httpx, 'AsyncClient', side_effect=lambda **kw:
                    real(transport=httpx.MockTransport(lambda request:
                        httpx.Response(status, json=[{'error': {'message': 'SECRET'}}])), **kw)):
                with self.assertRaises(studio_service.StudioError) as failure:
                    await studio_service.analyze(photo())
            self.assertIn(f'HTTP {status}', str(failure.exception))
            self.assertIn(detail, str(failure.exception))
            self.assertNotIn('SECRET', str(failure.exception))

    def test_native_parser_rejects_incomplete_and_blocked_responses(self):
        for payload in [
            {'promptFeedback': {'blockReason': 'SAFETY'}},
            {'candidates': [{'finishReason': 'MAX_TOKENS'}]},
        ]:
            with self.assertRaises(ai_provider.ProviderError):
                ai_provider.gemini_text(payload)
        self.assertEqual(ai_provider.gemini_text({'candidates': [{
            'finishReason': 'STOP', 'content': {'parts': [
                {'thought': True, 'text': 'private reasoning'},
                {'text': '{"ok":'}, {'text': 'true}'}]}}]}), '{"ok":true}')

    async def test_transient_503_retries_same_model_then_succeeds(self):
        requests = []
        def handler(request):
            requests.append(request)
            if len(requests) < 3:
                return httpx.Response(503, json=[{'error': {'message': 'Unavailable'}}])
            return httpx.Response(200, json=native_completion({'ok': True}))
        real = httpx.AsyncClient
        with patch.object(ai_provider.httpx, 'AsyncClient', side_effect=lambda **kw:
                real(transport=httpx.MockTransport(handler), **kw)), patch.object(
                ai_provider.asyncio, 'sleep', AsyncMock()) as sleep:
            result = await ai_provider.chat([{'role': 'user', 'content': 'test'}])
        self.assertEqual(json.loads(result), {'ok': True})
        self.assertEqual(len(requests), 3)
        self.assertEqual(sleep.await_count, 2)
        self.assertTrue(all(r.url.path.endswith('/models/gemini-3.8-flash:generateContent') for r in requests))

    async def test_persistent_503_is_not_changed_to_502(self):
        requests = []
        def handler(request):
            requests.append(request)
            return httpx.Response(503, json=[{'error': {'message': 'SECRET'}}])
        real = httpx.AsyncClient
        with patch.object(ai_provider.httpx, 'AsyncClient', side_effect=lambda **kw:
                real(transport=httpx.MockTransport(handler), **kw)), patch.object(
                ai_provider.asyncio, 'sleep', AsyncMock()):
            with self.assertRaises(studio_service.StudioError) as failure:
                await studio_service.analyze(photo())
        self.assertEqual(failure.exception.status, 503)
        self.assertIn('temporarily unavailable', str(failure.exception))
        self.assertNotIn('SECRET', str(failure.exception))
        self.assertEqual(len(requests), 3)

    async def test_long_retry_hint_does_not_trigger_early_retry(self):
        real = httpx.AsyncClient
        with patch.object(ai_provider.httpx, 'AsyncClient', side_effect=lambda **kw:
                real(transport=httpx.MockTransport(lambda request: httpx.Response(
                    503, headers={'Retry-After': '60'})), **kw)), patch.object(
                ai_provider.asyncio, 'sleep', AsyncMock()) as sleep:
            with self.assertRaises(ai_provider.ProviderError) as failure:
                await ai_provider.chat([])
        self.assertEqual(failure.exception.status, 503)
        self.assertIn('60 seconds', str(failure.exception))
        sleep.assert_not_called()

    def setUp(self):
        for name, value in [('AI_PROVIDER_PROFILE', 'cloudinary_gemini'),
                            ('GEMINI_API_KEY', 'gemini-test'),
                            ('GEMINI_MODEL', 'gemini-3.8-flash'),
                            ('OPENAI_API_KEY', 'must-not-use'),
                            ('OPENROUTER_API_KEY', 'must-not-use')]:
            item = patch.object(settings, name, value)
            item.start()
            self.addCleanup(item.stop)

    async def test_all_three_tasks_go_directly_to_google(self):
        seen = []
        def handler(request):
            body = json.loads(request.content)
            seen.append((request, body))
            prompt = body['systemInstruction']['parts'][0]['text']
            if 'factual catalog suggestions' in prompt:
                value = {'suggestions': [{'field': 'title', 'value': 'Woven basket',
                    'confidence': 'high', 'source': 'image', 'evidence': 'Woven container'}], 'questions': []}
            elif 'expert appraiser' in prompt:
                value = {'complexity_score': .6, 'detected_category': 'weaving',
                    'material_tier': 'medium', 'reasoning_en': 'Woven detail', 'reasoning_hi': 'बुनाई'}
            elif 'SAME product information' in prompt:
                value = {'score': .9}
            else:
                return httpx.Response(200, json=native_completion('Woven basket.'))
            return httpx.Response(200, json=native_completion(value))
        real = httpx.AsyncClient
        with patch.object(ai_provider.httpx, 'AsyncClient', side_effect=lambda **kw:
                real(transport=httpx.MockTransport(handler), **kw)):
            catalog = await studio_service.analyze(photo())
            pricing = await vision_pricing_service.analyze_product_image(None, 'Basket')
            translation = await translation_qa_service.check_round_trip('Woven basket.', 'बुनी टोकरी')
        self.assertEqual(catalog['fields']['title'], 'Woven basket')
        self.assertEqual(pricing['model_used'], 'gemini-3.8-flash')
        self.assertEqual(translation['method'], 'gemini')
        self.assertFalse(translation['is_fallback'])
        self.assertEqual(len(seen), 4)
        for request, body in seen:
            self.assertEqual(str(request.url), 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent')
            self.assertEqual(request.headers['x-goog-api-key'], 'gemini-test')
            self.assertNotIn('Authorization', request.headers)
            self.assertNotIn('gemini-test', str(request.url))
            self.assertGreaterEqual(body['generationConfig']['maxOutputTokens'], 8192)
            self.assertNotIn('provider', body)
        image = seen[0][1]['contents'][0]['parts'][1]['inlineData']
        self.assertEqual(image['mimeType'], 'image/jpeg')
        with Image.open(io.BytesIO(base64.b64decode(image['data'], validate=True))) as decoded:
            self.assertEqual(decoded.format, 'JPEG')
        self.assertEqual(seen[0][1]['generationConfig']['responseMimeType'], 'application/json')

    async def test_removal_stays_cloudinary(self):
        with patch.object(cloudinary_service, 'remove_background', AsyncMock(return_value=photo(True))) as remove, patch.object(
                studio_service, 'edit_photo', AsyncMock()) as paid:
            result = await studio_service.prepare(photo(), 'plainBackground')
        self.assertEqual(result['provider'], 'cloudinary')
        self.assertEqual(result['mime_type'], 'image/png')
        remove.assert_awaited_once()
        paid.assert_not_called()

    async def test_missing_key_and_rate_limit_do_not_switch_providers(self):
        with patch.object(settings, 'GEMINI_API_KEY', None), patch.object(ai_provider.httpx, 'AsyncClient') as client:
            with self.assertRaisesRegex(ai_provider.ProviderError, 'GEMINI_API_KEY'):
                await ai_provider.chat([])
            client.assert_not_called()
        requests = []
        def handler(request):
            requests.append(request)
            return httpx.Response(429, json={'error': {'message': 'Rate limited'}})
        real = httpx.AsyncClient
        with patch.object(ai_provider.httpx, 'AsyncClient', side_effect=lambda **kw:
                real(transport=httpx.MockTransport(handler), **kw)):
            with self.assertRaises(ai_provider.ProviderError) as failure:
                await ai_provider.chat([])
        self.assertEqual(failure.exception.status, 429)
        self.assertEqual([r.url.host for r in requests], ['generativelanguage.googleapis.com'])


class CloudinaryTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        for name, value in [('AI_PROVIDER_PROFILE', 'cloudinary_openrouter'),
                            ('CLOUDINARY_URL', 'cloudinary://test-key:test-secret@u59wk44t')]:
            item = patch.object(settings, name, value)
            item.start()
            self.addCleanup(item.stop)

    async def test_signed_upload_then_pending_derived_png(self):
        requests = []
        def handler(request):
            requests.append(request)
            if request.method == 'POST':
                return httpx.Response(200, json={'public_id': 'ignored-provider-url'})
            return httpx.Response(423) if len(requests) == 2 else httpx.Response(200, content=photo(True))
        real = httpx.AsyncClient
        with patch.object(cloudinary_service.httpx, 'AsyncClient', side_effect=lambda **kw:
                real(transport=httpx.MockTransport(handler), **kw)), patch.object(
                cloudinary_service.asyncio, 'sleep', AsyncMock()) as sleep:
            output = await cloudinary_service.remove_background(photo())
        self.assertEqual(output, photo(True))
        self.assertEqual(len(requests), 3)
        self.assertIn(b'name="signature"', requests[0].content)
        self.assertNotIn(b'test-secret', requests[0].content)
        self.assertNotIn(b'e_background_removal', requests[0].content)
        self.assertIn('/e_background_removal/aakar/studio/', requests[1].url.path)
        self.assertEqual(requests[1].url, requests[2].url)
        self.assertNotIn('Authorization', requests[1].headers)
        sleep.assert_awaited_once()

    async def test_modes_preserve_alpha_or_make_white_catalog(self):
        with patch.object(cloudinary_service, 'remove_background', AsyncMock(return_value=photo(True))), patch.object(
                studio_service, 'edit_photo', AsyncMock()) as paid:
            cutout = await studio_service.prepare(photo(), 'plainBackground')
            self.assertEqual(cutout['mime_type'], 'image/png')
            self.assertEqual(cutout['provider'], 'cloudinary')
            self.assertTrue(cutout['review_required'])
            im = Image.open(io.BytesIO(base64.b64decode(cutout['image_base64'])))
            self.assertEqual(im.getpixel((0, 0))[3], 0)
            catalog = await studio_service.prepare(photo(), 'b2bCatalog')
            self.assertEqual(catalog['mime_type'], 'image/jpeg')
            self.assertEqual(catalog['width'], 1200)
            natural = await studio_service.prepare(photo(), 'naturalSetting')
            self.assertEqual(natural['provider'], 'deterministic')
            paid.assert_not_called()

    async def test_failed_transform_no_paid_fallback_or_secret_leak(self):
        for status in [401, 403, 429, 500]:
            real = httpx.AsyncClient
            with patch.object(cloudinary_service.httpx, 'AsyncClient', side_effect=lambda **kw:
                    real(transport=httpx.MockTransport(lambda request:
                        httpx.Response(status, json={'error': 'SECRET'})), **kw)), patch.object(
                    studio_service, 'edit_photo', AsyncMock()) as paid:
                with self.assertRaises(studio_service.StudioError) as failure:
                    await studio_service.prepare(photo(), 'plainBackground')
                self.assertNotIn('SECRET', str(failure.exception))
                paid.assert_not_called()

    async def test_pending_timeout_is_bounded(self):
        real = httpx.AsyncClient
        def handler(request):
            return httpx.Response(200, json={}) if request.method == 'POST' else httpx.Response(423)
        with patch.object(cloudinary_service.httpx, 'AsyncClient', side_effect=lambda **kw:
                real(transport=httpx.MockTransport(handler), **kw)), patch.object(
                cloudinary_service.asyncio, 'sleep', AsyncMock()):
            with self.assertRaises(ai_provider.ProviderError) as failure:
                await cloudinary_service.remove_background(photo())
        self.assertEqual(failure.exception.status, 504)

    def test_missing_credentials_fail_cleanly(self):
        for value in [None, '', 'cloudinary://incomplete', 'not a URL']:
            with patch.object(settings, 'CLOUDINARY_URL', value):
                with self.assertRaises(ai_provider.ProviderError):
                    cloudinary_service.credentials()

    def test_saved_catalog_jpeg_composites_transparency_on_white(self):
        with tempfile.TemporaryDirectory() as folder:
            name = store_photo(photo(True), Path(folder))
            with Image.open(Path(folder) / name) as image:
                self.assertTrue(all(c > 240 for c in image.getpixel((0, 0))))
