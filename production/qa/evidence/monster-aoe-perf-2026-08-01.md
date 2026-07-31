# Evidence: Monster System AoE Death-Burst Performance (AC-40)

**GDD**: `design/gdd/monster.md`, AC-40 `[Performance · BLOCKING]`
**Tech Debt**: `TD-monster-004` (AC-28 half closed 2026-08-01; this closes the AC-40 half)
**Date**: 2026-08-01
**Method**: Live Godot MCP `run_script` against the pinned Godot 4.6.2.stable binary

## Deviation from AC-40's literal evidence path

Same accepted deviation as `monster-perf-2026-08-01.md` (AC-28) and `TD-perf-001`: no
interactive/windowed profiler session is available in this agent environment, so evidence is a
`.md` file with real numeric `Time.get_ticks_usec()` measurements instead of a literal
`production/qa/evidence/monster-aoe-perf-[date].png` screenshot.

## Setup

Real, isolated `Grid` (2 cells: one `SPAWN`, one `GOAL` — path length is irrelevant to this AC,
only spawn validity matters) + `PathfindingSystem` + `MonsterManager` (not stubs), built via
`run_script` against the live engine, matching AC-28's own already-established construction
pattern:

- **21 STANDARD monsters + 1 BOSS** (`base_hp=2000`, `tier=2`, real `boss_attack_range_cells`/
  `base_damage`/`base_attack_interval` fields set), all spawned via the real production
  `MonsterManager.spawn_monster()` API — all 22 confirmed `ACTIVE` (`spawn_fail_count == 0`).
- **22 lethal `MonsterDamageTaken` payloads** (`amount = 9999`, `source_type = 1` i.e. hero),
  one per entity, appended **directly to `MonsterManager._pending_damage`** rather than routed
  through the real `GEventBus.monster_damage_taken` signal. Deliberate: this isolated
  `MonsterManager` instance shares the same global `GEventBus` singleton as whatever real scene
  is running (in this case the project's default main scene), which is also subscribed to that
  signal — emitting through the shared bus risked cross-talk with real production entities. The
  EventBus delivery hop itself isn't what AC-40 measures; `_pass1_damage()`'s processing cost of
  22 simultaneous lethal hits is. Bypassing the hop keeps the measurement deterministic and
  isolated without touching the real running scene's own state.
- **Real spy listeners** connected directly to the shared `GEventBus.monsters_died_batch`,
  `GEventBus.monster_died`, and `GEventBus.boss_died` signals (read-only observation, no
  mutation) to verify the emission-shape claims in AC-40's own THEN clause, not just the timing.
- **One real `_physics_process(delta)` call**, timed with `Time.get_ticks_usec()` — covering the
  damage pass, BOSS logic pass, movement pass, and death/absorbed-flush pass in a single frame,
  matching AC-40's literal "the damage pass, death sequences, and absorbed flush all complete
  within a single `_physics_process` call."

## Result (22 simultaneous lethal hits, 1 physics frame)

| Assertion (AC-40's THEN clause) | Result |
|---|---|
| Total Monster System CPU time ≤ 4.0 ms | **0.128 ms** — ✅ PASS (3.2% of budget) |
| Exactly one `monsters_died_batch` emitted, with all 22 payloads | ✅ `batch_calls == [22]` — exactly 1 call, size 22 |
| No individual `monster_died` events (mutual exclusivity) | ✅ `individual_monster_died_calls == 0` |
| `boss_died` still emits synchronously (unbatched) for the BOSS | ✅ exactly 1 call, `cause="killed"`, correct `entity_id`/`monster_id` |
| All 22 entities leave `active_monsters` | ✅ `active_before=22` → `active_after=0` |

**Verdict**: **PASS on every clause**, not just the timing budget. 0.128ms is 3.2% of the 4.0ms
budget — comfortable headroom, consistent with AC-28's similarly-low measured cost for Monster
System's per-frame passes in general. Because every behavioral assertion (batch shape, mutual
exclusivity, `boss_died` timing, active-count drop) was independently confirmed correct alongside
the timing number, this measurement doesn't carry the same "is this number real?" uncertainty
AC-28's first (invalid, `_is_wave_active`-omitted) attempt did — the observed state changes prove
genuine work occurred, not a gated no-op.

**Note**: a benign engine warning fired during spawn (`PathfindingSystem.find_path: tier
parameter reserved for MVP. Proceeding with STANDARD routing.`) — expected, documented behavior
(tier-specific routing is explicitly out of MVP scope per that system's own doc comments), not an
error and not something this measurement depends on.

## Summary

| Question | Status |
|---|---|
| Does Monster System stay within its 4.0ms/frame budget for a 22-death AoE burst (AC-40)? | ✅ **Yes** — 0.128ms, real behavioral correctness confirmed alongside the timing |
| Does the batching/mutual-exclusivity/boss_died contract hold under this exact load? | ✅ **Yes** — every clause independently verified, not assumed |

`TD-monster-004` is now fully closed — both AC-28 (2026-08-01, `monster-perf-2026-08-01.md`) and
AC-40 (this file) have real, live-measured evidence.
