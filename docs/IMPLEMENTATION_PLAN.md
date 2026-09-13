# Implementation plan and demo checklist

## Production onboarding slice — 2026-09-12

- [x] Restore main home and workspace navigation after login / verification (2026-09-13). Keep the commerce demo boundary in Profile → Help & scope, without a top banner, and retain real account details at `/account`; refreshing verification also refreshes the account badge. Tenant-scoped commerce remains pending.

- [x] Follow the revised single-role rule: existing phone accounts skip role selection, opposite-role creation is rejected, and business profile setup offers back navigation.
- [x] Keep existing-account login read-only; test emitted SQL for both roles and remove unused client role-switch methods. No automatic role reconciliation.

- [x] Shared Firebase phone sign-in screen and backend account lookup; handle unavailable backend separately from new accounts.
- [x] Backend profile persistence and initial artisan/buyer role selection for new phone accounts only.
- [x] Warm artisan / cool buyer themes for profile, verification and account home, with Hindi/English support.
- [x] Private image uploads, consent/evidence checks, pending review and admin-only review APIs; profile changes require re-review.
- [x] Remove demo entry/reset controls from onboarding; keep legacy API screens blocked. Main commerce workspace access restored with explicit demo labeling on 2026-09-13.
- [x] Add the production account-review web UI (`admin-web/`): dashboard, verification queue and review, accounts, product moderation, manual order issues, counts, audit trail.
- [ ] Validate actual device OTP, resend/autoverification, camera permissions and PostgreSQL setup.
- [ ] Add deployment migrations and tenant-scoped commerce screens/services.
- [ ] Implement pgvector semantic matching; existing embedding placeholders are not completion evidence.

See [Account onboarding](ACCOUNT_ONBOARDING.md). The historical demo checklist below remains a record of that implementation, not a production-readiness claim.

Target: [Updated architecture](UPDATED_ARCHITECTURE.md). Baseline: [Project context](PROJECT_CONTEXT.md). Implementation added 2026-09-11. Read [implemented coverage and remaining boundaries](IMPLEMENTED_WORKFLOWS.md). Checked items have automated implementation evidence; open items include device/live-integration acceptance or partially implemented behavior. No live provider integration is implied.

## 1. Preserve the existing flow and establish shared state

- [ ] Run the current Flutter checks and manually establish the artisan demo baseline.
- [x] Define explicit demo/live service boundaries and shared persistent repositories; replace disconnected fixture state as workflows are added.
- [ ] Add common identity/role membership, buyer profile, post-login toggle, and role-specific home/navigation; seed a demo account authorized for both roles.
- [ ] Enforce backend ownership/participant/admin access when connecting real state; constrain auth bypass to explicit demo mode.
- [x] Choose minimal admin web technology only when implementing the admin slice; no separate buyer web target.

Accept when the same phone can switch roles without losing language/session/business state, while real authorization does not depend on the toggle.

## 2. Finish product creation and separate publication

- [x] Replace the active photo pipeline with authenticated OpenAI white-background editing, deterministic natural exposure and optional-cleanup B2B framing (2026-09-14). Add original-image catalog suggestions with field/evidence filtering, correction, unchanged artisan values and explicit image review. Persist photo metadata through the real product API. [Configuration and boundaries](OPENAI_PRODUCT_STUDIO.md). This supersedes the local-only photo path recorded below.
- [x] Migrate Studio to OpenAI image edits and Responses-based catalog extraction; separate API-credit and rate-limit errors, preserve legacy Gemini photo review and original/manual fallbacks. ChatGPT subscription billing is separate.
- [ ] Validate the OpenAI key/model access and actual output quality on artisan photos, including pale products, handles/fringes, heavy shadow and textured tables. Mocked responses and synthetic tests do not establish live accuracy.

- [x] Add an owner-only product availability switch with buyer-facing status, persisted boolean-only workflow updates, backend ownership checks and new-inquiry gating. Keep catalog approval/publication unchanged and capacity fields in the existing Edit & re-verify flow. Validate role/restart persistence and English/Hindi phone controls; defer live tenant-scoped commerce.

- [x] Show the B2B background switch only when B2B catalogue frame is selected.

- [x] Harden deterministic photo preparation (2026-09-13): 18px border seeds, protected central 70%, enclosed-island cleanup below 2%, and 3px outward feather. Natural mode skips masking; B2B fits retained bounds into 1200×1200 with 10% minimum margins and an optional whole-natural-photo setting. Full-image previews and original retention support review. Synthetic pixel regression tests pass; real textured-photo/device acceptance remains pending.

- [x] Remove the four trailing Review Catalog toggles (availability, customization, fragility, safe packaging) at user request. Preserve stored values and existing readiness checks; removing controls does not confirm capabilities.

