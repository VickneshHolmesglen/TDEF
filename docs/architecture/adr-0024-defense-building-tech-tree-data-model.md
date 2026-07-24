# ADR-0024: Defense Building Tech Tree and Structure Data Model

## Status
Accepted

## Date
2026-07-17

## Acceptance Note
Accepted 2026-07-17 by direct user decision during `/create-stories epic-05-sanctuary-production`, to unblock that epic's stories — outside the normal `/architecture-review` gate (which was explicitly deferred this session, see `production/session-state/active.md`). engine-specialist validation already completed at authoring time; no re-review performed at acceptance.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core (data/integration contract) |
| **Knowledge Risk** | LOW — extends ADR-0009's already-Accepted `GameDataRegistry`/`Resource`/`validate()` convention with two new Resource subclasses; reuses ADR-0021's Inventory methods, ADR-0023's Discovery-Ledger/boot-sweep pattern, and ADR-0020's direct-call criteria. No new engine subsystem. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; ADR-0009 (Resource Data Model); ADR-0023 (Crafting recipe data model — direct structural precedent for the ledger/boot-sweep pattern this ADR reuses) |
| **Post-Cutoff APIs Used** | Typed `Dictionary[StringName, int]` (4.4+, already verified working) for `material_costs` fields |
| **Verification Required** | None beyond what `VERSION.md` already confirms for typed Dictionaries |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0009 (Resource Data Model — Accepted, `GameDataRegistry` + `validate()` convention both new Resource subclasses follow), ADR-0021 (Inventory cross-system query/mutation API — `has_items()`/batch-consume this ADR's resolution sequence calls), ADR-0020 (Direct-Autoload-call exception pattern — Defense Building's Inventory/Resource Economy calls are Criterion A), ADR-0023 (Crafting recipe data model — this ADR's Discovery-Ledger/boot-sweep/`SaveRestorer` shape is structurally identical, cited directly rather than re-derived) |
| **Enables** | `design/gdd/defense-building.md` implementation stories (currently blocked pending this ADR); unblocks `crafting.md`'s `production_tech` consumer path and `menagerie.md`'s `sanctuary_structure_built` consumer path, both of which already depend on this system's exact contract (verified matching, per the GDD's own header note) |
| **Blocks** | None further downstream within this batch |
| **Ordering Note** | **Resolves ADR-0023's open ordering risk**: ADR-0023 flagged that Crafting's boot-time discovery sweep calls `DefenseBuilding.is_tech_unlocked()` with no confirmed ordering guarantee. This ADR settles that: Defense Building's tech-unlock state **is** `SaveRestorer`-backed (see Decision), so `Crafting.restore_order` must be strictly greater than **both** Inventory's (10) and Defense Building's `restore_order = 21` (already assigned in `save-persistence.md`). Crafting's own `restore_order` (left as `<TBD, > 10>` in ADR-0023) must therefore be assigned `> 21`. |

## Context

### Problem Statement

