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
