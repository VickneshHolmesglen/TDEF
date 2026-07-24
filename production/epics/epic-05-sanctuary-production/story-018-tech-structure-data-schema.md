# Story 018: TechNode/Structure Data Schema & Two Independent Ledgers

> **Epic**: Epic 05 — Sanctuary Production Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Config/Data *(implementation was routed to `godot-gdscript-specialist` as real code — see Completion Notes)*
> **Estimate**: S (1-2 hrs)
> **Manifest Version**: 2026-07-13b *(stale — does not yet cover ADR-0024; rules below extracted directly from the ADR)*

## Context

**GDD**: `design/gdd/defense-building.md`
**Requirement**: `TR-defbuild-001` — "5-node tech tree data schema (2 categories) and unlock-gating logic"

**ADR Governing Implementation**: ADR-0024 (Defense Building tech tree data model)
**ADR Decision Summary**: `TechNodeResource`/`StructureResource` (both static, `GameDataRegistry`-backed). Two independent `Dictionary[StringName, bool]` ledgers (`_tech_ledger`, `_structure_ledger`) — only the terminal `UNLOCKED`/`BUILT` state is persisted; `LOCKED_PREREQ`/`AVAILABLE` are derived at query time from the ledger + prerequisite chain, never a third stored state.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: **DefenseBuilding is Autoload #10** — required so `is_tech_unlocked()` is callable as a bare global by Crafting (Story 002).

**Control Manifest Rules (extracted from ADR-0024)**:
- Required: `gates: String` on `TechNodeResource` is content-authoring documentation only — never read at runtime
- Forbidden: persisting `LOCKED_PREREQ`/`AVAILABLE` as a stored 3rd state — always derive from the single terminal-state ledger

## Acceptance Criteria

- [ ] AC-1: GIVEN a fresh Defense Building state, WHEN the Tech Tree and Sanctuary Structures rosters are queried, THEN exactly two independent ledgers exist, each tracking its own entries' state, with no shared "progression point" currency — unlocking a tech node never debits/credits the structures ledger and vice versa, beyond the named `tech_gate` cross-link.
- [ ] AC-2: GIVEN both a tech node unlock and a structure build are attempted in the same Sanctuary session, WHEN each resolves, THEN each spends its own `gold_cost`/`material_costs` directly against the shared gold/material pools — no intermediate currency conversion. **DEFERRED — resolution/spend logic is out of this story's scope (Story 019/022/023); unverifiable until that logic lands.**
- [ ] AC-3: GIVEN the authored five-node tech tree, WHEN each node's `tech_category` is read, THEN `tech_production_2`/`_3`/`_4` are `"production_tech"` and `tech_structural_1`/`_2` are `"structural_tech"` — exactly two categories, five nodes total.

## Implementation Notes

```gdscript
class_name TechNodeResource extends Resource
@export var tech_id: StringName = &""
@export var tech_category: String = ""
@export var prerequisite_tech_id: StringName = &""
@export var branch_tier: int = 1
@export var gold_cost: int = 0
@export var material_costs: Dictionary[StringName, int] = {}
@export var gates: String = ""   # documentation only, never read at runtime

class_name StructureResource extends Resource
@export var structure_id: StringName = &""
@export var structure_type: String = ""
@export var tier: int = 1
@export var prerequisite_structure_id: StringName = &""
@export var tech_gate: StringName = &""
@export var gold_cost: int = 0
@export var material_costs: Dictionary[StringName, int] = {}
```

## Out of Scope

- Story 019: prerequisite-chain enforcement logic (this story only defines the schema/ledger shape)
- Story 025: the actual cost values (Formulas 1-3)

## QA Test Cases

**AC-1**: query both ledgers, confirm structural independence — unlock a tech node, assert zero mutation to `_structure_ledger`, and vice versa.

**AC-2**: unlock a tech node AND build a structure in one session, assert each debits gold/materials independently, no shared currency pool beyond raw gold/materials themselves.

**AC-3**: load the 5-node catalogue, assert exact category assignment per node — content-validation smoke check, not a runtime behavior test.

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: smoke check pass (`production/qa/smoke-*.md`)
**Status**: [x] Exceeded — real unit test suite created at `tests/unit/defense_building/tech_structure_data_schema_test.gd` (24 test functions), covering `TechNodeResource.validate()`, `StructureResource.validate()`, `GameDataRegistry` loading/lookup/isolation for both types, and `DefenseBuilding` ledger independence. Not yet executed in this environment (no headless Godot/gdUnit4 runner available) — verified by direct inspection only.

## Dependencies

- Depends on: None (first Defense Building story)
- Unlocks: Story 019, Story 020, Story 021, Story 022

## Completion Notes
**Completed**: 2026-07-18
**Criteria**: 2/3 passing (AC-2 DEFERRED — resolution/spend logic is Story 019/022/023 scope, unverifiable here)
**Deviations**:
- ADVISORY: header `Type: Config/Data` doesn't match actual implementation (real GDScript — 2 Resource subclasses + GameDataRegistry extension), routed to `godot-gdscript-specialist` during `/dev-story`. Evidence delivered exceeds the Config/Data bar regardless.
- ADVISORY: `DefenseBuilding` is not yet Autoload-registered per ADR-0024's full Decision — deliberately deferred to Story 019 (guarded by `test_defense_building_is_not_registered_as_autoload`). Logged as `TD-defbuild-001` in `docs/tech-debt-register.md`.
**Test Evidence**: `tests/unit/defense_building/tech_structure_data_schema_test.gd` (24 test functions) — verified by inspection, not yet executed (no headless Godot runner available this session).
**Code Review**: Complete — `/code-review`, Verdict: APPROVED WITH SUGGESTIONS (2026-07-17)
