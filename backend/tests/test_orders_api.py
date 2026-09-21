"""Order fulfilment: the artisan's 14-step flow shared with the buyer.

The order row is created by accepting a quotation; every later step is a PATCH
on `/api/v1/orders/{id}` that rewrites the stored payload. These tests drive the
whole artisan flow and read the result back as the buyer, so a step that only
updated the artisan's own copy would fail.
"""
import os
os.environ['DEBUG'] = 'false'

from contextlib import asynccontextmanager
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker

from app.core.database import Base, get_db
from app.core.config import settings
from app.routers import auth, inquiries, orders, products

PHONES = {
    'raj': '+919876543210',
    'kim': '+919876543211',
    'dev': '+919876543212',
}


async def identity(token):
    if token not in PHONES:
        raise ValueError('Invalid token')
    return {'uid': token, 'phone_number': PHONES[token]}


READY_PRODUCT = {
    'category': 'Baskets',
    'title': 'Handmade Bamboo Basket',
    'description': 'Handwoven bamboo storage basket with a fitted lid.',
    'craft': 'Bamboo & cane',
    'material': 'Bamboo',
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
    'approved': True,
}

INQUIRY = {
    'quantity': 50,
    'lead_days': 25,
    'location': 'Mumbai, Maharashtra',
    'budget': 380,
}

QUOTE = {
    'unit_price': 400,
    'quantity': 50,
    'lead_days': 20,
    'inspection_hours': 48,
    'delivery_terms': 'Artisan packs and ships directly',
    'location': 'Mumbai, Maharashtra',
    'middle_trigger': 'dispatch',
    'milestones': [
        {'trigger': 'advance', 'percent': 30},
        {'trigger': 'dispatch', 'percent': 50},
        {'trigger': 'delivery', 'percent': 20},
    ],
}


class OrderFlowTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='order-runtime-')
        root = Path(self.directory.name)
        self.engine = create_async_engine(
            'sqlite+aiosqlite:///' + (root / 'orders.db').as_posix())
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
        app.include_router(inquiries.router, prefix='/api/v1/inquiries')
        app.include_router(orders.router, prefix='/api/v1/orders')
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
        self.inquiries = '/api/v1/inquiries'
        self.orders = '/api/v1/orders'
        self.raj = {'Authorization': 'Bearer raj'}
        self.kim = {'Authorization': 'Bearer kim'}
        self.dev = {'Authorization': 'Bearer dev'}

    def tearDown(self):
        self.client.__exit__(None, None, None)
        for p in reversed(self.patches):
            p.stop()
        self.directory.cleanup()

    def register(self, headers, role):
        response = self.client.post(self.auth + '/verify-token?role=' + role,
                                    headers=headers)
        self.assertEqual(response.status_code, 200, response.text)

    def patch(self, path, headers, body, expect=200):
        response = self.client.patch(f'{self.orders}/{path}', headers=headers,
                                     json=body)
        self.assertEqual(response.status_code, expect, response.text)
        return response.json() if expect == 200 else response

    def accepted_order(self):
        """Drive a buyer inquiry through quotation to an accepted order."""
        self.register(self.raj, 'artisan')
        self.register(self.kim, 'buyer')
        product = self.client.post('/api/v1/products/', headers=self.raj,
                                   json=READY_PRODUCT).json()
        self.client.post(f"/api/v1/products/{product['id']}/publish",
                         headers=self.raj)
        inquiry = self.client.post(self.inquiries + '/', headers=self.kim,
                                   json={**INQUIRY, 'product_id': product['id']}).json()
        self.client.post(f"{self.inquiries}/{inquiry['id']}/capacity",
                         headers=self.raj,
                         json={'status': 'confirmed', 'quantity': 60, 'lead_days': 20})
        quoted = self.client.post(f"{self.inquiries}/{inquiry['id']}/quote",
                                  headers=self.raj, json=QUOTE).json()
        accepted = self.client.post(f"{self.inquiries}/{inquiry['id']}/accept",
                                    headers=self.kim,
                                    json={'quote_id': quoted['quotes'][-1]['id']}).json()
        return accepted['order_id']

    def test_artisan_flow_reaches_the_buyer_step_by_step(self):
        order_id = self.accepted_order()

        accepted = self.patch(f'{order_id}/accept', self.raj, {'accepted': True})
        self.assertEqual(accepted['status'], 'artisan_accepted')
        self.assertTrue(accepted['artisan_accepted'])

        planned = self.patch(f'{order_id}/production-plan', self.raj, {
            'prod_start_date': '2026-10-01',
            'prod_completion_date': '2026-10-20',
            'daily_target': '5 baskets',
        })
        self.assertEqual(planned['status'], 'in_production')
        self.assertEqual(planned['prod_start_date'], '2026-10-01')
        self.assertEqual(planned['daily_target'], '5 baskets')

        progress = self.patch(f'{order_id}/production-progress', self.raj, {
            'milestone': 'material_ready',
            'completed_units': 10,
            'note': 'Cane seasoned',
        })
        self.assertIn('material_ready', progress['production_milestones'])
        self.assertEqual(progress['completed_units'], 10)
        self.assertEqual(progress['progress_proofs'][-1]['note'], 'Cane seasoned')

        complete = self.patch(f'{order_id}/production-complete', self.raj,
                              {'completed_units': 50})
        self.assertEqual(complete['status'], 'ready')
        self.assertEqual(complete['production'], 'ready')
        self.assertIn('production_complete', complete['production_milestones'])

        packed = self.patch(f'{order_id}/packaging', self.raj, {
            'packaging_type': 'Carton',
            'num_boxes': 5,
            'total_weight': '12 kg',
        })
        self.assertTrue(packed['packaging_done'])
        self.assertEqual(packed['num_boxes'], 5)

        dispatched = self.patch(f'{order_id}/dispatch', self.raj, {
            'courier': 'India Post',
            'awb_number': 'EE123456789IN',
            'dispatch_date': '2026-10-21',
            'estimated_delivery': '2026-10-26',
        })
        self.assertEqual(dispatched['status'], 'dispatched')
        self.assertEqual(dispatched['shipping']['awb_number'], 'EE123456789IN')

        in_transit = self.patch(f'{order_id}/delivery-status', self.raj,
                                {'status': 'in_transit'})
        self.assertEqual(in_transit['status'], 'in_transit')
        self.assertEqual(in_transit['shipment'], 'in_transit')

        # The buyer reads the same row, with every step visible.
        seen = self.client.get(f'{self.orders}/{order_id}', headers=self.kim).json()
        self.assertEqual(seen['status'], 'in_transit')
        self.assertEqual(seen['prod_start_date'], '2026-10-01')
        self.assertTrue(seen['packaging_done'])
        self.assertEqual(seen['shipping']['courier'], 'India Post')
        self.assertIn('production_complete', seen['production_milestones'])
        self.assertTrue(any(e['title'].startswith('Order dispatched')
                            for e in seen['events']))

        delivered = self.patch(f'{order_id}/delivery-status', self.kim,
                               {'status': 'delivered'})
        self.assertEqual(delivered['status'], 'delivered')
        self.assertIsNotNone(delivered['delivered_at'])

    def test_buyer_and_strangers_cannot_drive_the_artisan_steps(self):
        order_id = self.accepted_order()
        self.register(self.dev, 'artisan')

        refused = self.client.patch(f'{self.orders}/{order_id}/accept',
                                    headers=self.kim, json={'accepted': True})
        self.assertEqual(refused.status_code, 403)
        stranger = self.client.patch(f'{self.orders}/{order_id}/accept',
                                     headers=self.dev, json={'accepted': True})
        self.assertEqual(stranger.status_code, 403)
        self.assertEqual(self.client.get(f'{self.orders}/{order_id}',
                                         headers=self.dev).status_code, 403)

    def test_steps_are_validated(self):
        order_id = self.accepted_order()

        # Packaging cannot precede production.
        self.patch(f'{order_id}/packaging', self.raj,
                   {'packaging_type': 'Carton', 'num_boxes': 1}, expect=422)
        # A production plan needs the order accepted first.
        self.patch(f'{order_id}/production-plan', self.raj,
                   {'prod_start_date': '2026-10-01',
                    'prod_completion_date': '2026-10-20'}, expect=422)

        self.patch(f'{order_id}/accept', self.raj, {'accepted': True})
        self.patch(f'{order_id}/production-progress', self.raj,
                   {'milestone': 'not_a_milestone', 'completed_units': 1},
                   expect=422)
        self.patch(f'{order_id}/delivery-status', self.raj,
                   {'status': 'teleported'}, expect=422)

    def test_settlement_persists_for_the_buyer(self):
        order_id = self.accepted_order()

        # Drive the order to delivered.
        self.patch(f'{order_id}/accept', self.raj, {'accepted': True})
        self.patch(f'{order_id}/production-plan', self.raj, {
            'prod_start_date': '2026-10-01',
            'prod_completion_date': '2026-10-20',
        })
        self.patch(f'{order_id}/production-complete', self.raj,
                   {'completed_units': 50})
        self.patch(f'{order_id}/packaging', self.raj,
                   {'packaging_type': 'Carton', 'num_boxes': 5})
        self.patch(f'{order_id}/dispatch', self.raj, {
            'courier': 'India Post',
            'awb_number': 'EE123456789IN',
            'dispatch_date': '2026-10-21',
            'estimated_delivery': '2026-10-26',
        })
        self.patch(f'{order_id}/delivery-status', self.kim, {'status': 'delivered'})

        seen = self.client.get(f'{self.orders}/{order_id}', headers=self.kim).json()
        # The inspection window is stamped on receipt, not left to the client.
        self.assertIsNotNone(seen['inspection_deadline'])
        milestones = {m['trigger']: m for m in seen['milestones']}

        # Final settlement is refused before the buyer has inspected.
        blocked = self.client.patch(f'{self.orders}/{order_id}/pay', headers=self.kim,
                                    json={'milestone_id': milestones['delivery']['id']})
        self.assertEqual(blocked.status_code, 422)

        # The artisan cannot record the buyer's payment.
        refused = self.client.patch(f'{self.orders}/{order_id}/pay', headers=self.raj,
                                    json={'milestone_id': milestones['advance']['id']})
        self.assertEqual(refused.status_code, 403)

        advance = self.patch(f'{order_id}/pay', self.kim,
                             {'milestone_id': milestones['advance']['id'],
                              'reference': 'UPI demo'})
        paid = {m['id']: m for m in advance['milestones']}
        self.assertEqual(paid[milestones['advance']['id']]['status'], 'confirmed')
        self.assertEqual(paid[milestones['advance']['id']]['reference'], 'UPI demo')
        self.assertEqual(paid[milestones['advance']['id']]['mode'], 'demo')

        # Completing needs every milestone settled and an accepted inspection.
        self.patch(f'{order_id}/inspection', self.kim,
                   {'quantity': 50, 'note': 'All good'})
        self.patch(f'{order_id}/pay', self.kim,
                   {'milestone_id': milestones['dispatch']['id']})
        self.patch(f'{order_id}/pay', self.kim,
                   {'milestone_id': milestones['delivery']['id']})
        done = self.patch(f'{order_id}/complete', self.kim, {})
        self.assertEqual(done['status'], 'completed')

        # The buyer reads the same settled record back.
        again = self.client.get(f'{self.orders}/{order_id}', headers=self.kim).json()
        self.assertEqual(again['status'], 'completed')
        self.assertEqual(again['inspection'], 'accepted')
        self.assertTrue(all(m['status'] == 'confirmed' for m in again['milestones']))

    def test_inspection_rejects_a_quantity_mismatch(self):
        order_id = self.accepted_order()
        self.patch(f'{order_id}/accept', self.raj, {'accepted': True})
        self.patch(f'{order_id}/production-complete', self.raj,
                   {'completed_units': 50})
        self.patch(f'{order_id}/dispatch', self.raj, {
            'courier': 'India Post', 'awb_number': 'EE1',
            'dispatch_date': '2026-10-21', 'estimated_delivery': '2026-10-26',
        })
        self.patch(f'{order_id}/delivery-status', self.kim, {'status': 'delivered'})

        # Inspecting before receipt, or with the wrong count, is refused.
        self.patch(f'{order_id}/inspection', self.kim, {'quantity': 40}, expect=422)

    def test_declining_an_order_closes_it(self):
        order_id = self.accepted_order()
        declined = self.patch(f'{order_id}/accept', self.raj, {'accepted': False})
        self.assertEqual(declined['status'], 'cancelled')
        self.assertFalse(declined['artisan_accepted'])


if __name__ == '__main__':
    unittest.main()
