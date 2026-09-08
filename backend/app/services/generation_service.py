"""
Listing Generation Service — Bilingual craft-aware SEO listing generator.
"""
import json
import httpx
from typing import Dict, Any
from app.core.config import settings

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


async def generate_bilingual_listing(
    attributes: Dict[str, Any],
    artisan_name: str,
    craft_category: str,
) -> Dict[str, Any]:
    """
    Generate bilingual EN + HI listing from extracted attributes.
    Craft-term preserving, SEO-optimized.
    """
    if not settings.LLM_API_KEY:
        return _demo_listing(craft_category)

    attr_text = "\n".join([
        f"- {k}: {v.get('value', 'unknown')}" if isinstance(v, dict) else f"- {k}: {v}"
        for k, v in attributes.items()
    ])

    try:
        async with httpx.AsyncClient(timeout=40) as client:
            resp = await client.post(
                f"{settings.LLM_API_BASE}/chat/completions",
                headers={"Authorization": f"Bearer {settings.LLM_API_KEY}"},
                json={
                    "model": settings.LLM_MODEL,
                    "messages": [
                        {"role": "system", "content": GENERATION_SYSTEM_PROMPT},
                        {"role": "user", "content": (
                            f"Artisan: {artisan_name}\n"
                            f"Craft Category: {craft_category}\n"
                            f"Attributes:\n{attr_text}\n\n"
                            f"Craft terms to preserve verbatim if present: {', '.join(CRAFT_TERMS_GLOSSARY)}"
                        )},
                    ],
                    "temperature": 0.4,
                    "response_format": {"type": "json_object"},
                }
            )
            resp.raise_for_status()
            return json.loads(resp.json()["choices"][0]["message"]["content"])
    except Exception:
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
