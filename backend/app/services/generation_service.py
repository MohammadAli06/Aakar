"""
Listing Generation Service — Bilingual craft-aware SEO listing generator.

Runs on the free Groq text tier (GENERATION_* env, else LLM_*). This task has no
confidence signal, so the only fallback trigger is invalid JSON / schema (see
_validate): one retry on the paid OpenAI model, then the deterministic demo listing.
"""
import json
import logging
from typing import Dict, Any

import httpx

from app.core.config import chat_completions_url, free_tier, settings

logger = logging.getLogger(__name__)

REQUIRED_KEYS = ('title_en', 'title_hi', 'desc_en', 'desc_hi', 'tags', 'craft_terms')


# Craft terms that must be preserved verbatim (not translated)
CRAFT_TERMS_GLOSSARY = {
    "matka", "bandhani", "ikat", "phulkari", "chikankari", "kantha",
    "kalamkari", "madhubani", "pattachitra", "dhokra", "bidri", "channapatna",
    "kondapalli", "etikoppaka", "nandyala", "nirmal", "penukonda",
    "terracotta", "tikuli", "sanjhi", "thangka", "tanjore",
}

GENERATION_SYSTEM_PROMPT = """You are an expert bilingual product listing writer for Indian handicrafts.
Create SEO-optimized product listings that preserve authentic craft terms.

RULES:
1. Preserve craft terms verbatim: matka, bandhani, ikat, phulkari, etc.
2. Write in simple, clear language suitable for e-commerce
3. Highlight the handmade, artisanal nature
4. Include emotional/story angle (artisan's craft heritage)
5. Keep Hindi natural and colloquial (not formal Sanskrit-heavy)

Return ONLY valid JSON:
{
  "title_en": "...(max 80 chars)...",
  "title_hi": "...(max 80 chars)...",
  "desc_en": "...(150-300 words)...",
  "desc_hi": "...(150-300 words)...",
  "tags": ["tag1", "tag2", ...],
  "craft_terms": ["preserved_term1", ...]
}"""


def _validate(listing: dict) -> dict:
    """Fallback trigger for this task: JSON must be an object carrying every key."""
    if not isinstance(listing, dict) or any(key not in listing for key in REQUIRED_KEYS):
        raise ValueError("Listing is missing required keys")
    return listing


async def _request(base: str, key: str, model: str, prompt: str) -> dict:
    async with httpx.AsyncClient(timeout=40) as client:
        resp = await client.post(
            chat_completions_url(base),
            headers={"Authorization": f"Bearer {key}"},
            json={
                "model": model,
                "messages": [
                    {"role": "system", "content": GENERATION_SYSTEM_PROMPT},
                    {"role": "user", "content": prompt},
                ],
                "temperature": 0.4,
                "response_format": {"type": "json_object"},
            }
        )
        resp.raise_for_status()
        return _validate(json.loads(resp.json()["choices"][0]["message"]["content"]))


async def generate_bilingual_listing(
    attributes: Dict[str, Any],
    artisan_name: str,
    craft_category: str,
) -> Dict[str, Any]:
    """
    Generate bilingual EN + HI listing from extracted attributes.
    Craft-term preserving, SEO-optimized.
    """
    attr_text = "\n".join([
        f"- {k}: {v.get('value', 'unknown')}" if isinstance(v, dict) else f"- {k}: {v}"
        for k, v in attributes.items()
    ])
    prompt = (
        f"Artisan: {artisan_name}\n"
        f"Craft Category: {craft_category}\n"
        f"Attributes:\n{attr_text}\n\n"
        f"Craft terms to preserve verbatim if present: {', '.join(CRAFT_TERMS_GLOSSARY)}"
    )

    base, key, model = free_tier('generation')
    tier, served_by = 'none', 'deterministic'
    if key:
        try:
            listing = await _request(base, key, model, prompt)
            logger.info('task=generation tier=free model=%s', model)
            return listing
        except Exception as exc:  # malformed JSON or missing keys
            logger.info('task=generation tier=free model=%s outcome=error: %s', model, exc)

    if settings.OPENAI_API_KEY:
        try:
            listing = await _request('https://api.openai.com/v1',
                                     settings.OPENAI_API_KEY.strip(),
                                     settings.OPENAI_VISION_MODEL, prompt)
            logger.info('task=generation tier=openai-fallback model=%s', settings.OPENAI_VISION_MODEL)
            return listing
        except Exception as exc:
            logger.info('task=generation tier=openai-fallback model=%s outcome=error: %s',
                        settings.OPENAI_VISION_MODEL, exc)

    logger.info('task=generation tier=%s model=deterministic', tier)
    return _demo_listing(craft_category)



def _demo_listing(craft_category: str) -> Dict[str, Any]:
    return {
        "title_en": "Handcrafted Rajasthani Terracotta Matka — Traditional Clay Water Pot",
        "title_hi": "हस्तनिर्मित राजस्थानी टेराकोटा मटका — पारंपरिक मिट्टी का घड़ा",
        "desc_en": (
            "A beautifully handcrafted terracotta matka made using the centuries-old wheel-throwing "
            "technique by skilled Rajasthani artisans. This traditional clay water pot naturally cools "
            "water and is an eco-friendly alternative to plastic. Each piece is unique, bearing the "
            "artisan's individual touch. Perfect for home décor and functional use. Supports local "
            "craft heritage and fair wages for skilled potters."
        ),
        "desc_hi": (
            "राजस्थान के कुशल कारीगरों द्वारा सदियों पुरानी चाक-निर्माण तकनीक से बनाया गया यह "
            "सुंदर टेराकोटा मटका पानी को प्राकृतिक रूप से ठंडा रखता है। यह प्लास्टिक का "
            "पर्यावरण-हितैषी विकल्प है। प्रत्येक टुकड़ा अनूठा है और कारीगर की व्यक्तिगत "
            "कलाकारी को दर्शाता है। घर की सजावट और उपयोग दोनों के लिए उत्तम।"
        ),
        "tags": [
            "handmade", "terracotta", "matka", "rajasthani", "pottery",
            "clay pot", "eco-friendly", "traditional craft", "water pot", "home decor",
            "हस्तनिर्मित", "मिट्टी", "राजस्थान",
        ],
        "craft_terms": ["matka", "terracotta"],
    }
