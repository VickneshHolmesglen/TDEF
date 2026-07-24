# Reference Hardware — Performance Test Machine Specification

> **Status**: Defined (2026-05-20)
> **Owner**: Technical Director
> **Blocks**: AC-4 (Pathfinding get_path() budget), AC-17 (would_block_all_paths() budget), OQ-3 (dirty rebuild budget), Monster System AC-28 (physics_process budget)

---

## Minimum-Spec Test Machine

All performance acceptance criteria run against this machine definition. A test that passes on this machine is considered passing for performance gate purposes.

| Component | Minimum Spec | Rationale |
|-----------|-------------|-----------|
| **CPU** | Intel Core i5-7500 (4c/4t, 3.4 GHz base) **or** AMD Ryzen 5 1600 (6c/12t, 3.2 GHz base) | 2017–2018 mid-range CPU. Represents the target floor for PC Steam/Epic launch. Single-core performance matters for GDScript (not multi-threaded). |
| **RAM** | 8 GB DDR4 | Project memory ceiling is 1 GB — 8 GB total machine RAM ensures OS + editor overhead does not constrain the game's budget. |
| **GPU** | NVIDIA GTX 1060 6GB **or** AMD RX 480 8GB (Vulkan 1.0 support required for Godot 4.6.2) | Pathfinding is CPU-only but rendering runs concurrently. A dedicated GPU prevents integrated-graphics contention during performance measurement. |
| **Storage** | SSD (SATA) | Load-time tests require consistent I/O. NVMe preferred but not required. |
| **OS** | Windows 10 64-bit (build 19041+) | Primary distribution target. D3D12 is Godot 4.6's default renderer on Windows — GPU must support D3D12 or Vulkan. |
| **Display** | 1920×1080, 60 Hz | Target resolution and refresh rate for frame budget calculations. |

---

## Performance Targets

These targets are **provisional** — validate empirically during Sprint 2 prototype pass before treating as pass/fail gates.

| AC | System | Metric | Provisional Target | Notes |
|----|--------|--------|--------------------|-------|
| AC-4 | Pathfinding | 100 `get_path()` calls in one physics frame (16×12 grid, avg path 25 cells) | ≤ 1 ms total | Working hypothesis. Cross-reference Monster System AC-28 (2ms total physics budget) — `get_path()` sub-budget must fit within that envelope. |
| AC-17 | Pathfinding | `would_block_all_paths()` call on max grid (24×18 = 432 cells) | ≤ 5 ms p99 | Player-triggered (placement confirmation only). A hitch on the placement frame is acceptable if ≤ one screen refresh interval at 60 Hz (~16.67 ms). Target is conservative to leave headroom. |
| OQ-3 | Pathfinding | One dirty template rebuild (16×12 grid, AStar2D C++ backed) | < 1 ms | Estimated from AStar2D C++ implementation. Validate on reference machine; at MVP (N=1 SPAWN) only 1 rebuild fires per tower event. |
| Monster AC-28 | Monster System | Total `_physics_process()` CPU time (150 active monsters) | ≤ 2 ms / frame | Steady-state budget. See the corrected note below — the scenario this row originally excluded does not exist in shipped code. |

**Path-invalidation frame note (corrected 2026-07-07, closes `TD-path-002`):** The original framing — "when `path_invalidated` fires, up to 150 monsters simultaneously call `get_path()` to refresh their local path copies" — describes a mechanism that does not exist in shipped code. `monster_manager.gd::_on_path_invalidated()` is an explicit no-op at MVP (kept for a post-MVP feature). `path_invalidated` only fires during SCOUT/INTERMISSION (Rule 20, `design/gdd/pathfinding.md`), when no monsters are active at all — there is no 150-monster refresh burst to measure, now or ever at MVP scope. The real equivalent scenario is a **150-monster wave-start spawn burst**: each monster calls `find_path()` once at spawn (`monster_manager.gd:286`), staggered by `WaveSpawnEntry.pre_delay` (2.0–5.0s apart in shipped wave data, not simultaneous). S4-10 measured this directly: 150-spawn burst = **0.164ms**, PASS vs. both the 2ms Monster AC-28 budget (~12× headroom) and the 10.67ms pathfinding residual frame budget (~65× headroom). Full numbers: `tests/performance/sprint-04-profiler.md`. See also `design/gdd/pathfinding.md` OQ-6's own superseded-text note, corrected in the same S4-10 session.

