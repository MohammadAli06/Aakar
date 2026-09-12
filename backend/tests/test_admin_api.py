"""Administrator console API: access control, directory, moderation and audit trail."""
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
from app.routers import admin, auth, products, account_verification


async def identity(token):
    if token not in ('alice', 'bob'):
        raise ValueError('Invalid token')
    return {'uid': token, 'phone_number': '+919876543210' if token == 'alice' else '+919876543211'}


class AdminApiTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='admin-runtime-')
        root = Path(self.directory.name)
        self.engine = create_async_engine('sqlite+aiosqlite:///' + (root / 'admin.db').as_posix())
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
        app.include_router(account_verification.router, prefix='/api/v1/auth')
        app.include_router(products.router, prefix='/api/v1/products')
        app.include_router(admin.router, prefix='/api/v1/admin')
        app.dependency_overrides[get_db] = db
        self.patches = [patch('app.routers.auth.verify_firebase_token', identity),
                        patch('app.core.auth_deps.verify_firebase_token', identity),
                        patch('app.routers.auth.set_role_claim'),
                        patch.object(account_verification, 'MEDIA', root / 'uploads'),
                        patch.object(settings, 'ADMIN_ACCESS_TOKEN', 'reviewer')]
        for p in self.patches:
            p.start()
        self.client = TestClient(app).__enter__()
        self.auth = '/api/v1/auth'
        self.base = '/api/v1/admin'
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
        return response.json()

    def submit_verification(self):
        for kind in ('identity', 'craft', 'selfie'):
            output = BytesIO()
            Image.new('RGB', (24, 24), 'green').save(output, 'PNG')
            response = self.client.post(self.auth + '/verification/evidence', headers=self.alice,
                data={'kind': kind}, files={'file': ('image.png', output.getvalue(), 'image/png')})
            self.assertEqual(response.status_code, 200, response.text)
        return self.client.post(self.auth + '/verification/submit', headers=self.alice,
                                json={'consent': True}).json()

    def test_admin_only_access(self):
        for path in ('/overview', '/accounts', '/products', '/activity', '/platform'):
            self.assertEqual(self.client.get(self.base + path).status_code, 403)
            self.assertEqual(self.client.get(self.base + path, headers=self.alice).status_code, 403)
            self.assertEqual(self.client.get(self.base + path, headers=self.admin).status_code, 200)

    def test_directory_and_overview_counts(self):
        self.register(self.alice, 'artisan')
        self.register(self.bob, 'buyer')
        self.client.put(self.auth + '/artisan-profile', headers=self.alice,
                        json={'name': 'Alice', 'state': 'Gujarat', 'district': 'Kutch',
                              'craft_category': 'weaving'})
        self.client.put(self.auth + '/buyer-profile', headers=self.bob,
                        json={'name': 'Bob', 'business_name': 'Bob Traders', 'state': 'Delhi'})
        self.submit_verification()

        overview = self.client.get(self.base + '/overview', headers=self.admin).json()
        self.assertEqual(overview['accounts']['total'], 2)
        self.assertEqual(overview['accounts']['artisan'], 1)
        self.assertEqual(overview['accounts']['buyer'], 1)
        self.assertEqual(overview['verifications']['pending'], 1)
        self.assertEqual(overview['verifications']['not_started'], 1)

        artisans = self.client.get(self.base + '/accounts?role=artisan', headers=self.admin).json()
        self.assertEqual([row['name'] for row in artisans], ['Alice'])
        self.assertEqual(artisans[0]['verification'], 'pending')
        self.assertEqual(artisans[0]['location'], 'Kutch, Gujarat')

        found = self.client.get(self.base + '/accounts?q=bob', headers=self.admin).json()
        self.assertEqual([row['business_name'] for row in found], ['Bob Traders'])

        detail = self.client.get(self.base + '/accounts/' + artisans[0]['id'], headers=self.admin).json()
        self.assertEqual(sorted(detail['evidence']), ['craft', 'identity', 'selfie'])
        self.assertFalse(detail['is_verified'])

    def test_moderation_records_state_and_audit(self):
        self.register(self.alice, 'artisan')
        self.client.put(self.auth + '/artisan-profile', headers=self.alice, json={'name': 'Alice'})
        created = self.client.post('/api/v1/products/', headers=self.alice, json={'category': 'pottery'})
        self.assertEqual(created.status_code, 200, created.text)
        product_id = created.json()['id']

        self.assertEqual(self.client.put(self.base + '/products/' + product_id + '/moderation',
            headers=self.alice, json={'status': 'flagged', 'note': 'Check photo'}).status_code, 403)
        self.assertEqual(self.client.put(self.base + '/products/' + product_id + '/moderation',
            headers=self.admin, json={'status': 'unclear', 'note': 'x'}).status_code, 422)
        self.assertEqual(self.client.put(self.base + '/products/' + product_id + '/moderation',
            headers=self.admin, json={'status': 'flagged', 'note': '  '}).status_code, 422)

        response = self.client.put(self.base + '/products/' + product_id + '/moderation',
            headers=self.admin, json={'status': 'flagged', 'note': 'Image looks machine-made'})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()['moderation'], 'flagged')

        flagged = self.client.get(self.base + '/products?moderation=flagged', headers=self.admin).json()
        self.assertEqual([row['id'] for row in flagged], [product_id])
        self.assertEqual(flagged[0]['artisan_name'], 'Alice')
        self.assertEqual(self.client.get(self.base + '/products?moderation=blocked',
                                         headers=self.admin).json(), [])
        self.assertEqual(self.client.get(self.base + '/overview', headers=self.admin).json()
                         ['products']['flagged'], 1)

        detail = self.client.get(self.base + '/products/' + product_id, headers=self.admin).json()
        self.assertEqual(detail['moderation_note'], 'Image looks machine-made')
        self.assertIsNone(detail['listing'])

        events = self.client.get(self.base + '/activity', headers=self.admin).json()
        self.assertIn('product_flagged', [event['action'] for event in events])

    def test_verification_decision_and_account_status_are_audited(self):
        self.register(self.alice, 'artisan')
        self.client.put(self.auth + '/artisan-profile', headers=self.alice,
                        json={'name': 'Alice', 'state': 'Gujarat', 'district': 'Kutch'})
        record = self.submit_verification()
        self.client.put(self.auth + '/verification-admin/' + record['id'], headers=self.admin,
                        json={'status': 'verified', 'note': 'Documents match'})

        events = self.client.get(self.base + '/activity', headers=self.admin).json()
        actions = [event['action'] for event in events]
        self.assertIn('verification_submitted', actions)
        self.assertIn('verification_verified', actions)
        self.assertEqual(self.client.get(self.base + '/overview', headers=self.admin).json()
                         ['accounts']['verified'], 1)

        detail = self.client.get(self.base + '/accounts?role=artisan', headers=self.admin).json()[0]
        disabled = self.client.put(self.base + '/accounts/' + detail['id'] + '/status',
            headers=self.admin, json={'is_active': False, 'note': 'Duplicate registration'})
        self.assertEqual(disabled.status_code, 200, disabled.text)
        self.assertFalse(disabled.json()['is_active'])
        self.assertEqual(self.client.get(self.auth + '/me', headers=self.alice).status_code, 403)
        self.assertEqual(self.client.get(self.base + '/overview', headers=self.admin).json()
                         ['accounts']['disabled'], 1)
        self.assertIn('account_disabled', [event['action'] for event in
                      self.client.get(self.base + '/activity', headers=self.admin).json()])


if __name__ == '__main__':
    unittest.main()
