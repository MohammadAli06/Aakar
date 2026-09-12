# Account onboarding — 2026-09-12

The active mobile entry flow now uses real account APIs. This replaces the demo entry described in older workflow notes; it does not turn the remaining commerce fixtures into production services.

## Flow and appearance

Existing Aakar splash/logo and language selection → common mobile-number sign-in → Firebase OTP → backend account lookup → choose Artisan or Buyer for a new account → role profile → optional verification submission → account home.

Artisans use warm cream, forest-green actions and rounded fields. Buyers use cool ivory, deep teal actions and restrained white cards. Both use the same components, Hindi/English localization, account service and Firebase session. Profile fields are validated and saved before proceeding. Network failures show retry states; they do not create local accounts or successful verification states.

The account screen at `/account` shows the authenticated account and links to profile editing and verification. The main home now opens the labeled demo commerce workspace. A registered phone number retains its database role. Existing artisans and buyers bypass role selection, including when their profile is unfinished. Only an authenticated number without an account sees role selection. The backend rejects changing an existing role or creating the opposite profile. `users.role` and ownership determine authorization. Profile setup has a back button: unfinished setup signs out to phone entry while preserving the registered role; profile editing returns home.

Account lookup is read-only: verify the Firebase token, query `users` by its verified `firebase_uid`, then query the matching role profile by `user_id`. No role is inferred from profile completeness or automatically repaired during login. The proposed legacy-role repair was reverted after the developer reset the affected account data. Regression coverage inspects SQL statements to ensure existing-account login and rejected opposite-role requests issue only SELECTs. Unused mobile role-switch service methods have been removed.

Update 2026-09-13: login and “Go to home” now open the main commerce workspace at `/dashboard`, with working `/workspace/*` tabs. Profile → Help & scope explains that sample products/orders are separate from the verified account. The top demo banner and account button have been removed; real profile editing and verification remain accessible from Profile. Profile and verification use the real backend; refreshing verification also refreshes the account badge. Commerce still uses the existing demonstration repository, not tenant-scoped account products/orders. Legacy API screens remain blocked. This restores navigation without claiming production commerce integration.

## Storage and endpoints

| Data | Implementation |
|---|---|
| Phone identity and OTP | Firebase Auth; backend verifies Firebase ID tokens |
| Account and role profiles | SQLAlchemy `users`, `artisans`, `buyers`; PostgreSQL configured through `DATABASE_URL` |
| Verification | `account_verifications`, one row per user/role, evidence URLs and consent/submission timestamps |
| Evidence binaries | `backend/uploads/verification/*.jpg`; image validation and re-encoding remove metadata; 8 MB upload cap |
| Catalog and orders | Existing SQL/commerce implementation; production mobile integration remains pending |
| Semantic matching | pgvector remains pending; JSON embedding placeholders are not vector search |

All account/evidence calls require `Authorization: Bearer <Firebase ID token>`:

- `GET /api/v1/auth/me`: account lookup; only a 404 means registration is needed. Invalid/disabled tokens and server outages remain failures.
- `POST /api/v1/auth/verify-token?role=artisan|buyer`: first registration after verified phone authentication; existing accounts return their current role.
- `PUT /api/v1/auth/role`: compatibility endpoint; only the already registered role is accepted, and a different role returns 409.
- `PUT /api/v1/auth/artisan-profile` and `/buyer-profile`: owner-only profile updates.
- `GET /api/v1/auth/verification`: current role's status, uploaded evidence and review note.
- `POST /api/v1/auth/verification/evidence`: multipart `file` and `kind`; artisan kinds are `identity`, `craft`, `selfie`; buyer kind is `business`.
- `POST /api/v1/auth/verification/submit`: JSON `{"consent":true}`. Requires complete profile and evidence; records pending review, never automatic approval.
- `GET /api/v1/auth/verification/evidence/{filename}`: authenticated owner access. These files are not publicly mounted.

Manual reviewers use a separate `ADMIN_ACCESS_TOKEN` bearer credential:

- `GET /api/v1/auth/verification-admin` lists submissions.
- `GET /api/v1/auth/verification-admin/{id}/evidence/{kind}` reads private review evidence.
- `PUT /api/v1/auth/verification-admin/{id}` accepts `{"status":"verified|needs_correction|rejected","note":"Review explanation"}` for pending submissions.

These are real account-review APIs, separate from the older demo admin queue. The dedicated account-review web interface now lives in `admin-web/` (see [implemented workflows](IMPLEMENTED_WORKFLOWS.md#admin-console-admin-web)); it signs in with the same `ADMIN_ACCESS_TOKEN`. Profile changes invalidate affected pending/approved reviews. Corrections can be uploaded and resubmitted. The UI does not promise approval or a fixed turnaround time.

## Run and validate

Configure Firebase phone authentication and the platform configuration files for the app package. Configure matching Firebase Admin credentials on the backend using `FIREBASE_CREDENTIALS_PATH` and `FIREBASE_PROJECT_ID`. Keep credentials out of Git.

Set `DATABASE_URL` to the PostgreSQL asyncpg connection, `ENABLE_DEMO_WORKSPACE=false`, and a separate `ADMIN_ACCESS_TOKEN` in the backend environment. From `backend/`, run `.venv/Scripts/python.exe -m uvicorn main:app --host 0.0.0.0 --port 8000`. Use an explicitly configured API URL for the app, for example `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1` on an Android emulator; deployments should use their HTTPS endpoint.

Startup creates missing tables, including the new verification table. It does not migrate incompatible existing tables: older databases without the current `users`/profile schema need a reviewed migration before use. Back up real data before schema changes. PostgreSQL and live Firebase/device OTP have not been verified in this run.

Automated coverage uses stubbed verified identities and isolated SQLite databases; it verifies registration, role/profile separation, evidence ownership, bad uploads, consent/evidence guards, admin-only review, and invalidation after profile edits. Flutter coverage checks shared entry routing, English/Hindi layouts, distinct role palettes, pending/retry behavior and stale authentication responses. Run `flutter test --no-pub` and, from backend, `.venv/Scripts/python.exe -m unittest discover -s tests -v`.

Remaining acceptance: real-device OTP/autoverification/resend and camera permission flows, PostgreSQL deployment/migrations, backup/access operations for verification evidence, tenant-scoped commerce integration, and pgvector matching. The admin review console itself is implemented; see [implemented workflows](IMPLEMENTED_WORKFLOWS.md#admin-console-admin-web).

Validation after the fixed-role correction: 68 Flutter tests and 11 backend tests pass, including back navigation for incomplete profiles and bypassing role selection for existing accounts. Flutter analysis is not lint-clean; repository warnings and informational findings remain. After the admin console was added, the backend suite runs 16 tests (including four admin API tests), and the admin web build and lint are clean.
