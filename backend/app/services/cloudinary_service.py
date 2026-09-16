"""Signed original upload and on-the-fly background removal; no Flutter secrets."""
import asyncio
import base64
import hashlib
import re
import time
import uuid
from urllib.parse import unquote, urlparse

import httpx

from app.core.config import settings
from app.services.ai_provider import ProviderError

MAX_BYTES = 12 * 1024 * 1024


def credentials():
    try:
        url = urlparse(settings.CLOUDINARY_URL or '')
        if (url.scheme != 'cloudinary' or not url.username or not url.password
                or not re.fullmatch(r'[a-zA-Z0-9_-]+', url.hostname or '')):
            raise ValueError()
        return url.hostname, unquote(url.username), unquote(url.password)
    except ValueError:
        raise ProviderError('Set a valid CLOUDINARY_URL in backend/.env and restart.', 503) from None


async def remove_background(data):
    cloud, key, secret = credentials()
    public_id = 'aakar/studio/' + uuid.uuid4().hex
    params = {'public_id': public_id, 'timestamp': str(int(time.time())), 'overwrite': 'false'}
    signing = '&'.join(f'{k}={v}' for k, v in sorted(params.items())) + secret
    signature = hashlib.sha1(signing.encode()).hexdigest()
    # The original upload is retained; only a derived PNG is transformed.
    path = f'e_background_removal/{public_id}.png'
    digest = hashlib.sha1((path + secret).encode()).digest()
    delivery_signature = base64.urlsafe_b64encode(digest).decode()[:8]
    delivery = f'https://res.cloudinary.com/{cloud}/image/upload/s--{delivery_signature}--/{path}'
    try:
        async with asyncio.timeout(settings.AI_TIMEOUT_SECONDS):
            async with httpx.AsyncClient(timeout=settings.AI_TIMEOUT_SECONDS) as client:
                response = await client.post(f'https://api.cloudinary.com/v1_1/{cloud}/image/upload',
                    data={**params, 'api_key': key, 'signature': signature},
                    files={'file': ('original.jpg', data, 'image/jpeg')})
                if response.status_code in (401, 403):
                    raise ProviderError('Cloudinary access failed. Check CLOUDINARY_URL and account permissions.', 503)
                response.raise_for_status()
                for attempt in range(30):
                    async with client.stream('GET', delivery) as result:
                        if result.status_code != 423:
                            result.raise_for_status()
                            chunks = bytearray()
                            async for chunk in result.aiter_bytes():
                                chunks.extend(chunk)
                                if len(chunks) > MAX_BYTES:
                                    raise ProviderError('Cloudinary returned an image larger than 12 MB.', 502)
                            return bytes(chunks)
                    await asyncio.sleep(min(1 + attempt, 3))
                raise ProviderError('Cloudinary is still preparing the background. Please retry.', 504)
    except (TimeoutError, httpx.TimeoutException):
        raise ProviderError('Cloudinary took too long. Your original is unchanged; please retry.', 504) from None
    except httpx.HTTPError:
        raise ProviderError('Cloudinary background removal failed. Check account transformation access and usage limits, then retry.') from None
