# Mission Outcome Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a Victory/Defeat outcome screen (stats + Retry / Return to Sanctuary) at mission end, owned by the mission scene, replacing the effectively-unusable interim HUD Retry button.

**Architecture:** A pure `MissionOutcomeStats` counter, a `MissionOutcomeScreen` CanvasLayer that listens to EventBus terminal events and owns the exit buttons, and a `SceneManager.set_terminal_auto_exit(bool)` opt-out so a scene hosting the screen takes over the leave-the-mission decision. The Mission HUD suppresses its interim Retry when the screen is present.

**Tech Stack:** Godot 4.6.2 GDScript (typed), gdUnit4, `GEventBus`, standard Controls, `tr()` keys in `assets/localization/strings.csv`.

**Spec:** `docs/superpowers/specs/2026-09-27-mission-outcome-screen-design.md` (binding authority).

## Global Constraints

- Presentation/flow only: no change to wave, damage, economy or `MissionSelect.retry_current_mission()` behavior.
- Typed GDScript, doc comments on public members, constants at the top of scripts, match surrounding style. All player-visible text via `tr()` keys added to `assets/localization/strings.csv` (`keys,en` header; keys prefixed `OUTCOME_`); after editing the CSV run the editor-mode reimport before headless tests, and write CSV rows with the Edit tool (append at the end of the file, quote values containing commas).
- ADR-0001 Rule 6: every `GEventBus` connection made in `_ready` is disconnected in `_exit_tree` with an `is_connected` guard.
- Seams for tests: `MissionOutcomeScreen` has injectable `_defeat_delay: float`, `_victory_delay: float`, `_retry_action: Callable`, `_sanctuary_action: Callable` (defaults: 1.5 / 0.5 / `GMissionSelect.retry_current_mission` / `GSceneManager.transition_to_sanctuary`).
- Real `GSceneManager` autoload is live in tests: any test that emits the real `hero_died` or MISSION_COMPLETE must either call handlers directly or set `GSceneManager._death_hold_seconds = 0.0` and `GSceneManager.set_terminal_auto_exit(false)` (restore both in `after_test`). Never leave a 1.5 s hold armed.
- Godot gotchas learned this project: headless tests cannot verify shaders (none are added here); `Array[StringName].sort()` is not lexical; `.tscn` files must not contain `#` comment lines inside node blocks; new `class_name`s and `strings.csv` edits need `Godot.exe --headless --editor --path G:/TDef --quit` before tests.
- Test runner: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:/TDef --script tests/gdunit4_runner.gd -- -a <res:// path> --ignoreHeadlessMode` (forward slashes under Git Bash). Run only the suites named per task; never the full suite; no live Godot MCP verification in tasks (the controller does that).
- Commit and push to `main` after each task's tests pass, staging only files you changed (many unrelated `addons/`/`.import` files are modified and `.superpowers/` is untracked: never stage them); track new `.gd.uid`/`.tscn` files; verify `git show --name-only --format= HEAD`. Commit messages end with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.
- Reports: exact command + raw summary line for every suite run.

## File Structure

| File | Responsibility |
|---|---|
| `src/presentation/mission_outcome/mission_outcome_stats.gd` (new) | counters + `format_time` |
| `src/presentation/mission_outcome/mission_outcome_screen.gd` + `MissionOutcomeScreen.tscn` (new) | the screen |
| `assets/localization/strings.csv` | `OUTCOME_*` keys |
| `src/core/scene_manager.gd` | `set_terminal_auto_exit` |
| `src/presentation/mission_hud/mission_hud.gd` | suppress interim Retry when the screen exists |
| `src/scenes/mission_scene.gd`, `src/gameplay/missions/the_gap/the_gap.gd` | mount the screen + opt out of SceneManager auto-exit |

---

### Task 1: `MissionOutcomeStats`

**Files:**
- Create: `src/presentation/mission_outcome/mission_outcome_stats.gd`
- Test: `tests/unit/mission_outcome/mission_outcome_stats_test.gd`

**Interfaces (Produces):**

```gdscript
class_name MissionOutcomeStats
extends RefCounted

var waves_cleared: int = 0
var total_waves: int = 0
var monsters_slain: int = 0
var breaches: int = 0
var elapsed_seconds: float = 0.0

func reset() -> void
func on_wave_started(_wave_number: int, total: int, _difficulty: float) -> void   # sets total_waves
func on_wave_completed(wave_number: int, _enemies_remaining: int, _boss_breached: bool) -> void  # waves_cleared = max(waves_cleared, wave_number)
func on_monster_died(_payload: MonsterDiedEvent) -> void   # monsters_slain += 1
func on_monster_breached(_entity_id: int, _monster_id: StringName, _tier: int) -> void  # breaches += 1
func tick(delta: float) -> void  # elapsed_seconds += delta (ignores negative)
static func format_time(seconds: float) -> String   # "M:SS", floor seconds, never negative: 0 -> "0:00", 65.9 -> "1:05", 3600 -> "60:00"
```

