# Implemented mobile and admin workflows

**2026-09-13 update:** Firebase sign-in and verification now lead to the main commerce home at `/dashboard`, with working `/workspace/*` navigation. Profile → Help & scope identifies sample products/orders as demo data separate from the verified account; the top banner and account button were removed at user request. Real profile and verification remain at `/account`, `/profile/edit` and `/verification`. Verification refresh also reloads the account badge. Artisan products and buyer requirements are now saved to the signed-in account in the shared backend database (see *Product catalogue* and *Buyer requirements* below); inquiries, quotes, orders, payments and shipping are still demo data. Legacy API screens remain blocked. See [Account onboarding](ACCOUNT_ONBOARDING.md).

Camera capture now runs **inside the app** (`lib/features/capture/`) instead of handing off to the device camera app. The previous `image_picker` camera intent could destroy the Flutter activity while the external camera was in front, so returning restarted the app and lost the photo. Product capture is a full-screen in-app preview; the selfie uses a circular guide with `google_mlkit_face_detection` that turns the ring green once one face is centred and correctly sized, then auto-captures after a short hold. Gallery selection still uses `image_picker`. This is not yet device-validated.

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

## Admin console (admin-web)

The production-facing reviewer console is the React app in `admin-web/`. It replaces the earlier single-page HTML dashboard for the real account-review work; `backend/admin/index.html` remains as the legacy demo-workspace page.

Run it from `admin-web/` with `npm install` then `npm run dev` (default `http://localhost:5173`), and sign in with the `ADMIN_ACCESS_TOKEN` value. In development Vite proxies `/api` to `BACKEND_URL` (default `http://localhost:8000`), so no browser CORS setup is needed. `VITE_API_BASE_URL` overrides the API prefix for a built asset.

Implemented against the shared database:

| Screen | Endpoint | Notes |
|---|---|---|
| Dashboard | `GET /api/v1/admin/overview`, `/admin/activity` | Counts, verification pipeline, role split, attention list |
| Verification queue | `GET /api/v1/auth/verification-admin` joined with `/admin/accounts` | Names come from the account directory; the record supplies evidence and status |
| Verification review | `GET /api/v1/auth/verification-admin/{id}/evidence/{kind}`, `PUT /api/v1/auth/verification-admin/{id}` | Approve, request correction or reject with a mandatory note; evidence is fetched per request and never cached |
| Accounts | `GET /api/v1/admin/accounts`, `GET /api/v1/admin/accounts/{id}`, `PUT /api/v1/admin/accounts/{id}/status` | Directory plus enable/disable access control |
| Products | `GET /api/v1/admin/products`, `GET /api/v1/admin/products/{id}`, `PUT /api/v1/admin/products/{id}/moderation` | Listing, cost-floor pricing, persisted moderation decision; rows are written by the mobile catalogue endpoints below |
| Requirements | `GET /api/v1/admin/requirements` | Buyer demand posted from the marketplace, with buyer, quantity, budget, lead time and destination. Read-only: a requirement is not an order, so no decision is recorded |
| Order issues | `GET`/`POST /api/v1/workspace` (admin token) | Manual review only; disabled unless `ENABLE_DEMO_WORKSPACE=true` |
| Analytics | `GET /api/v1/admin/overview` | Current-state snapshot; no time-series history is stored |
| Audit trail | `GET /api/v1/admin/activity` | `admin_audit_log` plus verification submissions |
| Platform | `GET /api/v1/admin/platform` | Read-only, non-secret backend facts |

Two tables back the new endpoints, created by the existing startup `create_all` so no migration is required for them: `product_moderation` (current decision per product) and `admin_audit_log` (who decided what). Verification review decisions now write an audit entry as well.

Boundaries kept explicit in the interface: moderation never publishes or unpublishes a listing (the artisan publishes); approving verification is invalidated by a later profile edit; the console moves no money, books no carrier and makes no external marketplace submission; and B2B monitoring, bidding/auctions, integrations and support are presented as a scope statement rather than mock screens. Legacy `verification` and `moderation` demo-workspace actions remain available to the HTML page but are no longer the primary admin path.

