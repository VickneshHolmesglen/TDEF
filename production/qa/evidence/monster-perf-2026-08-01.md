# Evidence: Monster System Field-Scale Active-Agent Performance (AC-28)

**GDD**: `design/gdd/monster.md`, AC-28 `[Performance · BLOCKING]`
**Tech Debt**: `TD-monster-004` (logged 2026-07-10 — measurement never captured before this pass)
**Date**: 2026-08-01
**Method**: Live Godot MCP `run_script` against the pinned Godot 4.6.2.stable binary

## Deviation from AC-28's literal evidence path

AC-28 specifies evidence saved as `production/qa/evidence/monster-perf-[date].png` (a literal
Godot profiler window screenshot). No interactive/windowed profiler session is available in this
agent environment — matching the same constraint already disclosed and accepted for `TD-perf-001`
and `tower-mastery-accrual-profiling-evidence.md`, both of which used numeric `Performance`
monitor / direct-timing measurements captured via the Godot MCP bridge instead of a literal
profiler screenshot, saved as a `.md` evidence file. This file follows that same established,
already-accepted precedent.

## Setup

A real, isolated `Grid` + `PathfindingSystem` + `MonsterManager` (not stubs — matching AC-28's
own "requires a real Godot scene with Grid Autoload and Pathfinding stubs populated" note,
using the same `_setup_isolated_pathfinding()`-equivalent construction already established in
`tests/integration/core/combat_loop_test.gd`), built via `run_script` against the live engine:

- **Grid**: 16×12 cells, one real `SPAWN` cell, one real `GOAL` cell, connected by a genuine
  multi-cell corridor built via the project's own snake-grid test helper. The real production
  `PathfindingSystem.find_path()` resolved an 11-cell route (the corridor's actual shortest legal
  path — the helper's snake shape produces a shorter route than the full 191-cell traversal when
  the path length spans multiple full row-widths, since consecutive row turnarounds create a
  legal shortcut column; not a pathfinding defect, just a property of that particular test-helper
  shape at this path length).
- **150 STANDARD monsters** (`base_hp=70`, `base_speed=2.0`, `tier=0`), all spawned via the real
  production `MonsterManager.spawn_monster()` API at the one real `SPAWN` cell, `wave_index=1`,
  `difficulty_tier=1` — all 150 confirmed `ACTIVE` immediately (real path assigned at spawn,
  `spawn_fail_count == 0`), matching AC-28's `MAX_ACTIVE_MONSTERS` cap exactly.
- **Wave-active state set explicitly** (`_is_wave_active = true`, `_current_wave_index = 1`) —
  `MonsterManager._physics_process()` gates all 4 processing passes behind this flag; an earlier
  measurement pass in this same session omitted it and produced a suspiciously-fast, invalid
  0.0002ms/frame result with zero actual monster movement (`distance_moved == 0`) — caught before
  being reported, by directly verifying a monster's `global_position` changed across the
  measurement window, not by trusting the first number alone.
- **Real `_physics_process(delta)` calls**, invoked directly 60 consecutive times via
  `mm.call("_physics_process", 1.0/60.0)`, each timed individually with `Time.get_ticks_usec()`
  — isolating Monster System's own CPU cost specifically, per AC-28's literal wording ("total
  Monster System `_physics_process` CPU time"), not a whole-frame/whole-engine sample.

## Result (60 consecutive physics frames, 150 ACTIVE monsters)

| Metric | Value | Budget (AC-28) |
|---|---|---|
| Avg CPU time per frame | **0.328 ms** | ≤ 2.0 ms |
| Max CPU time (single frame) | **0.857 ms** | ≤ 2.0 ms |
| p95 | 0.504 ms | — |
| p99 | 0.614 ms | — |
| Monsters still ACTIVE after 60 frames | 150 / 150 | 150 (no unexpected despawn/breach) |
| First entity distance moved | 128 world units (= 2 cells at `scaled_speed=2.0`, exactly matching 1 real second of simulated travel) | confirms real movement occurred, not a gated no-op |

**Verdict**: **PASS.** Average cost is 16.4% of the 2.0ms budget; even the single worst frame
(0.857ms) is 42.9% of budget, leaving comfortable headroom. This isolates Monster System's own
`_physics_process` cost specifically — it does not independently re-measure whole-frame/whole-
engine cost (rendering, other Autoloads) in this pass. `TD-perf-001`'s own separate whole-scene
measurement (Wave 1, 0–2 monsters, 60 FPS min/avg/max, p99 frame time 16.87ms) already confirmed
the project's baseline frame budget is otherwise healthy at low monster counts; this measurement
adds confidence that Monster System's own cost does not become the bottleneck even at the full
150-monster cap, but does not re-verify total frame time at that same scale in a rendered
context.

## AC-40 (AoE Death Burst Performance) — separately BLOCKING, not measured this pass

AC-40 (22 simultaneous lethal hits in one frame, ≤4.0ms) is a distinct scenario from AC-28 (150
monsters moving, no deaths) and was not measured in this pass — it requires a different setup
(damage dispatch + death/absorbed-flush passes under load, not movement). Left open; not
conflated with this AC-28 closure.

## Summary

| Question | Status |
|---|---|
| Does Monster System stay within its 2.0ms/frame budget at the 150-monster field-scale cap (AC-28)? | ✅ **Yes** — 0.328ms avg / 0.857ms max, real movement confirmed, live-measured via Godot MCP against the pinned engine |
| Does the AoE death-burst scenario (AC-40) stay within its separate 4.0ms budget? | ⚠️ **Not measured this pass** — a distinct scenario, remains open |
