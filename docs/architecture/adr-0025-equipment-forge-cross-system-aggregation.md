# ADR-0025: Equipment Forge Cross-System Aggregation

## Status
Accepted

## Acceptance Note
Accepted 2026-07-18 (Sprint 6, S6-04) by explicit user decision, outside the normal `/architecture-review` gate — same precedent as ADR-0022/0027/0028/0029's Sprint 6 acceptances. Lightweight manual cross-check: all dependency ADRs (0009, 0020, 0021, 0022, 0023) confirmed `Accepted`; `restore_order=32` confirmed collision-free against the full authoritative table (10, 11, 20, 21, 22, 24, 30, 31, 34); Menagerie's `request_sacrifice()` confirmed implementable (ADR-0026, already Accepted from Epic 05's batch). Unblocks Epic 08's Equipment Forge stories (008–016) — flips them `Blocked` → `Ready`, except the sacrifice-flow story which additionally waits on Menagerie's own core lifecycle stories per its own sequencing note. An independent `/architecture-review` pass in a fresh session is still recommended before Epic 08's next milestone.

## Date
2026-07-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core (data/integration contract) |
| **Knowledge Risk** | LOW — extends ADR-0009's `GameDataRegistry`/`Resource`/`validate()` convention and ADR-0023's `RecipeResource`/Discovery-Ledger shape; reuses ADR-0021's Inventory API and ADR-0020's direct-call criteria. No new engine subsystem. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; ADR-0009 (Resource Data Model); ADR-0023 (Crafting recipe data model — direct structural precedent); ADR-0021 (Inventory API); ADR-0020 (Direct-Autoload-call exception pattern); ADR-0024 (Defense Building — precedent for a system needing Autoload status solely to expose a direct-call method) |
| **Post-Cutoff APIs Used** | Typed `Dictionary[StringName, int]`/`Array[String]` (4.4+, already verified working) |
| **Verification Required** | None beyond what `VERSION.md` already confirms for typed Dictionaries |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0009, ADR-0020, ADR-0021, ADR-0023 (all Accepted-pending or Accepted); ADR-0022 (Constellation — Accepted-pending, its `restore_order=24` resolves this GDD's own flagged AC-26 blocker, confirmed below) |
| **Enables** | `design/gdd/equipment-forge.md` implementation stories (currently blocked pending this ADR) |
| **Blocks** | None further downstream — Equipment Forge is the project's most convergent system (per `systems-index.md`, "design last among Sanctuary systems") and nothing depends on it in turn |
| **Ordering Note** | **RESOLVED 2026-07-17 by ADR-0026**: Menagerie is confirmed as Autoload #11, and `request_sacrifice(creature_id: int, target_item_id: int) -> bool` is now implementable — this ADR's Key Interfaces code sample is corrected accordingly (see Last Verified). Originally, this ADR had an open dependency mirroring the situation ADR-0023 was in with Defense Building before ADR-0024 resolved it; the same pattern repeated here and was resolved in the same session. |

## Last Verified
2026-07-17 — `_resolve_sacrifice()`'s `creature_id` parameter corrected from `String` to `int` to match `Menagerie.request_sacrifice()`'s actual signature (ADR-0026) and `Inventory.reserve_instance_id() -> int` (ADR-0021's own return type for `target_item_id`). Caught by godot-specialist review of ADR-0026: this ADR's prose already stated `int`/`String` was a GDD-level drift to fix, but its own Key Interfaces code sample had not been updated in lockstep — fixed now.

## Context

### Problem Statement

`design/gdd/equipment-forge.md` is the project's most convergent Sanctuary system — it draws inputs from seven upstream systems (Hero, Crafting, Menagerie, Constellation, Tarot, Inventory, Save & Persistence) — but has no ADR covering its two recipe schemas (`EquipmentRecipeResource`, `SacrificeRecipeResource`), its three-ledger persistence model, or the cross-system call boundaries it originates (TR-equipforge-001/002/003). Without this ADR, every Equipment Forge implementation story is `Blocked`.

Two of the three previously-blocking interface gaps this GDD flagged are already resolved by prior work this session: `Inventory.has_room_for()` and `Inventory.apply_rune_to_item()` (including its required exemption to Inventory's Rule 5 equipped-item lock) are both specified by ADR-0021. Constellation's previously-missing `restore_order` (which left AC-26 explicitly unverifiable) is resolved by ADR-0022's `restore_order=24` — this ADR confirms that ordering is compatible with Equipment Forge's own `restore_order=32` (24 < 32, satisfying the GDD's own dependency rationale). The one gap this ADR cannot itself resolve is `Menagerie.request_sacrifice()`'s Autoload status, since Menagerie has no ADR yet — this is stated explicitly above rather than silently assumed.

### Constraints

- `EquipmentRecipeResource` must structurally extend `RecipeResource` (ADR-0023), not reinvent it — same fixed, never-rolled output philosophy, same `GameDataRegistry`-backed loading convention.
- Equipment Forge's own persisted save data is narrower than item data — it owns exactly two ledgers (Equipment Recipe Discovery Ledger, Available Rune Ledger); actual Equipment item instances (including `imbued_runes` and free-slot count) are Inventory's data, per ADR-0021's `InventorySlot.imbued_runes` field. This ADR must not duplicate that ownership.
- `restore_order = 32` (already assigned in `save-persistence.md`) must restore after Tarot (22), Menagerie (20), Constellation (24), and Hero (30) — this ADR confirms compatibility, does not re-derive the number.
- The `_forge_resolving` guard must span all three operation types (equipment crafting, rune imbuing, creature sacrifice) as one shared flag, mirroring Crafting's `_craft_resolving` and Defense Building's `_action_resolving` precedent (ADR-0023/ADR-0024) — not three independently-guarded operations that could race against each other.
- Menagerie-sourced runes must never enter the `available_runes` ledger (Rule 13) — they are consumed immediately in the same operation that creates them, a deliberate asymmetry from Constellation/Tarot-sourced runes that must not be architecturally blurred into one uniform rune-acquisition path.

### Requirements

- `EquipmentRecipeResource` fields (Rule 4): `recipe_id`, `recipe_category` (fixed `"hero_equipment"`), `output_slot`, `inputs`, `tech_prerequisite`, `output_item_id`, `quality_tier`, `rune_slot_count` (derived from `output_slot`, not authored per-recipe).
- `SacrificeRecipeResource` fields (Rule 18): `sacrifice_recipe_id`, `required_species`, `output_slot`, `output_base_item_id`, `quality_tier` (derived, Formula 2), `rune_id`, `stat_delta`.
- Equipment Recipe Discovery Ledger: identical shape to Crafting's (ADR-0023) — `Dictionary[StringName, bool]`, two-gate discovery, permanent.
- Available Rune Ledger: `Dictionary[StringName, Dictionary]` keyed `rune_id`, values `{rune_source: String, stat_delta: Dictionary}` — populated only by `constellation_rune_discovered`/`tarot_rune_discovered`, never by Menagerie sacrifice.
- Three resolution flows (equipment craft, rune imbue, creature sacrifice) share one `_forge_resolving` guard.
- `Menagerie.request_sacrifice(creature_id, target_item_id) -> bool` must be specified as a direct-call contract now, even though Menagerie's own ADR (not yet written) must confirm Menagerie's Autoload status before this is implementable.

## Decision

**Two Resource subclasses**, both `GameDataRegistry`-backed, following ADR-0023's `RecipeResource` pattern exactly:

- **`EquipmentRecipeResource`**: **not** a GDScript subclass of `RecipeResource` — a separate `Resource` subclass mirroring its field shape and validation convention (same pattern as `RecipeResource` itself is a sibling of `ItemDefinitionResource`, not a subclass of it). Fixed `recipe_category` literal `"hero_equipment"` and two additional fields beyond `RecipeResource`'s own set — `output_slot: String` (`weapon`/`armor`/`accessory`/`trinket` — a distinct vocabulary from Tower's `foundation`/`weapon`/`focus`/`power` slot names, flagged as a naming collision on the string `"weapon"` that is a content-authoring caution only, never a mechanical conflict since the two systems never compare these strings against each other) and `rune_slot_count: int` (derived at data-authoring time from the fixed `output_slot -> rune_slot_count` table in Rule 11: `weapon`=2, `armor`=2, `accessory`=1, `trinket`=1 — not itself an authored per-recipe field, computed/validated by `validate()`).
- **`SacrificeRecipeResource`**: a second, smaller Resource subclass (not a variant of `EquipmentRecipeResource` — it consumes a `creature_id`, not `inputs`, and has no material cost) with fields per Rule 18: `sacrifice_recipe_id`, `required_species`, `output_slot`, `output_base_item_id`, `quality_tier` (computed via Formula 2 at resolution time, not authored), `rune_id`, `stat_delta`.

Both reuse `recipe_discovered` (Equipment recipes) — no new event — and `hero_equipment_crafted`/`item_rune_imbued` (frozen in `event-bus.md`) for their respective resolution outcomes.

**Three ledgers, two persisted**:

1. **Equipment Recipe Discovery Ledger** — `Dictionary[StringName, bool]` (`recipe_id -> discovered`), identical shape and discovery-trigger logic to Crafting's ledger (ADR-0023), including the same three-trigger-path resolution (tech_unlocked, item_added, boot/restore sweep) — this ADR does not re-derive that logic, it reuses ADR-0023's pattern verbatim for Equipment recipes.
2. **Available Rune Ledger** — `Dictionary[StringName, Dictionary]` (`rune_id -> {rune_source: String, stat_delta: Dictionary}`), populated exclusively by `constellation_rune_discovered`/`tarot_rune_discovered` EventBus subscriptions. Menagerie-sourced runes are explicitly excluded from this structure by construction — Rule 19's sacrifice resolution flow never writes into it, closing Rule 13's asymmetry at the data-structure level rather than leaving it as a convention a future maintainer could accidentally violate.
3. **Per-Item Rune Slot Occupancy** — **not owned by this ADR at all**. This is `InventorySlot.imbued_runes`/rune-slot-count data, already specified by ADR-0021. Listed here only to make explicit what Equipment Forge does *not* persist, closing the exact ambiguity Rule 10 flags against `save-persistence.md`'s broader (and inaccurate) summary line.

Both persisted ledgers are covered by one `SaveRestorer` implementation, `get_save_key() -> "equipment_forge"`, `restore_order = 32` (already assigned in `save-persistence.md`) — confirmed compatible with Tarot (22), Menagerie (20), Constellation (24), and Hero (30), all of which must restore first per the GDD's own dependency rationale (Dependencies section, `equipment-forge.md`).

**Three resolution flows, one shared guard**: Equipment Crafting (Rule 9, mirrors Crafting's Rule 8 exactly), Rune Imbuing (Rule 14, calls `Inventory.apply_rune_to_item()` per ADR-0021), and Creature Sacrifice (Rule 19, calls `Menagerie.request_sacrifice()` — see below). All three are guarded by one `_forge_resolving: bool` flag (not three independent guards), set at the start of any operation's first validation step and cleared only after its final event emission — identical mechanism to Crafting's `_craft_resolving` (ADR-0023) and Defense Building's `_action_resolving` (ADR-0024), generalized here across three operation types instead of two.

**`Menagerie.request_sacrifice(creature_id, target_item_id) -> bool` — Criterion B direct call (ADR-0020)**: a narrow, single-caller action (only Equipment Forge calls this, structurally, by design — no other system originates a creature sacrifice), state-guarded by Menagerie's own `BREEDING_PEN` check per its Rule 13. Per ADR-0020's Criterion B and the precedent ADR-0024 already established for `DefenseBuilding.is_tech_unlocked()`, **this requires Menagerie to be an Autoload**, not scene-instanced — a scene-instanced Menagerie would force Equipment Forge to hold a node reference into it, violating ADR-0001. **This ADR cannot itself resolve Menagerie's Autoload status** (that is Menagerie's own ADR's decision to make), but states the requirement explicitly here so Menagerie's forthcoming ADR inherits a known constraint rather than discovering it independently, mirroring exactly how this session's Crafting→Defense Building dependency was surfaced and then resolved.

Equipment Forge's own resolution flow (Rule 19, steps a–f) is specified in full regardless of Menagerie's current ADR status: validate room (`has_room_for`, Criterion A) → reserve a prospective `item_id` → call `request_sacrifice()` (Criterion B, pending Menagerie's Autoload confirmation) → on `false`, abort with zero side effects → on `true`, construct the item, emit `hero_equipment_crafted`, then emit `item_rune_imbued` with `rune_source="menagerie"` in the same synchronous operation.

**Prospective `item_id` reservation — a small extension to ADR-0021's Inventory surface, needed here** (godot-specialist-flagged gap): the item does not yet exist when `target_item_id` must be passed to `request_sacrifice()` (step c precedes step d), but Equipment Forge is scene-instanced, not Autoload — any ID counter it held locally would not share Inventory's own uniqueness guarantee and would risk colliding with `InventorySlot.instance_id` values after a Sanctuary scene reload (Equipment Forge's local state resets; Inventory's Autoload state does not). Rather than minting IDs from scene-local state, Equipment Forge calls a new Inventory method, `Inventory.reserve_instance_id() -> int`, drawn from the same monotonic `_next_instance_id: int` counter ADR-0016 already owns and persists (Criterion A, ADR-0020 — read/reserve against a sole-owner Autoload). This is a one-line extension to ADR-0021's already-Proposed interface surface, not a new ADR — added directly to that ADR's Key Interfaces since it is still `Proposed`, not yet Accepted.

### Architecture Diagram

```
GameDataRegistry (Autoload, boot position 5)
  └─ preloads EquipmentRecipeResource[] and SacrificeRecipeResource[]
       from assets/data/{equipment_recipes,sacrifice_recipes}/
       validate() called per resource at boot (ADR-0009 contract)

EquipmentForge (scene-instanced node, Sanctuary-only — nothing calls INTO
                Equipment Forge directly; all its outputs are EventBus events,
                so it needs no Autoload status itself)
  ├─ owns: _equipment_discovery_ledger: Dictionary[StringName, bool]
  ├─ owns: _available_runes: Dictionary[StringName, Dictionary]   # rune_id -> {rune_source, stat_delta}
  ├─ owns: _forge_resolving: bool   # shared guard, all 3 operation types
  ├─ implements SaveRestorer:
  │    get_save_key() -> "equipment_forge"
  │    get_save_data() -> Dictionary (primitives only — both ledgers)
  │    restore_save_data(data) -> bool
  │    reset_to_defaults() -> void
  ├─ registers: SavePersistence.register(self, restore_order=32)
  ├─ reads: GameDataRegistry.get_equipment_recipe()/get_sacrifice_recipe()
  ├─ calls (direct, Criterion A/ADR-0020): Inventory.has_items(), has_room_for(),
  │    apply_rune_to_item()
  ├─ calls (direct, Criterion B/ADR-0020 — PENDING Menagerie ADR):
  │    Menagerie.request_sacrifice(creature_id, target_item_id) -> bool
  ├─ subscribes (EventBus): tech_unlocked, item_added, item_removed,
  │    constellation_rune_discovered, tarot_rune_discovered
  └─ emits (EventBus): hero_equipment_crafted, item_rune_imbued, recipe_discovered
```

### Key Interfaces

```gdscript
# EquipmentRecipeResource (assets/data/equipment_recipes/*.tres)
class_name EquipmentRecipeResource extends Resource
@export var recipe_id: StringName = &""
@export var recipe_category: String = "hero_equipment"   # fixed literal
@export var output_slot: String = ""              # weapon|armor|accessory|trinket
@export var inputs: Dictionary[StringName, int] = {}
@export var tech_prerequisite: StringName = &""
@export var output_item_id: StringName = &""
@export var quality_tier: int = 1
@export var rune_slot_count: int = 1              # derived from output_slot at authoring time
func validate() -> Array[String]: ...             # confirms rune_slot_count matches Rule 11's table

# SacrificeRecipeResource (assets/data/sacrifice_recipes/*.tres)
class_name SacrificeRecipeResource extends Resource
@export var sacrifice_recipe_id: StringName = &""
@export var required_species: StringName = &""
@export var output_slot: String = ""
@export var output_base_item_id: StringName = &""
@export var rune_id: StringName = &""
@export var stat_delta: Dictionary = {}
func validate() -> Array[String]: ...

# EquipmentForge (scene-instanced node, implements SaveRestorer per ADR-0003)
var _equipment_discovery_ledger: Dictionary[StringName, bool] = {}
var _available_runes: Dictionary[StringName, Dictionary] = {}   # rune_id -> {rune_source, stat_delta}
var _forge_resolving: bool = false

func get_save_key() -> String: return "equipment_forge"
func get_save_data() -> Dictionary:
    return {"discovery_ledger": _equipment_discovery_ledger, "available_runes": _available_runes}
func restore_save_data(data: Dictionary) -> bool:
    var raw_ledger = data.get("discovery_ledger", {})
    var raw_runes = data.get("available_runes", {})
    if typeof(raw_ledger) != TYPE_DICTIONARY or typeof(raw_runes) != TYPE_DICTIONARY:
        return false
    _equipment_discovery_ledger = raw_ledger
    _available_runes = raw_runes
    return true

func _resolve_sacrifice(sacrifice_recipe: SacrificeRecipeResource, creature_id: int) -> void:
    # creature_id typed int, matching Menagerie's CreatureInstance.creature_id
    # (ADR-0026) — corrected 2026-07-17 from an earlier String typing that had
    # drifted out of sync with ADR-0026's own int-typed signature.
    if _forge_resolving:
        return
    _forge_resolving = true
    if not Inventory.has_room_for(sacrifice_recipe.output_slot, 1):
        _forge_resolving = false
        return   # (b) — creature never touched
    var target_item_id: int = Inventory.reserve_instance_id()   # (c) — Criterion A, drawn from Inventory's own _next_instance_id counter (ADR-0016), not scene-local state
    if not Menagerie.request_sacrifice(creature_id, target_item_id):   # (d) — Criterion B, Menagerie confirmed Autoload #11 by ADR-0026
        _forge_resolving = false
        return   # (e) — abort, zero side effects
    # (f) — construct item, emit hero_equipment_crafted, then item_rune_imbued
    _forge_resolving = false
```

## Alternatives Considered

### Alternative A: A single `RuneSourceResource` abstraction unifying Constellation/Tarot/Menagerie acquisition

- **Description**: Model all three rune sources through one polymorphic acquisition interface, rather than treating Menagerie's sacrifice path as structurally distinct from the Constellation/Tarot discovery-ledger path.
- **Pros**: Superficially more "elegant" — one code path handles all rune acquisition.
- **Cons**: Directly contradicts Rule 13's explicit, deliberate asymmetry — Constellation/Tarot runes are discovered independently of any item and wait in a ledger; a Menagerie rune is inseparable from the sacrifice that produces it and is consumed atomically in the same operation. Forcing both through one abstraction would require either (a) writing Menagerie-sourced runes into `available_runes` transiently just to immediately consume them (adds a spurious state transition with no player-visible purpose), or (b) a polymorphic interface with a branch for "this source never actually goes through the ledger" (defeats the point of unifying in the first place).
- **Rejection Reason**: The GDD is explicit that this asymmetry is a deliberate design choice, not an oversight. Three data structures cleanly matching the three distinct sourcing mechanics (two ledger entries + one atomic consume-on-create) is simpler than one abstraction with an internal special case.

### Alternative B: Equipment Forge itself becomes an Autoload to simplify the Menagerie-Autoload question

- **Description**: Promote Equipment Forge to Autoload status so its own cross-system calls are symmetric with Inventory/DefenseBuilding, sidestepping any question of who calls whom.
- **Pros**: Superficial symmetry with the other Criterion-A/B callees.
- **Cons**: Nothing calls *into* Equipment Forge directly — every one of its outputs (`hero_equipment_crafted`, `item_rune_imbued`, `recipe_discovered`) is already an EventBus event, and its only cross-system calls are as a *caller* (into Inventory, prospectively into Menagerie), not a callee. ADR-0020's Criterion A/B only require the **callee** to be an Autoload; a caller can be scene-instanced regardless of what it calls, exactly as Crafting (scene-instanced) already calls Inventory (Autoload) without issue.
- **Rejection Reason**: Would add Autoload lifetime/reset complexity (per ADR-0002's own newly-added Negative consequence about Inventory/DefenseBuilding no longer resetting via scene teardown) for zero architectural benefit — Equipment Forge has no reason to be globally addressable, since nothing addresses it.

## Consequences

### Positive
- `EquipmentRecipeResource`/`SacrificeRecipeResource` give content authors concrete, validated schemas extending the already-established `RecipeResource` pattern, rather than a sixth divergent data format.
- Explicitly states the Menagerie-Autoload requirement now, before Menagerie's own ADR is written — the same proactive-flagging move that let this session catch and fix the Defense Building/Crafting ordering gap before it became an implementation-time surprise.
- Confirms two of the three previously-blocking interface gaps (`has_room_for`/`apply_rune_to_item`, Constellation `restore_order`) are already resolved by this session's prior ADRs, closing AC-9, AC-16(a)-(d), and AC-26 without further design work.

### Negative
- This ADR cannot be fully implementable until Menagerie's own ADR lands and confirms its Autoload status — Equipment Forge's Creature Sacrifice resolution flow (Rule 19) is architecturally specified but blocked on a sibling ADR, the same intermediate state ADR-0023's Crafting/Defense-Building dependency was in for part of this session.
- Two new Resource subclasses (`EquipmentRecipeResource`, `SacrificeRecipeResource`) rather than one, since Sacrifice recipes have a structurally different cost model (a creature, not material `inputs`) — a small duplication of `output_slot`/`quality_tier`-shaped fields across three Resource subclasses now (`RecipeResource`, `EquipmentRecipeResource`, `SacrificeRecipeResource`).

### Risks
- **Risk** (godot-specialist validation, fixed in this revision): the original draft's `_generate_prospective_item_id()` implied Equipment Forge could mint a unique item ID from its own scene-local state — but Equipment Forge is scene-instanced (see Alternative B), so any locally-held counter would not survive scene reload the way Inventory's Autoload state does, risking a collision with `InventorySlot.instance_id` values after a Sanctuary scene reload.
  - **Mitigation**: Fixed — the ID is now minted via `Inventory.reserve_instance_id()`, a small addition to ADR-0021's already-`Proposed` interface surface, drawing from the same monotonic `_next_instance_id` counter ADR-0016 already owns and persists. See Decision section.
- **Risk**: Menagerie's forthcoming ADR could reasonably decide Menagerie should remain scene-instanced (e.g. if `request_sacrifice()` is redesigned as an EventBus request/response pattern instead of a direct call) — in which case this ADR's Decision section's Criterion-B classification would need revision.
  - **Mitigation**: This ADR states the requirement as what Rule 19d's GDD-specified signature currently demands, not as an immutable constraint — if Menagerie's ADR chooses a different communication pattern, Equipment Forge's Rule 19 resolution flow must be revisited in lockstep, exactly as the Dependencies → Upstream Assumption Fragility table (row #6) in `equipment-forge.md` already anticipates for any change to Menagerie's sacrifice contract.
- **Risk**: The `output_slot` string collision between Equipment Forge's vocabulary (`weapon`/`armor`/`accessory`/`trinket`) and Tower's (`foundation`/`weapon`/`focus`/`power`) — both use the literal string `"weapon"` for unrelated concepts — could cause a content-authoring or query mistake if a future system ever queries both catalogues without namespacing.
  - **Mitigation**: Flagged explicitly in the Decision section per the GDD's own caution; `EquipmentRecipeResource.output_slot` and Tower's `component_slot` are never compared against each other by any specified system, so this remains a documentation-level caution, not an active bug — but any future cross-catalogue query API must namespace by resource type, not raw string.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| equipment-forge.md | Rule 4/18: `EquipmentRecipeResource`/`SacrificeRecipeResource` schemas | Both specified as `GameDataRegistry`-backed Resource subclasses, extending ADR-0023's pattern |
| equipment-forge.md | Rule 10: narrower save-payload scope than `save-persistence.md`'s summary | Explicitly confirmed: only 2 ledgers persisted; item/rune-slot data is Inventory's (ADR-0021) |
| equipment-forge.md | Rule 12/13: Available Rune Ledger excludes Menagerie-sourced runes | Data-structure-level exclusion — Rule 19's sacrifice flow never writes into `_available_runes` |
| equipment-forge.md | Edge Cases: `_forge_resolving` spans 3 operation types | Single shared guard specified in Key Interfaces, mirroring ADR-0023/ADR-0024's precedent |
| equipment-forge.md | AC-26 (previously blocked): Constellation-sourced rune restore ordering | Confirmed resolved — ADR-0022 assigned Constellation `restore_order=24`, compatible with Equipment Forge's 32 |
| equipment-forge.md | Open Questions: `Menagerie.request_sacrifice()` interface | Specified as Criterion B (ADR-0020); explicitly flagged as pending Menagerie's own forthcoming ADR for Autoload confirmation |

## Performance Implications
- **CPU**: Negligible — all three resolution flows are gameplay-action-triggered (Sanctuary-only, instant-on-confirm), not per-frame.
- **Memory**: Two small `Dictionary` ledgers bounded by content-authoring scale (recipe count, rune count) — negligible.
- **Load Time**: Resource definitions load alongside existing `GameDataRegistry` boot-time preloading (ADR-0009) — no new load-time phase.
- **Network**: N/A — single-player game.

## Migration Plan
N/A — Equipment Forge has no existing implementation to migrate from. This is a greenfield decision, partially blocked on Menagerie's forthcoming ADR (see Ordering Note).

## Validation Criteria
- Unit test confirms `_forge_resolving` rejects a second confirmation across all three operation types (craft, imbue, sacrifice), not just within one.
- Unit test confirms a Menagerie-sourced rune (post-`request_sacrifice`) never appears in `_available_runes` at any point, even transiently.
- Unit test confirms `apply_rune_to_item()` succeeds on a currently-equipped item (exercises ADR-0021's Rule-5-lock exemption from this GDD's own consumer side).
- Integration test confirms Equipment Forge's `restore_save_data()` executes after Tarot's (22), Menagerie's (20), Constellation's (24), and Hero's (30) — directly implements the previously-unverifiable AC-26.
- **Blocked pending Menagerie's ADR**: integration test confirming `Menagerie.request_sacrifice()` is callable as a direct Autoload call from Equipment Forge's Rule 19 flow.

## Related Decisions
- ADR-0009 (Resource Data Model) — `GameDataRegistry` + `validate()` pattern both new Resource subclasses extend
- ADR-0020 (Direct-Autoload-call exception pattern) — governs both the Criterion A (Inventory) and Criterion B (Menagerie, pending) calls this ADR specifies
- ADR-0021 (Inventory cross-system query/mutation API) — source of `has_items()`/`has_room_for()`/`apply_rune_to_item()`, and owner of the per-item rune-slot data this ADR explicitly does not duplicate
- ADR-0022 (Constellation pattern-detection data structure) — its `restore_order=24` resolves this GDD's previously-blocked AC-26
- ADR-0023 (Crafting recipe data model) — direct structural precedent for `RecipeResource`, Discovery Ledger, and `_*_resolving` guard patterns this ADR extends
- ADR-0024 (Defense Building tech tree data model) — precedent for a system needing Autoload status solely to expose a Criterion-B direct-call method; the same situation this ADR flags for Menagerie
- `design/gdd/equipment-forge.md` — source GDD for all requirements this ADR addresses