- [ ] **Step 1:** Write `mission_outcome_stats_test.gd` covering: defaults zero; `reset()` zeroes everything; `on_wave_completed(3,…)` then `(2,…)` keeps 3 (max semantics); `on_wave_started` sets total; `monsters_slain` increments per `on_monster_died(MonsterDiedEvent.new())`; breaches increment; `tick` accumulates and ignores negative deltas; `format_time` cases above plus `-5.0 -> "0:00"`.
- [ ] **Step 2:** Run the editor-mode reimport, then the suite: expect FAIL (class missing).
- [ ] **Step 3:** Implement the class with doc comments. Verify `MonsterDiedEvent` is the real payload class name (grep `signal monster_died` in `src/foundation/event_bus/event_bus.gd`).
- [ ] **Step 4:** Run the suite: PASS.
- [ ] **Step 5:** Commit + push (`.gd` + `.gd.uid` + test + test `.uid`), message `Add MissionOutcomeStats counters`.

---

### Task 2: `MissionOutcomeScreen` + strings

**Files:**
- Create: `src/presentation/mission_outcome/mission_outcome_screen.gd`, `src/presentation/mission_outcome/MissionOutcomeScreen.tscn`
- Modify: `assets/localization/strings.csv`
- Test: `tests/unit/mission_outcome/mission_outcome_screen_test.gd`

**Interfaces:**
- Consumes: `MissionOutcomeStats` (Task 1), `ReduceMotion.enabled()`.
- Produces:

```gdscript
class_name MissionOutcomeScreen
extends CanvasLayer

enum Mode { NONE, DEFEAT, VICTORY }
const OUTCOME_LAYER: int = 20
const DEFEAT_SHOW_DELAY_SECONDS: float = 1.5
const VICTORY_SHOW_DELAY_SECONDS: float = 0.5
const GROUP_NAME: StringName = &"mission_outcome_screen"

var _defeat_delay: float = DEFEAT_SHOW_DELAY_SECONDS
var _victory_delay: float = VICTORY_SHOW_DELAY_SECONDS
var _retry_action: Callable
var _sanctuary_action: Callable

func get_mode() -> Mode           # currently shown mode (NONE while hidden)
func is_showing() -> bool
func is_show_pending() -> bool
func get_stats() -> MissionOutcomeStats
static func title_key(mode: Mode) -> String            # DEFEAT -> "OUTCOME_TITLE_DEFEAT", VICTORY -> "OUTCOME_TITLE_VICTORY", NONE -> ""
static func buttons_for(mode: Mode) -> Array[StringName]   # DEFEAT -> [&"retry", &"sanctuary"], VICTORY -> [&"sanctuary"], NONE -> []
func _on_terminal_event(mode: Mode) -> void            # public-for-test entry: first terminal event of an attempt wins; starts the show timer (or shows immediately when the delay is <= 0)
func _on_phase_changed(_previous: String, new_phase: String, _timestamp: float) -> void
func _on_hero_died() -> void
func _on_mission_launched(_id: String, _modifiers: PackedStringArray, _tier: int) -> void   # reset stats, hide, cancel pending
func _on_retry_pressed() -> void
func _on_sanctuary_pressed() -> void
```

Behavior (from the spec §3/§7):
- `_ready`: join `GROUP_NAME`, `layer = OUTCOME_LAYER`, `process_mode = PROCESS_MODE_ALWAYS`, build the UI in code or the `.tscn` (full-rect dimming `ColorRect` with `mouse_filter = STOP`, a centered `PanelContainer` with a title `Label`, a `GridContainer` of stat rows — Waves cleared "N / M", Monsters slain, Breaches, Time — and an `HBoxContainer` with a Retry button and a Return-to-Sanctuary button), hidden by default; connect `wave_started`, `wave_completed`, `monster_died`, `monster_breached` to the stats, and `mission_phase_changed`, `hero_died`, `mission_launched` to the screen; `_process` ticks `stats.tick(delta)` while no terminal event has occurred and a mission is live (a `_live` flag set by `mission_launched` and by the first `wave_started`).
- `_on_phase_changed`: `"DEFEAT"` -> `_on_terminal_event(DEFEAT)`; `"MISSION_COMPLETE"` -> `_on_terminal_event(VICTORY)`; any other new phase -> hide and cancel a pending show (a Retry moves the phase out of DEFEAT).
- `_on_hero_died` -> `_on_terminal_event(DEFEAT)`.
- First terminal event wins per attempt (`_terminal_seen`, cleared by `mission_launched`/non-terminal phase); a second one is ignored.
- Show: the delay uses a `SceneTreeTimer` (`get_tree().create_timer(delay)`) whose `timeout` callback is stored and disconnected on cancel (a `SceneTreeTimer` cannot be stopped); `is_show_pending()` reflects it. On show: fill the labels via `tr()`, set the button set, grab focus on Retry (DEFEAT) or Return (VICTORY), `visible = true`; fade in over 0.25 s unless `ReduceMotion.enabled()` (then instant).
- `ui_cancel` while showing == Return to Sanctuary.
- `_on_retry_pressed`: hide, clear terminal flag, call `_retry_action`. `_on_sanctuary_pressed`: call `_sanctuary_action`. Defaults for the actions are set in `_ready` only when unset (`GMissionSelect.retry_current_mission`, `GSceneManager.transition_to_sanctuary`).
- `_exit_tree`: cancel any pending show, disconnect every EventBus connection (guarded).

