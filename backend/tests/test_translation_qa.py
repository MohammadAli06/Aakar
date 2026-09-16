"""Back-translation checks use a mocked OpenAI transport; no live API spend."""
import os
os.environ['DEBUG'] = 'false'

import json
from types import SimpleNamespace
import unittest
from unittest.mock import AsyncMock, patch

from fastapi import FastAPI, Header, HTTPException
from fastapi.testclient import TestClient
import httpx

from app.core.auth_deps import get_current_user
from app.core.config import settings
from app.services import ai_provider
from app.models.models import AccountRole
from app.routers import studio
from app.services import translation_qa_service as service


def chat_response(text):
    return {'choices': [{'finish_reason': 'stop', 'message': {'content': text}}]}


class TranslationQaServiceTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        selected = patch.object(settings, 'AI_PROVIDER_PROFILE', 'cloudinary_openrouter')
        selected.start()
        self.addCleanup(selected.stop)

    async def run_check(self, handler, english='Handwoven bamboo basket.',
                        translated='हाथ से बुनी बांस की टोकरी।', **kwargs):
        real_client = httpx.AsyncClient
        requests = []

        def recording(request):
            requests.append(json.loads(request.content))
            return handler(request)

        with patch.object(settings, 'OPENROUTER_API_KEY', 'test-only-key'), patch.object(
                ai_provider.httpx, 'AsyncClient',
                side_effect=lambda **kw: real_client(
                    transport=httpx.MockTransport(recording), **kw)):
            result = await service.check_round_trip(english, translated, **kwargs)
        return result, requests

    async def test_translation_then_comparison_contract(self):
        def handler(request):
            if 'response_format' in json.loads(request.content):
                return httpx.Response(200, json=chat_response('{"score": 0.9}'))
            return httpx.Response(200, json=chat_response('Handwoven bamboo basket.'))

        result, requests = await self.run_check(handler)
        self.assertFalse(result['is_fallback'])
        self.assertEqual(result['method'], 'openrouter')
        self.assertEqual(result['confidence_label'], 'checked')
        self.assertEqual(result['roundtrip_score'], 0.9)
        self.assertEqual(result['roundtrip'], 'Handwoven bamboo basket.')
        self.assertEqual(result['source_lang'], 'hi')
        self.assertEqual(result['pivot_lang'], 'en')

        translation, judge = requests
        self.assertEqual(translation['model'], settings.OPENROUTER_VISION_MODEL)
        self.assertIn('हाथ से बुनी', json.dumps(translation, ensure_ascii=False))
        self.assertEqual(translation['temperature'], 0.0)
        self.assertNotIn('response_format', translation)
        self.assertEqual(judge['response_format'], {'type': 'json_object'})
        payload = json.dumps(judge, ensure_ascii=False)
        self.assertIn('Handwoven bamboo basket.', payload)
        self.assertIn('IGNORE', payload)

    async def test_credentials_travel_in_the_header_only(self):
        seen = []

        def handler(request):
            seen.append((request.headers['Authorization'], str(request.url)))
            if 'response_format' in json.loads(request.content):
                return httpx.Response(200, json=chat_response('{"score": 1.0}'))
            return httpx.Response(200, json=chat_response('Basket.'))

        real_client = httpx.AsyncClient
        with patch.object(settings, 'OPENROUTER_API_KEY', 'test-only-key'), patch.object(
                ai_provider.httpx, 'AsyncClient',
                side_effect=lambda **kw: real_client(
                    transport=httpx.MockTransport(handler), **kw)):
            result = await service.check_round_trip('Basket.', 'टोकरी।')
        self.assertFalse(result['is_fallback'])
        self.assertEqual(len(seen), 2)
        for header, url in seen:
            self.assertEqual(header, 'Bearer test-only-key')
            self.assertNotIn('test-only-key', url)
            self.assertTrue(url.startswith('https://openrouter.ai/api/v1/chat/completions'))

    async def test_openrouter_failure_never_falls_back_to_paid_openai(self):
        seen = []
        real_client = httpx.AsyncClient
        def handler(request):
            seen.append(request.url.host)
            return httpx.Response(500, json={'error': 'SECRET'})
        with patch.object(settings, 'OPENROUTER_API_KEY', 'router-key'), patch.object(
                settings, 'OPENAI_API_KEY', 'paid-key'), patch.object(
                ai_provider.httpx, 'AsyncClient', side_effect=lambda **kw: real_client(
                    transport=httpx.MockTransport(handler), **kw)):
            result = await service.check_round_trip('Basket.', '??????')
        self.assertTrue(result['is_fallback'])
        self.assertEqual(seen, ['openrouter.ai'])

    async def test_openai_profile_uses_openai_only(self):
        seen = []
        real_client = httpx.AsyncClient
        def handler(request):
            seen.append(request.url.host)
            text = '{"score": 0.9}' if 'response_format' in json.loads(request.content) else 'Basket.'
            return httpx.Response(200, json=chat_response(text))
        with patch.object(settings, 'AI_PROVIDER_PROFILE', 'openai'), patch.object(
                settings, 'OPENAI_API_KEY', 'paid-key'), patch.object(
                ai_provider.httpx, 'AsyncClient', side_effect=lambda **kw: real_client(
                    transport=httpx.MockTransport(handler), **kw)):
            result = await service.check_round_trip('Basket.', '??????')
        self.assertEqual(result['method'], 'openai')
        self.assertEqual(seen, ['api.openai.com', 'api.openai.com'])

    async def test_low_score_asks_for_a_review(self):
        def handler(request):
            if 'response_format' in json.loads(request.content):
                return httpx.Response(200, json=chat_response('{"score": 0.4}'))
            return httpx.Response(200, json=chat_response('A metal lamp.'))

        result, _ = await self.run_check(handler)
        self.assertFalse(result['is_fallback'])
        self.assertEqual(result['confidence_label'], 'review')
        self.assertEqual(result['roundtrip_score'], 0.4)

    async def test_score_is_clamped_to_the_documented_range(self):
        for raw, expected in [('{"score": 4.2}', 1.0), ('{"score": -3}', 0.0)]:
            with self.subTest(raw=raw):
                def handler(request, raw=raw):
                    if 'response_format' in json.loads(request.content):
                        return httpx.Response(200, json=chat_response(raw))
                    return httpx.Response(200, json=chat_response('Basket.'))

                result, _ = await self.run_check(handler)
                self.assertEqual(result['roundtrip_score'], expected)

    async def test_blank_pair_never_calls_the_provider(self):
        for english, translated in [('', 'टोकरी'), ('Basket.', ''), ('', '')]:
            with self.subTest(english=english, translated=translated):
                result, requests = await self.run_check(
                    lambda request: httpx.Response(200, json=chat_response('unused')),
                    english=english, translated=translated)
                self.assertEqual(requests, [])
                self.assertTrue(result['is_fallback'])
                self.assertEqual(result['confidence_label'], 'unavailable')
                self.assertEqual(result['roundtrip_score'], 0.0)

    async def test_missing_key_is_unavailable_without_a_request(self):
        requests = []
        real_client = httpx.AsyncClient
        with patch.object(settings, 'OPENROUTER_API_KEY', None), patch.object(
                settings, 'OPENAI_API_KEY', None), patch.object(
                ai_provider.httpx, 'AsyncClient',
                side_effect=lambda **kw: real_client(
                    transport=httpx.MockTransport(
                        lambda request: requests.append(request)
                        or httpx.Response(200, json=chat_response('unused'))), **kw)):
            result = await service.check_round_trip('Basket.', 'टोकरी।')
        self.assertEqual(requests, [])
        self.assertTrue(result['is_fallback'])
        self.assertEqual(result['method'], 'unavailable')

    async def test_provider_failures_and_junk_never_raise(self):
        cases = [
            lambda request: httpx.Response(500, json={'error': 'SECRET_PROVIDER_DETAIL'}),
            lambda request: httpx.Response(401, json={'error': {'message': 'SECRET'}}),
            lambda request: httpx.Response(200, json=chat_response('not json')),
            lambda request: httpx.Response(200, json=chat_response('{"score": "high"}')),
            lambda request: httpx.Response(200, json={'choices': []}),
        ]
        for index, handler in enumerate(cases):
            with self.subTest(case=index):
                result, _ = await self.run_check(handler)
                self.assertTrue(result['is_fallback'])
                self.assertEqual(result['confidence_label'], 'unavailable')
                self.assertNotIn('SECRET', json.dumps(result))

    async def test_timeout_is_a_fallback(self):
        def handler(request):
            raise httpx.ReadTimeout('SECRET', request=request)

        result, _ = await self.run_check(handler)
        self.assertTrue(result['is_fallback'])
        self.assertNotIn('SECRET', json.dumps(result))

    async def test_language_codes_are_parameterised_not_hardcoded(self):
        captured = []

        def handler(request):
            captured.append(json.loads(request.content))
            if 'response_format' in json.loads(request.content):
                return httpx.Response(200, json=chat_response('{"score": 1.0}'))
            return httpx.Response(200, json=chat_response('translated'))

        result, _ = await self.run_check(handler, translated='हाताने बनवलेले भांडे.',
                                        source_lang='mr')
        self.assertEqual(result['source_lang'], 'mr')
        self.assertIn('हाताने बनवलेले भांडे.', json.dumps(captured[0], ensure_ascii=False))
        self.assertIn('English', json.dumps(captured[0], ensure_ascii=False))

        # The pivot is a parameter too, not a hardcoded English target.
        captured.clear()
        await self.run_check(handler, translated='இது ஒரு கைவினை.',
                             source_lang='ta', pivot_lang='hi')
        self.assertIn('Hindi', json.dumps(captured[0], ensure_ascii=False))
        self.assertNotIn('English', json.dumps(captured[0], ensure_ascii=False))


