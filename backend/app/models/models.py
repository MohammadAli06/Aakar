"""
SQLAlchemy ORM Models for Aakar.
All entities carry a verification_status — nothing publishes without artisan approval.
"""
import uuid
from datetime import datetime
from sqlalchemy import (
    Column, String, Float, Boolean, DateTime, Text,
    ForeignKey, JSON, Enum as SAEnum
)
from sqlalchemy.orm import relationship
import enum

from app.core.database import Base


def _uuid():
    return str(uuid.uuid4())


class VerificationStatus(str, enum.Enum):
    ai_generated = "ai_generated"
    artisan_reviewed = "artisan_reviewed"
    approved = "approved"
    rejected = "rejected"


class CraftCategory(str, enum.Enum):
    pottery = "pottery"
    weaving = "weaving"
    embroidery = "embroidery"
    woodcraft = "woodcraft"
    metalcraft = "metalcraft"
    painting = "painting"
    leathercraft = "leathercraft"
    jewelry = "jewelry"
    other = "other"


class ProductStatus(str, enum.Enum):
    draft = "draft"
    ai_generated = "ai_generated"
    verified = "verified"
    published = "published"


class B2BStatus(str, enum.Enum):
    not_started = "not_started"
    in_progress = "in_progress"
    ready = "ready"


# ── Artisan ──────────────────────────────────────────────────────────────
class Artisan(Base):
    __tablename__ = "artisans"

    id = Column(String, primary_key=True, default=_uuid)
    firebase_uid = Column(String, unique=True, nullable=False, index=True)
    name = Column(String(200), nullable=False)
    phone = Column(String(20), nullable=False, unique=True)
    language_pref = Column(String(10), default="hi")
    state = Column(String(100), nullable=True)
    district = Column(String(100), nullable=True)
    craft_category = Column(SAEnum(CraftCategory), default=CraftCategory.other)
    profile_image_url = Column(String(500), nullable=True)
    is_verified = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    products = relationship("Product", back_populates="artisan")


# ── Product ───────────────────────────────────────────────────────────────
class Product(Base):
    __tablename__ = "products"

    id = Column(String, primary_key=True, default=_uuid)
    artisan_id = Column(String, ForeignKey("artisans.id"), nullable=False)
    category = Column(SAEnum(CraftCategory), default=CraftCategory.other)
    status = Column(SAEnum(ProductStatus), default=ProductStatus.draft)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    artisan = relationship("Artisan", back_populates="products")
    images = relationship("ProductImage", back_populates="product")
    listing = relationship("ProductListing", back_populates="product", uselist=False)
    price_recommendation = relationship("PriceRecommendation", back_populates="product", uselist=False)
    b2b_readiness = relationship("B2BReadiness", back_populates="product")


# ── Product Image ─────────────────────────────────────────────────────────
class ProductImage(Base):
    __tablename__ = "product_images"

    id = Column(String, primary_key=True, default=_uuid)
    product_id = Column(String, ForeignKey("products.id"), nullable=False)
    original_url = Column(String(500), nullable=False)
    enhanced_url = Column(String(500), nullable=True)
    background_removed_url = Column(String(500), nullable=True)
    verification_status = Column(SAEnum(VerificationStatus), default=VerificationStatus.ai_generated)
    created_at = Column(DateTime, default=datetime.utcnow)

    product = relationship("Product", back_populates="images")


# ── Product Listing ───────────────────────────────────────────────────────
class ProductListing(Base):
    __tablename__ = "product_listings"

    id = Column(String, primary_key=True, default=_uuid)
    product_id = Column(String, ForeignKey("products.id"), nullable=False, unique=True)
    title_en = Column(String(300), nullable=False)
    title_hi = Column(String(300), nullable=False)
    desc_en = Column(Text, nullable=False)
    desc_hi = Column(Text, nullable=False)
    attributes = Column(JSON, default=dict)         # {key: {value, confidence, label_en, label_hi}}
    confidence_scores = Column(JSON, default=dict)  # {key: float}
    tags = Column(JSON, default=list)
    craft_terms = Column(JSON, default=list)         # preserved craft terms
    voice_transcript = Column(Text, nullable=True)
    verification_status = Column(SAEnum(VerificationStatus), default=VerificationStatus.ai_generated)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    product = relationship("Product", back_populates="listing")


