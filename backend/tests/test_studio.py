"""Studio checks use synthetic photos and mocked OpenAI; no live API spend."""
import os
os.environ['DEBUG'] = 'false'

import base64
import io
import json
from types import SimpleNamespace
import unittest
from unittest.mock import AsyncMock, patch

from fastapi import FastAPI, Header, HTTPException
from fastapi.testclient import TestClient
import httpx
from PIL import Image, ImageDraw

from app.core.auth_deps import get_current_user
from app.core.config import settings
from app.models.models import AccountRole
from app.routers import studio
from app.services import studio_service as service


def photo(size=(300, 180), colour=(110, 100, 90)):
    image = Image.new('RGB', size, colour)
    ImageDraw.Draw(image).rectangle((30, 40, size[0] - 30, size[1] - 40), fill=(160, 50, 30))
    output = io.BytesIO()
    image.save(output, 'PNG')
    return output.getvalue()


def image_response(data=None):
    return {'data': [{'b64_json': base64.b64encode(data or photo(colour='white')).decode()}]}


def catalog_response(text):
    return {'status': 'completed', 'output': [{'type': 'message', 'content': [
        {'type': 'output_text', 'text': text}]}]}


class StudioServiceTests(unittest.IsolatedAsyncioTestCase):
    async def test_distinct_modes_and_fixed_catalog_canvas(self):
        original = photo()
        with patch.object(service, 'edit_photo', AsyncMock(return_value=service.decode_photo(photo(colour='white')))) as openai:
            plain = await service.prepare(original, 'plainBackground')
            self.assertEqual(plain['provider'], 'openai')
            self.assertTrue(plain['review_required'])
            self.assertIn('BACKGROUND REPLACEMENT ONLY', openai.call_args.args[1])
            openai.reset_mock()
            natural = await service.prepare(original, 'naturalSetting')
            openai.assert_not_called()
            self.assertEqual(natural['width'], 300)
            self.assertFalse(natural['review_required'])
            for background in (False, True):
                openai.reset_mock()
                catalog = await service.prepare(original, 'b2bCatalog', background)
                self.assertEqual((catalog['width'], catalog['height']), (1200, 1200))
                self.assertEqual(openai.call_count, int(background))
            self.assertNotEqual(plain['image_base64'], natural['image_base64'])
        self.assertEqual(original, photo())

    async def test_no_image_or_invalid_provider_image_is_a_failure(self):
        for response in ({'data': []}, {'data': [{'b64_json': '!!!'}]}, {'data': None}, {'data': [{'url': 'https://example.com/not-fetched'}]}):
            with patch.object(service, 'request_openai', AsyncMock(return_value=response)):
                with self.assertRaises(service.StudioError):
                    await service.prepare(photo(), 'plainBackground')

    async def test_input_validation_before_openai(self):
        with patch.object(service, 'edit_photo', AsyncMock()) as openai:
            for data in (b'', b'not an image', b'x' * (service.MAX_BYTES + 1)):
                with self.assertRaises(service.StudioError):
                    await service.prepare(data, 'plainBackground')
            openai.assert_not_called()

    async def test_catalog_grounding_and_allowlist(self):
        def suggestion(field, value, **kwargs):
            return {'field': field, 'value': value, 'confidence': 'high',
                    'source': 'image', 'evidence': 'A woven container is visible', **kwargs}
        response = {'suggestions': [
            suggestion('title', 'Woven storage basket'),
            suggestion('title_hi', 'बुनी हुई टोकरी'),
            suggestion('category', 'Baskets'),
            suggestion('colour', 'Brown', confidence='medium'),
            suggestion('material', 'Bamboo'),
            suggestion('material', 'Cotton', source='artisan', evidence='cotton'),
            suggestion('material', 'Bamboo', source='artisan', evidence='made from bamboo'),
            suggestion('dimensions', '30 cm'), suggestion('price', '500'),
            suggestion('approved', 'true'), suggestion('story', 'Made in Jaipur'),
            suggestion('usage', 'Unknown'), suggestion('description', '1234'),
            suggestion('description_hi', 'English only'),
        ], 'questions': ['What are its dimensions?', 'What is its intended use?']}
        with patch.object(service, 'request_openai', AsyncMock(return_value=catalog_response(json.dumps(response)))) as openai:
            result = await service.analyze(photo(), 'This is made from bamboo.', 'hi')
            self.assertEqual(result['fields'], {'title': 'Woven storage basket', 'title_hi': 'बुनी हुई टोकरी',
                                              'category': 'Baskets', 'material': 'Bamboo'})
            self.assertIn('ORIGINAL photo', openai.call_args.kwargs['json']['instructions'])
            self.assertEqual(openai.call_args.kwargs['json']['text']['format']['type'], 'json_schema')

    async def test_invalid_catalog_and_empty_recognition(self):
        for text in ('not json', '[]', '{"suggestions":null,"questions":[]}'):
            with patch.object(service, 'request_openai', AsyncMock(return_value=catalog_response(text))):
                with self.assertRaises(service.StudioError):
                    await service.analyze(photo())
        with patch.object(service, 'request_openai', AsyncMock(return_value=catalog_response('{"suggestions":[],"questions":[]}'))):
            self.assertEqual((await service.analyze(photo()))['fields'], {})

    async def test_image_multipart_and_vision_json_contracts(self):
        requests = []
        def handler(request):
            requests.append(request)
            if request.url.path.endswith('/images/edits'):
                return httpx.Response(200, json=image_response())
            return httpx.Response(200, json=catalog_response('{"suggestions":[],"questions":[]}'))
        real_client = httpx.AsyncClient
        with patch.object(settings, 'OPENAI_API_KEY', 'test-only-key'), patch.object(
                service.httpx, 'AsyncClient', side_effect=lambda **kw: real_client(transport=httpx.MockTransport(handler), **kw)):
            self.assertEqual((await service.prepare(photo(), 'plainBackground'))['provider'], 'openai')
            self.assertEqual((await service.analyze(photo(), 'made from bamboo'))['fields'], {})
        for request in requests:
            self.assertEqual(request.url.host, 'api.openai.com')
            self.assertNotIn('test-only-key', str(request.url))
            self.assertEqual(request.headers['Authorization'], 'Bearer test-only-key')
        image_request, vision_request = requests
        self.assertIn('multipart/form-data', image_request.headers['content-type'])
        self.assertIn(b'name="image"; filename="original.jpg"', image_request.content)
        self.assertIn(b'Content-Type: image/jpeg', image_request.content)
        self.assertIn(settings.OPENAI_IMAGE_MODEL.encode(), image_request.content)
        self.assertIn(b'BACKGROUND REPLACEMENT ONLY', image_request.content)
        self.assertNotIn(b'input_fidelity', image_request.content)
        payload = json.loads(vision_request.content)
        self.assertFalse(payload['store'])
        self.assertTrue(payload['text']['format']['strict'])
        self.assertEqual(payload['model'], settings.OPENAI_VISION_MODEL)
        self.assertTrue(payload['input'][0]['content'][1]['image_url'].startswith('data:image/jpeg;base64,'))

    async def test_quota_rate_limits_and_provider_failures_are_actionable_and_safe(self):
        for status, code, expected_status, hint in [
            (429, 'insufficient_quota', 429, 'credit'),
            (429, 'rate_limit_exceeded', 429, 'Wait'),
            (401, 'invalid_api_key', 503, 'OPENAI_API_KEY'),
            (403, 'permission_denied', 503, 'model access'),
            (400, 'invalid_request_error', 422, 'configured model'),
            (500, 'server_error', 502, 'unavailable'),
        ]:
            with self.subTest(code=code):
                client = httpx.AsyncClient(transport=httpx.MockTransport(lambda request:
                    httpx.Response(status, json={'error': {'code': code, 'message': 'SECRET_PROVIDER_DETAIL'}})))
                with patch.object(settings, 'OPENAI_API_KEY', 'test-only-key'), patch.object(service.httpx, 'AsyncClient', return_value=client):
                    with self.assertRaises(service.StudioError) as failure:
                        await service.prepare(photo(), 'plainBackground')
                self.assertEqual(failure.exception.status, expected_status)
                self.assertIn(hint, str(failure.exception))
                self.assertNotIn('SECRET', str(failure.exception))
                self.assertNotIn('test-only-key', str(failure.exception))

    async def test_incomplete_or_refused_catalog_is_not_used(self):
        for response in ({'status': 'incomplete', 'output': []},
                         {'status': 'completed', 'output': [{'type': 'message', 'content': [{'type': 'refusal'}]}]},
                         {'status': 'completed', 'output': None}):
            with patch.object(service, 'request_openai', AsyncMock(return_value=response)):
                with self.assertRaises(service.StudioError):
                    await service.analyze(photo())

    async def test_timeout_keeps_original_and_reports_retry(self):
        def handler(request):
            raise httpx.ReadTimeout('SECRET', request=request)
        client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
        with patch.object(settings, 'OPENAI_API_KEY', 'test-only-key'), patch.object(service.httpx, 'AsyncClient', return_value=client):
            with self.assertRaises(service.StudioError) as failure:
                await service.prepare(photo(), 'plainBackground')
        self.assertEqual(failure.exception.status, 504)
        self.assertIn('original is unchanged', str(failure.exception))
        self.assertNotIn('SECRET', str(failure.exception))

    async def test_key_missing_fails_explicitly_but_natural_still_works(self):
        with patch.object(settings, 'OPENAI_API_KEY', None):
            with self.assertRaises(service.StudioError) as failure:
                await service.prepare(photo(), 'plainBackground')
            self.assertEqual(failure.exception.status, 503)
            self.assertIn('OPENAI_API_KEY', str(failure.exception))
            self.assertEqual((await service.prepare(photo(), 'naturalSetting'))['provider'], 'deterministic')

    def test_exif_rotation_and_wide_catalog_product_not_truncated(self):
        image = Image.new('RGB', (80, 40), 'red')
        exif = Image.Exif()
        exif[274] = 6
        stream = io.BytesIO()
        image.save(stream, 'JPEG', exif=exif)
        self.assertEqual(service.decode_photo(stream.getvalue()).size, (40, 80))
        wide = Image.new('RGB', (600, 100), 'white')
        draw = ImageDraw.Draw(wide)
        draw.rectangle((20, 30, 580, 70), fill='blue')
        draw.rectangle((20, 30, 40, 70), fill='red')
        result = service.catalog_frame(wide, trim_white=True)
        self.assertEqual(result.size, (1200, 1200))
        self.assertEqual(result.getpixel((119, 600)), (255, 255, 255))
        self.assertTrue(any(r > 200 and b < 50 for r, g, b in result.getdata()))
        self.assertTrue(any(b > 200 and r < 50 for r, g, b in result.getdata()))


