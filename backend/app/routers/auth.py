"""
Auth Router — Firebase token verification + artisan profile creation.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from typing import Optional

from app.core.database import get_db
from app.models.models import Artisan, CraftCategory
from app.core.firebase_auth import verify_firebase_token

router = APIRouter()


class ArtisanCreateRequest(BaseModel):
    name: str
    language_pref: str = "hi"
    state: Optional[str] = None
    district: Optional[str] = None
    craft_category: str = "other"


class ArtisanResponse(BaseModel):
    id: str
    firebase_uid: str
    name: str
    phone: str
    language_pref: str
    state: Optional[str]
    craft_category: str
    is_new: bool = False

    class Config:
        from_attributes = True


@router.post("/verify-token", response_model=ArtisanResponse)
async def verify_token_and_get_artisan(
    token: str,
    db: AsyncSession = Depends(get_db),
):
    """
    Verify Firebase ID token, create artisan if first login.
    Flutter calls this after phone OTP verification.
    """
    try:
        decoded = await verify_firebase_token(token)
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e))

    uid = decoded.get("uid")
    phone = decoded.get("phone_number", "")

    # Check if artisan exists
    result = await db.execute(select(Artisan).where(Artisan.firebase_uid == uid))
    artisan = result.scalar_one_or_none()

    if artisan is None:
        # New user — create with phone
        artisan = Artisan(firebase_uid=uid, name="", phone=phone)
        db.add(artisan)
        await db.commit()
        await db.refresh(artisan)
        return {**artisan.__dict__, "is_new": True}

    return {**artisan.__dict__, "is_new": False}


@router.put("/profile", response_model=ArtisanResponse)
async def update_profile(
    data: ArtisanCreateRequest,
    uid: str,  # In production: extract from JWT
    db: AsyncSession = Depends(get_db),
):
    """Update artisan profile (name, craft category, location)."""
    result = await db.execute(select(Artisan).where(Artisan.firebase_uid == uid))
    artisan = result.scalar_one_or_none()
    if not artisan:
        raise HTTPException(status_code=404, detail="Artisan not found")

    artisan.name = data.name
    artisan.language_pref = data.language_pref
    artisan.state = data.state
    artisan.district = data.district
    artisan.craft_category = CraftCategory(data.craft_category)
    await db.commit()
    await db.refresh(artisan)
    return artisan
