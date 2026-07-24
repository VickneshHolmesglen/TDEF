# S4-18 — Fix TD-monster-003 + TD-tower-002 Orphan Node Leaks

**Story ID**: S4-18
**Epic**: Core
**Layer**: Core
**Type**: Logic (test-infrastructure fix)
**Owner**: engine-programmer
**Sprint**: 4
**Estimate**: 0.15 days
**Status**: Complete
**Manifest Version**: 2026-05-16

## Context

**GDD**: None — this is a tech-debt closure task, not a new GDD requirement.

**ADR Governing Implementation**: None directly — `src/core/monster/monster_manager.gd` is
covered generally by ADR-0006 (Monster movement), but this story does not change monster
movement or combat logic, only Godot node lifecycle/parenting.

**Origin**: Closes two Advisory tech-debt items from `docs/tech-debt-register.md`:
- `TD-monster-003` — spawned `MonsterEntity` nodes were never `add_child()`'d, making every
  spawn a genuine Godot orphan node
- `TD-tower-002` — `tower_placement_test.gd`/`tower_combat_test.gd` set `_ts = null` in
  `after_test()` instead of freeing the `Node`-derived `TowerSystem` instance

**Engine**: Godot 4.6.2 | **Risk**: LOW — no new APIs; corrects existing node
lifecycle/parenting usage. `Node.reparent()` (used in a downstream fix) is a stable
Godot 4.0+ API.

## Acceptance Criteria

- [x] `MonsterManager._spawn_entity()` calls `add_child(entity)` so every spawned entity is a
      real scene-tree node from creation, not an orphan
- [x] `tests/unit/tower/tower_placement_test.gd` and `tower_combat_test.gd` free `TowerSystem`
      properly in `after_test()` instead of just nulling the reference
- [x] 0 orphan warnings in `tests/unit/tower/` (was 15+)
- [x] 0 orphan warnings in the monster test suites this story touches (was 18+ per subset run)
- [x] No regressions — full project test suite still passes

## Real Findings During Implementation (not anticipated by the tech-debt entries)

1. **Integration hazard**: `src/gameplay/missions/the_gap/the_gap.gd::_on_monster_spawned()`
   (written during S4-09, after TD-monster-003 was logged) already had its own scene-local
   `_monsters_container.add_child(entity)` workaround for the same gap. Adding `add_child()` in
   `MonsterManager` first would make this line error (a node can't be `add_child()`'d twice).
   Fixed by changing it to `entity.reparent(_monsters_container)`, which works regardless of
   the entity's current parent. User confirmed proceeding with fixing the real source
   (`MonsterManager`) rather than leaving the workaround as the permanent solution.
2. **`add_child()` on `MonsterManager` alone was insufficient in 3 unit test files**
   (`monster_spawn_test.gd`, `monster_movement_test.gd`, `monster_boss_test.gd`): these tests
   create `MonsterManager` via `.new()` but never add IT to the scene tree. An entity parented
   to a not-in-tree `MonsterManager` is still unreachable from the live SceneTree and continued
   to show as an orphan. Fixed by adding `add_child(_mm)` in each file's `before_test()` —
   ordered *before* overriding the `_grid`/`_pathfinding` DI stub seams, since `add_child()`
   triggers `_ready()`, which unconditionally overwrites those fields with the real
   `GGrid`/`GPathfindingSystem` autoloads — and `remove_child(_mm)` before `_mm.free()` in
   `after_test()`, matching the pattern already used in this codebase's integration test files.
3. **Confirmed empirically (not assumed): `Node.free()` does not recursively free children.**
   It only detaches them from their parent, leaving them as newly-orphaned, still-leaked
   objects. This was verified by temporarily removing the existing manual per-entity
   `.free()` loops in test `after_test()` blocks and observing orphan counts stay unchanged —
   proving those loops were already necessary and correct, not redundant. They were kept as-is
   in all affected files.

## Files Changed

- `src/core/monster/monster_manager.gd` — added `add_child(entity)` in `_spawn_entity()`
- `src/gameplay/missions/the_gap/the_gap.gd` — `_on_monster_spawned()` changed from
  `add_child()` to `reparent()`; class doc comment (deviation #4) updated
- `tests/unit/monster/monster_spawn_test.gd` — `before_test()`/`after_test()` add/remove `_mm`
  from the tree
- `tests/unit/monster/monster_movement_test.gd` — same
- `tests/unit/monster/monster_boss_test.gd` — same
- `tests/unit/tower/tower_placement_test.gd` — `after_test()` now calls `_ts.free()`
- `tests/unit/tower/tower_combat_test.gd` — same

## Out of Scope

- The remaining ~10 project-wide orphans after this fix — pre-existing, already tracked under
  `TD-test-001` (assert_error pattern) and `TD-test-002` (SceneManager resource warning), not
  part of this story
- `TD-hero-005` (`hero_lifecycle_test.gd` failure, missing `SanctuaryScene.tscn`) — pre-existing,
  unrelated, confirmed still present and unaffected by this story's changes

## Test Evidence

**Story Type**: Logic
**Required evidence**: 0 orphans in `tests/unit/tower/` and the touched monster test suites;
full regression shows no new failures
**Status**: [x] Verified

**Results**:
- `tests/unit/tower/` — 60/60 passing, 0 errors, 0 failures, **0 orphans**
- `tests/unit/monster` + `tests/integration/{wave_manager,core,mission_scene,monster}` —
  125/125 passing, 0 errors, 0 failures, **0 orphans**
- Full project regression — 557/557 executed, 0 errors, **1 pre-existing unrelated failure**
  (`TD-hero-005`), 0 new failures, project-wide orphan count down from ~77 baseline to 10
  (all remaining orphans pre-existing and tracked separately)

## Dependencies

- Depends on: None
- Unlocks: Cleaner test output for all future monster/tower work; no functional unlocks

---

## Completion Notes
**Completed**: 2026-07-06
**Criteria**: 5/5 passing.
**Deviations**: None uncaught — the scene-local reparenting conflict and the 3 unit-test files
missing `add_child(_mm)` were real gaps not anticipated by the original tech-debt entries, both
found and fixed within this session (not deferred).
**Test Evidence**: See above — all touched suites at 0 orphans, full regression clean.
**Code Review**: Skipped per lean review mode (small, mechanical, thoroughly empirically
verified fix — each hypothesis was tested against real headless runs before being accepted,
including one hypothesis that was proven wrong and reverted).
