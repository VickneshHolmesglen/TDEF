# Test Evidence: Epic 15 Story 006 — Projectile Visual Companion

> Story: `production/epics/epic-15-3d-visual-presentation/story-006-projectile-visual-companion.md`
> ADRs: ADR-0037 (Visual Presentation 3D Companion Layer), ADR-0019 (Projectile Pooling Strategy)
> Date: 2026-08-20

---

## ADR-0019 Gap Finding — READ THIS FIRST

**Story 006 and ADR-0019 describe and test against a pooled `ProjectileManager`/`Projectile` system that does not exist in this codebase and was never implemented.**

Verified during this story's implementation (2026-08-20):
- No `ProjectileManager` class exists anywhere in `src/` (`grep` for `class_name ProjectileManager`, `POOL_SIZE`, `_free_indices` returns zero matches).
- No pooled `Projectile` class exists.
- No test file for either exists in `tests/`.
- `TowerSystem._try_attack()` (`src/core/tower/tower_system.gd:288-314`) still emits `GEventBus.tower_attacked.emit.call_deferred(...)` immediately and unconditionally for every weapon type — no flight-time delay, no pool, no branching on `projectile_type`.
- `TR-tower-007` (the requirement ADR-0019 exists to close) remains open.
- ADR-0019's own Migration Plan says: *"Greenfield — no existing Projectile/ProjectileManager code to migrate."* That was true when the ADR was accepted and, per this verification, is **still** true.

The only real projectile-related code in this project is `ProjectileVisual` (`src/scenes/projectile_visual.gd`, `src/scenes/ProjectileVisual.tscn`) — a purely cosmetic `Node2D`, freshly `instantiate()`'d per shot by `mission_scene.gd`'s `_on_tower_attacked()` handler and `queue_free()`'d once its flight completes. This is a **create-per-shot/destroy-per-shot lifecycle** — the opposite of a reused pool.

### Decision (user-confirmed this session)

Building ADR-0019's real pooling system first was explicitly considered and **rejected** for this story's scope: it would be a substantive **gameplay timing change** (introducing a real flight delay before damage lands, where today damage is instant), not a visual-presentation change, and it directly conflicts with this epic's own non-negotiable "zero changes to gameplay simulation logic" boundary (ADR-0037's Constraints, upheld by every prior story in this epic). That decision is out of this story's authority.

**This story was redirected**: implement and test the `Node3D` visual companion against the REAL `ProjectileVisual` create-per-shot/destroy-per-shot lifecycle instead of the pool the story was originally written against. This is logged here, in the test file's own header doc comment (`tests/integration/visual_presentation/projectile_visual_companion_test.gd`), and in the implementation's own class-level doc comment (`src/scenes/projectile_visual.gd`, the "Epic 15 Story 006 (ADR-0037): 3D visual-companion subtree" block) — three places, deliberately, per the instruction not to bury this.

**This is logged as a separate, still-open item outside this epic's scope**, for the coordinator to track independently: closing `TR-tower-007` / implementing ADR-0019's real pooling system is undecided future work, not something this story silently closes or works around.

---

## Acceptance Criteria Coverage

