# OpenAI Product Studio

Migrated from Gemini to OpenAI on 2026-09-14. This replaces the active on-device flood-fill path with a backend preview service. The local Dart processing helpers remain for legacy use and tests; the app does not silently fall back to them when OpenAI fails.

## Configure the backend

Add these entries to **`backend/.env`**, alongside the existing database and Firebase settings:

```dotenv
OPENAI_API_KEY=your_openai_api_key_here
OPENAI_IMAGE_MODEL=gpt-image-2.5-sunburst
OPENAI_VISION_MODEL=gpt-4.1-mini
OPENAI_TIMEOUT_SECONDS=180
```

The same key serves both OpenAI models. It is separate from `LLM_API_KEY`, which remains the existing text-assistant provider configuration. No OpenAI key belongs in Flutter, a Dart define, or the committed environment template. Keep existing settings; do not replace the whole `.env` file.

Restart the backend from its directory:

```powershell
cd backend
.venv/Scripts/python.exe -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The app uses its existing `API_BASE_URL` and Firebase bearer token. An artisan account is required. The backend uses `httpx` with OpenAI's `POST /v1/images/edits` for photo cleanup and `POST /v1/responses` for catalog extraction. No new SDK dependency is needed. Image requests upload the normalized original as multipart, ask for one high-quality JPEG at automatic aspect ratio, and decode `data[0].b64_json`. Catalog requests include the original as an image input, strict JSON schema, and `store=false`; incomplete/refused responses are discarded. Backend timeout defaults to 180 seconds; the Flutter request allows 210 seconds.

A paid ChatGPT subscription does not fund these API calls. Create a key in the [OpenAI API dashboard](https://platform.openai.com/api-keys), configure API billing/credit and model access, then restart the backend. No key is read from ChatGPT or Codex login. Old `GEMINI_*` settings are accepted only so existing environment files still load; they are never used by Studio. Existing `LLM_*` settings remain independent.

OpenAI 429 `insufficient_quota`/`billing_hard_limit_reached` errors explain that API credit or spending limits need attention. Other 429 responses ask the user to wait and check rate limits. Access, invalid request, timeout and malformed response errors have distinct safe messages. Provider bodies and secrets are never returned. Failed requests do not silently call another provider or overwrite the original; there are no automatic paid retries.

The integration follows the official [image-editing guide](https://developers.openai.com/api/docs/guides/image-generation) and [structured-output guide](https://developers.openai.com/api/docs/guides/structured-outputs). [GPT Image 2.5 Sunburst](https://developers.openai.com/api/docs/models/gpt-image-2.5-sunburst) is selected for editing precision; [GPT-4.1 mini](https://developers.openai.com/api/docs/models/gpt-4.1-mini) handles the narrow catalog extraction task with image input and structured text output. Both model names are independently configurable; changed models must support the documented endpoints and request settings. Model access and actual photo quality have not been verified against a live account.

## Three photo options

| Option | Processing |
|---|---|
| Plain white background | OpenAI edits the supplied image. The prompt requests pure-white surroundings while preserving the entire visible object, handles, fringes, holes, grain, colours, imperfections, viewpoint and object count. It forbids props, restyling and inventing occluded parts. |
| Keep my natural setting | Pillow applies a bounded channel-neutral exposure gain when needed. No OpenAI generation or background mask. |
| B2B catalogue frame | A 1200×1200 white canvas with at least 10% margins. By default it uses the OpenAI-cleaned image and trims the outer white area with a safety rim; switching off background cleanup fits the full original photo. The switch appears only when B2B is chosen. |

Every request starts from the original, never a previously enhanced image. Inputs are validated (JPEG/PNG/WebP, at most 12 MB and 24 megapixels), EXIF orientation is corrected, metadata is removed from the transmitted normalized image, and working images are limited to 1600px on the longest edge. The server processes previews in memory and returns JPEG bytes as base64. Flutter writes a separate preview file, retaining the input file. Saving uses the existing product-image upload and database flow.

OpenAI is generative: a prompt cannot guarantee identical pixels, craftsmanship or object boundaries. No measured accuracy claim or automatic fidelity guarantee is made. The UI requires a before/after confirmation for OpenAI outputs, offers the untouched local original, and resets approval after edits. B2B white-border trimming can miss extremely pale edges, so its preview also needs review. `prepared`, `catalog_plain_background`, `photo_provider` and `photo_reviewed` persist in existing listing JSON attributes; no schema migration is required. Publishing rejects an explicitly unreviewed OpenAI photo and still enforces review on saved legacy Gemini photos. Existing provider metadata is retained; new edits store `photo_provider=openai`. Natural/framing-only options need the backend but not an OpenAI key.

## Catalog suggestions

On the first **Review catalog details**, the original photo and the artisan's notes go to the catalog endpoint. Existing products can use **Suggest missing details from photo** to request another analysis. Corrections are not automatically re-analyzed when the artisan reopens the form.

Only title, Hindi title/description, description, category, colour, visible craft construction, obvious usage and explicitly stated material are eligible. Backend filtering accepts only high model-confidence suggestions with meaningful wording and supporting evidence; confidence labels are estimates, not calibrated accuracy scores. Material requires a verbatim supporting quote from the notes. Category must match the app's options. Unknown/placeholder/numeric-only text is dropped. Uncertain fields stay empty; up to three questions and the evidence are shown for review.

The model cannot prefill prices, costs, MOQ, stock, capacity, lead time, measurements, location, availability, customization, story or approval. Original notes are retained. Existing non-empty artisan fields take precedence over suggestions. If analysis fails, the manual form still opens. Suggestions never save, approve or publish a product themselves.

## API and code

- `POST /api/v1/studio/prepare`: multipart `file`, `mode` (`plainBackground`, `naturalSetting`, `b2bCatalog`), `catalog_plain_background`.
- `POST /api/v1/studio/catalog`: multipart `file`, optional `notes`, `language` (`en`/`hi`).
- Both endpoints use the existing `require_artisan` authentication dependency. They accept photo bytes, not arbitrary server-fetched URLs. Existing same-backend product-image URLs can be downloaded by the app; other hosts require selecting the photo again.
- `backend/app/services/studio_service.py`: refined prompts, OpenAI transport, validation, mode-specific processing and catalog filtering.
- `lib/core/services/studio_service.dart`: authenticated upload, preview-file storage and safe suggestion merging.
- `lib/features/commerce/presentation/product_studio_screen.dart`: comparison, image-review gate, catalog prefill and manual correction.

Automated checks cover synthetic image behavior, mocked OpenAI responses/errors, access control, catalog allowlists/evidence, photo-review persistence/publication, and Flutter review/prefill/failure paths. The full backend suite passes. No live OpenAI image-quality, quota, phone-network or latency verification is claimed; these require a configured key and real product photos.
