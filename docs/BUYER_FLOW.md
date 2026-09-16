# Buyer reference flow — coverage and implementation

Updated 17 September 2026. This maps the supplied buyer diagrams to the active Aakar app. The diagrams use the older CraftConnect name; the app remains Aakar. Existing phone-OTP authentication, reviewed AI suggestions, manual payment records and logistics coordination remain explicit boundaries.

## Screen checklist

| Reference | Active behavior | Boundary |
|---|---|---|
| 1.1 Welcome | Existing welcome and registration entry | Existing Aakar branding |
| 1.2 Sign up | Firebase phone OTP, name and role-specific setup | Password and Google login from the drawing were not added; work email is business contact data, not a new login credential |
| 1.3 Business details | Name, type, industry, state/district plus newly persisted optional work email and website | Input validation; changing reviewed business data requires re-review |
| 1.4 Verification | Business document image upload, contact/consent submission and manual administrator review | No claim that a generic document checklist guarantees eligibility |
| 1.5 In progress | Pending status, refresh and browsing/home access | No unverified 1–2-day service promise |
| 1.6 Verified | Server-approved verification screen and badge | Verification does not activate unimplemented services |
| 2.1 Home | Search, three discovery entries, account-filtered requirement/quote/order/saved-supplier counts, Bidding and Saved Suppliers shortcuts | Quotes/orders are existing workspace records, not new live external metrics |
| 3.1 Search products | Search query carries from home; actual category/location/price bands and sorting | Catalogue data is authenticated backend data for signed-in users |
| 3.2 Browse artisans | Craft, region and verification filters now affect results; supplier profile opens from cards | Directory reflects known catalogue profiles, not a fabricated global directory |
| 3.3 Post requirement | Type/dictate text or attach a reference image at entry, then review details | Image is attached as reference; image-only requirements need manual specifications |
| 4.1 Structured requirement | Existing assistant/basic extraction, explicit field review and original wording retained | No new vision extraction or guaranteed AI inference from reference images |
| 4.2 Matched suppliers | Existing explainable fit ranking, reasons, capacity and lead times | Deterministic capability scoring is not a calibrated AI probability |
| 4.3 Compare | Existing up-to-three supplier matrix and inquiry actions | Artisan still confirms actual capacity |
| 5.1 Inquiry / RFQ | Quantity, customization, dates/location, optional sample and reference | Existing local/shared demo negotiation records |
| 5.2 Chat | Existing original/translated wording, attachments and speech input | Translation availability/provenance remains visible; no fake online presence or guarantee of real-time translation |
| 6.1 Capacity | Confirmed/partial/declined response before quotation acceptance | Existing workflow validation |
| 6.2 Quotation | Itemized unit, packing, delivery and other costs, milestones and terms | No automatic acceptance |
| 6.3 Negotiation | Original quote and successive versions, reject/counter/accept | No silent overwrite of agreements |
| 7.1 Payment protection | Existing configurable payment commitment/milestone screen | Demo payment records only; no escrow, held funds or money transfer |
| 7.2 Confirmed order | Existing quote acceptance, payment checkpoint before production | No escrow-backed claim |
| 8.1 Order progress | Existing production/shipment/inspection/completion states | Completion still requires inspection, settlement and no blocking issue |
| 8.2 Production updates | Existing photos/proofs, optional sample and progress checkpoint | Evidence does not guarantee quality |
| 8.3 Logistics | Existing carrier/reference/tracking and dispatched/in-transit/delivered statuses | Coordination records; no carrier booking or live tracking provider |
| 9.1 Completed | New prominent completion panel with reorder, review and supplier actions | Only shown for completed orders |
| 9.2 Save supplier | Account-filtered bookmarks; correct saved/remove state in artisan cards | Existing persisted workspace, not a new production bookmark service |
| 9.3 Reorder | Supplier history opens fresh repeat-purchase flow | Reconfirms current catalogue and terms |
| 9.4 Review | New 1–5 stars, 500-character feedback, optional tags; editable one review per completed owned order | Persisted in existing demo workflow on device or shared demo server; no public verified-review system claimed |
| 9.5 Relationship | New Overview / Products / Past Orders supplier hub, save and new-inquiry actions | Counts and ratings derive from available records; no invented reliability numbers |
| 9.6 Repeat purchase | Product → editable details → explicit confirmation → fresh RFQ | Previous quote acceptance, price, payment and capacity commitments are not duplicated |
| 10.1 Bidding | Previously implemented server-owned directory and sealed offers; activity opens the exact session | 15-second polling on bidding page; see BIDDING_FLOW.md |
| 10.2 Notifications | All / Orders / Quotes / Bidding / Others filters; bidding section derives current session activity | Current bidding activity is not a push-notification delivery service |
| 10.3 Saved suppliers | Dedicated directory, profile, order history/reorder, removal and discover-more actions | Buyer-specific saved keys; honest empty state |
| 11.1 Government marketplace | Dedicated Coming Soon page with useful catalogue/business-profile navigation | No pretend tenders, applications, email subscription or procurement integration |
| 11.2 Business profile | Business/type/industry/location/contact/site, edit and verification/document-status navigation | Documents remain under authenticated verification access |

## Code and persistence

- `commerce_screen.dart`: existing buyer surfaces, corrected discovery filters, navigation and activity counts.
- `buyer_experience.dart`: supplier relationship, saved directory, categorized activity, completion and future-marketplace screens, as part of the existing commerce screen library.
- `buyer_flow_widgets.dart`: review form and three-step repeat purchase UI with voice fields.
- `commerce_engine.dart` and `backend/app/services/workflow_service.py`: matching review rules in both existing workflow modes. Only the owning buyer may review a completed order; rating/text/tags are validated.
- `BuyerContact` in `backend/app/models/models.py`: new `buyer_contacts` table stores business work email and website separately from identity credentials. Existing startup creates this new table without altering the old buyer schema.
- `/auth/buyer-profile` and `/auth/me`: save/read the contact details for the authenticated buyer; unchanged details do not invalidate review, changed details do.

## Deployment and validation

Restart the backend for the new contact table/model and relaunch the rebuilt Flutter app. No AI keys or provider-profile changes are needed. Actual multi-device commerce, escrow, carrier integrations, password/Google login and automatic reference-image requirement extraction were not introduced in this UI pass.

Automated coverage includes phone-size English/Hindi routes, onboarding, buyer-only review permissions, invalid ratings/tags, contact validation and isolation, current-price/MOQ reorder, unavailable products, and the existing bidding flows. Real OTP, dictation and gallery/device acceptance remain separate checks.

Validation for this implementation: 89 Flutter tests and 20 backend tests passed. `flutter analyze --no-pub` reported no errors (172 warning/info findings remain). `flutter build apk --debug --no-pub` succeeded; output: `build/app/outputs/flutter-apk/app-debug.apk`. The APK has not been installed or checked on a physical device in this pass.
