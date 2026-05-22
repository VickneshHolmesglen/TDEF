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
| Monster AC-28 | Monster System | Total `_physics_process()` CPU time (150 active monsters) | ≤ 2 ms / frame | Steady-state budget. Does NOT include `path_invalidated` refresh frame (see note). |

**Path-invalidation frame note:** When `path_invalidated` fires, up to 150 monsters simultaneously call `get_path()` to refresh their local path copies. This event fires only during SCOUT and INTERMISSION (never WAVE_ACTIVE) — the same frame is not subject to the 2ms Monster System steady-state budget. A separate integration performance test should measure the path-invalidation refresh frame peak.

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

- [ ] AC-4 measured: `get_path()` × 100, 16×12 grid, p99 = _____ ms
- [ ] AC-17 measured: `would_block_all_paths()`, 24×18 grid, p99 = _____ ms
- [ ] OQ-3 measured: dirty rebuild, 16×12 grid, p99 = _____ ms
- [ ] Fallback A* measured: one standalone AStar2D build + A* run, 24×18 grid = _____ ms

If any provisional target is exceeded, update the target here and adjust the AC accordingly before implementation gates that AC.

---

## Hardware Procurement / CI Runner

For CI-automated performance tests, the CI runner must match or exceed this minimum spec. GitHub Actions hosted runners (2-core, 7 GB) are BELOW minimum spec for CPU-dependent tests — use a self-hosted runner matching the above, or run performance ACs as manual sprint-gated tests rather than per-commit CI.

**Current CI status:** Performance ACs run as **advisory manual tests** until a conforming CI runner is provisioned. Blocking gate ACs (AC-5, AC-6, AC-9a, AC-9b, etc.) run on the standard CI pipeline.
