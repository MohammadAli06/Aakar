"""
Pricing Router — Labour-aware, explainable pricing engine.
"""
import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from typing import Optional, List

from app.core.database import get_db
from app.models.models import PriceRecommendation, VerificationStatus
from app.services.pricing_service import compute_price_recommendation

router = APIRouter()


class PricingRequest(BaseModel):
    product_id: str
    craft_category: str
    material_cost: float
    labour_hours: float
    wage_per_hour: float
    overhead: float = 0.0
    craftsmanship_complexity: float = 0.5   # 0–1, artisan-reported


class ComparableItem(BaseModel):
    name: str
    price: float
    source: str


class PricingResponse(BaseModel):
    id: str
    product_id: str
    material_cost: float
    labour_cost: float
    overhead: float
    cost_floor: float
    craftsmanship_score: float
    recommended_min: float
    recommended_max: float
    explanation_text_en: str
    explanation_text_hi: str
    comparables: List[ComparableItem]
    verification_status: str


class SetFinalPriceRequest(BaseModel):
    product_id: str
    final_price: float
    artisan_action: str = "accept"


@router.post("/recommend", response_model=PricingResponse)
async def recommend_price(
    data: PricingRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Compute explainable price recommendation:
    - Cost floor = material + labour (hours × wage) + overhead
    - Market comparables: HANDMADE-ONLY (machine-made explicitly excluded)
    - Craftsmanship multiplier adjusts within market range
    - Explanation templated into plain language (EN + HI)
    """
    result = await compute_price_recommendation(
        craft_category=data.craft_category,
        material_cost=data.material_cost,
        labour_cost=data.labour_hours * data.wage_per_hour,
        overhead=data.overhead,
        craftsmanship_complexity=data.craftsmanship_complexity,
        db=db,
    )

    rec = PriceRecommendation(
        id=str(uuid.uuid4()),
        product_id=data.product_id,
        material_cost=data.material_cost,
        labour_cost=data.labour_hours * data.wage_per_hour,
        overhead=data.overhead,
        craftsmanship_score=result["craftsmanship_score"],
        comparable_ids=result["comparable_ids"],
        recommended_min=result["recommended_min"],
        recommended_max=result["recommended_max"],
        explanation_text_en=result["explanation_en"],
        explanation_text_hi=result["explanation_hi"],
        verification_status=VerificationStatus.ai_generated,
    )
    db.add(rec)
    await db.commit()
    await db.refresh(rec)

    cost_floor = data.material_cost + (data.labour_hours * data.wage_per_hour) + data.overhead
    return PricingResponse(
        id=rec.id,
        product_id=rec.product_id,
        material_cost=rec.material_cost,
        labour_cost=rec.labour_cost,
        overhead=rec.overhead,
        cost_floor=cost_floor,
        craftsmanship_score=rec.craftsmanship_score,
        recommended_min=rec.recommended_min,
        recommended_max=rec.recommended_max,
        explanation_text_en=rec.explanation_text_en,
        explanation_text_hi=rec.explanation_text_hi,
        comparables=result["comparables"],
        verification_status=rec.verification_status,
    )


@router.post("/set-final-price")
async def set_final_price(
    data: SetFinalPriceRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Artisan sets final price after reviewing the recommendation.
    Logged for trust + model improvement.
    """
    result = await db.execute(
        select(PriceRecommendation).where(PriceRecommendation.product_id == data.product_id)
    )
    rec = result.scalar_one_or_none()
    if not rec:
        raise HTTPException(status_code=404, detail="Price recommendation not found")

    rec.final_price = data.final_price
    rec.verification_status = VerificationStatus.approved

    # Log
    from app.models.models import VerificationLog
    log = VerificationLog(
        entity_type="price",
        entity_id=rec.id,
        artisan_id="",
        previous_status=VerificationStatus.ai_generated,
        new_status=VerificationStatus.approved,
        artisan_action=data.artisan_action,
        corrected_value={"final_price": data.final_price},
    )
    db.add(log)
    await db.commit()

    return {"status": "approved", "final_price": data.final_price}
