"""
Products Router — the artisan product catalogue.

A saved product is one `Product` row plus its `ProductListing`, its
`PriceRecommendation` and its `ProductImage`s, all owned by the authenticated
artisan. Saving never publishes; `POST /{id}/publish` is the separate,
explicit step, and readiness is re-checked here rather than trusted from the app.

The artisan app speaks a flat record shape, so `_record` serializes a product
back into that shape and screens need no separate DTO.
"""
import re
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from fastapi.responses import FileResponse
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import require_artisan_profile
from app.core.database import get_db
from app.core.ownership import load_owned_product
from app.models.models import (
    Artisan, CraftCategory, PriceRecommendation, Product, ProductImage,
    ProductListing, ProductModeration, ProductStatus, User, VerificationLog,
    VerificationStatus,
)
from app.services import image_store
from app.services.pricing_service import compute_price_recommendation

router = APIRouter()

MEDIA = Path(__file__).parents[2] / 'uploads' / 'products'

# Studio labels → stored enum. `Baskets`/`Textiles` have no dedicated value yet,
# so they fall back to weaving; the label the artisan chose is kept verbatim in
# `attributes["ui_category"]` and is what the app and console display.
CATEGORY_BY_LABEL = {
    'pottery': CraftCategory.pottery,
    'weaving': CraftCategory.weaving,
    'embroidery': CraftCategory.embroidery,
    'woodcraft': CraftCategory.woodcraft,
    'metalcraft': CraftCategory.metalcraft,
    'painting': CraftCategory.painting,
    'leathercraft': CraftCategory.leathercraft,
    'jewelry': CraftCategory.jewelry,
    'other': CraftCategory.other,
    'baskets': CraftCategory.weaving,
    'textiles': CraftCategory.weaving,
}

# Product facts that have no column of their own, kept on the listing JSON.
ATTRIBUTE_KEYS = (
    'craft', 'material', 'colour', 'dimensions', 'usage', 'story', 'location',
    'moq', 'stock', 'capacity', 'lead_days', 'available', 'customizable',
    'fragile', 'can_pack', 'ui_category',
    'prepared', 'catalog_plain_background', 'photo_provider', 'photo_reviewed',
)


def _craft_category(value: Optional[str]) -> CraftCategory:
    return CATEGORY_BY_LABEL.get((value or '').strip().lower(), CraftCategory.other)


def _num(value: Any, fallback: float = 0.0) -> float:
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        return fallback
    return parsed if parsed == parsed and parsed not in (float('inf'), float('-inf')) else fallback


def _text(value: Any) -> str:
    return '' if value is None else str(value).strip()


def _place(state, district) -> Optional[str]:
    parts = [part for part in (district, state) if part]
    return ', '.join(parts) if parts else None


def _iso(value: Optional[datetime]) -> Optional[str]:
    return value.isoformat() if value else None


class ProductDraft(BaseModel):
    """Everything Product Studio can hand over. Only facts the artisan entered."""

    category: str = 'Other'
    title: Optional[str] = None
    title_hi: Optional[str] = None
    description: Optional[str] = None
    description_hi: Optional[str] = None
    craft: Optional[str] = None
    material: Optional[str] = None
    colour: Optional[str] = None
    dimensions: Optional[str] = None
    usage: Optional[str] = None
    story: Optional[str] = None
    location: Optional[str] = None
    price: Optional[float] = None
    material_cost: Optional[float] = None
    labour_cost: Optional[float] = None
    labour_hours: Optional[float] = None
    hourly_rate: Optional[float] = None
    overhead: Optional[float] = None
    complexity: Optional[float] = None
    moq: Optional[float] = None
    stock: Optional[float] = None
    capacity: Optional[float] = None
    lead_days: Optional[float] = None
    available: Optional[bool] = None
    customizable: Optional[bool] = None
    fragile: Optional[bool] = None
    can_pack: Optional[bool] = None
    image: Optional[str] = None
    original_image: Optional[str] = None
    prepared: Optional[str] = None
    catalog_plain_background: Optional[bool] = None
    photo_provider: Optional[str] = None
    photo_reviewed: Optional[bool] = None
    transcript: Optional[str] = None
    approved: bool = False