## Architecture coverage

| Architecture sections | Implemented behavior | Boundary / remaining validation |
|---|---|---|
| 1–2, 16–18 | One mobile app, role-specific homes, persisted profiles, role toggle, verification evidence/contact-consent form, pending/verified/correction status, three discovery paths | Demo uses explicitly selected seeded identities. Real Firebase phone sign-in is wired but needs project/device verification. Separate production role membership is still needed. |
| 3–5 | Product studio camera/gallery, original retained, OpenAI white-background editing, deterministic natural exposure and 1200×1200 B2B framing with optional cleanup | Authenticated backend preview calls; original-image catalog suggestions fill supported fields for artisan review. OpenAI edits require before/after confirmation, with mode/provider/review stored on the product. Live OpenAI image quality and camera permissions still need device testing. See [setup](OPENAI_PRODUCT_STUDIO.md). |
| 6–9 | Speech-to-text on form fields, original transcript, optional AI catalog draft, English/Hindi fields, editable missing details, read-aloud and explicit approval | Device speech/TTS and configured AI need live validation. Follow-ups are editable missing-field review, not a calibrated confidence model. |
| 10–14 | Labour hours/rate, material and overhead, cost floor, handmade demo comparables, final price, save unpublished, edit/reapprove/publish, readiness gaps, stock/capacity/lead time, committed-capacity check | Comparables are fixtures. Internal readiness and external eligibility stay independent. No live production-capacity/calendar integration. |
| 19–22 | Typed/spoken requirement draft and confirmation, reference photo, quantity/budget/deadline/location/customization, ranked reasons/gaps, product/artisan details, comparison up to three | Deterministic explainable matching works without AI; there is no vector-search or external marketplace ingestion. |
| 23–29 | Shared RFQ, original/translated messages and attachments, reviewed AI-assisted quote drafting from conversation, requested/offered terms, full/partial/declined capacity, quote revisions/reject/accept, stale/duplicate and sample guards, one accepted order | AI cannot send or accept terms. Translation unavailable is explicitly labeled; users can supply reviewed wording. Negotiation is a lightweight structured workflow. |
| 30–32 | Four production updates, separate shipment/inspection/payment status, order details/history, saved suppliers, supplier-specific order history, editable fresh reorder requirement | Reorder does not copy old acceptance, capacity or payments. No ERP. |
| 33–40 | Future-scope information only | Auctions, bidding, advanced analytics and artisan business insights remain deferred by the agreed plan. |
| 41 | Independent GeM/ONDC/state-board preparation forms | Guidance/demo preparation only; no submission, eligibility guarantee or buyer guarantee. |
| 42 | Separate admin console (`admin-web/` React app plus the legacy HTML demo page): real account verification/correction/rejection with evidence viewer, account directory, product moderation state, counts, audit trail; manual issue notes/outcome and progress review in the shared workspace | Verification, accounts, moderation and counts are real; order issues depend on the opt-in demo workspace. No advanced adjudication, refunds, risk scoring or ecosystem analytics. |
| 43 | Direct/hub/needs-review recommendation with reasons, packaging checks/evidence, carrier/reference/tracking, hub availability/handoff fields, optional representation proposal and confirmation | Routing records coordinate people; they do not book carriers, reserve storage or hire representatives. |
| 44 | Configurable advance/checkpoint/dispatch/inspection milestones and totals; advance gates production | Manual simulated payment confirmation only. No money, escrow or automated release. |
| 45 | Optional requested/submitted/approved/changes-requested/rejected sample, evidence and terms; changed specifications require reapproval | Sample terms/evidence are recorded; no separate paid sample checkout or shipment provider. |
| 46 | Optional quantity/photo progress checkpoint and buyer/admin review | Review is separate from payment confirmation; no AI quality guarantee. |
| 47 | Participant issue category, description/evidence, shared admin queue, investigation notes/outcome, blocking unresolved issue | Manual review only; local-only demo cannot resolve admin issues without a shared server workflow. |
| 48–49 | Dispatch, in-transit, received quantity, configurable inspection window, explicit acceptance, settlement/open-issue completion guards | No automatic acceptance after the inspection deadline and no real carrier status feed. |
| 50 | Integrated catalog → sourcing → agreement → production → fulfillment → inspection/completion flow | Six-problem framing is preserved in the architecture and source documents. |

