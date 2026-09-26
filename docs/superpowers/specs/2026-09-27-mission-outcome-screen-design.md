# Mission Outcome Screen (Victory / Defeat) — Design

- **Date:** 2026-09-27
- **Status:** Implemented 2026-09-27 (commits cecd334, ac89c52, 23250ab, 832f922, 3092890); live verification pending. Decisions taken autonomously with the recommended option at each choice (the user was away and asked for "always the recommended option"). Flag anything you would change.
- **Follows:** `2026-09-26-windup-presentation-design.md` §1 (Retry/Outcome screen deferred as a separate later feature)
- **Why now:** the wind-up presentation's 1.5 s death hold makes `SceneManager` leave the mission for the Sanctuary roughly 1.5 s after the Hero dies, so the Mission HUD's interim DEFEAT Retry button (mission-hud.md Rule 25) is effectively unusable, and MISSION_COMPLETE leaves instantly with no acknowledgement. `mission-hud.md` already says an "outcome screen takes over" in both terminal states; that screen was never built.

## 1. Goal and non-goals

**Goal.** When a mission ends, the player sees a short outcome screen, reads how it went, and chooses what happens next: **Defeat** offers *Retry* and *Return to Sanctuary*; **Victory** offers *Return to Sanctuary*.

**Non-goals.**
- No rewards/loot summary, no XP breakdown, no persistence: the screen shows only run statistics gathered from EventBus events.
- No "abandon mid-mission" action (Pause Menu owns quitting).
- No change to attack/wave/economy simulation, `WaveManager`, or `MissionSelect.retry_current_mission()` behavior.
- No new art: a dimming backdrop + panel built from standard Controls with the project default theme.

## 2. Decisions

| Topic | Decision (recommended option) |
|---|---|
| Scope | One reusable `MissionOutcomeScreen` for both DEFEAT and MISSION_COMPLETE |
| Who owns leaving the mission | The screen. Mission scenes that host it tell `SceneManager` to stop auto-exiting on terminal events (§4); scenes without it keep today's behavior |
| When it appears | DEFEAT: after the Hero death sequence, `DEFEAT_SHOW_DELAY_SECONDS = 1.5`. MISSION_COMPLETE: `VICTORY_SHOW_DELAY_SECONDS = 0.5` |
| Statistics | Waves cleared (of total), monsters slain, breaches, elapsed mission time |
| Duplicate Retry | The Mission HUD's interim Retry button is suppressed when an outcome screen is present (§5) |
| Strings | All copy through `tr()` keys added to `assets/localization/strings.csv` |

## 3. Components

**`MissionOutcomeStats`** (`src/presentation/mission_outcome/mission_outcome_stats.gd`, `RefCounted`, no scene dependency): pure counters plus event handlers.
- Fields: `waves_cleared: int`, `total_waves: int`, `monsters_slain: int`, `breaches: int`, `elapsed_seconds: float`.
- `reset()`; `on_wave_started(wave_number, total_waves, _difficulty)` sets `total_waves`; `on_wave_completed(wave_number, _remaining, _boss_breached)` sets `waves_cleared = max(waves_cleared, wave_number)`; `on_monster_died(payload)` increments `monsters_slain`; `on_monster_breached(_id, _monster_id, _tier)` increments `breaches`; `tick(delta)` adds to `elapsed_seconds` (the screen ticks it while a mission is live).
- `format_time(seconds) -> String` static: `M:SS`.

**`MissionOutcomeScreen`** (`src/presentation/mission_outcome/MissionOutcomeScreen.tscn` + `mission_outcome_screen.gd`, `CanvasLayer` at `OUTCOME_LAYER = 20`, above the HUD):
- Owns a `MissionOutcomeStats`, connects `wave_started`, `wave_completed`, `monster_died`, `monster_breached`, `mission_launched` (reset), `mission_phase_changed`, `hero_died`; disconnects all in `_exit_tree` (ADR-0001 Rule 6).
- Joins group `mission_outcome_screen` in `_ready`.
- `mission_phase_changed(_, "DEFEAT", _)` or `hero_died` → after `DEFEAT_SHOW_DELAY_SECONDS` show DEFEAT mode; `"MISSION_COMPLETE"` → after `VICTORY_SHOW_DELAY_SECONDS` show VICTORY mode. Only the first terminal event of an attempt counts (a `hero_died` followed by the DEFEAT phase change shows once).
- Any non-terminal phase change or `mission_launched` (Retry) hides it and cancels a pending show-timer.
- Layout: full-rect dimming `ColorRect` (mouse-blocking), centered `PanelContainer` with title, a stats grid (label/value rows), and a button row. Default focus: *Retry* in DEFEAT, *Return to Sanctuary* in VICTORY. Gamepad and keyboard reachable (`focus_neighbor`s set, ui_accept/ui_cancel: `ui_cancel` = Return to Sanctuary).
- Buttons: *Retry* → hide, then `GMissionSelect.retry_current_mission()`; *Return to Sanctuary* → `GSceneManager.transition_to_sanctuary()`.
- Reduced motion: the panel appears with a single fade (no scale/slide); the fade honors `ReduceMotion.enabled()` by appearing instantly.
- Static helpers for testability: `static func title_key(mode) -> String`, `static func buttons_for(mode) -> Array[StringName]`.

