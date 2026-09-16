"""Back-translation validation for generated bilingual listings.

Translates a generated description back into the pivot language, then asks an LLM
whether the round trip still carries the same product facts. Catches meaning drift
that native bilingual generation can quietly introduce.

Uses the selected AI_PROVIDER_PROFILE without cross-provider fallback.
Failures are advisory and never imply a passing check.

Language codes are parameters rather than constants: the same functions serve a future
Marathi or Bengali listing without a rewrite.
"""
import json
import logging


from app.services import ai_provider

logger = logging.getLogger(__name__)

LANGUAGE_NAMES = {
    'hi': 'Hindi',
    'en': 'English',
    'mr': 'Marathi',
    'bn': 'Bengali',
    'ta': 'Tamil',
    'te': 'Telugu',
}

# At or above this score the round trip is treated as carrying the same product facts.
CHECKED_THRESHOLD = 0.75

# Matches studio_service.FIELD_LIMITS['description'].
MAX_TEXT = 600

_TRANSLATOR_PROMPT = (
    'You are a professional translator for handmade Indian craft product listings. '
    'Translate the supplied text faithfully into {target}. Preserve regional craft terms '
    'verbatim (matka, bandhani, ikat, phulkari, chikankari). Keep numbers, units and '
    'measurements exactly as given. Do not explain, summarise, add or omit anything. '
    'Return only the translation.'
)

_JUDGE_PROMPT = """You check whether two English texts convey the SAME product information.

They are an original description and a back-translation of its translation into another
language. Wording, sentence order, grammar and writing style will differ - IGNORE those.
Judge only whether the product facts agree: object, material, craft, colour, size,
quantity, use and origin.

Score 1.0 when every stated fact agrees. Lower the score for each fact that is added,
dropped, or changed into a different meaning. Score 0.0 when they describe different
products.

Return ONLY valid JSON: {"score": <float between 0.0 and 1.0>}"""


def _unavailable(reason, source_lang, pivot_lang):
    logger.info('Translation check unavailable (%s)', reason)
    return {
        'roundtrip': '',
        'roundtrip_score': 0.0,
        'confidence_label': 'unavailable',
        'source_lang': source_lang,
        'pivot_lang': pivot_lang,
        'method': 'unavailable',
        'is_fallback': True,
    }


async def _request(messages, json_mode=False):
    """Use only the selected profile, without paid fallback."""
    try:
        text = await ai_provider.chat(messages, task='translation', json_mode=json_mode)
        return {'choices': [{'message': {'content': text}}]}, ai_provider.selected_provider()
    except ai_provider.ProviderError:
        logger.info('Translation check unavailable for selected provider')
        return None, None


async def back_translate(text, source_lang='hi', pivot_lang='en'):
    """Translate text into the pivot language. Returns None when it cannot."""
    if not (text or '').strip():
        return None
    target = LANGUAGE_NAMES.get(pivot_lang, pivot_lang)
    result, _ = await _request([
        {'role': 'system', 'content': _TRANSLATOR_PROMPT.format(target=target)},
        {'role': 'user', 'content': text.strip()},
    ])
    if result is None:
        return None
    try:
        translated = result['choices'][0]['message']['content']
        return translated.strip() or None
    except (KeyError, IndexError, TypeError, AttributeError):
        return None


async def equivalence_score(english, roundtrip):
    """LLM judgement of whether two English texts carry the same product facts."""
    if not (english or '').strip() or not (roundtrip or '').strip():
        return None
    result, _ = await _request([
        {'role': 'system', 'content': _JUDGE_PROMPT},
        {'role': 'user', 'content': json.dumps(
            {'original': english.strip(), 'back_translation': roundtrip.strip()},
            ensure_ascii=False)},
    ], json_mode=True)
    if result is None:
        return None
    try:
        raw = result['choices'][0]['message']['content']
        return max(0.0, min(1.0, float(ai_provider.parse_json(raw)['score'])))
    except (KeyError, IndexError, TypeError, ValueError, AttributeError):
        return None


async def check_round_trip(english, translated_text, source_lang='hi', pivot_lang='en'):
    """Back-translate `translated_text` and compare it with `english`.

    Returns an advisory result dict. Never raises: every failure mode is reported as
    ``is_fallback=True`` with ``confidence_label='unavailable'``.
    """
    english = (english or '').strip()
    translated_text = (translated_text or '').strip()
    if not english or not translated_text:
        return _unavailable('no paired text', source_lang, pivot_lang)
    if not ai_provider.transport('translation')[1]:
        return _unavailable('no provider configured', source_lang, pivot_lang)

    roundtrip = await back_translate(translated_text, source_lang, pivot_lang)
    if not roundtrip:
        return _unavailable('translation failed', source_lang, pivot_lang)

    score = await equivalence_score(english, roundtrip)
    if score is None:
        return _unavailable('comparison failed', source_lang, pivot_lang)

    return {
        'roundtrip': roundtrip,
        'roundtrip_score': round(score, 2),
        'confidence_label': 'checked' if score >= CHECKED_THRESHOLD else 'review',
        'source_lang': source_lang,
        'pivot_lang': pivot_lang,
        'method': ai_provider.selected_provider(),
        'is_fallback': False,
    }

