# Sprint 3 Pathfinding Profiler Results

**Sprint**: 3
**Story**: S3-05 Combat Loop Integration
**Date**: 2026-07-03
**Run by**: /team-qa sprint follow-up (condition closure from Sprint 3 sign-off)
**Test source**: `tests/integration/core/combat_loop_test.gd`

Copy the `[PROFILER]` lines printed by GUT into the tables below.

> **AC-ID reconciliation (2026-07-03)**: This doc previously labeled its three sections
> "AC-8", "AC-9", "AC-10" — a fabricated local numbering that did not match any actual
> requirement ID. The obligation this doc closes is `production/sprints/sprint-03.md`'s
> S2-04 profiler carryover, which cites the real GDD requirement IDs from
> `design/gdd/pathfinding.md`: **AC-4**, **AC-17**, **AC-24a**. Sections below are now
> labeled with the correct IDs and cross-referenced to the test functions that measure them.

---

## AC-4: find_path() — 100-Sample Average (p99.9 proxy)

*GDD source: `design/gdd/pathfinding.md:396`. Test: `test_pathfinding_profiler_find_path_100_samples`.*

| Metric | Measured | Target (ADR-0004) | QA Verdict |
|--------|----------|-------------------|------------|
| Avg latency | 34.043 ms | ≤1 ms p99.9 | **INVALID — methodology gap, not a code-performance FAIL** |

Raw output:
```
[PROFILER] find_path() 100-sample avg: 34.043 ms  (target ≤1ms p99.9 per ADR-0004)
```

**QA note**: AC-4's target assumes `find_path()` resolves via the O(1) pre-built route-template
lookup on a "populated" grid (per its GDD text). This test's `before_test()` only wires a
`_StubPathfinding` for the combat-loop tests under test — it never configures the *real*
`GPathfindingSystem` autoload that the profiler tests call directly, so no route templates exist
when this measurement runs. Every one of the 100 calls falls through to a cold full-A* fallback
build instead of a template lookup — the measured 34.043ms reflects that fallback cost repeated
100×, not the warm-path scenario AC-4 specifies. This is corroborated by AC-24a below measuring
a near-identical single-call cost (30.645ms) via the same unconfigured path.
**This is not evidence the implementation violates its 1ms budget** — it is evidence the test
needs to build route templates (e.g. simulate `mission_launched` → wait for `templates_ready`)
before looping 100 `find_path()` calls. **Recommended follow-up**: add template-build setup to
`test_pathfinding_profiler_find_path_100_samples` and re-run before this AC can be given a real
PASS/WARNING/FAIL verdict.

---

## AC-17: would_block_all_paths() — 24×18 Grid Footprint

*GDD source: `design/gdd/pathfinding.md:437`. Test: `test_pathfinding_profiler_would_block_all_paths`.*

| Metric | Measured | Target (ADR-0004) | QA Verdict |
|--------|----------|-------------------|------------|
| p99 latency | 0.054 ms | ≤5 ms p99 | **PASS** |

Raw output:
```
[PROFILER] would_block_all_paths() 24×18 grid: 0.054 ms  (target ≤5ms p99 per ADR-0004)
```

**QA note**: This measurement does not depend on route templates being pre-built, so the
methodology gap affecting AC-4 does not apply here. 0.054ms is roughly 90× under budget — clean
PASS.

---

## AC-24a: Fallback A* Baseline — Single Cold find_path() Call

*GDD source: `design/gdd/pathfinding.md:455`. Test: `test_pathfinding_profiler_astar_baseline`.
Measurement-only AC — no pass/fail criterion per its own definition.*

| Metric | Measured |
|--------|----------|
| Single call | 30.645 ms |

Raw output:
```
[PROFILER] A* baseline single find_path(): 30.645 ms
```

**QA note**: Unlike AC-4, this measurement is exactly what AC-24a asks for — a single fallback
A* build+run on an unconfigured/off-template system. This value is valid as recorded and feeds
AC-24b's configuration-gate formula (`pathfinding_max_fallbacks_per_frame = max(1, floor(5.67 /
baseline_ms))`). At `baseline_ms = 30.645`, the formula's floor branch applies
(`baseline_ms ≥ 5.67`), so `pathfinding_max_fallbacks_per_frame` must be exactly **1** — matches
the current default per `design/gdd/pathfinding.md:374`. No action needed; AC-24b is satisfied.

---

## Notes

- Profiler tests run in the GUT headless context. If pathfinding templates are not
  pre-built, values reflect cold (uninitialized) call latency — still valid for
  worst-case measurement (as demonstrated by AC-24a above), but **invalid for AC-4**,
  which specifically requires a warm, populated-grid scenario.
- Verdicts (PASS / WARNING / FAIL / INVALID) are a QA sign-off judgment, not automated
  assertions. The story closes on measurement, not on threshold pass — but an INVALID
  verdict means the measurement itself doesn't test the right scenario and should not be
  used to judge the implementation either way.
- Thresholds from ADR-0004 (Pathfinding Performance Budget).
- **Open follow-up**: `test_pathfinding_profiler_find_path_100_samples` needs route-template
  setup added before AC-4 can be validly measured. Track as a small test-fix item in a future
  sprint (not blocking Sprint 3 sign-off — AC-24a's baseline and AC-17 are both valid and
  passing; only AC-4's specific 100-sample warm-path scenario is unmeasured).
