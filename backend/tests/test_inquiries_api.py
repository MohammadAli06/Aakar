"""Inquiries and quotations: one account-scoped record both participants read."""
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
from app.routers import auth, inquiries, notifications, orders, products

PHONES = {
    'raj': '+919876543210',
    'kim': '+919876543211',
    'dev': '+919876543212',
    'ana': '+919876543213',
}


async def identity(token):
    if token not in PHONES:
        raise ValueError('Invalid token')
    return {'uid': token, 'phone_number': PHONES[token]}


async def fake_assist(task, text, language):
    """Deterministic stand-in for the translation assistant."""
    return {'fields': {'translation': f'[{language}] {text}'}, 'provenance': 'translated'}


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
    'customization': 'Logo on the lid',
    'specifications': 'Food-safe natural finish',
    'packaging': 'Individual cartons',
    'sample_required': False,
}

MILESTONES = [
    {'trigger': 'advance', 'percent': 30},
    {'trigger': 'dispatch', 'percent': 50},
    {'trigger': 'delivery', 'percent': 20},
]

QUOTE = {
    'unit_price': 400,
    'quantity': 50,
    'lead_days': 20,
    'inspection_hours': 48,
    'delivery_terms': 'Artisan packs and ships directly',
    'location': 'Mumbai, Maharashtra',
    'packaging_cost': 500,
    'delivery_cost': 800,
    'middle_trigger': 'dispatch',
    'milestones': MILESTONES,
}


class InquiryApiTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='inquiry-runtime-')
        root = Path(self.directory.name)
        self.engine = create_async_engine(
            'sqlite+aiosqlite:///' + (root / 'inquiries.db').as_posix())
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
        app.include_router(notifications.router, prefix='/api/v1/notifications')
        app.dependency_overrides[get_db] = db
        self.patches = [patch('app.routers.auth.verify_firebase_token', identity),
                        patch('app.core.auth_deps.verify_firebase_token', identity),
                        patch('app.routers.auth.set_role_claim'),
                        patch.object(products, 'MEDIA', root / 'uploads' / 'products'),
                        patch.object(inquiries, 'VOICE_MEDIA',
                                     root / 'uploads' / 'inquiry_voice'),
                        patch('app.routers.inquiries.assist', fake_assist),
                        patch.object(settings, 'ADMIN_ACCESS_TOKEN', 'reviewer')]
        for p in self.patches:
            p.start()
        self.client = TestClient(app).__enter__()
        self.auth = '/api/v1/auth'
        self.products = '/api/v1/products'
        self.base = '/api/v1/inquiries'
        self.alerts = '/api/v1/notifications/'
        self.orders = '/api/v1/orders'
        self.raj = {'Authorization': 'Bearer raj'}
        self.kim = {'Authorization': 'Bearer kim'}
        self.dev = {'Authorization': 'Bearer dev'}
        self.ana = {'Authorization': 'Bearer ana'}

    def tearDown(self):
        self.client.__exit__(None, None, None)
        for p in reversed(self.patches):
            p.stop()
        self.directory.cleanup()

    def register(self, headers, role, name=None, language=None):
        response = self.client.post(self.auth + '/verify-token?role=' + role,
                                    headers=headers)
        self.assertEqual(response.status_code, 200, response.text)
        if role == 'buyer':
            body = {'name': name or 'Buyer', 'state': 'Maharashtra'}
            if language:
                body['language_pref'] = language
            updated = self.client.put(self.auth + '/buyer-profile', headers=headers,
                                      json=body)
            self.assertEqual(updated.status_code, 200, updated.text)
        elif language:
            updated = self.client.put(self.auth + '/artisan-profile', headers=headers,
                                      json={'language_pref': language})
            self.assertEqual(updated.status_code, 200, updated.text)

    def publish(self, headers, **overrides):
        response = self.client.post(self.products + '/', headers=headers,
                                    json={**READY_PRODUCT, **overrides})
        self.assertEqual(response.status_code, 200, response.text)
        product = response.json()
        published = self.client.post(f"{self.products}/{product['id']}/publish",
                                     headers=headers)
        self.assertEqual(published.status_code, 200, published.text)
        return published.json()

    def inquire(self, headers, product, **overrides):
        response = self.client.post(self.base + '/', headers=headers,
                                    json={**INQUIRY, 'product_id': product['id'],
                                          **overrides})
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def confirm_capacity(self, headers, inquiry, status='confirmed', quantity=60):
        response = self.client.post(f"{self.base}/{inquiry['id']}/capacity",
                                    headers=headers,
                                    json={'status': status, 'quantity': quantity,
                                          'lead_days': 20})
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def quote(self, headers, inquiry, **overrides):
        response = self.client.post(f"{self.base}/{inquiry['id']}/quote",
                                    headers=headers,
                                    json={**QUOTE, **overrides})
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def ready(self):
        """A published product plus a buyer's inquiry on it."""
        self.register(self.raj, 'artisan')
        self.register(self.kim, 'buyer', name='Kim')
        product = self.publish(self.raj)
        return product, self.inquire(self.kim, product)

    def test_buyer_inquiry_reaches_the_artisan(self):
        _product, inquiry = self.ready()
        self.assertEqual(inquiry['status'], 'sent')
        self.assertEqual(inquiry['capacity_status'], 'pending')

        # The artisan the product belongs to sees it, with the buyer named.
        listed = self.client.get(self.base + '/', headers=self.raj).json()
        self.assertEqual([row['id'] for row in listed], [inquiry['id']])
        self.assertEqual(listed[0]['product_title'], READY_PRODUCT['title'])
        self.assertEqual(listed[0]['buyer_name'], 'Kim')

        # The buyer sees the same record.
        mine = self.client.get(self.base + '/', headers=self.kim).json()
        self.assertEqual([row['id'] for row in mine], [inquiry['id']])
        detail = self.client.get(f"{self.base}/{inquiry['id']}", headers=self.raj).json()
        self.assertEqual(detail['quantity'], 50)

    def test_inquiry_is_scoped_to_its_participants(self):
        _product, inquiry = self.ready()
        self.register(self.dev, 'artisan')
        self.register(self.ana, 'buyer')
        self.assertEqual(self.client.get(self.base + '/', headers=self.dev).json(), [])
        self.assertEqual(self.client.get(self.base + '/', headers=self.ana).json(), [])
        self.assertEqual(self.client.get(f"{self.base}/{inquiry['id']}",
                                         headers=self.dev).status_code, 403)
        self.assertEqual(self.client.get(f"{self.base}/{inquiry['id']}",
                                         headers=self.ana).status_code, 403)

    def test_unpublished_or_paused_products_refuse_inquiries(self):
        self.register(self.raj, 'artisan')
        self.register(self.kim, 'buyer')
        created = self.client.post(self.products + '/', headers=self.raj,
                                   json=READY_PRODUCT).json()
        draft = self.client.post(self.base + '/', headers=self.kim,
                                 json={**INQUIRY, 'product_id': created['id']})
        self.assertEqual(draft.status_code, 422)
        self.assertIn('not published', draft.json()['detail'])

        paused = self.publish(self.raj, available=False)
        response = self.client.post(self.base + '/', headers=self.kim,
                                    json={**INQUIRY, 'product_id': paused['id']})
        self.assertEqual(response.status_code, 422)
        self.assertIn('not taking orders', response.json()['detail'])

        product = self.publish(self.raj)
        below = self.client.post(self.base + '/', headers=self.kim,
                                 json={**INQUIRY, 'product_id': product['id'],
                                       'quantity': 10})
        self.assertEqual(below.status_code, 422)
        self.assertIn('MOQ', below.json()['detail'])

    def test_only_buyers_open_an_inquiry(self):
        self.register(self.raj, 'artisan')
        product = self.publish(self.raj)
        response = self.client.post(self.base + '/', headers=self.raj,
                                    json={**INQUIRY, 'product_id': product['id']})
        self.assertEqual(response.status_code, 403)

    def test_capacity_then_quotation_then_acceptance_builds_one_order(self):
        product, inquiry = self.ready()

        # The buyer cannot answer their own capacity question.
        response = self.client.post(f"{self.base}/{inquiry['id']}/capacity",
                                    headers=self.kim,
                                    json={'status': 'confirmed', 'quantity': 60,
                                          'lead_days': 20})
        self.assertEqual(response.status_code, 403)

        # A quotation before capacity is refused.
        early = self.client.post(f"{self.base}/{inquiry['id']}/quote",
                                 headers=self.raj, json=QUOTE)
        self.assertEqual(early.status_code, 422)
        self.assertIn('capacity', early.json()['detail'])

        self.confirm_capacity(self.raj, inquiry)
        quoted = self.quote(self.raj, inquiry)
        self.assertEqual(quoted['status'], 'negotiating')
        quote = quoted['quotes'][-1]
        self.assertEqual(quote['version'], 1)
        self.assertEqual(quote['author'], 'artisan')
        self.assertEqual(quote['total'], 400 * 50 + 1300)

        # The artisan cannot accept their own quotation.
        own = self.client.post(f"{self.base}/{inquiry['id']}/accept", headers=self.raj,
                               json={'quote_id': quote['id']})
        self.assertEqual(own.status_code, 422)

        accepted = self.client.post(f"{self.base}/{inquiry['id']}/accept",
                                    headers=self.kim, json={'quote_id': quote['id']})
        self.assertEqual(accepted.status_code, 200, accepted.text)
        body = accepted.json()
        self.assertEqual(body['status'], 'ordered')
        self.assertEqual(body['quotes'][-1]['status'], 'accepted')
        self.assertTrue(body['order_id'])

        # Both accounts read the same order against the advertised capacity.
        for headers in (self.kim, self.raj):
            rows = self.client.get(self.orders + '/', headers=headers).json()
            self.assertEqual([row['id'] for row in rows], [body['order_id']])
            self.assertEqual(rows[0]['inquiry_id'], inquiry['id'])
            self.assertEqual(rows[0]['product_id'], product['id'])
            self.assertEqual(rows[0]['payment_mode'], 'demo')
            self.assertEqual([m['percent'] for m in rows[0]['milestones']], [30, 50, 20])
        other = self.client.get(f"{self.orders}/{body['order_id']}",
                                headers=self.raj).json()
        self.assertEqual(other['status'], 'confirmed')

    def test_quotation_below_the_cost_floor_is_refused(self):
        _product, inquiry = self.ready()
        self.confirm_capacity(self.raj, inquiry)
        response = self.client.post(f"{self.base}/{inquiry['id']}/quote",
                                    headers=self.raj,
                                    json={**QUOTE, 'unit_price': 100})
        self.assertEqual(response.status_code, 422)
        self.assertIn('cost floor', response.json()['detail'])

        bad = self.client.post(f"{self.base}/{inquiry['id']}/quote", headers=self.raj,
                               json={**QUOTE, 'milestones': [
                                   {'trigger': 'advance', 'percent': 30},
                                   {'trigger': 'dispatch', 'percent': 50}]})
        self.assertEqual(bad.status_code, 422)
        self.assertIn('100%', bad.json()['detail'])

    def test_conversation_and_rejected_quote_stay_on_the_shared_record(self):
        self.register(self.raj, 'artisan', language='hi')
        self.register(self.kim, 'buyer', name='Kim', language='en')
        product = self.publish(self.raj)
        inquiry = self.inquire(self.kim, product)
        self.confirm_capacity(self.raj, inquiry)
        self.quote(self.raj, inquiry)

        sent = self.client.post(f"{self.base}/{inquiry['id']}/messages", headers=self.kim,
                                json={'text': 'Can the colour change?',
                                      'translation': 'क्या रंग बदल सकते हैं?',
                                      'target_language': 'hi'})
        self.assertEqual(sent.status_code, 200, sent.text)
        self.assertEqual(len(sent.json()['messages']), 1)

        rejected = self.client.post(f"{self.base}/{inquiry['id']}/reject", headers=self.kim)
        self.assertEqual(rejected.status_code, 200, rejected.text)
        self.assertEqual(rejected.json()['quotes'][-1]['status'], 'rejected')

        # The artisan reads the same message, its reviewed translation and the
        # rejection. The buyer's own words are untouched.
        seen = self.client.get(f"{self.base}/{inquiry['id']}", headers=self.raj).json()
        self.assertEqual(seen['messages'][-1]['text'], 'Can the colour change?')
        self.assertEqual(seen['messages'][-1]['translation'], 'क्या रंग बदल सकते हैं?')
        self.assertEqual(seen['messages'][-1]['role'], 'buyer')
        self.assertEqual(seen['messages'][-1]['source_language'], 'en')
        self.assertEqual(seen['messages'][-1]['target_language'], 'hi')
        self.assertEqual(seen['messages'][-1]['provenance'], 'participant-reviewed')
        self.assertEqual(seen['quotes'][-1]['status'], 'rejected')

    def test_only_a_matching_language_preview_is_kept(self):
        self.register(self.raj, 'artisan', language='hi')
        self.register(self.kim, 'buyer', name='Kim', language='en')
        product = self.publish(self.raj)
        inquiry = self.inquire(self.kim, product)

        # A leftover or wrong-target draft must never be stored as a translation.
        stale = self.client.post(f"{self.base}/{inquiry['id']}/messages", headers=self.kim,
                                 json={'text': 'Second note', 'translation': 'Rang badlein',
                                       'target_language': 'en'})
        self.assertEqual(stale.status_code, 200, stale.text)
        self.assertEqual(stale.json()['messages'][-1]['translation'], '')
        self.assertEqual(stale.json()['messages'][-1]['provenance'], 'original')

        # Participants who share a language never get a translation.
        self.client.put(self.auth + '/artisan-profile', headers=self.raj,
                        json={'language_pref': 'en'})
        same = self.client.post(f"{self.base}/{inquiry['id']}/messages", headers=self.kim,
                                json={'text': 'No translation needed',
                                      'translation': 'should be discarded'})
        self.assertEqual(same.json()['messages'][-1]['translation'], '')

    def test_bridge_previews_a_message_before_it_is_sent(self):
        self.register(self.raj, 'artisan', language='hi')
        self.register(self.kim, 'buyer', name='Kim', language='en')
        product = self.publish(self.raj)

        preview = self.client.post(self.base + '/preview', headers=self.kim,
                                   json={'text': 'Need 500 baskets', 'product_id': product['id']})
        self.assertEqual(preview.status_code, 200, preview.text)
        self.assertEqual(preview.json()['target_language'], 'hi')
        self.assertEqual(preview.json()['translation'], '[hi] Need 500 baskets')
        self.assertEqual(preview.json()['status'], 'review_required')
        self.assertEqual(preview.json()['source_language'], 'en')
        # The original is echoed back untouched for review.
        self.assertEqual(preview.json()['text'], 'Need 500 baskets')

        inside = self.client.post(f"{self.base}/preview", headers=self.raj,
                                  json={'text': 'Hello', 'product_id': product['id']})
        self.assertEqual(inside.status_code, 403)

    def test_inquiry_can_open_with_the_buyer_s_first_message(self):
        _product, _inquiry = self.ready()
        product = self.publish(self.raj)
        opened = self.client.post(self.base + '/', headers=self.kim,
                                  json={**INQUIRY, 'product_id': product['id'],
                                        'communication': {'text': 'Please share your best price'}})
        self.assertEqual(opened.status_code, 200, opened.text)
        self.assertEqual(opened.json()['messages'][-1]['text'],
                         'Please share your best price')
        self.assertEqual(opened.json()['messages'][-1]['role'], 'buyer')

    def test_request_change_reopens_the_quotation(self):
        _product, inquiry = self.ready()
        self.confirm_capacity(self.raj, inquiry)
        quoted = self.quote(self.raj, inquiry)
        quote = quoted['quotes'][-1]

        # The author cannot ask themselves to change their own quotation.
        own = self.client.post(f"{self.base}/{inquiry['id']}/request-change", headers=self.raj,
                               json={'text': 'Make it cheaper', 'quote_id': quote['id']})
        self.assertEqual(own.status_code, 422)

        asked = self.client.post(f"{self.base}/{inquiry['id']}/request-change", headers=self.kim,
                                 json={'text': 'Please use a darker shade',
                                       'quote_id': quote['id']})
        self.assertEqual(asked.status_code, 200, asked.text)
        body = asked.json()
        self.assertEqual(body['quotes'][-1]['status'], 'changes_requested')
        self.assertEqual(body['messages'][-1]['kind'], 'change_request')
        self.assertEqual(body['messages'][-1]['quote_id'], quote['id'])

        # The superseded proposal can no longer be accepted.
        late = self.client.post(f"{self.base}/{inquiry['id']}/accept", headers=self.kim,
                                json={'quote_id': quote['id']})
        self.assertEqual(late.status_code, 422)

        revised = self.quote(self.raj, inquiry)
        self.assertEqual(revised['quotes'][-1]['version'], 2)
        self.assertEqual(revised['quotes'][-1]['status'], 'proposed')
        self.assertEqual(revised['quotes'][0]['status'], 'changes_requested')

        accepted = self.client.post(f"{self.base}/{inquiry['id']}/accept", headers=self.kim,
                                    json={'quote_id': revised['quotes'][-1]['id']})
        self.assertEqual(accepted.status_code, 200, accepted.text)

    def test_capacity_change_supersedes_the_open_quotation(self):
        _product, inquiry = self.ready()
        self.confirm_capacity(self.raj, inquiry)
        quoted = self.quote(self.raj, inquiry)
        self.assertEqual(quoted['quotes'][-1]['status'], 'proposed')

        again = self.confirm_capacity(self.raj, inquiry, status='partial', quantity=40)
        self.assertEqual(again['quotes'][-1]['status'], 'superseded')
        stale = self.client.post(f"{self.base}/{inquiry['id']}/accept", headers=self.kim,
                                 json={'quote_id': quoted['quotes'][-1]['id']})
        self.assertEqual(stale.status_code, 422)

    def test_voice_note_round_trip_and_participant_scope(self):
        _product, inquiry = self.ready()
        audio = b'\x00\x00\x00\x20ftypM4A \x00\x00\x00\x08mdat' + b'\x00' * 40

        sent = self.client.post(f"{self.base}/{inquiry['id']}/voice", headers=self.kim,
                                files={'file': ('note.m4a', audio, 'audio/mp4')})
        self.assertEqual(sent.status_code, 200, sent.text)
        message = sent.json()['messages'][-1]
        self.assertEqual(message['kind'], 'voice')
        self.assertEqual(message['provenance'], 'Original voice note')
        self.assertRegex(message['voice'], r'^[a-f0-9]{32}\.m4a$')
        name = message['voice']

        heard = self.client.get(f"{self.base}/{inquiry['id']}/voice/{name}", headers=self.raj)
        self.assertEqual(heard.status_code, 200)
        self.assertEqual(heard.headers['content-type'], 'audio/mp4')
        self.assertEqual(heard.content, audio)

        # A stranger cannot download it, and a non-audio upload is refused.
        self.register(self.dev, 'artisan')
        self.assertEqual(self.client.get(f"{self.base}/{inquiry['id']}/voice/{name}",
                                         headers=self.dev).status_code, 403)
        bad = self.client.post(f"{self.base}/{inquiry['id']}/voice", headers=self.kim,
                               files={'file': ('note.m4a', b'not audio at all', 'audio/mp4')})
        self.assertEqual(bad.status_code, 422)

    def test_a_language_change_reaches_the_bridge(self):
        # Both accounts start on the same default, so nothing is translated.
        _product, inquiry = self.ready()
        self.assertEqual(inquiry['buyer_language'], inquiry['artisan_language'])
        before = self.client.post(f"{self.base}/{inquiry['id']}/messages", headers=self.kim,
                                  json={'text': 'Can the colour change?',
                                        'translation': 'रंग बदल सकते हैं?',
                                        'target_language': 'hi'})
        self.assertEqual(before.json()['messages'][-1]['translation'], '')

        # The buyer switches to English on their account and the artisan stays
        # on Hindi. The bridge must follow the accounts, not the device.
        changed = self.client.put(self.auth + '/buyer-profile', headers=self.kim,
                                  json={'language_pref': 'en'})
        self.assertEqual(changed.status_code, 200, changed.text)
        self.assertEqual(changed.json()['language_pref'], 'en')

        seen = self.client.get(f"{self.base}/{inquiry['id']}", headers=self.raj).json()
        self.assertEqual(seen['buyer_language'], 'en')
        self.assertEqual(seen['artisan_language'], 'hi')

        bridge = self.client.post(f"{self.base}/{inquiry['id']}/bridge", headers=self.kim,
                                  json={'text': 'Can the colour change?'})
        self.assertEqual(bridge.json()['status'], 'review_required')
        self.assertEqual(bridge.json()['source_language'], 'en')
        self.assertEqual(bridge.json()['target_language'], 'hi')
        self.assertEqual(bridge.json()['translation'], '[hi] Can the colour change?')

        after = self.client.post(f"{self.base}/{inquiry['id']}/messages", headers=self.kim,
                                 json={'text': 'Can the colour change?',
                                       'translation': 'रंग बदल सकते हैं?',
                                       'target_language': 'hi'})
        self.assertEqual(after.json()['messages'][-1]['translation'], 'रंग बदल सकते हैं?')
        self.assertEqual(after.json()['messages'][-1]['provenance'],
                         'participant-reviewed')

    def test_a_message_notifies_the_other_participant_only(self):
        _product, inquiry = self.ready()

        sent = self.client.post(f"{self.base}/{inquiry['id']}/messages",
                                headers=self.kim,
                                json={'text': 'Can you do 500 pieces?'})
        self.assertEqual(sent.status_code, 200, sent.text)

        # The other side is told, and the link opens that conversation.
        artisan_notes = self.client.get(self.alerts, headers=self.raj).json()
        self.assertEqual(len(artisan_notes), 1)
        self.assertEqual(artisan_notes[0]['link'],
                         f"inquiry/{inquiry['id']}?tab=chat")
        self.assertIn('New message', artisan_notes[0]['title'])
        self.assertEqual(artisan_notes[0]['role'], 'artisan')
        self.assertFalse(artisan_notes[0]['read'])

        # The sender is not notified about their own message.
        self.assertEqual(self.client.get(self.alerts, headers=self.kim).json(), [])

        # A reply notifies the buyer in turn.
        self.client.post(f"{self.base}/{inquiry['id']}/messages", headers=self.raj,
                         json={'text': 'Yes, 20 days'})
        buyer_notes = self.client.get(self.alerts, headers=self.kim).json()
        self.assertEqual(len(buyer_notes), 1)
        self.assertEqual(buyer_notes[0]['role'], 'buyer')

        # Marking read clears only the caller's rows.
        marked = self.client.post(f'{self.alerts}read', headers=self.kim).json()
        self.assertTrue(all(n['read'] for n in marked))
        self.assertFalse(
            self.client.get(self.alerts, headers=self.raj).json()[0]['read'])

    def test_a_voice_note_also_notifies(self):
        product, inquiry = self.ready()
        audio = b'\x00\x00\x00\x20ftypM4A \x00\x00\x00\x08mdat' + b'\x00' * 40

        sent = self.client.post(f"{self.base}/{inquiry['id']}/voice", headers=self.kim,
                                files={'file': ('note.m4a', audio, 'audio/mp4')})
        self.assertEqual(sent.status_code, 200, sent.text)

        notes = self.client.get(self.alerts, headers=self.raj).json()
        self.assertEqual(len(notes), 1)
        self.assertEqual(notes[0]['link'], f"inquiry/{inquiry['id']}?tab=chat")

    def test_sample_approval_gates_the_order(self):
        self.register(self.raj, 'artisan')
        self.register(self.kim, 'buyer')
        product = self.publish(self.raj)
        inquiry = self.inquire(self.kim, product, sample_required=True)
        self.assertEqual(inquiry['sample_status'], 'requested')

        self.confirm_capacity(self.raj, inquiry)
        quoted = self.quote(self.raj, inquiry)
        quote = quoted['quotes'][-1]

        blocked = self.client.post(f"{self.base}/{inquiry['id']}/accept", headers=self.kim,
                                   json={'quote_id': quote['id']})
        self.assertEqual(blocked.status_code, 422)
        self.assertIn('sample', blocked.json()['detail'])

        submitted = self.client.post(f"{self.base}/{inquiry['id']}/sample", headers=self.raj,
                                     json={'status': 'submitted',
                                           'evidence': '/api/v1/products/images/' + 'b' * 32 + '.jpg',
                                           'terms': 'One sample, buyer pays courier'})
        self.assertEqual(submitted.status_code, 200, submitted.text)
        self.assertEqual(submitted.json()['sample_status'], 'submitted')

        approved = self.client.post(f"{self.base}/{inquiry['id']}/sample", headers=self.kim,
                                    json={'status': 'approved'})
        self.assertEqual(approved.status_code, 200, approved.text)
        self.assertEqual(approved.json()['sample_status'], 'approved')

        accepted = self.client.post(f"{self.base}/{inquiry['id']}/accept", headers=self.kim,
                                    json={'quote_id': quote['id']})
        self.assertEqual(accepted.status_code, 200, accepted.text)
        self.assertEqual(accepted.json()['status'], 'ordered')


if __name__ == '__main__':
    unittest.main()
