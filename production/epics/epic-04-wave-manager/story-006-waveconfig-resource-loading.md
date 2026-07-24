# Story 006: WaveConfig Resource Loading & Mission Launch Wiring

> **Epic**: Wave Manager
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-05-16
> **Estimate**: 6h

## Context

**GDD**: `design/gdd/wave-manager.md`
**Requirement**: `TR-wave-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Wave Manager FSM Architecture + ADR-0009: Resource Data Model
**ADR Decision Summary**: `WaveConfig`, `WaveScript`, `WaveSpawnEntry` are `.tres`-backed Resources (ADR-0009 territory) that define per-mission wave composition. Wave Manager reads `WaveConfig` once at `mission_launched`, resets all internal state (EC-9/AC-20's 8-field list), reads `Grid.get_spawn_cells()` once, and validates content constraints (empty config, empty spawn cells, `wave_time_budget` overrun) without crashing.

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM
**Engine Notes**: `Resource`/`@export` Array-of-Resource typed fields (`Array[WaveScript]`, `Array[WaveSpawnEntry]`) — verify `docs/engine-reference/godot/` for any 4.6.2-specific changes to typed-Resource-array export/serialization behavior before assuming standard 4.x semantics carry over unchanged (this project's standing rule: never assume post-cutoff API behavior without checking).

**Verified against the actual codebase (2026-07-04)**:
- No `WaveConfig`, `WaveScript`, or `MissionResource` classes exist anywhere in `src/` — this story authors them from scratch (`WaveSpawnEntry` already exists as a minimal `RefCounted`, not yet a `Resource`; see the note below on whether to convert it).
- The real `mission_launched` signal is `mission_launched(mission_id: String, modifiers: PackedStringArray)` — it does not yet carry `difficulty_tier: int`, despite the GDD's Rule 8 saying Wave Manager "Reads `difficulty_tier: int` from the mission launch data." **Decision (2026-07-05)**: add `difficulty_tier: int` as a third parameter to the real `mission_launched` EventBus signal. Blast-radius check: `mission_launched` has exactly one other subscriber in the codebase — `SavePersistence._on_mission_launched()` — which already ignores both existing parameters (underscore-prefixed, unused), so this is a low-risk, additive signal change. Update `design/gdd/event-bus.md`'s `mission_launched` catalogue row to the 3-field signature before implementation (same pattern already used for `monster_spawn_requested`'s 6-field update).
- `_wave_spawn_entries: Array[WaveSpawnEntry]` and `_spawn_cell: Vector2i` currently exist as raw, directly-settable fields for test injection — this story replaces their population mechanism (real `WaveConfig` loading + `Grid.get_spawn_cells()`) without necessarily removing the fields themselves (tests may still want to inject directly for unit-level coverage; only the production code path changes).
- No `mission_launched` handler exists in `wave_manager.gd` at all currently (confirmed via grep) — `_ready()` never subscribes to it. The IDLE→SCOUT transition (Rule 8, AC-1) is presently untestable via the real signal path.

**Control Manifest Rules (Feature layer)**:
- Required: mission loading must validate SPAWN and GOAL cell counts before entering SCOUT — a CI validator is referenced (AC-19b) but that's tooling work, out of this story's scope; this story only needs the runtime empty-spawn-cells guard (AC-36)
- Required: MVP missions must use exactly one SPAWN cell — the Voronoi partition is computed regardless, but multi-SPAWN is post-MVP (this affects `Grid.get_spawn_cells()`'s expected return shape, not Wave Manager's own logic)

---

## Acceptance Criteria

*From `design/gdd/wave-manager.md`, scoped to this story:*

- [ ] AC-1: On `mission_launched`, Wave Manager transitions IDLE → SCOUT and starts the 60s timer; `mission_phase_changed(from: "IDLE", to: "SCOUT")` fires in the same frame.
- [ ] Rule 8: Reads `WaveConfig` from the mission resource; reads SPAWN cells via `Grid.get_spawn_cells()`; resets `_wave_index = 0`, `_round_robin_counter = 0` (this story introduces `_round_robin_counter`, currently absent — see Story 007).
- [ ] Rule 8 (SCOUT preview): Immediately on SCOUT entry, emits `wave_preview_available(next_wave_number: 1, composition)` for wave 1 (unless `wave_scripts` is empty — AC-19 handles that case).
- [ ] AC-19: If `WaveConfig.wave_scripts` is empty, log an error and immediately emit `mission_phase_changed(previous_phase → MISSION_COMPLETE)` — bypasses SCOUT entirely (confirmed correct: entering SCOUT would start-then-immediately-stop its timer for a state no downstream system could ever observe; see Implementation Notes' `_on_mission_launched()` pseudocode, which places this guard before `_transition_to(Phase.SCOUT)`). No PRE_WAVE/WAVE_ACTIVE/INTERMISSION.
- [ ] AC-20: On `mission_launched` received while in DEFEAT or MISSION_COMPLETE, reset ALL state fields that currently exist on WaveManager synchronously before the SCOUT transition begins: `_wave_index`, `_round_robin_counter`, `_enemies_alive`, `_all_spawns_fired`, `_phase_locked`, `_wave_clear_fired`, `_templates_ready` (7 fields as of Story 006's landing — `_rebuild_pending_gate` is the 8th per ADR-0012's Key Interfaces list, but does not exist yet since Story 005 has not landed; extend `_reset_all_state()` once it does, tracked as a known gap in `wave_manager.gd`'s header comment, not silently dropped). Also cancel any in-flight timer (verified via the INTERMISSION-with-15s-remaining sub-case).
- [ ] AC-36: If `Grid.get_spawn_cells()` returns empty, log an error and emit `mission_phase_changed(previous_phase → MISSION_COMPLETE)` — bypasses SCOUT entirely, same reasoning and handling pattern as AC-19, no crash from downstream modulo-by-zero.
- [ ] AC-41: If any `WaveScript`'s total `pre_delay` sum exceeds `wave_time_budget`, log a content error identifying the offending wave index. Mission continues without clamping or aborting.
- [ ] Runtime validation (already partially specified by Story 004): `difficulty_growth_rate` bounds-checked at `mission_launched`, not clamped.
- [ ] `mission_launched`'s EventBus signature updated to include `difficulty_tier: int` as its third field; `design/gdd/event-bus.md`'s catalogue entry updated to match.
- [ ] Performance: No performance impact expected — Resource loading and state reset happen once per `mission_launched`, not per-frame.

---

## Implementation Notes

*Derived from ADR-0012/ADR-0009 Implementation Guidelines and the GDD Rules above:*

**Resource classes to author** (ADR-0009 pattern — see `MonsterResource`/`TowerPerkRegistry` in `src/core/` for this codebase's established Resource-authoring convention before writing these):

```gdscript
# src/gameplay/wave_config.gd
class_name WaveConfig
extends Resource

