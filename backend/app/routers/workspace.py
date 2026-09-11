"""Explicit shared demo workspace; separate admin capability and revision checks."""
import secrets
import io
import re
import uuid
from pathlib import Path
from fastapi import APIRouter, Depends, Header, HTTPException, UploadFile, File
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field
from sqlalchemy import Column, Integer, JSON, String, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm.exc import StaleDataError
from app.core.config import settings
from app.core.database import Base, get_db
from app.services import workflow_service as workflow
from app.services.workflow_assistant import assist
from PIL import Image, UnidentifiedImageError

router = APIRouter()


class Workspace(Base):
    __tablename__ = 'demo_workspaces'
    id = Column(String, primary_key=True)
    version = Column(Integer, nullable=False, default=0)
    data = Column(JSON, nullable=False)
    __mapper_args__ = {'version_id_col': version, 'version_id_generator': False}


class Command(BaseModel):
    action: str = Field(max_length=50)
    input: dict = Field(default_factory=dict)
    role: str
    actor: str
    version: int = Field(ge=0)


async def access(authorization: str = Header(default='')):
    if not settings.ENABLE_DEMO_WORKSPACE or settings.ENVIRONMENT == 'production':
        raise HTTPException(404, 'Demo workspace is disabled')
    token = authorization.removeprefix('Bearer ').strip()
    if not token:
        raise HTTPException(401, 'Demo workspace token required')
    if settings.ADMIN_ACCESS_TOKEN and secrets.compare_digest(token, settings.ADMIN_ACCESS_TOKEN):
        return 'admin'
    if settings.WORKSPACE_DEMO_TOKEN and secrets.compare_digest(token, settings.WORKSPACE_DEMO_TOKEN):
        return 'demo'
    raise HTTPException(401, 'Invalid workspace token')


async def get_workspace(db):
    record = (await db.execute(select(Workspace).where(Workspace.id == 'hackathon').with_for_update())).scalar_one_or_none()
    if record is None:
        record = Workspace(id='hackathon', version=0, data=workflow.seed())
        db.add(record)
        await db.flush()
    return record


@router.get('')
async def snapshot(_access=Depends(access), db: AsyncSession = Depends(get_db)):
    record = await get_workspace(db)
    result = record.data
    await db.commit()
    return result


@router.post('/actions')
async def command(command: Command, capability=Depends(access), db: AsyncSession = Depends(get_db)):
    if command.role == 'admin':
        if capability != 'admin' or command.actor != 'admin':
            raise HTTPException(403, 'Separate admin access token required')
    elif command.role not in ('buyer', 'artisan'):
        raise HTTPException(403, 'Invalid role')
    record = await get_workspace(db)
    if record.version != command.version:
        raise HTTPException(409, 'Workspace changed. Refresh and review before retrying.')
    if command.role != 'admin' and not any(p['id'] == command.actor and p['role'] == command.role for p in record.data['profiles']):
        raise HTTPException(403, 'Demo identity is not assigned this role')
    if command.action in ('verify', 'moderate', 'resolve') and capability != 'admin':
        raise HTTPException(403, 'Admin permission required')
    try:
        updated = workflow.apply(record.data, command.action, command.input, command.role, command.actor)
    except (ValueError, KeyError, TypeError) as exc:
        raise HTTPException(422, str(exc)) from None
    record.data = updated
    record.version = updated['version']
    try:
        await db.commit()
    except StaleDataError:
        await db.rollback()
        raise HTTPException(409, 'Concurrent update. Refresh and review before retrying.') from None
    return updated


@router.get('/admin', include_in_schema=False)
async def admin_page():
    # HTML carries no business data; all data/actions require the separate token.
    return FileResponse(Path(__file__).parents[2] / 'admin' / 'index.html')


@router.get('/admin-access')
async def admin_access(capability=Depends(access)):
    if capability != 'admin':
        raise HTTPException(403, 'Admin access token required')
    return {'access': 'admin'}


class AssistRequest(BaseModel):
    task: str
    text: str = Field(min_length=1, max_length=6000)
    language: str = 'en'


@router.post('/assist')
async def assistant(data: AssistRequest, _access=Depends(access)):
    if data.task not in ('catalog', 'requirement', 'translate', 'negotiation') or data.language not in ('en', 'hi'):
        raise HTTPException(422, 'Unsupported assistant task or language')
    return await assist(data.task, data.text, data.language)


MEDIA = Path(__file__).parents[2] / 'uploads' / 'workspace'


@router.post('/media')
async def upload(file: UploadFile = File(...), _access=Depends(access)):
    data = await file.read(12 * 1024 * 1024 + 1)
    if len(data) > 12 * 1024 * 1024:
        raise HTTPException(413, 'Photo must be smaller than 12 MB')
    try:
        with Image.open(io.BytesIO(data)) as image:
            if image.width * image.height > 24000000:
                raise HTTPException(413, 'Image dimensions are too large')
            image.load()
            image = image.convert('RGB')
            image.thumbnail((2000, 2000))
            MEDIA.mkdir(parents=True, exist_ok=True)
            name = uuid.uuid4().hex + '.jpg'
            # Re-encode to strip EXIF/location metadata and reject executable uploads.
            image.save(MEDIA / name, 'JPEG', quality=92)
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError):
        raise HTTPException(422, 'Upload a valid product/evidence image') from None
    return {'path': '/api/v1/workspace/media/' + name}


@router.get('/media/{name}')
async def media(name: str, _access=Depends(access)):
    if not re.fullmatch(r'[a-f0-9]{32}\.jpg', name) or not (MEDIA / name).is_file():
        raise HTTPException(404, 'Photo not found')
    return FileResponse(MEDIA / name, media_type='image/jpeg', headers={'Cache-Control': 'private, max-age=300'})
