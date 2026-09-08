"""
Attribute Extraction Service — LLM with confidence scores.

The confidence score per field is the core USP mechanism:
  - High confidence (≥0.8) → auto-fill, show green
  - Medium confidence (0.5–0.8) → show to artisan for review, show amber
  - Low confidence (<0.5) → trigger follow-up question, show red

Uses Groq/OpenAI-compatible API for demo; self-hostable Llama 3.1/Gemma 2 for production.
"""
import json
import httpx
from typing import List, Tuple
from app.core.config import settings

EXTRACTION_SYSTEM_PROMPT = """You are an expert craft product cataloger for Indian artisans.
Given a voice transcript describing a handmade product, extract product attributes as JSON.

For EACH attribute, provide:
- "value": the extracted value (null if not mentioned)
- "confidence": float 0.0 to 1.0 (how confident you are in the value)
  - 0.9+: clearly stated
  - 0.7-0.9: implied or partially stated
  - 0.5-0.7: inferred from context
  - <0.5: not mentioned or very uncertain (mark value as null)

IMPORTANT: Preserve craft-specific terms verbatim (matka, bandhani, ikat, chikankari, etc.)
Do NOT translate them into generic English equivalents.

Return ONLY valid JSON in this exact format:
{
  "product_type": {"value": "...", "confidence": 0.0},
  "material": {"value": "...", "confidence": 0.0},
  "craft_technique": {"value": "...", "confidence": 0.0},
  "color": {"value": "...", "confidence": 0.0},
  "dimensions": {"value": "...", "confidence": 0.0},
  "weight": {"value": null, "confidence": 0.0},
  "use_case": {"value": "...", "confidence": 0.0},
  "origin_region": {"value": "...", "confidence": 0.0},
  "quantity_available": {"value": null, "confidence": 0.0}
}"""

FIELD_METADATA = {
    "product_type": {"label_en": "Product Type", "label_hi": "उत्पाद प्रकार", "required": True},
    "material": {"label_en": "Material", "label_hi": "सामग्री", "required": True},
    "craft_technique": {"label_en": "Craft Technique", "label_hi": "शिल्प तकनीक", "required": True},
    "color": {"label_en": "Colour", "label_hi": "रंग", "required": True},
    "dimensions": {"label_en": "Dimensions", "label_hi": "आयाम", "required": False},
    "weight": {"label_en": "Weight", "label_hi": "वज़न", "required": False},
    "use_case": {"label_en": "Use Case", "label_hi": "उपयोग", "required": False},
    "origin_region": {"label_en": "Origin / Region", "label_hi": "उत्पत्ति / क्षेत्र", "required": True},
    "quantity_available": {"label_en": "Quantity Available", "label_hi": "उपलब्ध मात्रा", "required": False},
}


async def extract_attributes_with_confidence(
    transcript: str,
    craft_category: str,
) -> Tuple[List[dict], List[str]]:
    """
    Extract product attributes from transcript with per-field confidence scores.
    Returns (attributes_list, missing_required_fields).
    """
    if not settings.LLM_API_KEY:
        return _demo_extraction(craft_category)

    try:
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(
                f"{settings.LLM_API_BASE}/chat/completions",
                headers={"Authorization": f"Bearer {settings.LLM_API_KEY}"},
                json={
                    "model": settings.LLM_MODEL,
                    "messages": [
                        {"role": "system", "content": EXTRACTION_SYSTEM_PROMPT},
                        {"role": "user", "content": f"Craft category: {craft_category}\n\nTranscript: {transcript}"},
                    ],
                    "temperature": 0.1,
                    "response_format": {"type": "json_object"},
                }
            )
            resp.raise_for_status()
            raw = resp.json()["choices"][0]["message"]["content"]
            extracted = json.loads(raw)
    except Exception:
        return _demo_extraction(craft_category)

    return _build_attribute_list(extracted)


def _build_attribute_list(extracted: dict) -> Tuple[List[dict], List[str]]:
    attributes = []
    missing_required = []

    for key, meta in FIELD_METADATA.items():
        field_data = extracted.get(key, {"value": None, "confidence": 0.0})
        value = field_data.get("value")
        confidence = field_data.get("confidence", 0.0)

        attributes.append({
            "key": key,
            "label_en": meta["label_en"],
            "label_hi": meta["label_hi"],
            "value": value,
            "confidence": confidence,
            "is_required": meta["required"],
        })

        if meta["required"] and (value is None or confidence < 0.5):
            missing_required.append(key)

    return attributes, missing_required


def _demo_extraction(craft_category: str) -> Tuple[List[dict], List[str]]:
    """Demo extraction for when LLM API is not configured."""
    demo_data = {
        "product_type": {"value": "Clay Water Pot (Matka)", "confidence": 0.97},
        "material": {"value": "Terracotta Clay", "confidence": 0.92},
        "craft_technique": {"value": "Wheel-thrown, hand-finished", "confidence": 0.88},
        "color": {"value": "Earthy terracotta brown", "confidence": 0.90},
        "dimensions": {"value": "30 cm height, 25 cm diameter", "confidence": 0.82},
        "weight": {"value": None, "confidence": 0.05},
        "use_case": {"value": "Water storage, home decor", "confidence": 0.85},
        "origin_region": {"value": None, "confidence": 0.10},
        "quantity_available": {"value": None, "confidence": 0.0},
    }
    return _build_attribute_list(demo_data)
