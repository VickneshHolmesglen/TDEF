---
name: Tower System AC Review Findings
description: Third-pass adversarial AC review of tower.md — 27 blocking findings, 12 recommended, 7 missing ACs, methodology issues
type: project
---

Third-pass adversarial AC review of `design/gdd/tower.md` completed 2026-05-01.
Prior reviews: first pass 2026-04-26 (9 blockers), second pass 2026-05-01 (14 blockers + 6 missing ACs).

## Pre-Implementation Gate Status

NOT READY. 27 blocking findings remain open across AC testability, missing ACs, and methodology problems.

## BLOCKING AC Testability Findings (20 on existing ACs)

**AC-1** — "immediately" is not clock-defined. Deferred-dispatch implementation passes the word but violates the intent. Rewrite THEN to specify "within the same call frame."

**AC-2** — Visual "footprint flashes red" clause embedded in BLOCKING Logic AC. Split into separate ADVISORY Visual AC.

**AC-3** — Timing window ("before the first wave begins") not a moment. Rule 12 says same dispatch cycle as `tower_placed`. Unresolved from first review.

**AC-5** — "Same tower type" is undefined. Replace with "a tower with `pre_placement_perk` set to a valid perk type."

**AC-6** — Inventory API undefined. Use 4x `item_added` event proxy (but note `item_added` payload lacks `damaged: bool` field — separate gap).

**AC-13** — Two independent scenarios (30° cone and 90° cone) in a single AC. Must be split.

**AC-15** — ADVISORY classification tests a functional EventBus payload contract (`tower_damaged.max_hp`). Reclassify BLOCKING; test `max_hp` field value, not HUD display.

**AC-17** — GUT hook `var _test_current_hp` violates Rule 25. GDScript has no access modifiers; this ships in production. Add `tower_hp_reset` to EventBus instead. See Part 3 in review.

**AC-20** — Same inventory API gap as AC-6; additionally `item_added` payload lacks `damaged: bool` field.

**AC-24** — "Perk not stacked" clause depends on OQ-4 (deferred). Remove from gate criteria until OQ-4 resolves.

**AC-25** — "No components returned" has no event proxy. Rewrite: zero `item_added` events during rejection window, footprint cells still OCCUPIED.

**AC-27** — `eventbus_batch_threshold` not in entities.yaml or EventBus GDD. "Per frame" has no headless-test analog. Two-part fix: (a) register constant, (b) specify GUT EventBus instrumentation with fixed delta.

**AC-30** — "Evaluate targeting simultaneously" contradicts Rule 17a stagger. Fixture cannot be constructed as written. Use unit-isolation fixture with stagger disabled.

**AC-31** — Real `_process()` delta is non-deterministic in GUT headless. Test must inject fixed delta.

**AC-34** — Boss attack not guaranteed in wave N+1 fixture. AC passes vacuously if no boss fires. Add boss attack to preconditions.

**AC-35** — Non-contiguous IDs (0, 5, 12) require fixture explanation of how 5 and 12 ended up in cache with 0 alive.

**AC-36** — RANDOM mode: (a) `randi()` with `randomize()` is not seedable without injectable RNG (not specified in GDD), (b) [10,30] out of 100 is ±50% tolerance — too loose for bias detection, (c) 100 samples insufficient. Need injectable `RandomNumberGenerator`, 1000 samples, ±25% bounds.

**AC-38** — `_monster_cache.has()` is not a public API. Replace with behavioral observable: absence of `tower_attacked` emitting the breached entity_id.

**AC-39** — `damaged` flag save/load: `item_added` payload lacks `damaged: bool`; Inventory System GDD not authored. Blocked pending those prerequisites.

**AC-40** — GIVEN clause describes a race condition, not a deterministic fixture. Rewrite: inject stale event after Tower System processes `wave_completed`.

**Ordering dependency (BLOCKER):** AC-19 depends on AC-18. If formula test fails, deduction test is invalid. Must sequence in test suite.

## MISSING ACs (7 required — all BLOCKING)

**Perk transfer (Rule 13):** Same-archetype same-Intermission transfer sets `perk_active=true` on replacement, `pre_placement_perk_activated` does NOT fire. Counter-case: archetype mismatch forfeits perk.

**`tower_wave_summary` payload accuracy (Rule 23):** After wave, event fires per tower with correct `shots_fired`, `damage_dealt`, `idle_ticks` matching observed attack events.

**HP reset silence (Rule 23):** After `wave_completed`, no `tower_hp_reset` event fires. GUT signal monitor confirms zero emissions.

**AURA_EXTEND perk formula:** Support tower with `perk_power=0.25` and base `aura_radius_cells=3` gains +2 cells; `tower_aura_pulse` fires with `aura_radius_cells=5`.

**AURA_EXTEND at minimum perk_power:** `perk_power=0.05` yields `round(0.3)=0` cells — effective radius unchanged. No error.

**DAMAGE_BOOST perk formula:** Physical tower with `perk_power=0.25` produces 875.0 damage over 10 seconds (base 700 × 1.25).

**RANGE_BOOST at minimum perk_power:** `perk_power=0.05` yields `round(0.4)=0` cells — effective range unchanged. No error.

## RECOMMENDED Findings (12 total)

- AC-9/10: "immortal target" precondition missing; specify fixed-HP mock target
- AC-19: Resource Economy balance API undefined — need event proxy or API spec
- AC-23: "without error" clause untestable — rephrase as "no error logged to debug console"
- AC-28: "blocked cursor" visual clause in BLOCKING AC — split to ADVISORY
- AC-27: "per frame" methodology — specify manual `_process(0.016)` calls in GUT
- MISSING RECOMMENDED: `archetype_cost_factor=0.0` load-time rejection AC
- MISSING RECOMMENDED: HUD HP fallback for towers with no boss damage (ADVISORY)
- Ordering: AC-9/10 depend on AC-7/8; AC-24 depends on AC-3; AC-34 depends on AC-17; AC-39 depends on AC-20

## Prerequisites Before Implementation Sprint

1. Rewrite AC-1, 2, 3, 5, 6, 13, 15, 20, 24, 25, 27, 30, 31, 34, 35, 36, 38, 39, 40
2. Remove `var _test_current_hp` from AC-17; add `tower_hp_reset` to EventBus GDD
3. Register `eventbus_batch_threshold` in entities.yaml and EventBus GDD
4. Add 7 missing ACs to tower.md
5. Specify injectable `RandomNumberGenerator` for RANDOM targeting mode in GDD
6. Extend `item_added` EventBus payload with `damaged: bool` (or wait for Inventory GDD)
7. Sequence-order AC-18→19, AC-7→9, AC-8→10, AC-3→24, AC-17→34, AC-20→39 in test plan

**Why:** Pre-implementation gate. All BLOCKING ACs must be independently testable before the Tower System sprint begins. 27 blockers means the current AC set cannot be assigned to a QA tester with confidence.

**How to apply:** Before approving Tower System for implementation sprint planning, require GDD author to resolve all 27 blocking findings and add the 7 missing ACs. Do not begin implementation with ACs that depend on undefined APIs, have no observable proxies, or require non-production test hooks.
