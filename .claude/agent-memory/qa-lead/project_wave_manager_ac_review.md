---
name: project-wave-manager-ac-review
description: Wave Manager AC testability audit — 5 review passes total; re-review #5 (2026-05-20): 6 blockers remain, 10 recommended findings, 2 advisory. Document is NOT APPROVED.
metadata:
  type: project
---

Wave Manager GDD AC audit history: 5 review passes total. Latest: re-review #5, 2026-05-20.

**Why:** This is the fifth pass. The prior 9 blockers were largely resolved (7 of 9 fixed). 6 new/residual blockers found in re-review #5.

**How to apply:** These findings must be resolved before the Wave Manager GDD can be marked APPROVED and before any Logic-type implementation stories can be closed.

## Current Status: NOT APPROVED — 6 BLOCKERS

| ID | AC | Issue |
|----|-----|-------|
| B-1 | AC-5 | "followed by... in the same frame" — does not specify strict-order vs. co-tick assertion |
| B-2 | AC-8 | "enqueued for the same _process frame" undefined in GDScript synchronous dispatch; harness pattern unspecified |
| B-3 | AC-14 | No test specification; negative cases (either condition alone) untested |
| B-4 | AC-15 | No test specification; spawn-entries-not-fired has no bounded observation window |
| B-5 | AC-16 | No test specification; DEFEAT negative assertion untested |
| B-6 | Missing | Rule 22 (templates_ready gate) has NO AC — Logic requirement with zero coverage; need AC-31 |

## Recommended Findings (10)

R-1: AC-5 — wave_difficulty:1.00 duplicates AC-17 scope
R-2: AC-9 — zero vs ±1-frame tolerance conflated for 0.0 pre_delay case
R-3: AC-13 — _all_spawns_fired internal state reference in precondition
R-4: AC-19 — error log assertion method missing; no observation window for "no spawn events"
R-5: AC-20 — timer-stop behavior not tested, only field resets
R-6: AC-23 — no fixture spec, N unbound, Monster System test double contract missing
R-7: AC-27 — monster_id aggregation behavior untested; _wave_index internal reference
R-8: AC-29 — standard wave-clear path 3-event ordering not covered (only boss_died path)
R-9: Missing AC-30 — no AC for is_penultimate_wave correctness across all wave indices
R-10: Rule 17 — no AC for fire-and-forget abort on unknown monster_id

## Advisory Findings (2)

A-1: AC-19b — still in AC section despite "separate story" label — should be cross-reference only
A-2: wave_reward_scalar Monster System behavioral constraint has no AC in either GDD

## History

- Review #1: 8 blockers resolved (initial pass)
- Review #2: 2 blockers resolved
- Review #3 (2026-05-19): 9 blockers, 4 recommended — observable-output rewrite pass
- Review #4: 12 blockers resolved per document header claim
- Review #5 (2026-05-20): 7 of prior 9 blockers verified fixed; 6 new/residual blockers found
