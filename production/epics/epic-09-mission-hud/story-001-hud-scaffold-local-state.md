# Story 001: HUD Scaffold & Local State Model

> **Epic**: Epic 09 — Mission HUD
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/mission-hud.md`
**Requirement**: `TR-hud-000` *(no registered TR-ID covers Core Rules Group 1 yet — see Epic 09's own Untraced Requirements note; scoped directly from Core Rules 1-4)*

**ADR Governing Implementation**: ADR-0031 (Mission HUD Architecture)
**ADR Decision Summary**: `MissionHud` is a `class_name MissionHud extends CanvasLayer`, already placed by ADR-0002 as a static child of `MissionScene.tscn` (scene-instanced, not an Autoload). It owns zero gameplay state, no `SaveRestorer`. 5 typed HUD-local derived-state fields live on this outer root (never on the Planning Cluster — Story 002's scope), reset on mount.

**Engine**: Godot 4.6.2 | **Risk**: LOW — pure scene/script scaffolding, no post-cutoff API surface
**Engine Notes**: `_ready()`/`_exit_tree()` fire exactly once per mission (node destroyed only when `MissionScene` unloads) — "mounts"/"unmounts" below describe internal state transitions, not scene-tree membership (GDD Rule 1).

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates ADR-0031; follow ADR-0031 directly.
- Forbidden: Mission HUD must hold zero direct Node references to any gameplay system (control-manifest's cross-system-reference ban) — all reads are EventBus subscriptions except the 3 ADR-0020-classified direct calls (Stories 003/006/012's own scope).
- Guardrail: All local counters must reset exactly once, on `mission_phase_changed(IDLE → SCOUT)` — never partially, never on any other transition.

---

## Acceptance Criteria

*From GDD `design/gdd/mission-hud.md` Core Rules Group 1 (Rules 1-4):*

- [x] AC-1 — `MissionHud` (`CanvasLayer`) exists as a static child of `MissionScene.tscn`; its `_ready()`/`_exit_tree()` fire exactly once per mission lifetime (verified by a counter, not destroyed/recreated by internal phase transitions)
- [x] AC-2 — on `mission_phase_changed(previous_phase == "IDLE", new_phase == "SCOUT")`: all 5 local state fields reset to their documented defaults (`_enemies_alive_display=0`, `_breach_count=0`, `_active_tower_hp_bars={}`, `_boss_state={}`/null-equivalent, `_boss_telegraph_cell=Vector2i(-1,-1)`) and the HUD becomes visible/interactive
- [x] AC-3 — on `mission_phase_changed(new_phase in {"MISSION_COMPLETE", "DEFEAT"})`: HUD becomes hidden/inactive ("unmounts") — the node itself is NOT destroyed or freed
- [x] AC-4 — `_enemies_alive_display` increments +1 on `monster_spawned`, decrements -1 on `monster_died`/`monster_breached`, decrements -N on `monsters_died_batch`, clamped at a floor of 0
- [x] AC-5 — `_breach_count` increments +1 on any `monster_breached`, tier-agnostic, never resets mid-mission (only resets on the SCOUT mount, AC-2)
- [x] AC-6 — `_active_tower_hp_bars[tower_id]` is set/updated from `tower_damaged`'s own `current_hp`/`max_hp` payload fields; cleared entirely (not per-entry) on `mission_phase_changed → INTERMISSION`
- [x] AC-7 — `_boss_state` is set on a BOSS-tier `monster_spawned` only if currently null/empty; a second BOSS-tier spawn while already set logs a warning and is discarded without overwriting; cleared on `boss_died` only if the received `entity_id` matches — a non-matching or already-null `entity_id` is discarded as stray

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

```gdscript
class_name MissionHud
extends CanvasLayer

var _enemies_alive_display: int = 0
var _breach_count: int = 0
var _active_tower_hp_bars: Dictionary[int, Vector2] = {}
var _boss_state: Dictionary = {}          # {} = null-equivalent
var _boss_telegraph_cell: Vector2i = Vector2i(-1, -1)   # Story 006 populates this
var _terminal: bool = false               # latched on MISSION_COMPLETE/DEFEAT

func _ready() -> void:
    GEventBus.mission_phase_changed.connect(_on_mission_phase_changed)
    GEventBus.monster_spawned.connect(_on_monster_spawned)
    GEventBus.monster_died.connect(_on_monster_died)
    GEventBus.monsters_died_batch.connect(_on_monsters_died_batch)
    GEventBus.monster_breached.connect(_on_monster_breached)
    GEventBus.tower_damaged.connect(_on_tower_damaged)
    GEventBus.boss_died.connect(_on_boss_died)
    # Story 002+ add their own subscriptions in the same _ready(), never a
    # second competing _ready() — this is the ONE outer-root scaffold.
