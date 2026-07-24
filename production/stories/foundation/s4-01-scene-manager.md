# S4-01 — SceneManager Autoload

**Story ID**: S4-01
**Epic**: Foundation
**Layer**: Foundation
**Type**: Integration
**Owner**: engine-programmer
**Sprint**: 4
**Estimate**: 1.0 day
**Status**: Complete
**Manifest Version**: 2026-05-16

## Context

**GDD**: None — this is an ADR-only requirement. Neither `design/gdd/systems-index.md`
nor any file in `design/gdd/` documents SceneManager; it was introduced purely at
the architecture layer by ADR-0002's 2026-05-24 revision. Requirements below are
sourced directly from ADR-0002's Decision, Context, and Verification Required
sections rather than a GDD acceptance-criteria list.

**Requirement**: No TR-ID exists for this system (the TR registry is GDD-driven;
SceneManager predates any GDD coverage). Track this story by its ADR reference only.

**ADR Governing Implementation**: `docs/architecture/adr-0002-scene-autoload-structure.md` (Accepted, revised 2026-05-24)

**ADR Decision Summary**: SceneManager is Autoload #6 (after GameDataRegistry #5,
before WaveManager #7). It owns SANCTUARY↔MISSION scene transitions exclusively —
no other system may call `get_tree().change_scene_to_packed()` directly. It
publishes `scene_transition_started` before unloading the current scene and
`scene_transition_completed` after the new scene is ready. It only initiates
transitions in response to terminal mission events (`mission_complete`,
`hero_died`) — Wave Manager's FSM must have reached a terminal state first, so
mid-wave transitions are architecturally impossible. SceneManager and Wave
Manager are independent FSMs: SceneManager does not know which mission phase is
active; Wave Manager does not know which scene is loaded.

**Engine**: Godot 4.6.2 | **Risk**: LOW — `get_tree().change_scene_to_packed()`
and Autoload registration are stable APIs unchanged through 4.6. No post-cutoff
API risk.

**Engine Notes** (from ADR-0002 Verification Required): Verify Autoload boot
order is reflected in Project Settings. Verify `SceneManager.gd` can call
`get_tree().change_scene_to_packed()` without ordering issues (boots 6th, after
all data Autoloads).

**Performance budget**: No transition-time budget is specified in ADR-0002 —
scene transitions are not a per-frame hot path, so this story is not currently
perf-gated. If loading-screen UX work in a later sprint reveals a real budget
need, add one then. (Closed during `/story-readiness`, 2026-07-03.)

**Control Manifest Rules (Foundation layer)**:
- Required: SceneManager publishes `scene_transition_started` before unloading
  the current scene and `scene_transition_completed` after the new scene is ready
- Required: SceneManager only initiates transitions in response to terminal
  mission events (`mission_complete`, `hero_died`)
- Forbidden: Any other system calling `get_tree().change_scene_to_packed()` directly
- **Note**: `docs/architecture/control-manifest.md`'s own Foundation Layer Rules
  table still shows the stale 5-Autoload order (SceneManager at position 5, no
  GameDataRegistry). ADR-0002 (revised 2026-05-24) is authoritative — the manifest
  needs regeneration via `/create-control-manifest`, tracked separately, not a
  blocker for this story.

## Dependencies

- S4-02 GameDataRegistry — **must be Complete first** (SceneManager boots at
  position 6, immediately after GameDataRegistry at position 5)
- ADR-0001 (EventBus) — Accepted, satisfied (Sprint 2)

## Files to Create

- `src/core/scene_manager.gd` — SceneManager autoload
- `tests/unit/scene_manager/scene_manager_test.gd`
- `tests/integration/foundation/scene_manager_transition_test.gd`

## Acceptance Criteria

