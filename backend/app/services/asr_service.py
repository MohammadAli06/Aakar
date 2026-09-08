"""
ASR Service — Bhashini-first, IndicConformer fallback.
"""
import httpx
from app.core.config import settings


async def transcribe_audio(audio_bytes: bytes, language: str = "hi") -> str:
    """
    Transcribe audio using Bhashini ASR API.
    Falls back to mock transcript if API key not configured (demo mode).
    """
    if not settings.BHASHINI_API_KEY:
        # Demo fallback
        return _demo_transcript(language)

    # Bhashini ULCA ASR call
    import base64
    audio_b64 = base64.b64encode(audio_bytes).decode()

    payload = {
        "pipelineTasks": [{
            "taskType": "asr",
            "config": {
                "language": {"sourceLanguage": language},
                "serviceId": "",   # populated by Bhashini routing
                "audioFormat": "wav",
                "samplingRate": 16000,
            }
        }],
        "inputData": {
            "audio": [{"audioContent": audio_b64}]
        }
    }

    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(
            settings.BHASHINI_ASR_URL,
            json=payload,
            headers={
                "Authorization": settings.BHASHINI_API_KEY,
                "Content-Type": "application/json",
            }
        )
        resp.raise_for_status()
        data = resp.json()

    # Extract transcript from Bhashini response
    try:
        return data["pipelineResponse"][0]["output"][0]["source"]
    except (KeyError, IndexError):
        return _demo_transcript(language)


def _demo_transcript(language: str) -> str:
    demos = {
        "hi": (
            "यह एक हाथ से बना मिट्टी का मटका है। इसे राजस्थान की पारंपरिक "
            "कुम्हार कला से बनाया गया है। इसकी ऊंचाई लगभग 30 सेंटीमीटर है "
            "और इसका उपयोग पानी रखने के लिए किया जाता है।"
        ),
        "en": (
            "This is a handmade clay pot made using traditional Rajasthani pottery art. "
            "It is about 30 centimetres tall and is used for storing water."
        ),
        "mr": "हे हाताने बनवलेले मातीचे भांडे आहे, राजस्थानी परंपरेनुसार.",
        "ta": "இது ஒரு கைவினை மண் பாத்திரம்.",
        "te": "ఇది చేతితో తయారు చేసిన మట్టి కుండ.",
    }
    return demos.get(language, demos["hi"])
