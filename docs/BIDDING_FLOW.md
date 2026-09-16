# Bidding implementation — 17 September 2026

This replaces the fixed sample lot at the user's explicit request. The prior architecture exclusion of bidding is superseded for this flow.

## Reference checklist

| Step | Implemented screen / behavior |
|---|---|
| 1. Home | Existing Bidding tab and Host Bidding entry; actual live-session count, no sample countdown or unconditional LIVE badge |
| 2. Bidding section | Create entry, Upcoming / Live / Completed filters and saved session cards |
| 3. Select product | Search the artisan's existing products |
| 4. Preview | Product photo, description, category, material, stock and edit-product link |
| 5. Details | Whole-piece quantity, minimum unit price, local start date/time, duration, cost-floor guidance |
| 6. Relevant buyers | Verified, active buyer accounts with matching open requirements; names and matching reasons, explicit empty state |
| 7. Confirm | Product and schedule summary; save to database only on confirmation |
| 8. Scheduled | Persisted times, details, edit and cancel before start |
| 9. Live | Server-derived phase, time remaining, offer count, sealed prices; buyer submit/modify/withdraw |
| 10. Closed | Server rejects late offers; owner can see offer prices only after closing |
| 11. Compare | Unit price, quantity, requirement match reason, buyer notes; no fabricated reliability score |
| 12. Decide | One buyer, split across buyers, or reject all |
| 13. Allocate | Per-buyer quantity and running total; positive quantities within offer and lot limits; selected buyer can withdraw before quotation |
| 14. Quotation | Idempotent, persisted inquiry per selected buyer; open existing quotation workflow with selected price/quantity, without accepting an order |

## Implementation

- `backend/app/routers/bidding.py`: new `bidding_sessions` table, authenticated endpoints, server clock and access checks, optimistic revision checks, stock reservation among bidding sessions, verified-buyer matching, offers and quotation handoffs.
- `lib/features/commerce/data/bidding_repository.dart`: account-scoped Riverpod repository; no fallback to fabricated sessions when the backend fails.
- `lib/features/commerce/presentation/bidding_panel.dart`: English/Hindi setup and management flow in the existing commerce shell. Status polls every 15 seconds while the page is current; this is polling, not WebSocket delivery.
- `commerce_repository.dart`: participant-checked import into the existing quotation workspace; repeated opening preserves locally edited quotes.
- `commerce_screen.dart`: real home count and new hub, no sample bidding data; quotation form initially uses the selected offer's price.

New tables are created by the existing backend startup hook. Restart the backend after updating it and rebuild/relaunch Flutter. No new API keys or AI provider settings are required.

## Matching and commercial boundaries

Matching uses shared words from product title/category and an open buyer requirement. It is explainable deterministic matching, not semantic AI matching. Buyers must be verified and active; no minimum audience is invented. Cost-floor guidance comes from product material/labour/overhead, not a new AI price call. Reliability says that no completed-order rating is available.

All offers are stored on the server. While live, even the artisan API response omits sealed offers; a buyer sees only their own offer and never competitors' prices. Server deadlines are enforced on writes, even with an old client screen. There is no automatic highest-price acceptance, publication or order creation.

Bidding reservations prevent the same stock being put in multiple bidding sessions. Cancellation/rejection release the lot; selection reserves only allocated units. They are not an inventory/fulfillment integration: existing normal B2B capacity is reconfirmed in quotation. Quotation-stage bidding reservations remain allocated and are not automatically settled from demo order/payment records.

The handoff itself is persisted and visible to both participants. Subsequent quotation edits, conversations, order/payment/shipping transitions still use the pre-existing **local demo commerce engine**. They are not newly synchronized between signed-in devices by this change. The handoff screen states that boundary. A buyer backing out after quotation follows the existing B2B decision process; pre-quotation withdrawal is handled in bidding.

## Verification and manual test

Automated tests cover authentication/ownership, verified matching, sealing and buyer isolation, time boundaries, stale updates, edits/cancellation, reservations, cost-floor/timezone validation, withdrawal, split allocations and idempotent handoff. Phone-width widget tests cover creation, zero matches, split allocation, buyer controls and English/Hindi navigation. Actual multi-device behavior still needs device acceptance.

To try with real records:

1. Save an available artisan product with positive stock and costs.
2. On a separate verified buyer account, post an open requirement using relevant product/category wording (for example, “bamboo basket”).
3. On the artisan account, create a session with a future start and short duration; review the actual matched buyers and confirm.
4. On the buyer account, open Bidding → Live and enter an offer. Verify that the artisan can only see the offer count before closing.
5. After closing, compare/select or split quantities, then proceed to quotation. Final terms still need review and confirmation.

Validation result (2026-09-17): 17 backend bidding/catalogue tests and 46 focused Flutter tests passed. `flutter analyze --no-pub` reported no errors (168 warning/info findings remain). `flutter build apk --debug --no-pub` succeeded at `build/app/outputs/flutter-apk/app-debug.apk`. The local backend OpenAPI schema includes `/api/v1/bidding`. No real buyer offer, selection or commercial commitment was created during validation.
