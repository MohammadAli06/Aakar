"""Firebase Admin SDK token verification."""
from typing import Optional

import firebase_admin
from firebase_admin import auth, credentials

from app.core.config import settings

_initialized = False


def _init_firebase() -> bool:
    """Initialise the Admin SDK once. Returns False when no credentials exist."""
    global _initialized
    if _initialized:
        return True
    try:
        if settings.FIREBASE_CREDENTIALS_PATH:
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
        else:
            cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred, {
            "storageBucket": settings.FIREBASE_STORAGE_BUCKET,
            "projectId": settings.FIREBASE_PROJECT_ID,
        })
    except Exception:
        pass

    try:
        firebase_admin.get_app()
        _initialized = True
    except ValueError:
        _initialized = False
    return _initialized


def firebase_ready() -> bool:
    return _init_firebase()


async def verify_firebase_token(id_token: str) -> dict:
    """Verify a Firebase ID token and return its decoded claims."""
    if not _init_firebase():
        raise ValueError(
            "Firebase Admin is not configured on the server. "
            "Set FIREBASE_CREDENTIALS_PATH to a service account key."
        )
    try:
        return auth.verify_id_token(id_token)
    except Exception as e:
        raise ValueError(f"Invalid Firebase token: {e}")


def set_role_claim(uid: str, role: str) -> None:
    """Best-effort: mirror the account role into the Firebase custom claims."""
    if not _init_firebase():
        return
    try:
        auth.set_custom_user_claims(uid, {"role": role})
    except Exception:
        pass
