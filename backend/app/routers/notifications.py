"""
Notifications Router — the signed-in account's own notification list.

A notification belongs to one recipient and is created by the other participant
acting on something shared. Kept account-scoped so it survives a refresh, rather
than living only in the device's local demo state.
"""
from typing import Any, Dict

from fastapi import APIRouter, Depends
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user
from app.core.database import get_db
from app.models.models import Notification, User

router = APIRouter()


def notification_record(row: Notification) -> Dict[str, Any]:
    """The flat record the alerts list already renders."""
    return {
        'id': row.id,
        # The commerce workspace filters by account for server rows and by the
        # role's actor id for device-local demo rows, so both are supplied.
        'account_id': row.recipient_id,
        'actor_id': row.recipient_id,
        'role': row.role,
        'title': row.title,
        'link': row.link,
        'category': row.category,
        'read': bool(row.read),
        'time': row.created_at.isoformat() if row.created_at else None,
        'server': True,
    }


@router.get('/')
async def list_my_notifications(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Every notification for this account, newest first."""
    rows = (await db.scalars(select(Notification).where(
        Notification.recipient_id == user.id).order_by(
        Notification.created_at.desc()))).all()
    return [notification_record(row) for row in rows]


@router.post('/read')
async def mark_all_read(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Mark this account's notifications read. Only the recipient's own rows."""
    await db.execute(update(Notification).where(
        Notification.recipient_id == user.id).values(read=True))
    await db.commit()
    rows = (await db.scalars(select(Notification).where(
        Notification.recipient_id == user.id).order_by(
        Notification.created_at.desc()))).all()
    return [notification_record(row) for row in rows]
