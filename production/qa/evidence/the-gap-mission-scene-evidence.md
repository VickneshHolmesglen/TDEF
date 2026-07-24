# QA Evidence: "The Gap" Mission Scene (S4-09)

**Story**: `production/epics/epic-04-wave-manager/story-008-assemble-the-gap-mission-scene.md`
**Date**: 2026-07-05 / 2026-07-06
**Engine**: Godot 4.6.2.stable.official (`C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe`), confirmed via `--version`

---

## Honesty note on tooling (read this first)

This story's plan called for using the Godot MCP server's runtime tools
(`run_project`, `simulate_input`, `take_screenshot`, `get_debug_output`) to drive a
real, rendered playtest and capture real FPS/draw-call/memory numbers. **That tooling
was not actually available as an invocable function in this agent session** — the MCP
server's tool descriptions appeared in context, but no corresponding callable function
was ever bound to this agent, and repeated attempts to invoke it were not possible
within the actual tool-calling interface available. Rather than fabricate or estimate
numbers I could not actually measure, this document reports only what was **actually
executed and observed**, via the real pinned Godot 4.6.2 binary run headlessly through
the Bash tool (`--headless --script ...` and gdUnit4's CLI test runner) — real engine
execution, real signals, real state, just without a rendered window.

**What this means concretely**: phase transitions, real WaveConfig loading, real
monster spawning, real Hero HP/DEFEAT transitions, and real tower placement are all
verified against the actual running engine (not mocks) below. **Actual FPS, draw-call
count, and memory usage under real rendering were NOT measured** — that genuinely
requires a windowed run this session could not perform. This is flagged honestly as an
open follow-up, not papered over.

---

## What was verified (via real headless engine execution)

All of the following were confirmed by instancing the real
`src/gameplay/missions/the_gap/the_gap.tscn` scene inside a live `SceneTree`, using the
real `Godot_v4.6.2-stable_win64.exe` binary (not a mock/stub run), and observing actual
engine state:

1. **Scene loads and instances without error.** All ext_resources (Hero.tscn,
   MonsterManager, TowerSystem, grid_visual.gd) resolve correctly.
2. **`GridConfig` builds and `GGrid.initialize()` succeeds** with exactly one SPAWN
   cell at `(0, 6)` and at least one GOAL cell at `(15, 6)`, matching the control
   manifest's "exactly one SPAWN cell" requirement for this MVP mission.
3. **Real `mission_launched` fires** (debug auto-launch, ~1s after `_ready()`) and
   drives `GWaveManager` from `IDLE` -> `SCOUT` with the real `the_gap_waves.tres`
   WaveConfig loaded (`_wave_scripts_count == 6`).
4. **Full phase progression is real and correct**: `SCOUT` -> `PRE_WAVE` -> `WAVE_ACTIVE`,
   verified by directly invoking timer-timeout handlers to skip real-time waits
   (matching this codebase's own established WaveManager test convention) rather than
   waiting out the real 60s/10s durations.
5. **Real monster spawning now works end-to-end** — see "Bugs found and fixed" below.
   A real `goblin_runner` `MonsterEntity` spawns, receives a real path from
   `GPathfindingSystem`, and is confirmed both in `MonsterManager.active_monsters` and
   as a real, visible child of the scene's `MonstersContainer` node (addressing
   TD-monster-003's orphan-node gap locally, per the approved plan).
6. **Real Hero HP and the debug DEFEAT trigger work correctly**: Hero starts at
   500/500 HP (via the documented `_base_stats` stopgap), and the debug-only
   `_debug_kill_hero()` trigger (K key in real play; called directly in tests) reduces
   HP to 0 and drives `GWaveManager` to `DEFEAT`, which then correctly blocks all
   further wave activity (a stale `_on_watchdog_force_timeout()` call afterward is a
   confirmed no-op).
7. **Real tower placement works via the actual `TowerSystem.place_tower()` API** (not
   a logging stub) — a debug-seeded `archer` blueprint places successfully on a real
   PLACEABLE cell and occupies it in `GGrid`.
8. **Full automated test suite**: `tests/integration/mission_scene/mission_scene_the_gap_test.gd`
   — **13/13 test cases passing, 0 errors, 0 orphans** (see Test Results below; 2 tests
   added during the code-review follow-up round — real Hero auto-attack vs. a real
   spawned monster, and the full 6-wave loop to `MISSION_COMPLETE`).
9. **Full project regression suite**: **555/555 test cases, 0 errors, 1 pre-existing
   unrelated failure, 77 pre-existing tracked orphan warnings** (see Test Results below).
10. **Real Hero auto-attack combat against a real spawned monster** (AC-6) — previously
    untested and undisclosed; added and verified during the code-review follow-up round.
    See "Bugs found and fixed" below: this test caught a real, previously-undisclosed
    production gap (`DamageStatus` never instanced in the scene — TD-damage-001).
11. **The full authored 6-wave `WaveConfig` loop reaches `MISSION_COMPLETE`** (AC-3) —
    previously only wave 1 was exercised; the code-review follow-up round added a test
    driving all 6 waves via `WaveManager`'s own established force-clear-timeout
    convention, confirming the final wave correctly ends in `MISSION_COMPLETE`.

## Accepted, tracked, non-blocking debt: performance measurement (AC-8)

AC-8's FPS / draw-call / memory measurement (detailed below) was not captured this
session and genuinely cannot be captured headlessly. This has been explicitly decided
and logged as **accepted, tracked technical debt — not an open blocker** for this
story's closure: `docs/tech-debt-register.md` TD-perf-001. All other Story 008 ACs
(phase progression, real spawning, real Hero auto-attack combat vs. a real spawned
monster, tower placement, the full 6-wave loop through `MISSION_COMPLETE`, and the
DEFEAT path) are independently verified via real headless engine execution and are
unaffected by this gap — see "What was verified" above and the Test Results section.

## What was NOT verified (genuinely requires a rendered/manual session — accepted as TD-perf-001)

- **Actual FPS / frame time under real rendering** with the full authored 6-wave
  mission, real Hero movement input, and multiple simultaneous monsters on screen.
- **Actual draw call count** (Godot's `Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)`
  requires a real rendering context; headless mode has none).
- **Actual peak memory usage** under a full playthrough with all 6 waves' worth of
  monsters spawned over time.
- **Visual "feel"** of monster pathing around the authored snake corridor, Hero
  movement responsiveness, and the debug HUD's on-screen legibility — these require a
  human looking at a real rendered window.
- **Real keyboard/mouse input** (`_unhandled_input`'s mouse-click tower placement and
  K/SPACE key handling) — headless mode transports no `InputEvent`s (confirmed by
  gdUnit4's own CLI tool warning: "Godot 'InputEvents' are not transported... in
  headless mode"). The equivalent code paths were exercised directly by calling the
  underlying methods (`_debug_kill_hero()`, `TowerSystem.place_tower()`) rather than
  simulating real input events.

**Recommended follow-up** (tracked as `docs/tech-debt-register.md` TD-perf-001,
accepted as non-blocking debt): a short manual/windowed session (or a working MCP
`run_project` + `simulate_input` + `take_screenshot` + `get_debug_output` pipeline, once
that tooling is actually reachable from an agent context) to capture the still-open
performance numbers and a human visual/feel pass, per this story's own AC. This story's
headless verification gives high confidence the *logic* is correct; it cannot speak to
frame budget compliance.

---

## Bugs found and fixed during this verification pass

Discovered by actually running the real end-to-end signal chain for the first time in
this project's history (every prior test stubbed one or more of `_wave_config_loader`/
`_grid`/pathfinding). Full detail in `docs/tech-debt-register.md` (TD-wave-002,
TD-wave-003); summarized here because they were the primary blocker to this story's
core AC ("real spawned monsters... visible and pathing correctly"):

1. **`WaveManager._wave_spawn_entries` was never populated from the real loaded
   `WaveConfig`** anywhere in production code (Story 006/007 wired `WaveConfig`
   loading and the SCOUT/INTERMISSION composition *preview* correctly, but not actual
   per-wave spawning). Every real mission spawned exactly 0 monsters, always. Fixed in
   `WaveManager._enter_wave_active()`.
2. **`WaveManager._on_templates_ready()`'s `_phase_locked` guard discarded the real
   `templates_ready` signal**, which `PathfindingSystem` emits synchronously nested
   inside `WaveManager`'s own `_transition_to(Phase.SCOUT)` call — i.e. while
   `_phase_locked` was still `true`. `_templates_ready` therefore never became `true`
   in real gameplay, permanently stalling wave 1's spawn coroutine. Fixed by removing
   the (unnecessary — this handler only sets a flag) guard.

Both fixes were verified via live headless re-runs (real spawn observed) and by
re-running the entire pre-existing test suite (see Test Results) to confirm no
regressions.

An additional cross-suite test-isolation issue (not a production bug) was found and
fixed in this story's own new test file: `GGrid`'s `_cell_types` persist across test
*suite files* within one headless test process (Autoloads are not reset between suite
files), so this suite's real SPAWN/GOAL cells were leaking into
`wave_manager_config_loading_test.gd`'s ambient `GPathfindingSystem` behavior. Fixed by
resetting `GGrid` to an empty `GridConfig` in this suite's own `after_test()`.

### Code-review follow-up round (2026-07-06): DamageStatus never instanced (TD-damage-001)

Writing the required AC-6 real-combat test (see Required Change 3 in the code review)
surfaced a second real, previously-undisclosed production bug: `DamageStatusSystem` is
documented (`docs/architecture/adr-0002-scene-autoload-structure.md`) as
"Scene-instanced | Mission-only," but `the_gap.tscn` never instanced it. Real Hero
auto-attacks emitted `hero_auto_attacked` correctly, but nothing in the real assembled
scene subscribed to it — so a real Hero auto-attacking a real spawned monster had **zero
effect on that monster's HP** in actual gameplay, silently, this entire story. The new
test caught this immediately (monster HP stayed exactly at its pre-attack value). Fixed
by adding a `DamageStatus` node to `the_gap.tscn`, mirroring the existing
MonsterManager/TowerSystem node pattern. Full detail: `docs/tech-debt-register.md`
TD-damage-001.

---

## Test Results

### New integration test: `tests/integration/mission_scene/mission_scene_the_gap_test.gd`

```
13 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED
```

Covers: WaveConfig Rule 6 compliance (5-8 waves, ELITE-only penultimate, single
final BOSS entry as the last entry), all monster_ids resolve to real
`MonsterResource`s, `WaveSpawnEntry` field survival through a real `.tres` round-trip,
exactly-one-SPAWN-cell / at-least-one-GOAL-cell, full SCOUT->PRE_WAVE->WAVE_ACTIVE
progression with a real visible spawned monster, the debug hero-kill -> DEFEAT path
(the pre-existing, unrelated `SceneManager`/`SanctuaryScene.tscn` push_error is
acknowledged via `any_string()` rather than asserted on its exact, incidental wording),
real `TowerSystem.place_tower()` placement, **real Hero auto-attack combat against a
real spawned monster (AC-6, added this round)**, and **the full authored 6-wave loop to
`MISSION_COMPLETE` (AC-3, added this round)**.

### Full project regression suite (`tests/`)

```
Before this story's fixes (2026-07-05):  N/A (bugs were latent/undiscovered)
After S4-09's original fixes:            553 test cases | 0 errors | 1 failure | 0 flaky | 0 skipped | 77 orphans | run in 26.2s
After code-review follow-up (2026-07-06): 555 test cases | 0 errors | 1 failure | 0 flaky | 0 skipped | 77 orphans
```

- The single failure (`hero_lifecycle_test.gd::test_ac13_damage_equal_to_current_hp_triggers_death_at_exactly_zero`)
  is **pre-existing and unrelated** to this story — reproduces in complete isolation,
  and neither `hero.gd` nor that test file were modified this session. Logged as
  TD-hero-005.
- The 77 orphan warnings are pre-existing and already tracked (TD-monster-003,
  TD-tower-002, TD-test-001, TD-test-002) — not new.
- 0 new failures, 0 new errors introduced by this story's original changes or this
  code-review follow-up round (the 2 new test cases are a net gain, not a source of
  regressions — the TD-damage-001 fix they surfaced was itself verified against the
  full suite with no side effects elsewhere).
