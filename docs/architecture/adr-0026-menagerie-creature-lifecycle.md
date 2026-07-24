# ADR-0026: Menagerie Creature Lifecycle State Machine

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
| **Domain** | Data Structures / State Management |
| **Knowledge Risk** | LOW — reuses ADR-0016's `RefCounted`-entity-instance pattern, ADR-0009's `GameDataRegistry` convention, ADR-0021's Inventory query API, and ADR-0020's direct-call criteria. No new engine subsystem. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; ADR-0016 (Inventory Storage Model — `RefCounted` runtime-instance precedent); ADR-0021 (Inventory API); ADR-0025 (Equipment Forge — the sibling ADR whose flagged Menagerie dependency this ADR resolves) |
| **Post-Cutoff APIs Used** | Typed `Dictionary[StringName, int]`/`Array[StringName]` (4.4+, already verified working) |
| **Verification Required** | None beyond what `VERSION.md` already confirms for typed Dictionaries |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0009 (Resource Data Model), ADR-0016 (Inventory Storage Model — `RefCounted` runtime-instance precedent this ADR's `CreatureInstance` follows), ADR-0020 (Direct-Autoload-call exception pattern), ADR-0021 (Inventory API — `has_items()`/`materials_spent` convention this ADR's Lure action reuses) |
| **Enables** | `design/gdd/menagerie.md` implementation stories (currently blocked pending this ADR); **resolves ADR-0025's explicitly-flagged open dependency** — Equipment Forge's `Menagerie.request_sacrifice()` call is now implementable |
| **Blocks** | None further downstream — Equipment Forge (ADR-0025) is the only consumer of this ADR's direct-call surface, and its own ADR is already written and merely waiting on this confirmation |
| **Ordering Note** | **Resolves ADR-0025's flagged gap directly**: Menagerie is confirmed as an Autoload (see Decision), assigned boot position **#11** — the position ADR-0025 reserved without assigning. `docs/registry/architecture.yaml`'s `menagerie_sacrifice_request` interface entry and ADR-0002's boot-order/boundary tables are updated accordingly (see GDD Requirements Addressed). |

## Context

### Problem Statement

