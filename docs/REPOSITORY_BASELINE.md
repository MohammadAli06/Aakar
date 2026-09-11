# Repository context

Inspected 2026-09-10. This is a source-code snapshot, not runtime verification. Product decisions live in [UPDATED_ARCHITECTURE.md](UPDATED_ARCHITECTURE.md); work order lives in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md).

## Identity and stack

Aakar, SIH 2026, PS 26090, Ministry of Social Justice and Empowerment, as identified in the existing README. Original planning name: CraftConnect. Dart package: `craft_connect`. Keep existing identifiers unless a rename is explicitly part of the work.

Flutter app with Riverpod 2, GoRouter 14, Firebase dependencies, Dio, image/camera packages, SharedPreferences/Hive, and Hindi/English localization. `pubspec.yaml` specifies Dart `>=3.0.0 <4.0.0`; the README's Flutter 3.44+ claim is not a verified installed SDK requirement. Backend: FastAPI, async SQLAlchemy/PostgreSQL, Firebase auth helpers, ASR/extraction/generation/pricing services. Compose declares PostgreSQL with pgvector, Redis, API, and Celery worker. Database is the intended shared business source of truth.

## Where to work

| Path | Actual responsibility |
|---|---|
| `lib/main.dart`, `lib/app.dart` | Flutter initialization/application |
| `lib/core/routing/app_router.dart` | Existing GoRouter routes; currently artisan flow |
| `lib/core/services/app_providers.dart` | Language persistence, auth state, artisan profile, onboarding state |
| `lib/core/services/mock_ai_service.dart` | Simulated enhancement/catalog/pricing/channel behavior |
| `lib/core/localization/app_strings.dart` | App translations; preserve Hindi and English |
| `lib/core/theme/` and `lib/shared/widgets/` | Existing design system and reusable UI |
| `lib/shared/models/models.dart` | Dart data models |
| `lib/features/` | Onboarding, auth, profile, dashboard, photo capture, cataloging, pricing, B2B screens |
| `backend/main.py` | API creation, lifespan table creation, router registration, `/health` |
| `backend/app/core/` | Settings, DB, Firebase auth |
| `backend/app/models/models.py` | Artisan, Product, images, listing, comparable, price, channel/readiness, verification log |
| `backend/app/routers/` | Auth, products, catalog, pricing, external-channel B2B endpoints |
| `backend/app/services/` | ASR, extraction, generation, pricing services |
| `backend/docker-compose.yml` | Infrastructure declarations, including an incomplete worker reference |
| `backend/.env.example` | Configuration template; do not copy secrets into documentation |
| `test/widget_test.dart` | Language persistence/navigation and bilingual-screen widget coverage |

## What exists versus what is planned

Existing screens cover splash, languages, onboarding, auth/OTP, profile, dashboard, photo capture/enhancement, voice catalog, listing preview, pricing, and B2B. Several screens call `MockAIService`; camera UI also contains a mock frame. Backend service implementations exist separately, but this does not demonstrate a working mobile-to-backend AI pipeline. Voice verification and multimodal understanding are target behavior; verify actual recording/playback/correction integration before claiming completion.

No Buyer Mode routes/profile, role toggle, requirements/RFQs/matching, shared quotes/negotiation/orders, fulfillment, payment milestones, or admin frontend were found in the inspected source tree. No app implementation was added during documentation setup or the `1.pdf` update. Optional samples, progress reviews, shipment timeline, inspection, manual issues, and saved-supplier/history/reorder are newly documented targets, not implemented capabilities. The original code snapshot has not been revalidated as a full runtime audit by this documentation update.

## Latest planning update: `1.pdf`

The user requested incorporating the later lifecycle refinement PDF. [Coverage and decisions](LIFECYCLE_UPDATE.md) maps all 12 source sections. Working baseline now includes optional sample approval before a bulk order, configurable multi-milestone payment commitments, one optional progress review, packaging evidence/shipping reference/tracking, buyer inspection, a manual admin issue queue, structured requested/offered negotiation fields, and simple reorder creating a new requirement. Manual issue handling and simple reorder supersede their earlier deferral; advanced disputes and bidding remain later. Keep shipment/inspection/checkpoint state separate from the four production updates. This new PDF does not provide confirmed logistics partners, hub tariffs, staffing, or real financial integrations.

Important mismatches to resolve:

