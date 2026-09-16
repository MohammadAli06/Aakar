"""Draft pricing analysis must send the photo to vision, not run blind.

The pricing step runs before a new product is saved, so /analyze-draft carries the
image inline. These tests pin that the decoded photo reaches the vision service.
"""
import os
os.environ['DEBUG'] = 'false'

import base64
import unittest
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.core.auth_deps import require_artisan_profile
from app.models.models import Artisan
from app.routers import pricing

# Smallest valid JPEG-ish payload; the vision service is mocked, so only the
# transport and the decoded bytes matter here.
PHOTO = b'\xff\xd8\xff\xe0' + b'photo-bytes' * 4


def data_uri(payload=PHOTO):
    return 'data:image/jpeg;base64,' + base64.b64encode(payload).decode()


class AnalyzeDraftTests(unittest.TestCase):
    def setUp(self):
        app = FastAPI()
        app.include_router(pricing.router, prefix='/api/v1/pricing')

        async def artisan():
            return Artisan(id='artisan-1', user_id='user-1')

        app.dependency_overrides[require_artisan_profile] = artisan
        self.client = TestClient(app)
        self.seen = {}

    def result(self, **overrides):
        base = {'complexity_score': 0.7, 'detected_category': 'pottery',
                'material_tier': 'medium', 'reasoning_en': 'r_en',
                'reasoning_hi': 'r_hi', 'model_used': 'gpt-4.1-mini',
                'is_fallback': False}
        return {**base, **overrides}

    def analyze(self, payload):
        async def fake(image_path, description=''):
            self.seen['image_path'] = image_path
            self.seen['description'] = description
            self.seen['bytes'] = None
            if image_path:
                with open(image_path, 'rb') as handle:
                    self.seen['bytes'] = handle.read()
            return self.result()

        with patch.object(pricing, 'analyze_product_image', fake):
            return self.client.post('/api/v1/pricing/analyze-draft', json=payload)

    def test_the_draft_photo_reaches_vision(self):
        response = self.analyze({'image_b64': data_uri(), 'description': 'clay pot'})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertFalse(response.json()['is_fallback'])
        self.assertEqual(response.json()['complexity_score'], 0.7)
        self.assertIsNotNone(self.seen['image_path'], 'vision ran without the photo')
        self.assertEqual(self.seen['bytes'], PHOTO)
        self.assertEqual(self.seen['description'], 'clay pot')

    def test_the_temp_file_is_removed_after_analysis(self):
        self.analyze({'image_b64': data_uri()})
        self.assertFalse(os.path.exists(self.seen['image_path']))

    def test_raw_base64_without_a_data_uri_prefix_still_works(self):
        raw = base64.b64encode(PHOTO).decode()
        response = self.analyze({'image_b64': raw})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(self.seen['bytes'], PHOTO)

    def test_no_photo_still_answers_with_a_honest_result(self):
        response = self.analyze({'image_b64': None, 'description': 'clay pot'})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertIsNone(self.seen['image_path'])
        self.assertEqual(self.seen['description'], 'clay pot')

    def test_undecodable_photo_degrades_to_text_only(self):
        response = self.analyze({'image_b64': 'data:image/jpeg;base64,!!!not-base64!!!'})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertIsNone(self.seen['image_path'])

    def test_analysis_needs_an_artisan(self):
        app = FastAPI()
        app.include_router(pricing.router, prefix='/api/v1/pricing')

        async def no_artisan():
            raise __import__('fastapi').HTTPException(403, 'Artisan only')

        app.dependency_overrides[require_artisan_profile] = no_artisan
        client = TestClient(app)
        response = client.post('/api/v1/pricing/analyze-draft', json={'image_b64': data_uri()})
        self.assertEqual(response.status_code, 403)


if __name__ == '__main__':
    unittest.main()
