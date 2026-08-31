# Hero Skill Tree — Review Log

## Review — 2026-08-31 — Verdict: MAJOR REVISION NEEDED
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director (senior synthesis)
Blocking items: 3 | Recommended: 7
Summary: First-pass review of a brand-new GDD. Two of the three blocking items were the same defect seen from two angles — Formula 1's one-time-per-signature point grant capped lifetime income per archetype at 2 points while the chain cost 4, making `Skill_2` in every archetype permanently unreachable (economy-designer's income-ceiling finding and qa-lead's Formula-2 out-of-bounds-index finding were confirmed by creative-director to be the same root cause). The third blocking item was a vision mismatch: the Player Fantasy promised "the specific order you decided," but the fixed linear chain (one legal purchase at a time, identical for every player) delivers no real order-of-operations choice at all.
Prior verdict resolved: First review.

## Revision — 2026-08-31 — same day
User chose "revise now." Two design decisions needed the user's call (grouped into one AskUserQuestion round per the skill's process); the save/restore-ordering blocker was resolved directly as a technical call, no design decision required.

| # | Blocking item | Fix applied |
|---|---|---|
| 1 | Point income ceiling (2) < chain cost (4) — `Skill_2` permanently unreachable | User chose "repeating threshold" — reused `tower-mastery.md` Rule 14's existing mastery-continues-past-100% hook (already built for exactly this purpose). Formula 1 rewritten from a one-time `point_granted[build_signature]` boolean to `points_granted_count[build_signature]: int`, granting a new point at every whole multiple of `mastery_threshold_seconds` crossed, not just the first. |
| 2 | No `restore_order` assigned; sits on save-persistence.md's pre-existing unresolved Tower-Mastery/Hero-Skill-Build ordering question | Resolved without a design decision: this system's own persisted state (4 point-pool ints, 8 node-unlocked bools) is fully self-contained at restore time — cross-system reads only happen live, never during restore — so it inherits no strict ordering dependency. Proposed `restore_order = 37` (next free Advanced-layer slot). The pre-existing Tower Mastery/Hero Skill Build question is explicitly left open, unaffected. |
| 3 | Linear chain doesn't deliver the "order you decided" Player Fantasy promise | User chose to rewrite the Player Fantasy honestly rather than add branching. Rewritten around the real decision the structure delivers: which of the player's 4 unevenly-earned archetype pools to advance first (cross-archetype allocation), not within-chain node order. |

7 non-blocking findings also addressed inline in the same pass: Formula 2 gained an explicit `all_nodes_unlocked` guard (the qa-lead/economy-designer shared root cause, now also structurally impossible to hit as an out-of-bounds index even independent of the income fix); a migration note for Tower Mastery's retired `_unlocked_skills` dict; a Dependencies line flagging `event-bus.md`'s existing `skill_unlocked` entry as stale, not just needing new events added; 3 new Acceptance Criteria (AC-9 fully-unlocked-chain rejection, AC-10 `-1` sentinel consumer tolerance, AC-11 explicit land-together gate against `tower-mastery.md`); an explicit save/load atomicity Edge Case; a functional (non-visual) Sanctuary UI requirement to expose chain position at a glance; and Group 4's Minor-node content deferral reframed as load-bearing (must be authored before implementation, not a trailing pass).

Not yet re-reviewed.

