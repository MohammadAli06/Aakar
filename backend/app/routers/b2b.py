"""
B2B Router — Requirement gap checking & marketplace linkage.
"""
import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from typing import List, Optional, Dict, Any

from app.core.database import get_db
from app.models.models import B2BChannel, B2BReadiness, B2BStatus

router = APIRouter()

# Hardcoded demo channel requirement templates
# In production: loaded from DB + configurable per channel
DEMO_CHANNELS = {
    "gem": {
        "name": "GeM Portal",
        "name_hi": "सरकारी ई-मार्केट",
        "requirements": {
            "product_title": {"required": True, "label": "Product Title"},
            "product_description": {"required": True, "label": "Description (min 100 chars)"},
            "price": {"required": True, "label": "Listed Price"},
            "gst_number": {"required": True, "label": "GST Registration Number"},
            "moq": {"required": True, "label": "Minimum Order Quantity"},
            "production_capacity": {"required": True, "label": "Monthly Production Capacity"},
            "category": {"required": True, "label": "Product Category"},
            "images": {"required": True, "label": "Minimum 3 product images"},
        }
    },
    "ondc": {
        "name": "ONDC Network",
        "name_hi": "राष्ट्रीय डिजिटल व्यापार",
        "requirements": {
            "product_title": {"required": True, "label": "Product Title"},
            "description": {"required": True, "label": "Product Description"},
            "price": {"required": True, "label": "MRP"},
            "hsn_code": {"required": True, "label": "HSN Code"},
            "category": {"required": True, "label": "Category"},
            "images": {"required": True, "label": "Product Images"},
            "fulfillment_type": {"required": False, "label": "Delivery Type"},
        }
    },
    "state_board": {
        "name": "State Handicraft Board",
        "name_hi": "राज्य हस्तशिल्प बोर्ड",
        "requirements": {
            "product_title": {"required": True, "label": "Product Name"},
            "craft_category": {"required": True, "label": "Craft Category"},
            "origin_state": {"required": True, "label": "State of Origin"},
            "artisan_name": {"required": True, "label": "Artisan Name"},
            "price": {"required": True, "label": "Asking Price"},
            "gi_tag": {"required": False, "label": "GI Tag (if applicable)"},
        }
    }
}


class ReadinessCheckRequest(BaseModel):
    product_id: str
    channel_id: str
    available_fields: Dict[str, Any]   # fields artisan has already filled


class MissingFieldItem(BaseModel):
    key: str
    label: str
    required: bool
    prompt_hi: str
    prompt_en: str


class ReadinessResponse(BaseModel):
    product_id: str
    channel_id: str
    channel_name: str
    readiness_score: float
    missing_fields: List[MissingFieldItem]
    status: str


class FillFieldRequest(BaseModel):
    product_id: str
    channel_id: str
    field_key: str
    value: Any


@router.get("/channels")
async def list_channels():
    """List all available B2B channels with their names and descriptions."""
    return [
        {
            "id": ch_id,
            "name": ch["name"],
            "name_hi": ch["name_hi"],
            "field_count": len(ch["requirements"]),
        }
        for ch_id, ch in DEMO_CHANNELS.items()
    ]


@router.post("/check-readiness", response_model=ReadinessResponse)
async def check_readiness(
    data: ReadinessCheckRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Rule-engine check: given available fields vs. channel requirements.
    Returns a readiness score and plain-language prompts for each gap.
    """
    channel = DEMO_CHANNELS.get(data.channel_id)
    if not channel:
        raise HTTPException(status_code=404, detail="Channel not found")

    requirements = channel["requirements"]
    missing: List[MissingFieldItem] = []
    total_required = sum(1 for r in requirements.values() if r["required"])
    filled_required = 0

    for key, req in requirements.items():
        if key not in data.available_fields or not data.available_fields[key]:
            missing.append(MissingFieldItem(
                key=key,
                label=req["label"],
                required=req["required"],
                prompt_hi=f"कृपया '{req['label']}' भरें",
                prompt_en=f"Please provide: {req['label']}",
            ))
        elif req["required"]:
            filled_required += 1

    readiness = filled_required / total_required if total_required > 0 else 1.0

    # Persist to DB
    result = await db.execute(
        select(B2BReadiness).where(
            B2BReadiness.product_id == data.product_id,
            B2BReadiness.channel_id == data.channel_id,
        )
    )
    readiness_record = result.scalar_one_or_none()

    if readiness_record is None:
        readiness_record = B2BReadiness(
            id=str(uuid.uuid4()),
            product_id=data.product_id,
            channel_id=data.channel_id,
            missing_fields=[m.key for m in missing],
            provided_fields=data.available_fields,
            readiness_score=readiness,
            status=B2BStatus.ready if readiness >= 0.85 else B2BStatus.in_progress,
        )
        db.add(readiness_record)
    else:
        readiness_record.missing_fields = [m.key for m in missing]
        readiness_record.provided_fields = data.available_fields
        readiness_record.readiness_score = readiness
        readiness_record.status = B2BStatus.ready if readiness >= 0.85 else B2BStatus.in_progress

    await db.commit()

    return ReadinessResponse(
        product_id=data.product_id,
        channel_id=data.channel_id,
        channel_name=channel["name"],
        readiness_score=readiness,
        missing_fields=missing,
        status=readiness_record.status,
    )


@router.post("/connect")
async def connect_to_channel(
    product_id: str,
    channel_id: str,
    db: AsyncSession = Depends(get_db),
):
    """
    Trigger B2B connection request — packages the listing and submits to channel.
    In production: calls the actual GeM/ONDC API or submits to a portal queue.
    """
    result = await db.execute(
        select(B2BReadiness).where(
            B2BReadiness.product_id == product_id,
            B2BReadiness.channel_id == channel_id,
        )
    )
    rec = result.scalar_one_or_none()
    if not rec:
        raise HTTPException(status_code=404, detail="Run readiness check first")
    if rec.readiness_score < 0.6:
        raise HTTPException(
            status_code=400,
            detail=f"Readiness score {rec.readiness_score:.0%} is too low. Fill missing fields first."
        )

    # Simulate submission
    return {
        "status": "prepared_demo",
        "channel": DEMO_CHANNELS[channel_id]["name"],
        "message": "Demo preparation complete. No submission was made to the external channel. Follow the channel's official onboarding process.",
        "message_hi": "डेमो तैयारी पूरी हुई। बाहरी चैनल पर सबमिशन नहीं हुआ। आधिकारिक ऑनबोर्डिंग प्रक्रिया पूरी करें।",
    }