class TranslationCheckApiTests(unittest.TestCase):
    def setUp(self):
        app = FastAPI()
        app.include_router(studio.router, prefix='/api/v1/studio')

        async def identity(authorization: str = Header(default='')):
            if authorization not in ('Bearer artisan', 'Bearer buyer'):
                raise HTTPException(401, 'Sign in')
            return SimpleNamespace(
                role=AccountRole.artisan if authorization.endswith('artisan')
                else AccountRole.buyer)

        app.dependency_overrides[get_current_user] = identity
        self.client = TestClient(app)
        self.payload = {'description': 'Handwoven basket.',
                        'description_hi': 'बुनी हुई टोकरी।'}

    def test_requires_an_artisan(self):
        for token, status in [('', 401), ('buyer', 403)]:
            response = self.client.post('/api/v1/studio/translation-check',
                headers={'Authorization': 'Bearer ' + token}, json=self.payload)
            self.assertEqual(response.status_code, status)

    def test_returns_the_check_result(self):
        result = {'roundtrip': 'Woven basket.', 'roundtrip_score': 0.9,
                  'confidence_label': 'checked', 'source_lang': 'hi',
                  'pivot_lang': 'en', 'method': 'openai', 'is_fallback': False}
        with patch.object(service, 'check_round_trip',
                          AsyncMock(return_value=result)) as check:
            response = self.client.post('/api/v1/studio/translation-check',
                headers={'Authorization': 'Bearer artisan'}, json=self.payload)
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json(), result)
        self.assertEqual(check.call_args.args,
                         ('Handwoven basket.', 'बुनी हुई टोकरी।', 'hi'))

    def test_rejects_unsupported_language_and_empty_text(self):
        with patch.object(service, 'check_round_trip', AsyncMock()) as check:
            response = self.client.post('/api/v1/studio/translation-check',
                headers={'Authorization': 'Bearer artisan'},
                json={**self.payload, 'source_lang': 'klingon'})
            self.assertEqual(response.status_code, 422)
            response = self.client.post('/api/v1/studio/translation-check',
                headers={'Authorization': 'Bearer artisan'},
                json={**self.payload, 'description': ''})
            self.assertEqual(response.status_code, 422)
        check.assert_not_called()

    def test_overlong_description_is_rejected(self):
        response = self.client.post('/api/v1/studio/translation-check',
            headers={'Authorization': 'Bearer artisan'},
            json={**self.payload, 'description': 'x' * (service.MAX_TEXT + 1)})
        self.assertEqual(response.status_code, 422)
