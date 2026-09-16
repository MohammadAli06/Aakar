"""Account-owned sealed bidding. All time and visibility decisions are server-side."""
import copy
import re
import uuid
from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, AwareDatetime
from sqlalchemy import Column, String, Integer, JSON, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import Base, get_db
from app.core.auth_deps import get_current_user, require_artisan_profile
from app.models.models import User, Artisan, Buyer, Requirement, Product, ProductListing, PriceRecommendation


class BiddingSession(Base):
    __tablename__ = 'bidding_sessions'
    id = Column(String, primary_key=True)
    owner_id = Column(String, nullable=False, index=True)
    product_id = Column(String, nullable=False, index=True)
    revision = Column(Integer, nullable=False, default=1)
    data = Column(JSON, nullable=False)


router = APIRouter()

def now():
    return datetime.now(timezone.utc)


def phase(data, at=None):
    if data.get('outcome'):
        return data['outcome']
    at = at or now()
    if at < datetime.fromisoformat(data['starts_at']):
        return 'scheduled'
    if at < datetime.fromisoformat(data['ends_at']):
        return 'live'
    return 'closed'


def fail(condition, message, status=422):
    if not condition:
        raise HTTPException(status, message)


class Schedule(BaseModel):
    product_id: str
    quantity: int = Field(gt=0, le=1000000)
    min_price: float = Field(ge=0.01, le=100000000, multiple_of=0.01, allow_inf_nan=False)
    starts_at: AwareDatetime
    ends_at: AwareDatetime
    revision: int | None = None


class Action(BaseModel):
    revision: int
    action: Literal['cancel', 'offer', 'withdraw', 'select', 'reject', 'handoff']
    quantity: int = Field(default=0, ge=0, le=1000000)
    price: float = Field(default=0, ge=0, le=100000000, multiple_of=0.01, allow_inf_nan=False)
    note: str = Field(default='', max_length=1000)
    allocations: dict[str, int] = Field(default_factory=dict)


async def product_context(db, product_id, artisan):
    p = await db.scalar(select(Product).where(Product.id == product_id).with_for_update())
    fail(p is not None and p.artisan_id == artisan.id, 'Product not found', 404)
    listing = await db.scalar(select(ProductListing).where(ProductListing.product_id == p.id))
    price = await db.scalar(select(PriceRecommendation).where(PriceRecommendation.product_id == p.id))
    fail(listing is not None, 'Save product details first')
    attributes = listing.attributes or {}
    fail(attributes.get('available') is True, 'This product is not taking orders')
    floor = (price.material_cost + price.labour_cost + (price.overhead or 0)) if price else 0
    product = {**attributes, 'id': p.id, 'artisan_id': artisan.id, 'title': listing.title_en,
               'description': listing.desc_en, 'category': attributes.get('ui_category') or p.category.value,
               'price': price.final_price if price else 0, 'cost_floor': floor}
    return product


async def matches(db, product):
    # Explainable category/title matching, not fabricated AI buyer ratings.
    terms = set(re.findall(r'\w+', (product['title'] + ' ' + product['category']).lower())) - {'the', 'and', 'handmade', 'product'}
    rows = (await db.execute(select(Buyer, User, Requirement).join(User, Buyer.user_id == User.id)
        .join(Requirement, Requirement.buyer_id == User.id)
        .where(Buyer.is_verified.is_(True), User.is_active.is_(True), Requirement.status == 'open'))).all()
    found = {}
    for buyer, user, requirement in rows:
        demand = set(re.findall(r'\w+', requirement.product.lower()))
        overlap = sorted(terms & demand)
        if overlap and user.id not in found:
            found[user.id] = {'id': user.id, 'name': buyer.business_name or user.name or 'Buyer',
                'type': buyer.business_type or '', 'verified': True,
                'reason': 'Requirement matches: ' + ', '.join(overlap),
                'reliability': 'No completed-order rating available',
                'requirement_id': requirement.id, 'requested_quantity': requirement.quantity,
                'location': requirement.location, 'lead_days': requirement.lead_days,
                'sample_required': requirement.sample_required}
    return list(found.values())


async def available_stock(db, product, exclude=None):
    sessions = (await db.scalars(select(BiddingSession).where(BiddingSession.product_id == product['id']))).all()
    reserved = 0
    for session in sessions:
        if session.id == exclude or phase(session.data) in ('cancelled', 'rejected'):
            continue
        reserved += sum(session.data.get('allocations', {}).values()) if phase(session.data) in ('selected', 'quotation') else session.data['quantity']
    return max(0, int(float(product.get('stock', 0))) - reserved)


