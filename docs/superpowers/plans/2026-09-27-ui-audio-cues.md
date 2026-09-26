# UI Audio Cues Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every button audible feedback (click / confirm / cancel) and add denial cues (disabled-button press, blocked tower placement, rejected pickup), through the existing data-driven cue map and dispatcher.

**Architecture:** A `UiAudioBinder` node owned by `AudioCueDispatcher` watches `SceneTree.node_added`, hooks every `BaseButton`, and dispatches cues through the dispatcher's single `dispatch_cue` entry point. A node meta `ui_audio` overrides the cue per button. Cue data (`.tres` + wavs) is authored with the existing `tools/audio` pipeline from Kenney Interface Sounds (CC0).

**Tech Stack:** Godot 4.6.2 GDScript (typed), gdUnit4, `GEventBus`, ffmpeg (`C:\ffmpeg-8.0.1-full_build\bin\ffmpeg`), bash pipeline in `tools/audio/`.

**Spec:** `docs/superpowers/specs/2026-09-27-ui-audio-cues-design.md` (binding authority).

## Global Constraints

- No new EventBus signals; UI code is not edited except one-line `set_meta` annotations (Task 3). No hover/focus sounds.
- Cues are on bus `UI`; families: `ui_click` and `ui_cancel` → `ui_confirm_cancel`, `ui_confirm` → `activation_confirm`, `ui_denied` → `denial_rejection` (all three families already exist in `VoiceLimiter.DEFAULT_FAMILY_CAPS`).
- Typed GDScript, doc comments, constants at top; ADR-0001 Rule 6 (disconnect every connection you make, guarded by `is_connected` / `is_instance_valid`).
- `.tres` files: create with the Write tool or `tools/audio/author_cue.sh` (which emits valid files); never `#` comments inside `.tres`/`.tscn` blocks.
- Audio assets: CC0 only; every shipped sound is recorded in `assets/audio/sfx/SOURCES.md` (event, pack, original filename, license, URL, edits) and raw source files go under `assets/source/audio/<event>/` (see existing entries and `tools/audio/lib.sh`, `process_sound.sh`, `author_cue.sh`). The Kenney Interface Sounds zip URL is `https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip` (download to the scratchpad/temp dir, not into the repo; only the chosen files are copied to `assets/source/audio/...`). Candidate files: `click_*`, `tick_*`, `select_*`, `confirmation_*`, `back_*`, `error_*`, `bong_*` — audition by reading durations/characters, pick short dry ones; do not pick by name alone.
- Tests: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:/TDef --script tests/gdunit4_runner.gd -- -a <res:// path> --ignoreHeadlessMode`; editor-mode reimport after new `class_name`/assets: `... --headless --editor --path G:/TDef --quit`. Run only targeted suites; never the full suite; no live MCP verification by tasks.
- The live `GAudioSystem` autoload owns the real dispatcher; unit tests build their own `AudioCueDispatcher`/`UiAudioBinder` instances with injected callables and fixture cue maps (see `tests/unit/audio/audio_cue_dispatcher_windup_test.gd`). Never leave the real dispatcher's state changed.
- Commit and push to `main` per task, staging only your files (+ `.uid`, + new assets/import files that the editor generates: `.wav.import` files are tracked in this repo — check with `git ls-files assets/audio/sfx | head` and follow what exists); verify with `git show --name-only --format= HEAD`; message ends with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`. Report exact commands and raw summary lines.

## File Structure

| File | Responsibility |
|---|---|
| `src/core/audio/ui_audio_binder.gd` (new) | hook buttons, dispatch UI cues |
| `src/core/audio/audio_cue_dispatcher.gd` | own the binder; wire denial events with a rate limit |
| `assets/audio/sfx/ui_*.wav`, `assets/data/audio/cues/ui_*.tres`, `assets/data/audio/audio_cue_map.tres`, `assets/audio/sfx/SOURCES.md`, `assets/source/audio/ui_*/` | cue content |
| a few UI scripts | `set_meta` annotations |

---

### Task 1: `UiAudioBinder` (logic, no content)

**Files:**
- Create: `src/core/audio/ui_audio_binder.gd`
- Test: `tests/unit/audio/ui_audio_binder_test.gd`

**Interfaces (Produces):**

```gdscript
class_name UiAudioBinder
extends Node

