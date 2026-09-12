"""
Firebase identity and registration with a fixed account role.
Authorization resolves the registered role and ownership from the database.
"""
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user, require_artisan, require_buyer
from app.core.database import get_db
from app.core.firebase_auth import set_role_claim, verify_firebase_token
from app.models.models import AccountRole, AccountVerification, Artisan, Buyer, CraftCategory, User

router = APIRouter()


class ProfilePayload(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")


class ArtisanProfilePayload(ProfilePayload):
    name: Optional[str] = Field(default=None, min_length=1, max_length=200)
    language_pref: Optional[str] = Field(default=None, pattern='^(en|hi)$')
    state: Optional[str] = Field(default=None, min_length=1, max_length=100)
    district: Optional[str] = Field(default=None, min_length=1, max_length=100)
    craft_category: Optional[str] = None


class BuyerProfilePayload(ProfilePayload):
    name: Optional[str] = Field(default=None, min_length=1, max_length=200)
    language_pref: Optional[str] = Field(default=None, pattern='^(en|hi)$')
    business_name: Optional[str] = Field(default=None, min_length=1, max_length=200)
    business_type: Optional[str] = Field(default=None, min_length=1, max_length=100)
    industry: Optional[str] = Field(default=None, min_length=1, max_length=100)
    state: Optional[str] = Field(default=None, min_length=1, max_length=100)
    district: Optional[str] = Field(default=None, min_length=1, max_length=100)


class AccountResponse(BaseModel):
    id: str
    firebase_uid: str
    role: str
    name: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    language_pref: str
    is_new: bool = False
    profile: Optional[dict] = None


def _artisan_profile(artisan: Optional[Artisan]) -> Optional[dict]:
    if artisan is None:
        return None
    return {
        "id": artisan.id,
        "state": artisan.state,
        "district": artisan.district,
        "craft_category": artisan.craft_category.value,
        "is_verified": artisan.is_verified,
    }


def _buyer_profile(buyer: Optional[Buyer]) -> Optional[dict]:
    if buyer is None:
        return None
    return {
        "id": buyer.id,
        "business_name": buyer.business_name,
        "business_type": buyer.business_type,
        "industry": buyer.industry,
        "state": buyer.state,
        "district": buyer.district,
        "is_verified": buyer.is_verified,
    }


async def _account_payload(
    db: AsyncSession, user: User, is_new: bool = False
) -> AccountResponse:
    if user.role == AccountRole.artisan:
        result = await db.execute(select(Artisan).where(Artisan.user_id == user.id))
        profile = _artisan_profile(result.scalar_one_or_none())
    else:
        result = await db.execute(select(Buyer).where(Buyer.user_id == user.id))
        profile = _buyer_profile(result.scalar_one_or_none())

    return AccountResponse(
        id=user.id,
        firebase_uid=user.firebase_uid,
        role=user.role.value,
        name=user.name,
        phone=user.phone,
        email=user.email,
        language_pref=user.language_pref,
        is_new=is_new,
        profile=profile,
    )


@router.post("/verify-token", response_model=AccountResponse)
async def verify_token_and_get_account(
    role: str = Query(..., description="Initial role: artisan | buyer"),
    authorization: Optional[str] = Header(default=None),
    db: AsyncSession = Depends(get_db),
):
    """
    Verify a Firebase ID token and create the account on first login.

    The token is read from `Authorization: Bearer <token>`. Existing accounts
    retain their registered role even if a different role is requested.
    """
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization header with Firebase ID token",
        )
    token = authorization.split(" ", 1)[1].strip()

    try:
        requested_role = AccountRole(role)
    except ValueError:
        raise HTTPException(status_code=422, detail="role must be 'artisan' or 'buyer'")

    try:
        decoded = await verify_firebase_token(token)
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e))

    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Invalid identity")
    result = await db.execute(select(User).where(User.firebase_uid == uid))
    user = result.scalar_one_or_none()

    if user is not None:
        if not user.is_active:
            raise HTTPException(status_code=403, detail="Account is disabled")
        return await _account_payload(db, user, is_new=False)

    if not decoded.get("phone_number"):
        raise HTTPException(status_code=422, detail="Verify your phone number before creating an account")

    if await db.scalar(select(User.id).where(User.phone == decoded['phone_number'])):
        raise HTTPException(409, 'This phone number is already linked to an account. Contact support to recover access.')

    user = User(
        firebase_uid=uid,
        role=requested_role,
        name=None,
        phone=decoded.get("phone_number"),
        email=decoded.get("email"),
        language_pref="hi",
    )
    db.add(user)
    await db.flush()

    if requested_role == AccountRole.artisan:
        db.add(Artisan(user_id=user.id))
    else:
        db.add(Buyer(user_id=user.id))

    await db.commit()
    await db.refresh(user)
    set_role_claim(uid, requested_role.value)
    return await _account_payload(db, user, is_new=True)