`design/gdd/defense-building.md` is content-complete (5-node tech tree, 2 independent ledgers, Habitat Expansion's exact 3-tier contract independently verified to match `menagerie.md`) but has no ADR covering the `TechNodeResource`/`StructureResource` data schemas or the unlock-gating/persistence architecture (TR-defbuild-001, TR-defbuild-003). Without this ADR, every Defense Building implementation story is `Blocked`, and — per ADR-0023's own flagged risk — Crafting's boot-time discovery sweep has an unresolved dependency on exactly the tech-unlock state this ADR defines.

### Constraints

- Must follow ADR-0009's established `Resource` subclass + `GameDataRegistry` + `validate()` convention for both `TechNodeResource` and `StructureResource` — no divergent data-loading mechanism, consistent with `RecipeResource` (ADR-0023) and `ItemDefinitionResource` (ADR-0016).
- Must implement the two ledgers (Tech Tree, Sanctuary Structures) as genuinely independent state — Core Rule 1 requires "no shared 'progression point' currency," each spending real gold/materials directly, cross-linked only via the named `tech_gate` field.
- Must resolve ADR-0023's flagged ordering risk explicitly: Defense Building's `restore_order` (already assigned `21` in `save-persistence.md`) must be confirmed lower than Crafting's, and this ADR must state whether `is_tech_unlocked()` is safe to call from another system's `restore_save_data()`.
- The `_action_resolving` guard (Edge Cases) must be a single flag shared across **both** ledgers, not one per ledger — a tech unlock and a structure build could otherwise double-spend the same gold balance in the same frame if allowed to resolve concurrently.
- Must not introduce a second gold-balance-ownership mechanism — Core Rule 7 explicitly defers that (a pre-existing, project-wide open gap shared with Tower System) rather than inventing a Defense-Building-local resolution; this ADR must not contradict that deferral.

### Requirements

- `TechNodeResource` fields (Rule 2): `tech_id`, `tech_category`, `prerequisite_tech_id`, `branch_tier`, `gold_cost`/`material_costs`, `gates` (content-authoring only, not consulted at runtime).
- `StructureResource` fields (Rule 4): `structure_id`, `structure_type`, `tier`, `prerequisite_structure_id`, `tech_gate`, `gold_cost`/`material_costs`.
- Both ledgers use the same three-state shape (`LOCKED_PREREQ` / `AVAILABLE` / `UNLOCKED`-or-`BUILT`), but only the terminal state needs persisted storage — `LOCKED_PREREQ` vs. `AVAILABLE` is fully derivable at query time from the prerequisite chain and current gold/material state, mirroring Crafting's own discovery-vs-craftability split (ADR-0023).
- Resolution (Rule 9) must be synchronous and atomic per confirm: prerequisite/tech-gate re-validate → cost re-validate → gold debit → material consume → ledger write → event emission.
- `restore_order = 21` (already assigned in `save-persistence.md`'s Formula 4 table) — this ADR only needs to confirm it is compatible with Crafting's ordering requirement, not re-derive it.

## Decision

**Two Resource subclasses**, both `GameDataRegistry`-backed at boot (Autoload position 5), following ADR-0009's convention exactly — mirrors `RecipeResource` (ADR-0023) field-for-field in structure, differing only in domain-specific fields:

- **`TechNodeResource`**: `tech_id: StringName`, `tech_category: String`, `prerequisite_tech_id: StringName`, `branch_tier: int`, `gold_cost: int`, `material_costs: Dictionary[StringName, int]`, `gates: String` (content-authoring documentation field only — never read at runtime, since actual gating is enforced entirely on the *consumer* side, e.g. Crafting checking `tech_prerequisite` against `tech_unlocked` history, not by Defense Building pushing gate logic outward).
- **`StructureResource`**: `structure_id: StringName`, `structure_type: String`, `tier: int`, `prerequisite_structure_id: StringName`, `tech_gate: StringName`, `gold_cost: int`, `material_costs: Dictionary[StringName, int]`.

**Two independent ledgers**, both `Dictionary[StringName, bool]` (mirrors Crafting's and Constellation's Discovery Ledger shape exactly, per ADR-0023/ADR-0022 precedent), owned by Defense Building: `_tech_ledger` (keyed `tech_id`, `true` = `UNLOCKED`) and `_structure_ledger` (keyed `structure_id`, `true` = `BUILT`). Neither ledger stores `LOCKED_PREREQ`/`AVAILABLE` state — both are computed on demand: a node/structure is `AVAILABLE` iff its prerequisite chain resolves `true` against the ledger (and, for structures, its `tech_gate` also resolves `true` against `_tech_ledger`) and it is not already in the ledger as `true`; it is `LOCKED_PREREQ` otherwise. This avoids any risk of the derived state (locked/available) drifting out of sync with the authoritative terminal state (unlocked/built).

**Persistence**: Defense Building implements `SaveRestorer` (ADR-0003) at `restore_order = 21` (already assigned in `save-persistence.md`). `get_save_data()` returns both ledgers as flat `Dictionary[String, bool]` (StringName keys serialize as String, matching every other `SaveRestorer` implementor's convention in this project) — already primitive-only, satisfying `resource_object_in_save_data` (ADR-0003) by construction. **`is_tech_unlocked(tech_id: StringName) -> bool` is safe to call from another system's `restore_save_data()` if and only if that system's own `restore_order` is greater than 21** — this is the exact guarantee ADR-0023's Crafting boot sweep needs, and it resolves that ADR's flagged risk: Crafting's `restore_order` must be assigned `> 21` (not merely `> 10`) in `save-persistence.md`'s Formula 4 table.

**Resolution sequence** (Rule 9, both ledgers share one path shape): on confirm — (a) re-validate prerequisite chain and tech-gate (derived check against the ledgers, no cost touched), (b) re-validate gold balance and `Inventory.has_items(material_costs)` (Criterion A direct calls, ADR-0020/ADR-0021), (c) debit gold via `resources_changed(-cost, "tech_unlock"|"structure_built")`, (d) consume materials via `Inventory`'s batch-consume, (e) write `true` into the relevant ledger, (f) emit `tech_unlocked`/`sanctuary_structure_built`. All steps execute within one synchronous call, guarded by a single `_action_resolving: bool` flag shared across **both** ledgers (not two separate flags) — set at the start of step (a), cleared only after step (f), rejecting any second confirmation received while `true`, closing the double-spend race Edge Cases flags for a same-frame tech-unlock-and-structure-build pair.

Gold-balance ownership itself (who is authoritative, who validates affordability project-wide) is explicitly **not** resolved by this ADR — Core Rule 7 defers this as a pre-existing, shared gap with Tower System, to be resolved in one project-wide pass, not per-consumer. This ADR's step (b)/(c) follow the same self-debit convention every other gold-spending system in this project currently uses (`resources_changed(-cost, source)`), with no new pattern introduced.

### Architecture Diagram

```
GameDataRegistry (Autoload, boot position 5)
  └─ preloads TechNodeResource[] and StructureResource[] from assets/data/{tech,structures}/
       validate() called per resource at boot (ADR-0009 contract)

DefenseBuilding (Autoload — required for is_tech_unlocked() to be callable as a
bare global from Crafting's restore path, per ADR-0020's Criterion A: every
existing direct-call callee — Grid, GameDataRegistry, MissionEconomy, Inventory
(resolved 2026-07-17, ADR-0016 Last Verified) — is an Autoload; a scene-instanced
callee would require the caller to hold a node reference, violating ADR-0001's
direct_cross_system_node_reference ban. Boot position: #10, appended after
Inventory (#9) — Defense Building calls Inventory's methods (has_items(),
batch-consume), so Inventory must be available first; #9 was DefenseBuilding's
original assignment but was reassigned to Inventory when that ADR-0016 gap was
resolved in the same session. Gameplay behavior remains Sanctuary-only per Rule
11; being an Autoload only affects lifetime/callability, not when its screen is
accessible.)
  ├─ owns: _tech_ledger: Dictionary[StringName, bool]        # tech_id -> unlocked
  ├─ owns: _structure_ledger: Dictionary[StringName, bool]   # structure_id -> built
  ├─ owns: _action_resolving: bool                           # shared guard, both ledgers
  ├─ implements SaveRestorer:
  │    get_save_key() -> "defense_building"
  │    get_save_data() -> Dictionary (primitives only — both ledgers)
  │    restore_save_data(data) -> bool
  │    reset_to_defaults() -> void
  ├─ registers: SavePersistence.register(self, restore_order=21)   # matches save-persistence.md
  ├─ reads: GameDataRegistry.get_tech_node(tech_id) / get_structure(structure_id)
  ├─ calls (direct, Criterion A/ADR-0020): Inventory.has_items(), batch-consume; ResourceEconomy gold read
  ├─ exposes (direct, Criterion A/ADR-0020): is_tech_unlocked(tech_id) -> bool — callable safely
  │    from another system's restore_save_data() ONLY IF that system's restore_order > 21
  └─ emits (EventBus): tech_unlocked, sanctuary_structure_built, resources_changed(-cost, ...)
```

### Key Interfaces

```gdscript
# TechNodeResource (assets/data/tech/*.tres, loaded by GameDataRegistry)
class_name TechNodeResource extends Resource
@export var tech_id: StringName = &""
@export var tech_category: String = ""              # "production_tech" | "structural_tech"
@export var prerequisite_tech_id: StringName = &""   # "" = root node
@export var branch_tier: int = 1                     # 1-3
@export var gold_cost: int = 0
@export var material_costs: Dictionary[StringName, int] = {}
@export var gates: String = ""                       # content-authoring documentation only
func validate() -> Array[String]: ...                # per resource_validation contract (ADR-0009)

# StructureResource (assets/data/structures/*.tres, loaded by GameDataRegistry)
class_name StructureResource extends Resource
@export var structure_id: StringName = &""
@export var structure_type: String = ""
@export var tier: int = 1
@export var prerequisite_structure_id: StringName = &""  # "" = Tier 1 / untiered
@export var tech_gate: StringName = &""                  # "" = ungated
@export var gold_cost: int = 0
@export var material_costs: Dictionary[StringName, int] = {}
func validate() -> Array[String]: ...

# DefenseBuilding (Autoload #10, implements SaveRestorer per ADR-0003)
var _tech_ledger: Dictionary[StringName, bool] = {}
var _structure_ledger: Dictionary[StringName, bool] = {}
var _action_resolving: bool = false

func is_tech_unlocked(tech_id: StringName) -> bool:
    return _tech_ledger.get(tech_id, false)

func get_save_key() -> String: return "defense_building"
func get_save_data() -> Dictionary:
    return {"tech_ledger": _tech_ledger, "structure_ledger": _structure_ledger}
func restore_save_data(data: Dictionary) -> bool:
    var raw_tech = data.get("tech_ledger", {})
    var raw_struct = data.get("structure_ledger", {})
    if typeof(raw_tech) != TYPE_DICTIONARY or typeof(raw_struct) != TYPE_DICTIONARY:
        return false
    _tech_ledger = raw_tech
    _structure_ledger = raw_struct
    return true
```

## Alternatives Considered

### Alternative A: Single unified ledger with a shared "progression point" currency

- **Description**: Both tech nodes and structures draw from one abstracted progression-point pool rather than spending gold/materials directly.
- **Pros**: Simpler UI framing ("you have N progression points to spend").
- **Cons**: Directly contradicts Core Rule 1's explicit requirement — "no single unified 'progression point' currency spanning both; each spends real gold/materials directly" — and Core Rule 7's rationale that Defense Building deliberately uses gold+materials together specifically *because* it's the largest-scale investment category, distinct from Crafting/Menagerie's materials-only convention.
- **Rejection Reason**: The GDD is explicit and testable on this point (AC-1/AC-2) — this alternative fails by construction.

### Alternative B: Store `LOCKED_PREREQ`/`AVAILABLE`/`UNLOCKED` as an explicit 3-state enum per entry, persisted directly

- **Description**: Instead of deriving `LOCKED_PREREQ`/`AVAILABLE` at query time, store the full 3-state value per `tech_id`/`structure_id` and persist all three states.
- **Pros**: No derivation logic needed at query time.
- **Cons**: `AVAILABLE` depends on live gold/material affordability (a continuously-changing value per the GDD's own "affordability is a sub-state of Available" framing) — persisting it would require re-deriving it on every load anyway to stay correct, making the persisted value redundant at best and a stale-data risk at worst if a save is loaded after material counts changed.
- **Rejection Reason**: Deriving `LOCKED_PREREQ`/`AVAILABLE` from the single persisted terminal-state ledger (mirrors Crafting's discovery-vs-craftability split, ADR-0023) is strictly simpler and cannot drift out of sync, since there is only one source of truth (the terminal state) rather than three states that must be kept mutually consistent.

## Consequences

### Positive
- Resolves ADR-0023's flagged ordering risk explicitly — Crafting's boot sweep now has a confirmed, ADR-backed guarantee (`Crafting.restore_order > 21`) rather than an open question.
- Both `TechNodeResource` and `StructureResource` give content authors a concrete, validated schema, following the exact pattern every other data-driven system in this project already uses.
- The single shared `_action_resolving` guard across both ledgers closes the cross-ledger double-spend race explicitly, rather than leaving it to two independently-guarded ledgers that could still race against each other.

### Negative
- Defense Building's `restore_order = 21` is now a hard upper bound that Crafting (and potentially other future consumers of `is_tech_unlocked()`) must respect — a new ordering invariant to track alongside Inventory's 10, mirroring the same class of constraint ADR-0016 first established.
- Two separate Resource subclasses (`TechNodeResource`, `StructureResource`) rather than one unified schema — a small duplication of `gold_cost`/`material_costs` fields across both, though this mirrors the GDD's own explicit statement that the two ledgers are "cross-linked only at specific, named points," not a single data model.

### Risks
- **Risk**: A future system other than Crafting might call `is_tech_unlocked()` from its own `restore_save_data()` without checking its `restore_order` against Defense Building's 21, reintroducing the same class of bug this ADR fixes for Crafting specifically.
  - **Mitigation**: The `is_tech_unlocked()` contract in Key Interfaces states the ordering requirement explicitly as part of its own documentation, not only in this ADR's prose — any future ADR author consuming this method should find the constraint at the call site, not have to rediscover it.
- **Risk**: `gates: String` (Rule 2's free-text content-authoring field) could be mistaken for a runtime-consulted field by a future implementer, given every other field on `TechNodeResource` *is* consulted at runtime.
  - **Mitigation**: Explicitly called out in the Decision section and the Key Interfaces code comment as "never read at runtime" — flagged here so the distinction is visible at the ADR level, not just in the GDD's own field table.
- **Risk** (godot-specialist validation, blocking — resolved by this revision): the original draft classified `DefenseBuilding` as a scene-instanced node while having Crafting call `DefenseBuilding.is_tech_unlocked()` as a bare global — a scene-instanced node cannot be called this way without the caller holding a direct node reference, which ADR-0001 forbids. Separately: per ADR-0003's actual registration mechanism (`SavePersistence.register(self, restore_order)` called from each system's own `_ready()`; `_restore_all_systems()` runs as one later, separately-triggered batch sorted by `restore_order` — not tied to Autoload boot order), `restore_save_data()` calls only begin once *every* registered system has already completed its own `_ready()`. This means `is_tech_unlocked()` being called from Crafting's `restore_save_data()` is safe **only if Crafting's own registration (`_ready()`) has already happened by the time `_restore_all_systems()` fires** — true regardless of whether Crafting is Autoload or scene-instanced, since registration and restore are two separate, sequential phases, not one.
  - **Mitigation**: `DefenseBuilding` is now specified as an Autoload (fixed above), resolving the callability half of this risk. The registration-before-restore half is guaranteed structurally by ADR-0003's own two-phase design (all `register()` calls complete before `_restore_all_systems()` begins) and is not a new risk this ADR introduces — but implementers should verify Crafting's scene-instanced `_ready()` fires before Save & Persistence's restore trigger point (typically a `SceneManager`-driven Sanctuary-scene-loaded signal), not assume it from this ADR alone.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| defense-building.md | Rule 1: two independent ledgers, no shared currency | `_tech_ledger`/`_structure_ledger` as separate `Dictionary[StringName, bool]`, cross-linked only via `tech_gate` |
| defense-building.md | Rule 2/4: `TechNodeResource`/`StructureResource` schemas | Both specified as `GameDataRegistry`-backed Resource subclasses in Key Interfaces, following ADR-0009's convention |
| defense-building.md | States and Transitions: 3-state shape, only terminal state persisted | `LOCKED_PREREQ`/`AVAILABLE` derived at query time from the ledger + prerequisite chain; only `UNLOCKED`/`BUILT` is stored |
| defense-building.md | Rule 9/Edge Cases: `_action_resolving` shared across both ledgers | Single `bool` flag specified in Key Interfaces, guarding the full resolution sequence for either ledger |
| defense-building.md | Dependencies: `restore_order = 21` | Confirmed compatible with, and now the explicit lower bound for, Crafting's own `restore_order` requirement (ADR-0023) |

## Performance Implications
- **CPU**: Negligible — resolution is gameplay-action-triggered (Sanctuary-only, instant-on-confirm per Rule 9), not per-frame. No frame-budget concern.
- **Memory**: `TechNodeResource`/`StructureResource` instances loaded once at boot (shared, immutable) via `GameDataRegistry`; both ledgers are small `Dictionary`s bounded by content-authoring scale (5 tech nodes, a handful of structures at Alpha scope).
- **Load Time**: Resource definitions load alongside existing `GameDataRegistry` boot-time preloading (ADR-0009) — no new load-time phase.
- **Network**: N/A — single-player game.

## Migration Plan
N/A — Defense Building has no existing implementation to migrate from. This is a greenfield decision.

## Validation Criteria
- Unit test confirms `LOCKED_PREREQ`/`AVAILABLE` are correctly derived (never persisted) for a range of prerequisite-chain and ledger states, matching AC-4 through AC-6.
- Unit test confirms the Habitat Expansion 3-tier sequence (AC-15) resolves end-to-end with exact `structure_id`/`structure_type` payload values on each `sanctuary_structure_built` emission.
- Unit test confirms `_action_resolving` rejects a second confirmation (either ledger) received while the first is still resolving, closing the cross-ledger double-spend race.
- Integration test confirms Defense Building's `restore_save_data()` executes before Crafting's during a save-load sequence (order-of-operations test, mirrors ADR-0016's and ADR-0023's own validation criteria for the same class of ordering dependency).

## Related Decisions
- ADR-0009 (Resource Data Model) — `GameDataRegistry` + `validate()` pattern both new Resource subclasses extend
- ADR-0021 (Inventory cross-system query/mutation API) — source of `has_items()`/batch-consume this ADR's resolution sequence calls
- ADR-0023 (Crafting recipe data model) — direct structural precedent for the Discovery-Ledger/boot-sweep/`SaveRestorer` shape; this ADR resolves ADR-0023's flagged ordering risk
- ADR-0020 (Direct-Autoload-call exception pattern) — governs why Defense Building's Inventory/Resource Economy calls are direct, not EventBus
- `design/gdd/defense-building.md` — source GDD for all requirements this ADR addresses