@export var wave_scripts: Array[WaveScript] = []
@export var difficulty_growth_rate: float = 0.20  # safe range 0.15-0.25 (GDD Tuning Knobs)
@export var wave_time_budget: float = 90.0        # safe range 45-120s
```

```gdscript
# src/gameplay/wave_script.gd
class_name WaveScript
extends Resource

@export var entries: Array[WaveSpawnEntry] = []
```

**`WaveSpawnEntry` conversion decision**: it currently `extends RefCounted`, not `Resource` — RefCounted objects cannot be `@export`ed inside another Resource's typed Array. Converting it to `extends Resource` is required for `WaveScript.entries: Array[WaveSpawnEntry]` to work as a `.tres`-serializable field. Verify this doesn't break the existing `to_payload()` usage or any Story 004 changes made to it — Resource and RefCounted share enough of the same API surface that this should be a low-risk conversion, but confirm via the existing test suite before considering it complete.

**`mission_launched` handling** (new — no handler exists today):

```gdscript
func _ready() -> void:
    # ...existing...
    GEventBus.mission_launched.connect(_on_mission_launched)

func _exit_tree() -> void:
    # ...existing...
    GEventBus.mission_launched.disconnect(_on_mission_launched)


## Rule 8 / AC-1 / AC-20: full state reset (if restarting from a terminal
## phase) THEN load WaveConfig THEN transition to SCOUT. Order matters — the
## reset must complete before _transition_to(Phase.SCOUT) runs, so no stale
## state leaks into the new mission (AC-20).
func _on_mission_launched(mission_id: String, _modifiers: PackedStringArray) -> void:
    _reset_all_state()  # the 8-field list from AC-20, PLUS cancel in-flight timers
    _wave_config = _load_wave_config(mission_id)  # resolve WaveConfig for this mission_id — see open gap below
    _spawn_cells = GGrid.get_spawn_cells()
    if _spawn_cells.is_empty():
        push_error("WaveManager: 0 spawn cells — cannot spawn any monsters. Triggering MISSION_COMPLETE immediately.")
        _transition_to(Phase.MISSION_COMPLETE)  # AC-36 — bypasses SCOUT entirely
        return
    if _wave_config.wave_scripts.is_empty():
        push_error("WaveManager: WaveConfig has 0 wave_scripts — mission has no waves. Triggering MISSION_COMPLETE immediately.")
        _transition_to(Phase.MISSION_COMPLETE)  # AC-19
        return
    _validate_wave_time_budgets()  # AC-41 — logs only, never aborts
    # Do NOT duplicate the [0.10, 0.25] bounds check inline here — Story 004
    # already implemented this exact validation as _validate_difficulty_growth_rate(),
    # reading the WaveManager-level `difficulty_growth_rate` field (idempotent,
    # no state mutation, safe to call at any FSM phase). Assign the loaded
    # WaveConfig's value into that existing field, then call the existing
    # function, so Story 004's 5 validation tests actually cover the real
    # production path instead of exercising a function that never gets called.
    difficulty_growth_rate = _wave_config.difficulty_growth_rate
    _validate_difficulty_growth_rate()
    _transition_to(Phase.SCOUT)
    GEventBus.wave_preview_available.emit(1, _build_composition_preview(1))  # Rule 8 SCOUT preview
