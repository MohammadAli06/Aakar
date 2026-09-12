# Aakar

SIH 2026, PS 26090: AI-assisted cataloging and market linkage for artisans. One Flutter mobile app serves Artisan and Buyer modes; a separate React admin console (`admin-web/`) uses the shared FastAPI backend.

[Architecture](docs/UPDATED_ARCHITECTURE.md) | [Implemented workflows](docs/IMPLEMENTED_WORKFLOWS.md) | [Checklist](docs/IMPLEMENTATION_PLAN.md) | [Coding instructions](AGENTS.md) | [Source documents](docs/sources/README.md)

## Run the mobile demo

```powershell
flutter pub get
flutter run
```

Select the explicit demo login. Use the role toggle after login to show both modes on one phone/emulator. The app saves on-device records between launches. Product Studio ends with **Save to My Products**; publication is a separate action after readiness and artisan approval.

The cream/forest-green interface includes buyer discovery, requirements and explainable matches, supplier comparison, RFQs, chat, structured quote revisions, sample approval, payment milestones, production/checkpoint updates, packaging and shipment records, inspection, issue reporting, saved suppliers and fresh reorders.

## Run the shared backend and admin

Create an environment and install requirements once:

```powershell
py -m venv backend/.venv
backend/.venv/Scripts/python.exe -m pip install -r backend/requirements.txt
```

Then:

```powershell
cd backend
.\run_demo.ps1
```

This starts a persistent SQLite demo without Docker and prints separate mobile/admin tokens. In mobile **Profile > Connect backend workspace**, use the mobile token with `http://10.0.2.2:8000` for an Android emulator or your computer's LAN address for a physical phone. Connecting opens the server's records instead of merging local records. Pull to refresh for admin/other-device changes.

Then run the admin console:

```powershell
cd ../admin-web
npm install
npm run dev
```

Open [http://localhost:5173](http://localhost:5173) and sign in with the **admin token**. It covers the account verification queue and review (with private evidence), the account directory and access control, product moderation, counts, an analytics snapshot and the audit trail. Order issues and progress reviews read the shared demo workspace, so they need `ENABLE_DEMO_WORKSPACE=true` (which `run_demo.ps1` sets).

The earlier plain-HTML page at [http://localhost:8000/api/v1/workspace/admin](http://localhost:8000/api/v1/workspace/admin) still works for the demo workspace records. [API docs](http://localhost:8000/docs) describe every endpoint. The admin token is separate from the token entered on the phone and cannot be used by the mobile app.

For PostgreSQL development, configure `backend/.env` from `.env.example` and start the database. From **inside backend/** run:

```powershell
$env:DEBUG = 'false'
.\.venv\Scripts\python.exe -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Use `main:app` from this folder. Startup creates missing tables; no Alembic migrations are supplied. Compose defines PostgreSQL, Redis, API and Celery, but the complete Docker stack is not part of the validated SQLite demo.

## Technical stack

| Layer | Implementation |
|---|---|
| Mobile | Flutter / Dart, Riverpod, GoRouter; Android demo target, iOS source retained |
| Interface | Shared cream/forest-green components, Poppins, Hindi/English forms |
| Voice and images | speech_to_text, flutter_tts, camera/gallery, original-preserving image adjustment |
| State | SharedPreferences local demo; shared backend repository with version conflict handling |
| Backend | FastAPI, Pydantic, async SQLAlchemy; PostgreSQL configuration and SQLite demo runner |
| Assistant | Configured OpenAI-compatible LLM for reviewable catalog/requirement/translation/quote drafts; labeled basic/manual fallback |
| Identity | Firebase Phone Auth adapter; separate explicitly enabled seeded demo workspace |
| Admin | React 19 + Vite console for account review, moderation, counts and audit trail; legacy plain-HTML page for the demo workspace; common FastAPI database, separate admin access token |
| Media | Authenticated demo photo uploads, validation and EXIF stripping |

The solution connects artisan-approved catalog creation and labour-aware pricing to buyer sourcing, explicit agreement, production, physical fulfillment coordination and buyer acceptance. Business state persists across role changes, and the workflow enforces sample, capacity, cost-floor, milestone and completion guards.

## Configuration and honest demo boundaries

Demo payments are status records: no money is held or transferred. Logistics records do not book carriers/hubs, and external marketplace preparation does not submit to GeM/ONDC/state boards. Sample products/comparables are fixtures with clearly identified illustrations. Auctions and advanced admin remain deferred per the architecture.

Set `LLM_API_KEY`, `LLM_API_BASE` and a supported `LLM_MODEL` in backend configuration for live assistant drafts. For real phone sign-in configure the Firebase project, platform service files and phone authentication. No credentials are included. Voice/TTS depend on device availability and permissions; text entry remains available.

The shared demo endpoint is disabled in production and grants one token access to the seeded demonstration identities. It is not a production multi-tenant application. Production authorization, storage, migrations and provider integration still need work. See [the full coverage and limitations](docs/IMPLEMENTED_WORKFLOWS.md).

## Validation

```powershell
flutter test --no-pub
flutter analyze --no-pub
flutter build apk --debug --no-pub
```

From backend (16 tests, including the admin API):

```powershell
$env:DEBUG = 'false'
.venv/Scripts/python.exe -m unittest discover -s tests -v
```

From `admin-web`:

```powershell
npm run lint
npm run build
```

The Android APK builds. Existing analyzer style/deprecation findings and Kotlin plugin compatibility warnings remain. Device camera/voice/Firebase OTP and iOS compilation require separate device validation. Automated tests cover workflow transitions, persistence, English/Hindi phone layouts, backend access, version conflicts, media and fallback behavior. The admin web lint and build are clean, but the rendered console has not been reviewed in a real browser in this environment.
