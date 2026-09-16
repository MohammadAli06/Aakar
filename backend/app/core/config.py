"""Application settings from environment variables."""
from pydantic_settings import BaseSettings
from typing import Literal, Optional


class Settings(BaseSettings):
    # App
    APP_NAME: str = "Aakar API"
    ENVIRONMENT: str = "development"
    DEBUG: bool = True
    ENABLE_DEMO_WORKSPACE: bool = False
    WORKSPACE_DEMO_TOKEN: Optional[str] = None
    ADMIN_ACCESS_TOKEN: Optional[str] = None

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://craftconnect:craftconnect@localhost:5432/craftconnect"

    # Firebase Admin SDK
    # Token verification requires a service account key from the Firebase
    # project that issued the app's google-services.json (project `aakar-sih`).
    FIREBASE_CREDENTIALS_PATH: Optional[str] = None
    FIREBASE_PROJECT_ID: str = "aakar-sih"

    # Storage (Firebase / S3)
    FIREBASE_STORAGE_BUCKET: str = "aakar-sih.firebasestorage.app"

    # Redis (Celery broker)
    REDIS_URL: str = "redis://localhost:6379/0"
    CELERY_BROKER_URL: str = "redis://localhost:6379/0"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/1"

    # AI / Models
    # Groq is the free text tier. llama-3.1-70b-versatile was retired by Groq and
    # now 404s; openai/gpt-oss-120b is the current large text model on the free tier.
    LLM_API_KEY: Optional[str] = None
    LLM_API_BASE: str = "https://api.groq.com/openai/v1"
    LLM_MODEL: str = "openai/gpt-oss-120b"

    # Per-task model overrides. Each task falls back to LLM_* when its own entry is
    # unset, so existing .env files keep working without edits.
    EXTRACTION_MODEL: Optional[str] = None
    EXTRACTION_BASE: Optional[str] = None
    EXTRACTION_KEY: Optional[str] = None
    GENERATION_MODEL: Optional[str] = None
    GENERATION_BASE: Optional[str] = None
    GENERATION_KEY: Optional[str] = None
    NEGOTIATION_MODEL: Optional[str] = None
    NEGOTIATION_BASE: Optional[str] = None
    NEGOTIATION_KEY: Optional[str] = None
    # Legacy presets accepted for existing env files; judge selection now uses
    # AI_PROVIDER_PROFILE below.
    TRANSLATION_QA_MODEL: Optional[str] = None
    TRANSLATION_QA_BASE: Optional[str] = None
    TRANSLATION_QA_KEY: Optional[str] = None

    # OpenAI Product Studio (server-side only; independent of text LLM settings).
    AI_PROVIDER_PROFILE: Literal['openai', 'cloudinary_openrouter', 'cloudinary_gemini'] = 'openai'
    CLOUDINARY_URL: Optional[str] = None
    OPENROUTER_API_KEY: Optional[str] = None
    OPENROUTER_VISION_MODEL: str = 'google/gemma-4-26b-a4b-it:free'
    AI_TIMEOUT_SECONDS: float = 180
    OPENAI_API_KEY: Optional[str] = None
    OPENAI_IMAGE_MODEL: str = "gpt-image-2.5-sunburst"
    OPENAI_VISION_MODEL: str = "gpt-4.1-mini"
    # Judge model for the OpenAI profile.
    OPENAI_TRANSLATION_MODEL: str = "gpt-4.1-mini"
    OPENAI_TIMEOUT_SECONDS: float = 180
    # Direct Google Gemini API for the cloudinary_gemini profile.
    GEMINI_API_KEY: Optional[str] = None
    GEMINI_MODEL: str = 'gemini-3.8-flash'
    # Legacy image/vision settings are retained but not used by the profile.
    GEMINI_IMAGE_MODEL: str = "gemini-3.1-flash-image"
    GEMINI_VISION_MODEL: str = "gemini-2.5-flash"
    GEMINI_TIMEOUT_SECONDS: float = 120

    # Bhashini ASR
    BHASHINI_API_KEY: Optional[str] = None
    SARVAM_API_KEY: Optional[str] = None
    BHASHINI_ASR_URL: str = "https://dhruva-api.bhashini.gov.in/services/inference/pipeline"

    # JWT
    SECRET_KEY: str = "change-me-in-production-sih26-craftconnect"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080  # 7 days

    # CORS
    BACKEND_CORS_ORIGINS: list[str] = ["*"]

    class Config:
        env_file = ".env"
        case_sensitive = True
        # Shared .env files may contain inactive provider presets.
        extra = 'ignore'


settings = Settings()

# Tasks that share the free Groq text tier unless they set their own *_MODEL/_BASE/_KEY.
FREE_TIER_TASKS = ('extraction', 'generation', 'negotiation')


def chat_completions_url(base: str) -> str:
    """Join a configured OpenAI-compatible base URL with the chat completions path."""
    return base.rstrip('/') + '/chat/completions'


def free_tier(task: str):
    """Resolve (base, key, model) for a free-tier task.

    Resolution order per field: task-specific *_MODEL/*_BASE/*_KEY, then LLM_*.
    Returns (base, key, model) with key None when the free tier is not configured,
    which callers treat as "no primary provider" rather than an error.
    """
    name = task.upper()
    override = getattr(settings, f'{name}_MODEL', None)
    base = getattr(settings, f'{name}_BASE', None) or settings.LLM_API_BASE
    key = getattr(settings, f'{name}_KEY', None) or settings.LLM_API_KEY
    return base, key, override or settings.LLM_MODEL
