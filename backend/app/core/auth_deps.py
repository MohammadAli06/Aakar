"""Shared FastAPI auth dependencies.

Strategy: the client sends its Firebase ID token as `Authorization: Bearer <token>`
on every request. The backend verifies it per call and resolves the owning
account. There is no second app-issued token — the Firebase ID token is the
credential, and `AccountRole` is the authorization boundary.
"""
import secrets
from typing import Optional

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.firebase_auth import verify_firebase_token
from app.models.models import AccountRole, Artisan, Buyer, User


def require_admin(authorization: str = Header(default='')) -> None:
    """Gate reviewer/admin endpoints behind the separate administrator token."""
    expected = settings.ADMIN_ACCESS_TOKEN
    if not expected or not secrets.compare_digest(authorization, 'Bearer ' + expected):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )


async def get_current_user(
    authorization: Optional[str] = Header(default=None),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Resolve the account from a verified Firebase ID token."""
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
        )

    token = authorization.split(" ", 1)[1].strip()
    try:
        claims = await verify_firebase_token(token)
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e))

    uid = claims.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Invalid identity")
    result = await db.execute(select(User).where(User.firebase_uid == uid))
    user = result.scalar_one_or_none()
    if user is None:
        phone = claims.get('phone_number')
        if phone and await db.scalar(select(User.id).where(User.phone == phone)):
            raise HTTPException(409, 'This phone number is already linked to an account. Contact support to recover access.')
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not registered. Complete signup first.",
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is disabled",
        )
    return user


async def require_artisan(
    user: User = Depends(get_current_user),
) -> User:
    if user.role != AccountRole.artisan:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This action requires an artisan account",
        )
    return user


async def require_buyer(
    user: User = Depends(get_current_user),
) -> User:
    if user.role != AccountRole.buyer:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This action requires a buyer account",
        )
    return user


async def require_artisan_profile(
    user: User = Depends(require_artisan),
    db: AsyncSession = Depends(get_db),
) -> Artisan:
    """Resolve (or lazily create) the Artisan profile row for the caller."""
    result = await db.execute(select(Artisan).where(Artisan.user_id == user.id))
    artisan = result.scalar_one_or_none()
    if artisan is None:
        artisan = Artisan(user_id=user.id)
        db.add(artisan)
        await db.commit()
        await db.refresh(artisan)
    return artisan


async def require_buyer_profile(
    user: User = Depends(require_buyer),
    db: AsyncSession = Depends(get_db),
) -> Buyer:
    """Resolve (or lazily create) the Buyer profile row for the caller."""
    result = await db.execute(select(Buyer).where(Buyer.user_id == user.id))
    buyer = result.scalar_one_or_none()
    if buyer is None:
        buyer = Buyer(user_id=user.id)
        db.add(buyer)
        await db.commit()
        await db.refresh(buyer)
    return buyer
