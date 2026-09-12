"""HTTP account onboarding with verified-identity stubs, isolated DB and media."""
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
from sqlalchemy import event

from app.core.database import Base, get_db
from app.core.config import settings
from app.routers import auth, account_verification


async def identity(token):
    if token not in ('alice', 'bob'):
        raise ValueError('Invalid token')
    return {'uid': token, 'phone_number': '+919876543210' if token == 'alice' else '+919876543211'}


class AccountApiTests(unittest.TestCase):
    def setUp(self):
        # The system temp directory, not the repo: writing inside backend/tests
        # is denied on Windows and the cleanup fails there too.
        self.directory = tempfile.TemporaryDirectory(prefix='account-runtime-')
        root = Path(self.directory.name)
        self.engine = create_async_engine('sqlite+aiosqlite:///' + (root / 'accounts.db').as_posix())
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
        app.dependency_overrides[get_db] = db
        self.patches = [patch('app.routers.auth.verify_firebase_token', identity),
                        patch('app.core.auth_deps.verify_firebase_token', identity),
                        patch('app.routers.auth.set_role_claim'),
                        patch.object(account_verification, 'MEDIA', root / 'uploads'),
                        patch.object(settings, 'ADMIN_ACCESS_TOKEN', 'reviewer')]
        for p in self.patches: p.start()
        self.client = TestClient(app).__enter__()
        self.base = '/api/v1/auth'
        self.alice = {'Authorization': 'Bearer alice'}
        self.bob = {'Authorization': 'Bearer bob'}
        self.admin = {'Authorization': 'Bearer reviewer'}

    def tearDown(self):
        self.client.__exit__(None, None, None)
        for p in reversed(self.patches): p.stop()
        self.directory.cleanup()

    def register(self, headers, role):
        response = self.client.post(self.base + '/verify-token?role=' + role, headers=headers)
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def upload(self, kind, headers):
        output = BytesIO()
        Image.new('RGB', (24, 24), 'green').save(output, 'PNG')
        response = self.client.post(self.base + '/verification/evidence', headers=headers,
            data={'kind': kind}, files={'file': ('image.png', output.getvalue(), 'image/png')})
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def test_identity_profile_and_role_isolation(self):
        self.assertEqual(self.client.get(self.base + '/me').status_code, 401)
        self.assertEqual(self.client.get(self.base + '/me', headers=self.alice).status_code, 404)
        first = self.register(self.alice, 'artisan')
        self.assertEqual(self.register(self.alice, 'buyer')['id'], first['id'])
        self.assertEqual(self.client.put(self.base + '/buyer-profile', headers=self.alice, json={'name': 'Alice'}).status_code, 403)
        self.assertEqual(self.client.put(self.base + '/artisan-profile', headers=self.alice, json={'name': '  '}).status_code, 422)
        response = self.client.put(self.base + '/artisan-profile', headers=self.alice, json={'name': ' Alice ', 'state': 'Gujarat', 'district': 'Kutch', 'craft_category': 'weaving'})
        self.assertEqual(response.json()['name'], 'Alice')
        self.assertEqual(self.client.put(self.base + '/role', headers=self.alice, json={'role': 'buyer'}).status_code, 409)
        self.assertEqual(self.client.put(self.base + '/buyer-profile', headers=self.alice, json={'business_name': 'Alice Crafts', 'state': 'Gujarat'}).status_code, 403)
        self.assertEqual(self.client.put(self.base + '/role', headers=self.alice, json={'role': 'artisan'}).status_code, 200)
        self.assertEqual(self.register(self.alice, 'buyer')['role'], 'artisan')
        self.assertEqual(self.client.get(self.base + '/me', headers=self.alice).json()['profile']['craft_category'], 'weaving')
        self.register(self.bob, 'buyer')
        self.assertEqual(self.client.put(self.base + '/role', headers=self.bob, json={'role': 'artisan'}).status_code, 409)
        self.assertIsNone(self.client.get(self.base + '/me', headers=self.bob).json()['name'])

    def test_existing_login_and_opposite_role_requests_never_write_to_database(self):
        for headers, role, opposite in ((self.alice, 'artisan', 'buyer'), (self.bob, 'buyer', 'artisan')):
            self.register(headers, role)
            statements = []
            def record_sql(conn, cursor, statement, parameters, context, executemany):
                statements.append(statement.lstrip().split(None, 1)[0].upper())
            event.listen(self.engine.sync_engine, 'before_cursor_execute', record_sql)
            try:
                for _ in range(2):
                    response = self.client.get(self.base + '/me', headers=headers)
                    self.assertEqual(response.status_code, 200)
                    self.assertEqual(response.json()['role'], role)
                    self.assertEqual(self.register(headers, opposite)['role'], role)
                self.assertEqual(self.client.put(self.base + '/role', headers=headers, json={'role': opposite}).status_code, 409)
                self.assertEqual(self.client.put(self.base + '/' + opposite + '-profile', headers=headers, json={'name': 'Not allowed'}).status_code, 403)
                self.assertTrue(statements)
                self.assertEqual(set(statements), {'SELECT'}, statements)
            finally:
                event.remove(self.engine.sync_engine, 'before_cursor_execute', record_sql)

    def test_private_evidence_submit_and_manual_review(self):
        self.register(self.alice, 'artisan')
        self.register(self.bob, 'buyer')
        self.client.put(self.base + '/artisan-profile', headers=self.alice, json={'name': 'Alice', 'state': 'Gujarat'})
        self.assertEqual(self.client.post(self.base + '/verification/submit', headers=self.alice, json={'consent': True}).status_code, 422)
        for kind in ('identity', 'craft', 'selfie'):
            data = self.upload(kind, self.alice)
        url = data['evidence']['identity']
        self.assertEqual(self.client.get(url).status_code, 401)
        self.assertEqual(self.client.get(url, headers=self.bob).status_code, 404)
        self.assertEqual(self.client.get(url, headers=self.alice).status_code, 200)
        self.assertEqual(self.client.post(self.base + '/verification/submit', headers=self.alice, json={'consent': False}).status_code, 422)
        submitted = self.client.post(self.base + '/verification/submit', headers=self.alice, json={'consent': True}).json()
        self.assertEqual(submitted['status'], 'pending')
        self.assertFalse(self.client.get(self.base + '/me', headers=self.alice).json()['profile']['is_verified'])
        review_url = self.base + '/verification-admin/' + submitted['id']
        self.assertEqual(self.client.put(review_url, headers=self.alice, json={'status': 'verified', 'note': 'Reviewed'}).status_code, 403)
        self.assertEqual(self.client.put(review_url, headers=self.admin, json={'status': 'verified', 'note': 'Reviewed'}).status_code, 200)
        self.assertTrue(self.client.get(self.base + '/me', headers=self.alice).json()['profile']['is_verified'])
        self.client.put(self.base + '/artisan-profile', headers=self.alice, json={'state': 'Rajasthan'})
        self.assertFalse(self.client.get(self.base + '/me', headers=self.alice).json()['profile']['is_verified'])
        self.assertEqual(self.client.get(self.base + '/verification', headers=self.alice).json()['status'], 'needs_correction')
        self.assertEqual(self.client.get(self.base + '/verification', headers=self.bob).json()['status'], 'not_started')

    def test_upload_validation(self):
        self.register(self.bob, 'buyer')
        endpoint = self.base + '/verification/evidence'
        for kind in ['identity', 'business']:
            response = self.client.post(endpoint, headers=self.bob, data={'kind': kind}, files={'file': ('bad.jpg', b'not an image', 'image/jpeg')})
            self.assertEqual(response.status_code, 422)


if __name__ == '__main__':
    unittest.main()