```

- This story establishes ONLY the outer-root scaffold and Rule 4's 5 state fields plus their direct subscription handlers. It does NOT implement the Planning/Combat Cluster child nodes (Story 002), any visual rendering (Stories 003-011), or any of the 3 outbound signals (Stories 008-010, 012).
- `_terminal` latching: per the GDD's Edge Cases (combat events arriving after a terminal `mission_phase_changed` but before `_exit_tree()` runs, since Godot processes signals within the same frame before any deferred cleanup) — set `_terminal = true` on receipt of `MISSION_COMPLETE`/`DEFEAT` and short-circuit all further Rule-4 mutation handlers for the rest of the instance's life. This flag is read by every story added after this one.
- Mount reset (AC-2) must be a single explicit function (`_reset_local_state()`) called from the phase-changed handler — not scattered inline — since Story 002+ will extend it with their own fields (e.g. Story 006's `_boss_telegraph_cell` is already declared here per ADR-0031, reset alongside the rest).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: Planning Cluster / Combat Cluster child scene structure and lifecycle
- Story 011: the actual visual widgets (HP bars, boss bar UI, breach counter label) that read these state fields — this story only maintains the data, not its presentation
- Stories 003-010, 012: all rendering, direct-Autoload calls, and outbound signal emission

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-1**: `_ready()`/`_exit_tree()` fire-once
  - Given: a fresh `MissionScene` load
  - When: the mission runs through several internal phase transitions (SCOUT→PRE_WAVE→WAVE_ACTIVE→INTERMISSION)
  - Then: `_ready()`'s fire count remains 1 throughout — no internal phase transition destroys/recreates the `MissionHud` node itself

- **AC-2**: Mount reset
  - Given: a `MissionHud` instance with non-default state (e.g. `_breach_count=3`)
  - When: `mission_phase_changed("IDLE", "SCOUT")` fires
  - Then: all 5 fields reset to documented defaults exactly once

- **AC-4**: Enemy count clamp
  - Given: `_enemies_alive_display=0`
  - When: `monster_died` fires with no prior `monster_spawned`
  - Then: `_enemies_alive_display` remains 0 (never goes negative)
  - Edge cases: `monsters_died_batch` decrementing below 0 also clamps to 0

- **AC-7**: Boss-state single-slot guard
  - Given: `_boss_state` already set from creature A
  - When: a second BOSS-tier `monster_spawned` fires for creature B
  - Then: `_boss_state` still reflects creature A, a warning is logged, no overwrite occurs
  - Edge cases: `boss_died` for a non-matching `entity_id` is a no-op; `boss_died` while `_boss_state` is already null is a no-op (idempotent)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/mission-hud/hud-scaffold-local-state_test.gd` — must exist and pass

**Status**: [x] Created — `tests/integration/mission-hud/hud-scaffold-local-state_test.gd` (16 tests, passing)

---

## Dependencies

- Depends on: None
- Unlocks: Story 002 (Phase-Gated Cluster Lifecycle), and every other story in this epic (all build on this scaffold)

---

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 7/7 passing (16 integration tests, all passing).
**Deviations**:
- **Real, not fabricated scene attachment point found**: ADR-0002/GDD both call for `MissionHud` as a static `CanvasLayer` child of the mission scene, described generically as `MissionScene.tscn`. The actual, only-existing mission scene is `src/gameplay/missions/the_gap/the_gap.tscn`, whose `HUD` `CanvasLayer` node was already present as an explicitly-documented placeholder ("Mission HUD remains Skeleton" per `the_gap.gd`'s own header comment). Attached `mission_hud.gd` to that existing `HUD` node rather than creating a parallel/duplicate node — the existing debug Panel (Phase/Wave/Timer/Help labels), still directly managed by `the_gap.gd`, was left untouched; reconciling it into the real HUD's PC-4 rendering is Story 011's scope, not this one's.
- **AC-1 (`_ready()`/`_exit_tree()` fire-once) verified via live Godot MCP** (`run_project` + `run_script` against the real running `the_gap.tscn`), not a gdUnit test — this project's established test convention never instantiates scene-tree-dependent classes via `add_child()`, so `_ready()`-triggered subscription-connection behavior falls outside what the existing test suite exercises; matches the GDD's own precedent (Rule 6's equivalent claim was verified the same way, not via a unit test).
- `monster_spawned`'s BOSS-tier detection required resolving `MonsterResource.tier` via `GGameDataRegistry.get_monster_resource()` — the GDD's Rule 4 text says "on monster_spawned with BOSS tier" but `MonsterSpawnedEvent`'s own payload has no `tier` field (only `monster_died` does); this is a read-only Criterion-A-shaped lookup, not a new direct-call classification requiring an ADR amendment (ADR-0031 already lists `GameDataRegistry` reads generically alongside its 3 named direct calls).
**Test Evidence**: Integration — `tests/integration/mission-hud/hud-scaffold-local-state_test.gd`.
**Code Review**: Pending — deferred to a batch pass at a later Mission HUD checkpoint, matching Epic 08's established pattern.

**Addendum (2026-07-20, post-Story-002)**: a full-project regression run after Story 002 shipped caught a real regression this story's own test file introduced: Story 002 extended `_on_mission_phase_changed()`'s SCOUT-mount branch to call `_spawn_planning_cluster()`, which dereferences the `@onready`-resolved `_planning_cluster_host` — but this story's tests originally used bare `MissionHud.new()` with no `add_child()`, so that reference was never resolved (stayed null), crashing 3 tests with `Cannot call method 'add_child' on a null value`. Fixed by updating this test file's fixture to match Story 002/003's now-established convention (build `CombatCluster`/`PlanningClusterHost` children, `add_child()` the whole thing into the test's own tree). Re-verified clean: 29/29 across all 3 mission-hud test files, 0 errors.
