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
    FIREBASE_CREDENTIALS_PATH: Optional[str] = None
    FIREBASE_PROJECT_ID: str = "craftconnect-sih26"

    # Storage (Firebase / S3)
    FIREBASE_STORAGE_BUCKET: str = "craftconnect-sih26.appspot.com"

    # Redis (Celery broker)
    REDIS_URL: str = "redis://localhost:6379/0"
    CELERY_BROKER_URL: str = "redis://localhost:6379/0"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/1"

    # AI / Models
    LLM_API_KEY: Optional[str] = None
    LLM_API_BASE: str = "https://api.groq.com/openai/v1"
    LLM_MODEL: str = "llama-3.1-70b-versatile"

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
