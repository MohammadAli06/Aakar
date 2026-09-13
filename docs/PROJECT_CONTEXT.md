# Repository context

Latest correction: registered phone numbers keep their existing artisan/buyer role; only new accounts see role selection. Role switching has been removed from account home and is rejected by the backend. Profile setup now has a back button to phone entry; profile editing returns home.

Account lookup uses the verified Firebase UID to SELECT the user and stored role profile. It never rewrites roles or guesses from profile rows. The temporary role-reconciliation proposal was reverted; the developer cleared the inconsistent account data. No live database repair is part of the current fix.

**Current entry flow, 2026-09-13:** Read [Account onboarding](ACCOUNT_ONBOARDING.md). `/dashboard` renders the main commerce home and `/workspace/*` routes are reachable after completing signup. Profile → Help & scope labels sample products/orders as demo data separate from the verified account; the top banner and account button are removed. `/account` retains real account details; verification refresh also reloads the account badge. Shared phone OTP, backend profiles and private verification remain real services. Legacy API screens remain blocked. PostgreSQL/live OTP validation, tenant-scoped commerce production integration and pgvector remain pending.

Updated 2026-09-11. Read [Updated architecture](UPDATED_ARCHITECTURE.md) for scope and [Implemented workflows](IMPLEMENTED_WORKFLOWS.md) for the current feature map, setup and limitations. [Original implementation baseline](REPOSITORY_BASELINE.md) preserves the earlier inspection; its missing-feature statements are historical.

## Current application

**Product Studio update, 2026-09-14:** active photo preparation now uses authenticated `/api/v1/studio/prepare`: OpenAI for plain-white background editing, deterministic exposure for natural setting, and a 1200×1200 B2B frame with optional OpenAI cleanup. `/api/v1/studio/catalog` analyzes the original photo and notes for reviewable, evidence-backed catalog suggestions, never commercial or approval fields. The image-review checkbox, original/undo behavior and catalog correction step remain explicit. Photo mode/provider/review metadata persists in listing JSON; publishing requires review of OpenAI output. See [OpenAI Product Studio](OPENAI_PRODUCT_STUDIO.md) for backend `.env` settings, API boundaries and validation. Live OpenAI quality has not been validated. The 2026-09-13 deterministic photo implementation described below is historical and superseded for the active screen.

Artisan product details now include an owner-only Available Now / Not Taking Orders switch near the title. The dedicated `availability` workflow action accepts only a boolean and enforces artisan ownership in Dart and Python; it changes neither catalog approval nor publication status. Buyers see the status on catalog cards/details, and unavailable products reject new inquiries in both workflow engines. Existing conversations, quotes and orders continue under their existing rules. Stock, MOQ, monthly capacity and lead time remain editable through Edit & re-verify → Correct details / voice edit. No separate capacity screen was added. Workspace role synchronization now waits for saved state to load, preventing initial demo data from overwriting persisted buyer records. These remain demo-workspace features, not tenant-scoped production commerce.

The Product Studio B2B background switch is visible only while B2B catalogue frame is selected; choosing another preparation or restoring the original hides it.

Product Studio photo preparation (2026-09-13) uses deterministic on-device operations. Plain background builds an immutable-source Lab mask with border seeds every 18px, protects the middle 70% of each dimension, removes enclosed retained components under 2% only when detached from the protected region, and feathers three pixels outward without changing retained pixels. Natural setting remains exposure-only and never calls masking. B2B now fits mask-retained bounds onto a 1200×1200 white canvas with 10% minimum margins instead of cropping the centre square. Its background switch can fit the entire untouched natural photo instead; the applied choice is stored as `catalog_plain_background`. Before/after previews show the whole image. Originals remain separate and EXIF orientation is baked before file processing.

The protected rectangle is a conservative heuristic, not a subject detector: background inside it remains, and similarly coloured product parts outside it or small detached pieces can still be removed. Compare the result with the original. No generative processing or ML segmentation has been added. Synthetic tests cover textured borders, centre protection, islands, feathering, distinct modes and wide-product framing; real wood-grain photos and device performance still need validation.

Review Catalog no longer shows the four trailing availability/customization/fragility/packaging toggles. Existing draft values are preserved; readiness checks still apply and missing capabilities are not automatically confirmed.