---

## Measurement Protocol

1. **Build mode:** Godot export template (Release build) — NOT in-editor. GDScript performance differs significantly between debug and release.
2. **Profiling tool:** Godot's built-in profiler (`Debugger → Profiler`) or external frame capture (e.g., Windows Performance Recorder for CPU-level analysis).
3. **Warmup:** Run 10 physics frames before sampling to avoid cold-cache effects.
4. **Sample count:** Measure 100 consecutive frames; report p50, p95, p99 values.
5. **Isolation:** Disable rendering during CPU-only tests (use headless export with `-d` flag for pathfinding-specific tests).
6. **Concurrent load:** Pathfinding tests run with all other Autoloads active (EventBus, SavePersistence, Grid) — not isolated Autoload-only tests. This measures real-world overhead.

---

## Validation Gate

Performance ACs (AC-4, AC-17) are unblocked once these measurements are recorded for at least 3 runs on the reference machine:

- [x] AC-4 measured: `find_path()` × 100 (warm template, 16×12 grid, avg path 25), p99 = 0.1200 ms (p99.9 = 0.1370 ms) — **measured 2026-07-06 headless CI run (S4-10), not yet on physical reference hardware; see caveat below**
- [ ] AC-17 measured: `would_block_all_paths()`, 24×18 grid, p99 = _____ ms
- [ ] OQ-3 measured: dirty rebuild, 16×12 grid, p99 = _____ ms
- [ ] Fallback A* measured: one standalone AStar2D build + A* run, 24×18 grid = _____ ms

**S4-10 caveat**: the AC-4 number above comes from `tests/performance/sprint-04-profiler.md`,
run headless via `GdUnitCmdTool.gd` on the development machine, not the physical
minimum-spec reference machine this document defines. It replaces the earlier INVALID
cold-fallback measurement (34.043ms, `tests/performance/sprint-03-profiler.md`) with a real
warm-template measurement per TD-path-001's closure. Treat as directionally correct (250×
under budget) but re-verify on the actual reference-spec machine before a final performance
sign-off — this checklist item is checked as "real number recorded", not as "3 runs on
physical reference hardware confirmed" (that stronger bar remains open).

If any provisional target is exceeded, update the target here and adjust the AC accordingly before implementation gates that AC.

### S4-10 stretch/extension measurements (not part of the original Validation Gate list, recorded for completeness)

- AC-2 (max-grid stretch case, 24×18 grid, avg path 60, not a hard gate): p50=0.1030ms, p95=0.1060ms, p99=0.1260ms, p99.9=0.1640ms — well under the same provisional 1ms target, real number recorded regardless of pass/fail per story scope.
- AC-3 (spawn-burst, corrected from OQ-6's stale `path_invalidated`-refresh framing — see TD-path-002): 150 `find_path()` calls in one frame (warm 16×12 grid) = 0.1640ms total. PASS vs both the Monster System AC-28 2ms `_physics_process()` budget and the pathfinding.md 10.67ms residual frame budget. See `tests/performance/sprint-04-profiler.md` for the finding that real wave data stages spawns via 2.0–5.0s `pre_delay`, so a true same-frame 150-monster burst is not observed in shipped content — this is a synthetic worst-case upper bound.

---

## Hardware Procurement / CI Runner

For CI-automated performance tests, the CI runner must match or exceed this minimum spec. GitHub Actions hosted runners (2-core, 7 GB) are BELOW minimum spec for CPU-dependent tests — use a self-hosted runner matching the above, or run performance ACs as manual sprint-gated tests rather than per-commit CI.

**Current CI status:** Performance ACs run as **advisory manual tests** until a conforming CI runner is provisioned. Blocking gate ACs (AC-5, AC-6, AC-9a, AC-9b, etc.) run on the standard CI pipeline.
