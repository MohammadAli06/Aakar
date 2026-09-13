"""Buyer requirements: account-scoped demand that the admin console can see."""
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
from app.routers import admin, auth, requirements

PHONES = {
    'alice': '+919876543210',
    'bob': '+919876543211',
    'carol': '+919876543212',
}


async def identity(token):
    if token not in PHONES:
        raise ValueError('Invalid token')
    return {'uid': token, 'phone_number': PHONES[token]}


REQUIREMENT = {
    'product': 'Handmade bamboo baskets for hotel gifting',
    'quantity': 500,
    'lead_days': 30,
    'location': 'Mumbai, Maharashtra',
    'budget': 320,
    'customization': 'Logo on the lid',
    'specifications': 'Food-safe natural finish',
    'packaging': 'Individual cartons',
    'target_date': '2027-01-15',
    'sample_required': True,
    'original': 'मुझे 500 बाँस की टोकरियाँ 30 दिन में चाहिए',
    'confirmed': True,
}


class RequirementApiTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='requirement-runtime-')
        root = Path(self.directory.name)
        self.engine = create_async_engine('sqlite+aiosqlite:///' + (root / 'requirements.db').as_posix())
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
        app.include_router(requirements.router, prefix='/api/v1/requirements')
        app.include_router(admin.router, prefix='/api/v1/admin')
        app.dependency_overrides[get_db] = db
        self.patches = [patch('app.routers.auth.verify_firebase_token', identity),
                        patch('app.core.auth_deps.verify_firebase_token', identity),
                        patch('app.routers.auth.set_role_claim'),
                        patch.object(requirements, 'MEDIA', root / 'uploads' / 'requirements'),
                        patch.object(settings, 'ADMIN_ACCESS_TOKEN', 'reviewer')]
        for p in self.patches:
            p.start()
        self.client = TestClient(app).__enter__()
        self.auth = '/api/v1/auth'
        self.base = '/api/v1/requirements'
        self.admin_base = '/api/v1/admin'
        self.alice = {'Authorization': 'Bearer alice'}
        self.bob = {'Authorization': 'Bearer bob'}
        self.carol = {'Authorization': 'Bearer carol'}
        self.admin = {'Authorization': 'Bearer reviewer'}

    def tearDown(self):
        self.client.__exit__(None, None, None)
        for p in reversed(self.patches):
            p.stop()
        self.directory.cleanup()

    def register(self, headers, role, business=None):
        response = self.client.post(self.auth + '/verify-token?role=' + role, headers=headers)
        self.assertEqual(response.status_code, 200, response.text)
        if business is not None:
            self.client.put(self.auth + '/buyer-profile', headers=headers,
                            json={'name': business, 'business_name': business,
                                  'state': 'Maharashtra'})

    def post(self, headers, **overrides):
        response = self.client.post(self.base + '/', headers=headers,
                                    json={**REQUIREMENT, **overrides})
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def test_buyer_requirement_reaches_the_shared_store(self):
        self.register(self.alice, 'buyer', 'The Earth Store')
        row = self.post(self.alice)
        self.assertEqual(row['product'], REQUIREMENT['product'])
        self.assertEqual(row['quantity'], 500)
        self.assertEqual(row['lead_days'], 30)
        self.assertEqual(row['status'], 'open')
        self.assertTrue(row['sample_required'])
        # The buyer's own words are preserved verbatim.
        self.assertEqual(row['original'], REQUIREMENT['original'])

        mine = self.client.get(self.base + '/', headers=self.alice).json()
        self.assertEqual([r['id'] for r in mine], [row['id']])
        detail = self.client.get(self.base + '/' + row['id'], headers=self.alice).json()
        self.assertEqual(detail['customization'], 'Logo on the lid')

    def test_unconfirmed_requirement_is_refused(self):
        self.register(self.alice, 'buyer')
        response = self.client.post(self.base + '/', headers=self.alice,
                                    json={**REQUIREMENT, 'confirmed': False})
        self.assertEqual(response.status_code, 422, response.text)
        self.assertIn('confirm', response.json()['detail'])

    def test_incomplete_requirement_is_refused(self):
        self.register(self.alice, 'buyer')
        for overrides in ({'quantity': 0}, {'lead_days': 0}, {'location': '   '},
                          {'product': '   '}, {'quantity': -5}):
            with self.subTest(**overrides):
                response = self.client.post(self.base + '/', headers=self.alice,
                                            json={**REQUIREMENT, **overrides})
                self.assertEqual(response.status_code, 422, response.text)
        self.assertEqual(self.client.get(self.base + '/', headers=self.alice).json(), [])

    def test_only_buyers_can_post_or_list(self):
        self.register(self.alice, 'artisan')
        self.assertEqual(self.client.post(self.base + '/', headers=self.alice,
                                          json=REQUIREMENT).status_code, 403)
        self.assertEqual(self.client.get(self.base + '/', headers=self.alice).status_code, 403)

    def test_another_buyer_cannot_read_the_requirement(self):
        self.register(self.alice, 'buyer')
        self.register(self.bob, 'buyer')
        row = self.post(self.alice)
        self.assertEqual(self.client.get(self.base + '/' + row['id'],
                                         headers=self.bob).status_code, 403)
        self.assertEqual(self.client.get(self.base + '/', headers=self.bob).json(), [])

    def test_reference_image_upload(self):
        self.register(self.alice, 'buyer')
        self.register(self.bob, 'artisan')
        output = BytesIO()
        Image.new('RGB', (24, 24), 'blue').save(output, 'PNG')

        uploaded = self.client.post(self.base + '/images', headers=self.alice,
                                    files={'file': ('ref.png', output.getvalue(), 'image/png')})
        self.assertEqual(uploaded.status_code, 200, uploaded.text)
        self.assertRegex(uploaded.json()['path'],
                         r'^/api/v1/requirements/images/[a-f0-9]{32}\.jpg$')
        served = self.client.get(uploaded.json()['path'])
        self.assertEqual(served.status_code, 200)
        self.assertEqual(served.headers['content-type'], 'image/jpeg')

        # Artisans do not upload buyer reference images, and non-images are refused.
        self.assertEqual(self.client.post(self.base + '/images', headers=self.bob,
                                          files={'file': ('ref.png', output.getvalue(),
                                                          'image/png')}).status_code, 403)
        self.assertEqual(self.client.post(self.base + '/images', headers=self.alice,
                                          files={'file': ('notes.txt', b'not an image',
                                                          'text/plain')}).status_code, 422)

    def test_admin_sees_requirements_and_counts(self):
        self.assertEqual(self.client.get(self.admin_base + '/requirements').status_code, 403)
        self.assertEqual(self.client.get(self.admin_base + '/requirements',
                                         headers=self.alice).status_code, 403)

        self.register(self.alice, 'buyer', 'The Earth Store')
        self.register(self.bob, 'buyer', 'Blue Lotus Traders')
        first = self.post(self.alice)
        second = self.post(self.bob, product='Cotton handloom stoles', quantity=80,
                           lead_days=20, location='Delhi', budget=900)

        listed = self.client.get(self.admin_base + '/requirements', headers=self.admin).json()
        self.assertEqual([row['id'] for row in listed], [second['id'], first['id']])
        self.assertEqual(listed[1]['buyer_name'], 'The Earth Store')
        self.assertEqual(listed[1]['business_name'], 'The Earth Store')
        self.assertEqual(listed[1]['quantity'], 500)

        filtered = self.client.get(self.admin_base + '/requirements?q=stoles',
                                   headers=self.admin).json()
        self.assertEqual([row['id'] for row in filtered], [second['id']])
        self.assertEqual(self.client.get(self.admin_base + '/requirements?q=nothing',
                                         headers=self.admin).json(), [])
        self.assertEqual(self.client.get(self.admin_base + '/requirements?status=closed',
                                         headers=self.admin).json(), [])

        overview = self.client.get(self.admin_base + '/overview', headers=self.admin).json()
        self.assertEqual(overview['requirements'], {'total': 2, 'open': 2})


if __name__ == '__main__':
    unittest.main()