Aakar is one Flutter mobile app, Riverpod state management and GoRouter navigation. `/dashboard` now opens the commerce workspace. `/workspace/create` opens Product Studio; other workspace routes cover both roles, discovery, RFQs, quotations, orders, profiles, notifications and external preparation. Legacy artisan screens remain but are not the active dashboard flow.

The shared commerce engine is pure Dart with a Python server counterpart. Local demonstration records persist in SharedPreferences; shared demonstration records use a versioned SQLAlchemy JSON workspace and authenticated photo uploads. Buyer/artisan role switching sees the same records.

The admin side has two clients on the same FastAPI database. `admin-web/` is the React console used for real account review — dashboard, verification queue and decision, account directory and access control, product moderation state, counts, analytics snapshot and an administrator audit trail — backed by `backend/app/routers/admin.py` plus the existing verification-review endpoints, all gated by the separate `ADMIN_ACCESS_TOKEN`. `backend/admin/index.html` is the earlier plain-HTML page for the opt-in shared demo workspace records (issues, progress reviews, orders).

The UI follows the supplied reference: warm cream, deep forest green, muted accent cards, rounded containers, discovery shortcuts and order timelines. Demo artwork is original vector-style craft illustration; actual photos come from camera/gallery. English/Hindi forms and speech/TTS adapters are implemented. Voice and camera need testing on a real device.

## Runtime and configuration

Validated here with Flutter 3.47.2 / Dart 3.13.2 and backend Python 3.14.4. Backend dependencies are in `backend/requirements.txt`; install into an isolated `.venv`. A fresh developer should use the resolved lockfile rather than infer versions from the historic README.

From root: `flutter pub get`, `flutter test`, `flutter analyze`, `flutter run` or `flutter build apk --debug --no-pub`. From backend: `.\run_demo.ps1` starts the explicitly enabled SQLite demo and prints mobile/admin tokens. From `admin-web/`: `npm run dev` serves the admin console on `http://localhost:5173` and proxies `/api` to the backend. See [complete connection instructions](IMPLEMENTED_WORKFLOWS.md#start-the-demo). API docs are `/docs`; the legacy demo workspace admin page is `/api/v1/workspace/admin`.

For normal PostgreSQL development set DATABASE_URL and run `python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000` **inside backend/**. Set `$env:DEBUG = 'false'` if the shell has an invalid DEBUG value. `backend.main:app` is the wrong import from that directory. Six UTF-16 package initializers were repaired to UTF-8. Startup creates missing tables — which covers the admin console's `product_moderation` and `admin_audit_log` tables — but changing existing columns still needs a reviewed migration.

Do not use a real Firebase token as the shared demo token. Firebase phone authentication and the explicit seeded workspace are separate boundaries. Live phone sign-in needs valid Firebase configuration; AI drafting needs configured LLM credentials/model. Without AI, basic extraction/manual review remains usable and translation is labeled unavailable.

## Validation and remaining boundaries

Tests now live in `test/commerce_engine_test.dart`, `test/commerce_repository_test.dart`, `test/commerce_screens_test.dart`, existing `test/widget_test.dart`, and `backend/tests/`. Run backend checks with `$env:DEBUG='false'; .venv/Scripts/python.exe -m unittest discover -s tests -v` from backend. They use isolated temporary SQLite databases and never call a live LLM.

The Android debug build succeeds; current KGP compatibility warnings do not block it. Analyzer findings include existing unused imports, deprecations and style notices; there are no known compile errors. No device was connected, so live camera/voice/OTP and iOS validation remain pending. See the implementation checklist for external-service and acceptance work, not the historical baseline.

Payments, logistics and external-channel preparation are explicit simulations/manual records. No escrow, booking or marketplace submission is implemented. The opt-in shared API is a single seeded demo workspace, disabled in production; production user/tenant isolation and migrations are separate work. Original CRUD routes require a security/integration audit before deployment. A Celery entrypoint exists but no full worker stack validation is claimed.

## Maintenance

Keep source PDFs/text untouched. Keep Dart/Python transition rules consistent, preserve unrelated user edits and update coverage/checklists based on tested behavior. New production services must replace explicit boundaries, not silently relabel simulation as live integration.