def _attributes_from(draft: ProductDraft, existing: Optional[dict] = None) -> Dict[str, Any]:
    """Merge the draft's product facts onto the listing's JSON attributes."""
    attributes = dict(existing or {})
    for key in ATTRIBUTE_KEYS:
        value = getattr(draft, key, None)
        if value is not None:
            attributes[key] = value
    attributes['ui_category'] = _text(draft.category) or attributes.get('ui_category') or 'Other'
    if _text(draft.original_image):
        attributes['original_image'] = draft.original_image
    if _text(draft.image):
        attributes['image'] = draft.image
    return attributes


def _labour_cost(draft: ProductDraft) -> float:
    """Explicit labour cost wins; otherwise hours × rate, as Product Studio computes it."""
    if draft.labour_cost is not None:
        return _num(draft.labour_cost)
    return _num(draft.labour_hours) * _num(draft.hourly_rate)


def _cost_floor(price: Optional[PriceRecommendation]) -> float:
    if price is None:
        return 0.0
    return _num(price.material_cost) + _num(price.labour_cost) + _num(price.overhead)


def _readiness(product, listing, price, attributes) -> List[str]:
    """Mirror of the app's CommerceEngine.readiness, enforced server-side."""
    missing: List[str] = []
    if not _text(listing.title_en if listing else None):
        missing.append('title')
    if not _text(listing.desc_en if listing else None):
        missing.append('description')
    if not _text(attributes.get('image')):
        missing.append('image')
    if attributes.get('photo_provider') in ('gemini', 'openai') and attributes.get('photo_reviewed') is not True:
        missing.append('photo review')
    if not _text(attributes.get('location')):
        missing.append('location')
    if not _text(attributes.get('ui_category')):
        missing.append('category')
    floor = _cost_floor(price)
    if floor <= 0 or _num(price.final_price) <= 0:
        missing.append('price')
    for key in ('moq', 'lead_days'):
        if _num(attributes.get(key)) <= 0:
            missing.append(key)
    for key in ('stock', 'capacity'):
        if key not in attributes or _num(attributes.get(key)) < 0:
            missing.append(key)
    if _num(attributes.get('stock')) + _num(attributes.get('capacity')) <= 0:
        missing.append('stock or production capacity')
    for key in ('available', 'customizable'):
        if not isinstance(attributes.get(key), bool):
            missing.append(key)
    if listing is None or listing.verification_status != VerificationStatus.approved:
        missing.append('artisan approval')
    if _num(price.final_price) < floor:
        missing.append('price below cost floor')
    return missing


def _price_value(price: Optional[PriceRecommendation]) -> float:
    """The artisan's own price once set, otherwise the recommended floor."""
    if price is None:
        return 0.0
    if price.final_price is not None:
        return _num(price.final_price)
    return _num(price.recommended_min)


def _record(product, listing, price, image, artisan, owner, moderation) -> Dict[str, Any]:
    """Serialize a product into the flat record shape the artisan app renders."""
    attributes = dict((listing.attributes if listing else None) or {})
    title = _text(listing.title_en if listing else None)
    return {
        'id': product.id,
        'artisan_id': product.artisan_id,
        'title': title or f'{product.category.value} product',
        'title_hi': _text(listing.title_hi if listing else None) or title,
        'description': _text(listing.desc_en if listing else None),
        'description_hi': _text(listing.desc_hi if listing else None)
        or _text(listing.desc_en if listing else None),
        'category': _text(attributes.get('ui_category')) or product.category.value,
        'craft': _text(attributes.get('craft')),
        'material': _text(attributes.get('material')),
        'colour': _text(attributes.get('colour')),
        'dimensions': _text(attributes.get('dimensions')),
        'usage': _text(attributes.get('usage')),
        'story': _text(attributes.get('story')),
        'location': _text(attributes.get('location'))
        or (_place(artisan.state, artisan.district) if artisan else '') or '',
        'price': _price_value(price),
        'material_cost': _num(price.material_cost) if price else 0,
        'labour_cost': _num(price.labour_cost) if price else 0,
        'overhead': _num(price.overhead) if price else 0,
        'recommended_min': _num(price.recommended_min) if price else 0,
        'recommended_max': _num(price.recommended_max) if price else 0,
        'moq': _num(attributes.get('moq')),
        'stock': _num(attributes.get('stock')),
        'capacity': _num(attributes.get('capacity')),
        'lead_days': _num(attributes.get('lead_days')),
        'available': attributes.get('available') is True,
        'customizable': attributes.get('customizable') is True,
        'fragile': attributes.get('fragile') is True,
        'can_pack': attributes.get('can_pack') is True,
        'image': _text(attributes.get('image')),
        'original_image': _text(attributes.get('original_image'))
        or _text(attributes.get('image')),
        'prepared': attributes.get('prepared', 'original'),
        'catalog_plain_background': attributes.get('catalog_plain_background', True),
        'photo_provider': attributes.get('photo_provider'),
        'photo_reviewed': attributes.get('photo_reviewed', True),
        'status': 'published' if product.status == ProductStatus.published else 'draft',
        'server_status': product.status.value,
        'approved': bool(listing and listing.verification_status == VerificationStatus.approved),
        'moderation': moderation.status if moderation else 'clear',
        'moderation_note': moderation.note if moderation else None,
        'external': {},
        'artisan_name': owner.name if owner else None,
        'artisan_location': _place(artisan.state, artisan.district) if artisan else None,
        'artisan_verified': bool(artisan.is_verified) if artisan else False,
        'created_at': _iso(product.created_at),
    }


