# ADR-0016: Inventory Storage Model

## Status
Accepted

## Date
2026-07-11

## Last Verified
2026-07-17 — Inventory's Autoload-vs-scene-instanced status, left "TBD at implementation time" by this ADR's original Architecture Diagram, is now **resolved: Inventory is an Autoload**. This was surfaced as a load-bearing gap during `/architecture-decision` for ADR-0024 (Defense Building): ADR-0021 (Inventory cross-system query/mutation API) already depends on Inventory exposing `has_items()`/`has_room_for()`/`clear_damaged_flag()`/`apply_rune_to_item()` as direct-call methods to Crafting, Equipment Forge, Menagerie, and Defense Building — per ADR-0020's Criterion A, every direct-call callee in this project (Grid, GameDataRegistry, MissionEconomy, and now Defense Building) is an Autoload; a scene-instanced Inventory would require every caller to hold a node reference, which ADR-0001 forbids. Boot position: **Autoload #9**, appended after MissionEconomy (#8) — Inventory has no Autoload-time dependency on any system booting after it, so appending rather than inserting mid-sequence avoids renumbering positions 1–8. Defense Building (ADR-0024) is renumbered from #9 to **#10** to preserve dependency order (Defense Building calls Inventory's methods; Inventory should be available first). See `docs/registry/architecture.yaml`'s `autoload_boot_order` entry for the authoritative current sequence.

