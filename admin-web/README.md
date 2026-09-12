# Aakar admin console

React + Vite console for the shared Aakar backend. It is the dedicated account-review
web interface: artisan and buyer verification decisions, the account directory, product
moderation, a manual order-issue queue, counts and an administrator audit trail.

It is one of three clients of the same FastAPI database (Flutter mobile app, this console,
and the legacy `backend/admin/index.html` demo page).

## Run it

The backend must be running first. From `backend/`:

```powershell
.\run_demo.ps1           # print the admin token it generates
```

Then from `admin-web/`:

```powershell
npm install
npm run dev              # http://localhost:5173
```

Sign in with the **admin access token** (the value of `ADMIN_ACCESS_TOKEN`). The token is
verified server-side on every request; the mobile/workspace token is rejected with 403.

Point the console at a different backend with `BACKEND_URL` (dev proxy) or
`VITE_API_BASE_URL` (built asset). See `.env.example`.

```powershell
npm run lint             # oxlint
npm run build            # dist/
```

## What is implemented

| Screen | Data source | State |
|---|---|---|
| Dashboard | `GET /api/v1/admin/overview`, `/admin/activity` | Live counts, pipeline bars, role split, attention list |
| Verification | `GET /api/v1/auth/verification-admin` + `/admin/accounts` | Real queue, filter by role/status |
| Verification review | `PUT /api/v1/auth/verification-admin/{id}` | Approve / request correction / reject, private evidence viewer |
| Accounts | `GET /api/v1/admin/accounts`, `/accounts/{id}` | Directory + profile, verification, enable/disable |
| Products | `GET /api/v1/admin/products`, `/products/{id}` | Listing, cost-floor pricing, persisted moderation decision |
| Order issues | `GET/POST /api/v1/workspace` | Manual issue review — needs `ENABLE_DEMO_WORKSPACE=true` |
| Analytics | `GET /api/v1/admin/overview` | Current-state snapshot only; no time series is stored |
| Audit trail | `GET /api/v1/admin/activity` | Reviewer decisions, moderation and submissions |
| Platform | `GET /api/v1/admin/platform` | Read-only, non-secret backend facts |

Deferred screens (B2B monitoring, bidding/auctions, integrations, support) are shown as a
scope statement rather than mock data, so the console never claims a capability it lacks.

## Honest boundaries

- Moderation decisions never publish, unpublish or re-approve a listing; publication stays
  the artisan's action in the mobile app.
- Approving verification marks the role profile verified. A later profile edit invalidates
  the review.
- The console does not move money, hold escrow, book carriers or hold external marketplace
  submissions. Order issues come from the shared demo workspace and are manual notes.
- Evidence images are fetched per request with the administrator credential and are never
  cached by the browser.

## Structure

```
src/
  lib/         api client, hash router, async hook, formatting, queue join, toast context
  components/  layout, UI kit, icon set, toast provider
  pages/       one component per screen
  styles.css   design tokens and the whole stylesheet
```
