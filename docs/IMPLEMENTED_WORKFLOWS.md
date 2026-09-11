# Implemented mobile and admin workflows

Updated 2026-09-11. The architecture remains the product specification. This file records the implemented **hackathon demo**, its setup, verification, and remaining integration boundaries.

## Start the demo

From the repository root:

```powershell
flutter pub get
flutter run
```

Choose the explicit demo login. The dashboard now opens the commerce workspace. Switch Artisan / Buyer on the same device; language and business records persist. Profile offers seeded artisan selection and an explicitly confirmed local reset. Four sample product illustrations are included; camera/gallery can supply actual craft photos.

For shared mobile/admin records, install backend requirements into `backend/.venv`, then:

```powershell
cd backend
.\run_demo.ps1
```

The script sets a valid boolean DEBUG, starts `main:app` from the correct folder, uses `backend/demo.db` (SQLite), and prints separate randomly generated mobile/admin tokens. It does not need Docker or Redis for this workflow. Keep that terminal open. Existing environment tokens are retained when provided.

In mobile Profile → Connect backend workspace, enter the mobile token and base URL: `http://10.0.2.2:8000` for an Android emulator, or the computer's LAN address for a phone on the same network. Connecting loads the server workspace; it does not merge/upload the local workspace. Pull to refresh to retrieve changes from another device/admin. Failed writes remain failures; the app does not silently switch to local simulation.

Open `http://localhost:8000/api/v1/workspace/admin` on the computer and enter the **admin** token. The mobile token cannot perform admin actions. Admin verification, moderation, issue resolution, progress reviews and counts use the same database. Evidence photos require authenticated access.

## Architecture coverage

| Architecture sections | Implemented behavior | Boundary / remaining validation |
|---|---|---|
| 1–2, 16–18 | One mobile app, role-specific homes, persisted profiles, role toggle, verification evidence/contact-consent form, pending/verified/correction status, three discovery paths | Demo uses explicitly selected seeded identities. Real Firebase phone sign-in is wired but needs project/device verification. Separate production role membership is still needed. |
| 3–5 | Product studio camera/gallery, original retained, before/after review, gentle exposure adjustment, replace photo | Enhancement is deterministic image processing; no fabricated generative/vision enhancement claim. Real camera permissions need device testing. |
| 6–9 | Speech-to-text on form fields, original transcript, optional AI catalog draft, English/Hindi fields, editable missing details, read-aloud and explicit approval | Device speech/TTS and configured AI need live validation. Follow-ups are editable missing-field review, not a calibrated confidence model. |
| 10–14 | Labour hours/rate, material and overhead, cost floor, handmade demo comparables, final price, save unpublished, edit/reapprove/publish, readiness gaps, stock/capacity/lead time, committed-capacity check | Comparables are fixtures. Internal readiness and external eligibility stay independent. No live production-capacity/calendar integration. |
| 19–22 | Typed/spoken requirement draft and confirmation, reference photo, quantity/budget/deadline/location/customization, ranked reasons/gaps, product/artisan details, comparison up to three | Deterministic explainable matching works without AI; there is no vector-search or external marketplace ingestion. |
| 23–29 | Shared RFQ, original/translated messages and attachments, reviewed AI-assisted quote drafting from conversation, requested/offered terms, full/partial/declined capacity, quote revisions/reject/accept, stale/duplicate and sample guards, one accepted order | AI cannot send or accept terms. Translation unavailable is explicitly labeled; users can supply reviewed wording. Negotiation is a lightweight structured workflow. |
| 30–32 | Four production updates, separate shipment/inspection/payment status, order details/history, saved suppliers, supplier-specific order history, editable fresh reorder requirement | Reorder does not copy old acceptance, capacity or payments. No ERP. |
| 33–40 | Future-scope information only | Auctions, bidding, advanced analytics and artisan business insights remain deferred by the agreed plan. |
| 41 | Independent GeM/ONDC/state-board preparation forms | Guidance/demo preparation only; no submission, eligibility guarantee or buyer guarantee. |
| 42 | Separate HTML admin dashboard, verification/correction/rejection, moderation, counts, manual issue notes/outcome, progress review, evidence viewer | Basic demo admin only; no advanced adjudication, refunds or production account administration. |
| 43 | Direct/hub/needs-review recommendation with reasons, packaging checks/evidence, carrier/reference/tracking, hub availability/handoff fields, optional representation proposal and confirmation | Routing records coordinate people; they do not book carriers, reserve storage or hire representatives. |
| 44 | Configurable advance/checkpoint/dispatch/inspection milestones and totals; advance gates production | Manual simulated payment confirmation only. No money, escrow or automated release. |
| 45 | Optional requested/submitted/approved/changes-requested/rejected sample, evidence and terms; changed specifications require reapproval | Sample terms/evidence are recorded; no separate paid sample checkout or shipment provider. |
| 46 | Optional quantity/photo progress checkpoint and buyer/admin review | Review is separate from payment confirmation; no AI quality guarantee. |
| 47 | Participant issue category, description/evidence, shared admin queue, investigation notes/outcome, blocking unresolved issue | Manual review only; local-only demo cannot resolve admin issues without a shared server workflow. |
| 48–49 | Dispatch, in-transit, received quantity, configurable inspection window, explicit acceptance, settlement/open-issue completion guards | No automatic acceptance after the inspection deadline and no real carrier status feed. |
| 50 | Integrated catalog → sourcing → agreement → production → fulfillment → inspection/completion flow | Six-problem framing is preserved in the architecture and source documents. |

