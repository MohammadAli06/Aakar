# Repository context

Updated 2026-09-11. Read [Updated architecture](UPDATED_ARCHITECTURE.md) for scope and [Implemented workflows](IMPLEMENTED_WORKFLOWS.md) for the current feature map, setup and limitations. [Original implementation baseline](REPOSITORY_BASELINE.md) preserves the earlier inspection; its missing-feature statements are historical.

## Current application

Aakar / CraftConnect is one Flutter mobile app, Riverpod state management and GoRouter navigation. `/dashboard` now opens the commerce workspace. `/workspace/create` opens Product Studio; other workspace routes cover both roles, discovery, RFQs, quotations, orders, profiles, notifications and external preparation. Legacy artisan screens remain but are not the active dashboard flow.

The shared commerce engine is pure Dart with a Python server counterpart. Local demonstration records persist in SharedPreferences; shared demonstration records use a versioned SQLAlchemy JSON workspace and authenticated photo uploads. Buyer/artisan role switching sees the same records. The separate plain HTML admin dashboard uses the same FastAPI database and a separate admin token.

The UI follows the supplied reference: warm cream, deep forest green, muted accent cards, rounded containers, discovery shortcuts and order timelines. Demo artwork is original vector-style craft illustration; actual photos come from camera/gallery. English/Hindi forms and speech/TTS adapters are implemented. Voice and camera need testing on a real device.

## Runtime and configuration

Validated here with Flutter 3.47.2 / Dart 3.13.2 and backend Python 3.14.4. Backend dependencies are in `backend/requirements.txt`; install into an isolated `.venv`. A fresh developer should use the resolved lockfile rather than infer versions from the historic README.

From root: `flutter pub get`, `flutter test`, `flutter analyze`, `flutter run` or `flutter build apk --debug --no-pub`. From backend: `.\run_demo.ps1` starts the explicitly enabled SQLite demo and prints mobile/admin tokens. See [complete connection instructions](IMPLEMENTED_WORKFLOWS.md#start-the-demo). API docs are `/docs`; admin is `/api/v1/workspace/admin`.

For normal PostgreSQL development set DATABASE_URL and run `python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000` **inside backend/**. Set `$env:DEBUG = 'false'` if the shell has an invalid DEBUG value. `backend.main:app` is the wrong import from that directory. Six UTF-16 package initializers were repaired to UTF-8. Startup creates missing tables; schema evolution still needs migrations.

Do not use a real Firebase token as the shared demo token. Firebase phone authentication and the explicit seeded workspace are separate boundaries. Live phone sign-in needs valid Firebase configuration; AI drafting needs configured LLM credentials/model. Without AI, basic extraction/manual review remains usable and translation is labeled unavailable.

## Validation and remaining boundaries

Tests now live in `test/commerce_engine_test.dart`, `test/commerce_repository_test.dart`, `test/commerce_screens_test.dart`, existing `test/widget_test.dart`, and `backend/tests/`. Run backend checks with `$env:DEBUG='false'; .venv/Scripts/python.exe -m unittest discover -s tests -v` from backend. They use isolated temporary SQLite databases and never call a live LLM.

The Android debug build succeeds; current KGP compatibility warnings do not block it. Analyzer findings include existing unused imports, deprecations and style notices; there are no known compile errors. No device was connected, so live camera/voice/OTP and iOS validation remain pending. See the implementation checklist for external-service and acceptance work, not the historical baseline.

Payments, logistics and external-channel preparation are explicit simulations/manual records. No escrow, booking or marketplace submission is implemented. The opt-in shared API is a single seeded demo workspace, disabled in production; production user/tenant isolation and migrations are separate work. Original CRUD routes require a security/integration audit before deployment. A Celery entrypoint exists but no full worker stack validation is claimed.

## Maintenance

Keep source PDFs/text untouched. Keep Dart/Python transition rules consistent, preserve unrelated user edits and update coverage/checklists based on tested behavior. New production services must replace explicit boundaries, not silently relabel simulation as live integration.