```

**`difficulty_tier` sourcing — resolved**: add `difficulty_tier: int` directly to `mission_launched` (see decision above). This story's `_on_mission_launched()` signature becomes `func _on_mission_launched(mission_id: String, _modifiers: PackedStringArray, difficulty_tier: int) -> void:` — store it directly on WaveManager (e.g. `_difficulty_tier`), assigned fresh from the parameter each call. Do **not** add it to `_reset_all_state()`'s field list below — it isn't being reset to a default, it's being set anew from real mission data on every `mission_launched`.

**`difficulty_growth_rate` validation — reuse, do not duplicate (flagged during Story 004's code review, 2026-07-05)**: Story 004 already implemented `_validate_difficulty_growth_rate()` on WaveManager, tested against 5 cases including both inclusive boundaries. Do not reimplement the `[0.10, 0.25]` bounds check inline in `_on_mission_launched()` — assign the loaded `WaveConfig.difficulty_growth_rate` into the existing `difficulty_growth_rate` field, then call the existing function (see the corrected code sample above). Reimplementing it inline would leave Story 004's function as permanent dead code and its test coverage disconnected from the real production path.

**`_reset_all_state()`** (AC-20's 8 fields, plus what Stories 002/003/005 have added):

```gdscript
func _reset_all_state() -> void:
    _stop_phase_timers()
    if GEventBus.path_invalidated.is_connected(_on_path_invalidated):
        GEventBus.path_invalidated.disconnect(_on_path_invalidated)
    _wave_index = 0
    _round_robin_counter = 0  # introduced by Story 007
    _enemies_alive = 0
    _all_spawns_fired = false
    _phase_locked = false
    _wave_clear_fired = false  # introduced by Story 003
    _templates_ready = false
    _rebuild_pending_gate = false  # introduced by Story 005
