# Story 010: Drop Table Schema & Registry Lookup

> **Epic**: Epic 03 — Core Economy
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/resource-economy.md`
**Requirement**: `TR-econ-???` *(no TR-ID exists yet)*

**ADR Governing Implementation**: ADR-0017 (Resource Economy Drop Resolution)
**ADR Decision Summary**: `DropTableResource`/`DropEntry` are Resource subclasses loaded via `GameDataRegistry` at boot, each implementing `validate() -> Array[String]` per ADR-0009's `resource_validation` contract — the exact schema specified in ADR-0017's Key Interfaces. Rejected folding drop data into `MonsterResource` directly (breaks content reuse across monster types sharing a table).

**Engine**: Godot 4.6.2 / GDScript | **Risk**: LOW, confirmed by godot-specialist validation during ADR authoring — matches ADR-0016's already-validated Resource-subclass pattern
**Engine Notes**: `class_name X extends Resource`, `@export`, `StringName` literals all confirmed idiomatic for 4.6.2.

**Control Manifest Rules (this layer)**:
- Required (Global Rules): gameplay values must be data-driven — this story IS the data-driven foundation for the whole epic's drop system
- Required (Global Rules): no hardcoded gameplay constants in GDScript

---

## Acceptance Criteria

*From GDD `design/gdd/resource-economy.md`, scoped to this story:*

- [x] **AC-05**: GIVEN a `DropTableResource` registered under `"goblin_basic"` with two `DropEntry` children, WHEN `monster_died` cites that id, THEN exactly those two entries' materials resolve, sourced from `GameDataRegistry`, never a hardcoded table.
- [x] **AC-13**: GIVEN an unregistered `drop_table_id` triggers twice in one session, WHEN both occur, THEN exactly one warning logs and both resolve as no-drop.

---

## Implementation Notes

*Derived from ADR-0017:* Schema per the GDD's Core Rule 4:
```
DropTableResource: drop_table_id: StringName, entries: Array[DropEntry], guaranteed_min_quantity: int
DropEntry: material_id: StringName, base_quantity: int, base_quality_probability: float, is_rare: bool
```
`monster_died.drop_table_id` resolves through `GameDataRegistry.get_drop_table(id)` — a missing table is a load-time validation error for genuinely malformed content, but an *unregistered ID encountered at runtime* (this story's AC-13) is a runtime warning-then-no-drop path, not a hard crash. These are two different failure modes; do not conflate them.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: the quantity math that consumes `DropEntry.base_quantity`
- Story 009: the quality math that consumes `DropEntry.base_quality_probability`
- Story 011: despawn suppression (this story only covers table lookup, not when lookup is skipped entirely)

---

## QA Test Cases

- **AC-05**: Data-driven table resolution
  - Given: a `DropTableResource` registered under `"goblin_basic"` with two `DropEntry` children
  - When: `monster_died` cites `drop_table_id="goblin_basic"`
  - Then: exactly those two entries resolve, sourced from `GameDataRegistry` — no hardcoded fallback table exists anywhere in the resolution path
  - Edge cases: a `DropTableResource` with zero `DropEntry` children must resolve as a valid no-drop table, not an error (per Edge Cases in the GDD)

- **AC-13**: Unregistered drop_table_id handling
  - Given: an unregistered `drop_table_id` value triggers via `monster_died` twice within the same session
  - When: both occurrences happen
  - Then: exactly one content-data warning logs (not two), and both resolve as no-drop
  - Edge cases: confirm the warning dedup key is the `drop_table_id` string itself — two *different* unregistered IDs must each produce their own warning, not be suppressed by the first one logged

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/resource_economy/drop_table_schema_registry_test.gd` — must exist and pass

**Status**: [x] Created — 17/17 passing (750/750 full project suite, live-verified, Godot 4.6.2.stable headless)

---

## Dependencies

- Depends on: None (this is the foundational story for the Resource Economy portion of this epic)
- Unlocks: Story 008, Story 009, Story 012

---

## Completion Notes

**Completed**: 2026-07-16
**Criteria**: 2/2 passing (AC-05, AC-13)
**Deviations**: Advisory only
- No test proves heterogeneous-batch (two different `drop_table_id`s in one call) resolves independently — logged as tech debt.
**Test Evidence**: Logic — `tests/unit/resource_economy/drop_table_schema_registry_test.gd`, 17/17 passing
**Code Review**: Complete — verdict APPROVED WITH SUGGESTIONS (`/code-review`, 2026-07-16; GDScript specialist agent hit an external session-limit error mid-review, substituted with orchestrator's own direct file verification)
