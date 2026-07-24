# ADR-0017: Resource Economy Drop Resolution

## Status
Accepted

## Date
2026-07-11

## Last Verified
2026-07-13 — corrected an inaccurate precedent citation in the Decision section: Wave Manager is Autoload #7 (ADR-0002/ADR-0012), not "non-Autoload" as originally stated here. The underlying decision (Resource Economy as scene-instanced) is unaffected — it already matches ADR-0002's own Autoload/Scene-Instanced boundary table directly. See `docs/architecture/architecture-review-2026-07-13.md` Conflict 2.

2026-07-16 (Story 014, `godot-gdscript-specialist` code review) — found and fixed an internal inconsistency: the original Validation Criteria bullet ("no double-award of materials/gold if `monster_died` and `monsters_died_batch` both reference the same `entity_id`") asked for a guarantee that Resource Economy's own stateless-calculator Decision (this ADR, "no accumulator," Consequences: "no hidden mutable history to reset between test cases") structurally cannot provide, and that the same Risk's own Mitigation text already conceded is enforced upstream ("current EventBus dispatch code already prevents this"). The criterion has been corrected below to match the actual, accepted design: a test documenting current tripwire behavior at this layer's boundary, with exclusivity enforcement confirmed as an emitter-side (Monster System/Wave Manager) responsibility, not Resource Economy's. See `tests/unit/resource_economy/batch_resolution_independence_test.gd`'s third test for the corrected criterion's implementation, and TD-econ-006 (`docs/tech-debt-register.md`) for the tracked follow-up recommending an emitter-side integration test that verifies the exclusivity invariant itself, which remains genuinely unverified by any test in the codebase today.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core (data/calculation service) |
| **Knowledge Risk** | MEDIUM — same profile as ADR-0016 (no dedicated engine module for a pure data/calculation domain; risk is inherited from the `GameDataRegistry`/Resource-loading boundary already governed by ADR-0009) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/deprecated-apis.md`; no `modules/core.md` exists |
| **Post-Cutoff APIs Used** | None beyond what ADR-0009 already establishes (typed `Dictionary[K,V]`, already verified working per `VERSION.md`'s Project-Specific API Tracking table) |
| **Verification Required** | None beyond ADR-0009's existing verification scope |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0009 (Resource data model — Accepted, `GameDataRegistry` + `validate()` convention), ADR-0001 (EventBus architecture — Accepted, batching rules this system's `monster_died` subscription must respect) |
| **Enables** | Unblocks Epic 03 stories 008-012, 014-015 (`production/epics/epic-03-core-economy/`) |
| **Blocks** | None |
| **Ordering Note** | Story 013 (Gold Track & Scout Starting Grant) remains partially Blocked after this ADR — see Open Questions. This ADR deliberately does not resolve gold-balance ownership; that is a separate decision, likely involving Wave Manager or a new mission-session-state holder, not invented here as a side effect. |

## Context

### Problem Statement

`design/gdd/resource-economy.md` is content-complete and passed `/consistency-check`, but no ADR exists covering how drop tables are represented as data, how the stateless-calculator pattern (GDD Core Rule 1) is actually implemented as a Godot node/Autoload, or the mechanics of subscribing to `monster_died`/`monsters_died_batch` correctly. Without this decision, 8 of Epic 03's 15 stories are `Status: Blocked`.

### Constraints

- Must follow the `resource_validation` contract (ADR-0009): any persistent data Resource (`DropTableResource`) must implement `validate() -> Array[String]`.
- Must not emit data Resources as EventBus payloads (`data_resource_as_event_payload` forbidden pattern, ADR-0009) — `materials_earned`/`materials_spent`/`resources_changed` are already frozen as primitives-only in `event-bus.md`, and this ADR must not need to change that.
- Must respect the `monster_died` batching contract (ADR-0001): Wave Manager owns the batch accumulator; Resource Economy is a subscriber only and must resolve `monsters_died_batch` entries identically to individual dispatch (GDD Edge Cases, already specified).
- Must not become a second, competing definition of `wave_reward_scalar` — that formula is owned by `wave-manager.md`/ADR-0012, consumed here only.

### Requirements

- Drop resolution triggered by `monster_died` (`drop_table_id`, `menagerie_attraction_drop_chance`, `kill_source`) — GDD Core Rules 2, 5, 6
- Quantity/quality math per GDD Formulas 1-4 (already fully specified with worked examples — this ADR does not re-derive them, only decides their implementation home)
- Zero owned persistent state (GDD Core Rule 1) — verify this is achievable as a Godot implementation, not just a design aspiration

## Decision

**Resource Economy is implemented as a scene-instanced node (not an Autoload)**, subscribed to `monster_died`/`monsters_died_batch`/`mission_phase_changed`/`wave_reward_scalar`-bearing events for the lifetime of a mission, and freed at mission end. This directly matches ADR-0002's existing Autoload/Scene-Instanced boundary table, which already classifies Resource Economy (alongside Inventory) as scene-instanced, with state owned by Save & Persistence and cross-system communication via EventBus subscription only.

**Correction (2026-07-13)**: an earlier draft of this ADR justified the scene-instanced choice by "mirroring Wave Manager's own non-Autoload, per-mission lifecycle." That characterization of Wave Manager is incorrect — ADR-0002 (revised) and ADR-0012 both establish **WaveManager as Autoload #7**; its per-mission behavior comes from resetting to an `IDLE` FSM state (ADR-0012 EC-9), not from being scene-instanced. The comparison has been removed. It does not change the decision itself: Resource Economy's scene-instanced classification stands on ADR-0002's boundary table alone and needs no Wave Manager precedent. Although Resource Economy's *data* (drop tables) is global and boot-loaded, its *subscription lifecycle* is mission-scoped, matching where `monster_died` actually fires.

**Drop tables** follow ADR-0016's established two-tier pattern exactly:
```
DropTableResource: drop_table_id: StringName, entries: Array[DropEntry], guaranteed_min_quantity: int, base_drop_rate: float
DropEntry: material_id: StringName, base_quantity: int, base_quality_probability: float, is_rare: bool
```
*(`base_drop_rate` added 2026-07-16 during Story 008 — the original schema omitted Formula 1's per-table occurrence-roll input; see Key Interfaces for the corrected field list.)*
Both are Resource subclasses, loaded via `GameDataRegistry` at boot (same Autoload, position 5, as `MonsterResource`/`ItemDefinitionResource`), each implementing `validate() -> Array[String]` per the `resource_validation` contract. `MonsterResource.drop_table_id` (already an existing field per `monster.md`) resolves through `GameDataRegistry.get_drop_table(id)`.

**Statelessness is achieved as follows**: the Resource Economy node holds exactly one piece of mutable data — a cached `float` (`_menagerie_quality_bonus`), updated synchronously whenever `creature_happiness_changed`/`creature_moved_to_breeding_pen`/`creature_returned_from_breeding_pen` fire. This is the sole exception to "no owned state," and it is a single scalar with no save/restore requirement (it resets naturally on mission start via a fresh node instance, and Menagerie — not yet designed — is expected to re-broadcast current happiness at mission start). All other computation (quantity, quality roll, gold delta) is purely a function of the incoming event's payload plus this one cached scalar — no accumulator, no transaction log, no per-kill history retained.

**Gold emission** uses the existing shipped `resources_changed(gold: int, source: StringName)` signal (already in `event_bus.gd`, needs only the `event-bus.md` catalogue documentation — a small housekeeping fix, not a design decision). Resource Economy computes and emits deltas; it does **not** track a running balance itself (see Open Questions — balance storage is out of this ADR's scope).

### Architecture Diagram

```
GameDataRegistry (Autoload, boot position 5)
  └─ preloads DropTableResource[] from assets/data/drop_tables/
       validate() called per table at boot (ADR-0009 contract)

