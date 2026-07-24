# Story 004: Discovery Ledger Persistence

> **Epic**: Epic 06 — Mission Combat Extensions
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/constellation.md`
**Requirement**: `TR-const-002`

**ADR Governing Implementation**: ADR-0022 (Constellation Pattern-Detection Data Structure)
**ADR Decision Summary**: The Discovery Ledger is a separate, save-persisted `Dictionary[String, bool]` keyed by `shape_id` (not `pattern_id` — discovery is per-shape, not per-instance). It implements `SaveRestorer` (ADR-0003) at `restore_order=24`, already assigned in `save-persistence.md`.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: `Dictionary[String, bool]` is already primitive-only, satisfying ADR-0003's save-data constraint with zero conversion work.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0003/ADR-0022 directly.
- Forbidden: Never re-fire `constellation_rune_discovered` for an already-`DISCOVERED` `shape_id`, even across break/reform cycles at the same or a different anchor.
- Guardrail: **Project-wide SavePersistence gap** — Constellation is a `MissionScene` child (destroyed/recreated every mission); whether `SavePersistence` correctly re-applies already-loaded save data to a system that re-registers mid-session is unconfirmed (ADR-0029's Risks section, flagged project-wide). Do not mark this story's persistence behavior fully verified until that gap is resolved or explicitly worked around — see Known Blockers in `EPIC.md`.

---

## Acceptance Criteria

*From GDD `design/gdd/constellation.md`, scoped to this story:*

- [x] AC-14 — First-ever activation of a shape_id fires both `constellation_activated` and `constellation_rune_discovered`
- [x] AC-15 — Re-forming the same shape at a different anchor does not re-fire discovery
- [x] AC-16 — Breaking and reforming the identical instance does not re-fire discovery

---

## Implementation Notes

*Derived from ADR-0022 Implementation Guidelines:*

```gdscript
func get_save_key() -> String: return "constellation"
func get_save_data() -> Dictionary: return {"discovery_ledger": _discovery_ledger}
func restore_save_data(data: Dictionary) -> bool: ...
func reset_to_defaults() -> void: _discovery_ledger.clear()
```

- On first-ever `ACTIVE` transition of any instance of a given `shape_id` in the current playthrough, fire `constellation_rune_discovered(rune_id, pattern_id)` in addition to `constellation_activated`, and set `_discovery_ledger[shape_id] = true`.
- `DISCOVERED` is terminal — never reverts, even if all instances of the shape later break.
- Register with `SavePersistence.register(self, restore_order=24)` per `save-persistence.md`'s already-assigned slot.
- Active-instance table and reverse index are **not** persisted — they are mission-scoped and rebuild from Grid/Tower state each mission. Only the Discovery Ledger crosses save/load.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001–003: the activation/deactivation mechanics that trigger discovery checks
- Project-wide SavePersistence mid-session-restore fix (tracked as a cross-epic blocker, not owned by this story)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-14**: First-ever activation fires both events
  - Given: fresh playthrough state, Discovery Ledger has no entry for `triad_line`
  - When: a `triad_line` instance first transitions to `ACTIVE` at anchor `(2,4)`
  - Then: both `constellation_activated("triad_line@(2,4)", ...)` and `constellation_rune_discovered(rune_id, "triad_line@(2,4)")` emit

- **AC-15**: Different anchor does not re-fire discovery
  - Given: Discovery Ledger already has `triad_line = DISCOVERED` (from a prior activation at a different anchor, now broken)
  - When: a new, distinct `triad_line` instance activates at anchor `(9,9)`
  - Then: `constellation_activated("triad_line@(9,9)", ...)` emits but `constellation_rune_discovered` does not

- **AC-16**: Break-and-reform identical instance does not re-fire discovery
  - Given: Discovery Ledger already has `triad_line = DISCOVERED`, and `triad_line@(2,4)` is currently `INACTIVE` after breaking
  - When: the same 3 cells are re-occupied and the instance re-activates at the same anchor `(2,4)`
  - Then: `constellation_activated("triad_line@(2,4)", ...)` emits again (bonus reapplies) but `constellation_rune_discovered` does not
  - Edge cases: also verify `get_save_data()`/`restore_save_data()` round-trip the ledger correctly across a simulated save/load cycle at `restore_order=24`

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/constellation/discovery-ledger-persistence_test.gd` — 9 tests covering AC-14/15/16, `RESTORE_ORDER == 24`, a full save/load round-trip, malformed-payload rejection, primitive-only serialization, `reset_to_defaults()`, and discovery permanence after a shape fully breaks. All passing.

**Status**: [x] Created and passing (2026-07-19). Full project regression re-run: 1108/1109 (the sole failure is the same pre-existing, unrelated Menagerie `CreatureInstance.CreatureState` enum-value mismatch, `TD-menag-006` — untouched by this story).

---

## Dependencies

- Depends on: Story 002 (DONE) — discovery checks piggyback on activation
- Unlocks: Encyclopedia/Equipment Forge downstream consumption of `constellation_rune_discovered` (Epic 08)

**Unblocked**: ADR-0022 accepted 2026-07-18 (Sprint 6, S6-02). The project-wide SavePersistence mid-session-restore gap this story was also flagged against is resolved (ADR-0003's 2026-07-18 revision).

**Implemented (2026-07-19, Sprint 7)**: found on inspection that this story's production code was already fully built as part of Stories 001-003's own implementation pass (S6-08) — `constellation.gd` already had `_discovery_ledger`, the full `SaveRestorer` interface at `RESTORE_ORDER = 24`, and `_activate_instance()` already fired `constellation_rune_discovered` exactly once per shape_id (gated on `_discovery_ledger.get(shape_id, false)`, set before the emit). Only the test file itself was missing (`Test Evidence: Not yet created`). Wrote `tests/integration/constellation/discovery-ledger-persistence_test.gd` (9 tests) to close that gap — no production code changes were needed. Live-verified via gdUnit4: 9/9 new tests passing; full regression 1108/1109 (same pre-existing unrelated `TD-menag-006` failure).
