"""
Catalog Router — ASR → Attribute Extraction → Listing Generation pipeline.
Heavy inference calls are enqueued to Celery; lightweight transcript/extraction
can run inline for the demo.
"""
import uuid
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from typing import Optional, List, Dict, Any

from app.core.auth_deps import require_artisan_profile
from app.core.database import get_db
from app.core.ownership import load_owned_product
from app.services.asr_service import transcribe_audio
from app.services.extraction_service import extract_attributes_with_confidence
from app.services.generation_service import generate_bilingual_listing
from app.models.models import Artisan, Product, ProductListing, VerificationStatus

router = APIRouter()


class TranscribeResponse(BaseModel):
    transcript: str
    language_detected: str


class AttributeField(BaseModel):
    key: str
    label_en: str
    label_hi: str
    value: Optional[str]
    confidence: float
    is_required: bool


class ExtractionResponse(BaseModel):
    attributes: List[AttributeField]
    missing_required: List[str]


class ListingGenerateRequest(BaseModel):
    product_id: str
    attributes: Dict[str, Any]
    artisan_name: str
    craft_category: str


class ListingResponse(BaseModel):
    id: str
    product_id: str
    title_en: str
    title_hi: str
    desc_en: str
    desc_hi: str
    tags: List[str]
    craft_terms: List[str]
    verification_status: str


class VerifyListingRequest(BaseModel):
    product_id: str
    artisan_action: str   # accept | edit | reject
    corrected_listing: Optional[dict] = None


async def _owned_product(db: AsyncSession, product_id: str, artisan: Artisan) -> Product:
    return await load_owned_product(db, product_id, artisan)


@router.post("/transcribe")
async def transcribe(
    audio: UploadFile = File(...),
    language: str = Form(default="hi"),
    artisan: Artisan = Depends(require_artisan_profile),
):
    """
    Upload audio → return transcript via Bhashini / IndicConformer.
    """
    audio_bytes = await audio.read()
    try:
        transcript = await transcribe_audio(audio_bytes, language)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"ASR error: {e}")
    return TranscribeResponse(transcript=transcript, language_detected=language)


@router.post("/extract", response_model=ExtractionResponse)
async def extract_attributes(
    transcript: str,
    craft_category: str = "other",
    artisan: Artisan = Depends(require_artisan_profile),
):
    """
    Transcript → attribute extraction with per-field confidence scores.
    The confidence score drives which fields are asked as follow-up questions.
    """
    attributes, missing = await extract_attributes_with_confidence(transcript, craft_category)
    return ExtractionResponse(attributes=attributes, missing_required=missing)


@router.post("/generate-listing", response_model=ListingResponse)
async def generate_listing(
    data: ListingGenerateRequest,
    artisan: Artisan = Depends(require_artisan_profile),
    db: AsyncSession = Depends(get_db),
):
    """
    Attributes → bilingual listing (EN + HI), craft-term preserving.
    Listing is initially ai_generated; artisan must approve before publish.
    """
    product = await _owned_product(db, data.product_id, artisan)

    listing_data = await generate_bilingual_listing(
        data.attributes,
        data.artisan_name,
        data.craft_category,
    )

    listing = ProductListing(
        id=str(uuid.uuid4()),
        product_id=data.product_id,
        title_en=listing_data["title_en"],
        title_hi=listing_data["title_hi"],
        desc_en=listing_data["desc_en"],
        desc_hi=listing_data["desc_hi"],
        attributes=data.attributes,
        tags=listing_data["tags"],
        craft_terms=listing_data["craft_terms"],
        verification_status=VerificationStatus.ai_generated,
    )
    db.add(listing)
    await db.commit()
    await db.refresh(listing)
    return listing


@router.post("/verify-listing")
async def verify_listing(
    data: VerifyListingRequest,
    artisan: Artisan = Depends(require_artisan_profile),
    db: AsyncSession = Depends(get_db),
):
    """
    Artisan approve / edit / reject the AI-generated listing.
    Nothing publishes until this step is completed with 'accept'.
    Logs the artisan action to VerificationLog.
    """
    from app.models.models import VerificationLog

    await _owned_product(db, data.product_id, artisan)

    result = await db.execute(
        select(ProductListing).where(ProductListing.product_id == data.product_id)
    )
    listing = result.scalar_one_or_none()
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")

    prev_status = listing.verification_status

    if data.artisan_action == "accept":
        listing.verification_status = VerificationStatus.approved
    elif data.artisan_action == "edit":
        if data.corrected_listing:
            listing.title_en = data.corrected_listing.get("title_en", listing.title_en)
            listing.title_hi = data.corrected_listing.get("title_hi", listing.title_hi)
            listing.desc_en = data.corrected_listing.get("desc_en", listing.desc_en)
            listing.desc_hi = data.corrected_listing.get("desc_hi", listing.desc_hi)
        listing.verification_status = VerificationStatus.artisan_reviewed
    elif data.artisan_action == "reject":
        listing.verification_status = VerificationStatus.rejected
    else:
        raise HTTPException(status_code=422, detail="artisan_action must be accept, edit or reject")

    # Log the action against the authenticated artisan
    log = VerificationLog(
        entity_type="listing",
        entity_id=listing.id,
        artisan_id=artisan.id,
        previous_status=prev_status,
        new_status=listing.verification_status,
        artisan_action=data.artisan_action,
        corrected_value=data.corrected_listing,
    )
    db.add(log)
    await db.commit()

    return {"status": listing.verification_status, "listing_id": listing.id}
