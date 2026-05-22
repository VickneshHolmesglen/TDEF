---
name: Pathfinding AC Review Findings
description: Fifth adversarial AC review of pathfinding.md (2026-05-20): 6 blockers; AC-2/AC-16/AC-20 new targets; AC-4/AC-17 still unresolved (hardware doc absent); AC-11 push_warning infrastructure gap
metadata:
  type: project
---

Fifth adversarial AC review of `design/gdd/pathfinding.md` completed 2026-05-20.
Prior fourth-review blockers (13 claimed resolved per user): AC-1 no accessor, AC-3 contradiction, AC-4 hardware doc absent, AC-9 split, AC-12 internal timing, AC-14 integration tag, AC-15 wrong GDD, AC-16 malformed WHEN + private field.

## Status changes from fourth review
- AC-1: PASS — THEN now uses `get_path()` observable output + `templates_ready.spawn_count`.
- AC-3: Partially improved — "immediately following (r,c)" is consistent with F3. "No cells skipped" still lacks cardinal adjacency definition (advisory).
- AC-9: Correctly split into AC-9a (batching, PASS) and AC-9b (WAVE_ACTIVE suppression, advisory — wrong system boundary).
- AC-12: PASS — two distinct GridConfigs, observable output.
- AC-14: PASS — [INTEGRATION] tag added, WaveManager stub in AC text, ordering assertion via EventBus spy.
- AC-15: PASS — tombstoned/moved to Tower GDD.
- AC-16 WHEN: PASS — now says "tower_destroyed emitted on EventBus." But THEN clause still uses undefined "this frame / next deferred frame" in headless context. Still blocking.

## Blockers (6 total — must resolve before any Pathfinding Logic story is Done)

- **AC-2**: First THEN clause ("template stores path = []") asserts internal state. Remove it — second clause (`get_path()` returns `[]`) is sufficient and observable.
- **AC-4**: `production/qa/reference-hardware.md` does not exist. Threshold marked "provisional." Create hardware doc with specific CPU/GPU spec and confirmed threshold, or downgrade AC-4 to ADVISORY.
- **AC-11**: `push_warning()` capture is not standard in GUT/gdUnit4. No capture mechanism specified. Project needs a test helper or must change the observable (e.g., dedicated signal or public flag). Blocking until infrastructure decision made.
- **AC-16**: "This frame or the next deferred frame" is undefined in headless GUT. Rewrite: after `await get_tree().process_frame`, EventBus spy records zero `path_invalidated` emissions. Also: GIVEN specifies BOSS damage — fixture should emit `tower_destroyed` directly on EventBus, not instantiate a BOSS.
- **AC-17**: Same class as AC-4 — provisional threshold, no hardware doc. Create `production/qa/reference-hardware.md` or downgrade to ADVISORY.
- **AC-20**: Second THEN clause ("second monster's velocity is set to Vector2.ZERO") is Monster System behavior. Pathfinding returns `FALLBACK_DEFERRED`; velocity is Monster's concern. Remove cross-system assertion. Author velocity-zeroing in Monster integration tests separately.

## Advisory (fix before implementation, not blocking sprint start)

- **AC-3**: "No cells skipped" needs definition: for each consecutive pair `(cells[i], cells[i+1])`, `abs(cells[i+1].x - cells[i].x) + abs(cells[i+1].y - cells[i].y) == 1`.
- **AC-5**: "This frame" undefined in headless. Rewrite: after manually triggering deferred cycle, EventBus spy call count == 0.
- **AC-9b**: Tests Grid/Tower suppression, not Pathfinding behavior. Move to Grid/Tower integration test or add [INTEGRATION] tag.
- **AC-10**: Fixture must use a map where geometric-nearest GOAL != cost-nearest GOAL. Without this fixture, AC does not distinguish distance from A* cost.
- **AC-19**: Confirm gdUnit4 version supports `push_error()` assertions. If same gap as `push_warning()`, inherits AC-11's blocker.
- **AC-21**: Clause (c) OR fallback (`primary_blocking_cell == blocked_cells[0]`) allows trivial pass without testing load-bearing behavior. Drop the OR; require `would_block_all_paths([primary_blocking_cell]) == true`.

## Confirmed clean ACs

- AC-1: PASS
- AC-7 (Post-MVP): PASS
- AC-9a: PASS
- AC-12: PASS
- AC-13: PASS
- AC-13b: PASS
- AC-14: PASS
- AC-18: PASS

## Resolved from prior reviews (carry-forward confirmation)

- AC-15: Tombstoned/moved to Tower GDD. No longer in Pathfinding set.
- AC-8 (from review #4): Confirmed redundant with AC-9a. Should be deleted.

## Author decisions required before any AC rewrite

1. **AC-4 / AC-17**: Create `production/qa/reference-hardware.md` with specific hardware spec and confirmed numeric thresholds, OR explicitly downgrade both to ADVISORY before Sprint 2.
2. **AC-11**: Decide on `push_warning()` capture mechanism: custom test helper, GUT plugin, or change the observable to a public signal/flag.
3. **AC-20**: Confirm velocity-zeroing AC authored separately in Monster integration tests before marking AC-20 revised.

**Why:** ACs were written across multiple sessions. The main remaining blocker categories are: (a) missing test infrastructure for warning capture, (b) undefined temporal references in headless GUT context, (c) cross-system boundary violations, (d) provisional performance thresholds without a reference document.

**How to apply:** Block any Pathfinding Logic story marked Done if AC-2, AC-4, AC-11, AC-16, AC-17, or AC-20 are unresolved. Advisory items must be addressed before implementation begins to avoid test-phase rework.