## Code map

- `lib/features/commerce/domain/commerce_engine.dart`: pure workflow transitions, readiness, matching and route explanations.
- `lib/features/commerce/data/commerce_repository.dart`: product actions go to the authenticated backend catalogue (see *Product catalogue*); the remaining demo flows stay local or on the opt-in shared workspace, with version conflicts, media uploads and reviewed assistant drafts.
- `lib/core/services/product_service.dart`: authenticated product catalogue client — list, create, update, publish, availability and photo upload, all resolved from the Firebase identity.
- `lib/core/services/requirement_service.dart`: authenticated buyer-requirement client — list, create and reference-image upload, resolved from the same Firebase identity.
- `backend/app/routers/requirements.py`: account-owned buyer demand — `POST /`, `GET /`, `GET /{id}`, `POST /images` and `GET /images/{name}`, all buyer-only and scoped to the caller.
- `backend/app/services/image_store.py`: shared photo handling (size and pixel caps, EXIF/licence strip by re-encoding, unguessable name) used by the product and requirement uploads.
- `backend/app/routers/products.py`: account-scoped product catalogue — the flat record the app renders, plus `POST /`, `PUT /{id}`, `POST /{id}/publish`, `POST /{id}/availability`, `POST /images` and `GET /images/{name}`. Product facts without a column of their own live in `ProductListing.attributes`; no migration is required.
- `backend/app/routers/catalog.py`: attribute/listing generation pipeline plus `GET /published`, the published-only marketplace read used by buyer discovery.
- `lib/features/commerce/presentation/`: cream/forest-green mobile screens, shared form/card/image components and product studio.
- `backend/app/services/workflow_service.py`: server-side workflow validation; keep transition rules aligned with the Dart engine and tests.
- `backend/app/routers/workspace.py`: versioned SQLAlchemy JSON workspace, demo access, separate admin capability, media and assistant endpoints.
- `backend/app/services/workflow_assistant.py`: configured OpenAI-compatible LLM requests with field allowlists and explicit fallback provenance. Configure `LLM_API_KEY`, `LLM_API_BASE` and a model supported by your account through `LLM_MODEL`; credentials are not supplied by this implementation.
- `backend/app/routers/admin.py`: administrator read API (overview, accounts, products, requirements, activity, platform) with moderation and account-status actions; gated by `require_admin` in `backend/app/core/auth_deps.py`.
- `admin-web/src/`: React admin console — `lib/` (API client, hash router, async hook, queue join), `components/` (layout, UI kit, icons), `pages/` (one component per screen), `styles.css`.
- `backend/admin/index.html`: legacy demo-workspace admin page, retained for the shared workspace records.

## Checks and practical limits

OpenAI Studio update, 2026-09-14: the full backend suite passes 41 tests, including twelve Studio service/API tests and persisted OpenAI photo-review/publication checks. Flutter Studio tests cover distinct modes, review gating, original-image analysis, preservation of artisan wording, manual fallback, and pending-request controls. The active OpenAI flow supersedes the 2026-09-13 flood-fill implementation below. Tests mock OpenAI; no live generation or calibrated recognition/fidelity accuracy is claimed.

Product availability (2026-09-13): owners can switch Available Now / Not Taking Orders directly on product details. Status is visible on catalog cards and buyer details. The persisted `availability` action validates boolean input and artisan ownership in Dart/Python without invalidating catalog approval or publication; new inquiries are blocked while paused. Existing conversations, quotes and orders remain usable. Capacity quantities still use the existing catalog editor. Tests cover unauthorized/invalid updates, unchanged catalog/order records, pause/resume, matching gaps, restart persistence, and English/Hindi owner/buyer controls. Buyer startup now waits for workspace loading before role synchronization to preserve saved records.