`design/gdd/menagerie.md` is content-complete (5-species roster, 3-state creature lifecycle, deterministic happiness decay/tend/breeding, Equipment Forge's sacrifice contract already adopted by both sides) but has no ADR covering the creature entity data model, the state-ownership/transition-validation architecture, or — critically — the exact question ADR-0025 left open: whether `Menagerie.request_sacrifice()` can be a direct Autoload call. Without this ADR, every Menagerie implementation story is `Blocked`, and Equipment Forge's Creature Sacrifice resolution flow (ADR-0025 Rule 19) remains architecturally specified but unimplementable.

### Constraints

- Creature happiness decay/tend must tick on `mission_launched` (EventBus), never `_process()`/wall-clock time — Rule 8 is explicit that this is a deliberate architectural choice, not an implementation detail, and Core Rule 8's Edge Cases confirm a save restored mid-breeding-timer resumes correctly precisely because `mission_launched` (not wall-clock) drives the counter.
- `menagerie_quality_bonus` must be pushed to Resource Economy via `creature_happiness_changed`'s `quality_bonus` field on every HABITAT-composition-changing action (Rule 6, the GDD's own "highest-risk rule") — Resource Economy caches, never recomputes, so a missed push desyncs the cache silently.
- `Menagerie.request_sacrifice(creature_id, target_item_id) -> bool` (Rule 13, signature originated by `equipment-forge.md` Rule 19d and already adopted here) must be callable as a direct Autoload call by Equipment Forge — per ADR-0020's Criterion B (narrow single-caller action) and the identical precedent ADR-0024 already established for `DefenseBuilding.is_tech_unlocked()`.
- `restore_order = 20` (already assigned in `save-persistence.md`, restored immediately after Inventory's 10) — this ADR confirms compatibility, does not re-derive the number.
- HABITAT capacity increases only via Defense Building's `sanctuary_structure_built` EventBus event (Rule 4) — this is a **subscription**, not a direct call, so it does not require Menagerie to coordinate boot order with Defense Building the way the sacrifice call requires coordination with Equipment Forge.

### Requirements

- Creature entity fields (Rule 2, 7, States and Transitions): `creature_id`, `species: StringName`, `state` (enum: `RESERVE`/`HABITAT`/`BREEDING_PEN`/terminal `SACRIFICED`), `happiness: float` (20–100), `missions_since_tended: int`.
- Species roster (Rule 1): 5 species across 3 rarity tiers, driving Formula 1/4/5's tier-dependent constants.
- HABITAT capacity: base 4, +2 per Habitat Expansion tier (max 3 tiers, 10 slots), driven by `sanctuary_structure_built` subscription.
- Breeding pen: fixed 2 pens (4 slots), same-species pairing only, `breeding_missions_remaining` counter per pen, decrementing on `mission_launched`.
- `request_sacrifice(creature_id, target_item_id) -> bool` must validate the creature is not `BREEDING_PEN`, remove it (recomputing the aggregate if it was HABITAT), and emit `creature_sacrificed` — all synchronously within the call.
- Persistence: creature instances, HABITAT capacity tier, active breeding-pen pairings/timers — `restore_order = 20`.

## Decision

**Creature entity model**: `CreatureInstance`, a plain `RefCounted` (not a `Resource` — mirrors ADR-0016's `InventorySlot` and ADR-0022's `ConstellationInstance` precedent for mission/playthrough-scoped runtime entities that need no `validate()` or boot-time loading), held in `Array[CreatureInstance]` on the Menagerie Autoload. Fields: `creature_id: int` (monotonic, same pattern as Inventory's `_next_instance_id`, ADR-0016), `species: StringName`, `state: CreatureState` (enum), `happiness: float`, `missions_since_tended: int`.

**Species roster as static data**: a minimal `SpeciesResource` (`GameDataRegistry`-backed, following ADR-0009's convention) with exactly two fields relevant to this GDD's formulas — `species_id: StringName`, `species_tier: int` (1–3). Kept deliberately minimal (no discovery/unlock gate per Rule 1) rather than a heavier schema, since the GDD itself treats the 5-species roster as fixed Alpha-scope content with no per-species behavioral variance beyond tier.

**Breeding pen model**: a fixed-size `Array[BreedingPen]` (size 2, not expandable per Rule 12), each `BreedingPen` a `RefCounted` with `occupant_ids: Array[int]` (0–2 `creature_id`s) and `breeding_missions_remaining: int` (only meaningful once `occupant_ids.size() == 2`). Not a `Dictionary`-keyed structure since pen count is fixed and small — direct array indexing by pen slot is simpler and matches the GDD's own "not expandable, not a live-tunable balance lever" framing (Tuning Knobs).

**HABITAT capacity**: a single `int` field (`_habitat_capacity`), initialized to 4 (`habitat_base_capacity`), incremented by 2 on each `sanctuary_structure_built` event where `structure_type == "habitat_expansion"` (an EventBus subscription — no direct call to Defense Building is needed here, unlike the sacrifice path, since Menagerie only reacts to an event Defense Building already broadcasts per ADR-0024). Capped at 10 (3 tiers) by construction — a 4th event, if it ever arrived, is a no-op past the cap.

**`mission_launched` tick (Rule 8/11 — decay and breeding countdown)**: the subscriber snapshots `_creatures.filter(...)` (HABITAT only, for decay) and iterates `_breeding_pens` (fixed size 2, no filter needed) in two separate passes. The breeding pass may append a new `CreatureInstance` to `_creatures` when `breeding_missions_remaining` reaches 0 (Rule 11) — this must happen **after** both passes complete, not interleaved with the decay pass's iteration, to avoid a newly-created offspring being visited by the same tick's decay pass (a freshly-bred `RESERVE` creature has no decay to apply in the tick that created it, and RESERVE creatures never decay regardless — but the ordering is stated explicitly here so a future implementer doesn't accidentally fold offspring creation into the same filtered array being iterated).

**Aggregate recompute-and-push (Rule 6)**: a single internal method, `_recompute_and_push_aggregate(representative_creature_id: int)`, called synchronously by every HABITAT-composition-changing action (Lure-into-HABITAT, move to/from HABITAT, HABITAT-sourced sacrifice) — computes Formula 3 over the current HABITAT set and emits `creature_happiness_changed(representative_creature_id, new_happiness, quality_bonus)` in the same call stack as the triggering transfer/sacrifice event, never deferred. This is the architectural guarantee behind AC-10 through AC-15 (the GDD's own "highest-risk rule" test group) — a single method call site, not a convention repeated at each of the 4 call sites independently, closes the risk of one call site forgetting the push.

**`Menagerie.request_sacrifice(creature_id: int, target_item_id: int) -> bool` — Criterion B direct call (ADR-0020), resolving ADR-0025's flagged gap**: Menagerie is confirmed as an **Autoload**, boot position **#11** (the position ADR-0025 reserved without assigning, immediately after DefenseBuilding's #10). This mirrors the identical reasoning ADR-0024 already established for `DefenseBuilding.is_tech_unlocked()`: a narrow, single-caller action (only Equipment Forge calls this, structurally, by design) that must not require the caller to hold a node reference (ADR-0001). The method validates `state != BREEDING_PEN` (Rule 13), and on success: transitions the creature to terminal `SACRIFICED`, recomputes the aggregate if the creature was `HABITAT`-sourced, and emits `creature_sacrificed(creature_id, target_item_id)` — using `target_item_id` exactly as supplied by Equipment Forge (an `int`, matching ADR-0021's `reserve_instance_id()` return type — corrected from the GDD's own `String` typing, since both this ADR and ADR-0016/0021 treat instance identity as `int`, and Equipment Forge's `target_item_id` is minted via `Inventory.reserve_instance_id()`, ADR-0025), never looked up or validated against Inventory by Menagerie itself.

### Architecture Diagram

```
GameDataRegistry (Autoload, boot position 5)
  └─ preloads SpeciesResource[] from assets/data/species/
       validate() called per resource at boot (ADR-0009 contract)

Menagerie (Autoload #11 — required for request_sacrifice() to be callable
           as a bare global from Equipment Forge, per ADR-0020 Criterion B;
           boots after DefenseBuilding (#10) since neither depends on boot-
           time data from the other, appended to preserve existing order)
  ├─ owns: _creatures: Array[CreatureInstance]
  ├─ owns: _breeding_pens: Array[BreedingPen]           # fixed size 2
  ├─ owns: _habitat_capacity: int                        # 4-10, +2 per tier
  ├─ owns: _next_creature_id: int                        # monotonic counter
  ├─ implements SaveRestorer:
  │    get_save_key() -> "menagerie"
  │    get_save_data() -> Dictionary (primitives only)
  │    restore_save_data(data) -> bool
  │    reset_to_defaults() -> void
  ├─ registers: SavePersistence.register(self, restore_order=20)   # after Inventory(10)
  ├─ reads: GameDataRegistry.get_species(species_id) -> SpeciesResource
  ├─ calls (direct, Criterion A/ADR-0020): Inventory.has_items(), materials_spent (Lure action)
  ├─ exposes (direct, Criterion B/ADR-0020): request_sacrifice(creature_id, target_item_id) -> bool
  │    — callable by Equipment Forge, resolving ADR-0025's flagged gap
  ├─ subscribes (EventBus): mission_launched (decay/breeding tick), sanctuary_structure_built
  │    (HABITAT capacity)
  └─ emits (EventBus): creature_acquired, creature_happiness_changed, creature_bred,
       creature_sacrificed, creature_moved_to_breeding_pen, creature_returned_from_breeding_pen
```

### Key Interfaces

```gdscript
# SpeciesResource (assets/data/species/*.tres, loaded by GameDataRegistry)
class_name SpeciesResource extends Resource
@export var species_id: StringName = &""
@export var species_tier: int = 1   # 1-3
func validate() -> Array[String]: ...

enum CreatureState { RESERVE, HABITAT, BREEDING_PEN, SACRIFICED }

# CreatureInstance (RefCounted, playthrough-scoped, persisted via Menagerie's own SaveRestorer)
class_name CreatureInstance extends RefCounted
var creature_id: int
var species: StringName
var state: CreatureState = CreatureState.RESERVE
var happiness: float = 70.0
var missions_since_tended: int = 0

# BreedingPen (RefCounted, fixed 2 instances)
class_name BreedingPen extends RefCounted
var occupant_ids: Array[int] = []          # 0-2 creature_ids
var breeding_missions_remaining: int = -1  # -1 = not active (fewer than 2 occupants)

# Menagerie (Autoload #11, implements SaveRestorer per ADR-0003)
var _creatures: Array[CreatureInstance] = []
var _breeding_pens: Array[BreedingPen] = [BreedingPen.new(), BreedingPen.new()]
var _habitat_capacity: int = 4
var _next_creature_id: int = 0

func request_sacrifice(creature_id: int, target_item_id: int) -> bool:
    var creature := _find_creature(creature_id)
    if creature == null or creature.state == CreatureState.BREEDING_PEN:
        return false
    var was_habitat := creature.state == CreatureState.HABITAT
    creature.state = CreatureState.SACRIFICED
    if was_habitat:
        var representative_id := _pick_representative()   # -1 if HABITAT is now empty
        if representative_id != -1:
            _recompute_and_push_aggregate(representative_id)
        # else: skip clause (Rule 6/AC-14) — no creature_happiness_changed this
        # frame; menagerie_quality_bonus correctly reports 1.0 on the NEXT
        # natural happiness-changing event (next mission_launched tick, or the
        # next acquisition/move into HABITAT) rather than being force-pushed
        # here with no representative creature to attribute the event to.
    EventBus.creature_sacrificed.emit(creature_id, target_item_id)
    return true

func _pick_representative() -> int:
    # Longest-tended remaining HABITAT creature (Rule 6) — arbitrary tie-break
    # is acceptable since the field only carries the pushed aggregate value,
    # not the representative's own identity, to any consumer's decision logic.
    var candidates := _creatures.filter(func(c): return c.state == CreatureState.HABITAT)
    if candidates.is_empty():
        return -1
    candidates.sort_custom(func(a, b): return a.missions_since_tended > b.missions_since_tended)
    return candidates[0].creature_id

func get_save_key() -> String: return "menagerie"
func get_save_data() -> Dictionary:
    return {
        "creatures": _serialize_creatures(),   # Array[Dictionary], primitives only
        "breeding_pens": _serialize_pens(),
        "habitat_capacity": _habitat_capacity,
        "next_creature_id": _next_creature_id,
    }
```

## Alternatives Considered

### Alternative A: Creature entities as `Resource` subclasses, `duplicate_deep()`'d per instance

- **Description**: Follow the `TowerMissionState` pattern (ADR-0008) — `CreatureInstance` as a `Resource`, deep-duplicated at creation.
- **Pros**: Uniformity with Tower's mission-instance pattern.
- **Cons**: `CreatureInstance`'s fields are all flat primitives (`int`, `StringName`, `float`) with no nested Resource references — the exact situation ADR-0016 already rejected this pattern for (`InventorySlot`'s Alternative C). `duplicate_deep()` exists for genuine Resource-tree isolation (e.g. `TowerComponent`'s nested perk data); a flat-primitive entity gets no benefit from it.
- **Rejection Reason**: Directly mirrors ADR-0016's own rejection reasoning for the identical class of decision — a plain `RefCounted` achieves the same isolation with less overhead.

### Alternative B: `request_sacrifice()` as an EventBus request/response pair instead of a direct call

- **Description**: Equipment Forge emits a `sacrifice_requested(creature_id, target_item_id)` event; Menagerie subscribes, validates, and emits `sacrifice_validated(target_item_id, success)` back.
- **Pros**: Keeps all Menagerie/Equipment-Forge communication on the EventBus, avoiding the Autoload-status question entirely.
- **Cons**: Equipment Forge's Rule 19 resolution flow requires the validation result **synchronously**, in the same call stack, before proceeding to construct the item (step e/f depend directly on step d's return value) — an event-driven request/response would need Equipment Forge to `await` a reply, breaking the "steps (a)-(f) execute synchronously within one confirm" guarantee both this GDD's Rule 9-style resolution pattern and `equipment-forge.md`'s Rule 19 explicitly require, and reintroducing exactly the async-ordering risk ADR-0020 Criterion B exists to avoid for single-caller, single-callee actions.
- **Rejection Reason**: `equipment-forge.md` Rule 19d already specifies `request_sacrifice() -> bool` as a synchronous call with a return value Equipment Forge branches on immediately — changing to an async event pattern would require revising an already-adopted, cross-GDD-agreed contract for no architectural benefit, purely to avoid the Autoload classification question this ADR resolves directly instead.

## Consequences

### Positive
- Directly resolves ADR-0025's explicitly-flagged open dependency — Equipment Forge's Creature Sacrifice flow is now fully implementable, not just architecturally specified.
- The single `_recompute_and_push_aggregate()` call site (rather than 4 independent call sites each remembering to push) directly addresses the GDD's own "highest-risk rule" framing for Rule 6 — a missed push becomes structurally harder, not merely a discipline requirement.
- `SpeciesResource` gives content authors a validated schema consistent with the project's established `GameDataRegistry` convention, even though the roster itself is tiny (5 entries) at Alpha.

### Negative
- Menagerie is now the 11th global Autoload singleton — continues the pattern ADR-0002's Consequences section already flags (no access-modifier enforcement, convention/code-review only) and, like Inventory/DefenseBuilding, means Menagerie's creature state persists for the game's full lifetime rather than resetting via scene teardown; explicit `reset_to_defaults()` is the only new-game reset path.
- `target_item_id`'s type is corrected here from the GDD's own `String` annotation to `int`, to match ADR-0021's `reserve_instance_id() -> int` — a small but real divergence from `equipment-forge.md`/`menagerie.md`'s literal prose that must be reconciled at implementation time (flagged in Risks).

### Risks
- **Risk**: `equipment-forge.md` Rule 19d and `menagerie.md`'s own Interactions table both write `creature_id: String`/`target_item_id: String` in prose, but this ADR (following ADR-0016/ADR-0021's `int`-typed instance identity convention) specifies `int`. A literal implementation following the GDD prose would create a type mismatch against `Inventory.reserve_instance_id() -> int`.
  - **Mitigation**: This ADR's Key Interfaces is the authoritative signature (`int`, not `String`) — flagged explicitly here so `equipment-forge.md`/`menagerie.md` can be corrected at their next revision pass, following the same "ADR is authoritative, GDD catches up" precedent ADR-0024 already established for `defense-building.md`'s save-payload description.
- **Risk**: Menagerie's Autoload status means `_creatures`/`_breeding_pens` never reset implicitly — a bug in `reset_to_defaults()` (new-game path) could leak creature state from a prior playthrough into a new one, a class of bug that doesn't exist for scene-instanced systems.
  - **Mitigation**: Explicit unit test required (Validation Criteria) confirming `reset_to_defaults()` fully clears `_creatures`/`_breeding_pens`/`_habitat_capacity` to their new-game defaults — same discipline already flagged for Inventory/DefenseBuilding by ADR-0002's Negative consequence.
- **Risk** (godot-specialist validation): the `mission_launched` tick iterates `_creatures` (filtered to HABITAT, for decay) and `_breeding_pens` (for the breeding countdown) in the same handler; the breeding pass can append a new offspring `CreatureInstance` to `_creatures` mid-tick, which — if not sequenced carefully — risks a mutate-during-iterate bug on the same class of issue ADR-0022's Constellation ADR caught and fixed earlier this session.
  - **Mitigation**: Explicitly sequenced in the Decision section — the decay pass and breeding pass run as two separate, non-interleaved passes, with offspring creation happening only after both complete. Flagged here as an explicit ordering requirement, not left implicit.
- **Risk** (godot-specialist validation): if the sacrificed creature was the sole remaining HABITAT creature, `_pick_representative()` has no candidate — the original draft did not specify this case's behavior.
  - **Mitigation**: `_pick_representative()` now returns `-1` for an empty HABITAT set, and `request_sacrifice()` skips the `_recompute_and_push_aggregate()` call entirely in that case — directly implementing Rule 6's explicit skip clause and AC-14 (the aggregate correctly reports `1.0` on the next natural happiness-changing event, not force-pushed with no representative to attribute it to).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| menagerie.md | Rule 2/7: creature entity model, `starting_happiness=70` | `CreatureInstance` (RefCounted), specified in Key Interfaces |
| menagerie.md | Rule 4: HABITAT capacity, Defense Building expansion | `_habitat_capacity: int`, incremented via `sanctuary_structure_built` subscription (EventBus, not direct call) |
| menagerie.md | Rule 6 (highest-risk rule): aggregate recompute-and-push | Single `_recompute_and_push_aggregate()` method, called from every HABITAT-composition-changing call site |
| menagerie.md | Rule 10-12: breeding pen, fixed 2 pens, same-species only | `Array[BreedingPen]` fixed size 2, `occupant_ids`/`breeding_missions_remaining` per pen |
| menagerie.md | Rule 13: `request_sacrifice()` — **resolves ADR-0025's flagged gap** | Menagerie confirmed as Autoload #11; method specified with `BREEDING_PEN` rejection and synchronous `creature_sacrificed` emission |
| menagerie.md | Dependencies: `restore_order=20`, after Inventory (10) | Confirmed compatible; `SaveRestorer` implementation specified in Key Interfaces |
| equipment-forge.md | Rule 19d / ADR-0025 Ordering Note | Menagerie's Autoload boot position (#11) assigned, unblocking Equipment Forge's Creature Sacrifice flow end-to-end |

## Performance Implications
- **CPU**: Negligible — Lure/Tend/breeding-pen actions are gameplay-action-triggered; decay/breeding-timer ticks fire once per `mission_launched`, not per-frame. Aggregate recompute is O(HABITAT count), bounded at 10.
- **Memory**: `_creatures` bounded by realistic playthrough scale (tens, not hundreds, of creatures); `_breeding_pens` fixed at 2. Negligible.
- **Load Time**: `SpeciesResource` definitions (5 entries) load alongside existing `GameDataRegistry` boot-time preloading (ADR-0009) — no new load-time phase.
- **Network**: N/A — single-player game.

## Migration Plan
N/A — Menagerie has no existing implementation to migrate from. This is a greenfield decision.

## Validation Criteria
- Unit test confirms `_recompute_and_push_aggregate()` fires `creature_happiness_changed` with the correct `quality_bonus` for all 4 HABITAT-composition-changing call sites (Lure-into-HABITAT, move-to-HABITAT, move-from-HABITAT, HABITAT-sourced sacrifice) — directly implements AC-10 through AC-15.
- Unit test confirms `request_sacrifice()` rejects a `BREEDING_PEN`-state creature and returns `false` with zero mutation.
- Unit test confirms `request_sacrifice()` is callable as `Menagerie.request_sacrifice(...)` from another Autoload/scene-instanced node without a node reference — confirms the Autoload/Criterion-B resolution.
- Unit test confirms `reset_to_defaults()` fully clears all Menagerie state (new-game path, per the Risks section above).
- Integration test confirms Menagerie's `restore_save_data()` executes after Inventory's (10) during a save-load sequence.

## Related Decisions
- ADR-0009 (Resource Data Model) — `GameDataRegistry` + `validate()` pattern `SpeciesResource` extends
- ADR-0016 (Inventory Storage Model) — `RefCounted` runtime-instance precedent `CreatureInstance` follows
- ADR-0020 (Direct-Autoload-call exception pattern) — governs both the Criterion A (Inventory) and Criterion B (`request_sacrifice`) calls this ADR specifies
- ADR-0021 (Inventory cross-system query/mutation API) — source of `has_items()`/`materials_spent`/`reserve_instance_id()` this ADR's Lure and Sacrifice flows consume
- ADR-0024 (Defense Building tech tree data model) — direct precedent for a system needing Autoload status solely to expose a Criterion-B direct-call method
- ADR-0025 (Equipment Forge cross-system aggregation) — the sibling ADR whose flagged Menagerie-Autoload dependency this ADR resolves
- `design/gdd/menagerie.md` — source GDD for all requirements this ADR addresses
