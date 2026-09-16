# Switching Product Studio AI providers

Change `backend/.env`, then **restart the backend process**. Flutter does not hold provider credentials and does not need rebuilding for subsequent profile changes. Install the updated Flutter build once for PNG previews and Cloudinary photo review.

## Cloudinary + OpenRouter

```env
AI_PROVIDER_PROFILE=cloudinary_openrouter
CLOUDINARY_URL=cloudinary://<api_key>:<api_secret>@u59wk44t
OPENROUTER_API_KEY=<your_openrouter_key>
OPENROUTER_VISION_MODEL=google/gemma-4-26b-a4b-it:free
AI_TIMEOUT_SECONDS=180
# OPENAI_API_KEY=...
```

Use your actual Cloudinary credentials, with URL encoding for reserved characters in the key/secret. The cloud name comes from `CLOUDINARY_URL`; it is not hardcoded in the application.

| Task | `cloudinary_openrouter` | `openai` |
|---|---|---|
| Plain-background removal / optional B2B cleanup | Cloudinary `e_background_removal` | `OPENAI_IMAGE_MODEL` |
| Photo catalog suggestions | `OPENROUTER_VISION_MODEL` | `OPENAI_VISION_MODEL` |
| Pricing complexity assessment | `OPENROUTER_VISION_MODEL` | `OPENAI_VISION_MODEL` |
| Translation back-translation and drift judge | `OPENROUTER_VISION_MODEL` | `OPENAI_TRANSLATION_MODEL` |

There is **no cross-provider fallback** for these four tasks. Cloudinary/OpenRouter errors cannot trigger OpenAI charges, even if its key remains configured. Catalog failure offers manual entry; pricing and translation failures remain explicitly unavailable. Natural exposure correction and B2B framing without cleanup stay deterministic.

Groq extraction, generation and negotiation keep their existing `LLM_*` and task-specific settings and existing fallback behavior. Commenting out `OPENAI_API_KEY` also disables those existing services' OpenAI fallback; it does not change their Groq models. Older `TRANSLATION_QA_*` settings no longer select the judge: the profile above does. Unused `_OR` presets in a shared `.env` are tolerated but are not provider switches.

## Third option: Cloudinary + direct Gemini

```env
AI_PROVIDER_PROFILE=cloudinary_gemini
CLOUDINARY_URL=cloudinary://<api_key>:<api_secret>@u59wk44t
GEMINI_API_KEY=<your_google_ai_studio_key>
GEMINI_MODEL=gemini-3.8-flash
```

Keep a single active entry per setting and restart the backend. This profile uses Cloudinary removal and **Google directly** for catalog extraction, pricing complexity and both translation-check calls. OpenRouter and OpenAI keys are not used by these four tasks. Groq services retain their existing behavior. The other two profile options remain available.

The backend calls Google's native `https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent` endpoint with the key in `x-goog-api-key`. It converts normalized photo bytes into base64 `inlineData` with the actual `image/jpeg` MIME type, supplies system instructions separately, requests JSON for catalog/pricing, and parses completed native response parts. Thinking text is excluded. [Google native API documentation](https://ai.google.dev/api/generate-content).

Google project/model access, billing and quota apply. There is no promise of unlimited/free access or automatic fallback if Google rejects a request. The profile is covered by mocked tests. A live synthetic image request succeeded on the native endpoint while the compatibility endpoint returned 503 with the same key/model; provider availability can still vary. Existing installations can select this profile without a Flutter rebuild.

## Switch back to OpenAI

```env
AI_PROVIDER_PROFILE=openai
OPENAI_API_KEY=<your_openai_key>
OPENAI_IMAGE_MODEL=gpt-image-2.5-sunburst
OPENAI_VISION_MODEL=gpt-4.1-mini
OPENAI_TRANSLATION_MODEL=gpt-4.1-mini
OPENAI_TIMEOUT_SECONDS=180
AI_TIMEOUT_SECONDS=180
```

Restart the backend. You can leave the unused provider's credentials commented out. The source default remains `openai` so an existing installation is not silently switched to an unconfigured provider. No new SDK dependency is required.

## Image behavior and boundaries

