# QA Evidence: Monster Visual Companion (Epic 15 Story 004)

**Story**: `production/epics/epic-15-3d-visual-presentation/story-004-monster-visual-companion.md`
**ADR**: `docs/architecture/adr-0037-visual-presentation-3d-companion-layer.md` (also governed by ADR-0006, `per_monster_physics_process` forbidden pattern)
**Date**: 2026-08-20
**Status**: PARTIAL — AC-1, AC-2, AC-3, AC-6 have real automated coverage (below). AC-4 (performance
budget) and AC-5 (live visual tracking) are **DEFERRED** pending a human/profiled live session — see
"Deferred checks" below. No fabricated numbers or screenshot evidence in this document.

---

## Automated coverage (this session)

`tests/integration/visual_presentation/monster_visual_companion_test.gd` exercises the real
`MonsterManager`/`MonsterInstance` classes headless, driving the actual centralized
`_physics_process()` (not individual pass methods in isolation, except where the existing project
convention for isolating Pass 1/Pass 4 in `monster_movement_test.gd`-style tests already does so):

| AC | Test(s) | What it proves |
|---|---|---|
| AC-1 (companion + real mesh resolution) | `test_spawn_creates_visual_companion_with_a_real_node3d_mesh_child`, `test_spawn_seeds_companion_at_correct_position_before_any_sync_call` | Spawning a monster creates a `VisualCompanion3D` `Node3D` holding one real `Node3D` mesh, resolved through the live `GGameDataRegistry` boot path against the shipped `assets/data/visual_meshes/enemy_ufo_a.tres`, correctly positioned from the very first visible frame (no one-frame lag). |
| AC-2 (map_to_3d sync, centralized pass, no new callback) | `test_position_sync_tracks_map_to_3d_across_multiple_physics_process_frames`, `test_position_sync_at_grid_boundary_position_maps_correctly`, `test_monster_instance_and_monster_entity_scripts_declare_no_process_callback` | Companion position exactly matches `VisualMath.map_to_3d(entity.global_position, 0.0)` across 10 real `MonsterManager._physics_process()` frames of actual movement, driven entirely through the real wiring (not the sync method called in isolation). A direct source-text scan confirms zero `_process`/`_physics_process` declarations exist on either `monster_instance.gd` or `monster_entity.gd` — the single most important regression guard for this story, per ADR-0006's `per_monster_physics_process` forbidden pattern. |
| AC-3 (no invariant regression) | Verified by re-running the project's existing `MonsterManager` unit-test suite after this story's change (see "Existing suite regression check" below) — not re-implementable inside this new integration file, since GdUnit4 suites cannot invoke another suite's test functions directly. |
| AC-6 (companion lifecycle, no orphan) | `test_monster_death_frees_companion_with_no_orphan`, `test_batch_death_of_multiple_monsters_frees_all_companions_no_leak` | A killed monster's `VisualCompanion3D` is freed with no orphan (checked via `is_instance_id_valid()`, not just visual absence), including the Pass 4 batch-death path (ADR-0033) with 5 simultaneous deaths in one frame. |

All 8 tests are headless-executable and deterministic; two (`test_monster_death_frees_companion_with_no_orphan`,
`test_batch_death_of_multiple_monsters_frees_all_companions_no_leak`) use `await get_tree().process_frame`
(twice) to observe `queue_free()`'s deferred removal, matching this project's established async-test pattern.

### Existing suite regression check

Ran the project's pre-existing `MonsterManager` test suite(s) after this story's change (adding
`_pass3c_visual_sync()` between Pass 3/Movement and Pass 4/Death-and-Absorbed-Flush) — result:
**0 new failures**. The 4-pass structure's own ordering (Damage → BOSS Logic → Movement → Absorbed
Flush) is unchanged; `_pass3c_visual_sync()` is an additive sub-pass inserted after Movement, not a
reordering of the 4 documented passes, and does not touch `active_monsters`, damage state, or the
DEAD-priority invariant in any way.

---

## Deferred checks (require a human with a live/profiled session)

**AC-4 (performance budget, `MonsterManager._physics_process` ≤ 2ms/frame at 150 entities)**
- The story requires this be **measured, not assumed** (ADR-0006's own guardrail language).
- **DEFERRED** — no real profiler run was performed in this session; fabricating a number would
  violate this project's own "measured, not assumed" standard. The added cost per entity is one
  `Vector3` construction (`VisualMath.map_to_3d()`, confirmed zero-allocation in Story 001's
  code review) plus one function call (`sync_visual_companion_position()`) — expected to be a small
  addition on top of the existing ≤2ms budget, but "expected small" is not the same as "measured,"
  and this is flagged explicitly rather than assumed safe. Recommend a live Godot MCP profiling pass
  at 150 active entities before treating this budget as confirmed, same as Story 001 and Story 003's
  own similarly-deferred performance items.

**AC-5 (live visual tracking, gameplay observation)**
- Requires a human (or a live Godot MCP `run_project` + `take_screenshot` session) watching a
  spawned monster move and visually confirming the 3D companion tracks it with no lag/jitter.
- **DEFERRED** — not producible without a live rendered session. The automated
  `test_position_sync_tracks_map_to_3d_across_multiple_physics_process_frames` test above proves the
  underlying **math** is exact (companion position equals `map_to_3d()`'s output every single frame,
  not just eventually-consistent) — what remains unverified is purely the *visual* experience (does
  it read as smooth movement, does the placeholder UFO mesh's scale/orientation look reasonable for
  a ground-traveling monster), which is exactly the kind of thing this project's own established
  practice treats as screenshot-only, not derivable from position math alone.

---

## Deviations / judgment calls

- **Mesh choice**: `enemy_ufo_a.tres` (one of the "Tower Defense Models" pack's UFO enemy pieces) was
  used as the placeholder mesh for `&"enemy_ufo_a"`. This is explicitly a Phase 1 placeholder per the
  epic's own Overview ("source art... is a third-party placeholder pack... this epic's Definition of
  Done does not include replacing that placeholder art") — real fantasy-monster models are Phase 6
  (Content re-authoring), a separate future epic, not in scope here.
- **Sync pass placement**: `_pass3c_visual_sync()` was inserted as a new named sub-pass between Pass 3
  (Movement) and Pass 4 (Death & Absorbed Flush), rather than folded into Pass 3 itself — chosen so
  the visual sync reads a monster's position only after Movement has fully finalized it for the frame,
  and runs before Pass 4 so a monster dying this same frame still gets one last correct sync before
  its companion is freed. This preserves the existing 4-pass structure's documented boundaries exactly
  (no pass was modified, one was added after Movement).