class RolePayload(BaseModel):
    role: AccountRole


@router.put("/role", response_model=AccountResponse)
async def select_role(data: RolePayload, user: User = Depends(get_current_user),
                      db: AsyncSession = Depends(get_db)):
    """Compatibility endpoint: registered accounts cannot select another role."""
    if data.role != user.role:
        raise HTTPException(409, 'This phone number already has a registered role.')
    return await _account_payload(db, user)


async def invalidate_review(db, user, data, profile):
    """Material profile corrections require a fresh review of the affected role."""
    changes = data.model_dump(exclude_none=True)
    name_changed = 'name' in changes and changes['name'] != user.name
    changed = name_changed or any(
        key not in ('name', 'language_pref') and value != getattr(profile, key, None)
        for key, value in changes.items())
    if not changed:
        return
    records = (await db.scalars(select(AccountVerification).where(
        AccountVerification.user_id == user.id))).all()
    for record in records:
        if (name_changed or record.role == user.role.value) and record.status in ('pending', 'verified'):
            record.status = 'needs_correction'
            record.review_note = 'Profile updated. Please review your documents and submit again.'
            model = Artisan if record.role == 'artisan' else Buyer
            affected = await db.scalar(select(model).where(model.user_id == user.id))
            if affected:
                affected.is_verified = False


@router.get("/me", response_model=AccountResponse)
async def get_me(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return the authenticated account and its role-specific profile."""
    return await _account_payload(db, user)


@router.put("/artisan-profile", response_model=AccountResponse)
async def update_artisan_profile(
    data: ArtisanProfilePayload,
    user: User = Depends(require_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Update the artisan profile. Only the artisan account itself can call this."""
    result = await db.execute(select(Artisan).where(Artisan.user_id == user.id))
    artisan = result.scalar_one_or_none()
    if artisan is None:
        artisan = Artisan(user_id=user.id)
        db.add(artisan)

    await invalidate_review(db, user, data, artisan)
    if data.name is not None:
        user.name = data.name
    if data.language_pref is not None:
        user.language_pref = data.language_pref

    if data.state is not None:
        artisan.state = data.state
    if data.district is not None:
        artisan.district = data.district
    if data.craft_category is not None:
        try:
            artisan.craft_category = CraftCategory(data.craft_category)
        except ValueError:
            raise HTTPException(status_code=422, detail="Unknown craft category")

    await db.commit()
    await db.refresh(user)
    return await _account_payload(db, user)


@router.put("/buyer-profile", response_model=AccountResponse)
async def update_buyer_profile(
    data: BuyerProfilePayload,
    user: User = Depends(require_buyer),
    db: AsyncSession = Depends(get_db),
):
    """Update the buyer profile. Only the buyer account itself can call this."""
    result = await db.execute(select(Buyer).where(Buyer.user_id == user.id))
    buyer = result.scalar_one_or_none()
    if buyer is None:
        buyer = Buyer(user_id=user.id)
        db.add(buyer)

    await invalidate_review(db, user, data, buyer)
    if data.name is not None:
        user.name = data.name
    if data.language_pref is not None:
        user.language_pref = data.language_pref

    if data.business_name is not None:
        buyer.business_name = data.business_name
    if data.business_type is not None:
        buyer.business_type = data.business_type
    if data.industry is not None:
        buyer.industry = data.industry
    if data.state is not None:
        buyer.state = data.state
    if data.district is not None:
        buyer.district = data.district

    await db.commit()
    await db.refresh(user)
    return await _account_payload(db, user)
