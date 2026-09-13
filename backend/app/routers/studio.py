"""Authenticated, non-publishing Product Studio previews and suggestions."""
from typing import Literal

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from app.core.auth_deps import require_artisan
from app.services import studio_service

router = APIRouter(dependencies=[Depends(require_artisan)])


@router.post('/prepare')
async def prepare_photo(
    file: UploadFile = File(...),
    mode: Literal['plainBackground', 'naturalSetting', 'b2bCatalog'] = Form(...),
    catalog_plain_background: bool = Form(True),
):
    data = await file.read(studio_service.MAX_BYTES + 1)
    try:
        return await studio_service.prepare(data, mode, catalog_plain_background)
    except studio_service.StudioError as exc:
        raise HTTPException(exc.status, str(exc)) from None


@router.post('/catalog')
async def analyze_catalog(
    file: UploadFile = File(...),
    notes: str = Form('', max_length=3000),
    language: Literal['en', 'hi'] = Form('en'),
):
    data = await file.read(studio_service.MAX_BYTES + 1)
    try:
        return await studio_service.analyze(data, notes, language)
    except studio_service.StudioError as exc:
        raise HTTPException(exc.status, str(exc)) from None