@router.get('/matches/{product_id}')
async def match_buyers(product_id: str, session_id: str | None = None, artisan=Depends(require_artisan_profile), db: AsyncSession = Depends(get_db)):
    product = await product_context(db, product_id, artisan)
    if session_id:
        existing = await db.get(BiddingSession, session_id)
        fail(existing is not None and existing.owner_id == artisan.user_id and existing.product_id == product_id,
             'Session not found', 404)
    return {'buyers': await matches(db, product), 'available_stock': await available_stock(db, product, session_id),
            'cost_floor': product['cost_floor']}


def visible(row, user):
    data = copy.deepcopy(row.data)
    owner = row.owner_id == user.id
    status = phase(data)
    offers = data.pop('offers', {})
    data['offer_count'] = len(offers)
    data['buyer_count'] = len(data['buyers'])
    data['offers'] = list(offers.values()) if owner and status in ('closed', 'selected', 'quotation', 'rejected') else []
    data['my_offer'] = offers.get(user.id) if not owner else None
    if not owner:
        data['product'].pop('cost_floor', None)
        data['buyers'] = [b for b in data['buyers'] if b['id'] == user.id]
        data['allocations'] = {k: v for k, v in data.get('allocations', {}).items() if k == user.id}
        data['inquiries'] = [r for r in data.get('inquiries', []) if r['buyer_id'] == user.id]
    return {**data, 'id': row.id, 'revision': row.revision, 'status': status, 'server_now': now().isoformat()}


