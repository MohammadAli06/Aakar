"""Real HTTP + SQLAlchemy integration against an isolated SQLite database."""
import os
import tempfile
import unittest
from io import BytesIO
from pathlib import Path
from PIL import Image
from unittest.mock import patch
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker

_test_root = Path(__file__).resolve().parent
_directory = tempfile.TemporaryDirectory(prefix='runtime-', dir=_test_root)
os.environ.update(DEBUG='false', ENVIRONMENT='development', ENABLE_DEMO_WORKSPACE='true', DATABASE_URL='sqlite+aiosqlite:///' + _directory.name.replace('\\', '/') + '/workspace.db', WORKSPACE_DEMO_TOKEN='test-mobile-only', ADMIN_ACCESS_TOKEN='test-admin-only')
from fastapi.testclient import TestClient
from main import create_app
from app.core.config import settings
from app.core.database import get_db


class WorkspaceApiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Explicit fixtures work regardless of which API test imports settings first.
        engine = create_async_engine(os.environ['DATABASE_URL'])
        sessions = async_sessionmaker(engine, expire_on_commit=False)
        async def database():
            async with sessions() as session:
                yield session
        cls.patches = [patch('main.engine', engine),
                       patch.object(settings, 'ENABLE_DEMO_WORKSPACE', True),
                       patch.object(settings, 'ENVIRONMENT', 'development'),
                       patch.object(settings, 'WORKSPACE_DEMO_TOKEN', 'test-mobile-only'),
                       patch.object(settings, 'ADMIN_ACCESS_TOKEN', 'test-admin-only'),
                       patch.object(settings, 'LLM_API_KEY', None)]
        for p in cls.patches:
            p.start()
        app = create_app()
        app.dependency_overrides[get_db] = database
        cls.client = TestClient(app)
        cls.client.__enter__()

    @classmethod
    def tearDownClass(cls):
        cls.client.__exit__(None, None, None)
        for p in reversed(cls.patches):
            p.stop()
        Path(_directory.name).resolve().relative_to(_test_root)
        _directory.cleanup()

    def test_auth_admin_and_revision_conflict(self):
        base = '/api/v1/workspace'
        mobile = {'Authorization': 'Bearer test-mobile-only'}
        admin = {'Authorization': 'Bearer test-admin-only'}
        self.assertEqual(self.client.get(base).status_code, 401)
        self.assertEqual(self.client.get(base + '/admin-access', headers=mobile).status_code, 403)
        self.assertEqual(self.client.get(base + '/admin-access', headers=admin).status_code, 200)
        state = self.client.get(base, headers=mobile).json()
        command = dict(action='verify', input=dict(id='buyer', status='verified'), role='admin', actor='admin', version=state['version'])
        self.assertEqual(self.client.post(base + '/actions', headers=mobile, json=command).status_code, 403)
        response = self.client.post(base + '/actions', headers=admin, json=command)
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()['profiles'][0]['verification'], 'verified')
        self.assertEqual(self.client.post(base + '/actions', headers=admin, json=command).status_code, 409)
        fresh = self.client.get(base, headers=mobile).json()
        bad = dict(action='product', input=dict(id='basket', title='Overwrite'), role='artisan', actor='sakhi', version=fresh['version'])
        self.assertEqual(self.client.post(base + '/actions', headers=mobile, json=bad).status_code, 422)
        self.assertEqual(self.client.get(base, headers=mobile).json(), fresh)

    def test_assistant_fallback_and_admin_page(self):
        response = self.client.post('/api/v1/workspace/assist', headers={'Authorization': 'Bearer test-mobile-only'}, json=dict(task='requirement', text='500 bamboo baskets in 30 days', language='en'))
        self.assertEqual(response.status_code, 200)
        self.assertFalse(response.json()['ai'])
        self.assertEqual(response.json()['fields']['quantity'], 500)
        self.assertEqual(self.client.get('/api/v1/workspace/admin').status_code, 200)

    def test_media_requires_token_and_valid_image(self):
        base = '/api/v1/workspace/media'
        headers = {'Authorization': 'Bearer test-mobile-only'}
        self.assertEqual(self.client.post(base, headers=headers, files={'file': ('bad.jpg', b'not-image', 'image/jpeg')}).status_code, 422)
        image = BytesIO()
        Image.new('RGB', (20, 20), '#af945e').save(image, format='PNG')
        response = self.client.post(base, headers=headers, files={'file': ('photo.png', image.getvalue(), 'image/png')})
        self.assertEqual(response.status_code, 200)
        path = response.json()['path']
        self.assertEqual(self.client.get(path).status_code, 401)
        self.assertEqual(self.client.get(path, headers=headers).status_code, 200)
        # Clean up only the exact test-generated file.
        from app.routers.workspace import MEDIA
        (MEDIA / path.rsplit('/', 1)[-1]).unlink()


if __name__ == '__main__':
    unittest.main()
