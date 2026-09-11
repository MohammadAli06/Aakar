# Lifecycle update from `1.pdf`

Incorporated at the user's request on 2026-09-10. Source: [preserved PDF](sources/b2b-lifecycle-refinements.pdf) and [full extracted text](sources/b2b-lifecycle-refinements.txt). The working specification is [UPDATED_ARCHITECTURE.md](UPDATED_ARCHITECTURE.md); this file records coverage and reconciled decisions, not a competing architecture.

## Complete source coverage

| `1.pdf` section | Adopted conclusion / example | Merged architecture sections |
|---|---|---|
| 1. Bulk production too early | Optional Sample Required? branch; one logo basket approved for shape/size/logo before a 500-unit bulk order | 15, 29, 45 |
| 2. Money to begin production | Agreement/payment terms → advance pending/confirmed → production → dispatch/delivery → balance settlement; record commitments/status, no MVP escrow; percentages agreed, not fixed | 27, 29, 44 |
| 3. Production quality visibility | One optional progress photo/update reviewed by buyer/admin; 250 of 500 = 50%; AI can flag inconsistencies, cannot guarantee quality | 30, 42, 46 |
| 4. Vague dispatch | Ready → packaging checklist/photo → shipping method → label/reference → tracking ID → Dispatched/In Transit/Delivered; artisan-booked small-order courier and cluster consolidation; coordinate, do not operate logistics | 30, 31, 43, 49 |
| 5. Exception handling | Quality mismatch, unfulfillable quantity, damage, cancellation, incorrect received count, disputed payment → Flag an Issue → manual admin with order/terms/payment/production/fulfillment/evidence; 470 received of 500 example | 31, 42, 47 |
| 6. Inspection | Delivered → buyer inspection → acceptance or issue; configurable window, no universal 48-hour rule | 31, 44, 48 |
| 7. Readiness ambiguity | Internal CraftConnect Ready includes images/description/price/MOQ/capacity/lead time/availability; external channel-specific states remain independent | 13, 14, 41, 50 |
| 8. Unstructured negotiation | Quantity/MOQ/unit price/target date/lead time/customization/delivery/payment/specifications from reviewed voice/chat; 500 available in 40 rather than requested 30 days = Needs negotiation | 24, 27, 28 |
| 9. Repeat business mechanism | Completed → Saved Supplier → Order History → Reorder; hotel returns to Meena after six months, changes 500 baskets to 700, creates new requirement | 16, 32 |
| 10. Bidding distraction | Future optional Artisan-initiated Bulk Clearance; 80 surplus baskets to eligible/pre-verified buyers; no live MVP bidding engine | 33–39, 50 |
| 11. Six actual problems | Digitalization, discovery/capability mismatch, communication/negotiation, transaction risk, fulfillment, ecosystem fragmentation; preserve corresponding AI/workflow solutions | 50 |
| 12. Final combined solution | Artisan AI creation/catalog/verification/pricing + buyer requirement/understanding/matching/selection → AI B2B bridge/voice/translation → structured negotiation → sample/agreement → payment → production/progress → packaging → dispatch/tracking → delivery/inspection → issue/admin when needed → completion → reorder; readiness alongside, bidding later | 15, 45–50 |

## Scope changes and conflict resolution

- Support samples and progress checkpoints, but activate them only when appropriate/agreed for an order. They are not mandatory on every purchase, and “optional” does not mean erase the branch from the baseline.
- The small manual issue queue and explicit saved-supplier/history/reorder mechanism are now baseline features. This supersedes the earlier blanket dispute deferral and cuttable reorder status. Advanced dispute automation, trust/safety scoring, and full operations tooling remain later.
- Preserve four production updates. Checkpoint reviews, shipment tracking, inspection, payment, and issues have separate records; adding In Transit/Delivered does not imply manufacturing ERP.
- Preserve prior payment and settlement safeguards when the new diagram abbreviates acceptance as “Complete.” Inspection acceptance alone cannot settle outstanding milestones or close an unresolved blocking issue.
- The document's reviewer suggestions are not all final requirements: fixed 30/50/20, universal 48 hours, actual escrow, mandatory sampling, guaranteed AI quality, and immediate 3PL integration are not adopted.
- The payment review mentions 30% raw materials / 50% production QC / 20% delivery; its final example instead uses 30% before production / 50% dispatch / 20% after delivery. Preserve both as configurable trigger examples. ₹3,00,000 yields ₹90,000, ₹1,50,000, and ₹60,000. Neither percentage nor event is hardcoded.
- Logistics example retained: fragile ceramic lamps, cushioning, secured inner product, sealed outer box, packaging photo, shipping reference or label through a supported provider. Tracking may be entered manually; live 3PL/label functionality needs actual integration.
- Preserve the same-phone Artisan/Buyer hackathon demo, separate admin web, separate product saving/publishing, dual readiness, and existing proposed direct/hub/demo-representation details. The later PDF does not establish named providers, hubs, tariffs, or a staffed logistics operation.

## Implementation impact

[AGENTS.md](../AGENTS.md) now carries the new invariants. [Implementation plan](IMPLEMENTATION_PLAN.md) includes build steps, acceptance cases, fixtures, and an updated one-device video script. [Project context](PROJECT_CONTEXT.md) explicitly labels these additions as planned. No application code is implemented by this documentation update.

Proposed implementation details beyond the source include sample decision states/waivers, issue statuses/access, inspection expiry handling, and state-transition guards. They are identified as Proposed in the architecture. Exact sample terms, checkpoint timing/holds, inspection duration, provider availability, and operational decisions remain to be agreed during implementation.