async def load_bundle(db: AsyncSession, products: List[Product]) -> Dict[str, Any]:
    """Load every related row for a page of products in one round of queries."""
    ids = [product.id for product in products]
    if not ids:
        return {'listings': {}, 'prices': {}, 'images': {}, 'moderations': {},
                'artisans': {}, 'owners': {}}

    listings = {row.product_id: row for row in (await db.scalars(
        select(ProductListing).where(ProductListing.product_id.in_(ids)))).all()}
    prices = {row.product_id: row for row in (await db.scalars(
        select(PriceRecommendation).where(PriceRecommendation.product_id.in_(ids)))).all()}
    moderations = {row.product_id: row for row in (await db.scalars(
        select(ProductModeration).where(ProductModeration.product_id.in_(ids)))).all()}
    images: Dict[str, ProductImage] = {}
    for row in (await db.scalars(select(ProductImage).where(
            ProductImage.product_id.in_(ids)).order_by(ProductImage.created_at))).all():
        images.setdefault(row.product_id, row)

    artisans = {row.id: row for row in (await db.scalars(
        select(Artisan).where(Artisan.id.in_({p.artisan_id for p in products})))).all()}
    owners = {row.id: row for row in (await db.scalars(
        select(User).where(User.id.in_({a.user_id for a in artisans.values()})))).all()}

    return {'listings': listings, 'prices': prices, 'images': images,
            'moderations': moderations, 'artisans': artisans, 'owners': owners}


def serialize_products(products: List[Product], bundle: Dict[str, Any]) -> List[Dict[str, Any]]:
    rows = []
    for product in products:
        artisan = bundle['artisans'].get(product.artisan_id)
        rows.append(_record(
            product,
            bundle['listings'].get(product.id),
            bundle['prices'].get(product.id),
            bundle['images'].get(product.id),
            artisan,
            bundle['owners'].get(artisan.user_id) if artisan else None,
            bundle['moderations'].get(product.id),
        ))
    return rows


async def _owned_record(db: AsyncSession, artisan: Artisan, product: Product) -> Dict[str, Any]:
    bundle = await load_bundle(db, [product])
    return serialize_products([product], bundle)[0]


def _apply_listing(listing: ProductListing, draft: ProductDraft) -> None:
    """Copy the artisan-confirmed wording. Nothing is invented or auto-translated."""
    if _text(draft.title):
        listing.title_en = _text(draft.title)
    if _text(draft.description):
        listing.desc_en = _text(draft.description)
    if _text(draft.title_hi):
        listing.title_hi = _text(draft.title_hi)
    if _text(draft.description_hi):
        listing.desc_hi = _text(draft.description_hi)
    if draft.transcript is not None:
        listing.voice_transcript = draft.transcript
    # The columns are NOT NULL, so an absent translation falls back to the original.
    listing.title_hi = _text(listing.title_hi) or _text(listing.title_en)
    listing.desc_hi = _text(listing.desc_hi) or _text(listing.desc_en)
    listing.verification_status = (
        VerificationStatus.approved if draft.approved else VerificationStatus.ai_generated)


