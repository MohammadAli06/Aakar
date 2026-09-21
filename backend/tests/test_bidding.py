"""Bidding authorization, sealing, deadlines, allocation and persistent handoff."""
import os
os.environ['DEBUG'] = 'false'
import tempfile
import unittest
from pathlib import Path
from datetime import datetime, timedelta, timezone
from contextlib import asynccontextmanager
from unittest.mock import patch
from fastapi import FastAPI, Header, HTTPException
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
from app.core.database import Base, get_db
from app.core.auth_deps import get_current_user
from app.models.models import User, Artisan, Buyer, Product, ProductListing, Requirement, AccountRole, PriceRecommendation
from app.routers import bidding


class BiddingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        engine = create_async_engine('sqlite+aiosqlite:///' + (Path(self.temp.name)/'test.db').as_posix())
        factory = async_sessionmaker(engine, expire_on_commit=False)
        self.clock = datetime(2030, 1, 1, tzinfo=timezone.utc)
        self.patch = patch.object(bidding, 'now', lambda: self.clock)
        self.patch.start()
        async def db():
            async with factory() as session: yield session
        async def identity(authorization: str = Header(default='')):
            key = authorization.replace('Bearer ', '')
            if key not in ('owner','stranger','one','two','unverified'): raise HTTPException(401)
            async with factory() as session: return await session.get(User, key)
        @asynccontextmanager
        async def lifespan(app):
            async with engine.begin() as connection: await connection.run_sync(Base.metadata.create_all)
            async with factory() as session:
                for key in ['owner','stranger','one','two','unverified']:
                    session.add(User(id=key, firebase_uid=key, role=AccountRole.artisan if key in ('owner','stranger') else AccountRole.buyer, name=key))
                await session.flush()
                session.add(Artisan(id='artisan', user_id='owner'))
                session.add(Artisan(id='other', user_id='stranger'))
                for key in ['one','two','unverified']:
                    session.add(Buyer(user_id=key, business_name=key, is_verified=key!='unverified'))
                    session.add(Requirement(buyer_id=key,product='Bamboo basket',quantity=20,lead_days=7,location='Delhi'))
                session.add(Product(id='product',artisan_id='artisan'))
                session.add(ProductListing(product_id='product',title_en='Bamboo basket',title_hi='',desc_en='Woven',desc_hi='',attributes={'stock':30,'available':True,'moq':1}))
                session.add(PriceRecommendation(product_id='product', material_cost=80, labour_cost=60, overhead=10,
                    recommended_min=150, recommended_max=250, final_price=200, explanation_text_en='', explanation_text_hi=''))
                await session.commit()
            yield
            await engine.dispose()
        app=FastAPI(lifespan=lifespan)
        app.include_router(bidding.router,prefix='/bidding')
        app.dependency_overrides[get_db]=db
        app.dependency_overrides[get_current_user]=identity
        self.client=TestClient(app).__enter__()
    def tearDown(self):
        self.client.__exit__(None,None,None);self.patch.stop();self.temp.cleanup()
    def request(self,method,path,who='owner',data=None,status=200):
        r=self.client.request(method,'/bidding'+path,headers={'Authorization':'Bearer '+who},json=data)
        self.assertEqual(r.status_code,status,r.text)
        return r.json()
    def create(self,**changes):
        return self.request('POST','',data={
            'product_id':'product','quantity':25,'min_price':200,
            'starts_at':(self.clock+timedelta(minutes=10)).isoformat(),
            'ends_at':(self.clock+timedelta(minutes=20)).isoformat(),**changes})
    def action(self,s,action,who='owner',status=200,**fields):
        return self.request('POST','/'+s['id']+'/actions',who,{'revision':s['revision'],'action':action,**fields},status)
    def test_verified_matching_and_owner_access(self):
        result=self.request('GET','/matches/product')
        self.assertEqual({b['id'] for b in result['buyers']},{'one','two'})
        self.request('GET','/matches/product','stranger',status=404)
        self.request('GET','/matches/product','one',status=403)
        s=self.create()
        self.assertEqual(self.request('GET','','stranger'),[])
        self.assertEqual(self.request('GET','','unverified'),[])
        self.action(s,'cancel','stranger',status=404)
    def test_sealing_deadlines_and_buyer_isolation(self):
        s=self.create()
        self.action(s,'offer','one',status=409,quantity=10,price=220)
        self.clock+=timedelta(minutes=10)
        s=self.action(s,'offer','one',quantity=10,price=220)
        self.assertEqual(s['my_offer']['price'],220)
        owner=self.request('GET','')[0]
        self.assertEqual(owner['offers'],[])
        self.assertIsNone(owner['my_offer'])
        other=self.request('GET','','two')[0]
        self.assertIsNone(other['my_offer'])
        self.assertEqual(other['offers'],[])
        self.assertNotIn('one',str(other['buyers']))
        self.action(s,'offer','two',status=422,quantity=40,price=220)
        self.action(s,'offer','two',status=422,quantity=10,price=199)
        self.clock+=timedelta(minutes=10)
        self.action(s,'offer','one',status=409,quantity=10,price=250)
        owner=self.request('GET','')[0]
        self.assertEqual(owner['offers'][0]['price'],220)
        self.assertEqual(self.request('GET','','two')[0]['offers'],[])
    def test_split_allocation_stale_revision_and_idempotent_handoff(self):
        s=self.create();self.clock+=timedelta(minutes=11)
        s=self.action(s,'offer','one',quantity=20,price=250)
        stale=s.copy()
        s=self.action(s,'offer','two',quantity=20,price=240)
        self.action(stale,'offer','one',status=409,quantity=10,price=260)
        self.clock+=timedelta(minutes=10)
        self.action(s,'select',status=422,allocations={'one':20,'two':20})
        self.action(s,'select',status=422,allocations={'one':0})
        self.action(s,'select',status=422,allocations={'missing':10})
        self.action(s,'select','one',status=403,allocations={'one':10})
        s=self.action(s,'select',allocations={'one':10,'two':15})
        s=self.action(s,'handoff');self.assertEqual(len(s['inquiries']),2)
        ids=[r['id'] for r in s['inquiries']]
        s=self.action(s,'handoff');self.assertEqual([r['id'] for r in s['inquiries']],ids)
        self.assertEqual(len(self.request('GET','','one')[0]['inquiries']),1)
        self.assertTrue(all(r['quotes']==[] and r['status']=='sent' for r in s['inquiries']))
    def test_reservation_cancel_and_reject_release(self):
        s=self.create()
        self.assertEqual(self.request('GET','/matches/product')['available_stock'],5)
        s=self.action(s,'cancel')
        self.assertEqual(self.request('GET','/matches/product')['available_stock'],30)
        s=self.create();self.clock+=timedelta(minutes=21)
        self.action(s,'reject')
        self.assertEqual(self.request('GET','/matches/product')['available_stock'],30)
    def test_a_session_that_closes_without_offers_releases_stock(self):
        self.create()
        self.assertEqual(self.request('GET','/matches/product')['available_stock'],5)
        self.clock+=timedelta(minutes=21)
        # Nobody offered, so there is nothing to select; the lot is free again.
        self.assertEqual(self.request('GET','/matches/product')['available_stock'],30)
        self.assertEqual(self.create(quantity=30)['quantity'],30)
    def test_edit_is_future_only_and_validated(self):
        s=self.create()
        data={'product_id':'product','quantity':31,'min_price':200,'starts_at':s['starts_at'],'ends_at':s['ends_at'],'revision':s['revision']}
        self.request('PUT','/'+s['id'],data=data,status=422)

        data['quantity']=20
        s=self.request('PUT','/'+s['id'],data=data)
        self.assertEqual(s['quantity'],20)
        self.clock+=timedelta(minutes=11)
        self.action(s,'cancel',status=409)
        self.request('PUT','/'+s['id'],data=data,status=422)

    def test_cost_floor_timezone_and_selected_withdrawal(self):
        payload={'product_id':'product','quantity':10,'min_price':149,
            'starts_at':(self.clock+timedelta(minutes=10)).isoformat(),
            'ends_at':(self.clock+timedelta(minutes=20)).isoformat()}
        self.request('POST','',data=payload,status=422)
        payload['min_price']=200; payload['starts_at']='2030-01-01T00:10:00'
        self.request('POST','',data=payload,status=422)
        s=self.create(); self.clock+=timedelta(minutes=11)
        s=self.action(s,'offer','one',quantity=10,price=220)
        s=self.action(s,'withdraw','one')
        self.assertEqual(s['offer_count'],0)
        s=self.action(s,'offer','one',quantity=10,price=220)
        self.clock+=timedelta(minutes=10)
        s=self.action(s,'select',allocations={'one':10})
        s=self.action(s,'withdraw','one')
        self.assertEqual(s['status'],'closed')
        self.assertEqual(s['allocations'],{})