# ── Market Comparable ─────────────────────────────────────────────────────
class MarketComparable(Base):
    __tablename__ = "market_comparables"

    id = Column(String, primary_key=True, default=_uuid)
    category = Column(SAEnum(CraftCategory))
    name = Column(String(300))
    price = Column(Float, nullable=False)
    source = Column(String(200))
    is_handmade = Column(Boolean, default=True)  # ONLY handmade — machine-made excluded
    image_url = Column(String(500), nullable=True)
    embedding_vector = Column(JSON, nullable=True)  # pgvector in production
    created_at = Column(DateTime, default=datetime.utcnow)


# ── Price Recommendation ──────────────────────────────────────────────────
class PriceRecommendation(Base):
    __tablename__ = "price_recommendations"

    id = Column(String, primary_key=True, default=_uuid)
    product_id = Column(String, ForeignKey("products.id"), nullable=False, unique=True)
    material_cost = Column(Float, nullable=False)
    labour_cost = Column(Float, nullable=False)
    overhead = Column(Float, default=0.0)
    craftsmanship_score = Column(Float, default=0.5)   # 0–1
    comparable_ids = Column(JSON, default=list)
    recommended_min = Column(Float, nullable=False)
    recommended_max = Column(Float, nullable=False)
    final_price = Column(Float, nullable=True)           # artisan-set
    explanation_text_en = Column(Text, nullable=False)
    explanation_text_hi = Column(Text, nullable=False)
    verification_status = Column(SAEnum(VerificationStatus), default=VerificationStatus.ai_generated)
    created_at = Column(DateTime, default=datetime.utcnow)

    product = relationship("Product", back_populates="price_recommendation")


# ── B2B Channel ───────────────────────────────────────────────────────────
class B2BChannel(Base):
    __tablename__ = "b2b_channels"

    id = Column(String, primary_key=True, default=_uuid)
    name = Column(String(200), nullable=False)
    description = Column(Text)
    requirement_template = Column(JSON, default=dict)   # {field: {label, required, type}}
    logo_url = Column(String(500), nullable=True)
    is_active = Column(Boolean, default=True)


# ── B2B Readiness ─────────────────────────────────────────────────────────
class B2BReadiness(Base):
    __tablename__ = "b2b_readiness"

    id = Column(String, primary_key=True, default=_uuid)
    product_id = Column(String, ForeignKey("products.id"), nullable=False)
    channel_id = Column(String, ForeignKey("b2b_channels.id"), nullable=False)
    missing_fields = Column(JSON, default=list)
    provided_fields = Column(JSON, default=dict)
    readiness_score = Column(Float, default=0.0)    # 0–1
    status = Column(SAEnum(B2BStatus), default=B2BStatus.not_started)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    product = relationship("Product", back_populates="b2b_readiness")
    channel = relationship("B2BChannel")


# ── Verification Log ──────────────────────────────────────────────────────
class VerificationLog(Base):
    __tablename__ = "verification_logs"

    id = Column(String, primary_key=True, default=_uuid)
    entity_type = Column(String(50))            # product_image, listing, price, b2b
    entity_id = Column(String, nullable=False)
    artisan_id = Column(String, ForeignKey("artisans.id"), nullable=False)
    previous_status = Column(SAEnum(VerificationStatus))
    new_status = Column(SAEnum(VerificationStatus))
    artisan_action = Column(String(20))          # accept, edit, reject
    corrected_value = Column(JSON, nullable=True)
    timestamp = Column(DateTime, default=datetime.utcnow)
