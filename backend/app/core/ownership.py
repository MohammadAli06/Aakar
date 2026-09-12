"""Ownership helpers — a product is only ever reachable by its owning artisan."""
from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.models import Artisan, Product


async def load_owned_product(
    db: AsyncSession, product_id: str, artisan: Artisan
) -> Product:
    """Load a product and assert it belongs to the calling artisan."""
    result = await db.execute(select(Product).where(Product.id == product_id))
    product = result.scalar_one_or_none()
    if product is None:
        raise HTTPException(status_code=404, detail="Product not found")
    if product.artisan_id != artisan.id:
        raise HTTPException(status_code=403, detail="Not your product")
    return product