## 4. SceneManager change

Add an opt-out: `SceneManager.set_terminal_auto_exit(enabled: bool)` (default `true`). While `false`, `_on_hero_died` and the `MISSION_COMPLETE` branch of `_on_mission_phase_changed` do nothing. The death-hold machinery is unchanged and still governs scenes that do not host an outcome screen. `_do_transition` keeps cancelling any pending hold. Mission scenes call `set_terminal_auto_exit(false)` when they mount an outcome screen and `set_terminal_auto_exit(true)` in `_exit_tree` (so the Sanctuary and menus are unaffected). ADR-0002 gets a dated amendment.

## 5. Mission HUD interaction

`MissionHud._enter_terminal("DEFEAT")` currently shows its interim Retry button. Change: if a node exists in group `mission_outcome_screen`, do not show the interim button (the group check is done at terminal time). Story 012's tests that exercise the interim button remain valid because they run without an outcome screen in the tree.

## 6. Wiring

`mission_scene.gd` and `the_gap.gd` instantiate `MissionOutcomeScreen`, add it to the scene, and toggle `set_terminal_auto_exit` (mount in `_ready`, restore in `_exit_tree`). One block per scene, placed next to the `HeroFeedback` block.

## 7. Edge cases

1. **Retry during the show delay** (HUD interim button is hidden, but Pause menu retry or a test can still relaunch): `mission_launched` cancels the pending show.
2. **Death then MISSION_COMPLETE** in the same frame: the first terminal event wins; the second is ignored for the attempt.
3. **Screen present but SceneManager left enabled** (a scene forgets to opt out): both would act; the screen's Sanctuary action calls `transition_to_sanctuary()`, and `_do_transition` is idempotent, so the worst case is the old auto-exit. Covered by a wiring test asserting the opt-out is set.
4. **Pause**: the screen uses `process_mode = PROCESS_MODE_ALWAYS` so buttons work if the tree is paused at a terminal state.
5. **Focus loss/mouse**: the backdrop consumes clicks so the HUD/world under it is not clickable.

## 8. Testing

Unit: `MissionOutcomeStats` counters/`max` semantics/`format_time`/reset; screen show/hide state machine driven by direct handler calls and a zero show-delay injection (`_defeat_delay`/`_victory_delay` fields); buttons per mode; first-terminal-wins; Retry hides and calls the retry seam (injectable `Callable`, default `GMissionSelect.retry_current_mission`); Return calls the sanctuary seam (default `GSceneManager.transition_to_sanctuary`); Rule 6 disconnects; `SceneManager.set_terminal_auto_exit(false)` makes `hero_died` and MISSION_COMPLETE no-ops and `true` restores; HUD suppresses the interim Retry when the group node exists. Integration: both mission scenes contain the screen and set the opt-out; a simulated DEFEAT shows the screen and does NOT leave the mission.
Live (only when asked): kill the Hero → death sequence → after ~1.5 s the Defeat panel shows with stats, Retry restarts the mission, Return goes to the Sanctuary; finish a mission → Victory panel.

## 9. Files

| File | Change |
|---|---|
| `src/presentation/mission_outcome/mission_outcome_stats.gd` (new) | counters |
| `src/presentation/mission_outcome/mission_outcome_screen.gd` + `MissionOutcomeScreen.tscn` (new) | the screen |
| `assets/localization/strings.csv` | new `OUTCOME_*` keys |
| `src/core/scene_manager.gd` | `set_terminal_auto_exit` |
| `src/presentation/mission_hud/mission_hud.gd` | suppress interim Retry when the screen is present |
| `src/scenes/mission_scene.gd`, `src/gameplay/missions/the_gap/the_gap.gd` | mount + opt out |
| docs: `mission-hud.md`, `mission-select.md` note, ADR-0002 amendment, `active.md` | update |

## Deviations (implementation, 2026-09-27)

- The screen is added under the scene root (next to the `HeroFeedback` block), not under `_gameplay_root`, because that root is hidden with processing off until launch.
- Task 2 review fix: elapsed time does not tick while the tree is paused.
- Implemented via a UID follow-up commit (3092890) for the new tests; no behavioral change.
- Nothing has been live-verified yet.
