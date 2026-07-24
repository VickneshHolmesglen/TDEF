# ADR-0023: Crafting Recipe Data Model and Discovery State Machine

## Status
Accepted

## Date
2026-07-17

## Acceptance Note
Accepted 2026-07-17 by direct user decision during `/create-stories epic-05-sanctuary-production`, to unblock that epic's stories — outside the normal `/architecture-review` gate (which was explicitly deferred this session, see `production/session-state/active.md`). engine-specialist validation already completed at authoring time; no re-review performed at acceptance. **Open item carried forward, not resolved by acceptance**: the project-wide SavePersistence mid-session-restore gap (flagged in ADR-0029) still blocks Crafting's persistence-dependent stories specifically — Accepted status here unblocks story creation/readiness, not that separate infrastructure gap.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core (data/integration contract) |
| **Knowledge Risk** | LOW — extends ADR-0009's already-Accepted `GameDataRegistry`/`Resource`/`validate()` convention with a new Resource subclass; reuses ADR-0021's Inventory methods and ADR-0020's direct-call criteria. No new engine subsystem. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; ADR-0009 (Resource Data Model); ADR-0016 (Inventory Storage Model); ADR-0021 (Inventory cross-system query/mutation API) |
| **Post-Cutoff APIs Used** | Typed `Dictionary[StringName, int]` (4.4+, already verified working) for `RecipeResource.inputs` |
| **Verification Required** | None beyond what `VERSION.md` already confirms for typed Dictionaries |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0009 (Resource Data Model — Accepted, `GameDataRegistry` + `validate()` convention this ADR's `RecipeResource` follows), ADR-0021 (Inventory cross-system query/mutation API — Accepted-pending, `has_items()`/`has_room_for()`/`clear_damaged_flag()` this ADR's Crafting Resolution calls), ADR-0020 (Direct-Autoload-call exception pattern — Crafting's Inventory calls are Criterion A) |
| **Enables** | `design/gdd/crafting.md` implementation stories (currently blocked pending this ADR); indirectly Equipment Forge, whose `EquipmentRecipeResource` explicitly extends this ADR's `RecipeResource` schema/pattern (`equipment-forge.md` Dependencies row) |
| **Blocks** | None further downstream within this batch |
| **Ordering Note** | Should land before the Equipment Forge ADR, since `equipment-forge.md` states its own recipe model "structurally extends `RecipeResource`" — Equipment Forge's ADR should cite this one rather than re-deriving the same schema decision. |

## Context

### Problem Statement

`design/gdd/crafting.md` is content-complete but two of its core mechanisms have no governing ADR: (1) the `RecipeResource` data schema and how it integrates with `GameDataRegistry` (TR-craft-001), and (2) the recipe discovery trigger/state-tracking mechanism (TR-craft-002) — which has a confirmed, qa-lead-flagged implementability gap: Rule 4 defines only two discovery triggers (`tech_unlocked`, `item_added`), but AC-1 requires a third, undefined trigger — an initialization/save-load-restore-time sweep — without which a recipe whose gates are already both-true at session start never fires `recipe_discovered`. Without this ADR, every Crafting implementation story is `Blocked`, and Equipment Forge's own recipe model (which explicitly extends this one) has no schema to extend.

Note: `Inventory.has_room_for()` and `Inventory.clear_damaged_flag()` (Crafting's two previously-proposed Inventory dependencies) are resolved by ADR-0021 — this ADR does not need to re-litigate them, only consume them. Likewise, `component_repaired` is already merged into `event-bus.md`'s frozen catalogue (78 events, as of 2026-07-17) — this ADR does not need to propose it, only specify when Crafting emits it.

### Constraints

- Must follow ADR-0009's established `Resource` subclass + `GameDataRegistry` + `validate()` convention — no divergent data-loading mechanism.
- Must not contradict the `resource_validation` interface contract (ADR-0009): `RecipeResource.validate() -> Array[String]` must be called by `GameDataRegistry` at boot, same as every other data Resource.
- Must resolve TR-craft-002's flagged gap by defining an explicit third discovery trigger — this ADR cannot leave AC-1 unimplementable.
- Must not introduce a second material-availability check divergent from `Inventory.has_items()` (ADR-0021) — Crafting's craftability gate is a pure consumer of that existing method, not a reimplementation.
- Repair (Rule 2, Rule 6) is explicitly not a recipe and must not be modeled as a `RecipeResource` instance — it has no `recipe_id`, never fires `recipe_discovered`, and its own state (an item's `damaged: bool` flag) already lives on `InventorySlot` per ADR-0021.

### Requirements

- `RecipeResource` fields per `crafting.md` Rule 1: `recipe_id`, `recipe_category`, `component_slot`, `inputs: Dictionary[StringName, int]`, `tech_prerequisite`, `output_item_id`, `output_quantity`, `quality_tier`.
- Two independent gates (tech, material) must both be true for craftability; `recipe_discovered` fires exactly once per `recipe_id`, permanently, the first moment both become simultaneously true (Rule 3/4).
- Discovery must be checked from three trigger paths (this ADR adds the third): `tech_unlocked`, `item_added`, and a one-time initialization/restore-time sweep.
- Discovery Ledger (`DISCOVERED` recipe set) must persist across save/load, mirroring Constellation's Discovery Ledger pattern (`crafting.md` States and Transitions explicitly cites this precedent).

## Decision

**`RecipeResource`** (static, data-driven, `GameDataRegistry`-backed, following ADR-0009's pattern exactly): one `.tres` file per recipe, loaded at boot (Autoload position 5) and validated via `validate() -> Array[String]` per the `resource_validation` contract. Repair is explicitly **not** modeled as a `RecipeResource` — it is a Crafting-owned action gated on `InventorySlot.damaged == true` (ADR-0021) and a Formula-3-derived Common-material cost, with no `recipe_id` and no discovery lifecycle.

**Discovery state machine**: a `Dictionary[StringName, bool]` Discovery Ledger, keyed by `recipe_id`, owned by Crafting, implementing `SaveRestorer` (ADR-0003) — structurally identical to Constellation's Discovery Ledger (ADR-0022), which `crafting.md`'s own States and Transitions section explicitly cites as the precedent to mirror. Three trigger paths re-check discovery, resolving TR-craft-002's flagged gap by adding the third:

1. **`tech_unlocked(tech_id, ...)`** (existing, Rule 4): for every recipe whose `tech_prerequisite == tech_id`, if `Inventory.has_items(recipe.inputs)` is already true, fire `recipe_discovered` now.
2. **`item_added(...)`** (existing, Rule 4): for every tech-gate-satisfied, not-yet-discovered recipe, re-check `has_items(inputs)`; if now true, fire `recipe_discovered`.
3. **Boot/restore-time sweep** (new — resolves TR-craft-002/AC-1): Crafting's `SaveRestorer.restore_save_data()` — called after **both** Inventory's and Defense Building's own restores complete (Crafting's `restore_order` must be strictly greater than **both** Inventory's `10` and Defense Building's, so material counts and unlocked-tech state are already correct when the sweep runs) — performs one pass over every `RecipeResource` not already `DISCOVERED` in the just-restored ledger, checking both gates (`tech_prerequisite` against Defense Building's already-restored `tech_unlocked` state, and `has_items(inputs)` against the now-restored Inventory) and firing `recipe_discovered` for any recipe that qualifies. This runs exactly once, at the end of the save-restore sequence, not on every scene load — a fresh (non-restored) game state has an empty Discovery Ledger and no recipes pre-qualify, so the sweep is a no-op on a new game. If Defense Building's tech-unlock state is not itself `SaveRestorer`-backed (i.e. it is derived or always-valid non-save-gated state), this ordering constraint reduces to Inventory-only — whichever is true must be confirmed against Defense Building's own forthcoming ADR before `restore_order` values are assigned in `save-persistence.md`'s Formula 4 table.

**Craftability** (Craft button enabled/disabled) remains, unchanged from the GDD, a continuously re-evaluated `has_items(inputs)` check on every `item_added`/`item_removed` — independent of the (permanent, one-way) Discovery Ledger. This ADR does not alter that split; it only formalizes how discovery itself becomes checkable at three points instead of two.

**Crafting Resolution** (Rule 8, already fully specified in the GDD) is implemented as a synchronous, atomic sequence calling ADR-0021's Inventory methods directly (Criterion A, ADR-0020): `has_items()` re-validate → `has_room_for()` pre-check (tower_component only) → batch-consume → `item_added` → `component_crafted`/`component_repaired` emission. This ADR does not change that sequence; it is included in the Architecture Diagram below for completeness since it is the consumer of both this ADR's `RecipeResource` and ADR-0021's Inventory API in the same call stack.

### Architecture Diagram

```
GameDataRegistry (Autoload, boot position 5)
  └─ preloads RecipeResource[] from assets/data/recipes/
       validate() called per recipe at boot (ADR-0009 contract)

Crafting (scene-instanced node, Sanctuary-only)
  ├─ owns: _discovery_ledger: Dictionary[StringName, bool]   # recipe_id -> discovered
  ├─ owns: _craft_resolving: bool                            # single-frame double-confirm guard (Edge Cases)
  ├─ implements SaveRestorer:
  │    get_save_key() -> "crafting"
  │    get_save_data() -> Dictionary (primitives only — _discovery_ledger)
  │    restore_save_data(data) -> bool   # ALSO runs the boot-time discovery sweep (trigger 3)
  │    reset_to_defaults() -> void
  ├─ registers: SavePersistence.register(self, restore_order=<TBD, > Inventory's 10>)
  ├─ reads: GameDataRegistry.get_recipe(recipe_id) -> RecipeResource
  ├─ calls (direct, Criterion A/ADR-0020): Inventory.has_items(), has_room_for(), clear_damaged_flag()
  ├─ subscribes (EventBus): tech_unlocked, item_added, item_removed
  └─ emits (EventBus): component_crafted, recipe_discovered, component_repaired
```

### Key Interfaces

```gdscript
# RecipeResource (assets/data/recipes/*.tres, loaded by GameDataRegistry)
class_name RecipeResource extends Resource
@export var recipe_id: StringName = &""
@export var recipe_category: String = ""        # "tower_component" | "crafted_good"
@export var component_slot: String = ""         # foundation|weapon|focus|power; "" unless tower_component
@export var inputs: Dictionary[StringName, int] = {}   # material_id -> quantity, 1-3 entries
@export var tech_prerequisite: StringName = &""  # "" = ungated
@export var output_item_id: StringName = &""
@export var output_quantity: int = 1
@export var quality_tier: int = 0                # 0 = N/A (crafted_good); 1-4 for tower_component
func validate() -> Array[String]: ...            # per resource_validation contract (ADR-0009)

# Crafting (scene-instanced node, implements SaveRestorer per ADR-0003)
var _discovery_ledger: Dictionary[StringName, bool] = {}
var _craft_resolving: bool = false

func get_save_key() -> String: return "crafting"
func get_save_data() -> Dictionary: return {"discovery_ledger": _discovery_ledger}
func restore_save_data(data: Dictionary) -> bool:
    # Per ADR-0003's SaveRestorer contract: return false only if the save
    # payload itself is malformed (discovery_ledger present but not a
    # Dictionary[StringName,bool]-shaped value). The boot sweep itself cannot
    # fail — GameDataRegistry.get_all_recipes() is boot-loaded/validated data,
    # and a missing/malformed individual RecipeResource is a content-authoring
    # bug caught by validate() at boot (ADR-0009), not a restore-time failure.
    var raw_ledger = data.get("discovery_ledger", {})
    if typeof(raw_ledger) != TYPE_DICTIONARY:
        return false
    _discovery_ledger = raw_ledger
    _run_boot_discovery_sweep()   # trigger 3 — resolves TR-craft-002
    return true

func _run_boot_discovery_sweep() -> void:
    for recipe: RecipeResource in GameDataRegistry.get_all_recipes():
        if _discovery_ledger.get(recipe.recipe_id, false):
            continue
        var tech_gate_ok := recipe.tech_prerequisite == &"" or DefenseBuilding.is_tech_unlocked(recipe.tech_prerequisite)
        if tech_gate_ok and Inventory.has_items(recipe.inputs):
            _fire_recipe_discovered(recipe.recipe_id, recipe.recipe_category)
```

## Alternatives Considered

### Alternative A: Recipe catalogue as a flat Dictionary/JSON, not a Resource subclass

- **Description**: Load recipes from a raw data file (JSON or custom parser) without `GameDataRegistry` integration.
- **Pros**: Simplest possible implementation.
- **Cons**: Breaks from the project's established data-driven-Resource convention (ADR-0009 already covers `MonsterResource`, `WaveConfig`, and ADR-0016 already extended it to `ItemDefinitionResource`) — a fifth, differently-loaded data format for recipes adds inconsistency and duplicates loader/validation infrastructure that already exists.
- **Rejection Reason**: No technical justification for diverging from the pattern every other content-authored system in this project already uses successfully.

### Alternative B: Leave the boot/restore-time discovery gap unresolved, defer to implementation time

- **Description**: Ship the ADR without adding a third trigger; let whoever implements Crafting decide informally whether/how to sweep at restore time.
- **Pros**: Smaller ADR.
- **Cons**: This is the exact gap qa-lead flagged as blocking AC-1 — leaving it undefined at the ADR level pushes an architecture decision (when does the sweep run, relative to Inventory's own restore) into implementation, where it's far more likely to be gotten wrong (e.g. running before Inventory restores, silently under-discovering).
- **Rejection Reason**: The ordering dependency (`Crafting.restore_order > Inventory.restore_order`) is exactly the kind of decision an ADR exists to pin down — ADR-0016 already established this pattern for Hero's ordering relative to Inventory, and this ADR should do the same for Crafting.

## Consequences

### Positive
- Resolves TR-craft-002's confirmed implementability gap — AC-1 is now specifiable as an automated test against a defined trigger, not a behavior Rule 4 didn't actually define.
- `RecipeResource` gives Equipment Forge's `EquipmentRecipeResource` a concrete schema to extend, rather than an aspirational "structurally extends" reference with nothing behind it.
- Reuses ADR-0021's Inventory API and ADR-0020's direct-call criteria without modification — no new cross-system communication pattern introduced.

### Negative
- Crafting's `restore_order` is now constrained to be strictly greater than Inventory's (10) — a new ordering invariant that must be respected if Inventory's own `restore_order` ever changes (mitigated by the same registry-checking discipline ADR-0016's own Risks section already established for Hero/Inventory ordering).
- The boot-time sweep iterates every un-discovered `RecipeResource` once per save-load — negligible at content-authoring scale (dozens of recipes, not hundreds), but worth noting as a load-time cost that scales with catalogue size.

### Risks
- **Risk**: If Crafting's `restore_order` is assigned without checking Inventory's actual registered value, the sweep could run before Inventory's data is restored, causing `has_items()` to read pre-restore (likely empty) inventory state and silently under-discover recipes that should have qualified.
  - **Mitigation**: Whoever assigns Crafting's `restore_order` in `save-persistence.md`'s Formula 4 table must confirm it is strictly greater than Inventory's 10 — flagged here explicitly, mirroring ADR-0016's own mitigation note for the same class of risk.
- **Risk** (godot-specialist validation, blocking-adjacent): if Defense Building's tech-unlock state is itself `SaveRestorer`-backed (not yet confirmed — Defense Building has no ADR yet), and its `restore_order` is not pinned strictly lower than Crafting's, the boot sweep's `DefenseBuilding.is_tech_unlocked()` calls could read stale/default tech-gate state, silently under-discovering tech-gated recipes at restore time — the same class of bug as the Inventory-ordering risk above, but for the tech gate instead of the material gate.
  - **Mitigation**: This ADR requires `Crafting.restore_order` to be strictly greater than **both** Inventory's (10) and Defense Building's (once assigned) — stated explicitly in the Decision section's boot-sweep description. Defense Building's forthcoming ADR must confirm whether its tech-unlock state is `SaveRestorer`-backed at all; if it is not (e.g. derived or always-valid state), this constraint reduces to Inventory-only and should be noted as resolved when that ADR lands.
- **Risk**: The boot-time sweep and the `tech_unlocked`/`item_added` triggers could double-fire `recipe_discovered` for the same recipe if the sweep runs after a same-session `tech_unlocked`/`item_added` has already fired it.
  - **Mitigation**: The sweep runs exactly once, at `restore_save_data()` time, before either EventBus trigger can fire in that session (both require gameplay actions that cannot occur before restore completes) — and the `_discovery_ledger.get(recipe.recipe_id, false)` early-continue in the sweep additionally makes it idempotent even if this ordering assumption is ever violated.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| crafting.md | Rule 1: `RecipeResource` schema, `GameDataRegistry`-backed | `RecipeResource` Resource subclass specified in Key Interfaces, following ADR-0009's convention exactly |
| crafting.md | Rule 3/4: two-gate discovery, fires exactly once per `recipe_id` | Discovery Ledger (`Dictionary[StringName, bool]`) with idempotent fire-once logic across all three trigger paths |
| crafting.md | AC-1 / qa-lead-flagged Open Question: no defined init/restore trigger path | Third trigger path specified: `restore_save_data()` runs a one-time boot sweep, ordered strictly after Inventory's own restore |
| crafting.md | Rule 2/6: repair is not a recipe, mutates `damaged` in place | Explicitly excluded from `RecipeResource`/discovery lifecycle; consumes ADR-0021's `clear_damaged_flag()` directly |
| crafting.md | States and Transitions: Discovery Ledger mirrors Constellation's pattern | Structurally identical `SaveRestorer`-backed `Dictionary[StringName, bool]`, same precedent ADR-0022 already established |

## Performance Implications
- **CPU**: Negligible — recipe discovery checks are gameplay-action-triggered (`tech_unlocked`, `item_added`) or one-time (boot sweep), not per-frame. No frame-budget concern, consistent with Inventory's own assessment (ADR-0016) of similar action-triggered systems.
- **Memory**: `RecipeResource` instances loaded once at boot (shared, immutable) via `GameDataRegistry`; Discovery Ledger is a small `Dictionary` bounded by total recipe count (content-authoring scale, dozens not hundreds).
- **Load Time**: Recipe definitions load alongside existing `GameDataRegistry` boot-time preloading (ADR-0009) — no new load-time phase. The boot-restore sweep adds one bounded pass over un-discovered recipes at save-load time only.
- **Network**: N/A — single-player game.

## Migration Plan
N/A — Crafting has no existing implementation to migrate from. This is a greenfield decision.

## Validation Criteria
- Unit test confirms a recipe whose gates are already both-true in a restored save fires `recipe_discovered` exactly once via the boot sweep (directly implements AC-1, previously unimplementable).
- Unit test confirms the boot sweep does not re-fire `recipe_discovered` for a recipe already `DISCOVERED` in the restored ledger.
- Unit test confirms `tech_unlocked` and `item_added` trigger paths each independently fire `recipe_discovered` exactly once (AC-2, AC-11).
- Integration test confirms Crafting's `restore_save_data()` executes after Inventory's during a save-load sequence (order-of-operations test, mirrors ADR-0016's own validation criteria for Hero/Inventory ordering).

## Related Decisions
- ADR-0009 (Resource Data Model) — `GameDataRegistry` + `validate()` pattern `RecipeResource` extends
- ADR-0016 (Inventory Storage Model) — precedent for `restore_order` ordering constraints and `SaveRestorer` implementation
- ADR-0021 (Inventory cross-system query/mutation API) — source of `has_items()`, `has_room_for()`, `clear_damaged_flag()` this ADR's Crafting Resolution calls
- ADR-0022 (Constellation Pattern-Detection Data Structure) — source of the Discovery Ledger pattern this ADR mirrors
- ADR-0020 (Direct-Autoload-call exception pattern) — governs why Crafting's Inventory calls are direct, not EventBus
- `design/gdd/crafting.md` — source GDD for all requirements this ADR addresses
