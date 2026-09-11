"""
Pricing Service — Labour-aware, explainable pricing engine.

Core formula:
  cost_floor = material + labour(hours × fair_wage) + overhead  [hard floor]
  craftsmanship_score = weighted complexity (self-reported, category-normalized)
  comparable_range = vector-search over HANDMADE-ONLY products
  recommended_price = clamp(cost_floor * (1 + margin), comparable_min, comparable_max)
  explanation = template string with actual computed numbers (not LLM-generated)
"""
from typing import Any, Dict, List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

# Category-specific craftsmanship multiplier ranges (fair wage floors)
CRAFT_WAGE_FLOORS = {
    "pottery": 120,
    "weaving": 150,
    "embroidery": 160,
    "woodcraft": 140,
    "metalcraft": 180,
    "painting": 200,
    "leathercraft": 130,
    "jewelry": 250,
    "other": 120,
}

# Demo comparable data (production: from pgvector similarity search)
DEMO_COMPARABLES = {
    "pottery": [
        {"name": "Handmade Clay Pot — Jaipur Crafts", "price": 2350, "source": "Craftsvilla"},
        {"name": "Traditional Matka — IndiaCraft", "price": 2500, "source": "IndiaCraft"},
        {"name": "Terracotta Water Pot — Artisera", "price": 2700, "source": "Artisera"},
    ],
    "weaving": [
        {"name": "Handloom Dupatta — Bandhani", "price": 1800, "source": "FabIndia"},
        {"name": "Hand-woven Shawl — Kutch", "price": 2200, "source": "Craftsvilla"},
    ],
    "embroidery": [
        {"name": "Phulkari Dupatta — Punjab", "price": 1500, "source": "IndiaCraft"},
        {"name": "Kashmiri Embroidery Stole", "price": 2800, "source": "Artisera"},
    ],
    "woodcraft": [
        {"name": "Carved Wooden Elephant", "price": 1200, "source": "Craftsvilla"},
        {"name": "Traditional Wooden Box — Rajasthan", "price": 800, "source": "IndiaCraft"},
    ],
    "jewelry": [
        {"name": "Tribal Silver Necklace", "price": 3500, "source": "Artisera"},
        {"name": "Oxidised Earrings Set", "price": 850, "source": "FabIndia"},
    ],
    "other": [
        {"name": "Handmade Craft Item", "price": 1000, "source": "Generic"},
    ],
}


async def compute_price_recommendation(
    craft_category: str,
    material_cost: float,
    labour_cost: float,
    overhead: float,
    craftsmanship_complexity: float,  # 0–1 artisan-reported
    db: AsyncSession,
) -> Dict[str, Any]:
    """
    Computes an explainable, labour-aware price recommendation.
    Returns explanation as templated strings (not free-form LLM output —
    ensures accuracy and auditability).
    """
    cost_floor = material_cost + labour_cost + overhead

    # Craftsmanship score = blend of complexity + category premium
    category_premium = CRAFT_WAGE_FLOORS.get(craft_category, 120) / 120.0
    craftsmanship_score = round(
        (craftsmanship_complexity * 0.6 + (category_premium - 1.0) * 0.4), 2
    )
    craftsmanship_score = min(max(craftsmanship_score, 0.0), 1.0)

    # Get comparables (HANDMADE-ONLY — machine-made excluded)
    comparables = DEMO_COMPARABLES.get(craft_category, DEMO_COMPARABLES["other"])
    comparable_prices = [c["price"] for c in comparables]
    market_min = min(comparable_prices) if comparable_prices else cost_floor * 1.2
    market_max = max(comparable_prices) if comparable_prices else cost_floor * 1.8

    # Hard floor enforcement + craftsmanship-adjusted recommendation
    base_margin = 0.30 + craftsmanship_score * 0.25   # 30–55% margin range
    recommended_min = max(cost_floor * (1 + base_margin), cost_floor * 1.15)
    recommended_max = min(cost_floor * (1 + base_margin + 0.3), market_max * 1.05)
    recommended_min = max(cost_floor, round(min(recommended_min, market_max), 0))
    recommended_max = max(recommended_min, cost_floor, round(min(recommended_max, market_max * 1.1), 0))

    margin_en = recommended_min - cost_floor
    margin_hi = recommended_max - cost_floor

    # Templated explanation (auditable, not LLM-generated)
    explanation_en = (
        f"₹{recommended_min:.0f}–₹{recommended_max:.0f} recommended because your total cost is "
        f"₹{cost_floor:.0f} (materials ₹{material_cost:.0f} + labour ₹{labour_cost:.0f} + "
        f"overhead ₹{overhead:.0f}). Similar handmade {craft_category} products sell for "
        f"₹{market_min:.0f}–₹{market_max:.0f} — machine-made products excluded. "
        f"Your craftsmanship score of {int(craftsmanship_score * 100)}% earns a premium, "
        f"giving you ₹{margin_en:.0f}–₹{margin_hi:.0f} margin while staying competitive."
    )

    explanation_hi = (
        f"₹{recommended_min:.0f}–₹{recommended_max:.0f} की सिफारिश इसलिए की जाती है क्योंकि "
        f"आपकी कुल लागत ₹{cost_floor:.0f} है (सामग्री ₹{material_cost:.0f} + "
        f"मजदूरी ₹{labour_cost:.0f} + अन्य ₹{overhead:.0f})। "
        f"इसी तरह के हस्तनिर्मित {craft_category} उत्पाद ₹{market_min:.0f}–₹{market_max:.0f} में बिकते हैं। "
        f"आपका शिल्पकारी स्कोर {int(craftsmanship_score * 100)}% है, जिससे आपको "
        f"₹{margin_en:.0f}–₹{margin_hi:.0f} का मुनाफा मिलता है।"
    )

    return {
        "craftsmanship_score": craftsmanship_score,
        "comparable_ids": [f"demo_{i}" for i in range(len(comparables))],
        "recommended_min": recommended_min,
        "recommended_max": recommended_max,
        "explanation_en": explanation_en,
        "explanation_hi": explanation_hi,
        "comparables": comparables,
        "market_min": market_min,
        "market_max": market_max,
    }