2026-07-13 — `restore_order` corrected from 20 to 10 (collided with `save-persistence.md`'s own Formula 4 assignment, where 20 belongs to Menagerie) during `/architecture-review` 2026-07-13. See `docs/architecture/architecture-review-2026-07-13.md` Conflict 1.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core (persistence/data) |
| **Knowledge Risk** | MEDIUM — inherited from Save & Persistence's boundary (`FileAccess.store_*()` returns `bool` since 4.4) and from `Resource.duplicate()`'s shallow-copy behavior for nested Resources since 4.5. Not a novel risk for this ADR itself; both are already governed by ADR-0003 and ADR-0008. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/deprecated-apis.md`; no dedicated `modules/core.md` exists (expected — pure data/persistence domain, not a rendering/physics/UI/audio/input/navigation/networking/animation module) |
| **Post-Cutoff APIs Used** | `Resource.duplicate_deep()` (4.5+) — only if a unique-instance item needs mission-time isolation when equipped (see Decision, Key Interfaces) |
| **Verification Required** | Confirm `duplicate_deep()` correctly isolates a stat-rolled item's override Dictionary from the Inventory-held original once equipped — verify via a unit test, not just code review |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (Save file format — Accepted, `SaveRestorer` interface convention), ADR-0009 (Resource data model — Accepted, `GameDataRegistry` + `validate()` convention) |
| **Enables** | Unblocks Epic 03 stories 001-007 (`production/epics/epic-03-core-economy/`) |
| **Blocks** | None — this ADR is itself the blocker being resolved |
| **Ordering Note** | Inventory must register with `SavePersistence` at `restore_order` strictly lower than Hero's (30, the only currently-registered Core-band implementor) — see Decision |

## Context

### Problem Statement

`design/gdd/inventory.md` is content-complete and passed `/consistency-check`, but no ADR exists covering how Inventory actually stores item stacks, how item definitions (static data: name, category, base stats) relate to runtime stack instances, or how stat-rolled unique items get a stable per-instance identity that prevents duplicate rolls from merging (GDD AC-18). Without this decision, all 7 Inventory stories in Epic 03 are `Status: Blocked`.

### Constraints

- Must follow the already-Accepted `SaveRestorer` pattern (ADR-0003): `get_save_key()`, `get_save_data() -> Dictionary` (primitives only), `restore_save_data(data) -> bool`, `reset_to_defaults()`, registered via `SavePersistence.register(self, restore_order)`.
- Must not return Resource instances from `get_save_data()` (forbidden pattern `resource_object_in_save_data`, ADR-0003).
- `restore_order` must be strictly lower than Hero's (30) per the GDD's own requirement — equip-state validation in Hero/Tower must see fresh Inventory data.
- Must not contradict `data_resource_as_event_payload` (ADR-0009) — `item_added`/`item_removed`/`equipment_slot_changed`/`item_pickup_rejected` payloads are already primitives-only per the frozen `event-bus.md` catalogue; this ADR's storage choice must not require changing that.

### Requirements

- 10 starting slots, type-driven stack caps (Equipment/Tower Components = 1, Materials/Crafted Goods = 99), auto-overflow to new stacks (GDD Core Rules 1-2)
- Two independently stat-rolled instances of the same item definition must occupy distinct slots and never merge (AC-18)
- Partial stack consumption must not trigger slot compaction (AC-17)
- Equipped/installed items are locked against removal but still count against capacity (AC-11, AC-12)

## Decision

**Two-tier data model**, mirroring the existing `MonsterResource`/`MonsterEntity` split (ADR-0006/ADR-0009):

1. **`ItemDefinitionResource`** (static, data-driven) — one `.tres` file per distinct item definition (e.g. `frost_silk`, `iron_foundation_component`), loaded by `GameDataRegistry` at boot (Autoload position 5, per ADR-0009's existing convention) and validated via `validate() -> Array[String]` (per the `resource_validation` contract). Fields: `item_id: StringName`, `item_type: StringName` (maps to the 4 fixed tabs), `display_name: String`, `is_unique_instance: bool` (true for Equipment/stat-rolled Tower Components), `base_stats: Dictionary` (only meaningful when `is_unique_instance == true`).

2. **`InventorySlot`** (runtime, NOT a Resource) — a plain `RefCounted` or typed inner class held in an `Array[InventorySlot]` on the Inventory Autoload/node. Fields: `item_id: StringName` (FK into `GameDataRegistry`), `quantity: int`, `instance_id: int` (`-1` for stackable items; a positive monotonic counter value for unique instances — see Key Interfaces), `stat_overrides: Dictionary` (empty for stackable items; holds the specific roll for unique instances), `locked: bool` (true while equipped/installed).

This keeps `get_save_data()` trivially primitive: each `InventorySlot` serializes to a flat `Dictionary` (`item_id` as `String`, `quantity`, `instance_id`, `stat_overrides`, `locked`) — no Resource objects ever cross the save boundary, satisfying the `resource_object_in_save_data` forbidden pattern by construction rather than by discipline.

**Unique-instance identity**: Inventory owns a monotonic `_next_instance_id: int` counter (persisted in `get_save_data()` alongside slot data, so IDs remain stable and non-colliding across save/load). Every stat-rolled pickup gets a new `instance_id` at creation time. Stack-cap enforcement, removal-lock checks, and non-merge behavior (AC-18) are all keyed on `instance_id`, never on `item_id` or stat equality — two identical rolls of the same definition get two different `instance_id` values and therefore never collapse into one slot.

**Equip-time isolation**: when a unique-instance item is equipped (Hero) or installed (Tower Component), Inventory does not hand off ownership of the `stat_overrides` Dictionary by reference — it passes a duplicated copy (`Dictionary.duplicate(true)`, sufficient here since `stat_overrides` contains only primitives, not nested Resources — `duplicate_deep()` is reserved for actual Resource trees per ADR-0008's `shallow_duplicate_for_components` pattern, which does not apply here since `InventorySlot` itself is not a Resource). The `locked: bool` flag prevents removal while equipped; the slot itself never leaves Inventory's array.

### Architecture Diagram

```
GameDataRegistry (Autoload, boot position 5)
  └─ preloads ItemDefinitionResource[] from assets/data/items/
       validate() called per definition at boot (ADR-0009 contract)

Inventory (Autoload #9 — resolved 2026-07-17, see Last Verified; required for ADR-0021's cross-system direct-call surface to be callable as a bare global, per ADR-0020 Criterion A)
  ├─ owns: Array[InventorySlot] (runtime, not Resources)
  ├─ owns: _next_instance_id: int (monotonic counter)
  ├─ implements SaveRestorer:
  │    get_save_key() -> "inventory"
  │    get_save_data() -> Dictionary (primitives only — slots + _next_instance_id)
  │    restore_save_data(data) -> bool
  │    reset_to_defaults() -> void
  ├─ registers: SavePersistence.register(self, restore_order=10)   # matches save-persistence.md Formula 4; < Hero's 30
  ├─ reads: GameDataRegistry.get_item_definition(item_id) -> ItemDefinitionResource
  ├─ subscribes (EventBus): materials_earned, materials_spent
  └─ emits (EventBus): item_added, item_removed, equipment_slot_changed, item_pickup_rejected
```

### Key Interfaces

```gdscript
# ItemDefinitionResource (assets/data/items/*.tres, loaded by GameDataRegistry)
class_name ItemDefinitionResource extends Resource
@export var item_id: StringName = &""
@export var item_type: StringName = &""       # Equipment | TowerComponent | Material | CraftedGood
@export var display_name: String = ""
@export var is_unique_instance: bool = false   # true = cap 1, stat-rolled; false = cap 99, stackable
@export var base_stats: Dictionary = {}        # only meaningful when is_unique_instance == true
func validate() -> Array[String]: ...          # per resource_validation contract (ADR-0009)

# InventorySlot (runtime only — NOT a Resource, never saved directly)
class_name InventorySlot extends RefCounted
var item_id: StringName
var quantity: int = 0
var instance_id: int = -1        # -1 = stackable; >=0 = unique-instance identity
var stat_overrides: Dictionary = {}   # consider Dictionary[StringName, float] at implementation time
var locked: bool = false

# Inventory (implements SaveRestorer per ADR-0003)
func get_save_key() -> String: return "inventory"
func get_save_data() -> Dictionary: ...   # primitives only — no InventorySlot/Resource objects
func restore_save_data(data: Dictionary) -> bool: ...
func reset_to_defaults() -> void: ...
```

## Alternatives Considered

### Alternative A: Lightweight-only (no Resource subclass at all)

- **Description**: Item definitions live as plain `Dictionary` data loaded from a non-Resource data file (e.g. raw JSON or a custom parser), with no `GameDataRegistry` integration.
- **Pros**: Simplest possible implementation; no new Resource subclass to validate.
- **Cons**: Breaks from the project's established data-driven-Resource convention (ADR-0009 already covers `MonsterResource`, `WaveConfig`, `TowerComponent` — a fourth, differently-loaded data format for items adds inconsistency); would need its own loader and validation path outside `GameDataRegistry`, duplicating infrastructure that already exists.
- **Rejection Reason**: No technical justification for diverging from the existing Resource-subclass + `GameDataRegistry` pattern that Monster and Tower already use successfully.

### Alternative C: Full Resource runtime (every stack is a Resource subclass)

- **Description**: `InventorySlot` itself becomes a `Resource` subclass (`ItemStackResource`), `duplicate_deep()`'d per unique instance at creation, following the `TowerMissionState` pattern from ADR-0008 exactly.
- **Pros**: Maximum uniformity — every persistent-ish object in the codebase is a Resource with `validate()`.
- **Cons**: Heavier than needed — `InventorySlot` never needs the Resource base class's serialization/editor-inspector machinery; it would still require an explicit conversion step to primitives for `get_save_data()` anyway (Resources cannot cross the save boundary directly per the forbidden pattern), making the Resource wrapper pure overhead for this specific object; `duplicate_deep()` per stack creation is unnecessary cost when `InventorySlot`'s only "nested" data is a flat `Dictionary` of primitives, which plain `Dictionary.duplicate(true)` already isolates correctly.
- **Rejection Reason**: The `TowerMissionState` precedent exists because `TowerComponent` Resources have genuinely nested Resource-to-Resource references needing `duplicate_deep()`. `InventorySlot`'s `stat_overrides` is a flat primitive Dictionary — a plain `RefCounted`/inner-class with `Dictionary.duplicate(true)` achieves the same isolation without inheriting Resource's overhead.

## Consequences

### Positive

- `get_save_data()` is trivially primitive-only by construction — no risk of accidentally serializing a Resource reference (the forbidden pattern this ADR must avoid).
- Mirrors the already-proven `MonsterResource`/`MonsterEntity` static-vs-runtime split — no new architectural pattern introduced, just a new instance of an existing one.
- Unique-instance non-merging (AC-18) is structurally guaranteed by `instance_id` uniqueness, not by convention or discipline in comparison logic.

### Negative

- Two-tier model means any code touching an item must resolve both the static `ItemDefinitionResource` (via `GameDataRegistry`) and the runtime `InventorySlot` — slightly more indirection than a single flat structure.
- `_next_instance_id` must itself be save-persisted correctly (included in `get_save_data()`) — an implementation bug here (e.g., forgetting to restore the counter) could theoretically produce a collision after load. This should be an explicit unit test.

### Risks

- **Risk**: A future system (Crafting, Equipment Forge) might be tempted to read `InventorySlot.stat_overrides` directly rather than going through Inventory's query API, creating a direct-state-read dependency.
  - **Mitigation**: Inventory should expose read-only accessor methods (e.g., `get_slot_contents(slot_index) -> Dictionary`) rather than exposing the `Array[InventorySlot]` itself — this is an implementation detail for the eventual story, not this ADR, but flagged here as a design intent.
- **Risk**: `restore_order=10` is chosen to match `save-persistence.md`'s own Formula 4 assignment table (Inventory=10, Menagerie=20, ..., Tower=23, Hero=30), but Tower System (Complete, Epic 02) does not yet appear in the `restore_order` registry comment block in `save_persistence.gd` — its actual registered value (if any) is unverified as of this ADR.
  - **Mitigation**: Whoever implements Story 001 must grep `save_persistence.gd`'s registry comment block at implementation time to confirm Tower's actual `restore_order` (if registered) matches the GDD's assignment of 23, and update the comment block per the existing convention ("Update this list whenever a new SaveRestorer implementor is added"). **Resolved 2026-07-13**: the original draft of this ADR used `restore_order=20`, which collided with Menagerie's own slot in `save-persistence.md`'s Formula 4 table — corrected to 10 during `/architecture-review`.
- **Minor note** (godot-specialist validation, non-blocking): `base_stats` and `stat_overrides` are untyped `Dictionary` in this ADR's snippets. The project has already verified typed `Dictionary[K,V]` works in this engine version (per `VERSION.md`'s Project-Specific API Tracking table). Consider `Dictionary[StringName, float]` for both at implementation time for compiler-optimization benefits — not an ADR-level blocker, a Story 001 code-quality note.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| inventory.md | Core Rule 1-2: 10-slot start, type-driven stack caps | `InventorySlot.quantity` + `ItemDefinitionResource.is_unique_instance` drive cap enforcement (cap 1 vs 99) |
| inventory.md | AC-18: stat-rolled duplicates never merge | `instance_id` monotonic counter, keyed identity independent of stat equality |
| inventory.md | AC-11/AC-12: equipped-item lock, still counts against cap | `InventorySlot.locked: bool`, checked at removal-attempt and capacity-check time |
| inventory.md | Dependencies: `SaveRestorer` interface, `restore_order` lower than Hero/Tower | `restore_order=10` (matches `save-persistence.md`'s own Formula 4 assignment; below Hero's 30), full `SaveRestorer` method set specified in Key Interfaces |
| inventory.md | AC-17: partial consumption, no slot compaction | `InventorySlot` array is index-stable — consumption only mutates `quantity` in place, never re-indexes the array |

## Performance Implications

- **CPU**: Negligible — Inventory operations are player-action-triggered (add/remove/query), not per-frame. No frame-budget concern.
- **Memory**: `ItemDefinitionResource` instances are loaded once at boot (shared, immutable) via `GameDataRegistry`; `InventorySlot` instances are lightweight (a handful of primitive fields), well within the 1 GB memory ceiling for any realistic item count (max 40 slots per the GDD's own tier cap).
- **Load Time**: Item definitions load alongside existing `GameDataRegistry` boot-time preloading (ADR-0009) — no new load-time phase introduced.
- **Network**: N/A — single-player game.

## Migration Plan

N/A — Inventory has no existing implementation to migrate from. This is a greenfield decision.

## Validation Criteria

- Unit tests confirm: two stat-rolled instances of the same `item_id` never merge (AC-18), regardless of identical `stat_overrides` content.
- Unit tests confirm: `get_save_data()` output contains only primitive types (no Resource instances) — verifiable via a type-inspection test on the returned Dictionary.
- Unit tests confirm: `_next_instance_id` round-trips correctly across a save/load cycle (no collision after restore).
- Integration test confirms: Inventory's `restore_order` executes before Hero's during a save-load sequence (order-of-operations test, not just a numeric comparison).

## Related Decisions

- ADR-0003 (Save file format) — `SaveRestorer` interface this ADR implements
- ADR-0009 (Resource data model) — `GameDataRegistry` + `validate()` pattern this ADR extends to `ItemDefinitionResource`
- ADR-0008 (Tower placement gate) — precedent for mission-instance isolation (`duplicate_deep()`), explicitly not applied here (see Alternative C)
- `design/gdd/inventory.md` — source GDD for all requirements this ADR addresses
