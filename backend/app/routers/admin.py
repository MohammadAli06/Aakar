"""Administrator console API: account directory, products, moderation, audit trail.

Everything here is gated by the separate `ADMIN_ACCESS_TOKEN` credential and reads
the shared production tables. Verification decisions themselves stay in
`account_verification.py`; this router records who looked at what.
"""
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import require_admin
from app.core.config import settings
from app.core.database import get_db
from app.models.models import (
    AccountVerification, AdminAuditLog, Artisan, Buyer, PriceRecommendation,
    Product, ProductListing, ProductModeration, Requirement, User,
)
from app.routers.requirements import requirement_record

router = APIRouter()

VERIFICATION_STATUSES = (
    "not_started", "pending", "verified", "needs_correction", "rejected")
MODERATION_STATUSES = ("clear", "flagged", "blocked")


def _iso(value: Optional[datetime]) -> Optional[str]:
    return value.isoformat() if value else None


def _place(state, district) -> Optional[str]:
    parts = [part for part in (district, state) if part]
    return ", ".join(parts) if parts else None


async def _directory(db: AsyncSession):
    """Load the account tables once so callers never query per row."""
    users = (await db.scalars(select(User).order_by(desc(User.created_at)))).all()
    verifications = (await db.scalars(select(AccountVerification))).all()
    artisans = {row.user_id: row for row in (await db.scalars(select(Artisan))).all()}
    buyers = {row.user_id: row for row in (await db.scalars(select(Buyer))).all()}
    return users, verifications, artisans, buyers


def _current_verifications(users, verifications) -> dict:
    """Map each account to the review record matching its registered role."""
    by_key = {(row.user_id, row.role): row for row in verifications}
    return {user.id: by_key.get((user.id, user.role.value)) for user in users}


def _account(user, verification, artisans, buyers) -> dict:
    artisan = artisans.get(user.id)
    buyer = buyers.get(user.id)
    if user.role.value == "artisan":
        profile, location = artisan, _place(artisan.state, artisan.district) if artisan else None
        craft = artisan.craft_category.value if artisan and artisan.craft_category else None
    else:
        profile, location = buyer, _place(buyer.state, buyer.district) if buyer else None
        craft = None
    return {
        "id": user.id,
        "name": user.name,
        "phone": user.phone,
        "email": user.email,
        "role": user.role.value,
        "language_pref": user.language_pref,
        "is_active": bool(user.is_active),
        "created_at": _iso(user.created_at),
        "location": location,
        "craft_category": craft,
        "business_name": buyer.business_name if buyer else None,
        "business_type": buyer.business_type if buyer else None,
        "industry": buyer.industry if buyer else None,
        "is_verified": bool(profile.is_verified) if profile else False,
        "verification": verification.status if verification else "not_started",
        "submitted_at": _iso(verification.submitted_at) if verification else None,
    }


def _matches(term: str, *values) -> bool:
    needle = term.strip().lower()
    return not needle or any(needle in str(value or "").lower() for value in values)


