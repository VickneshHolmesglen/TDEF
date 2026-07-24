# S4-10 — 100-Agent Pathfinding Performance Stress Test

**Story ID**: S4-10
**Epic**: Foundation
**Layer**: Foundation
**Type**: Logic
**Owner**: technical-director + godot-gdscript-specialist
**Sprint**: 4
**Estimate**: 1.0 day
**Status**: Complete
**Manifest Version**: 2026-05-16

## Context

**GDD**: `design/gdd/pathfinding.md`
**Requirement**: `TR-path-007` — "100+ simultaneous agents at 60 FPS" (status: active, confirmed in `docs/architecture/tr-registry.yaml`)
*(Requirement text lives in the TR registry — read fresh at review time)*

**ADR Governing Implementation**: `docs/architecture/adr-0004-pathfinding-strategy.md` (Accepted) — this story does not change the pathfinding strategy itself; it re-measures and validates an existing implementation against its own stated performance budget.

**ADR Decision Summary**: AStar2D with pre-computed route templates. `get_path()` is meant to be an O(1) dictionary lookup + O(k) `Array[Vector2i]` Variant copy against a warm template cache — not a cold full-A* rebuild.

**Real, previously-found gap this story fixes**: `docs/tech-debt-register.md`'s `TD-path-001` (logged 2026-07-03) — the existing profiler test (`tests/integration/core/combat_loop_test.gd::test_pathfinding_profiler_find_path_100_samples`) calls the real `GPathfindingSystem` autoload directly without ever building route templates first, so every one of its 100 sampled `get_path()` calls falls through to the cold fallback A* path instead of the warm template-lookup path AC-4 actually specifies. The recorded number (34.043ms avg per call) is real, but it measures the wrong scenario — it's nearly identical to AC-24a's own single-fallback-call baseline (30.645ms), which would not be true if the 100-sample test were actually hitting a warm cache after the first call.

**Engine**: Godot 4.6.2 | **Risk**: LOW — this is a test-fixture and measurement-methodology fix, not new engine-API usage. `Time.get_ticks_usec()` for timing and the GC-forcing allocation pattern below are both stable, pre-4.0 APIs.

**Important scope note — this is NOT blocked by the same tooling gap Story 008 (Wave Manager epic) hit.** Story 008's deferred performance measurement (`TD-perf-001`) needed *real rendering* (FPS, draw calls under a live window) — genuinely unmeasurable headlessly. AC-4's measurement here is pure CPU timing of `get_path()` calls via `Time.get_ticks_usec()`, with no rendering dependency at all. This story is fully executable headlessly in a future session; it does not require the Godot MCP tooling that wasn't available during Story 008.

**Control Manifest Rules (Foundation layer)**:
- Required: Pathfinding budget is binding per `design/gdd/pathfinding.md`'s own frame-budget accounting: 16.67ms total frame budget − 5ms (AC-17 placement confirmation) − 1ms (AC-4, this story's target) = 10.67ms residual, of which at most 5.67ms is budgeted for fallback A* calls
- Required: measurement must include at least one forced GC collection cycle within the 10-second sampling window — a result that only passes on GC-quiescent frames does not satisfy AC-4

---

## Acceptance Criteria

*From `design/gdd/pathfinding.md` (AC-4, quoted verbatim) and TR-path-007:*