async def _apply_pricing(db: AsyncSession, product: Product, draft: ProductDraft,
                         artisan: Artisan) -> PriceRecommendation:
    """Recompute the explainable recommendation and store the artisan's own price."""
    material_cost = _num(draft.material_cost)
    labour_cost = _labour_cost(draft)
    overhead = _num(draft.overhead)
    category = product.category.value if product.category else 'other'
    result = await compute_price_recommendation(
        craft_category=category,
        material_cost=material_cost,
        labour_cost=labour_cost,
        overhead=overhead,
        craftsmanship_complexity=_num(draft.complexity, 0.5),
        db=db,
    )
    floor = material_cost + labour_cost + overhead
    price = draft.price if draft.price is not None else floor
    if _num(price) < floor:
        raise HTTPException(status_code=422, detail='Price must cover the material, labour and overhead floor')

    existing = await db.scalar(select(PriceRecommendation).where(
        PriceRecommendation.product_id == product.id))
    if existing is None:
        existing = PriceRecommendation(id=str(uuid.uuid4()), product_id=product.id)
        db.add(existing)
    existing.material_cost = material_cost
    existing.labour_cost = labour_cost
    existing.overhead = overhead
    existing.craftsmanship_score = result['craftsmanship_score']
    existing.comparable_ids = result['comparable_ids']
    existing.recommended_min = result['recommended_min']
    existing.recommended_max = result['recommended_max']
    existing.explanation_text_en = result['explanation_en']
    existing.explanation_text_hi = result['explanation_hi']
    existing.final_price = _num(price)
    existing.verification_status = (
        VerificationStatus.approved if draft.approved else VerificationStatus.ai_generated)

    db.add(VerificationLog(
        entity_type='price', entity_id=existing.id, artisan_id=artisan.id,
        new_status=existing.verification_status, artisan_action='accept',
        corrected_value={'final_price': existing.final_price}))
    return existing


async def _apply_images(db: AsyncSession, product: Product, listing: ProductListing,
                        draft: ProductDraft) -> None:
    original = _text(draft.original_image) or _text(draft.image)
    enhanced = _text(draft.image)
    if not original and not enhanced:
        return
    image = await db.scalar(select(ProductImage).where(
        ProductImage.product_id == product.id).order_by(ProductImage.created_at))
    if image is None:
        image = ProductImage(id=str(uuid.uuid4()), product_id=product.id)
        db.add(image)
    image.original_url = original or enhanced
    image.enhanced_url = enhanced
    image.verification_status = listing.verification_status


async def _product_state(db: AsyncSession, product: Product):
    listing = await db.scalar(select(ProductListing).where(
        ProductListing.product_id == product.id))
    price = await db.scalar(select(PriceRecommendation).where(
        PriceRecommendation.product_id == product.id))
    moderation = await db.scalar(select(ProductModeration).where(
        ProductModeration.product_id == product.id))
    attributes = dict((listing.attributes if listing else None) or {})
    return listing, price, moderation, attributes


@router.post('/', status_code=200)
async def create_product(
    data: ProductDraft,
    artisan: Artisan = Depends(require_artisan_profile),
    db: AsyncSession = Depends(get_db),
):
    """Save a product. A payload with no listing detail still creates a bare draft."""
    product = Product(
        id=str(uuid.uuid4()),
        artisan_id=artisan.id,
        category=_craft_category(data.category),
        status=ProductStatus.draft,
    )
    db.add(product)

    has_listing = bool(_text(data.title) or _text(data.description))
    if has_listing:
        listing = ProductListing(
            id=str(uuid.uuid4()), product_id=product.id,
            title_en=_text(data.title),
            title_hi=_text(data.title_hi) or _text(data.title),
            desc_en=_text(data.description),
            desc_hi=_text(data.description_hi) or _text(data.description),
            attributes={}, tags=[], craft_terms=[],
            voice_transcript=data.transcript,
            verification_status=VerificationStatus.ai_generated,
        )
        db.add(listing)
        _apply_listing(listing, data)
        listing.attributes = _attributes_from(data)
        await db.flush()
        await _apply_pricing(db, product, data, artisan)
        await _apply_images(db, product, listing, data)
        product.status = (ProductStatus.verified if data.approved
                          else ProductStatus.ai_generated)

    await db.commit()
    await db.refresh(product)
    return await _owned_record(db, artisan, product)


@router.get('/')
async def list_my_products(
    artisan: Artisan = Depends(require_artisan_profile),
    db: AsyncSession = Depends(get_db),
):
    """Every product the authenticated artisan owns, newest first."""
    products = (await db.scalars(select(Product).where(
        Product.artisan_id == artisan.id).order_by(Product.created_at.desc()))).all()
    bundle = await load_bundle(db, list(products))
    return serialize_products(list(products), bundle)


