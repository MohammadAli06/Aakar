"""Application settings from environment variables."""
from pydantic_settings import BaseSettings
from typing import Optional


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
    LLM_API_KEY: Optional[str] = None
    LLM_API_BASE: str = "https://api.groq.com/openai/v1"
    LLM_MODEL: str = "llama-3.1-70b-versatile"
    # OpenAI Product Studio (server-side only; independent of text LLM settings).
    OPENAI_API_KEY: Optional[str] = None
    OPENAI_IMAGE_MODEL: str = "gpt-image-2.5-sunburst"
    OPENAI_VISION_MODEL: str = "gpt-4.1-mini"
    OPENAI_TIMEOUT_SECONDS: float = 180
    # Legacy entries accepted so existing .env files still load; no Gemini calls.
    GEMINI_API_KEY: Optional[str] = None
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


settings = Settings()
