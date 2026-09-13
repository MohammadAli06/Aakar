"""
Vision Pricing Service — GPT-4.1-mini vision analysis for product craftsmanship assessment.

Sends the product photo + description to OpenAI GPT vision to automatically assess:
  - craftsmanship_complexity (0.0–1.0)
  - detected craft category
  - material tier (low / medium / premium)
  - bilingual reasoning text shown to artisan in the UI

Always returns a safe fallback dict if OpenAI is unavailable, times out, or returns
unexpected output — so the pricing flow is never blocked by AI unavailability.
"""
import base64
import json
import logging
import os
from typing import Any, Dict

from app.core.config import settings

logger = logging.getLogger(__name__)

_FALLBACK = {
    "complexity_score": 0.5,
    "detected_category": "other",
    "material_tier": "medium",
    "reasoning_en": "AI analysis unavailable. Please adjust the craftsmanship slider manually based on the detail and time invested in your product.",
    "reasoning_hi": "AI विश्लेषण उपलब्ध नहीं है। कृपया अपने उत्पाद की मेहनत और बारीकियों के अनुसार स्लाइडर खुद सेट करें।",
    "model_used": "fallback",
    "is_fallback": True,
}

_SYSTEM_PROMPT = """You are an expert appraiser of handmade Indian craft products.
Given a product photo and optional description, assess the craftsmanship.
Respond ONLY with a valid JSON object with these exact keys:
{
  "complexity_score": <float 0.0-1.0, where 0=very simple, 1=extremely intricate>,
  "detected_category": <one of: pottery, weaving, embroidery, woodcraft, metalcraft, painting, leathercraft, jewelry, other>,
  "material_tier": <one of: low, medium, premium>,
  "reasoning_en": <1-2 sentence English explanation of complexity score for the artisan>,
  "reasoning_hi": <same explanation in simple Hindi>
}
Be concise. Do not add any text outside the JSON object."""


def _image_to_base64(image_path: str) -> str | None:
    """Read an image file and encode it as base64. Returns None if file missing."""
    try:
        with open(image_path, "rb") as f:
            return base64.b64encode(f.read()).decode("utf-8")
    except (FileNotFoundError, PermissionError, OSError) as e:
        logger.warning("Could not read image for vision analysis: %s — %s", image_path, e)
        return None


def _parse_response(text: str) -> Dict[str, Any]:
    """Extract JSON from model response, handling markdown code fences."""
    text = text.strip()
    # Strip ```json ... ``` fences if present
    if text.startswith("```"):
        lines = text.splitlines()
        text = "\n".join(
            line for line in lines if not line.startswith("```")
        ).strip()
    data = json.loads(text)
    # Validate required keys
    score = float(data.get("complexity_score", 0.5))
    score = max(0.0, min(1.0, score))
    return {
        "complexity_score": round(score, 2),
        "detected_category": str(data.get("detected_category", "other")),
        "material_tier": str(data.get("material_tier", "medium")),
        "reasoning_en": str(data.get("reasoning_en", "")),
        "reasoning_hi": str(data.get("reasoning_hi", "")),
        "model_used": settings.OPENAI_VISION_MODEL,
        "is_fallback": False,
    }


async def analyze_product_image(
    image_path: str | None,
    description: str = "",
) -> Dict[str, Any]:
    """
    Call GPT-4.1-mini with the product image + description.

    Args:
        image_path: Absolute path to the product image on disk (may be None).
        description: Product description text (from voice catalog, optional).

    Returns:
        Dict with complexity_score, detected_category, material_tier,
        reasoning_en, reasoning_hi, model_used, is_fallback.
    """
    api_key = settings.OPENAI_API_KEY
    if not api_key:
        logger.warning("OPENAI_API_KEY not set — returning fallback pricing analysis")
        return _FALLBACK

    try:
        from openai import AsyncOpenAI  # imported lazily — not required for startup

        client = AsyncOpenAI(
            api_key=api_key,
            timeout=settings.OPENAI_TIMEOUT_SECONDS,
        )

        # Build message content
        content: list = []

        # Add image if available
        if image_path:
            b64 = _image_to_base64(image_path)
            if b64:
                # Detect MIME type from extension
                ext = os.path.splitext(image_path)[1].lower()
                mime = {
                    ".jpg": "image/jpeg",
                    ".jpeg": "image/jpeg",
                    ".png": "image/png",
                    ".webp": "image/webp",
                }.get(ext, "image/jpeg")
                content.append({
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:{mime};base64,{b64}",
                        "detail": "low",  # low detail = faster + cheaper, sufficient for assessment
                    },
                })

        # Add text prompt
        text_prompt = "Analyze this handmade Indian craft product for craftsmanship complexity."
        if description.strip():
            text_prompt += f"\n\nArtisan's description: {description.strip()}"
        content.append({"type": "text", "text": text_prompt})

        if not content or all(c.get("type") == "text" for c in content):
            # No image — use text-only prompt with description
            logger.info("No product image available; using description-only analysis")

        response = await client.chat.completions.create(
            model=settings.OPENAI_VISION_MODEL,
            messages=[
                {"role": "system", "content": _SYSTEM_PROMPT},
                {"role": "user", "content": content},
            ],
            max_tokens=300,
            temperature=0.2,
        )

        raw = response.choices[0].message.content or ""
        result = _parse_response(raw)
        logger.info(
            "Vision analysis complete: score=%.2f category=%s tier=%s",
            result["complexity_score"],
            result["detected_category"],
            result["material_tier"],
        )
        return result

    except json.JSONDecodeError as e:
        logger.warning("Vision model returned non-JSON response: %s", e)
        return _FALLBACK
    except Exception as e:
        logger.warning("Vision analysis failed (%s: %s) — using fallback", type(e).__name__, e)
        return _FALLBACK

