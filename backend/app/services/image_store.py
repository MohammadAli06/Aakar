"""Shared storage for user-supplied photographs.

Product catalogue photos and requirement reference images go through the same
validation: a size cap, a pixel cap, an EXIF/location strip by re-encoding, and
an unguessable file name. Identity and verification evidence does not use this
path and keeps its authenticated endpoints.
"""
import io
import uuid
from pathlib import Path

from fastapi import HTTPException
from PIL import Image, UnidentifiedImageError

MAX_BYTES = 12 * 1024 * 1024
MAX_PIXELS = 24_000_000
MAX_EDGE = 2000


def store_photo(data: bytes, folder: Path, label: str = 'photo') -> str:
    """Validate and save one photo, returning the generated file name."""
    if len(data) > MAX_BYTES:
        raise HTTPException(status_code=413, detail='Photo must be smaller than 12 MB')
    try:
        with Image.open(io.BytesIO(data)) as image:
            if image.width * image.height > MAX_PIXELS:
                raise HTTPException(status_code=413, detail='Image dimensions are too large')
            image.load()
            image = image.convert('RGB')
            image.thumbnail((MAX_EDGE, MAX_EDGE))
            folder.mkdir(parents=True, exist_ok=True)
            name = uuid.uuid4().hex + '.jpg'
            image.save(folder / name, 'JPEG', quality=92)
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError):
        raise HTTPException(status_code=422, detail=f'Upload a valid {label}') from None
    return name