ResourceEconomy (scene-instanced node, mission-scoped — NOT an Autoload)
  ├─ owns: _menagerie_quality_bonus: float (sole mutable state, cached scalar)
  ├─ subscribes (EventBus): monster_died, monsters_died_batch, mission_phase_changed,
  │    creature_happiness_changed, creature_moved_to_breeding_pen,
  │    creature_returned_from_breeding_pen
  ├─ reads: GameDataRegistry.get_drop_table(drop_table_id) -> DropTableResource
  └─ emits (EventBus): materials_earned, materials_spent, resources_changed
       (gold balance itself is NOT tracked here — emission only)
```

### Key Interfaces

```gdscript
# DropTableResource / DropEntry (assets/data/drop_tables/*.tres, loaded by GameDataRegistry)
class_name DropTableResource extends Resource
@export var drop_table_id: StringName = &""
@export var entries: Array[DropEntry] = []
@export var guaranteed_min_quantity: int = 1
@export var base_drop_rate: float = 0.45  ## per-table (amended 2026-07-16, Story 008) — Formula 1's occurrence-roll input, range 0.3-0.6 per GDD Tuning Knobs. Missing from this ADR's original Key Interfaces block; the field genuinely belongs here per resource-economy.md's own "base_drop_rate (per table)" Tuning Knob row, not on DropEntry.
func validate() -> Array[String]: ...   # per resource_validation contract (ADR-0009)

