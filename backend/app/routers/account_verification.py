"""Private, account-owned verification evidence and manual review queue."""
from datetime import datetime
from io import BytesIO
from pathlib import Path
import uuid

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse
from PIL import Image, ImageOps, UnidentifiedImageError
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user, require_admin
from app.core.database import get_db
from app.models.models import (
    AccountRole, AccountVerification, AdminAuditLog, Artisan, Buyer, User)

router = APIRouter()
MEDIA = Path(__file__).resolve().parents[2] / 'uploads' / 'verification'
REQUIRED = {'artisan': {'identity', 'craft', 'selfie'}, 'buyer': {'business'}}


async def current_record(db, user):
    # Lock the account row to serialize create/upload/submit operations on PostgreSQL.
    await db.execute(select(User).where(User.id == user.id).with_for_update())
    return await db.scalar(select(AccountVerification).where(
        AccountVerification.user_id == user.id, AccountVerification.role == user.role.value))


def payload(record):
    if record is None:
        return {'status': 'not_started', 'evidence': {}, 'review_note': None}
    return {'id': record.id, 'user_id': record.user_id, 'role': record.role,
            'status': record.status, 'evidence': record.evidence,
            'review_note': record.review_note, 'submitted_at': record.submitted_at}


@router.get('/verification')
async def get_verification(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return payload(await current_record(db, user))


@router.post('/verification/evidence')
async def upload_evidence(kind: str = Form(...), file: UploadFile = File(...),
                          user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if kind not in REQUIRED[user.role.value]:
        raise HTTPException(422, 'Unsupported evidence type for this role')
    record = await current_record(db, user)
    if record and record.status in ('pending', 'verified'):
        raise HTTPException(409, 'Evidence is already submitted for review')
    raw = await file.read(8 * 1024 * 1024 + 1)
    await file.close()
    if len(raw) > 8 * 1024 * 1024:
        raise HTTPException(413, 'Choose an image smaller than 8 MB')
    try:
        with Image.open(BytesIO(raw)) as source:
            if source.format not in ('JPEG', 'PNG', 'WEBP') or source.width * source.height > 20_000_000:
                raise ValueError('Unsupported image')
            cleaned = ImageOps.exif_transpose(source).convert('RGB')
            cleaned.thumbnail((2400, 2400))
            output = BytesIO()
            cleaned.save(output, 'JPEG', quality=90)
    except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError):
        raise HTTPException(422, 'Upload a valid JPG, PNG or WebP photo')
    if record is None:
        record = AccountVerification(user_id=user.id, role=user.role.value, evidence={})
        db.add(record)
    MEDIA.mkdir(parents=True, exist_ok=True)
    filename = uuid.uuid4().hex + '.jpg'
    path = MEDIA / filename
    path.write_bytes(output.getvalue())
    previous = (record.evidence or {}).get(kind)
    record.evidence = {**(record.evidence or {}), kind: '/api/v1/auth/verification/evidence/' + filename}
    try:
        await db.commit()
    except Exception:
        path.unlink(missing_ok=True)
        raise
    if previous:
        (MEDIA / Path(previous).name).unlink(missing_ok=True)
    return payload(record)


@router.get('/verification/evidence/{filename}')
async def evidence(filename: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    records = (await db.scalars(select(AccountVerification).where(AccountVerification.user_id == user.id))).all()
    url = '/api/v1/auth/verification/evidence/' + filename
    if not any(url in (r.evidence or {}).values() for r in records):
        raise HTTPException(404, 'Evidence not found')
    path = MEDIA / Path(filename).name
    if not path.is_file():
        raise HTTPException(404, 'Evidence not found')
    return FileResponse(path, media_type='image/jpeg', headers={'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff'})


class Submission(BaseModel):
    consent: bool


@router.post('/verification/submit')
async def submit(data: Submission, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    record = await current_record(db, user)
    if record and record.status in ('pending', 'verified'):
        return payload(record)
    model = Artisan if user.role == AccountRole.artisan else Buyer
    profile = await db.scalar(select(model).where(model.user_id == user.id))
    if not user.name or not profile or not profile.state or (user.role == AccountRole.buyer and not profile.business_name):
        raise HTTPException(422, 'Complete your profile first')
    if not data.consent:
        raise HTTPException(422, 'Your consent is required')
    if record is None or not REQUIRED[user.role.value].issubset(record.evidence):
        raise HTTPException(422, 'Upload the requested evidence first')
    record.status = 'pending'
    record.consent_at = record.submitted_at = datetime.utcnow()
    record.review_note = None
    await db.commit()
    return payload(record)


@router.get('/verification-admin', dependencies=[Depends(require_admin)])
async def queue(db: AsyncSession = Depends(get_db)):
    return [payload(r) for r in (await db.scalars(select(AccountVerification))).all()]


@router.get('/verification-admin/{record_id}/evidence/{kind}', dependencies=[Depends(require_admin)])
async def admin_evidence(record_id: str, kind: str, db: AsyncSession = Depends(get_db)):
    record = await db.get(AccountVerification, record_id)
    url = (record.evidence or {}).get(kind) if record else None
    if not url or not (MEDIA / Path(url).name).is_file():
        raise HTTPException(404, 'Evidence not found')
    return FileResponse(MEDIA / Path(url).name, media_type='image/jpeg', headers={'Cache-Control': 'no-store'})


class Review(BaseModel):
    status: str = Field(pattern='^(verified|needs_correction|rejected)$')
    note: str = Field(min_length=1, max_length=2000)


@router.put('/verification-admin/{record_id}', dependencies=[Depends(require_admin)])
async def review(record_id: str, data: Review, db: AsyncSession = Depends(get_db)):
    record = await db.scalar(select(AccountVerification).where(AccountVerification.id == record_id).with_for_update())
    if not record:
        raise HTTPException(404, 'Verification not found')
    if record.status != 'pending':
        raise HTTPException(409, 'Only pending submissions can be reviewed')
    record.status, record.review_note = data.status, data.note.strip()
    model = Artisan if record.role == 'artisan' else Buyer
    profile = await db.scalar(select(model).where(model.user_id == record.user_id))
    profile.is_verified = data.status == 'verified'
    db.add(AdminAuditLog(
        actor='admin', action='verification_' + data.status,
        entity_type='verification', entity_id=record.id,
        summary=f'{record.role} verification {data.status}',
        note=record.review_note))
    await db.commit()
    return payload(record)
