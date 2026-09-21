"""
Orders Router — the agreed order an accepted quotation creates.
Orders Router — shared order record both accounts see once a quotation is accepted.

Read-only on purpose. Production, payment, shipping and inspection remain on the
existing demo engine; what this exposes is the shared record both accounts see
once a quotation is accepted, so the buyer and the artisan stop holding separate
copies.
Read endpoints serve both buyer and artisan.
PATCH endpoints (artisan-side actions) update the payload JSON column and order status.
"""
from typing import Any, Dict, Optional
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user
from app.core.database import get_db
from app.models.models import AccountRole, Artisan, Order, ProductListing, User

router = APIRouter()


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _num(value: Any, fallback: float = 0.0) -> float:
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        return fallback
    return parsed if parsed == parsed else fallback


def order_record(row: Order) -> Dict[str, Any]:
    """The flat record the order screens render, from the stored payload."""
    payload = dict(row.payload or {})
    return {
        **payload,
        'id': row.id,
        'inquiry_id': row.inquiry_id,
        'buyer_id': row.buyer_id,
        'artisan_id': row.artisan_id,
        'product_id': row.product_id,
        'product_title': row.product_title,
        'status': row.status,
        'server': True,
        'time': payload.get('time') or (
            row.created_at.isoformat() if row.created_at else None),
    }


async def _scope(db: AsyncSession, user: User, row: Order) -> None:
    if user.role == AccountRole.buyer:
        if row.buyer_id != user.id:
            raise HTTPException(status_code=403, detail='This order belongs to another buyer')
        return
    artisan = await db.scalar(select(Artisan).where(Artisan.user_id == user.id))
    if artisan is None or row.artisan_id != artisan.id:
        raise HTTPException(status_code=403, detail='This order belongs to another artisan')


async def _artisan_scope(db: AsyncSession, user: User, row: Order) -> Artisan:
    """Assert caller is the artisan who owns this order; returns the Artisan row."""
    if user.role != AccountRole.artisan:
        raise HTTPException(status_code=403, detail='Only the artisan can perform this action')
    artisan = await db.scalar(select(Artisan).where(Artisan.user_id == user.id))
    if artisan is None or row.artisan_id != artisan.id:
        raise HTTPException(status_code=403, detail='This order belongs to another artisan')
    return artisan


async def _get_order(db: AsyncSession, order_id: str) -> Order:
    row = await db.get(Order, order_id)
    if row is None:
        raise HTTPException(status_code=404, detail='Order not found')
    return row


def _append_event(payload: dict, text: str, role: str) -> None:
    events = payload.setdefault('events', [])
    events.append({'title': text, 'role': role, 'time': _now()})


# ── READ ──────────────────────────────────────────────────────────────────────

