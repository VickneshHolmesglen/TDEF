# Smoke Test: Critical Paths

**Purpose**: Run these checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check` (which reads this file)
**Update**: Add new entries when new core systems are implemented.

## Core Stability (always run)

1. Game launches to main menu without crash
2. New game / session can be started from the main menu
3. Main menu responds to all inputs (K/M and gamepad) without freezing

## EventBus (once EventBus.gd is implemented)

4. All 70 signals declared in `EventBus.gd` compile without type errors
5. A subscriber freed mid-wave produces a clear error (not a silent crash)

## Save & Persistence (once SavePersistence.gd is implemented)

6. Save game completes without error — `.tmp` renamed to `.dat` successfully
7. Load game restores correct state from `.dat` file
8. Stale `.tmp` file at startup is cleaned up by `SavePersistence._ready()`

## Pathfinding (once Pathfinding.gd is implemented)

9. `templates_ready` event fires before first `monster_spawn_requested`
10. `would_block_all_paths()` returns `true` when all routes are blocked
11. Route templates rebuild correctly after a tower is placed or removed

## Wave Manager (once WaveManager.gd is implemented)

12. Wave does not start before `templates_ready` is received
13. `monster_died_batch` fires when > 20 monsters die in one frame

## Performance

14. No visible frame rate drops below 60 FPS on target hardware
15. No memory growth over 5 minutes of play (once core loop is implemented)