@router.get('')
async def sessions(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    rows = (await db.scalars(select(BiddingSession))).all()
    return [visible(r, user) for r in rows if r.owner_id == user.id or any(b['id'] == user.id for b in r.data['buyers'])]


async def schedule(data, artisan, db, row=None):
    fail(data.starts_at > now(), 'Choose a future start time')
    duration = (data.ends_at - data.starts_at).total_seconds()
    fail(60 <= duration <= 7 * 86400, 'Session duration must be between one minute and seven days')
    product = await product_context(db, data.product_id, artisan)
    fail(data.quantity <= await available_stock(db, product, row.id if row else None), 'Quantity exceeds unreserved stock')
    fail(data.min_price >= product['cost_floor'], 'Minimum price must cover material, labour and overhead')
    buyers = await matches(db, product)
    fail(bool(buyers), 'No verified buyers with relevant open requirements yet')
    result = {'product': product, 'quantity': data.quantity, 'min_price': round(data.min_price, 2),
        'starts_at': data.starts_at.astimezone(timezone.utc).isoformat(),
        'ends_at': data.ends_at.astimezone(timezone.utc).isoformat(),
        'buyers': buyers, 'offers': {}, 'allocations': {}, 'inquiries': []}
    if row:
        fail(row.owner_id == artisan.user_id, 'Session not found', 404)
        fail(phase(row.data) == 'scheduled', 'Only upcoming sessions can be edited', 409)
        fail(data.product_id == row.product_id, 'The scheduled product cannot be changed')
        await save(db, row, result, data.revision)
    else:
        row = BiddingSession(id=str(uuid.uuid4()), owner_id=artisan.user_id, product_id=data.product_id, revision=1, data=result)
        db.add(row)
        await db.commit()
    return visible(row, type('Actor', (), {'id': artisan.user_id})())


@router.post('')
async def create(data: Schedule, artisan=Depends(require_artisan_profile), db: AsyncSession = Depends(get_db)):
    return await schedule(data, artisan, db)


@router.put('/{session_id}')
async def edit(session_id: str, data: Schedule, artisan=Depends(require_artisan_profile), db: AsyncSession = Depends(get_db)):
    row = await db.get(BiddingSession, session_id)
    fail(row is not None and row.owner_id == artisan.user_id, 'Session not found', 404)
    return await schedule(data, artisan, db, row)


async def save(db, row, data, revision):
    result = await db.execute(update(BiddingSession).where(BiddingSession.id == row.id, BiddingSession.revision == revision)
        .values(data=data, revision=revision + 1).execution_options(synchronize_session=False)) if revision is not None else None
    fail(result is not None and result.rowcount == 1, 'Session changed. Refresh and try again.', 409)
    await db.commit()
    await db.refresh(row)


@router.post('/{session_id}/actions')
async def act(session_id: str, action: Action, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    row = await db.get(BiddingSession, session_id)
    fail(row is not None, 'Session not found', 404)
    owner = row.owner_id == user.id
    data = copy.deepcopy(row.data)
    buyer = next((b for b in data['buyers'] if b['id'] == user.id), None)
    fail(owner or buyer is not None, 'Session not found', 404)
    status = phase(data)
    if action.action in ('offer', 'withdraw'):
        fail(buyer is not None and not owner, 'Only invited buyers can offer', 403)
        verified = await db.scalar(select(Buyer.is_verified).where(Buyer.user_id == user.id))
        fail(verified is True, 'Buyer verification is required', 403)
        fail(status == 'live' or (action.action == 'withdraw' and status == 'selected'),
             'Offers can only change while live; selected buyers may withdraw before quotation', 409)
        if action.action == 'withdraw':
            data['offers'].pop(user.id, None)
            data['allocations'].pop(user.id, None)
            if status == 'selected' and not data['allocations']:
                data.pop('outcome', None)
        else:
            fail(0 < action.quantity <= data['quantity'], 'Choose a quantity within the lot')
            fail(action.price >= data['min_price'], 'Offer is below the minimum unit price')
            data['offers'][user.id] = {'buyer_id': user.id, 'name': buyer['name'], 'quantity': action.quantity,
                'price': round(action.price, 2), 'note': action.note, 'time': now().isoformat(),
                'reliability': buyer['reliability'], 'fit': buyer['reason']}
    else:
        fail(owner, 'Only the session owner can decide', 403)
        if action.action == 'cancel':
            fail(status == 'scheduled', 'Only upcoming sessions can be cancelled', 409)
            data['outcome'] = 'cancelled'
        elif action.action == 'reject':
            fail(status == 'closed', 'Wait until the session closes', 409)
            data['outcome'] = 'rejected'
        elif action.action == 'select':
            fail(status == 'closed', 'Wait until the session closes', 409)
            allocations = action.allocations
            fail(bool(allocations) and sum(allocations.values()) <= data['quantity'], 'Allocate at least one unit without exceeding the lot')
            artisan = await db.scalar(select(Artisan).where(Artisan.user_id == user.id))
            current_product = await product_context(db, row.product_id, artisan)
            fail(sum(allocations.values()) <= await available_stock(db, current_product, row.id),
                 'Stock changed. Reduce the allocation or reject these offers.', 409)
            for bidder, quantity in allocations.items():
                offer = data['offers'].get(bidder)
                fail(offer is not None and 0 < quantity <= offer['quantity'], 'Allocation exceeds an offer or is invalid')
                fail(offer['price'] >= current_product['cost_floor'], 'Product costs changed; this offer is below the current cost floor.', 409)
                eligible = await db.scalar(select(Buyer.id).join(User, Buyer.user_id == User.id).where(
                    User.id == bidder, User.is_active.is_(True), Buyer.is_verified.is_(True)))
                fail(eligible is not None, 'A selected buyer is no longer verified or active. Refresh your selection.', 409)
            data['allocations'] = allocations
            data['outcome'] = 'selected'
        elif action.action == 'handoff':
            fail(status in ('selected', 'quotation'), 'Select offers first', 409)
            if status != 'quotation':
                for bidder, quantity in data['allocations'].items():
                    offer = data['offers'][bidder]
                    match = next(b for b in data['buyers'] if b['id'] == bidder)
                    data['inquiries'].append({'id': 'bid-' + row.id + '-' + bidder,
                        'bidding_session_id': row.id, 'product_id': row.product_id,
                        'artisan_id': data['product']['artisan_id'], 'buyer_id': bidder,
                        'buyer_name': match['name'], 'product_title': data['product']['title'],
                        'quantity': quantity, 'budget': offer['price'], 'lead_days': match['lead_days'],
                        'location': match['location'], 'sample_required': match['sample_required'],
                        'sample_status': 'requested' if match['sample_required'] else 'not_required',
                        'status': 'sent', 'capacity_status': 'pending', 'messages': [], 'quotes': [], 'events': [],
                        'time': now().isoformat(), 'specifications': offer['note']})
                data['outcome'] = 'quotation'
    await save(db, row, data, action.revision)
    return visible(row, user)
