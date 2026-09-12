"""
Products Router — CRUD for products (artisan-owned).
"""
import uuid
from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import require_artisan_profile
from app.core.database import get_db
from app.models.models import Artisan, CraftCategory, Product, ProductStatus

router = APIRouter()


class ProductCreateRequest(BaseModel):
    category: str = "other"


class ProductResponse(BaseModel):
    id: str
    artisan_id: str
    category: str
    status: str
    created_at: datetime

    class Config:
        from_attributes = True


@router.post("/", response_model=ProductResponse)
async def create_product(
    data: ProductCreateRequest,
    artisan: Artisan = Depends(require_artisan_profile),
    db: AsyncSession = Depends(get_db),
):
    """Create a draft product owned by the authenticated artisan."""
    try:
        category = CraftCategory(data.category)
    except ValueError:
        raise HTTPException(status_code=422, detail="Unknown craft category")

    product = Product(
        id=str(uuid.uuid4()),
        artisan_id=artisan.id,
        category=category,
        status=ProductStatus.draft,
    )
    db.add(product)
    await db.commit()
    await db.refresh(product)
    return product


@router.get("/", response_model=List[ProductResponse])
async def list_my_products(
    artisan: Artisan = Depends(require_artisan_profile),
    db: AsyncSession = Depends(get_db),
):
    """List the authenticated artisan's own products."""
    result = await db.execute(select(Product).where(Product.artisan_id == artisan.id))
    return result.scalars().all()


@router.get("/{product_id}", response_model=ProductResponse)
async def get_product(
    product_id: str,
    artisan: Artisan = Depends(require_artisan_profile),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Product).where(Product.id == product_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    if product.artisan_id != artisan.id:
        raise HTTPException(status_code=403, detail="Not your product")
    return product