Strings (append to `assets/localization/strings.csv`, en column): `OUTCOME_TITLE_DEFEAT,Defeat`; `OUTCOME_TITLE_VICTORY,Mission Complete`; `OUTCOME_STAT_WAVES,Waves cleared`; `OUTCOME_STAT_SLAIN,Monsters slain`; `OUTCOME_STAT_BREACHES,Breaches`; `OUTCOME_STAT_TIME,Time`; `OUTCOME_BUTTON_RETRY,Retry`; `OUTCOME_BUTTON_SANCTUARY,Return to Sanctuary`.

- [ ] **Step 1:** Write `mission_outcome_screen_test.gd` (instantiate the scene via `load(...).instantiate()`, `add_child`, set `_defeat_delay = 0.0`, `_victory_delay = 0.0`, and recording lambdas for `_retry_action` / `_sanctuary_action`): static helpers (`title_key`, `buttons_for` for all three modes); DEFEAT via `_on_phase_changed("WAVE_ACTIVE","DEFEAT",0.0)` shows with mode DEFEAT and the Retry button focused; `_on_hero_died()` shows DEFEAT and a following DEFEAT phase change does not restart or change it (first wins); MISSION_COMPLETE shows VICTORY with only the sanctuary button visible and focused; non-zero delay case (`_defeat_delay = 0.2`): `is_show_pending()` true and `is_showing()` false until the timer elapses (drive with `await get_tree().create_timer(0.35).timeout`); `_on_mission_launched(...)` during the pending delay cancels it (never shows after waiting) and resets stats; a non-terminal phase change hides a showing screen; Retry pressed hides and invokes the retry recorder once; Return pressed invokes the sanctuary recorder; stats feed through real signals (`GEventBus.wave_started.emit(1,5,1.0)`, `wave_completed`, `monster_died` with `MonsterDiedEvent.new()`, `monster_breached`) and the labels show "1 / 5", counts (assert on the stat label texts after showing); the screen is in group `mission_outcome_screen`; Rule 6: after `remove_child`, `GEventBus.mission_phase_changed.is_connected(screen._on_phase_changed)` is false (and likewise `hero_died`, `mission_launched`). Do NOT emit the real `hero_died` or MISSION_COMPLETE phase changes on the global bus in these tests without `GSceneManager.set_terminal_auto_exit(false)` — that method arrives in Task 3, so in this task call the handlers (`_on_hero_died()`, `_on_phase_changed(...)`) directly and only emit the non-terminal bus signals globally.
- [ ] **Step 2:** Append the strings, run the editor-mode reimport, run the suite: FAIL.
- [ ] **Step 3:** Implement the screen and scene.
- [ ] **Step 4:** Run the suite: PASS; also run `tests/unit/mission_outcome/mission_outcome_stats_test.gd`.
- [ ] **Step 5:** Commit + push (all new files with their `.uid`s + `strings.csv`; the compiled `.translation` files are gitignored), message `Add MissionOutcomeScreen (victory/defeat) with run statistics`.

---

### Task 3: `SceneManager.set_terminal_auto_exit`, HUD suppression, scene wiring

**Files:**
- Modify: `src/core/scene_manager.gd`, `src/presentation/mission_hud/mission_hud.gd`, `src/scenes/mission_scene.gd`, `src/gameplay/missions/the_gap/the_gap.gd`
- Test: `tests/unit/scene_manager/scene_manager_terminal_exit_test.gd` (new), extend `tests/unit/mission_hud` (find the existing HUD retry tests: `grep -rln "_retry_button\|Retry" tests`), `tests/integration/mission_outcome/mission_outcome_wiring_test.gd` (new)

**Interfaces:**
- Consumes: `MissionOutcomeScreen` (Task 2).
- Produces: `SceneManager.set_terminal_auto_exit(enabled: bool) -> void`, `SceneManager.is_terminal_auto_exit_enabled() -> bool` (default `true`).