class_name DropEntry extends Resource
@export var material_id: StringName = &""
@export var base_quantity: int = 1
@export var base_quality_probability: float = 0.10
@export var is_rare: bool = false

# ResourceEconomy (scene-instanced node, subscribes/unsubscribes with mission lifecycle)
# No public call API beyond what EventBus provides — pure event-reactive service,
# consistent with Damage & Status's "no direct call API" precedent (ADR-0007).
```

## Alternatives Considered

### Alternative B: Lightweight Dictionary-based drop table (no Resource subclass)

- **Description**: Drop tables as plain `Dictionary` data, loaded outside `GameDataRegistry`.
- **Pros**: Marginally simpler for a first pass.
- **Cons**: Identical rejection reasoning to ADR-0016's Alternative A — breaks from the established `GameDataRegistry`/Resource-subclass convention now used by `MonsterResource`, `WaveConfig`, `TowerComponent`, and `ItemDefinitionResource` (ADR-0016).
- **Rejection Reason**: No technical justification for a fifth, differently-loaded data format when four precedents already exist.

### Alternative C: Fold drop tables into MonsterResource directly

- **Description**: Add `drop_entries: Array[DropEntry]` and `guaranteed_min_quantity` fields directly onto `MonsterResource` instead of a separate `DropTableResource`, referenced 1:1 by the monster that owns them.
- **Pros**: One fewer Resource type; no separate `drop_table_id` → table lookup indirection.
- **Cons**: Couples Monster System's already-Approved, already-implemented data schema to Resource Economy's concerns — multiple monster types sharing an identical drop table (a common content pattern, e.g. "all Tier-1 goblin variants drop from the same table) would require duplicating the same entries across every `MonsterResource` instance, rather than one shared table referenced by ID. `MonsterResource.drop_table_id: StringName` (an indirection, not an inline array) is the existing field per `monster.md` — this ADR should honor that existing indirection, not collapse it.
- **Rejection Reason**: Breaks content reuse and requires modifying an already-shipped, already-tested system's data schema for no structural benefit.

## Consequences

### Positive

- Drop table content reuse across monster types is possible via shared `drop_table_id` references, matching the existing `monster.md` field design.
- Mission-scoped node lifecycle (not Autoload) keeps Resource Economy's subscription lifetime matching where `monster_died` actually fires — no risk of a stale global subscriber processing kills from a scene that no longer exists.
- The stateless design (one cached scalar, no accumulator) is straightforward to unit-test — no hidden mutable history to reset between test cases.

### Negative

- A `DropTableResource` lookup miss (unregistered `drop_table_id`) requires runtime handling (warn-once, no-drop per GDD Edge Cases) rather than a load-time guarantee, since `MonsterResource.drop_table_id` is data-authored independently of `DropTableResource` content and the two can drift out of sync during content authoring.
- The `_menagerie_quality_bonus` cached scalar has an implicit assumption: Menagerie (not yet designed) must re-broadcast current happiness at mission start so a fresh Resource Economy node instance isn't stuck at a stale default. This is a forward dependency on a system that doesn't exist yet — flagged, not resolved, in Open Questions.

### Risks

- **Risk**: Gold-balance ownership remains unresolved (per the collaborative decision to scope this ADR to drop-resolution only). Story 013 stays partially Blocked.
  - **Mitigation**: A follow-up ADR or GDD-level decision (likely involving Wave Manager, which already owns other mission-scoped state per ADR-0012, or a new dedicated mission-session-state holder) must resolve this before Story 013 can be fully implemented and tested end-to-end.
- **Risk**: If Menagerie's eventual GDD does not re-broadcast happiness at mission start, `_menagerie_quality_bonus` could silently default to whatever the class's field initializer specifies (likely `1.0`), producing an inconsistent early-mission bonus.
  - **Mitigation**: Flag this explicitly as a requirement for the future Menagerie GDD's Interactions section — noted in Open Questions here, not invented as a workaround.
- **Risk** (godot-specialist validation): subscribing to both `monster_died` and `monsters_died_batch` relies on an implicit exclusivity assumption — a given kill must fire exactly one of the two, never both, or this system would silently double-award materials/gold for that kill. Confirmed against shipped Wave Manager code (`_on_monster_died`/`_on_monsters_died_batch`) that this exclusivity already holds project-wide (Wave Manager's own `_enemies_alive` decrement relies on the same guarantee), so this is a pre-existing, already-relied-upon invariant, not a new risk this ADR introduces — but unlike a simple decrement, drop-resolution math makes a violation a real-money-adjacent bug class.
  - **Mitigation (corrected 2026-07-16, Story 014)**: Resource Economy's own stateless-calculator design (this ADR's Decision) means this layer cannot itself detect or prevent a double-award — it can only document the failure mode. A unit test at this layer (`batch_resolution_independence_test.gd`) exists as a tripwire confirming the *current* (correct, by design) behavior: if the upstream exclusivity guarantee is ever violated, Resource Economy double-awards. The actual guarantee — that `monster_died` and `monsters_died_batch` are mutually exclusive per `entity_id` — is owned and must be verified at the emitter (Monster System/Wave Manager's kill-dispatch code), not here. Tracked as TD-econ-006 (`docs/tech-debt-register.md`): no test anywhere in the codebase today verifies the emitter-side guarantee itself.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| resource-economy.md | Core Rule 1: stateless calculator | Node holds exactly one cached scalar (`_menagerie_quality_bonus`); all other computation is pure per-event |
| resource-economy.md | Core Rule 2, Formulas 1-4: drop resolution math | Formulas are unchanged from the GDD — this ADR only decides where the computation runs (mission-scoped node) and where data lives (`DropTableResource` via `GameDataRegistry`) |
| resource-economy.md | Core Rule 4: `DropTableResource`/`DropEntry` schema | Implemented exactly as specified in the GDD, following ADR-0016's established Resource-subclass pattern |
| resource-economy.md | Rule 9, Edge Cases: batch resolution independence | Node subscribes to both `monster_died` and `monsters_died_batch`, resolving each batch entry identically to an individual dispatch |

## Performance Implications

- **CPU**: Negligible — drop resolution triggers once per kill (or per batch entry), well within the `monster_died`/`monsters_died_batch` EventBus budget already governed by ADR-0001.
- **Memory**: `DropTableResource` instances are boot-loaded and shared (immutable), same memory profile as `MonsterResource`.
- **Load Time**: Adds to `GameDataRegistry`'s existing boot-time preload phase — no new load-time phase introduced.
- **Network**: N/A — single-player game.

## Migration Plan

N/A — greenfield decision, no existing implementation.

## Validation Criteria

- Unit tests confirm Formulas 1-4 produce the GDD's worked examples exactly.
- Unit tests confirm `monsters_died_batch` entries resolve identically to individual `monster_died` dispatch (no shared rounding state between batch entries).
- Unit tests confirm an unregistered `drop_table_id` warns exactly once per unique ID per session, not once per kill.
- Integration test confirms the Resource Economy node correctly unsubscribes at mission end (no dangling EventBus connections into a freed node — per EventBus Core Rule 6/EC-2).
- Unit test documents Resource Economy's actual behavior if `monster_died` and `monsters_died_batch` both reference the same `entity_id` (corrected 2026-07-16, Story 014 — see Risks/Mitigation above: this layer's stateless design means the test is a tripwire on current behavior, not a guarantee of prevention; the exclusivity invariant itself is an emitter-side responsibility, tracked separately as TD-econ-006).

## Related Decisions

- ADR-0009 (Resource data model) — `GameDataRegistry` + `validate()` pattern this ADR extends to `DropTableResource`/`DropEntry`
- ADR-0016 (Inventory Storage Model) — sibling Core-economy ADR; this ADR mirrors its two-tier Resource pattern and its precedent for rejecting a non-Resource-based data format
- ADR-0001 (EventBus architecture) — batching contract this ADR's subscriber must respect
- ADR-0012 (Wave Manager FSM) — Autoload #7 achieving per-mission behavior via IDLE-state reset, not scene-instancing (corrected 2026-07-13 — no longer cited as an architectural precedent for this ADR's scene-instanced choice, which rests on ADR-0002's boundary table instead); Wave Manager is also the likely eventual owner of gold-balance state (unresolved, see Open Questions)
- `design/gdd/resource-economy.md` — source GDD for all requirements this ADR addresses

## Open Questions

| Question | Owner | Notes |
|---|---|---|
| Who owns the runtime gold balance? | technical-director | Deliberately out of scope for this ADR per explicit user decision during authoring — Resource Economy only emits deltas. Likely candidates: Wave Manager (already owns other mission-scoped state) or a new dedicated mission-session-state holder. Story 013 stays partially Blocked until resolved. |
| Does Menagerie need to re-broadcast current happiness at mission start? | game-designer (Menagerie GDD author) | Flagged as a forward-dependency risk in Consequences — Menagerie's own GDD (not yet authored) should specify this explicitly when written. |
