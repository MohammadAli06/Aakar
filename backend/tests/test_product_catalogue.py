"""Product catalogue API: real, account-scoped products shared with the admin console."""
import os
os.environ['DEBUG'] = 'false'

from contextlib import asynccontextmanager
from io import BytesIO
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient
from PIL import Image
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker

from app.core.database import Base, get_db
from app.core.config import settings
from app.routers import admin, auth, catalog, products


async def identity(token):
    if token not in ('alice', 'bob'):
        raise ValueError('Invalid token')
    return {'uid': token, 'phone_number': '+919876543210' if token == 'alice' else '+919876543211'}


READY_PRODUCT = {
    'category': 'Baskets',
    'title': 'Handmade Bamboo Basket',
    'title_hi': 'हस्तनिर्मित बाँस की टोकरी',
    'description': 'Handwoven bamboo storage basket with a fitted lid.',
    'craft': 'Bamboo & cane',
    'material': 'Bamboo',
    'colour': 'Natural',
    'dimensions': '30 × 25 cm',
    'usage': 'Storage and gifting',
    'story': 'Woven by hand in Jaipur',
    'location': 'Jaipur, Rajasthan',
    'price': 400,
    'material_cost': 90,
    'labour_cost': 100,
    'overhead': 30,
    'complexity': 0.6,
    'moq': 50,
    'stock': 250,
    'capacity': 500,
    'lead_days': 20,
    'available': True,
    'customizable': True,
    'fragile': False,
    'can_pack': True,
    'image': 'http://testserver/api/v1/products/images/' + 'a' * 32 + '.jpg',
    'original_image': 'http://testserver/api/v1/products/images/' + 'a' * 32 + '.jpg',
    'transcript': 'बाँस की टोकरी',
    'approved': True,
}


class ProductCatalogueTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='product-runtime-')
        root = Path(self.directory.name)
        self.engine = create_async_engine('sqlite+aiosqlite:///' + (root / 'products.db').as_posix())
        sessions = async_sessionmaker(self.engine, expire_on_commit=False)

        async def db():
            async with sessions() as session:
                yield session

        @asynccontextmanager
        async def lifespan(app):
            async with self.engine.begin() as conn:
                await conn.run_sync(Base.metadata.create_all)
            yield
            await self.engine.dispose()

        app = FastAPI(lifespan=lifespan)
        app.include_router(auth.router, prefix='/api/v1/auth')
        app.include_router(products.router, prefix='/api/v1/products')
        app.include_router(catalog.router, prefix='/api/v1/catalog')
        app.include_router(admin.router, prefix='/api/v1/admin')
        app.dependency_overrides[get_db] = db
        self.patches = [patch('app.routers.auth.verify_firebase_token', identity),
                        patch('app.core.auth_deps.verify_firebase_token', identity),
                        patch('app.routers.auth.set_role_claim'),
                        patch.object(products, 'MEDIA', root / 'uploads' / 'products'),
                        patch.object(settings, 'ADMIN_ACCESS_TOKEN', 'reviewer')]
        for p in self.patches:
            p.start()
        self.client = TestClient(app).__enter__()
        self.auth = '/api/v1/auth'
        self.base = '/api/v1/products'
        self.alice = {'Authorization': 'Bearer alice'}
        self.bob = {'Authorization': 'Bearer bob'}
        self.admin = {'Authorization': 'Bearer reviewer'}

    def tearDown(self):
        self.client.__exit__(None, None, None)
        for p in reversed(self.patches):
            p.stop()
        self.directory.cleanup()

    def register(self, headers, role):
        response = self.client.post(self.auth + '/verify-token?role=' + role, headers=headers)
        self.assertEqual(response.status_code, 200, response.text)

    def create(self, headers, **overrides):
        payload = {**READY_PRODUCT, **overrides}
        response = self.client.post(self.base + '/', headers=headers, json=payload)
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def test_gemini_photo_metadata_persists_and_requires_review_to_publish(self):
        self.register(self.alice, 'artisan')
        product = self.create(self.alice, prepared='b2bCatalog', catalog_plain_background=True,
                              photo_provider='gemini', photo_reviewed=False)
        self.assertEqual(product['prepared'], 'b2bCatalog')
        self.assertFalse(product['photo_reviewed'])
        response = self.client.post(f"{self.base}/{product['id']}/publish", headers=self.alice)
        self.assertEqual(response.status_code, 422, response.text)
        self.assertIn('photo review', response.text)
        response = self.client.put(f"{self.base}/{product['id']}", headers=self.alice,
            json={**READY_PRODUCT, 'prepared': 'b2bCatalog', 'catalog_plain_background': True,
                  'photo_provider': 'gemini', 'photo_reviewed': True})
        self.assertEqual(response.status_code, 200, response.text)
        listed = self.client.get(self.base + '/', headers=self.alice).json()[0]
        self.assertTrue(listed['photo_reviewed'])
        self.assertEqual(listed['photo_provider'], 'gemini')
        response = self.client.post(f"{self.base}/{product['id']}/publish", headers=self.alice)
        self.assertEqual(response.status_code, 200, response.text)

    def test_openai_photo_metadata_persists_and_requires_review_to_publish(self):
        self.register(self.alice, 'artisan')
        product = self.create(self.alice, prepared='b2bCatalog', catalog_plain_background=True,
                              photo_provider='openai', photo_reviewed=False)
        self.assertEqual(product['prepared'], 'b2bCatalog')
        self.assertFalse(product['photo_reviewed'])
        response = self.client.post(f"{self.base}/{product['id']}/publish", headers=self.alice)
        self.assertEqual(response.status_code, 422, response.text)
        self.assertIn('photo review', response.text)
        response = self.client.put(f"{self.base}/{product['id']}", headers=self.alice,
            json={**READY_PRODUCT, 'prepared': 'b2bCatalog', 'catalog_plain_background': True,
                  'photo_provider': 'openai', 'photo_reviewed': True})
        self.assertEqual(response.status_code, 200, response.text)
        listed = self.client.get(self.base + '/', headers=self.alice).json()[0]
        self.assertTrue(listed['photo_reviewed'])
        self.assertEqual(listed['photo_provider'], 'openai')
        response = self.client.post(f"{self.base}/{product['id']}/publish", headers=self.alice)
        self.assertEqual(response.status_code, 200, response.text)

    def test_saved_product_reaches_the_shared_catalogue(self):
        self.register(self.alice, 'artisan')
        row = self.create(self.alice)
        self.assertEqual(row['title'], 'Handmade Bamboo Basket')
        self.assertEqual(row['category'], 'Baskets')
        self.assertEqual(row['price'], 400)
        self.assertEqual(row['status'], 'draft')
        self.assertTrue(row['approved'])
        self.assertEqual(row['material'], 'Bamboo')

        mine = self.client.get(self.base + '/', headers=self.alice).json()
        self.assertEqual([p['id'] for p in mine], [row['id']])

        detail = self.client.get(self.base + '/' + row['id'], headers=self.alice).json()
        self.assertEqual(detail['dimensions'], '30 × 25 cm')

        # The admin console reads the same rows.
        listed = self.client.get('/api/v1/admin/products', headers=self.admin).json()
        self.assertEqual([p['id'] for p in listed], [row['id']])
        self.assertEqual(listed[0]['category'], 'Baskets')
        self.assertEqual(listed[0]['listing_status'], 'approved')
        self.assertEqual(listed[0]['final_price'], 400)

    def test_a_draft_without_listing_detail_still_creates_a_product(self):
        self.register(self.alice, 'artisan')
        created = self.client.post(self.base + '/', headers=self.alice, json={'category': 'pottery'})
        self.assertEqual(created.status_code, 200, created.text)
        self.assertEqual(created.json()['status'], 'draft')
        detail = self.client.get('/api/v1/admin/products/' + created.json()['id'],
                                 headers=self.admin).json()
        self.assertIsNone(detail['listing'])

    def test_price_below_the_cost_floor_is_refused(self):
        self.register(self.alice, 'artisan')
        response = self.client.post(self.base + '/', headers=self.alice,
                                    json={**READY_PRODUCT, 'price': 100})
        self.assertEqual(response.status_code, 422, response.text)
        self.assertIn('floor', response.json()['detail'])

    def test_publish_requires_internal_readiness(self):
        self.register(self.alice, 'artisan')
        self.register(self.bob, 'buyer')
        row = self.create(self.alice, moq=0, customizable=None)
        blocked = self.client.post(self.base + '/' + row['id'] + '/publish', headers=self.alice)
        self.assertEqual(blocked.status_code, 422, blocked.text)
        self.assertIn('Complete readiness', blocked.json()['detail'])

        fixed = self.client.put(self.base + '/' + row['id'], headers=self.alice,
                                json={**READY_PRODUCT, 'title': 'Handmade Bamboo Basket'})
        self.assertEqual(fixed.status_code, 200, fixed.text)
        published = self.client.post(self.base + '/' + row['id'] + '/publish', headers=self.alice)
        self.assertEqual(published.status_code, 200, published.text)
        self.assertEqual(published.json()['status'], 'published')

        # Buyers see published products only.
        marketplace = self.client.get('/api/v1/catalog/published', headers=self.bob).json()
        self.assertEqual([p['id'] for p in marketplace], [row['id']])
        self.assertEqual(marketplace[0]['artisan_name'], None)

    def test_availability_is_operational_only(self):
        self.register(self.alice, 'artisan')
        row = self.create(self.alice)
        self.client.post(self.base + '/' + row['id'] + '/publish', headers=self.alice)
        off = self.client.post(self.base + '/' + row['id'] + '/availability',
                               headers=self.alice, json={'available': False})
        self.assertEqual(off.status_code, 200, off.text)
        self.assertFalse(off.json()['available'])
        self.assertEqual(off.json()['status'], 'published')

    def test_another_artisan_cannot_reach_the_product(self):
        self.register(self.alice, 'artisan')
        self.register(self.bob, 'artisan')
        row = self.create(self.alice)
        self.assertEqual(self.client.get(self.base + '/' + row['id'],
                                         headers=self.bob).status_code, 403)
        self.assertEqual(self.client.put(self.base + '/' + row['id'], headers=self.bob,
                                         json=READY_PRODUCT).status_code, 403)
        self.assertEqual(self.client.post(self.base + '/' + row['id'] + '/publish',
                                          headers=self.bob).status_code, 403)
        self.assertEqual(self.client.post(self.base + '/' + row['id'] + '/availability',
                                          headers=self.bob,
                                          json={'available': False}).status_code, 403)

    def test_buyers_cannot_write_the_catalogue(self):
        self.register(self.bob, 'buyer')
        response = self.client.post(self.base + '/', headers=self.bob, json=READY_PRODUCT)
        self.assertEqual(response.status_code, 403)

    def test_product_photo_upload_stores_an_image(self):
        self.register(self.alice, 'artisan')
        output = BytesIO()
        Image.new('RGB', (32, 32), 'brown').save(output, 'PNG')
        response = self.client.post(self.base + '/images', headers=self.alice,
                                    files={'file': ('photo.png', output.getvalue(), 'image/png')})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertRegex(response.json()['path'],
                         r'^/api/v1/products/images/[a-f0-9]{32}\.jpg$')

        served = self.client.get(response.json()['path'])
        self.assertEqual(served.status_code, 200)
        self.assertEqual(served.headers['content-type'], 'image/jpeg')

    def test_upload_rejects_non_images(self):
        self.register(self.alice, 'artisan')
        response = self.client.post(self.base + '/images', headers=self.alice,
                                    files={'file': ('notes.txt', b'not an image', 'text/plain')})
        self.assertEqual(response.status_code, 422)


if __name__ == '__main__':
    unittest.main()
