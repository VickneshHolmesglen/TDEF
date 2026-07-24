# ADR-0028: Mission Select Runtime State and Retry Architecture

## Status
Accepted

## Acceptance Note
Accepted 2026-07-18 (Sprint 6, S6-03) by explicit user decision, outside the normal `/architecture-review` gate — same precedent as ADR-0022/ADR-0029's Sprint 6 S6-02 acceptance. Lightweight manual cross-check: all dependency ADRs (0009, 0020, 0023, 0027) confirmed `Accepted` (ADR-0027 accepted in this same S6-03 pass); `restore_order=11` confirmed collision-free against the full authoritative table (10, 20, 21, 22, 24, 30, 31, 32, 34); Autoload #12 reclassification confirmed consistent with ADR-0002's own precedent (Inventory #9, Defense Building #10, Menagerie #11 already reclassified). Unblocks Epic 07's Mission Select stories (008–014) — flips them `Blocked` → `Ready`. An independent `/architecture-review` pass in a fresh session is still recommended before Epic 07's next milestone.

## Date
2026-07-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | State Management / Data Structures |
| **Knowledge Risk** | LOW — reuses ADR-0009's `GameDataRegistry` convention, the static/runtime Resource split pattern (ADR-0016/0023/0027), and ADR-0020's direct-call criteria. No new engine subsystem. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; ADR-0002 (Scene/Autoload structure — Mission Select's current, incorrect scene-instanced classification); ADR-0020 (Direct-Autoload-call exception pattern — already retroactively classified `retry_current_mission()` as Criterion B, using Mission Select as its own worked example, before this ADR existed) |
| **Post-Cutoff APIs Used** | Typed `Dictionary[String, int]`/`Dictionary[int, MissionCompletionRecord]` (4.4+, already verified working) |
| **Verification Required** | None beyond what `VERSION.md` already confirms for typed Dictionaries |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0009 (Resource Data Model), ADR-0020 (Direct-Autoload-call exception pattern — already names Mission Select's `retry_current_mission()` as its Criterion B worked example), ADR-0023/ADR-0027 (static/runtime Resource split precedent this ADR applies to `MissionEntry`/`completion_records`) |
| **Enables** | `design/gdd/mission-select.md` implementation stories (currently blocked pending this ADR) |
| **Blocks** | None further downstream — Mission Select is upstream of Grid/Wave Manager/Tarot but all of those consume it via already-frozen EventBus contracts or the already-specified `GridConfig` direct-init call, neither of which this ADR changes |
| **Ordering Note** | **This ADR reclassifies Mission Select from scene-instanced to Autoload — the fourth occurrence of this exact pattern this session** (after Inventory, Defense Building, Menagerie). Unlike the prior three, the reason here is not solely the `retry_current_mission()` direct call (ADR-0020 Criterion B) — it is more fundamental: `MissionRuntimeState` (Rule 10) must survive the SANCTUARY→MISSION scene transition, and a scene-instanced node is freed when its scene unloads. Boot position: **#12**, after Menagerie's #11. `restore_order = 11` (already assigned in `save-persistence.md`) is unaffected — Autoload boot order and `SaveRestorer.restore_order` are independent axes (per ADR-0002/ADR-0003's own established distinction). |

## Context

### Problem Statement

`design/gdd/mission-select.md` is content-complete — a fully-specified two-step select/configure/launch flow, an explicit resolution of Grid System's OQ-4 (`cell_size` as a fixed constant), and a retry mechanism (Rule 10) that reconciles three other GDDs' constraints — but has no ADR covering the `MissionEntry` data model, `MissionRuntimeState`'s actual storage mechanism, or (critically) a structural problem: `MissionRuntimeState` is described as "cached in memory (Autoload singleton field, never persisted to save)" (Rule 10), but `ADR-0002`'s current Sanctuary Scene hierarchy lists `MissionSelectSystem` as a **scene-instanced** child node — which would be freed the moment `SanctuaryScene` unloads for the mission, destroying the exact cached state Rule 10 depends on surviving into the mission. This ADR resolves that contradiction, and — mirroring ADR-0027's finding for Tarot — also resolves a second GDD-level inconsistency: `MissionEntry.completion_records` is listed as a mutable field directly on a `GameDataRegistry`-loaded static Resource, the same class of problem ADR-0027 just fixed for `TarotCardResource`.

### Constraints

- `MissionEntry` must follow ADR-0009's convention: boot-loaded via `GameDataRegistry`, immutable, shared, validated via `validate()`.
- `completion_records` (mutable, per-save, per-`mission_id`-per-`difficulty_tier` state) must **not** live on the shared `MissionEntry` Resource instance — must be a separate, Mission-Select-owned runtime ledger, per the same reasoning ADR-0027 already applied to Tarot's mastery/discovery state.
- `MissionRuntimeState` must survive the SANCTUARY→MISSION scene transition intact — including holding the **same `GridConfig` instance** (Rule 10/EC-6's explicit "not a re-fetched equivalent one" requirement) across a DEFEAT→retry cycle.
- `retry_current_mission()` must be callable as a direct Autoload call by Mission HUD (a `MissionScene` child, per ADR-0002's Mission Scene hierarchy) — already classified Criterion B by ADR-0020, using this exact method as its worked example.
- Orphaned `completion_records` entries (EC-5 — a `mission_id` no longer in current game data) must be retained, not discarded, and must never be surfaced in the catalogue UI or block a save load.
- `restore_order = 11` (already assigned in `save-persistence.md`) — this ADR confirms compatibility, does not re-derive the number.

### Requirements

- `MissionEntry` fields (Rule 1, static portion only): `mission_id`, `display_name`, `grid_config: GridConfig`, `wave_config_path`, `base_wave_count`, `recommended_difficulty_tier`.
- Runtime `CompletionLedger` (Mission-Select-owned, save-persisted): `Dictionary[String, Dictionary]` (outer typed by `mission_id`; inner `Dictionary` maps `difficulty_tier: int -> MissionCompletionRecord`, untyped since GDScript typed Dictionaries only type the outer container — same limitation already noted during ADR-0021's engine-specialist review), keyed `mission_id -> difficulty_tier -> record`.
- `MissionRuntimeState` (Mission-Select-owned, **never persisted**, Autoload-lifetime only): `mission_id`, the exact `GridConfig` instance from that mission's `MissionEntry`, `difficulty_tier`, `modifiers: PackedStringArray`.
- `retry_current_mission() -> void`: re-emits `mission_launched` with the cached values, re-delivers the identical cached `GridConfig` instance to Grid.
- `MissionRuntimeState` clears on `MISSION_COMPLETE`; retains (armed for retry) on `DEFEAT`.

## Decision

**Split `MissionEntry` (static, immutable, `GameDataRegistry`-backed) from a new `CompletionLedger` (runtime, Mission-Select-owned, save-persisted)** — applying the identical static/runtime split ADR-0027 just established for Tarot, and ADR-0023/ADR-0016 before it. `MissionEntry` carries only content-authored fields; `completion_records` is removed from it entirely.

**`MissionEntry`** (static content data): `mission_id: String`, `display_name: String`, `grid_config: GridConfig` (nested Resource, same embedding pattern `WaveConfig`/`WaveScript` already use per ADR-0009, confirmed safe by ADR-0027's engine-specialist validation), `wave_config_path: String`, `base_wave_count: int`, `recommended_difficulty_tier: int`. Loaded at boot via `GameDataRegistry`, validated via `validate()`.

**`CompletionLedger`** (runtime, Mission-Select-owned): `Dictionary[String, Dictionary]` (outer typed by `mission_id`; inner untyped `Dictionary`, since GDScript typed Dictionaries only type the outer container), keyed `mission_id -> difficulty_tier (1/2/3) -> MissionCompletionRecord`. `MissionCompletionRecord` is a plain `RefCounted` (mirrors ADR-0026's `CreatureInstance` precedent for a small flat-primitive runtime entity — not a `Resource`, since it is per-save mutable state, never boot-loaded or validated content): `completed: bool`, `best_time_seconds: float` (`-1.0` sentinel). A `mission_id` with no ledger entry is treated identically to an entry with `completed: false, best_time_seconds: -1.0` for every tier (EC-1) — the ledger does not need to be pre-populated for every mission at boot; absence and explicit-false-state are equivalent by construction, checked via `Dictionary.get()` with a default, never by presence-testing alone.

**Orphaned entries (EC-5)**: the `CompletionLedger` is keyed by raw `mission_id` strings, entirely independent of whether that `mission_id` currently resolves via `GameDataRegistry.get_mission_entry()`. Restore never cross-validates ledger keys against the loaded `MissionEntry` roster — an orphaned key is retained unconditionally. Only the **catalogue UI's** own iteration (which walks `GameDataRegistry`'s loaded `MissionEntry` list, not the ledger) determines what is ever displayed — an orphaned ledger entry is structurally unreachable from the UI without needing an explicit filter, since the UI never iterates the ledger directly.

**`MissionRuntimeState`** (runtime-only, Autoload-lifetime, **never persisted** — Rule 10 is explicit this is "never persisted to save"): a single instance held as a field on the Mission Select Autoload itself (not a separate class — four scalar/reference fields do not warrant their own `RefCounted` wrapper). Set once at `mission_launched` (initial launch): `_runtime_mission_id`, `_runtime_grid_config` (the **exact instance reference** from `MissionEntry.grid_config` — never `.duplicate()`'d, satisfying Rule 10/EC-6's same-instance guarantee by construction, since GDScript `Resource` fields are reference types and simply are not copied unless explicitly duplicated), `_runtime_difficulty_tier`, `_runtime_modifiers`. Cleared (`null`/empty) on `mission_phase_changed → MISSION_COMPLETE`; retained unchanged on `→ DEFEAT` (arms `retry_current_mission()`).

**Mission Select reclassified as Autoload #12** (resolving the scene-instanced contradiction identified in Context, and confirming ADR-0020's prior Criterion-B classification of `retry_current_mission()`): the retry method reads `MissionRuntimeState`'s cached fields, guards on their presence (EC-6 — logs an error and takes no action if absent, never falls back to re-fetching a fresh `GridConfig`), then re-emits `mission_launched` with the identical cached values and re-delivers `_runtime_grid_config` (the same instance) to `Grid.initialize_from_config()` (or equivalent, per Grid's existing direct-call write API, ADR-0005).

### Architecture Diagram

```
GameDataRegistry (Autoload, boot position 5)
  └─ preloads MissionEntry[] from assets/data/missions/
       validate() called per entry at boot (ADR-0009 contract)

MissionSelect (Autoload #12 — reclassified from scene-instanced; required
               both because MissionRuntimeState must survive the
               SANCTUARY→MISSION scene transition (a scene-instanced node
               would be freed on scene unload) AND so retry_current_mission()
               is callable as a bare global from Mission HUD, a MissionScene
               child — per ADR-0020 Criterion B, already using this exact
               method as its worked example)
  ├─ owns: _completion_ledger: Dictionary[String, Dictionary]   # inner: {tier: MissionCompletionRecord}
  ├─ owns: _runtime_mission_id: String                    # MissionRuntimeState, NOT persisted
  ├─ owns: _runtime_grid_config: GridConfig                # same instance, never duplicated
  ├─ owns: _runtime_difficulty_tier: int
  ├─ owns: _runtime_modifiers: PackedStringArray
  ├─ implements SaveRestorer:
  │    get_save_key() -> "mission_select"
  │    get_save_data() -> Dictionary (primitives only — _completion_ledger ONLY,
  │         MissionRuntimeState is explicitly excluded per Rule 10)
  │    restore_save_data(data) -> bool
  │    reset_to_defaults() -> void
  ├─ registers: SavePersistence.register(self, restore_order=11)
  ├─ reads: GameDataRegistry.get_mission_entry(mission_id) -> MissionEntry
  ├─ calls (direct, Criterion A/ADR-0020): Grid.initialize(config) at mission_launched/retry
  ├─ exposes (direct, Criterion B/ADR-0020): retry_current_mission() -> void
  │    — callable by Mission HUD (MissionScene child)
  ├─ subscribes (EventBus): mission_phase_changed (MISSION_COMPLETE clears
  │    MissionRuntimeState; DEFEAT retains/arms it)
  └─ emits (EventBus): mission_selected, run_modifier_selected, mission_launched
```

### Key Interfaces

```gdscript
# MissionEntry (assets/data/missions/*.tres, loaded by GameDataRegistry)
class_name MissionEntry extends Resource
@export var mission_id: String = ""
@export var display_name: String = ""
@export var grid_config: GridConfig = null
@export var wave_config_path: String = ""
@export var base_wave_count: int = 5
@export var recommended_difficulty_tier: int = 1
func validate() -> Array[String]: ...   # confirms grid_config.cell_size == 64.0 (Rule 2)

# MissionCompletionRecord (RefCounted, runtime — not a Resource, never boot-loaded)
class_name MissionCompletionRecord extends RefCounted
var completed: bool = false
var best_time_seconds: float = -1.0    # sentinel — never 0.0

# MissionSelect (Autoload #12, implements SaveRestorer per ADR-0003)
var _completion_ledger: Dictionary[String, Dictionary] = {}   # mission_id -> {tier: MissionCompletionRecord}
var _runtime_mission_id: String = ""
var _runtime_grid_config: GridConfig = null
var _runtime_difficulty_tier: int = 0
var _runtime_modifiers: PackedStringArray = PackedStringArray()

func retry_current_mission() -> void:
    if _runtime_mission_id.is_empty() or _runtime_grid_config == null:
        push_error("MissionSelect.retry_current_mission() called with no armed MissionRuntimeState.")
        return   # EC-6 — never falls back to a fresh GridConfig fetch
    Grid.initialize(_runtime_grid_config)   # same instance, Criterion A — ADR-0005's actual write API name
    EventBus.mission_launched.emit(_runtime_mission_id, _runtime_modifiers, _runtime_difficulty_tier)

func get_completion_record(mission_id: String, tier: int) -> MissionCompletionRecord:
    var by_tier: Dictionary = _completion_ledger.get(mission_id, {})
    return by_tier.get(tier, MissionCompletionRecord.new())   # EC-1 — absence == default record

func get_save_key() -> String: return "mission_select"
func get_save_data() -> Dictionary:
    # MissionRuntimeState is intentionally excluded — Rule 10: "never persisted to save"
    return {"completion_ledger": _serialize_ledger(_completion_ledger)}
```

## Alternatives Considered

### Alternative A: `MissionRuntimeState` persisted across scene transitions via `SceneManager`'s own transition payload, keeping Mission Select scene-instanced

- **Description**: Rather than making Mission Select an Autoload, have `SceneManager.transition_to_mission()` accept and forward the runtime state as a parameter, letting a freshly-instanced `MissionSelectSystem` in `MissionScene` reconstruct it.
- **Pros**: Avoids adding a 12th Autoload.
- **Cons**: `MissionScene`'s own hierarchy (ADR-0002) does not include a `MissionSelectSystem` node at all — Mission Select's UI has no reason to exist inside `MissionScene`, only its cached state does. Threading runtime state through `SceneManager`'s transition call would couple `SceneManager` to Mission Select's specific data shape (`GridConfig`, `difficulty_tier`, `modifiers`), a responsibility `SceneManager` (ADR-0002) explicitly does not currently have and should not gain just to work around this.
- **Rejection Reason**: Autoload status is the simpler, already-established pattern for "state that must survive scene transitions" (Grid, GameDataRegistry, MissionEconomy all already do this) — no reason to invent a second mechanism for the same problem class.

### Alternative B: `retry_current_mission()` as an EventBus event Mission HUD emits, Mission Select subscribes to

- **Description**: `retry_requested` event instead of a direct call.
- **Pros**: Avoids the Criterion-B Autoload requirement for this specific call.
- **Cons**: Doesn't resolve the deeper problem (Alternative A already ruled out) — `MissionRuntimeState` still needs to survive the scene transition regardless of how the retry is triggered, so Mission Select still needs Autoload status for that reason alone. An EventBus-based retry would also lose the synchronous, immediate re-delivery of the exact `GridConfig` instance that Rule 10/EC-6 requires — Grid's own initialization call happens as part of the same synchronous operation, not decoupled via a second event hop.
- **Rejection Reason**: Doesn't address the root cause, and ADR-0020 already established Criterion B as the correct classification for exactly this call shape (single caller, single callee, state-guarded) using this method as its own example.

## Consequences

### Positive
- Resolves a structural contradiction that would have caused `MissionRuntimeState` to be silently destroyed on every SANCTUARY→MISSION transition if implemented literally per ADR-0002's current (incorrect) scene-instanced classification — caught at the ADR-authoring stage rather than at runtime.
- Mirrors ADR-0027's Tarot fix for the identical `completion_records`-on-a-shared-Resource inconsistency, closing it here before it becomes an implementation bug too.
- `_runtime_grid_config`'s same-instance guarantee (Rule 10/EC-6) is satisfied structurally, not by convention — GDScript's reference semantics for `Resource` fields make "assign the reference, never duplicate" the natural default, not something requiring active discipline to maintain.

### Negative
- Mission Select is the 12th global Autoload singleton — continues the pattern flagged by ADR-0002's own Risks section (added earlier this session) as worth checking for on every new ADR going forward. This is now the fourth confirmation that check was worth adding.
- `MissionCompletionRecord` as a `RefCounted` (not `Resource`) means it participates in no `validate()`/`GameDataRegistry` boot-loading — correct for its role (pure runtime/save state), but a future maintainer scanning for "all Resource subclasses" as an inventory of data-driven content would miss it, same discoverability tradeoff already accepted for `InventorySlot`/`ConstellationInstance`/`CreatureInstance`.

### Risks
- **Risk**: A future implementer, following the GDD's literal Rule 1 table (which still lists `completion_records` as a `MissionEntry` field), could re-introduce the shared-mutable-Resource bug this ADR fixes.
  - **Mitigation**: This ADR's Decision section is authoritative over the GDD's literal field table, following the same "ADR corrects GDD" precedent ADR-0024 established for `defense-building.md`'s save-payload description and ADR-0027 established for `tarot.md`'s Rule 1. Flagged here explicitly for `mission-select.md`'s next revision pass to correct.
- **Risk** (godot-specialist validation, fixed in this revision): the original draft's code sample called a nonexistent `Grid.initialize_from_config()` method — ADR-0005's actual write API is `Grid.initialize(config: GridConfig) -> void`.
  - **Mitigation**: Fixed — Key Interfaces now calls `Grid.initialize()`, matching ADR-0005 exactly.
- **Risk** (godot-specialist validation, fixed in this revision): the original draft's prose (Requirements/Decision/Architecture Diagram) wrote `Dictionary[String, Dictionary[int, MissionCompletionRecord]]`, implying nested-Dictionary typing GDScript doesn't actually support — its own Key Interfaces code correctly used the untyped-inner form, but the prose had drifted out of sync (the same class of issue ADR-0026's `_tower_membership` typing caught and fixed for Constellation earlier this session).
  - **Mitigation**: Fixed — all prose references now correctly state `Dictionary[String, Dictionary]` with an untyped inner Dictionary, matching the code and citing the same limitation already noted during ADR-0021's review.
- **Risk**: `GameDataRegistry.get_mission_entry()` could be called with a `mission_id` that fails to resolve (e.g., a `CompletionLedger` key with no matching `MissionEntry`, if ever accidentally used to drive UI lookup instead of the intended catalogue-iteration approach).
  - **Mitigation**: The Decision section explicitly specifies the UI walks the `MissionEntry` roster (never the ledger) to determine what's displayable — the ledger is only ever looked up *by* a known-valid `mission_id` obtained from that roster, never used as the iteration source itself. This ordering is stated explicitly here so a future implementer doesn't invert it.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| mission-select.md | Rule 1: `MissionEntry` schema; `completion_records` mutability inconsistency | Split into static `MissionEntry` + runtime `CompletionLedger`, mirroring ADR-0027's Tarot fix |
| mission-select.md | Rule 10/EC-6: `MissionRuntimeState`, same-`GridConfig`-instance guarantee | `_runtime_grid_config` holds the exact reference, never duplicated; Mission Select reclassified Autoload #12 so this state survives scene transitions |
| mission-select.md | Rule 10: `retry_current_mission()` — confirms ADR-0020's prior Criterion B classification | Method specified in Key Interfaces, guarded per EC-6, callable by Mission HUD as a bare global |
| mission-select.md | EC-1: absent ledger entry == default `{completed:false, best_time_seconds:-1.0}` | `get_completion_record()`'s `Dictionary.get()`-with-default pattern, no pre-population required |
| mission-select.md | EC-5: orphaned `completion_records` retained, never surfaced | Ledger keyed independently of `MissionEntry` existence; UI iterates the roster, never the ledger, structurally excluding orphans from display |
| mission-select.md | Dependencies: `restore_order=11` | Confirmed independent of Autoload boot order (position #12) — the two are separate axes |

## Performance Implications
- **CPU**: Negligible — mission select/configure/launch and retry are all gameplay-action-triggered, not per-frame.
- **Memory**: `_completion_ledger` bounded by catalogue size (4-10 missions × 3 tiers) — negligible. `MissionRuntimeState`'s 4 fields are trivial.
- **Load Time**: `MissionEntry` definitions load alongside existing `GameDataRegistry` boot-time preloading (ADR-0009) — no new load-time phase.
- **Network**: N/A — single-player game.

## Migration Plan
N/A — Mission Select has no existing implementation to migrate from. This is a greenfield decision.

## Validation Criteria
- Unit test confirms `_runtime_grid_config` after `retry_current_mission()` is the exact same object identity (`==` on the `Resource` reference, not merely equal field values) as the one delivered at the original `mission_launched` — directly implements AC-23's same-instance requirement.
- Unit test confirms `MissionRuntimeState` fields are absent from `get_save_data()`'s returned Dictionary entirely (not merely null-valued) — confirms Rule 10's "never persisted" guarantee.
- Unit test confirms `retry_current_mission()` called with no armed `MissionRuntimeState` logs an error and performs zero side effects (no `mission_launched` emission, no Grid call) — implements AC-25/EC-6.
- Integration test confirms an orphaned `CompletionLedger` entry (unknown `mission_id`) survives a save/load round-trip and is never returned by any catalogue-iteration code path — implements AC-28/EC-5.
- Integration test confirms Mission Select is reachable as a bare global (`MissionSelect.retry_current_mission()`) from a `MissionScene`-child node with no node reference held — confirms the Autoload reclassification resolves the scene-transition problem this ADR identifies.

## Related Decisions
- ADR-0009 (Resource Data Model) — `GameDataRegistry` + `validate()` pattern `MissionEntry` extends
- ADR-0020 (Direct-Autoload-call exception pattern) — already names `MissionSelect.retry_current_mission()` as its Criterion B worked example, before this ADR existed to confirm it
- ADR-0023 (Crafting recipe data model) / ADR-0027 (Tarot modifier aggregation pipeline) — direct precedent for the static-Resource/runtime-ledger split this ADR applies to `MissionEntry`/`completion_records`
- ADR-0026 (Menagerie creature lifecycle) — precedent for a plain `RefCounted` runtime entity (`MissionCompletionRecord` mirrors `CreatureInstance`'s role)
- ADR-0002 (Scene/Autoload structure) — corrected by this ADR's reclassification (see GDD Requirements Addressed); must be revised in the same pass as this ADR lands, per ADR-0002's own Risks section
- ADR-0005 (Grid System Data Model) — source of the Grid write API this ADR's retry flow calls
- `design/gdd/mission-select.md` — source GDD for all requirements this ADR addresses
