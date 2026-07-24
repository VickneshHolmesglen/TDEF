# Story 011: Despawn Drop Suppression

> **Epic**: Epic 03 — Core Economy
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/resource-economy.md`
**Requirement**: `TR-econ-???` *(no TR-ID exists yet)*

**ADR Governing Implementation**: ADR-0017 (Resource Economy Drop Resolution)
**ADR Decision Summary**: Resource Economy's mission-scoped node subscribes to `monster_died`/`monsters_died_batch` only. **Corrected 2026-07-16 (verified via direct source read of `monster_manager.gd` during Story 008's code review, confirmed again here)**: this "despawns never fire either signal" premise is only true for AC-06 (BOSS breach emits the distinct `monster_breached` signal, never `monster_died` — confirmed at `monster_manager.gd:227`, so AC-06 genuinely requires no new code). It is FALSE for AC-07: `monster_manager.gd:366-368` unconditionally emits `monster_died` with `kill_source="wave_end"` for force-cleared monsters at wave end. AC-07 therefore requires real `kill_source == "wave_end"` filtering logic inside `ResourceEconomy` itself (not a change to Monster System, which stays out of scope) — this was tracked as **TD-econ-002** (logged during Story 008, flagged as a currently-live GDD violation) and this story is exactly where it gets fixed.

**Engine**: Godot 4.6.2 / GDScript | **Risk**: Unassessed
**Engine Notes**: None yet.

**Control Manifest Rules (this layer)**:
- Required (Global Rules): no direct runtime Node reference — this story only observes `monster_died` (or its absence) via EventBus, never queries Monster System directly

---

## Acceptance Criteria

*From GDD `design/gdd/resource-economy.md`, scoped to this story:*

- [x] **AC-06**: GIVEN a BOSS reaches breach, WHEN despawn occurs, THEN `monster_died` never fires and no material/gold signal emits.
- [x] **AC-07**: GIVEN a monster force-cleared with `kill_source == "wave_end"`, WHEN this occurs, THEN no `monster_died` fires and no drop resolves.

---

## Implementation Notes

*Derived from ADR-0017 + GDD Rule 5, corrected 2026-07-16.* AC-06 (BOSS breach) genuinely closes Wave Manager's OQ-6 by falling out of the event contract naturally — `monster_died` structurally never fires for a breach, so this half needs only a confirming test, not new logic. **AC-07 (wave_end) is different**: `monster_died` DOES fire for force-clears (with `kill_source="wave_end"`), so this half requires real, new filtering logic in `ResourceEconomy._process_drops()` — check `payload.kill_source` and skip all resolution (no table lookup, no Formula 1/2/3 evaluation, no `materials_earned` emission) before doing anything else. This is the actual fix for TD-econ-002.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008/009/010: the normal kill → drop resolution path (this story only covers the two despawn exceptions)
- Any change to Monster System's own despawn implementation (out of this epic's scope entirely — Monster System is Complete per Epic 02)

---

## QA Test Cases

- **AC-06**: BOSS breach suppression
  - Given: a BOSS monster reaches the breach condition
  - When: despawn occurs
  - Then: `monster_died` never fires, and consequently no `materials_earned`/`resources_changed` signal emits from this despawn
  - Edge cases: confirm this holds even if the BOSS's `drop_table_id` references a table with guaranteed non-zero drops — the suppression must happen before any table lookup occurs, not as a zero-quantity result

- **AC-07**: Force-clear (wave_end) suppression
  - Given: a monster is force-cleared with `kill_source == "wave_end"`
  - When: this occurs
  - Then: no `monster_died` fires and no drop resolves
  - Edge cases: verify a normal kill immediately before the force-clear batch still resolves correctly — this story must not accidentally suppress legitimate kills that happen to be processed in the same frame as force-clears

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/resource_economy/despawn_drop_suppression_test.gd` — must exist and pass

**Status**: [x] Created — 4/4 passing (770/770 full project suite, live-verified, Godot 4.6.2.stable headless)

---

## Dependencies

- Depends on: Story 010 (drop table schema — needed to confirm suppression happens before, not after, table lookup)
- Unlocks: None currently identified

---

## Completion Notes

**Completed**: 2026-07-16
**Criteria**: 2/2 passing (AC-06, AC-07)
**Deviations**: Advisory only
- Story's original premise was wrong ("no code needed") — corrected before implementation; AC-07 genuinely required a new guard, closing **TD-econ-002**.
- One non-blocking suggestion (all-wave_end-batch test for defense-in-depth). Logged as tech debt.
**Test Evidence**: Integration — `tests/integration/resource_economy/despawn_drop_suppression_test.gd`, 4/4 passing
**Code Review**: Complete — verdict APPROVED WITH SUGGESTIONS (`/code-review`, 2026-07-16)
