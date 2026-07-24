# Story 013: Gold Track & Scout Starting Grant

> **Epic**: Epic 03 — Core Economy
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/resource-economy.md`
**Requirement**: `TR-econ-003` (registered 2026-07-13, `/architecture-review`)

**ADR Governing Implementation**: ADR-0017 (Resource Economy Drop Resolution) — covers Resource Economy's node architecture and the gold-emission side. **ADR-0018 (Mission Economy — Runtime Gold Balance Ownership)** — resolves the previously-open gold-balance-ownership question.
**ADR Decision Summary**: **UNBLOCKED (2026-07-13).** ADR-0017 confirms Resource Economy emits gold deltas via the existing `resources_changed(gold, source)` signal. ADR-0018 adds a new Autoload, `MissionEconomy` (boot position 8), which subscribes to `resources_changed` and accumulates `_gold_balance: int`, resets it to 0 on `mission_launched`, and exposes `get_gold_balance() -> int` / `can_afford(cost: int) -> bool` as a direct-call read API (no `SaveRestorer` — gold is ephemeral per-mission state, same category as other unsaved mission-runtime scalars per `save-persistence.md`). This story can now be implemented and tested end-to-end, not just for emission.

**Engine**: Godot 4.6.2 / GDScript | **Risk**: LOW
**Engine Notes**: `resources_changed(gold: int, source: StringName)` already exists in shipped `event_bus.gd` code (confirmed via grep during GDD authoring) but is undocumented in `event-bus.md`'s formal catalogue — a small housekeeping fix still needed alongside implementation. `mission_launched` is an existing, shipped signal — no new EventBus additions required for ADR-0018 itself.

**Control Manifest Rules (this layer)**:
- Required (Global Rules): events with 1-4 fields use typed parameters directly on signal — `resources_changed(gold: int, source: StringName)` already fits this pattern in shipped code
- Required (ADR-0018): `MissionEconomy` mutates `_gold_balance` only via its `resources_changed` subscription — no external write path; other systems read only via `get_gold_balance()`/`can_afford()`

---

## Acceptance Criteria

*From GDD `design/gdd/resource-economy.md`, scoped to this story:*

- [x] **AC-09**: GIVEN any gold delta, WHEN emitted, THEN it fires only as `resources_changed`, never `materials_earned`/`materials_spent`.
- [x] **AC-10**: GIVEN `mission_phase_changed(new_phase="SCOUT")`, WHEN handled, THEN `resources_changed(150, "mission_start_grant")` fires exactly once, before the phase timer starts.
- [x] **AC-11** *(new — ADR-0018)*: GIVEN `mission_launched` fires, WHEN `MissionEconomy` handles it, THEN `get_gold_balance()` returns `0` immediately, even mid-session (a second mission in the same run resets cleanly).
- [x] **AC-12** *(new — ADR-0018)*: GIVEN the AC-10 Scout grant has fired followed by a `resources_changed(-30, "tower_placement")` delta, WHEN both are processed, THEN `get_gold_balance() == 120`.
- [x] **AC-13** *(new — ADR-0018)*: GIVEN `can_afford(cost)` is called with `cost == get_gold_balance()` exactly, THEN it returns `true` (boundary case, not strictly less-than).

**Testability gap closed (2026-07-13)**: AC-09/AC-10 previously could only be tested for *emission*, not end-to-end balance correctness, because no system owned the actual gold balance. ADR-0018's `MissionEconomy` closes this — AC-11 through AC-13 now test the balance side directly.

---

## Implementation Notes

**Correction (2026-07-16, `/story-readiness`)**: this section previously claimed Resource Economy "already emits `resources_changed(150, 'mission_start_grant')` on `mission_phase_changed` to SCOUT" and required no changes. Verified false via direct grep of `resource_economy.gd` — the file has zero `mission_phase_changed` or `resources_changed` references; only a doc-comment placeholder noting this as future Story 013 work. **This story must implement the SCOUT grant emission in `ResourceEconomy`, not just verify it.** Also, `resources_changed` is already catalogued in `event-bus.md` (added 2026-07-13, closing ADR-0017/ADR-0018's documentation gap) — the "housekeeping fix still needed" note below is stale; no action needed there.

Implement `MissionEconomy` per ADR-0018: a new Autoload (`src/core/mission_economy.gd`, boot position 8, after `WaveManager` — confirmed correct, 7 autoloads currently registered). It subscribes to `EventBus.resources_changed` (accumulate `_gold_balance += gold`) and `EventBus.mission_launched` (reset `_gold_balance = 0`) in `_ready()`, disconnects both in `_exit_tree()`, and exposes `get_gold_balance() -> int` and `can_afford(cost: int) -> bool` as direct-call reads — no `SaveRestorer` registration.

Additionally implement in `ResourceEconomy`: subscribe to `mission_phase_changed`, and when `new_phase == "SCOUT"`, emit `resources_changed(150, "mission_start_grant")` exactly once, before the phase timer starts (AC-10) — do not double-grant on a second SCOUT entry within the same mission (e.g. mission restart after defeat is a new `ResourceEconomy` node instance per its mission-scoped lifecycle, so this should hold naturally, but verify with a test per the QA Test Cases' flagged edge case). Remember to update Project Settings → Autoloads to add `MissionEconomy` at position 8.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Materials-side economy (Stories 008-012) — this story is gold-only
- Tower System's consumption of gold for placement (Tower System is Complete per Epic 02 — any changes there are out of this epic's scope) — **exception found and fixed during code review, see Completion Notes: TowerSystem's existing `resources_changed` usage violated the delta-payload contract and corrupted `MissionEconomy`, a live bug not a scope choice, approved by the user to fix immediately rather than defer.**

---

## QA Test Cases

- **AC-09**: Gold track separation
  - Given: any gold delta occurs (Scout grant, future kill-based gold, etc.)
  - When: it's emitted
  - Then: it fires exclusively as `resources_changed` — never through `materials_earned`/`materials_spent`
  - Edge cases: this is a structural/architectural test — verify by code inspection or a signal-connection audit that no gold-related code path emits the materials signals

- **AC-10**: Scout Phase starting gold grant
  - Given: `mission_phase_changed` fires with `new_phase="SCOUT"`
  - When: this is handled
  - Then: `resources_changed(150, "mission_start_grant")` fires exactly once, before the Scout Phase timer starts
  - Edge cases: confirm this does NOT re-fire if `mission_phase_changed` to SCOUT happens again later (e.g., mission restart after defeat) in a way that would double-grant — clarify this edge case explicitly if the GDD doesn't already (it does not appear to; flag as a follow-up question)

- **AC-11**: `MissionEconomy` resets on `mission_launched`
  - Given: any non-zero `_gold_balance` (e.g. from a prior mission in the same session)
  - When: `mission_launched` fires
  - Then: `get_gold_balance()` returns `0` immediately
  - Edge cases: verify this holds on a *second* mission launched in the same play session, not just cold boot

- **AC-12**: Balance accumulates across sequential deltas
  - Given: `resources_changed(150, "mission_start_grant")` then `resources_changed(-30, "tower_placement")`
  - When: both are processed in order
  - Then: `get_gold_balance() == 120`
  - Edge cases: a delta that would drive the balance negative is applied as-is (no silent clamping) — `can_afford()` must correctly return `false` for any positive cost afterward

- **AC-13**: `can_afford()` boundary
  - Given: `get_gold_balance() == N`
  - When: `can_afford(N)` is called (cost exactly equal to balance)
  - Then: returns `true` — not strictly less-than

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/resource_economy/gold_track_scout_grant_test.gd` — must exist and pass (AC-09/AC-10, emission side)
- `tests/integration/core/mission_economy_test.gd` — must exist and pass (AC-11/AC-12/AC-13, balance-tracking side per ADR-0018)

