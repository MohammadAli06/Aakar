"""
Inquiries Router — the buyer↔artisan request-for-quotation exchanged in place.

An inquiry belongs to both participants: the buyer who asked and the artisan who
owns the product. The conversation, the capacity answer and every quotation
version are stored here, so both accounts read the same record instead of a
device-local copy that never reaches the other side.

Rules mirror `CommerceEngine`/`workflow_service`: a quotation never goes below
the material + labour + overhead floor, capacity is answered by the artisan
before pricing, and accepting a quotation records an order. Nothing here holds
money — payment milestones are status records only.
"""
import uuid
import re
from pathlib import Path
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from fastapi.responses import FileResponse
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user, require_buyer
from app.core.database import get_db
from app.services.workflow_assistant import assist
from app.models.models import (
    AccountRole, Artisan, Inquiry, Notification, Order, PriceRecommendation,
    Product, ProductListing, ProductStatus, User,
)

router = APIRouter()
VOICE_MEDIA = Path(__file__).parents[2] / 'uploads' / 'inquiry_voice'
MAX_VOICE_BYTES = 5 * 1024 * 1024

CAPACITY_STATUSES = ('confirmed', 'partial', 'declined')
MILESTONE_TRIGGERS = ('advance', 'checkpoint', 'dispatch', 'delivery')
QUOTE_CHARGES = ('packaging_cost', 'delivery_cost', 'storage_cost', 'demo_cost')


def _num(value: Any, fallback: float = 0.0) -> float:
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        return fallback
    return parsed if parsed == parsed and parsed not in (float('inf'), float('-inf')) else fallback


def _text(value: Any) -> str:
    return '' if value is None else str(value).strip()


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _ident(prefix: str) -> str:
    return f'{prefix}-{uuid.uuid4().hex[:16]}'


def inquiry_record(row: Inquiry, buyer_name: Optional[str] = None,
                   artisan_name: Optional[str] = None) -> Dict[str, Any]:
    """The flat record the marketplace screens already render."""
    return {
        'id': row.id,
        'buyer_id': row.buyer_id,
        'artisan_id': row.artisan_id,
        'product_id': row.product_id,
        'product_title': row.product_title,
        'quantity': row.quantity,
        'lead_days': row.lead_days,
        'budget': row.budget or 0,
        'location': row.location,
        'target_date': row.target_date,
        'customization': row.customization,
        'specifications': row.specifications,
        'packaging': row.packaging,
        'reference_image': row.reference_image,
        'requirement_id': row.requirement_id,
        'capacity_status': row.capacity_status,
        'confirmed_quantity': row.confirmed_quantity,
        'offered_lead_days': row.offered_lead_days,
        'sample_required': bool(row.sample_required),
        'sample_status': row.sample_status,
        'sample_evidence': row.sample_evidence,
        'sample_terms': row.sample_terms,
        'sample_note': row.sample_note,
        'status': row.status,
        'order_id': row.order_id,
        'messages': list(row.messages or []),
        'quotes': list(row.quotes or []),
        'events': list(row.events or []),
        'time': row.created_at.isoformat() if row.created_at else None,
        'buyer_name': buyer_name,
        'artisan_name': artisan_name,
        'server': True,
    }


async def _serialize(db: AsyncSession, rows: List[Inquiry]) -> List[Dict[str, Any]]:
    """Serialize a page of inquiries without a query per row."""
    if not rows:
        return []
    buyers = {u.id: u for u in (await db.scalars(select(User).where(
        User.id.in_({r.buyer_id for r in rows})))).all()}
    artisans = {a.id: a for a in (await db.scalars(select(Artisan).where(
        Artisan.id.in_({r.artisan_id for r in rows})))).all()}
    owners = {u.id: u for u in (await db.scalars(select(User).where(
        User.id.in_({a.user_id for a in artisans.values()})))).all()}

    records = []
    for row in rows:
        artisan = artisans.get(row.artisan_id)
        buyer = buyers.get(row.buyer_id)
        owner = owners.get(artisan.user_id) if artisan else None
        record = inquiry_record(row, buyer.name if buyer else None,
                                owner.name if owner else None)
        record.update(buyer_language=buyer.language_pref if buyer else None,
                      artisan_language=owner.language_pref if owner else None)
        records.append(record)
    return records