@router.post('/images')
async def upload_product_image(
    file: UploadFile = File(...),
    _artisan: Artisan = Depends(require_artisan_profile),
):
    """Store a catalogue photo and return the path to save with the product.

    The path is relative on purpose: the client resolves it against the API base
    URL it is already talking to, so a proxy or dev-tunnel host never leaks into
    stored data (deriving it from the request produced unreachable
    `https://localhost:8000/...` URLs behind a tunnel).
    """
    name = image_store.store_photo(
        await file.read(image_store.MAX_BYTES + 1), MEDIA, 'product photo')
    return {'path': f'/api/v1/products/images/{name}'}


@router.get('/images/{name}')
async def product_image(name: str):
    """Catalogue photos are public-read under an unguessable filename.

    Identity and verification evidence keep their authenticated endpoints; these
    are product photos meant to be shown to buyers.
    """
    if not re.fullmatch(r'[a-f0-9]{32}\.jpg', name) or not (MEDIA / name).is_file():
        raise HTTPException(status_code=404, detail='Photo not found')
    return FileResponse(MEDIA / name, media_type='image/jpeg',
                        headers={'Cache-Control': 'public, max-age=300'})


@router.get('/{product_id}')
async def get_product(
    product_id: str,
    artisan: Artisan = Depends(require_artisan_profile),
    db: AsyncSession = Depends(get_db),
):
    product = await load_owned_product(db, product_id, artisan)
    return await _owned_record(db, artisan, product)


@router.put('/{product_id}')
async def update_product(
    product_id: str,
    data: ProductDraft,
    artisan: Artisan = Depends(require_artisan_profile),
    db: AsyncSession = Depends(get_db),
):
    """Edit an existing product. Editing a published product returns it to review."""
    product = await load_owned_product(db, product_id, artisan)
    listing, _price, _moderation, _attributes = await _product_state(db, product)

    if listing is None:
        listing = ProductListing(
            id=str(uuid.uuid4()), product_id=product.id, title_en='', title_hi='',
            desc_en='', desc_hi='', attributes={}, tags=[], craft_terms=[],
            verification_status=VerificationStatus.ai_generated)
        db.add(listing)
        await db.flush()

    if _text(data.category):
        product.category = _craft_category(data.category)
    _apply_listing(listing, data)
    listing.attributes = _attributes_from(data, existing=listing.attributes)
    await db.flush()
    await _apply_pricing(db, product, data, artisan)
    await _apply_images(db, product, listing, data)

    product.status = (ProductStatus.verified if data.approved
                      else ProductStatus.ai_generated)
    await db.commit()
    await db.refresh(product)
    return await _owned_record(db, artisan, product)


@router.post('/{product_id}/publish')
async def publish_product(
    product_id: str,
    artisan: Artisan = Depends(require_artisan_profile),
    db: AsyncSession = Depends(get_db),
):
    """Publish an internally ready product. Nothing else republishes it."""
    product = await load_owned_product(db, product_id, artisan)
    listing, price, moderation, attributes = await _product_state(db, product)
    if moderation is not None and moderation.status in ('flagged', 'blocked'):
        raise HTTPException(status_code=422, detail='Resolve moderation before publishing')
    missing = _readiness(product, listing, price, attributes)
    if missing:
        raise HTTPException(status_code=422, detail='Complete readiness: ' + ', '.join(missing))
    product.status = ProductStatus.published
    await db.commit()
    await db.refresh(product)
    return await _owned_record(db, artisan, product)


class AvailabilityUpdate(BaseModel):
    available: bool


@router.post('/{product_id}/availability')
async def set_availability(
    product_id: str,
    data: AvailabilityUpdate,
    artisan: Artisan = Depends(require_artisan_profile),
    db: AsyncSession = Depends(get_db),
):
    """Taking orders or not. Operational only — it never publishes or unpublishes."""
    product = await load_owned_product(db, product_id, artisan)
    listing = await db.scalar(select(ProductListing).where(
        ProductListing.product_id == product.id))
    if listing is None:
        raise HTTPException(status_code=422, detail='Save the product before changing availability')
    attributes = dict(listing.attributes or {})
    attributes['available'] = data.available
    listing.attributes = attributes
    await db.commit()
    return await _owned_record(db, artisan, product)