Photo preparation correction, 2026-09-13: plain background now uses 18px border seeding, a protected central 70% rectangle, enclosed-island cleanup under 2%, and a 3px outward feather. Natural setting stays exposure-only. B2B fits retained bounds with 10% minimum padding into 1200×1200, or fits the entire natural photo when its background switch is off. The applied switch value persists on the product; previews show full images. Original files remain untouched. Synthetic pixel and commerce screen checks pass; actual textured-background photos and device performance remain unvalidated. The centre protection deliberately retains some backdrop and cannot protect similarly coloured product extensions outside that region.

Navigation fix validated 2026-09-13: all 70 Flutter tests pass, including verified Artisan/Buyer → Go to home → workspace tab → real account details and English/Hindi navigation. `flutter analyze --no-pub` reports 156 existing warnings/informational findings; analysis is not lint-clean. `flutter build apk --debug --no-pub` succeeds; artifact: `build/app/outputs/flutter-apk/app-debug.apk`. Phone installation and live admin-to-device refresh remain unvalidated.

**Product catalogue, 2026-09-13.** Saving a product in Product Studio now writes real, account-scoped rows instead of staying on the device. The artisan identity comes from the verified Firebase token (`require_artisan_profile`); `POST /api/v1/products/` creates the `Product`, its `ProductListing`, a `PriceRecommendation` (cost floor = material + labour + overhead, explainable comparables) and its `ProductImage`s in one call, and the app renders the flat record those calls return. Saving still does not publish: `POST /api/v1/products/{id}/publish` re-checks readiness server-side and refuses flagged/blocked listings, and `POST /api/v1/products/{id}/availability` changes operational availability only. Buyers browse published products through `GET /api/v1/catalog/published`. Studio labels that have no enum value (`Baskets`, `Textiles`) are stored as `weaving` and the original label is kept in `attributes.ui_category`, so the app and the console show what the artisan chose. Photos are uploaded with `POST /api/v1/products/images` and served public-read under unguessable filenames; verification evidence keeps its authenticated path. Records loaded from the backend are treated as backend-owned, so the seeded on-device demo catalogue keeps working until the shared catalogue replaces it — inquiries, quotes, orders, payments and shipping are unchanged and still demo. Validated: 27 backend tests pass (9 new catalogue tests: create → list → admin visibility, draft without listing detail, cost-floor refusal, readiness-blocked publish, availability, ownership isolation on read/write/publish/availability, buyer write refusal, photo upload and non-image rejection) and all 89 Flutter tests pass. Live end-to-end artisan-to-admin flow on a device is still unvalidated, and the running backend must be restarted to serve the new routes.

Also fixed: `backend/app/routers/catalog.py` used `select(...)` in `verify_listing` without importing it.

**Buyer requirements, 2026-09-14.** Posting a requirement now writes a real, account-owned row instead of staying on the device. `POST /api/v1/requirements/` (buyer-only via `require_buyer`) stores what the buyer needs — product, quantity, budget per unit, lead time, destination, target date, customization, specifications, packaging and a sample request — plus the buyer's own words verbatim in `original`, so nothing is lost to translation. The buyer must have confirmed the structured form (`confirmed: true`) or the request is refused with 422, and quantity and lead time must be positive. `GET /api/v1/requirements/` and `GET /{id}` are scoped to the caller; another buyer receives 403. A reference image is uploaded with `POST /api/v1/requirements/images` and served public-read under an unguessable filename, because an artisan has to see it when matching. The console gains a read-only **Requirements** page (`GET /api/v1/admin/requirements`, plus `requirements: {total, open}` in `/admin/overview`) and a "Buyer demand" card on the dashboard; it records no decision, because a requirement is demand rather than an order. Matching itself is unchanged and deterministic — `CommerceEngine.matches` still scores capability fit (product/craft, MOQ, capacity, lead time, budget, customization, availability) against published products, which is now the real published catalogue, so an empty catalogue means an empty match list rather than demo results. Products and requirements now share `app/services/image_store.py` instead of each carrying its own validation. Validated: the full backend suite passes 48 tests (7 new requirement tests: post → list, admin visibility with buyer and business name, confirmed-gate refusal, incomplete-input refusal, buyer-only access, cross-buyer isolation, and reference-image upload with non-image refusal), all 95 Flutter tests pass, and the console lints clean and builds. The artisan/console view of a posted requirement on a real device is still unvalidated, and a restarted backend is required for the new routes and the `requirements` table.