async def _load(db: AsyncSession, inquiry_id: str) -> Inquiry:
    row = await db.scalar(select(Inquiry).where(Inquiry.id == inquiry_id).with_for_update())
    if row is None:
        raise HTTPException(status_code=404, detail='Inquiry not found')
    return row


async def _scope(db: AsyncSession, user: User, row: Inquiry) -> str:
    """Enforce participation and return the caller's role in this inquiry."""
    if user.role == AccountRole.buyer:
        if row.buyer_id != user.id:
            raise HTTPException(status_code=403, detail='This inquiry belongs to another buyer')
        return 'buyer'
    artisan = await db.scalar(select(Artisan).where(Artisan.user_id == user.id))
    if artisan is None or row.artisan_id != artisan.id:
        raise HTTPException(status_code=403, detail='This inquiry belongs to another artisan')
    return 'artisan'


async def _product_context(db: AsyncSession, product_id: str):
    product = await db.get(Product, product_id)
    if product is None:
        raise HTTPException(status_code=404, detail='Product not found')
    listing = await db.scalar(select(ProductListing).where(
        ProductListing.product_id == product_id))
    price = await db.scalar(select(PriceRecommendation).where(
        PriceRecommendation.product_id == product_id))
    return product, listing, dict((listing.attributes if listing else None) or {}), price


def _floor(price: Optional[PriceRecommendation]) -> float:
    if price is None:
        return 0.0
    return _num(price.material_cost) + _num(price.labour_cost) + _num(price.overhead)


async def _event(db: AsyncSession, row: Inquiry, title: str, actor: str, role: str) -> None:
    row.events = [*(row.events or []), {'title': title, 'time': _now(), 'actor': actor, 'role': role}]


async def _notify_message(db: AsyncSession, row: Inquiry, role: str) -> None:
    """Tell the other participant a message arrived, and where to read it.

    Only the recipient is notified — the sender already knows. The link opens
    that inquiry directly on its chat tab.
    """
    if role == 'buyer':
        recipient_role = 'artisan'
        artisan = await db.get(Artisan, row.artisan_id)
        recipient = artisan.user_id if artisan else None
    else:
        recipient_role = 'buyer'
        recipient = row.buyer_id
    if not recipient:
        return
    db.add(Notification(
        id=str(uuid.uuid4()),
        recipient_id=recipient,
        role=recipient_role,
        title=f'New message · {row.product_title}',
        link=f'inquiry/{row.id}?tab=chat',
        category='Others',
        read=False,
    ))


class CommunicationDraft(BaseModel):
    text: str = Field(min_length=1, max_length=6000)
    translation: str = Field(default='', max_length=12000)
    target_language: Optional[str] = None


class InquiryDraft(BaseModel):
    """The structured inquiry the buyer's review step produces."""

    model_config = ConfigDict(str_strip_whitespace=True, extra='ignore')

    product_id: str = Field(min_length=1)
    quantity: float = Field(gt=0)
    lead_days: float = Field(gt=0)
    location: str = Field(min_length=1, max_length=300)
    product: Optional[str] = None
    budget: Optional[float] = 0
    target_date: Optional[str] = None
    customization: Optional[str] = None
    specifications: Optional[str] = None
    packaging: Optional[str] = None
    reference_image: Optional[str] = None
    sample_required: bool = False
    requirement_id: Optional[str] = None
    communication: Optional[CommunicationDraft] = None


class BridgeDraft(BaseModel):
    text: str = Field(min_length=1, max_length=6000)
    product_id: Optional[str] = None


async def _languages(db, row):
    buyer = await db.get(User, row.buyer_id)
    artisan = await db.get(Artisan, row.artisan_id)
    owner = await db.get(User, artisan.user_id) if artisan else None
    return {'buyer': buyer.language_pref if buyer else None,
            'artisan': owner.language_pref if owner else None}