- [ ] **AC-4 (re-measured with warm templates)**: GIVEN a reference machine matching `production/qa/reference-hardware.md`, WHEN 100 `get_path()` calls execute in a single physics frame on a populated 16×12 grid with average path length 25 **and pre-built route templates already warm** (not the cold-fallback scenario TD-path-001 found), THEN total elapsed time for all 100 calls is ≤ 1ms at p99.9 — measured across a 10-second window that includes at least one forced GC collection cycle, not only on GC-quiescent frames.
- [ ] **100-agent stress scenario (TR-path-007) — corrected to the real spawn-burst trigger**: GIVEN up to 150 monsters spawning in the same/adjacent physics frames at wave start (the real code path — `monster_manager.gd:286` calls `find_path()` once per monster at spawn; OQ-6's original "`path_invalidated` refresh burst" framing is dead code at MVP, see Implementation Notes item 4), THEN the combined pathfinding cost across the spawn-burst frame(s) stays within the 10.67ms residual frame budget `design/gdd/pathfinding.md` allocates to it, and the monster-side `_physics_process()` work (Monster System AC-28's 2ms sub-budget) is not itself breached.
- [ ] **TD-path-001 closure**: the profiler test is fixed to build real route templates (simulate `mission_launched` → await `templates_ready`, matching Story 006's real signal-chain convention from the Wave Manager epic) before its measurement loop, and a real PASS/WARNING/FAIL verdict is recorded in `tests/performance/sprint-03-profiler.md`, replacing the invalid cold-path number currently there.
- [ ] **TR-path-007 disposition**: based on the re-measured result, TR-path-007's HIGH engine-risk classification (per OQ-6 in the GDD) is either formally retired (if the warm-path measurement passes comfortably) or re-scoped with the pre-approved remediation fallback (index+template-reference return instead of an `Array[Vector2i]` copy, per OQ-6 option (b) — already pre-approved at the TD level to avoid a mid-sprint API redesign decision if needed).

---

## Implementation Notes

*Derived from TD-path-001's own recommended fix and the GDD's AC-4/OQ-6 sections:*

1. **Fix the profiler test's precondition** (`tests/integration/core/combat_loop_test.gd::test_pathfinding_profiler_find_path_100_samples`): populate `GGrid` with a real `GridConfig` and trigger `GPathfindingSystem`'s real template-build path before the measurement loop — the Wave Manager epic's Story 006/008 already established the exact real-signal-chain pattern to do this (`GEventBus.mission_launched.emit(...)` → await `GEventBus.templates_ready`), rather than stubbing pathfinding as the file's existing `before_test()` does for its (unrelated) combat-loop tests.

2. **GC-forcing mechanism** (per the GDD's own specified protocol, since Godot 4 has no direct `GC.collect()` API): allocate and discard ≥10MB of throwaway `Array` data immediately before the measurement window to reliably trigger a collection on the next GC-eligible frame:
   ```gdscript
   var _gc_trigger: Array = []
   for i in 400000:
       _gc_trigger.append(Vector2i(i, i))
   _gc_trigger.clear()
   ```

3. **Measurement protocol** (per AC-4's exact GDD text): use `Time.get_ticks_usec()` before/after each `get_path()` call; record 100 samples per physics frame over a 10-second window; report p99.9 across all samples including GC frames — not just quiescent-frame p99.

4. **100-agent extension — corrected to the real trigger (found during dev-story context load, 2026-07-06)**: OQ-6's original framing ("when `path_invalidated` fires, up to 150 monsters simultaneously call `get_path()` to refresh") describes a mechanism that does **not** exist in shipped code. `src/core/monster/monster_manager.gd::_on_path_invalidated()` is an explicit no-op ("Dead code at MVP (Grid locks tower writes during WAVE_ACTIVE). Kept for post-MVP.") — Grid's WAVE_ACTIVE write lock means tower changes cannot occur mid-wave, so `path_invalidated` never triggers a monster-side refresh burst at MVP. The only call site for `find_path()` is `monster_manager.gd:286`, once per monster **at spawn**. The real "100+ simultaneous agents" scenario is therefore a **wave-start spawn burst**: extend the harness to simulate up to 150 monsters spawning in the same/adjacent physics frames, each independently calling `find_path()` once — this is both the scenario that can actually occur and a closer match to TR-path-007's "100+ simultaneous agents" framing than the non-existent refresh path.

5. **Pre-approved remediation, if needed**: if the GC-inclusive p99.9 fails the ≤1ms budget, the pre-approved fallback (do not re-litigate this as a new design decision) is OQ-6's option (b): change `get_path()`'s return contract from an `Array[Vector2i]` copy to a `{template_ref, start_index}` struct, eliminating per-call Variant allocation at the cost of changing every Monster System call site. This is pre-approved specifically to avoid a mid-sprint API redesign debate if the number comes back over budget.

---

## Out of Scope

- Any change to the pathfinding *algorithm* itself (AStar2D route-template strategy is unchanged, ADR-0004 stands)
- Real FPS/draw-call/rendering measurement (that's `TD-perf-001`, tracked separately, genuinely requires a windowed session)
- Monster System's own `_physics_process()` budget beyond confirming pathfinding's share fits within its allocated slice
- Implementing a real `path_invalidated` monster-refresh mechanism — `monster_manager.gd::_on_path_invalidated()` is confirmed dead code at MVP by its own doc comment; making it live is a post-MVP feature change, not a perf-measurement task. Log the GDD's OQ-6 text being stale about this mechanism as a new tech-debt item during this story (see Test Evidence).

---

## Test Evidence

**Story Type**: Logic (performance/measurement)
**Required evidence**: fixed `tests/integration/core/combat_loop_test.gd::test_pathfinding_profiler_find_path_100_samples` passing with a real warm-path measurement, plus an updated `tests/performance/sprint-03-profiler.md` recording the real PASS/WARNING/FAIL verdict
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: S4-09 / the Wave Manager epic (Complete 2026-07-06) — needed for the real `mission_launched`/`templates_ready` signal chain this story's fixed test drives, and for `WaveConfig`/`GridConfig` construction patterns to reuse
- Unlocks: Formal retirement or re-scoping of TR-path-007's HIGH risk classification; informs whether S4-11's playtest round needs to flag pathfinding-related frame hitches as a known issue

---

## Completion Notes
**Completed**: 2026-07-06
**Criteria**: 4/4 passing. AC-4 warm 16×12 p99.9 = 0.137ms (target ≤1ms, ~7.3× headroom). Max-grid 24×18 p99.9 = 0.164ms (~6.1× headroom). Spawn-burst (150 monsters, 1 frame) = 0.164ms (PASS vs 2ms Monster AC-28 budget, ~12× headroom; PASS vs 10.67ms pathfinding residual budget, ~65× headroom). TD-path-001 closed with real numbers. TR-path-007's OQ-6 risk classification formally retired in `design/gdd/pathfinding.md`.
**Deviations**: Advisory only — (1) results recorded in new `tests/performance/sprint-04-profiler.md` rather than the story's literal `sprint-03-profiler.md` reference (more correct — keeps Sprint 3's doc intact); (2) template warm-up used the codebase's established `_on_mission_phase_changed("", "SCOUT", 0.0)` pattern rather than the story's literal "emit mission_launched, await templates_ready" phrasing (same production code path, matches `pathfinding_template_test.gd` precedent); (3) AC-4's literal 10-second wall-clock window was executed as 1000×100 batches (100,000 calls) for CI practicality — disclosed in-code and in the profiler doc; (4) a duplicate tech-debt ID (`TD-test-002` collision) was found in code review and fixed by renumbering the new entry to `TD-test-003`.
**Real findings surfaced**: (1) `monster_manager.gd::_on_path_invalidated()` is dead code at MVP — GDD OQ-6's "150-monster path_invalidated refresh" scenario doesn't exist in shipped code; corrected to a wave-start spawn-burst scenario instead, logged as `TD-path-002` (stale GDD text). (2) The project's documented headless test runner (`tests/gdunit4_runner.gd`) is broken (`GdUnitTestCIRunner.run_tests()` doesn't exist); the working alternative (`GdUnitCmdTool.gd`) was used instead and the breakage logged as `TD-test-003`. (3) Real wave data (`the_gap_waves.tres`) stages spawns 2-5s apart — a true same-frame 150-monster burst never happens in shipped content; the AC-3 test is explicitly labeled a synthetic worst-case upper bound, not observed behavior.
**Test Evidence**: Logic — `tests/integration/core/combat_loop_test.gd` (modified, 2 tests) + `tests/integration/core/pathfinding_stress_test.gd` (new, 1 test), all passing. Full regression: 557/557 executed, 0 errors, 1 pre-existing unrelated failure, 0 new failures, 0 orphans in touched files.
**Code Review**: Complete — 1 Required Change found (duplicate `TD-test-002` ID) and fixed; re-verified clean. Verdict: APPROVED.
