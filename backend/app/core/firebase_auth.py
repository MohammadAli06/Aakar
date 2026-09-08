"""Firebase Admin SDK token verification."""
import firebase_admin
from firebase_admin import credentials, auth
from app.core.config import settings

_initialized = False


def _init_firebase():
    global _initialized
    if not _initialized:
        if settings.FIREBASE_CREDENTIALS_PATH:
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
        else:
            cred = credentials.ApplicationDefault()
        try:
            firebase_admin.initialize_app(cred, {
                "storageBucket": settings.FIREBASE_STORAGE_BUCKET,
                "projectId": settings.FIREBASE_PROJECT_ID,
            })
            _initialized = True
        except Exception:
            pass  # Already initialized or no creds (demo mode)


async def verify_firebase_token(id_token: str) -> dict:
    """
    Verify a Firebase ID token and return decoded claims.
    In demo mode (no Firebase credentials), returns mock claims.
    """
    if not settings.FIREBASE_CREDENTIALS_PATH:
        # Demo mode — trust any token, return mock claims
        return {
            "uid": f"demo_{id_token[:8]}",
            "phone_number": "+919876543210",
            "email": None,
        }

    _init_firebase()
    try:
        decoded = auth.verify_id_token(id_token)
        return decoded
    except Exception as e:
        raise ValueError(f"Invalid Firebase token: {e}")