class StudioApiTests(unittest.TestCase):
    def setUp(self):
        app = FastAPI()
        app.include_router(studio.router, prefix='/api/v1/studio')
        async def identity(authorization: str = Header(default='')):
            if authorization not in ('Bearer artisan', 'Bearer buyer'):
                raise HTTPException(401, 'Sign in')
            return SimpleNamespace(role=AccountRole.artisan if authorization.endswith('artisan') else AccountRole.buyer)
        app.dependency_overrides[get_current_user] = identity
        self.client = TestClient(app)

    def test_auth_validation_and_modes(self):
        for endpoint in ('prepare', 'catalog'):
            for token, status in [('', 401), ('buyer', 403)]:
                response = self.client.post('/api/v1/studio/' + endpoint,
                    headers={'Authorization': 'Bearer ' + token},
                    files={'file': ('photo.png', photo(), 'image/png')}, data={'mode': 'plainBackground'})
                self.assertEqual(response.status_code, status)
        with patch.object(service, 'edit_photo', AsyncMock(return_value=service.decode_photo(photo(colour='white')))):
            response = self.client.post('/api/v1/studio/prepare', headers={'Authorization': 'Bearer artisan'},
                files={'file': ('photo.png', photo(), 'image/png')}, data={'mode': 'b2bCatalog'})
            self.assertEqual(response.status_code, 200, response.text)
            self.assertEqual(response.json()['width'], 1200)
        response = self.client.post('/api/v1/studio/prepare', headers={'Authorization': 'Bearer artisan'},
            files={'file': ('photo.png', photo(), 'image/png')}, data={'mode': 'invented'})
        self.assertEqual(response.status_code, 422)