- [x] Wire guided capture/enhancement with original preservation and review; label any simulated processing. The studio now offers three real, deterministic preparations — plain background, exposure correction and a fixed 1200×1200 catalogue frame — each with before/after comparison, undo, and the choice stored on the product record. Back navigation moves between studio steps instead of leaving the wizard.
- [ ] Wire speech input, image/voice extraction, confidence-based follow-ups, generated catalog, read-aloud, and voice corrections/approval.
- [x] Ensure artisan-set final price is saved; fix and test recommendation cost-floor enforcement, including cost above demo market prices.
- [x] End creation at My Products. Support Draft, Ready to publish, Published, Needs update; map existing enums deliberately.
- [x] Add edit/re-verify/update/publish/republish behavior with durable product state.
- [x] Implement internal readiness for all §13 fields, distinguish zero/false from absent data, and show missing requirements.
- [x] Keep GeM/ONDC/state-board readiness separate and explicitly simulated; remove submission/response guarantees from demo wording.
- [x] Add stock, capacity/time basis, production time, and availability fields; validate against existing commitments as orders arrive.

Accept when an artisan can create/save/exit without publishing, return and publish internally after correcting gaps, and remain internally discoverable while externally incomplete. Rejected or unreviewed AI data must not publish.

## 3. Buyer requirement and matching

- [x] Implement business profile and basic verification status.
- [x] Provide product search, artisan browsing, and requirement posting paths.
- [x] Structure typed/spoken requirement into product/quantity/budget/deadline/customization/location/other needs; require buyer confirmation.
- [x] Implement basic matching across every §20 factor with explanations, infeasibility/partial-capacity handling, and an AI-unavailable fallback.
- [x] Provide product/artisan detail and compact mobile comparison covering price/MOQ/capacity/lead time/customization/verification.
- [x] Share submitted requirements/matches/inquiries across both roles; include basic in-app updates.

Accept when a buyer's confirmed requirement matches the artisan's actual published product, explains reasons, and exposes any capacity/deadline gap. A drafted/unpublished product must not appear.

## 4. Inquiry, quote, and agreement

- [x] Implement RFQ fields and participant-scoped conversations.
- [x] Preserve original messages and reviewable AI translations/simplifications without changing commitments.
- [ ] Extract quantity, MOQ, unit price, target date, lead time, customization, delivery/payment terms, and specifications into reviewed quote changes; retain requested versus offered values and Needs negotiation when they conflict.
- [x] Store customization and full/partial/declined capacity confirmation.
- [x] Include route, packaging, delivery, and payment assumptions in draft quotes (coordinate with step 5).
- [x] Add accept/request change/reject and simple revisions with immutable version history.
- [x] Add optional sample request/order/evidence/buyer approval before bulk order; support no-sample branch and changes requested/rejected without bypassing approval or the bulk advance.
- [x] Create an order once from the specifically accepted terms; handle duplicate/stale acceptance and capacity conflicts.

Accept when switching modes demonstrates one inquiry, a correction/counterquote, optional sample approval, explicit agreement, and one shared bulk order with matching totals/terms. Verify 40 offered days versus 30 requested days remains a negotiation gap, and an unapproved required sample blocks bulk creation. Avoid adding full contract management.

## 5. Fulfillment and payment additions

- [x] Build explainable direct/hub/needs-review routing from inputs in §43, with labeled fixture availability/costs.
- [x] Provide product-specific packaging guidance, responsibility, cost assumptions, and QC/dispatch evidence.
- [x] Record optional hub receipt/storage/consolidation/handoff plan and carrier candidate; do not simulate booking as a real booking.
- [x] Add optional on-site demonstration request with person/role, location/date/purpose, sample movement, costs, and confirmation.
- [x] Store agreed payment milestones and clearly labeled manual/simulated confirmation; no real funds/escrow in this slice.
- [x] Support configurable advance/QC/dispatch/final triggers and validate milestone totals; 30/50/20 is an example, not fixed policy.
- [x] Gate production on the agreed advance; expose balance due and settlement independently.
- [x] Implement exactly four production updates with optional evidence and map them to the overall order lifecycle.
- [x] Add one optional progress checkpoint with quantity/percentage/photo/update and buyer/admin review; AI inconsistency flags cannot guarantee quality or automatically confirm payment.
- [x] Record packaging photo, shipping method, label/reference and tracking ID; show Dispatched → In Transit → Delivered with manual/simulated/provider provenance, separate from production states.
- [x] Add configurable buyer inspection window and acceptance/issue action; do not hardcode 48 hours or auto-accept at expiry.
- [x] Add participant issue intake for quality, capacity shortfall, damage, cancellation, received quantity mismatch, and disputed milestone, with evidence and order context.
- [x] Require delivery, inspection acceptance, due settlement, and no unresolved blocking issue before completion.
- [x] Add Saved Supplier → Order History → Reorder; prefill a new editable requirement linked to the previous order and reconfirm current commercial terms/capacity.

Accept when the demo explains who packs, where goods go, who carries them, who pays, and what enables production. Verify direct, hub, and missing-information paths; unknown hub availability cannot produce a confirmed route. Verify unpaid advance blocks production, disputed milestones remain unpaid, and delivery/inspection/issue/settlement guards prevent premature completion. Verify reordering 500 as 700 creates a new requirement without copying acceptance or payment state.