- [ ] AC-1: `SceneManager` registers as Autoload #6 in `project.godot`, immediately
      after `GameDataRegistry` (#5) and before `WaveManager` (#7)
- [ ] AC-2: Calling the public transition method with a valid mission scene path
      loads that scene via `get_tree().change_scene_to_packed()`
- [ ] AC-3: `scene_transition_started` fires on EventBus before the current scene
      is unloaded
- [ ] AC-4: `scene_transition_completed` fires on EventBus after the new scene's
      `_ready()` has run
- [ ] AC-5: SceneManager does not initiate a transition except in direct response
      to `mission_complete` or `hero_died` — no other trigger path exists
- [ ] AC-6: SceneManager holds no reference to WaveManager's internal phase state,
      and WaveManager holds no reference to which scene is currently loaded — the
      two FSMs are verifiably independent (no cross-imports, no shared private state)
- [ ] AC-7: Autoloads that persist across both SANCTUARY and MISSION scenes
      (EventBus, SavePersistence, Grid, Pathfinding, GameDataRegistry, SceneManager,
      WaveManager) retain their state across a transition — verified by checking a
      known EventBus-held value survives a SANCTUARY→MISSION→SANCTUARY round trip

## Implementation Notes (from ADR-0002)

### Boot Order Context

```
EventBus(1) → SavePersistence(2) → Grid(3) → Pathfinding(4) →
GameDataRegistry(5) → SceneManager(6) → WaveManager(7)
```

### Context Boundary Rule

SceneManager owns SANCTUARY↔MISSION loading/unloading. Wave Manager owns the
inner mission phase FSM (SCOUT→WAVE_ACTIVE→INTERMISSION→MISSION_COMPLETE/DEFEAT).
These two FSMs are independent — SceneManager does not know which mission phase
is active; Wave Manager does not know which scene is loaded.

### Transition Safety

SceneManager only initiates transitions in response to terminal mission events
(`mission_complete`, `hero_died`) — events Wave Manager emits only after its FSM
has reached a terminal state. Mid-wave transitions are architecturally impossible
by this design.

### Scene Hierarchy (for context — not implemented by this story)

```
SanctuaryScene ←──SceneManager──→ MissionScene
  Crafting                          Hero (CharacterBody2D)
  Menagerie                         MonsterMgr (Area2D)
  Defense Bldg                      TowerMgr (Node2D)
  Inventory                         D&S, Constellation
  Resource Econ                     MissionHUD
```

Autoloads persist across both scenes. WaveManager idles in IDLE state during
SanctuaryScene; activates on `mission_launched`.

## Out of Scope

- The actual `SanctuaryScene.tscn` and `MissionScene.tscn` scene files and their
  child node contents — those are assembled in S4-09 ("The Gap" mission scene)
- Loading screen UI/visuals — SceneManager's transition signals are the hook
  point; actual loading-screen presentation is a Presentation-layer concern
- Wave Manager's inner FSM — already implemented (S3-06), untouched here

## QA Test Cases

- **AC-1**: Autoload registration order
  - Given: `project.godot`
  - When: `[autoload]` section is read
  - Then: `GSceneManager` appears immediately after `GGameDataRegistry` and before `GWaveManager`

- **AC-2/3/4**: Transition signal sequence
  - Given: SceneManager autoload live, a stub/test scene registered
  - When: transition method is called with a valid scene path
  - Then: `scene_transition_started` fires, then the scene loads, then `scene_transition_completed` fires — in that order
  - Edge cases: transition called with an invalid/missing scene path → no crash, transition aborts, no `scene_transition_completed` fires

- **AC-5**: Transition trigger restriction
  - Given: SceneManager subscribed to EventBus
  - When: any EventBus signal other than `mission_complete` or `hero_died` fires
  - Then: no scene transition occurs
  - Edge cases: `mission_complete` and `hero_died` both fire in the same frame (race) — transition occurs exactly once, not twice

- **AC-6**: FSM independence (static/structural check)
  - Given: `src/core/scene_manager.gd` and `src/gameplay/wave_manager.gd`
  - When: source is inspected
  - Then: neither file references the other's class name or private fields directly

- **AC-7**: State persistence across transition
  - Given: a known value set on a persistent Autoload (e.g. EventBus-tracked player gold via SavePersistence)
  - When: a SANCTUARY→MISSION→SANCTUARY round trip occurs
  - Then: the value is unchanged

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/unit/scene_manager/scene_manager_test.gd` — AC-1, AC-5, AC-6
- `tests/integration/foundation/scene_manager_transition_test.gd` — AC-2, AC-3, AC-4, AC-7

**Status**: [ ] Not yet created

## Dependencies

- Depends on: S4-02 (GameDataRegistry — boot order requires it complete first)
- Unlocks: S4-08 (WaveManager Autoload reorder — requires SceneManager to exist at position 6 first), S4-09 (mission scene assembly)

## Completion Notes
**Completed**: 2026-07-03
**Criteria**: 7/7 passing (AC-1 through AC-7). 13/13 automated tests passing, 0 errors, 0 failures.
**Deviations**: Advisory only — TD-test-002 (engine-exit resource warning, already logged); `control-manifest.md` staleness (pre-existing, not introduced here).
**Test Evidence**: Integration — `tests/unit/scene_manager/scene_manager_test.gd` (9 tests), `tests/integration/foundation/scene_manager_transition_test.gd` (4 tests) — 13 total, all passing.
**Code Review**: Complete — 4 Required Changes found and fixed (doc comments, AC-7 test strengthened to check real value persistence not just identity, frame-count race replaced with signal-await, `current_scene` restoration added). A critical bug was then found DURING fix verification: `_do_transition()` emitted `scene_transition_completed` before resetting `_transition_in_progress`, causing a real 5-minute test hang when a caller awaited completion and immediately started a second transition (exactly what the AC-7 round-trip test does). Fixed by reordering the guard reset before the emit; re-verified — same test now completes in 100ms. Re-reviewed, verdict APPROVED.
