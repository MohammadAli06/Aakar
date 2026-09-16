"""Pricing vision must receive the stored product photo, not run blind.

Regression: the router resolved product photos against the workspace media directory,
where they are never stored, so every analysis fell back with image_path=None.
"""
import os
os.environ['DEBUG'] = 'false'

from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker

from app.core.auth_deps import require_artisan_profile
from app.core.database import Base, get_db
from app.models.models import Artisan, Product, ProductImage
from app.routers import pricing

PRODUCT_ID = '11111111-1111-1111-1111-111111111111'


class PricingVisionImageTests(unittest.TestCase):
    def setUp(self):
        # The system temp directory, not the repo: writing inside backend/tests is
        # denied on Windows.
        self.directory = tempfile.TemporaryDirectory(prefix='pricing-photo-')
        root = Path(self.directory.name)
        self.media = root / 'products'
        self.media.mkdir()
        self.url = 'sqlite+aiosqlite:///' + (root / 'pricing.db').as_posix()

        app = FastAPI()
        app.include_router(pricing.router, prefix='/api/v1/pricing')

        async def db():
            engine = create_async_engine(self.url)
            async with engine.begin() as conn:
                await conn.run_sync(Base.metadata.create_all)
            factory = async_sessionmaker(engine, expire_on_commit=False)
            async with factory() as session:
                yield session
            await engine.dispose()

        app.dependency_overrides[get_db] = db

        async def artisan():
            return Artisan(id='artisan-1', user_id='user-1')

        app.dependency_overrides[require_artisan_profile] = artisan
        self.patch = patch.object(pricing, '_PRODUCT_MEDIA', self.media)
        self.patch.start()
        self.client = TestClient(app).__enter__()

    def tearDown(self):
        self.client.__exit__(None, None, None)
        self.patch.stop()
        self.directory.cleanup()

    def seed(self, original_url, with_file=True):
        import asyncio

        async def run():
            engine = create_async_engine(self.url)
            async with engine.begin() as conn:
                await conn.run_sync(Base.metadata.create_all)
            factory = async_sessionmaker(engine, expire_on_commit=False)
            async with factory() as session:
                session.add(Product(id=PRODUCT_ID, artisan_id='artisan-1'))
                session.add(ProductImage(id='image-1', product_id=PRODUCT_ID,
                                         original_url=original_url))
                await session.commit()
            await engine.dispose()

        asyncio.run(run())
        if with_file:
            name = original_url.rstrip('/').split('/')[-1]
            (self.media / name).write_bytes(b'\xff\xd8\xff\xd9')

    def analyze(self):
        return self.client.post('/api/v1/pricing/analyze-image',
                                json={'product_id': PRODUCT_ID})

    def result(self, **overrides):
        base = {'complexity_score': 0.8, 'detected_category': 'pottery',
                'material_tier': 'premium', 'reasoning_en': 'r_en',
                'reasoning_hi': 'r_hi', 'model_used': 'gpt-4.1-mini',
                'is_fallback': False}
        return {**base, **overrides}

    def test_stored_product_photo_is_sent_to_vision(self):
        self.seed('/api/v1/products/images/' + 'a' * 32 + '.jpg')
        seen = {}

        async def fake(image_path, description=''):
            seen['image_path'] = image_path
            return self.result()

        with patch.object(pricing, 'analyze_product_image', fake):
            response = self.analyze()
        self.assertEqual(response.status_code, 200, response.text)
        self.assertFalse(response.json()['is_fallback'])
        self.assertEqual(response.json()['complexity_score'], 0.8)
        self.assertIsNotNone(seen['image_path'], 'vision ran without the stored photo')
        self.assertTrue(os.path.isfile(seen['image_path']))

    def test_vision_receives_the_on_disk_path(self):
        self.seed('/api/v1/products/images/' + 'b' * 32 + '.jpg')
        seen = {}

        async def fake(image_path, description=''):
            seen['image_path'] = image_path
            return self.result()

        with patch.object(pricing, 'analyze_product_image', fake):
            self.analyze()
        self.assertTrue(seen['image_path'].endswith('b' * 32 + '.jpg'))

    def test_missing_file_still_reports_a_fallback_rather_than_failing(self):
        self.seed('/api/v1/products/images/' + 'c' * 32 + '.jpg', with_file=False)
        seen = {}

        async def fake(image_path, description=''):
            seen['image_path'] = image_path
            return self.result(model_used='fallback', is_fallback=True)

        with patch.object(pricing, 'analyze_product_image', fake):
            response = self.analyze()
        self.assertEqual(response.status_code, 200, response.text)
        self.assertIsNone(seen['image_path'])
        self.assertTrue(response.json()['is_fallback'])


if __name__ == '__main__':
    unittest.main()