## 6. Minimal admin and final integration

- [x] Add separate admin web access using the common backend/database.
- [x] Implement artisan/buyer verification queue with approve/reject/request correction.
- [x] Add basic flagged-product/AI-output moderation and basic counts.
- [x] Add a minimal manual order-issue queue exposing agreed terms, payment/production/fulfillment status, and evidence; record admin review notes/outcome and support optional production review.
- [x] Rebuild the admin console as a React app over the real account APIs (`admin-web/`): account directory, verification review with private evidence, product moderation state, counts, and an administrator audit trail. Order issues and progress reviews remain workspace-backed and are labelled as the shared demo workspace.
- [ ] Confirm both mobile modes and admin see consistent statuses with appropriate access.
- [ ] Repair backend setup gaps relevant to the chosen demo (migrations, channel seeding, worker references if needed).
- [x] Update README/current context to match working commands and honestly distinguish real services from fixtures.

Accept when minimal verification/moderation/counts and manual issue intake/review work with participant/admin access checks. Do not expand into automated adjudication/refunds, risk scoring, a sophisticated dispute system, auction monitoring, or ecosystem analytics.

## One-device video script

1. Open the mobile app; select language; log in/use explicitly labeled demo login. Show Artisan Mode and profile/verification status.
2. Capture/select a product photo; compare enhancement; speak description; answer one genuinely missing/uncertain field; listen/correct/approve generated information.
3. Show labour-aware price explanation, finalize price, and save to My Products. Demonstrate that publishing is a separate action.
4. Publish after internal-readiness gaps are addressed. Briefly show external-channel readiness as independent and any connection as simulated.
5. Switch to Buyer Mode on the same device. Confirm business profile, post/confirm a requirement, inspect match reasons and compact comparison, send an inquiry.
6. Switch to Artisan Mode. Show simplified/translated requirement, confirm capacity/customization, review routing/packaging/cost assumptions, and send quote.
7. Switch roles to demonstrate one revision and, for the customized order, a one-sample request/approval before final bulk agreement. Show the shared order and simulated advance confirmation with configurable remaining milestones.
8. Show production updates and optional progress photo/review, chosen direct/hub route, packaging checklist/photo, shipping method/reference/tracking ID, and optional demo representation record. Use alternate fixtures to show the no-sample/no-checkpoint and alternative route branches if useful.
9. Show Dispatched → In Transit → Delivered, buyer inspection acceptance, required balance/settlement, and completion. Use a separate exception fixture (470 received of 500) to show Flag an Issue and the manual admin queue. Keep simulated payments/logistics visibly labeled.
10. Show Saved Supplier → Order History → Reorder, changing 500 to 700 and creating a new requirement. Show a short separate admin web segment; finish with future Artisan-initiated Bulk Clearance and buyer web. Buyer mobile demonstration remains on the same phone/emulator throughout.

Demo fixtures should include at least two comparable artisans, a product with a correctable readiness gap, an internal-ready/external-incomplete product, a full and a partial capacity case, and direct/hub/unknown routing cases. Add requested/rejected/approved sample and no-sample cases, 250/500 progress review, 40-versus-30-day negotiation, configurable milestones, inspection acceptance and issue branches, 470/500 quantity mismatch, and 500-to-700 reorder. Use stable shared identifiers and resettable demo data. Label sample analytics and provider status honestly.

## Explicitly deferred backlog

- Full sealed-bid lifecycle (§33–39): eligibility/invitations, T−2-day/T−1-hour/start/during/end/result notifications, sealed offers, artisan choice/splits/reject-all, minimum price, failure handling.
- Advanced admin: full account/B2B monitoring, trust/risk scoring, reports/restrictions, advanced/automated dispute adjudication, bidding monitoring, integration operations, full ecosystem analytics. Basic manual order-issue evidence/review is core.
- Live approved GeM/ONDC/state-board publication/sync and permitted external buyer-requirement sources.
- Real provider payments/escrow, releases/refunds, carrier booking/tracking, contracted hubs/storage/manpower.
- Artisan business insights unless core completion leaves time; simple saved-supplier/history/reorder is now core under `1.pdf`.
- Buyer Flutter Web with desktop procurement layouts; broader regional-language support.
- Production ERP remains outside the agreed lightweight product scope unless explicitly reconsidered.

## Checks when implementing

Use existing Flutter localization/widget checks plus focused tests for new stateful behavior. Prioritize source-of-truth consistency across modes, unpublished visibility, readiness independence, cost-floor edge cases, unauthorized access, stale/duplicate quote acceptance, capacity conflicts, and payment/production/completion transitions. Include sample approval/rejection/waiver, optional checkpoint review versus payment confirmation, shipment versus inspection state, configurable milestone totals/window, unresolved issues blocking completion, issue evidence access, and reorder creating fresh state. Manually verify phone layout, spoken review/correction, denied permissions, API/AI failure fallback, and clearly labeled simulations. Mark each checklist item only after its acceptance behavior is demonstrated.