Behavior:
- `SceneManager`: `var _terminal_auto_exit: bool = true`. In `_on_hero_died`: `if not _terminal_auto_exit: return` (first line). In `_on_mission_phase_changed`: keep the "cancel death hold on non-DEFEAT/non-MISSION_COMPLETE phase" logic unchanged; the `MISSION_COMPLETE -> transition_to_sanctuary()` branch only runs when `_terminal_auto_exit`. Doc comments and an ADR-0002 reference.
- `MissionHud._enter_terminal("DEFEAT")`: show the interim `_retry_button` only when `get_tree().get_first_node_in_group(MissionOutcomeScreen.GROUP_NAME) == null`.
- Mission scenes: after the `HeroFeedback` block in each of `mission_scene.gd` and `the_gap.gd`, instantiate `MissionOutcomeScreen.tscn`, name it `MissionOutcomeScreen`, `add_child` it (mission_scene: under `_gameplay_root`? NO — under `self`, so it is not affected by the gameplay root's hidden/process-off state; the_gap: under `self`), then `GSceneManager.set_terminal_auto_exit(false)`. In each scene's `_exit_tree`, `GSceneManager.set_terminal_auto_exit(true)` (add or extend `_exit_tree`; guard `GSceneManager` validity).

- [ ] **Step 1:** Write tests. SceneManager suite (real autoload with stub scene paths exactly like `tests/unit/scene_manager/scene_manager_death_hold_test.gd`; read it first): default enabled true; with `set_terminal_auto_exit(false)`, `hero_died` neither transitions nor arms a hold, and `MISSION_COMPLETE` neither transitions; with `true` restored both behave as before; `after_test` restores `true` and `_death_hold_seconds`. HUD test: with a `MissionOutcomeScreen` instance in the tree the DEFEAT terminal leaves `_retry_button.visible == false`; without it the button shows (existing behavior). Wiring integration test (model on `tests/integration/hero/hero_feedback_wiring_test.gd`): both scenes boot with a child `MissionOutcomeScreen`, `GSceneManager.is_terminal_auto_exit_enabled()` is false while a mission scene is mounted and true again after it is freed; simulate DEFEAT by calling the screen's `_on_phase_changed("WAVE_ACTIVE","DEFEAT",0.0)` with `_defeat_delay = 0.0` and assert it shows and the current scene did not change; guard every real-bus terminal emission per Global Constraints.
- [ ] **Step 2:** Run: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run: the new suites, `scene_manager_test.gd`, `scene_manager_death_hold_test.gd`, the existing HUD suites you find (all suites that mention the interim Retry), `hero_feedback_wiring_test.gd`, `mission_scene_the_gap_test.gd`, and the suites that boot `MissionScene.tscn` (`grep -rln "MissionScene.tscn" tests`). All PASS.
- [ ] **Step 5:** Commit + push, message `Let mission scenes own the mission-end exit: outcome screen wiring, SceneManager opt-out, HUD Retry suppression`.

---

### Task 4: Documentation and session state

**Files:** `design/gdd/mission-hud.md` (Rules 25/DEFEAT and MISSION_COMPLETE rows: the outcome screen now exists as `MissionOutcomeScreen`; interim Retry button is suppressed when present), `design/gdd/mission-select.md` (Retry entry point: outcome screen), `docs/architecture/adr-0002-*.md` (dated amendment: `set_terminal_auto_exit` opt-out, why, default unchanged), `docs/superpowers/specs/2026-09-27-mission-outcome-screen-design.md` (status -> implemented; record any deviations), `production/session-state/active.md` (new top extract "part 29" with what shipped, tests, and a live checklist: defeat panel after the death sequence, stats plausible, Retry restarts and hides the panel, Return goes to the Sanctuary, victory panel, HUD interim Retry absent, gamepad focus, pause behavior; state honestly that nothing was live-verified by the tasks).

- [ ] **Step 1:** Read each doc and edit in its own style with the Edit tool; grep changed files for the double-encoding sequence (A-circumflex).
- [ ] **Step 2:** Commit + push, message `Document the mission outcome screen`.

---

## Self-review

Spec coverage: §3 stats (T1) and screen (T2), §4 SceneManager opt-out (T3), §5 HUD (T3), §6 wiring (T3), §7 edge cases (T2 tests: cancel on relaunch, first-wins, pause via process mode; T3 wiring/opt-out), §8 tests (per task), §9 docs (T4). Types: `MissionOutcomeScreen.Mode`, `GROUP_NAME`, `set_terminal_auto_exit`/`is_terminal_auto_exit_enabled`, seams `_defeat_delay/_victory_delay/_retry_action/_sanctuary_action` are defined once (T2/T3) and reused consistently. Known risk called out to the implementer: no test may emit the real terminal events on the global bus without the opt-out, because the real SceneManager would arm a hold or leave the mission.