const META_KEY: StringName = &"ui_audio"
const KIND_CONFIRM: StringName = &"confirm"
const KIND_CANCEL: StringName = &"cancel"
const KIND_NONE: StringName = &"none"
const CUE_CLICK: StringName = &"ui_click"
const CUE_CONFIRM: StringName = &"ui_confirm"
const CUE_CANCEL: StringName = &"ui_cancel"
const CUE_DENIED: StringName = &"ui_denied"

static func cue_for(kind: Variant) -> StringName   # &"confirm"->CUE_CONFIRM, &"cancel"->CUE_CANCEL, &"none"->&"" (no cue), anything else (null/other) -> CUE_CLICK
func setup(dispatch: Callable, tree: SceneTree) -> void   # stores the callable (signature (cue: StringName)), connects tree.node_added, hooks every BaseButton already in tree.root
func hooked_count() -> int
func _hook(button: BaseButton) -> void        # idempotent (meta &"_ui_audio_hooked"); connects button.pressed and button.gui_input with bound handlers
func _on_pressed(button: BaseButton) -> void  # dispatches cue_for(button.get_meta(META_KEY, null)) unless empty
func _on_gui_input(event: InputEvent, button: BaseButton) -> void  # disabled button + left mouse press -> dispatch CUE_DENIED once per press
func _on_node_added(node: Node) -> void       # hooks if node is BaseButton
```

- `_exit_tree`: disconnect `tree.node_added` and every still-valid hooked button's two connections (guarded); tolerate freed buttons.
- Buttons added after `setup` are hooked via `node_added` — note `node_added` fires when the node enters the tree; the button's `disabled` state is read at press time, never cached.

- [ ] **Step 1:** Write `ui_audio_binder_test.gd` with a recording dispatch lambda (`var played: Array[StringName]`) and a real `SceneTree` (`get_tree()` of the test): `cue_for` for all kinds (including `null` and an unknown StringName); a `Button` added AFTER `setup` is hooked and `pressed.emit()` dispatches `ui_click`; a `Button` that existed BEFORE `setup` is hooked; meta `confirm` -> `ui_confirm`, `cancel` -> `ui_cancel`, `none` -> nothing; a disabled button receiving an `InputEventMouseButton` (left, pressed) through `_on_gui_input` dispatches `ui_denied` exactly once, an enabled one does not, a right-click on a disabled one does not, and a mouse *release* does not; hooking the same button twice leaves `hooked_count()` unchanged and one press plays one cue; after `remove_child`/free of the binder, pressing a still-live hooked button plays nothing and errors nothing; freeing a hooked button then adding others is safe; `CheckBox`/`TextureButton` are hooked. Free everything in `after_test` (`auto_free`).
- [ ] **Step 2:** Run the editor-mode reimport, then the suite: FAIL.
- [ ] **Step 3:** Implement the binder.
- [ ] **Step 4:** Run the suite: PASS.
- [ ] **Step 5:** Commit + push (`.gd` + `.gd.uid` + test + test `.uid`), message `Add UiAudioBinder: hook every button for UI click/confirm/cancel/denial cues`.

---

### Task 2: Wire the binder into the dispatcher; denial events; cue content

**Files:**
- Modify: `src/core/audio/audio_cue_dispatcher.gd`, `assets/data/audio/audio_cue_map.tres`, `assets/audio/sfx/SOURCES.md` (+ `LICENSE.txt` only if a new attribution is needed — Kenney is CC0, so normally not)
- Create: `assets/audio/sfx/ui_click_v1.wav` (+ `_v2`, `_v3`), `ui_confirm.wav`, `ui_cancel.wav`, `ui_denied.wav`, matching `assets/data/audio/cues/ui_click.tres`, `ui_confirm.tres`, `ui_cancel.tres`, `ui_denied.tres`, and raw sources under `assets/source/audio/ui_click/`, `ui_confirm/`, `ui_cancel/`, `ui_denied/`
- Test: `tests/unit/audio/ui_audio_dispatcher_test.gd`, extend the real-map content check (see `tests/unit/audio/audio-cue-content_test.gd`)

**Interfaces:**
- Consumes: Task 1 `UiAudioBinder`.
- Produces: `AudioCueDispatcher.DENIED_EVENT_MIN_GAP_MSEC: int = 300`, `var _last_denied_event_msec`, `func _dispatch_denied_event() -> void` (rate-limited dispatch of `ui_denied`); the binder is a child named `UiAudioBinder` created in `_ready` via `setup(dispatch_cue, get_tree())`; cues `ui_click` (2-3 variants, `AudioStreamRandomizer`), `ui_confirm`, `ui_cancel`, `ui_denied` in the real map.

Behavior:
- In `_ready` (after `_build_player_pool`) create the binder. Tests that build an `AudioCueDispatcher` per test still get a binder: give the dispatcher a test seam `var _create_ui_binder: bool = true` (tests set false when they do not want scene-tree hooking) — or verify the existing dispatcher tests do not break with it on; prefer leaving it on and confirming they pass.
- `_connect_all_events`: `_wire(GEventBus.tower_placement_blocked, func(_cells: Array, _cell: Vector2i) -> void: _dispatch_denied_event())` and `_wire(GEventBus.item_pickup_rejected, func(_a: String, _b: String, _c: int, _d: String) -> void: _dispatch_denied_event())` (verify signatures in `src/foundation/event_bus/event_bus.gd`).
- Paused-tree check (spec §4.5): read `_play_stream`/the pool creation and confirm UI cues play while `get_tree().paused`; if the pool players or the dispatcher stop processing while paused, set the players' (and the binder's) `process_mode = Node.PROCESS_MODE_ALWAYS` and add a test asserting the process mode. Report what you found.
- Content: download the Kenney zip to a temp dir, audition candidates (durations via ffprobe/ffmpeg, character by name and listening-independent properties: short, dry), pick: 2-3 clicks (~<0.1 s), a brighter confirm (<0.25 s), a softer cancel/back (<0.2 s), a low short denial (<0.25 s); process through `tools/audio/process_sound.sh` (normalize/trim/convert to wav as the other cues) and author with `tools/audio/author_cue.sh`: `ui_click ui_confirm_cancel UI false -8 <v1 v2 v3>`, `ui_confirm activation_confirm UI false -6 <file>`, `ui_cancel ui_confirm_cancel UI false -8 <file>`, `ui_denied denial_rejection UI false -6 <file>` (read the script and `lib.sh` first; the argument order is `<event> <family> <bus> <spatial> <db> <file.wav>...`). Record every sound in `SOURCES.md`.

- [ ] **Step 1:** Write `ui_audio_dispatcher_test.gd` (model on `audio_cue_dispatcher_windup_test.gd`): the dispatcher creates a child `UiAudioBinder` in `_ready`; `tower_placement_blocked.emit([], Vector2i(1,1))` and `item_pickup_rejected.emit("x","y",1,"full")` each dispatch `ui_denied` (fixture map containing `ui_denied`); two blocked events within 300 ms dispatch once (backdate `_last_denied_event_msec` to test the gap, no sleeps); the real `audio_cue_map.tres` contains the four cue names with bus `UI` and the right families, and every stream loads (non-null). Extend or add a test that `VoiceLimiter.DEFAULT_FAMILY_CAPS` contains the three families.
- [ ] **Step 2:** Run: FAIL.
- [ ] **Step 3:** Implement code + author content.
- [ ] **Step 4:** Reimport, run the new suite, `tests/unit/audio` (all), `tests/integration/audio` (if it exists): PASS.
- [ ] **Step 5:** Commit + push (code, tests, cue `.tres`, wavs and their `.import` files if tracked, raw sources, `SOURCES.md`), message `Wire UI audio cues: binder in the dispatcher, denial events, Kenney click/confirm/cancel/denied content`.

---

### Task 3: Per-button overrides and documentation

**Files:**
- Modify: the UI scripts that own the buttons listed below (one-line `set_meta` each), `design/gdd/audio-system.md`, `production/qa/audio-cue-listening-pass.md`, `production/session-state/active.md`, the spec (status)
- Test: `tests/integration/audio/ui_audio_annotations_test.gd`

Annotate (find each by grep; if a listed button does not exist, skip it and say so):
- `MissionOutcomeScreen`: Retry = `KIND_CONFIRM`; Return to Sanctuary = default click.
- Mission HUD Ready / ready-up and the Mission Select Launch button = `KIND_CONFIRM`; any Back / Close / Cancel / "Return" buttons in the Mission Select screen, Pause Menu sub-panels, Tarot Deck UI and Sanctuary UI screens = `KIND_CANCEL` (grep `"Back"`, `"Cancel"`, `"Close"`, `BACK`, `CANCEL` text/keys in `src/`).
- Buttons whose action already plays its own event cue (craft, repair, build/upgrade structure, equip forge craft, tower placement confirmation) = `KIND_NONE` so the two sounds do not stack: find the buttons that emit `component_crafted`, `component_repaired`, `sanctuary_structure_built`, `structure_upgraded`, `hero_equipment_crafted` (grep for their emit sites and trace back to the button handler).

Use `UiAudioBinder.META_KEY` / `KIND_*` constants (never raw strings) and set the meta where the button is created or in `_ready` right after its node reference is resolved.

Docs: `audio-system.md` (Core Rule 3/4 note: UI cues arrive through the `UiAudioBinder` auto-hook, list the four cue names, meta override, no hover sounds, denial sources), `audio-cue-listening-pass.md` (add the four cues to the listening list, marked placeholders), `active.md` (new top extract, `part 30`: what shipped with SHAs, tests, rulings, honest NOT-live-verified statement, live checklist: click sounds in Sanctuary/HUD/Mission Select/Pause Menu, confirm on primary actions, cancel on back, denial on a disabled button/blocked placement/rejected pickup, no double-sound on craft/build, sounds while paused, volume balance vs music), spec status -> Implemented.

- [ ] **Step 1:** Write `ui_audio_annotations_test.gd`: instantiate the outcome screen scene and assert Retry has meta `confirm` and Return has none/click; for each other annotated screen you can instantiate cheaply (grep how existing integration tests mount them), assert the annotated buttons carry the expected meta; assert `UiAudioBinder.cue_for` of each annotated kind resolves as expected.
- [ ] **Step 2:** Run: FAIL. **Step 3:** Annotate + docs. **Step 4:** Run the new suite and every suite of a screen you touched: PASS.
- [ ] **Step 5:** Commit + push, message `Annotate UI buttons for confirm/cancel/no-cue and document the UI audio cues`.

---

## Self-review

Spec coverage: §3 binder (T1), dispatcher ownership + denial events + rate limit + cue data + paused-tree check (T2), annotations + docs (T3), §4 edge cases (T1 tests: pre-existing/late/double hook/freed; T2: pause; T3: no double-sound via `none`), §5 tests (per task). Types: `UiAudioBinder` constants and `cue_for`/`setup` defined once in T1 and used in T2/T3; `DENIED_EVENT_MIN_GAP_MSEC` only in T2. Watch item carried to reviewers: sounds are placeholders chosen without listening — the human listening pass is on the live checklist.