```

`_validate_wave_time_budgets()` (AC-41) and `_build_composition_preview()` (used both here for the SCOUT preview and by Story 002 for INTERMISSION previews — factor this into one shared helper rather than duplicating).

**Round-robin spawn cell assignment (Rule 15b) and its modulo-wrap edge cases (AC-10, AC-35) are Story 007's scope, not this one** — this story only needs `Grid.get_spawn_cells()` called and stored; Story 007 consumes `_spawn_cells` for actual per-entry cell assignment.

---

## Out of Scope

- **Story 001**: `_is_final_wave()` (reads `_wave_config.wave_scripts.size()` once this story lands — coordinate the exact field name)
- **Story 002**: `_build_composition_preview()`'s per-wave lookup logic beyond the wave-1 SCOUT-entry case this story triggers
- **Story 004**: The `_wave_reward_scalar`/`is_penultimate_wave` formulas themselves (this story only ensures `difficulty_growth_rate` and `wave_scripts.size()` are real, sourced values those formulas can read)
- **Story 007**: Round-robin spawn cell assignment logic and modulo-wrap handling
- **AC-19b**: The CI WaveConfig validator tool — tracked separately as tooling work, not runtime WaveManager code

---

## QA Test Cases

- **AC-1**: `mission_launched` → SCOUT
  - Given: Wave Manager in IDLE
  - When: `mission_launched("the_gap", [])` fires
  - Then: `mission_phase_changed(from: "IDLE", to: "SCOUT")` same frame; 60s scout timer running

- **AC-19**: Empty `wave_scripts` → immediate MISSION_COMPLETE
  - Given: A `WaveConfig` with `wave_scripts = []`
  - When: `mission_launched` fires
  - Then: error logged; `mission_phase_changed(SCOUT → MISSION_COMPLETE)`; no PRE_WAVE/WAVE_ACTIVE/INTERMISSION for 30 simulated seconds

- **AC-20**: Full 8-field state reset on restart from a terminal phase
  - Given: Wave Manager in DEFEAT (or MISSION_COMPLETE) with all 8 fields at non-default values from a prior mission; INTERMISSION timer sub-case: Wave Manager in INTERMISSION with 15s remaining
  - When: `mission_launched` fires again
  - Then: assert ALL 8 fields explicitly reset (not a subset); for the INTERMISSION sub-case, assert no `phase_timer_tick(phase: "INTERMISSION", ...)` fires for 30 simulated seconds after the reset (proving the timer was actually cancelled)

- **AC-36**: Empty spawn cells → immediate MISSION_COMPLETE
  - Given: `Grid.get_spawn_cells()` stubbed to return `[]`
  - When: `mission_launched` fires
  - Then: error logged containing "0 spawn cells"; `mission_phase_changed(SCOUT → MISSION_COMPLETE)`; no crash

- **AC-41**: `wave_time_budget` overrun logs but doesn't abort
  - Given: A `WaveConfig` where one `WaveScript`'s `pre_delay` sum (e.g. [0.0, 50.0, 50.0] = 100s) exceeds `wave_time_budget` (90s default)
  - When: `mission_launched` fires
  - Then: error logged containing "exceeds wave_time_budget" and the offending wave index; mission continues normally (at least one `phase_timer_tick` fires in SCOUT within 30 simulated seconds, proving no abort to MISSION_COMPLETE)
  - Negative case: all waves within budget → no error logged

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/wave_manager/wave_manager_config_loading_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: Story 007 (round-robin spawn cell assignment needs real `_spawn_cells` and `WaveConfig` entries — Story 007 also edits `wave_spawn_entry.gd`, so land this story's `RefCounted`→`Resource` conversion first to avoid a same-file conflict), Story 008 (mission scene assembly needs real mission data, not test-injected placeholders)

---

## Completion Notes
**Completed**: 2026-07-05
**Criteria**: 10/10 passing (all COVERED, no deferred items)
**Deviations**: ADVISORY (x6) — (1) `WaveConfig`'s field schema conflict between ADR-0009 (`reward_base`) and this story's AC-41 (`wave_time_budget`) resolved by keeping both; (2) the `mission_launched` signature change required an unplanned companion fix to `save_persistence.gd` (same class of issue as Story 002's `wave_completed` fix); (3) AC-19/AC-36's wording didn't match the SCOUT-bypass implementation — independently judged correct during code review, now doc-synced; (4) AC-20's 8th field (`_rebuild_pending_gate`) excluded pending Story 005, tracked in both the story and `wave_manager.gd`; (5) code review found and fixed a null-safety gap on `_load_wave_config()` and a brittle textual-source-inspection performance test; (6) the implementing agent hit its session limit twice — remaining verification (a Godot class-cache rescan, and a recurring GDScript lambda-capture-by-value bug in two test functions) was completed directly.
**Test Evidence**: `tests/integration/wave_manager/wave_manager_config_loading_test.gd` — 24/24 passing; full regression run across `wave_manager`/`event_bus`/`save_persistence`: 180/180 passing, 0 errors, 0 failures
**Code Review**: Complete — APPROVED (after one APPROVED WITH SUGGESTIONS round; all 4 suggestions applied)