**Status**: [x] Created and passing — `gold_track_scout_grant_test.gd` (5 tests), `mission_economy_test.gd` (8 tests). Additionally, `tests/unit/tower/tower_placement_test.gd`/`tower_combat_test.gd` (Epic 02, pre-existing) were updated during the TowerSystem bug fix.

---

## Dependencies

- Depends on: ADR-0017 (Accepted), ADR-0018 (Accepted 2026-07-13 — gold-balance ownership resolved via new `MissionEconomy` Autoload)
- Unlocks: None currently identified

---

## Completion Notes

**Completed**: 2026-07-16
**Criteria**: 5/5 passing (AC-09 through AC-13)
**Deviations**: Implementation Notes' claim that Resource Economy "already emits" the SCOUT grant was false — corrected before implementation (see Implementation Notes' Correction note).
**Test Evidence**: Integration — `tests/integration/resource_economy/gold_track_scout_grant_test.gd` (5 tests) and `tests/integration/core/mission_economy_test.gd` (8 tests), all passing. Full project suite: 811/811 passing, 0 errors, 0 failures, 65/65 suites — no regression.
**Code Review**: Complete — APPROVED (godot-gdscript-specialist: BLOCKING → resolved; qa-tester: GAPS → resolved).
**Notes**: Code review found a real, live cross-epic bug, independently confirmed by both review agents: `src/core/tower/tower_system.gd` (Epic 02, already shipped/Complete) violated the frozen `resources_changed` delta-payload contract (`event-bus.md`, catalogued 2026-07-13) — it self-tracked its own `_player_gold` as an absolute balance and re-emitted its full running balance as the payload on every tower placement/sale, which would silently corrupt `MissionEconomy`'s balance the moment both systems were exercised together in a real mission. This was outside this story's stated Out of Scope boundary, so the user was asked and explicitly approved fixing it immediately rather than deferring: `TowerSystem`'s local gold cache was removed entirely, Gate 2 now reads `GMissionEconomy.can_afford()` live, and its emissions send signed deltas. Two pre-existing Epic 02 test files (`tower_placement_test.gd`, `tower_combat_test.gd`) and one mission-scene debug stopgap (`the_gap.gd`) were updated accordingly. ADR-0008's own pre-existing open-follow-up note (dated 2026-07-13, which had already flagged this exact risk) was closed. Logged as **TD-econ-008** (resolved) in `docs/tech-debt-register.md` for full audit trail.

**This is the final story in Epic 03 — all 15 of 15 stories are now Complete.**
