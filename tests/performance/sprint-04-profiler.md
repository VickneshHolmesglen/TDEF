# Sprint 4 Pathfinding Profiler Results

**Sprint**: 4
**Story**: S4-10 100-Agent Pathfinding Performance Stress Test
**Date**: 2026-07-06
**Run by**: engine-programmer (headless CI run, `GdUnitCmdTool.gd`, `Godot_v4.6.2-stable_win64.exe`)
**Test sources**:
- `tests/integration/core/combat_loop_test.gd::test_pathfinding_profiler_find_path_100_samples` (AC-4)
- `tests/integration/core/combat_loop_test.gd::test_pathfinding_profiler_find_path_100_samples_max_grid_24x18` (AC-2)
- `tests/integration/core/pathfinding_stress_test.gd::test_pathfinding_stress_150_monster_spawn_burst_single_frame_cost` (AC-3)

This story closes `TD-path-001` (see `docs/tech-debt-register.md`) and re-measures AC-4 with
warm route templates instead of the invalid cold-fallback number recorded in
`tests/performance/sprint-03-profiler.md`.

---

## Real gap this story fixes (context)

`docs/tech-debt-register.md`'s `TD-path-001`: the Sprint 3 AC-4 profiler test called the live
`GPathfindingSystem` autoload directly without ever building route templates, so all 100 sampled
calls fell through to a cold full-A* fallback (34.043ms avg — 34× over budget) instead of the
O(1) warm template-lookup path AC-4 actually specifies. This story fixes the test methodology,
not the implementation — no pathfinding algorithm code was touched (ADR-0004 stands).

**Also corrected during dev-story context load (2026-07-06)**: GDD OQ-6 describes a
`path_invalidated`-triggered "150 monsters simultaneously call `get_path()`" refresh burst. This
mechanism is dead code at MVP — `src/core/monster/monster_manager.gd::_on_path_invalidated()` is
an explicit no-op, since Grid's `WAVE_ACTIVE` write lock means `path_invalidated` never fires
mid-wave. The real 100+-agent scenario is a **wave-start spawn burst**
(`monster_manager.gd:286`, once per monster at spawn). AC-3 below measures the corrected
scenario. See `docs/tech-debt-register.md`'s `TD-path-002` for the stale-GDD-text follow-up this
discrepancy left behind.

---

## AC-4: `find_path()` — Warm 16×12 Grid, Avg Path Length 25 (TD-path-001 closure)

*GDD source: `design/gdd/pathfinding.md:396`. Test: `test_pathfinding_profiler_find_path_100_samples`.*

**Setup**: fresh, isolated `PathfindingSystem`/`Grid`/`EventBus` instances (not the live
`GPathfindingSystem` autoload, to avoid cross-test global-state pollution). Grid is a
single-lane snake corridor, 16 cols × 12 rows, SPAWN→PATH×24→GOAL (25 cells after SPAWN).
Templates warmed via the real production code path
(`_on_mission_phase_changed("", "SCOUT", 0.0)`) before measurement.

**Measurement protocol deviation (disclosed)**: AC-4's GDD text specifies "measured across a
10-second window." A literal 10 real-time wall-clock seconds of sampling is impractical for a
CI unit test suite. This test substitutes **1000 batches of 100 `find_path()` calls each
(100,000 total calls)** as a statistically equivalent synthetic sampling window — large enough
for a meaningful p99.9 (index 999 of 1000 sorted samples) — with one forced GC-trigger
allocation (~400,000 discarded `Vector2i` array entries) fired at batch 500, per this story's
Implementation Notes item 2.

| Metric | Measured (100-call batch total) | Target (ADR-0004) | Verdict |
|--------|----------------------------------|--------------------|---------|
| p50 | 0.0960 ms | — | — |
| p95 | 0.0990 ms | — | — |
| p99 | 0.1200 ms | — | — |
| p99.9 | 0.1370 ms | ≤ 1 ms | **PASS** (≈ 7.3× headroom) |

Raw output:
```
[PROFILER] find_path() warm 16x12 grid (avg path 25), 1000 batches of 100 calls: p50=0.0960ms p95=0.0990ms p99=0.1200ms p99.9=0.1370ms  (target: 100 calls/frame total <=1ms p99.9 per ADR-0004)
```

**Verdict: PASS.** This confirms the implementation itself was never the problem — TD-path-001's
34.043ms number was purely a test-methodology artifact of measuring the cold fallback path. With
real warm templates, 100 `find_path()` calls cost ~0.137ms at p99.9, comfortably inside the 1ms
budget with headroom to spare.

---

## AC-2: `find_path()` — Warm 24×18 Max Grid, Avg Path Length 60 (stretch case, not a hard gate)

*Test: `test_pathfinding_profiler_find_path_100_samples_max_grid_24x18`. Per S4-10 scope, this
measurement is recorded regardless of pass/fail against the provisional 1ms target — it is not
a blocking gate.*

**Setup**: identical isolated-instance pattern as AC-4, but the max mission grid size (24×18)
with a longer snake corridor (60 cells after SPAWN, spanning 3 rows).

| Metric | Measured (100-call batch total) | Provisional target | Verdict (informational) |
|--------|----------------------------------|---------------------|--------------------------|
| p50 | 0.1030 ms | — | — |
| p95 | 0.1060 ms | — | — |
| p99 | 0.1260 ms | — | — |
| p99.9 | 0.1640 ms | ≤ 1 ms (not a hard gate) | **PASS** (≈ 6.1× headroom) |