@router.get('/')
async def list_my_orders(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Every order this account participates in, newest first."""
    if user.role == AccountRole.buyer:
        rows = (await db.scalars(select(Order).where(
            Order.buyer_id == user.id).order_by(Order.created_at.desc()))).all()
    else:
        artisan = await db.scalar(select(Artisan).where(Artisan.user_id == user.id))
        if artisan is None:
            return []
        rows = (await db.scalars(select(Order).where(
            Order.artisan_id == artisan.id).order_by(Order.created_at.desc()))).all()
    return [order_record(row) for row in rows]


@router.get('/{order_id}')
async def get_order(
    order_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    row = await db.get(Order, order_id)
    if row is None:
        raise HTTPException(status_code=404, detail='Order not found')
    row = await _get_order(db, order_id)
    await _scope(db, user, row)
    return order_record(row)


# ── ARTISAN PATCH ACTIONS ─────────────────────────────────────────────────────

class AcceptBody(BaseModel):
    accepted: bool


@router.patch('/{order_id}/accept')
async def accept_order(
    order_id: str,
    body: AcceptBody,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Artisan accepts or declines a new confirmed order."""
    row = await _get_order(db, order_id)
    await _artisan_scope(db, user, row)

    payload = dict(row.payload or {})
    if body.accepted:
        payload['artisan_accepted'] = True
        payload['artisan_accepted_at'] = _now()
        row.status = 'artisan_accepted'
        _append_event(payload, 'Artisan accepted the order', 'artisan')
    else:
        payload['artisan_accepted'] = False
        payload['artisan_declined_at'] = _now()
        row.status = 'cancelled'
        _append_event(payload, 'Artisan declined the order', 'artisan')

    row.payload = payload
    await db.commit()
    await db.refresh(row)
    return order_record(row)


class ProductionPlanBody(BaseModel):
    prod_start_date: str
    prod_completion_date: str
    daily_target: Optional[str] = None


@router.patch('/{order_id}/production-plan')
async def set_production_plan(
    order_id: str,
    body: ProductionPlanBody,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Artisan sets production plan dates."""
    row = await _get_order(db, order_id)
    await _artisan_scope(db, user, row)

    allowed = {'artisan_accepted', 'in_production', 'ready'}
    if row.status not in allowed and row.status != 'artisan_accepted':
        raise HTTPException(422, 'Accept the order before setting a production plan')

    payload = dict(row.payload or {})
    payload['prod_start_date'] = body.prod_start_date
    payload['prod_completion_date'] = body.prod_completion_date
    if body.daily_target is not None:
        payload['daily_target'] = body.daily_target
    payload['production'] = payload.get('production', 'not_started')
    if row.status == 'artisan_accepted':
        row.status = 'in_production'
        payload['production'] = 'started'
    _append_event(payload, 'Production plan set', 'artisan')

    row.payload = payload
    await db.commit()
    await db.refresh(row)
    return order_record(row)


class ProductionProgressBody(BaseModel):
    milestone: str   # 'material_ready' | 'production_started' | 'in_progress'
    completed_units: int
    note: Optional[str] = None
    photo_url: Optional[str] = None


@router.patch('/{order_id}/production-progress')
async def update_production_progress(
    order_id: str,
    body: ProductionProgressBody,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Artisan updates production milestone and optionally uploads a proof photo."""
    row = await _get_order(db, order_id)
    await _artisan_scope(db, user, row)

    valid_milestones = {'material_ready', 'production_started', 'in_progress'}
    if body.milestone not in valid_milestones:
        raise HTTPException(422, f'milestone must be one of: {", ".join(valid_milestones)}')

    payload = dict(row.payload or {})
    milestones_done: list = payload.setdefault('production_milestones', [])
    if body.milestone not in milestones_done:
        milestones_done.append(body.milestone)
    payload['completed_units'] = body.completed_units

    # Progress proofs list
    proofs: list = payload.setdefault('progress_proofs', [])
    if body.photo_url or body.note:
        proofs.append({
            'milestone': body.milestone,
            'photo_url': body.photo_url or '',
            'note': body.note or '',
            'time': _now(),
        })

    # Map milestone → production status
    milestone_status_map = {
        'material_ready': 'started',
        'production_started': 'started',
        'in_progress': 'in_progress',
    }
    new_production = milestone_status_map[body.milestone]
    payload['production'] = new_production
    if row.status not in ('in_production', 'ready'):
        row.status = 'in_production'

    _append_event(payload, f'Production milestone: {body.milestone}', 'artisan')

    row.payload = payload
    await db.commit()
    await db.refresh(row)
    return order_record(row)


class ProductionCompleteBody(BaseModel):
    completed_units: int


@router.patch('/{order_id}/production-complete')
async def mark_production_complete(
    order_id: str,
    body: ProductionCompleteBody,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Artisan marks production as complete."""
    row = await _get_order(db, order_id)
    await _artisan_scope(db, user, row)

    payload = dict(row.payload or {})
    payload['production'] = 'ready'
    payload['completed_units'] = body.completed_units
    payload['production_completed_at'] = _now()
    milestones_done: list = payload.setdefault('production_milestones', [])
    for m in ('material_ready', 'production_started', 'in_progress', 'production_complete'):
        if m not in milestones_done:
            milestones_done.append(m)

    row.status = 'ready'
    _append_event(payload, 'Production marked complete', 'artisan')

    row.payload = payload
    await db.commit()
    await db.refresh(row)
    return order_record(row)


class PackagingBody(BaseModel):
    packaging_type: str
    num_boxes: int
    total_weight: Optional[str] = None
    packaging_photo: Optional[str] = None


@router.patch('/{order_id}/packaging')
async def set_packaging(
    order_id: str,
    body: PackagingBody,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Artisan records packaging details after production is complete."""
    row = await _get_order(db, order_id)
    await _artisan_scope(db, user, row)

    if row.status not in ('ready', 'dispatched'):
        raise HTTPException(422, 'Mark production complete before entering packaging details')

    payload = dict(row.payload or {})
    payload['packaging_type'] = body.packaging_type
    payload['num_boxes'] = body.num_boxes
    if body.total_weight:
        payload['total_weight'] = body.total_weight
    if body.packaging_photo:
        payload['packaging_photo'] = body.packaging_photo
    payload['packaging_done'] = True
    _append_event(payload, 'Packaging details recorded', 'artisan')

    row.payload = payload
    await db.commit()
    await db.refresh(row)
    return order_record(row)


class DispatchBody(BaseModel):
    courier: str
    awb_number: str
    dispatch_date: str
    estimated_delivery: str


@router.patch('/{order_id}/dispatch')
async def dispatch_order(
    order_id: str,
    body: DispatchBody,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Artisan dispatches the order with courier and tracking details."""
    row = await _get_order(db, order_id)
    await _artisan_scope(db, user, row)

    if row.status not in ('ready', 'artisan_accepted', 'in_production'):
        if row.status not in ('ready',):
            pass  # allow dispatch from ready onwards

    payload = dict(row.payload or {})
    payload['shipping'] = {
        'courier': body.courier,
        'awb_number': body.awb_number,
        'dispatch_date': body.dispatch_date,
        'estimated_delivery': body.estimated_delivery,
        'status': 'dispatched',
    }
    payload['shipment'] = 'dispatched'
    payload['production'] = 'dispatched'
    row.status = 'dispatched'
    _append_event(payload, f'Order dispatched via {body.courier} · AWB {body.awb_number}', 'artisan')

    row.payload = payload
    await db.commit()
    await db.refresh(row)
    return order_record(row)


class DeliveryStatusBody(BaseModel):
    status: str   # 'dispatched' | 'in_transit' | 'out_for_delivery' | 'delivered'


@router.patch('/{order_id}/delivery-status')
async def update_delivery_status(
    order_id: str,
    body: DeliveryStatusBody,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update delivery tracking status (manual/demo — no live carrier integration)."""
    row = await _get_order(db, order_id)
    # Both buyer and artisan can update delivery status (e.g. buyer confirms receipt)
    await _scope(db, user, row)

    valid = {'dispatched', 'in_transit', 'out_for_delivery', 'delivered'}
    if body.status not in valid:
        raise HTTPException(422, f'status must be one of: {", ".join(valid)}')

    payload = dict(row.payload or {})
    shipping: dict = payload.setdefault('shipping', {})
    shipping['status'] = body.status
    payload['shipment'] = body.status

    if body.status == 'delivered':
        row.status = 'delivered'
        payload['delivered_at'] = _now()
        # The buyer's inspection window starts at receipt, mirroring the engine.
        hours = _num(payload.get('inspection_hours'), 48)
        payload['inspection_deadline'] = (
            datetime.now(timezone.utc) + timedelta(hours=hours)).isoformat()
    elif body.status in ('dispatched', 'in_transit', 'out_for_delivery'):
        row.status = body.status

    _append_event(payload, f'Delivery status: {body.status}', user.role.value)

    row.payload = payload
    await db.commit()
    await db.refresh(row)
    return order_record(row)


class PayMilestoneBody(BaseModel):
    milestone_id: str
    reference: Optional[str] = None


@router.patch('/{order_id}/pay')
async def pay_milestone(
    order_id: str,
    body: PayMilestoneBody,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Buyer records an agreed milestone payment.

    A status record only — Aakar never holds or moves money. Each trigger has a
    precondition so a milestone cannot be paid before the work it covers.
    """
    row = await _get_order(db, order_id)
    if user.role != AccountRole.buyer or row.buyer_id != user.id:
        raise HTTPException(403, 'Only the buyer records payments')

    payload = dict(row.payload or {})
    milestones = [dict(m) for m in (payload.get('milestones') or [])]
    index = next(
        (i for i, m in enumerate(milestones) if m.get('id') == body.milestone_id),
        None,
    )
    if index is None:
        raise HTTPException(422, 'Unknown milestone')

    milestone = milestones[index]
    trigger = milestone.get('trigger')
    if trigger == 'checkpoint' and payload.get('checkpoint') != 'approved':
        raise HTTPException(422, 'Approve the progress review first')
    if trigger == 'dispatch' and payload.get('production') not in ('ready', 'dispatched'):
        raise HTTPException(422, 'Production must be ready for the dispatch milestone')
    if trigger == 'delivery' and payload.get('inspection') != 'accepted':
        raise HTTPException(422, 'Accept the delivery inspection before final settlement')

    milestone['status'] = 'confirmed'
    milestone['reference'] = body.reference or 'Simulated payment'
    milestone['confirmed_at'] = _now()
    milestone['mode'] = 'demo'
    milestones[index] = milestone
    payload['milestones'] = milestones
    _append_event(payload, f'{trigger} payment recorded · simulation', 'buyer')

    row.payload = payload
    await db.commit()
    await db.refresh(row)
    return order_record(row)


class InspectionBody(BaseModel):
    quantity: float
    note: Optional[str] = None


@router.patch('/{order_id}/inspection')
async def accept_inspection(
    order_id: str,
    body: InspectionBody,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Buyer accepts the delivered goods. A mismatch is an issue, not this."""
    row = await _get_order(db, order_id)
    if user.role != AccountRole.buyer or row.buyer_id != user.id:
        raise HTTPException(403, 'Only the buyer accepts the inspection')

    payload = dict(row.payload or {})
    if payload.get('shipment') != 'delivered':
        raise HTTPException(422, 'Confirm physical delivery first')
    if _num(body.quantity) != _num(payload.get('quantity')):
        raise HTTPException(422, 'Quantity mismatch: flag an issue for review')

    payload['inspection'] = 'accepted'
    payload['inspection_note'] = body.note or ''
    _append_event(payload, 'Buyer accepted inspection', 'buyer')

    row.payload = payload
    await db.commit()
    await db.refresh(row)
    return order_record(row)


@router.patch('/{order_id}/complete')
async def complete_order(
    order_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Buyer closes the order once delivery, inspection and settlement are done."""
    row = await _get_order(db, order_id)
    if user.role != AccountRole.buyer or row.buyer_id != user.id:
        raise HTTPException(403, 'Only the buyer completes the order')

    payload = dict(row.payload or {})
    if payload.get('status') == 'completed' or row.status == 'completed':
        return order_record(row)
    if payload.get('shipment') != 'delivered':
        raise HTTPException(422, 'Confirm physical delivery first')
    if payload.get('inspection') != 'accepted':
        raise HTTPException(422, 'Accept the delivery inspection first')
    unpaid = [m.get('trigger') for m in (payload.get('milestones') or [])
              if m.get('status') != 'confirmed']
    if unpaid:
        raise HTTPException(
            422, 'All agreed milestones must be settled first: ' + ', '.join(unpaid))

    row.status = 'completed'
    payload['status'] = 'completed'
    _append_event(payload, 'Order completed', 'buyer')

    # Completing the order consumes the advertised stock, as the engine does.
    listing = await db.scalar(select(ProductListing).where(
        ProductListing.product_id == row.product_id))
    if listing is not None:
        attributes = dict(listing.attributes or {})
        attributes['stock'] = max(
            0.0, _num(attributes.get('stock')) - _num(payload.get('quantity')))
        listing.attributes = attributes

    row.payload = payload
    await db.commit()
    await db.refresh(row)
    return order_record(row)