async def _bridge(text, source, target):
    # Language comes from the participants' accounts, never their roles.
    if source == target and source in ('hi', 'en'):
        return {'text': text, 'translation': '', 'status': 'same_language',
                'source_language': source, 'target_language': target}
    if source not in ('hi', 'en') or target not in ('hi', 'en'):
        return {'text': text, 'translation': '', 'status': 'unavailable',
                'source_language': source, 'target_language': target}
    result = await assist('translate', text, target)
    translated = _text(result.get('fields', {}).get('translation'))
    return {'text': text, 'translation': translated,
            'status': 'review_required' if translated else 'unavailable',
            'source_language': source, 'target_language': target}


@router.post('/preview')
async def preview_requirement(data: BridgeDraft, user: User = Depends(require_buyer),
                              db: AsyncSession = Depends(get_db)):
    product, _listing, _attributes, _price = await _product_context(db, data.product_id or '')
    if product.status != ProductStatus.published:
        raise HTTPException(422, 'Product is not published')
    artisan = await db.get(Artisan, product.artisan_id)
    owner = await db.get(User, artisan.user_id)
    return await _bridge(data.text, user.language_pref, owner.language_pref)


@router.post('/{inquiry_id}/bridge')
async def preview_message(inquiry_id: str, data: BridgeDraft,
                          user: User = Depends(get_current_user),
                          db: AsyncSession = Depends(get_db)):
    row = await _load(db, inquiry_id)
    role = await _scope(db, user, row)
    languages = await _languages(db, row)
    # Release the read transaction before the external service call.
    await db.rollback()
    return await _bridge(data.text, languages[role], languages['artisan' if role == 'buyer' else 'buyer'])


@router.post('/', status_code=200)
async def create_inquiry(
    data: InquiryDraft,
    user: User = Depends(require_buyer),
    db: AsyncSession = Depends(get_db),
):
    """Send an inquiry to the artisan who published a product."""
    product, listing, attributes, _price = await _product_context(db, data.product_id)
    if product.status != ProductStatus.published:
        raise HTTPException(status_code=422, detail='Product is not published')
    if attributes.get('available') is not True:
        raise HTTPException(status_code=422, detail='This product is not taking orders')
    if _num(data.quantity) < _num(attributes.get('moq')):
        raise HTTPException(status_code=422, detail='Requested quantity is below MOQ')

    artisan = await db.get(Artisan, product.artisan_id)
    if artisan is None:
        raise HTTPException(status_code=422, detail='This product has no artisan profile')

    row = Inquiry(
        id=str(uuid.uuid4()),
        buyer_id=user.id,
        artisan_id=product.artisan_id,
        product_id=product.id,
        product_title=_text(listing.title_en if listing else None) or _text(data.product) or 'Product',
        quantity=_num(data.quantity),
        lead_days=_num(data.lead_days),
        budget=_num(data.budget),
        location=_text(data.location),
        target_date=data.target_date,
        customization=data.customization,
        specifications=data.specifications,
        packaging=data.packaging,
        reference_image=data.reference_image,
        requirement_id=data.requirement_id,
        capacity_status='pending',
        sample_required=bool(data.sample_required),
        sample_status='requested' if data.sample_required else 'not_required',
        status='sent',
        messages=[],
        quotes=[],
        events=[],
    )
    db.add(row)
    if data.communication and data.communication.text.strip():
        languages = await _languages(db, row)
        row.messages = [_message(data.communication.model_dump(), user.id, 'buyer', languages)]
    await _event(db, row, 'Inquiry sent', user.id, 'buyer')
    await db.commit()
    await db.refresh(row)
    return (await _serialize(db, [row]))[0]