| AC (story's numbering, reframed per the redirect above) | Status | Evidence |
|---|---|---|
| AC-1: `Node3D` visual-companion + `MeshInstance3D`, resolved via `VisualMeshMappingResource` | **Automated** | `test_configure_creates_visual_companion_with_a_real_node3d_mesh_child` — real, live `GGameDataRegistry.get_visual_mesh_mapping()` boot path against the shipped `assets/data/visual_meshes/projectile_bolt.tres` |
| AC-2: position sync via `map_to_3d()`, no new per-instance callback | **Automated** | `test_position_sync_tracks_map_to_3d_across_multiple_process_frames_ballistic`, `..._homing_moving_target`, `..._when_homing_target_dies_mid_flight`; `test_projectile_visual_script_declares_exactly_one_process_and_zero_physics_process`; `test_process_body_calls_the_visual_companion_sync` |
| AC-3/AC-4 (pool release/reuse toggling, as literally written) | **N/A — no pool exists** | See ADR-0019 Gap Finding above and the test file's header doc comment. Not tested; not fabricated. |
| AC-4's underlying concern, real-lifecycle equivalent ("no one-frame flash at a stale/default position") | **Automated (indirect, cross-referenced during code review)** | `test_configure_seeds_companion_at_start_position_before_any_process_call` — proves the companion is seeded at its correct real start position before any `_process()` call runs, so a freshly-instantiated `ProjectileVisual` never renders one frame at the `Node3D` default `(0,0,0)`. Originally filed only under AC-1/AC-2; added here per qa-tester's code-review finding so this real coverage isn't lost against AC-4's literal wording. |
| Rapid release-reuse cycling (story's mass-kill stress edge case) | **N/A — no reuse exists to cycle** | Same reason. |
| Multiple pool slots releasing/reusing in the same frame | **N/A — no shared pool slots exist** | Same reason. Partially analogous coverage exists for a *different* real scenario — see below. |
| Real analog: multiple independent `ProjectileVisual` instances active in the same frame | **Automated** | `test_multiple_independent_projectiles_in_the_same_frame_do_not_cross_contaminate` — explicitly NOT a substitute for the N/A'd pool-slot scenario; documented as such in the test file. |
| Companion freed with no orphan at end-of-flight (this codebase's real, non-pooled "release" — `queue_free()`) | **Automated** | `test_process_frees_companion_at_end_of_flight_with_no_orphan` — asserts both the `ProjectileVisual` and its companion's instance IDs are invalid after the deferred free resolves. gdUnit4's own orphan counter also reports 0 across every run (see Test Runs below). |
| AC-5 (existing `ProjectileManager` test suite / re-acquisition throttle unchanged) | **N/A — no such suite exists** | There was never a `ProjectileManager` test suite to regress. The closest real regression surface (`ProjectileVisual`'s own pre-existing 2D flight-path behavior, and every system that spawns it) was re-verified instead — see Test Runs below. |
| AC-6 (performance budget, "well under 0.1ms/frame") | **Deferred — not measured** | Same honest-deferral pattern as every prior story in this epic. No profiler run was performed. `_sync_visual_companion_position()` is O(1), zero-allocation (`Vector3` is a value type, no heap allocation in the hot path per `engine-code.md`), added to an already-running per-instance `_process()` — architecturally consistent with the other converted entity types' unmeasured-but-structurally-cheap sync additions, but this is an engineering judgment, not a measurement. Should not be represented as verified. |
| AC-7 (live visual tracking, no lag/desync across a real shot's flight) | **Deferred — not observed** | No live screenshot/gameplay-observation session was performed this pass. Requires a human comparing a rendered frame across an actual fired shot, per the story's own QA Test Cases ("Manual check: live gameplay observation"). Not fabricated. |

---

## Test Runs (real, headless, this session — 2026-08-20)

All runs against the pinned `Godot_v4.6.2-stable_win64.exe` binary via `tests/gdunit4_runner.gd`.

### New suite (this story)
```
res://tests/integration/visual_presentation/projectile_visual_companion_test.gd
9 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED (1s 991ms)
```

### Regression check — visual_presentation + tower suites
```
res://tests/integration/visual_presentation
res://tests/unit/tower
res://tests/integration/tower
109 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED (26s 432ms)
```
Includes every prior story's own visual-companion suite (`tower_camera_companion_test.gd`, `monster_visual_companion_test.gd`, `hero_visual_companion_test.gd`, `grid_terrain_visual_companion_test.gd`, `visual_mesh_mapping_resource_test.gd`) plus the full `tower_placement_test.gd`/Tower System unit and integration coverage — all pass unmodified with this story's change applied.

### Regression check — mission scene suites (the real spawn site for `ProjectileVisual`)
```
res://tests/integration/mission-scene
res://tests/integration/mission_scene
25 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED (17s 646ms)
```

**Observed but not attributed to this story**: each run above prints a shutdown-time `WARNING: ObjectDB instances leaked at exit` / `ERROR: N resources still in use at exit` from the Godot process itself, after gdUnit4 has already reported `0 orphans` for every suite. This is a process-teardown-time artifact (scales with how many scenes/resources were loaded across the whole run, not correlated with any specific failing test), not a per-test regression — gdUnit4's own orphan accounting (which is what the story's tests actually assert against) is clean in every run. Flagging it here rather than silently ignoring it, but not treating it as a story-006 defect: it was not isolated to this story's suite (the tower-only run, which barely touches `ProjectileVisual`, shows the same class of message), and no test failure or assertion failure is attributed to it.

---

## Files Changed/Added

- `src/scenes/projectile_visual.gd` — modified: `_build_visual_companion()` (called from `configure()`), `_sync_visual_companion_position()` (called from the existing `_process()`), `PROJECTILE_MESH_ENTITY_ID`/`PROJECTILE_LAYER_HEIGHT` consts, `_visual_companion` var.
- `assets/data/visual_meshes/projectile_bolt.tres` — new `VisualMeshMappingResource`, `&"projectile_bolt"` → `weapon-ammo-bullet.glb` (Kenney-style Phase 1 placeholder art).
- `tests/integration/visual_presentation/projectile_visual_companion_test.gd` — new integration suite (9 test cases, all passing).
- `production/qa/evidence/projectile-visual-companion-evidence.md` — this file.

No changes to `TowerSystem`, `MonsterManager`, `mission_scene.gd`'s fire path, or any gameplay simulation/timing code.
