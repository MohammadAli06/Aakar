"""
Products Router — CRUD for products.
"""
import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

from app.core.database import get_db
from app.models.models import Product, ProductStatus, CraftCategory

router = APIRouter()


class ProductCreateRequest(BaseModel):
    artisan_id: str
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
    db: AsyncSession = Depends(get_db),
):
    """Create a new product (draft). Called when artisan starts a new listing flow."""
    product = Product(
        id=str(uuid.uuid4()),
        artisan_id=data.artisan_id,
        category=CraftCategory(data.category),
        status=ProductStatus.draft,
    )
    db.add(product)
    await db.commit()
    await db.refresh(product)
    return product


@router.get("/{product_id}", response_model=ProductResponse)
async def get_product(product_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Product).where(Product.id == product_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return product


@router.get("/artisan/{artisan_id}", response_model=List[ProductResponse])
async def list_artisan_products(artisan_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Product).where(Product.artisan_id == artisan_id))
    return result.scalars().all()