@router.get('/')
async def list_my_inquiries(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Every inquiry this account participates in, newest first."""
    if user.role == AccountRole.buyer:
        rows = (await db.scalars(select(Inquiry).where(
            Inquiry.buyer_id == user.id).order_by(Inquiry.created_at.desc()))).all()
    else:
        artisan = await db.scalar(select(Artisan).where(Artisan.user_id == user.id))
        if artisan is None:
            return []
        rows = (await db.scalars(select(Inquiry).where(
            Inquiry.artisan_id == artisan.id).order_by(Inquiry.created_at.desc()))).all()
    return await _serialize(db, list(rows))


@router.get('/{inquiry_id}')
async def get_inquiry(
    inquiry_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    row = await _load(db, inquiry_id)
    await _scope(db, user, row)
    return (await _serialize(db, [row]))[0]


class MessageDraft(BaseModel):
    model_config = ConfigDict(extra='ignore')

    text: str = Field(min_length=1, max_length=6000)
    translation: Optional[str] = ''
    attachment: Optional[str] = ''
    provenance: Optional[str] = 'original'
    target_language: Optional[str] = None


class ChangeDraft(CommunicationDraft):
    quote_id: str


@router.post('/{inquiry_id}/request-change')
async def request_change(inquiry_id: str, data: ChangeDraft,
                         user: User = Depends(get_current_user),
                         db: AsyncSession = Depends(get_db)):
    row = await _load(db, inquiry_id)
    role = await _scope(db, user, row)
    quotes = [dict(q) for q in row.quotes or []]
    if (row.status == 'ordered' or not quotes or quotes[-1]['id'] != data.quote_id
            or quotes[-1]['author'] == role or quotes[-1]['status'] != 'proposed'):
        raise HTTPException(422, 'Refresh and review the latest open quotation')
    if not data.text.strip():
        raise HTTPException(422, 'Describe the changes you need')
    quotes[-1]['status'] = 'changes_requested'
    row.quotes = quotes
    message = _message(data.model_dump(), user.id, role, await _languages(db, row))
    row.messages = [*(row.messages or []), {**message, 'kind': 'change_request', 'quote_id': data.quote_id}]
    await _event(db, row, 'Changes requested to quotation', user.id, role)
    await db.commit()
    await db.refresh(row)
    return (await _serialize(db, [row]))[0]


def _message(data, actor, role, languages):
    source = languages[role]
    target = languages['artisan' if role == 'buyer' else 'buyer']
    # Discard stale/wrong-language previews, and never translate voice media.
    translation = (data.get('translation') or '') if (
        source in ('en', 'hi') and target in ('en', 'hi') and source != target
        and data.get('target_language') == target) else ''
    return {'id': _ident('message'), 'kind': 'text', 'text': data['text'],
            'translation': translation, 'role': role, 'actor': actor, 'time': _now(),
            'source_language': source, 'target_language': target,
            'attachment': data.get('attachment') or '',
            'provenance': 'participant-reviewed' if translation else 'original'}


@router.post('/{inquiry_id}/messages')
async def add_message(
    inquiry_id: str,
    data: MessageDraft,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Append a participant's message. Original wording is kept verbatim."""
    row = await _load(db, inquiry_id)
    role = await _scope(db, user, row)
    if not data.text.strip():
        raise HTTPException(422, 'Enter a message')
    row.messages = [*(row.messages or []),
                    _message(data.model_dump(), user.id, role, await _languages(db, row))]
    await _notify_message(db, row, role)
    await db.commit()
    await db.refresh(row)
    return (await _serialize(db, [row]))[0]


@router.post('/{inquiry_id}/voice')
async def send_voice(inquiry_id: str, file: UploadFile = File(...),
                     user: User = Depends(get_current_user),
                     db: AsyncSession = Depends(get_db)):
    row = await _load(db, inquiry_id)
    role = await _scope(db, user, row)
    content = await file.read(MAX_VOICE_BYTES + 1)
    await file.close()
    if len(content) > MAX_VOICE_BYTES:
        raise HTTPException(413, 'Voice note must be under 5 MB')
    if len(content) < 32 or content[4:8] != b'ftyp' or b'mdat' not in content:
        raise HTTPException(422, 'Record an AAC/M4A voice note')
    name = uuid.uuid4().hex + '.m4a'
    VOICE_MEDIA.mkdir(parents=True, exist_ok=True)
    path = VOICE_MEDIA / name
    path.write_bytes(content)
    row.messages = [*(row.messages or []), {
        'id': _ident('message'), 'kind': 'voice', 'text': '', 'translation': '',
        'voice': name, 'role': role, 'actor': user.id, 'time': _now(),
        'provenance': 'Original voice note',
    }]
    await _notify_message(db, row, role)
    try:
        await db.commit()
    except Exception:
        path.unlink(missing_ok=True)
        raise
    await db.refresh(row)
    return (await _serialize(db, [row]))[0]


@router.get('/{inquiry_id}/voice/{name}')
async def get_voice(inquiry_id: str, name: str,
                    user: User = Depends(get_current_user),
                    db: AsyncSession = Depends(get_db)):
    row = await _load(db, inquiry_id)
    await _scope(db, user, row)
    if (not re.fullmatch(r'[a-f0-9]{32}\.m4a', name)
            or not any(m.get('voice') == name for m in row.messages or [])
            or not (VOICE_MEDIA / name).is_file()):
        raise HTTPException(404, 'Voice note not found')
    return FileResponse(VOICE_MEDIA / name, media_type='audio/mp4',
                        headers={'Cache-Control': 'private, no-store'})


class CapacityDraft(BaseModel):
    status: str
    quantity: Optional[float] = None
    lead_days: Optional[float] = None


@router.post('/{inquiry_id}/capacity')
async def confirm_capacity(
    inquiry_id: str,
    data: CapacityDraft,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """The artisan's answer before any price is discussed."""
    row = await _load(db, inquiry_id)
    role = await _scope(db, user, row)
    if role != 'artisan':
        raise HTTPException(status_code=403, detail='Only the artisan confirms capacity')
    if row.status == 'ordered':
        raise HTTPException(422, 'Order terms are already agreed')
    if data.status not in CAPACITY_STATUSES:
        raise HTTPException(status_code=422, detail='Choose a capacity response')
    if data.status != 'declined' and not (_num(data.quantity) > 0 and _num(data.lead_days) > 0):
        raise HTTPException(status_code=422, detail='Confirm quantity and lead time')
    if data.status == 'confirmed' and _num(data.quantity) < _num(row.quantity):
        raise HTTPException(status_code=422, detail='Use Partial for a smaller quantity')
    if data.status == 'partial' and _num(data.quantity) >= _num(row.quantity):
        raise HTTPException(422, 'Partial quantity must be less than requested quantity')

    row.capacity_status = data.status
    row.confirmed_quantity = data.quantity
    row.offered_lead_days = data.lead_days
    row.quotes = [{**q, 'status': 'superseded'} if q.get('status') == 'proposed' else q
                  for q in row.quotes or []]
    await _event(db, row, f'Capacity {data.status}', user.id, role)
    await db.commit()
    await db.refresh(row)
    return (await _serialize(db, [row]))[0]


class QuoteDraft(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra='ignore')

    unit_price: float = Field(gt=0)
    quantity: float = Field(gt=0)
    lead_days: float = Field(gt=0)
    inspection_hours: float = Field(gt=0)
    delivery_terms: str = Field(min_length=1)
    location: str = Field(min_length=1)
    target_date: Optional[str] = None
    customization: Optional[str] = None
    specifications: Optional[str] = None
    packaging_cost: Optional[float] = 0
    delivery_cost: Optional[float] = 0
    storage_cost: Optional[float] = 0
    demo_cost: Optional[float] = 0
    middle_trigger: Optional[str] = 'dispatch'
    checkpoint_required: bool = False
    terms: Optional[str] = None
    milestones: List[Dict[str, Any]] = Field(default_factory=list)


@router.post('/{inquiry_id}/quote')
async def propose_quote(
    inquiry_id: str,
    data: QuoteDraft,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Append a quotation version. History is never overwritten."""
    row = await _load(db, inquiry_id)
    role = await _scope(db, user, row)
    if row.status == 'ordered':
        raise HTTPException(status_code=422, detail='Order terms are already agreed')
    if row.id.startswith('bid-') and row.capacity_status == 'pending':
        row.capacity_status = 'confirmed'
        row.confirmed_quantity = row.confirmed_quantity or row.quantity
        row.offered_lead_days = row.offered_lead_days or row.lead_days
    if row.capacity_status not in ('confirmed', 'partial'):
        raise HTTPException(status_code=422, detail='Artisan must confirm capacity first')
    if role != 'artisan' and not row.quotes:
        raise HTTPException(403, 'The artisan sends the first quotation')

    _product, _listing, attributes, price = await _product_context(db, row.product_id)
    min_qty = 1 if row.id.startswith('bid-') else _num(attributes.get('moq'))
    if not (min_qty <= _num(data.quantity) <= _num(row.confirmed_quantity)):
        raise HTTPException(status_code=422, detail='Quantity must satisfy MOQ and confirmed capacity')
    if _num(data.unit_price) < _floor(price):
        raise HTTPException(status_code=422, detail='Price below cost floor')
    if any(_num(getattr(data, key)) < 0 for key in QUOTE_CHARGES):
        raise HTTPException(status_code=422, detail='Charges cannot be negative')

    milestones = data.milestones or []
    if not milestones or abs(sum(_num(m.get('percent')) for m in milestones) - 100) >= 0.01:
        raise HTTPException(status_code=422, detail='Milestones must total 100%')
    if any(_num(m.get('percent')) <= 0 or m.get('trigger') not in MILESTONE_TRIGGERS
           for m in milestones):
        raise HTTPException(status_code=422, detail='Invalid milestone')
    if not any(m.get('trigger') == 'advance' for m in milestones):
        raise HTTPException(status_code=422, detail='Milestones must include an advance')
    if any(m.get('trigger') == 'checkpoint' for m in milestones) and not data.checkpoint_required:
        raise HTTPException(status_code=422, detail='QC milestone requires a checkpoint')
    if data.middle_trigger not in ('checkpoint', 'dispatch'):
        raise HTTPException(status_code=422, detail='Unknown middle milestone trigger')

    charges = sum(_num(getattr(data, key)) for key in QUOTE_CHARGES)
    total = _num(data.unit_price) * _num(data.quantity) + charges
    quote = {
        **data.model_dump(),
        'id': _ident('quote'),
        'version': len(row.quotes or []) + 1,
        'author': role,
        'time': _now(),
        'total': total,
        'currency': 'INR',
        'status': 'proposed',
    }
    if (row.sample_required and row.sample_status == 'approved' and row.sample_basis
            and any(_text(quote.get(key)) != _text((row.sample_basis or {}).get(key))
                    for key in ('customization', 'specifications'))):
        row.sample_status = 'requested'
        await _event(db, row, 'Specifications changed; sample approval required again',
                     user.id, role)

    row.quotes = [*[{**q, 'status': 'superseded'} if q.get('status') == 'proposed' else q
                    for q in row.quotes or []], quote]
    row.status = 'negotiating'
    row.capacity_status = 'confirmed'
    await _event(db, row, f'Quote v{quote["version"]} proposed', user.id, role)
    await db.commit()
    await db.refresh(row)
    return (await _serialize(db, [row]))[0]


class AcceptDraft(BaseModel):
    quote_id: str = Field(min_length=1)


@router.post('/{inquiry_id}/accept')
async def accept_quote(
    inquiry_id: str,
    data: AcceptDraft,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Accept the latest quotation. Records an order; holds no money."""
    row = await _load(db, inquiry_id)
    role = await _scope(db, user, row)
    # Fresh dicts, so reassigning the JSON column is a real change SQLAlchemy
    # records; mutating the stored dicts in place would not be persisted.
    quotes = [dict(entry) for entry in (row.quotes or [])]
    if not quotes:
        raise HTTPException(status_code=422, detail='No quote to accept')
    quote = quotes[-1]
    if quote.get('id') != data.quote_id:
        raise HTTPException(status_code=422, detail='Quote changed; refresh and review')
    if row.status == 'ordered':
        return (await _serialize(db, [row]))[0]
    if quote.get('author') == role:
        raise HTTPException(status_code=422, detail='The other participant must accept an open quote')
    if quote.get('status') != 'proposed':
        raise HTTPException(status_code=422, detail='This quote is no longer open')
    if row.sample_required and row.sample_status != 'approved':
        raise HTTPException(status_code=422, detail='Approve sample before bulk order')

    _product, _listing, attributes, _price = await _product_context(db, row.product_id)
    committed = sum(_num((o.payload or {}).get('quantity')) for o in (await db.scalars(
        select(Order).where(Order.product_id == row.product_id,
                            Order.status != 'completed'))).all())
    available = (_num(attributes.get('stock'))
                 + _num(attributes.get('capacity')) * _num(quote.get('lead_days')) / 30
                 - committed)
    if available < _num(quote.get('quantity')):
        raise HTTPException(status_code=422, detail='Capacity changed; revise the quote')

    order_id = str(uuid.uuid4())
    total = _num(quote.get('total'))
    milestones = [
        {**m, 'id': f'm{index}', 'amount': round(total * _num(m.get('percent')) / 100, 2),
         'status': 'pending'}
        for index, m in enumerate(quote.get('milestones') or [])
    ]
    payload = {
        **quote,
        'id': order_id,
        'inquiry_id': row.id,
        'product_id': row.product_id,
        'product_title': row.product_title,
        'buyer_id': row.buyer_id,
        'artisan_id': row.artisan_id,
        'quote_id': quote.get('id'),
        'status': 'confirmed',
        'production': 'not_started',
        'shipment': 'not_dispatched',
        'inspection': 'pending',
        'checkpoint': 'not_submitted',
        'packaging_checks': [],
        'events': [{'title': f'Order confirmed · quote v{quote.get("version")}',
                    'time': _now(), 'actor': user.id, 'role': role}],
        'milestones': milestones,
        'payment_mode': 'demo',
        'time': _now(),
    }
    db.add(Order(
        id=order_id,
        inquiry_id=row.id,
        buyer_id=row.buyer_id,
        artisan_id=row.artisan_id,
        product_id=row.product_id,
        product_title=row.product_title,
        status='confirmed',
        payload=payload,
    ))
    quote['status'] = 'accepted'
    row.quotes = quotes
    row.status = 'ordered'
    row.order_id = order_id
    await _event(db, row, f'Order confirmed · quote v{quote.get("version")}', user.id, role)
    await db.commit()
    await db.refresh(row)
    return (await _serialize(db, [row]))[0]


@router.post('/{inquiry_id}/reject')
async def reject_quote(
    inquiry_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Reject the latest quotation. The other participant may propose a revision."""
    row = await _load(db, inquiry_id)
    role = await _scope(db, user, row)
    quotes = [dict(entry) for entry in (row.quotes or [])]
    if not quotes:
        raise HTTPException(status_code=422, detail='No quote to reject')
    if row.status == 'ordered' or quotes[-1].get('author') == role:
        raise HTTPException(status_code=422, detail='Cannot reject this quote')
    quotes[-1] = {**quotes[-1], 'status': 'rejected'}
    row.quotes = quotes
    await _event(db, row, 'Quote rejected', user.id, role)
    await db.commit()
    await db.refresh(row)
    return (await _serialize(db, [row]))[0]


class SampleDraft(BaseModel):
    status: str
    evidence: Optional[str] = None
    terms: Optional[str] = None
    note: Optional[str] = None


@router.post('/{inquiry_id}/sample')
async def review_sample(
    inquiry_id: str,
    data: SampleDraft,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Optional sample approval before a bulk order, in either direction."""
    row = await _load(db, inquiry_id)
    role = await _scope(db, user, row)
    if not row.sample_required:
        raise HTTPException(status_code=422, detail='No sample was requested')

    if role == 'artisan':
        if data.status != 'submitted' or row.sample_status not in (
                'requested', 'changes_requested', 'rejected') or not _text(data.evidence):
            raise HTTPException(status_code=422,
                                detail='Submit a requested or revised sample with evidence')
        row.sample_evidence = data.evidence
        row.sample_terms = data.terms or ''
    else:
        if row.sample_status != 'submitted' or data.status not in (
                'approved', 'changes_requested', 'rejected'):
            raise HTTPException(status_code=422, detail='Review the submitted sample')

    row.sample_status = data.status
    if data.status == 'approved':
        basis = (row.quotes or [{}])[-1] if row.quotes else {}
        row.sample_basis = {key: basis.get(key, '') for key in ('customization', 'specifications')}
    row.sample_note = data.note or ''
    await _event(db, row, f'Sample {data.status}', user.id, role)
    await db.commit()
    await db.refresh(row)
    return (await _serialize(db, [row]))[0]