## Review — 2026-08-31 — Verdict: NEEDS REVISION (re-review, same day)
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director (senior synthesis)
Blocking items: 2 confirmed blocking + 2 near-blocking AC gaps (elevated by creative-director) | Recommended: 4 | Nice-to-have: 4
Summary: The two originally-blocking items from the first review (income ceiling, out-of-bounds index) were confirmed genuinely closed by systems-designer. New issues found: Formula 1 had no stopping condition once an archetype's chain fully unlocks (economy-designer, an unbounded points/notification faucet with no sink) and referenced an undefined `catalogue[build_signature].archetype` schema field (systems-designer, elevated to blocking by creative-director). qa-lead found AC-11 asserted an untestable cross-document fact and flagged a missing save-migration AC. game-designer called the Player Fantasy's "which archetype to advance first" promise structurally broken (spend order doesn't change eventual outcome since points are uncapped/non-fungible) — creative-director partially disagreed, reframing this as a prose overclaim (the real, defensible decision is tempo/sequencing, not sacrifice) rather than a structural defect, and downgraded it from blocking to recommended.
Prior verdict resolved: Yes — the first review's 3 blockers stayed closed through this pass; this pass surfaced different issues in the revision itself.

## Revision — 2026-08-31 — same day
User chose "revise now." Two design decisions needed the user's call, grouped into one AskUserQuestion round: (1) how Formula 1 should behave once a chain is maxed — user chose "stop granting entirely once maxed"; (2) whether the ~2x pacing slowdown from Minor nodes riding the same threshold currency was intended — user chose "yes, ratify it as intended."

| # | Item | Fix applied |
|---|---|---|
| 1 | Formula 1 — no stopping condition once a chain maxes out | Added an explicit `all_nodes_unlocked` guard before and inside the grant loop; a maxed archetype stops earning points/emitting `skill_tree_point_earned`, though `mastery_time` tracking continues unaffected for HUD display |
| 2 | Formula 1 referenced undefined `catalogue[build_signature].archetype` field | Replaced with `archetype_of(build_signature)`, deriving archetype from the Foundation component per `tower-mastery.md` Rule 4/`tower.md` Rule 5, matching how the rest of the system already does it |
| 3 | AC-11 asserted an untestable fact about `tower-mastery.md`'s own codebase | Rescoped to this system's own single `skill_unlocked` emission site; the cross-document dead-code claim explicitly left for `tower-mastery.md`'s own Acceptance Criteria |
| 4 | No AC for the pre-revision-save migration risk | Added AC-12 |
| 5 | Formula 1's multi-write grant loop had no atomicity guarantee | Added a matching Edge Case, mirroring Formula 2's existing one |
| 6 | ~2x pacing slowdown never explicitly ratified | Confirmed intentional in Tuning Knobs, no retuning applied |
| 7 | Player Fantasy overclaimed sacrifice/allocation | Reframed the closing beat around tempo ("which path pays off soonest") |

User then chose "accept revisions and mark Approved" without a further re-review pass — `hero-skill-tree.md`'s Status header and `systems-index.md` updated to Approved accordingly.

## Confirmation Re-review — 2026-08-31 — Verdict: APPROVED (confirmed clean)
Scope signal: L (unchanged)
Specialists: none — lean/solo confirmation pass, matching this project's established convention for re-reviews with no new design surface (companion-document landing only, since the last full pass)
Summary: User requested a follow-up `/design-review` after the `tower-mastery.md`/`event-bus.md` companion revisions landed, to confirm cross-document cleanliness. Found and fixed 4 documentation-drift items, no design-logic issues: (1) this GDD's Dependencies section still described the EventBus and Save & Persistence gaps as open, though both had already been resolved earlier in the same session — updated to RESOLVED; (2) `restore_order = 37` had been proposed in this GDD but never actually landed in `save-persistence.md`'s two authoritative tables (the same "proposed but never added" drift pattern this project has caught for Crafting/Building Upgrade/Tower Assembly) — added, with `save-persistence.md`'s system count corrected 15→16 in 3 places; (3) `hero-skill-build.md`'s `mastery_source_build_signature` field found to be vestigial at runtime under the new archetype-pool model (mirroring the equivalent flag already added to `tower-mastery.md` Rule 7) — flagged in both documents; (4) the Notes section's "is written to be land-together" language updated to reflect that the companion revision has actually landed.
Prior verdict resolved: Yes — no regression from the prior Approved state; all fixes this pass were staleness corrections between documents, not changes to this GDD's own mechanics.