**Stored media paths, 2026-09-14.** Upload responses return a path relative to the API (`/api/v1/products/images/...`, `/api/v1/requirements/images/...`) rather than an absolute URL, and the app stores that path. Building an absolute URL from the request produced `https://localhost:8000/...`: uvicorn trusts the dev tunnel's `X-Forwarded-Proto: https` while the Host stays `localhost:8000`, so the stored URL was unreachable from the app and from a browser. `ApiClient.mediaUrl` now resolves a relative path against the API base URL the build is actually using, and `CraftImage` renders it (device-captured paths and sample illustration names still behave as before). Rows written before the fix were rewritten to relative paths; the image files themselves were always stored correctly and serve `200 image/jpeg`.

Validation recorded 2026-09-11: 54 Flutter tests passed, 8 backend tests passed, admin JavaScript syntax passed, and documentation links resolved. `flutter analyze --no-pub` reports 0 errors, 9 warnings and 172 informational findings (181 total); it exits nonzero because lint findings remain. Final Android artifact: `build/app/outputs/flutter-apk/app-debug.apk`.

Re-validated 2026-09-12: 68 Flutter tests pass, 12 backend tests pass (account/verification, workflow, workspace demos), and the debug APK still builds with ML Kit linked in. `flutter analyze --no-pub` reports 0 errors and 156 lint findings. The account API tests previously errored on Windows because the harness created its runtime directory inside `backend/tests/`, where creation and cleanup are denied; they now use the system temp directory.

Admin console added 2026-09-12: the backend suite runs 16 tests, adding four admin API tests (access control per endpoint, directory/overview counts, moderation state plus audit entry, verification decision and account disable audited). `npm run lint` (oxlint) reports 0 warnings and 0 errors and `npm run build` succeeds. The dev server and its `/api` proxy were smoke-tested against a running backend: `/api/v1/admin/*` returns 403 without the admin token and 200 with it, and the mobile/workspace token is rejected. The React console was not driven in a real browser — `agent-browser` is not installed in this environment — so visual review of the rendered screens is still outstanding.

Flutter engine, persistence and phone-layout tests cover role continuity, independent readiness, ownership, matching gaps, price floor, quote versions, optional samples, advance/production/checkpoint/dispatch/inspection/settlement, blocking issues and fresh reorders. English/Hindi layouts include inquiry, order and product studio. Backend unit and real HTTP/SQLite tests cover transitions, access tokens, separate admin permissions, revision conflicts, uploads and assistant fallback.

Android debug APK builds with the installed SDK. The Kotlin plugin compatibility notice remains a warning. Analyzer style/deprecation findings remain in the repository; do not describe analysis as clean. No emulator/phone was connected during implementation, so actual speech, camera, Firebase OTP, LAN connectivity and iOS builds still need device validation.

The shared API is deliberately an opt-in **single demo workspace**, disabled in production. Its mobile token authorizes switching seeded demo identities and reading the shared demonstration data. It is not production multi-tenant authorization. Local preferences/media use demo storage; production needs protected user-specific storage, token handling, tenant-scoped APIs, schema migrations and service integration review. Legacy CRUD/AI screens and endpoints remain in the repository but are not the active new commerce flow and should not be exposed as a production service without an authorization audit.

Main startup creates missing tables; no Alembic revision history is supplied. PostgreSQL remains supported by the configured backend, but this run tested SQLite. Celery's missing entrypoint is repaired; this does not mean background AI tasks or the whole Docker stack were tested.