## Code map

- `lib/features/commerce/domain/commerce_engine.dart`: pure workflow transitions, readiness, matching and route explanations.
- `lib/features/commerce/data/commerce_repository.dart`: persistent local demo or authenticated shared demo API, version conflicts, media uploads and reviewed assistant drafts.
- `lib/features/commerce/presentation/`: cream/forest-green mobile screens, shared form/card/image components and product studio.
- `backend/app/services/workflow_service.py`: server-side workflow validation; keep transition rules aligned with the Dart engine and tests.
- `backend/app/routers/workspace.py`: versioned SQLAlchemy JSON workspace, demo access, separate admin capability, media and assistant endpoints.
- `backend/app/services/workflow_assistant.py`: configured OpenAI-compatible LLM requests with field allowlists and explicit fallback provenance. Configure `LLM_API_KEY`, `LLM_API_BASE` and a model supported by your account through `LLM_MODEL`; credentials are not supplied by this implementation.
- `backend/admin/index.html`: minimal shared admin UI, escaped record rendering and protected image viewing.

## Checks and practical limits

Validation recorded 2026-09-11: 54 Flutter tests passed, 8 backend tests passed, admin JavaScript syntax passed, and documentation links resolved. `flutter analyze --no-pub` reports 0 errors, 9 warnings and 172 informational findings (181 total); it exits nonzero because lint findings remain. Final Android artifact: `build/app/outputs/flutter-apk/app-debug.apk`.

Flutter engine, persistence and phone-layout tests cover role continuity, independent readiness, ownership, matching gaps, price floor, quote versions, optional samples, advance/production/checkpoint/dispatch/inspection/settlement, blocking issues and fresh reorders. English/Hindi layouts include inquiry, order and product studio. Backend unit and real HTTP/SQLite tests cover transitions, access tokens, separate admin permissions, revision conflicts, uploads and assistant fallback.

Android debug APK builds with the installed SDK. The Kotlin plugin compatibility notice remains a warning. Analyzer style/deprecation findings remain in the repository; do not describe analysis as clean. No emulator/phone was connected during implementation, so actual speech, camera, Firebase OTP, LAN connectivity and iOS builds still need device validation.

The shared API is deliberately an opt-in **single demo workspace**, disabled in production. Its mobile token authorizes switching seeded demo identities and reading the shared demonstration data. It is not production multi-tenant authorization. Local preferences/media use demo storage; production needs protected user-specific storage, token handling, tenant-scoped APIs, schema migrations and service integration review. Legacy CRUD/AI screens and endpoints remain in the repository but are not the active new commerce flow and should not be exposed as a production service without an authorization audit.

Main startup creates missing tables; no Alembic revision history is supplied. PostgreSQL remains supported by the configured backend, but this run tested SQLite. Celery's missing entrypoint is repaired; this does not mean background AI tasks or the whole Docker stack were tested.