Raw output:
```
[PROFILER] find_path() warm 24x18 max grid (avg path 60), 1000 batches of 100 calls: p50=0.1030ms p95=0.1060ms p99=0.1260ms p99.9=0.1640ms  (provisional target <=1ms — not a hard gate, per S4-10 AC-2)
```

**Note**: the max-grid case is only ~20% more expensive than the 16×12 case despite a 2.4×
longer path — consistent with the O(1) template-lookup + O(k) slice cost model (ADR-0004): the
per-call cost scales with the returned slice length k, not with total grid size.

---

## AC-3: 150-Monster Wave-Start Spawn Burst (corrected scenario, replaces OQ-6's stale framing)

*Test: `tests/integration/core/pathfinding_stress_test.gd::test_pathfinding_stress_150_monster_spawn_burst_single_frame_cost`.*

**Corrected scenario**: OQ-6's original framing ("`path_invalidated` fires → 150 monsters call
`get_path()`") is dead code at MVP (see `TD-path-002`). The real "100+ simultaneous agents"
scenario is a wave-start spawn burst: up to 150 monsters spawning in the same/adjacent physics
frames, each independently calling `find_path()` once (`monster_manager.gd:286`).

**Setup**: same warm 16×12/path-25 grid as AC-4. Simulated 150 independent `find_path()` calls
from the same SPAWN cell within a single frame — this is itself a realistic sub-case (multiple
monsters spawning from the same SPAWN cell in the same frame do each call
`find_path(spawn_cell, tier)` independently), but the "all 150 in one frame" timing is a
synthetic worst-case upper bound (see finding below).

| Metric | Measured | Budget | Verdict |
|--------|----------|--------|---------|
| Total pathfinding-only cost, 150 calls, 1 frame | 0.1640 ms | ≤ 2 ms (Monster System AC-28 `_physics_process()` budget) | **PASS** |
| Same measurement | 0.1640 ms | ≤ 10.67 ms (pathfinding.md residual frame budget) | **PASS** |

Raw output:
```
[PROFILER] pathfinding-only cost of 150 find_path() calls in one frame (warm 16x12 grid, avg path 25): 0.1640ms
[PROFILER] vs Monster System AC-28 2ms physics budget: PASS (pathfinding-only cost; does not include real MonsterManager._physics_process() work)
[PROFILER] vs pathfinding.md 10.67ms residual frame budget: PASS
```

**Important real-world finding**: `assets/data/waves/the_gap_waves.tres` shows every
`WaveSpawnEntry.pre_delay` is 2.0–5.0 seconds, and `src/gameplay/wave_manager.gd::_run_spawn_sequence()`
awaits `get_tree().create_timer(entry.pre_delay).timeout` between spawn entries whenever
`pre_delay > 0.0`. **150 monsters do not spawn within the same or adjacent physics frames in any
shipped wave data — spawns are staggered several seconds apart.** This measurement is therefore
a synthetic worst-case upper bound, not an observed real gameplay frame. The real-world
per-frame pathfinding cost at wave start is almost certainly far lower than 0.164ms (likely 1-2
`find_path()` calls per frame at most, given the staggering), making this an even more
comfortable margin than the number above already suggests.

**TR-path-007 disposition**: given AC-4's real PASS (≈7.3× headroom), AC-2's real PASS (≈6.1×
headroom on the max grid), and AC-3's real PASS (≈12× headroom vs the 2ms Monster budget, ≈65×
headroom vs the 10.67ms residual budget) — all measured against the actual worst-case synthetic
scenarios, not just typical-case ones — **TR-path-007's HIGH engine-risk classification should
be formally retired**, not re-scoped. The pre-approved OQ-6 option (b) remediation
(`{template_ref, start_index}` return contract instead of an `Array[Vector2i]` copy) is
**not needed** based on these numbers. This is a recommendation for QA/technical-director
sign-off, not a decision made by this story — no remediation was implemented, per S4-10's scope.

---

## Notes

- All S4-10 measurements use fresh, isolated `PathfindingSystem`/`Grid`/`EventBus` instances
  (never the live `GPathfindingSystem`/`GGrid` autoloads), per the pattern established in
  `tests/unit/pathfinding/pathfinding_template_test.gd`, specifically to avoid cross-test
  global-state pollution when warming route templates.
- Machine: development machine (headless CI run via `GdUnitCmdTool.gd`), **not** yet the
  physical minimum-spec reference machine defined in `production/qa/reference-hardware.md`. The
  Validation Gate checklist there has been updated with these real numbers but flagged with a
  caveat that physical reference-hardware confirmation is still open.
- No pathfinding algorithm code was modified for this story (ADR-0004 stands unchanged). This is
  a test-methodology fix and measurement story only.
- Thresholds from ADR-0004 (Pathfinding Performance Budget) and `design/gdd/pathfinding.md`'s
  own frame-budget accounting (16.67ms total − 5ms AC-17 − 1ms AC-4 = 10.67ms residual).
- `tests/performance/sprint-03-profiler.md` is left unmodified for historical record; its AC-4
  section's INVALID verdict is now superseded by the real PASS verdict recorded above. Readers
  should treat this document (sprint-04) as the current source of truth for AC-4.