@router.get("/overview")
async def overview(_admin: None = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    """Counts for the dashboard. Read-only and independent of the demo workspace."""
    users, verifications, artisans, buyers = await _directory(db)
    current = _current_verifications(users, verifications)

    accounts = {"total": len(users), "artisan": 0, "buyer": 0,
                "verified": 0, "disabled": 0}
    statuses = {name: 0 for name in VERIFICATION_STATUSES}
    for user in users:
        accounts[user.role.value] += 1
        if not user.is_active:
            accounts["disabled"] += 1
        status = current[user.id].status if current[user.id] else "not_started"
        statuses[status] = statuses.get(status, 0) + 1
        if user.role.value == "artisan" and status == "verified":
            accounts["verified"] += 1

    products = (await db.scalars(select(Product))).all()
    moderations = (await db.scalars(select(ProductModeration))).all()
    by_status = {name: 0 for name in ("draft", "ai_generated", "verified", "published")}
    for product in products:
        by_status[product.status.value] = by_status.get(product.status.value, 0) + 1
    flagged = sum(1 for row in moderations if row.status in ("flagged", "blocked"))

    requirements = (await db.scalars(select(Requirement))).all()

    return {
        "accounts": accounts,
        "verifications": statuses,
        "products": {"total": len(products), "flagged": flagged, "by_status": by_status},
        "requirements": {
            "total": len(requirements),
            "open": sum(1 for row in requirements if row.status == "open"),
        },
        "generated_at": datetime.utcnow().isoformat(),
    }


@router.get("/accounts")
async def list_accounts(
    role: Optional[str] = Query(default=None, pattern="^(artisan|buyer)$"),
    status: Optional[str] = Query(default=None),
    q: Optional[str] = None,
    _admin: None = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    users, verifications, artisans, buyers = await _directory(db)
    current = _current_verifications(users, verifications)
    rows = []
    for user in users:
        record = current[user.id]
        state = record.status if record else "not_started"
        payload = _account(user, record, artisans, buyers)
        if role and payload["role"] != role:
            continue
        if status and state != status:
            continue
        if not _matches(q or "", payload["name"], payload["phone"], payload["email"],
                        payload["location"], payload["business_name"], payload["craft_category"]):
            continue
        rows.append(payload)
    return rows


@router.get("/accounts/{user_id}")
async def account_detail(
    user_id: str,
    _admin: None = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(404, "Account not found")
    record = await db.scalar(select(AccountVerification).where(
        AccountVerification.user_id == user.id, AccountVerification.role == user.role.value))
    artifacts = await db.scalar(select(Artisan).where(Artisan.user_id == user.id))
    business = await db.scalar(select(Buyer).where(Buyer.user_id == user.id))
    payload = _account(user, record, {user.id: artifacts} if artifacts else {},
                       {user.id: business} if business else {})
    payload["review_note"] = record.review_note if record else None
    payload["evidence"] = list((record.evidence or {}).keys()) if record else []
    products = (await db.scalars(select(Product).where(
        Product.artisan_id == artifacts.id))).all() if artifacts else []
    payload["product_count"] = len(products)
    return payload


class AccountStatus(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    is_active: bool
    note: str = Field(min_length=1, max_length=2000)


@router.put("/accounts/{user_id}/status")
async def set_account_status(
    user_id: str,
    data: AccountStatus,
    _admin: None = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Enable or disable an account. A disabled account cannot authenticate."""
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(404, "Account not found")
    user.is_active = data.is_active
    db.add(AdminAuditLog(
        actor="admin",
        action="account_enabled" if data.is_active else "account_disabled",
        entity_type="account", entity_id=user.id,
        summary=f'{user.role.value} account {"enabled" if data.is_active else "disabled"}',
        note=data.note))
    await db.commit()
    return {"id": user.id, "is_active": bool(user.is_active)}


@router.get("/products")
async def list_products(
    status: Optional[str] = Query(default=None),
    moderation: Optional[str] = Query(default=None),
    q: Optional[str] = None,
    _admin: None = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    products = (await db.scalars(select(Product).order_by(desc(Product.created_at)))).all()
    listings = {row.product_id: row for row in (await db.scalars(select(ProductListing))).all()}
    prices = {row.product_id: row for row in (await db.scalars(select(PriceRecommendation))).all()}
    moderations = {row.product_id: row for row in (await db.scalars(select(ProductModeration))).all()}
    artisans = {row.id: row for row in (await db.scalars(select(Artisan))).all()}
    users = {row.id: row for row in (await db.scalars(select(User))).all()}

    rows = []
    for product in products:
        listing = listings.get(product.id)
        artisan = artisans.get(product.artisan_id)
        owner = users.get(artisan.user_id) if artisan else None
        moderation_row = moderations.get(product.id)
        moderation_state = moderation_row.status if moderation_row else "clear"
        attributes = (listing.attributes if listing else None) or {}
        row = {
            "id": product.id,
            "title": (listing.title_en if listing else None) or f"{product.category.value} product",
            "category": attributes.get("ui_category") or product.category.value,
            "status": product.status.value,
            "created_at": _iso(product.created_at),
            "artisan_id": product.artisan_id,
            "artisan_name": owner.name if owner else None,
            "listing_status": listing.verification_status.value if listing else None,
            "has_listing": listing is not None,
            "final_price": prices[product.id].final_price if product.id in prices else None,
            "recommended_min": prices[product.id].recommended_min if product.id in prices else None,
            "recommended_max": prices[product.id].recommended_max if product.id in prices else None,
            "moderation": moderation_state,
            "moderation_note": moderation_row.note if moderation_row else None,
        }
        if status and row["status"] != status:
            continue
        if moderation and moderation_state != moderation:
            continue
        if not _matches(q or "", row["title"], row["artisan_name"], row["category"],
                        row["listing_status"]):
            continue
        rows.append(row)
    return rows


@router.get("/products/{product_id}")
async def product_detail(
    product_id: str,
    _admin: None = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    product = await db.get(Product, product_id)
    if product is None:
        raise HTTPException(404, "Product not found")
    listing = await db.scalar(select(ProductListing).where(ProductListing.product_id == product.id))
    price = await db.scalar(select(PriceRecommendation).where(
        PriceRecommendation.product_id == product.id))
    moderation = await db.scalar(select(ProductModeration).where(
        ProductModeration.product_id == product.id))
    artisan = await db.get(Artisan, product.artisan_id) if product.artisan_id else None
    owner = await db.get(User, artisan.user_id) if artisan else None
    return {
        "id": product.id,
        "category": product.category.value,
        "status": product.status.value,
        "created_at": _iso(product.created_at),
        "artisan_name": owner.name if owner else None,
        "artisan_verified": bool(artisan.is_verified) if artisan else False,
        "location": _place(artisan.state, artisan.district) if artisan else None,
        "listing": {
            "title_en": listing.title_en,
            "title_hi": listing.title_hi,
            "desc_en": listing.desc_en,
            "desc_hi": listing.desc_hi,
            "tags": listing.tags or [],
            "attributes": listing.attributes or {},
            "verification_status": listing.verification_status.value,
        } if listing else None,
        "pricing": {
            "material_cost": price.material_cost,
            "labour_cost": price.labour_cost,
            "overhead": price.overhead,
            "recommended_min": price.recommended_min,
            "recommended_max": price.recommended_max,
            "final_price": price.final_price,
            "explanation_en": price.explanation_text_en,
        } if price else None,
        "moderation": moderation.status if moderation else "clear",
        "moderation_note": moderation.note if moderation else None,
    }


class Moderation(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    status: str = Field(pattern="^(clear|flagged|blocked)$")
    note: str = Field(min_length=1, max_length=2000)


@router.put("/products/{product_id}/moderation")
async def moderate_product(
    product_id: str,
    data: Moderation,
    _admin: None = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Record a moderation decision. It never republishes; the artisan decides that."""
    product = await db.get(Product, product_id)
    if product is None:
        raise HTTPException(404, "Product not found")
    row = await db.scalar(select(ProductModeration).where(
        ProductModeration.product_id == product_id))
    if row is None:
        row = ProductModeration(product_id=product_id)
        db.add(row)
    row.status, row.note = data.status, data.note
    db.add(AdminAuditLog(
        actor="admin", action="product_" + data.status,
        entity_type="product", entity_id=product_id,
        summary=f"{product.category.value} listing marked {data.status}",
        note=row.note))
    await db.commit()
    return {"id": product_id, "moderation": row.status, "note": row.note}


@router.get("/activity")
async def activity(
    limit: int = Query(default=100, ge=1, le=500),
    _admin: None = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Administrator actions plus verification submissions, newest first."""
    logs = (await db.scalars(select(AdminAuditLog).order_by(
        desc(AdminAuditLog.created_at)).limit(limit))).all()
    users, verifications, _artisans, _buyers = await _directory(db)
    names = {user.id: user.name or user.phone or user.id for user in users}
    events = [{
        "at": _iso(row.created_at), "actor": row.actor, "action": row.action,
        "entity_type": row.entity_type, "entity_id": row.entity_id,
        "summary": row.summary, "note": row.note,
    } for row in logs]
    for record in verifications:
        if record.submitted_at is None:
            continue
        events.append({
            "at": _iso(record.submitted_at), "actor": names.get(record.user_id, record.user_id),
            "action": "verification_submitted", "entity_type": "verification",
            "entity_id": record.id,
            "summary": f"{record.role} submitted verification for review",
            "note": None,
        })
    events.sort(key=lambda item: item["at"] or "", reverse=True)
    return events[:limit]


@router.get("/requirements")
async def list_requirements(
    status: Optional[str] = Query(default=None, pattern="^(open|closed)$"),
    q: Optional[str] = None,
    _admin: None = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Buyer-posted demand, newest first. Read-only: no decision is recorded here.

    A requirement is a statement of what a buyer needs, not an order. The console
    shows it so reviewers can see real demand alongside the catalogue.
    """
    requirements = (await db.scalars(select(Requirement).order_by(
        desc(Requirement.created_at)))).all()
    users, _verifications, _artisans, buyers = await _directory(db)
    owners = {user.id: user for user in users}
    rows = []
    for requirement in requirements:
        owner = owners.get(requirement.buyer_id)
        profile = buyers.get(requirement.buyer_id)
        if status and requirement.status != status:
            continue
        if not _matches(q or "", requirement.product, requirement.original,
                        requirement.location, owner.name if owner else None,
                        owner.phone if owner else None,
                        profile.business_name if profile else None):
            continue
        item = requirement_record(requirement, owner,
                                  profile.business_name if profile else None)
        item["buyer_phone"] = owner.phone if owner else None
        item["created_at"] = _iso(requirement.created_at)
        rows.append(item)
    return rows


@router.get("/platform")
async def platform(_admin: None = Depends(require_admin)):
    """Non-secret platform facts for the console's settings view."""
    return {
        "app_name": settings.APP_NAME,
        "environment": settings.ENVIRONMENT,
        "demo_workspace_enabled": bool(settings.ENABLE_DEMO_WORKSPACE),
        "database": "sqlite" if settings.DATABASE_URL.startswith("sqlite") else "postgresql",
        "assistant_configured": bool(settings.LLM_API_KEY),
        "migrations": "startup create_all; no Alembic revision history",
    }