The device original remains unchanged. The backend validates and normalizes a copy, uploads it with a server-generated signature to `aakar/studio/<random-id>` in Cloudinary, and requests a signed derived PNG using `e_background_removal`. It polls temporary HTTP 423 responses within a bounded timeout. The uploaded Cloudinary source is retained; no automatic deletion/retention policy is implemented. These are product photos, not private verification evidence. See [Cloudinary background removal](https://cloudinary.com/documentation/background_removal) and [request signatures](https://cloudinary.com/documentation/signatures).

Plain-background preparation returns a transparent PNG preview. B2B frames and saved catalog uploads retain the existing white JPEG format; transparency is composited on white rather than turning black. Every AI/Cloudinary result still requires comparison with the original before publishing. Extraction always reads the original photo.

OpenRouter uses chat completions with image data and JSON-object output. The requested [Gemma endpoint](https://openrouter.ai/google/gemma-4-26b-a4b-it:free) supports image input and JSON output without schema enforcement, so the backend applies its own field/evidence validation. Its free endpoint is rate limited; Cloudinary transformations have separate usage charges. See [OpenRouter image inputs](https://openrouter.ai/docs/guides/overview/multimodal/image-understanding).

## Gemini temporary unavailability

Gemini HTTP 503 responses receive at most two retries against the same model, with exponential delay and jitter, within `AI_TIMEOUT_SECONDS` total. Numeric `Retry-After` hints up to 10 seconds are respected; longer or unparseable hints stop automatic retries. Persistent 503s remain HTTP 503 through `/studio/catalog` and show a temporary-service-unavailability message instead of a generic 502. Quota/auth failures are not automatically retried or sent to another provider. Gemini temperature is left at the provider default. See [Google troubleshooting](https://ai.google.dev/gemini-api/docs/troubleshooting).

## Validation

### Rate-limit troubleshooting

A 429 can come from OpenRouter's platform limits or the selected model's upstream provider. The app distinguishes upstream capacity/rate limits, recognized daily-limit errors, and generic rate limits, and displays numeric `Retry-After` hints when supplied. A 402 is reported separately as a credit/key-cap issue. These rate-limit errors are not automatically retried and never trigger paid fallback. Read-only `GET https://openrouter.ai/api/v1/key` reports `free_model_daily_requests`; do not conclude that a generic 429 means that counter is exhausted. See [OpenRouter limits](https://openrouter.ai/docs/api-reference/limits).

Live diagnostic on 2026-09-16: the configured key reported 0 of 50 daily free requests used, but the selected Gemma endpoint returned HTTP 429 with Google AI Studio as the upstream provider. No Retry-After hint was supplied. This records a transient provider-side failure, not a successful live extraction.

Automated coverage includes both profiles, provider isolation with both keys present, missing credentials, incomplete responses, upload/derived-image requests, Cloudinary processing retries, PNG alpha preservation, white JPEG storage, catalog filtering, translation checks and pricing model provenance. New-provider tests use mocked HTTP and synthetic images. Live Cloudinary/OpenRouter account access and actual craft-photo quality still need validation with configured credentials.

Code: `backend/app/core/config.py`, `backend/app/services/ai_provider.py`, `backend/app/services/cloudinary_service.py`, and the existing Studio/translation/pricing services.

## Photo request diagnostics

Flutter uploads the original image as multipart `file` to `/studio/catalog`, together with notes and language. FastAPI validates and normalizes the photo before calling Gemini; Flutter never handles provider credentials. Upstream 400/401/403/404 now have distinct messages including the upstream HTTP status. Server logs include provider, task and HTTP status without logging headers, images, artisan notes or raw provider bodies.

Keep only one active `GEMINI_API_KEY` and `GEMINI_MODEL` assignment in `backend/.env`: a later blank duplicate overrides an earlier populated value. Restart the backend after environment changes. The native transport change needs a backend restart only.

Validation limit: the simple live native image call succeeded, but subsequent complete catalog requests still received Google HTTP 503 after bounded retries, including with low thinking effort. End-to-end live catalog success is not yet verified. All 50 backend tests and 20 Flutter Studio tests passed; Flutter analysis reported 157 existing warnings/info and no errors.