- Pricing currently navigates directly to `/b2b`. Target: save to My Products first, publish separately.
- Current B2B screen/router concerns external channels. Internal marketplace publish readiness needs its own model/UI and validation.
- Backend `ProductStatus` values are `draft`, `ai_generated`, `verified`, `published`; target user-facing Draft / Ready to publish / Published / Needs update needs deliberate mapping and possibly migrations.
- `b2b.py` uses hardcoded channel templates, treats truthy fields as provided, marks readiness at 0.85, and permits simulated connection at 0.6. These are current code facts, not accepted readiness policy.
- `/b2b/connect` simulates submission but returns language suggesting a real submission and buyer contact within 3–5 business days. Replace with honest simulation wording during implementation.
- Channel readiness uses a foreign key to channels while demo channel definitions are hardcoded; verify seeding before exercising persistence.
- Product routes accept caller-supplied artisan identifiers without ownership dependencies in the inspected CRUD handlers. Shared buyer/admin workflows require explicit server-side authorization.
- Firebase helper falls back to mock claims without credentials. Restrict this to explicit demo/development mode before connecting real users/data.
- Pricing service advertises a hard cost floor but caps recommendations by market values after calculating it. A high-cost case can fall below the floor; regression coverage is needed when repairing pricing.
- Comparable data is hardcoded; model embeddings are JSON placeholders. Real pgvector matching is not implemented merely because the Docker image supports it.
- `backend/app/workers/` contains only `__init__.py`; Compose references missing `app.workers.celery_app`. Do not claim the full worker stack works.
- README suggests `alembic upgrade head`, but migration configuration/revisions were not found. Startup currently uses `Base.metadata.create_all`; this is not a migration strategy for changing existing tables.
- README stack/flow and demo claims describe earlier work and can overstate integration. Use the reconciled documents for target behavior and inspect code for implementation facts.

## Development and validation commands

Flutter compile fix (2026-09-11): removed invalid `const` contexts around gradient colours computed with `withOpacity()` in Dashboard, Pricing, and B2B. Preserved the existing colours/opacity values and formatted those files. All 15 existing widget tests pass. `flutter build apk --debug --no-pub` succeeds and produces `build/app/outputs/flutter-apk/app-debug.apk`. `flutter analyze --no-pub` still reports 138 findings, including existing style/deprecation diagnostics; lint cleanup is separate from the reported constant-expression build failure. The camera/device-info Kotlin plugin compatibility warning remains but did not block this build.

Backend startup troubleshooting (2026-09-11): six empty `app/**/__init__.py` files were UTF-16 and caused `SyntaxError: source code string cannot contain null bytes`; converted them to UTF-8. From inside `backend/`, import `main:app`, not `backend.main:app`. This session also had process `DEBUG=release`, which overrides `.env` and fails boolean validation; set `$env:DEBUG = 'false'` in the launch terminal. Import succeeds with that override. The configured database initially refused connections; PostgreSQL must be running before FastAPI lifespan can complete. These checks do not establish complete API integration.

From a PowerShell terminal in `backend/`:

```powershell
$env:DEBUG = 'false'
.\.venv\Scripts\python.exe -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

For the repository's local PostgreSQL setup, start Docker Desktop and run `docker compose up -d db` from `backend/`. Start Redis only when required. The missing Celery worker remains a separate limitation; avoid launching the entire Compose stack until it is addressed.

Run from repository root for Flutter:

```powershell
flutter --version
flutter pub get
flutter analyze
flutter test
flutter run
```

Format changed Dart files with `dart format <paths>`. Run targeted tests first; widen checks when cross-screen behavior changes. Test the complete role-switch flow on one phone/emulator when it exists. Do not add a buyer web build to the hackathon checks.

For backend setup, use an isolated environment, install `backend/requirements.txt`, and configure local settings using `backend/.env.example`. On this Windows workstation `py` resolves to Python; `python` resolves to the Microsoft Store alias.

```powershell
py -m venv backend/.venv
backend/.venv/Scripts/python.exe -m pip install -r backend/requirements.txt
```

From `backend/`, with the environment active and PostgreSQL/settings configured:

```powershell
uvicorn main:app --reload --port 8000
```

API docs: `http://localhost:8000/docs`; health: `/health`. Compose configuration may be inspected with `docker compose config` from `backend/`. Repair/omit the missing worker before claiming a successful full-stack startup. Establish migrations before schema evolution against retained data; do not run the README's migration command blindly.

No backend test suite was found. Add focused tests for readiness independence, ownership, pricing floor, quote acceptance, and payment/production transitions as those behaviors are implemented. Documentation-only work needs source coverage/link checks, not an app rebuild.

## Documentation maintenance

Keep original sources unchanged. Record new user decisions in the updated architecture and reflect actual implementation progress in the checklist. A planned API, mock screen, or status label is not proof of an integration. Preserve existing user edits; do not fix unrelated code during documentation requests.
