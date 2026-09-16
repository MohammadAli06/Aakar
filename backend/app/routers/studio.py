"""Authenticated, non-publishing Product Studio previews and suggestions."""
from typing import Literal

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from pydantic import BaseModel, Field
from app.core.auth_deps import require_artisan
from app.services import studio_service, translation_qa_service

router = APIRouter(dependencies=[Depends(require_artisan)])


class TranslationCheckRequest(BaseModel):
    description: str = Field(min_length=1, max_length=translation_qa_service.MAX_TEXT)
    description_hi: str = Field(min_length=1, max_length=translation_qa_service.MAX_TEXT)
    source_lang: str = 'hi'


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


@router.post('/translation-check')
async def translation_check(payload: TranslationCheckRequest):
    """Advisory back-translation check for the Listen & Verify step.

    Compares the generated description against a back-translation of its translated
    counterpart. Never blocks or fails the artisan: an unavailable check is reported
    as a fallback so the UI does not imply a verification that did not happen.
    """
    if payload.source_lang not in translation_qa_service.LANGUAGE_NAMES:
        raise HTTPException(422, 'Unsupported source language')
    return await translation_qa_service.check_round_trip(
        payload.description, payload.description_hi, payload.source_lang)
