"""
Requirements Router — buyer-posted demand, owned by the signed-in account.

A requirement is what a buyer needs (quantity, budget, lead time, destination)
plus the buyer's own words. Posting one is not an order and commits nobody:
matching, capacity confirmation and quoting are separate steps, and the artisan
still has to confirm.
"""
import re
import uuid
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from fastapi.responses import FileResponse
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import require_buyer
from app.core.database import get_db
from app.models.models import Requirement, User
from app.services import image_store

router = APIRouter()

MEDIA = Path(__file__).parents[2] / 'uploads' / 'requirements'

STATUSES = ("open", "closed")


class RequirementDraft(BaseModel):
    """The structured requirement Product Studio's review step produces."""

    model_config = ConfigDict(str_strip_whitespace=True)

    product: str = Field(min_length=1, max_length=2000)
    quantity: float = Field(gt=0)
    lead_days: float = Field(gt=0)
    location: str = Field(min_length=1, max_length=300)
    original: Optional[str] = None
    budget: Optional[float] = 0
    target_date: Optional[str] = None
    customization: Optional[str] = None
    specifications: Optional[str] = None
    packaging: Optional[str] = None
    reference_image: Optional[str] = None
    sample_required: bool = False
    confirmed: bool = False


def requirement_record(requirement: Requirement, buyer: Optional[User] = None,
                      business_name: Optional[str] = None) -> dict:
    """The flat record the marketplace screens already render."""
    return {
        'id': requirement.id,
        'buyer_id': requirement.buyer_id,
        'product': requirement.product,
        'original': requirement.original,
        'quantity': requirement.quantity,
        'budget': requirement.budget or 0,
        'lead_days': requirement.lead_days,
        'location': requirement.location,
        'target_date': requirement.target_date,
        'customization': requirement.customization,
        'specifications': requirement.specifications,
        'packaging': requirement.packaging,
        'reference_image': requirement.reference_image,
        'sample_required': bool(requirement.sample_required),
        'status': requirement.status,
        'time': requirement.created_at.isoformat() if requirement.created_at else None,
        'buyer_name': buyer.name if buyer else None,
        'business_name': business_name,
    }


@router.post('/', status_code=200)
async def post_requirement(
    data: RequirementDraft,
    user: User = Depends(require_buyer),
    db: AsyncSession = Depends(get_db),
):
    """Post a requirement. The buyer must have reviewed and confirmed it."""
    if not data.confirmed:
        raise HTTPException(status_code=422,
                            detail='Review and confirm the requirement before posting')
    requirement = Requirement(
        id=str(uuid.uuid4()),
        buyer_id=user.id,
        product=data.product,
        original=data.original,
        quantity=data.quantity,
        budget=data.budget or 0,
        lead_days=data.lead_days,
        location=data.location,
        target_date=data.target_date,
        customization=data.customization,
        specifications=data.specifications,
        packaging=data.packaging,
        reference_image=data.reference_image,
        sample_required=data.sample_required,
        status='open',
    )
    db.add(requirement)
    await db.commit()
    await db.refresh(requirement)
    return requirement_record(requirement, user)


@router.get('/')
async def list_my_requirements(
    user: User = Depends(require_buyer),
    db: AsyncSession = Depends(get_db),
):
    """Every requirement posted by the authenticated buyer, newest first."""
    rows = (await db.scalars(select(Requirement).where(
        Requirement.buyer_id == user.id).order_by(Requirement.created_at.desc()))).all()
    return [requirement_record(row, user) for row in rows]


@router.post('/images')
async def upload_reference_image(
    file: UploadFile = File(...),
    _user: User = Depends(require_buyer),
):
    """Store the buyer's reference image and return the path to attach.

    Relative on purpose, like the catalogue photos: the client resolves it
    against its own API base URL.
    """
    name = image_store.store_photo(
        await file.read(image_store.MAX_BYTES + 1), MEDIA, 'reference image')
    return {'path': f'/api/v1/requirements/images/{name}'}


@router.get('/images/{name}')
async def reference_image(name: str):
    """Public-read under an unguessable filename, like catalogue photos.

    An artisan needs to see the reference image when matching the requirement.
    """
    if not re.fullmatch(r'[a-f0-9]{32}\.jpg', name) or not (MEDIA / name).is_file():
        raise HTTPException(status_code=404, detail='Image not found')
    return FileResponse(MEDIA / name, media_type='image/jpeg',
                        headers={'Cache-Control': 'public, max-age=300'})


@router.get('/{requirement_id}')
async def get_requirement(
    requirement_id: str,
    user: User = Depends(require_buyer),
    db: AsyncSession = Depends(get_db),
):
    requirement = await db.get(Requirement, requirement_id)
    if requirement is None:
        raise HTTPException(status_code=404, detail='Requirement not found')
    if requirement.buyer_id != user.id:
        raise HTTPException(status_code=403, detail='Not your requirement')
    return requirement_record(requirement, user)
