"""
Attribute Extraction Service — LLM with confidence scores.

The confidence score per field is the core USP mechanism:
  - High confidence (≥0.8) → auto-fill, show green
  - Medium confidence (0.5–0.8) → show to artisan for review, show amber
  - Low confidence (<0.5) → trigger follow-up question, show red

Runs on the free Groq text tier (EXTRACTION_* env, else LLM_*). Fallback triggers
(see _low_confidence below): malformed JSON, a provider error, or required fields left
below 0.5 → one retry on the paid OpenAI model, then the deterministic demo extraction.
The fallback is scoped to this task; generation and negotiation have no confidence
signal and only fall back on JSON/schema failure.
"""
import json
import logging
from typing import List, Tuple

import httpx

from app.core.config import chat_completions_url, free_tier, settings

logger = logging.getLogger(__name__)

# Required fields below this confidence are treated as missing (see _build_attribute_list).
CONFIDENCE_FLOOR = 0.5

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


async def _request(base: str, key: str, model: str, transcript: str, craft_category: str) -> dict:
    """One OpenAI-compatible chat completion returning the parsed JSON object."""
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(
            chat_completions_url(base),
            headers={"Authorization": f"Bearer {key}"},
            json={
                "model": model,
                "messages": [
                    {"role": "system", "content": EXTRACTION_SYSTEM_PROMPT},
                    {"role": "user", "content": f"Craft category: {craft_category}\n\nTranscript: {transcript}"},
                ],
                "temperature": 0.1,
                "response_format": {"type": "json_object"},
            }
        )
        resp.raise_for_status()
        extracted = json.loads(resp.json()["choices"][0]["message"]["content"])
    if not isinstance(extracted, dict):
        raise ValueError("Expected a JSON object")
    return extracted


def _low_confidence(extracted: dict) -> bool:
    """True when a required field came back at or below the confidence floor."""
    return any(
        (extracted.get(key) or {}).get("value") is None
        or (extracted.get(key) or {}).get("confidence", 0.0) < CONFIDENCE_FLOOR
        for key, meta in FIELD_METADATA.items() if meta["required"]
    )


async def extract_attributes_with_confidence(
    transcript: str,
    craft_category: str,
) -> Tuple[List[dict], List[str]]:
    """
    Extract product attributes from transcript with per-field confidence scores.
    Returns (attributes_list, missing_required_fields).
    """
    base, key, model = free_tier('extraction')
    extracted = None
    tier = 'none'
    served_by = 'deterministic'

    if key:
        try:
            extracted = await _request(base, key, model, transcript, craft_category)
            tier, served_by = 'free', model
        except Exception as exc:  # malformed JSON, provider error, timeout
            logger.info('task=extraction tier=free model=%s outcome=error: %s', model, exc)

    # Fallback trigger: no free result, or required fields still below the floor.
    if (extracted is None or _low_confidence(extracted)) and settings.OPENAI_API_KEY:
        try:
            extracted = await _request(
                'https://api.openai.com/v1', settings.OPENAI_API_KEY.strip(),
                settings.OPENAI_VISION_MODEL, transcript, craft_category)
            tier, served_by = 'openai-fallback', settings.OPENAI_VISION_MODEL
        except Exception as exc:
            logger.info('task=extraction tier=openai-fallback model=%s outcome=error: %s',
                        settings.OPENAI_VISION_MODEL, exc)

    logger.info('task=extraction tier=%s model=%s', tier, served_by)
    if extracted is None:
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
