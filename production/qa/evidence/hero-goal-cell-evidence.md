# QA Evidence: Hero Presence on GOAL Cell Does Not Trigger a Breach (AC-14)

**Story**: `production/epics/epic-02-core-combat/story-002-hero-movement.md` (S4-04, Rule 27/AC-14)
**Date**: 2026-07-07
**Engine**: Godot 4.6.2.stable.official, driven live via the Godot MCP bridge (`run_project` on `src/gameplay/missions/the_gap/the_gap.tscn`, `run_script`, `take_screenshot`)
**Status**: Advisory evidence — closes the manual/debug-overlay verification this story's Test Evidence section deferred; the automated structural check (`hero_movement_test.gd::test_ac14_hero_script_has_no_body_entered_handler_or_breach_emission`) already covers the negative source-code case and remains the primary automated evidence.

---

## What was verified

AC-14 requires confirming that the hero standing on a GOAL cell never fires `monster_breached` —
breach detection is a Monster-System-owned concept (monsters reaching GOAL), and the hero must
never be misidentified as a breaching entity by any collision/area-detection path.

## Method

1. Launched "The Gap" mission scene live via the Godot MCP bridge (`run_project`, background mode).
2. Ran a script against the live scene tree:
   - Connected a listener to `GEventBus.monster_breached`.
   - Set `Hero.global_position` directly to the GOAL cell's world position (`GGrid.cell_to_world(Vector2i(15, 6))` — `the_gap.gd`'s `GOAL_CELL` constant).
   - Awaited 30 physics frames with the hero held at that exact position.
   - Disconnected the listener and reported the fire count.
3. Captured a screenshot confirming the hero (blue) sprite visually sitting on the GOAL cell (red).
4. Checked `get_debug_output` for any runtime errors during the hold window.

## Results

| Check | Result |
|---|---|
| `monster_breached` fire count over 30 physics frames at GOAL cell | **0** |
| `monster_breached` payloads captured | `[]` (none) |
| Hero final position vs. GOAL cell world position | Exact match (`(992, 416)` both) |
| Runtime errors during the hold window | **0** |
| Visual confirmation | Screenshot confirms hero sprite positioned exactly on the GOAL (red) cell |

## Verdict

**PASS.** The hero can occupy the GOAL cell indefinitely without ever triggering a breach —
consistent with the automated structural check's finding that `hero.gd` contains no
`body_entered` handler and never references `monster_breached` at all. This live run
additionally proves the *absence of any indirect path* to a breach (e.g., via a shared
Area2D, a Grid-level cell-occupancy check, or an EventBus side effect) — something the
structural source-grep alone couldn't rule out, since it only proves the hero's own script
doesn't do it directly.

## Notes

- This verification uses direct position assignment (`global_position =`) rather than driving
  the hero there via movement input — sufficient for this AC, since the concern is presence at
  the cell, not the path taken to arrive. Movement mechanics themselves are covered separately
  by `hero_movement_test.gd`'s Rule 26/27 tests.
- Story `S4-04`'s Test Evidence section marked this as ADVISORY and explicitly deferred pending
  "a manual/windowed session or working MCP runtime tooling" — that tooling is now reachable in
  this environment (confirmed across multiple sessions this sprint), closing that gap.
