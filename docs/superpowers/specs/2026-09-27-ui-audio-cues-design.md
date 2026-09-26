# UI Click / Confirm / Cancel / Denial Audio Cues — Design

- **Date:** 2026-09-27
- **Status:** Implemented (2026-09-27; not live-verified); decisions taken with the recommended option at each choice, on the user's instruction ("pick the recommended options and go ahead").
- **Closes:** the audio follow-up "UI-click and denial cue hooks" (audio-cue-list spec §9, session state backlog).
- **GDD:** `design/gdd/audio-system.md` Core Rules 3-5 (families #3 Denial/Rejection, #4 Activation/Deactivation Confirm, #5 UI Confirm/Cancel; `UI` bus with the UI→Music+SFX sidechain duck).

## 1. Goal and non-goals

**Goal.** Every button in the game gives audible feedback: a dry click for ordinary buttons, a brighter confirm for primary actions, a softer cancel for back/dismiss, and a short low denial when the player presses a disabled button or the game rejects an action (blocked tower placement, rejected item pickup).

**Non-goals.**
- No hover or focus-move ticks (the audio GDD calls UI Confirm the most fatiguing, highest-frequency family).
- No volume settings screen (the four sliders already exist as buses; the settings UI is a separate item).
- No new EventBus signals and no direct UI → Audio calls beyond the binder described below.
- No real sound design: Kenney Interface Sounds (CC0) placeholders, like every other cue so far.

## 2. Decisions

| Topic | Decision |
|---|---|
| Mechanism | **Auto-hook.** A `UiAudioBinder` (child of `AudioCueDispatcher`) watches `SceneTree.node_added`, hooks every `BaseButton`, and dispatches cues through the dispatcher's existing single entry point. No edits across the ~22 UI scripts; new screens get sound for free |
| Per-button override | Node meta `ui_audio` on the button: `&"confirm"`, `&"cancel"`, `&"none"`; absent = ordinary click. Set in scripts with `button.set_meta(UiAudioBinder.META_KEY, UiAudioBinder.KIND_CONFIRM)` |
| Denial | (a) a click on a **disabled** button (detected from `gui_input`, because a disabled `BaseButton` emits no `pressed`); (b) existing EventBus events `tower_placement_blocked` and `item_pickup_rejected` |
| Cues | `ui_click`, `ui_confirm`, `ui_cancel`, `ui_denied`, all on the `UI` bus (so they duck music/SFX by the existing sidechain), families `ui_confirm_cancel` (click, cancel), `activation_confirm` (confirm), `denial_rejection` (denied) |
| Audio when paused | The dispatcher already freezes with the tree; UI cues on the Pause Menu must still play: the binder and dispatcher players use `process_mode = ALWAYS` if the dispatcher is not already always-processing (verify; see §4) |

## 3. Components

**`UiAudioBinder`** (`src/core/audio/ui_audio_binder.gd`, `class_name UiAudioBinder`, `Node`):
- Constants: `META_KEY = &"ui_audio"`, `KIND_CONFIRM = &"confirm"`, `KIND_CANCEL = &"cancel"`, `KIND_NONE = &"none"`, and cue names `CUE_CLICK = &"ui_click"`, `CUE_CONFIRM = &"ui_confirm"`, `CUE_CANCEL = &"ui_cancel"`, `CUE_DENIED = &"ui_denied"`.
- `setup(dispatch: Callable, tree: SceneTree)`: stores the injectable dispatch callable (default the dispatcher's `dispatch_cue`), connects `tree.node_added` and hooks every button already in the tree (`_hook_existing(tree.root)`).
- `static func cue_for(button_kind: StringName) -> StringName`: `confirm`→`ui_confirm`, `cancel`→`ui_cancel`, `none`→`&""`, anything else → `ui_click`.
- `_hook(button: BaseButton)`: idempotent (a meta flag `_ui_audio_hooked`), connects `pressed` to a bound handler and `gui_input` to a bound denial handler; buttons freed later disconnect themselves (the connections live on the button, so freeing it drops them).
- `_on_pressed(button)`: reads the button's `ui_audio` meta, dispatches `cue_for(kind)` unless `none`.
- `_on_gui_input(event, button)`: if `button.disabled` and `event` is a left-mouse press, dispatch `CUE_DENIED` once per press; keyboard/gamepad cannot activate a disabled button (no focus), so mouse is the only path.
- `_exit_tree`: disconnects `node_added` and every hooked button's connections (Rule 6, guarded by `is_connected` and `is_instance_valid`).

**`AudioCueDispatcher`** gains: creation of the binder in `_ready` (`add_child`, `setup(dispatch_cue, get_tree())`), plus two `_wire(...)` lines mapping `tower_placement_blocked` and `item_pickup_rejected` to `dispatch_cue(&"ui_denied")`. `tower_placement_blocked` may fire repeatedly while the cursor hovers a blocked cell: rate-limit `ui_denied` from events to one per `DENIED_EVENT_MIN_GAP_MSEC = 300` (same pattern as the wind-up warning).

**Cue data** (`assets/data/audio/cues/ui_click.tres`, `ui_confirm.tres`, `ui_cancel.tres`, `ui_denied.tres`, registered in `audio_cue_map.tres`): authored through `tools/audio/author_cue.sh` / `process_sound.sh`; two or three light variants for `ui_click` (an `AudioStreamRandomizer`, ±pitch) so repetition is not fatiguing; short (<0.25 s), dry, `volume_db_offset` around -8/-6/-8/-6.

**Button annotations** (one-line `set_meta` calls, only where the default click is wrong): outcome screen Retry = confirm, Return = click; Mission HUD Ready/Launch-type primary actions = confirm; Back/Close/Cancel buttons = cancel. Everything else stays the default click.

## 4. Edge cases

1. **Buttons created before the binder** exist (autoload order): `_hook_existing` walks the whole tree once in `setup`.
2. **A button is hooked twice** (re-parented): the hooked-meta flag makes `_hook` a no-op.
3. **`TextureButton`, `CheckBox`, `OptionButton`, `MenuButton`** are `BaseButton`s and are hooked; `toggled`-only checkboxes still emit `pressed`.
4. **Programmatic `button.pressed.emit()`** (tests, gamepad synthesis) plays the click; acceptable.
5. **Paused tree**: Pause Menu buttons are `PROCESS_MODE_ALWAYS`; `pressed` still fires, but the dispatcher's own `_process` (sidechain ticking) freezes while paused. The cue itself must still play: verify `_play_stream` does not depend on `_process`; if the dispatcher's player pool stops while paused, set the pool players' `process_mode = PROCESS_MODE_ALWAYS`.
6. **Silent when no stream**: a cue without a stream still dispatches (routing only), as today.
7. **`ui_audio = none`** for buttons that already trigger their own richer cue (e.g. a craft button whose `component_crafted` event plays a cue) so the two do not stack; annotate those buttons `none` where an existing event cue plays for the same action (craft, repair, build/upgrade structure, equip forge).

## 5. Testing

Unit: `cue_for` mapping; binder hooks a `Button` added after setup and one that existed before; `pressed` dispatches `ui_click` / confirm / cancel / nothing per meta; a disabled button's left-click `gui_input` dispatches `ui_denied` once and an enabled one does not; double hooking is a no-op; freeing the binder disconnects (no errors when the button later presses); dispatcher wiring: `tower_placement_blocked` and `item_pickup_rejected` dispatch `ui_denied` and the event rate limit works; the real `audio_cue_map.tres` contains the four cues with the right bus and families; `VoiceLimiter` accepts the families. Integration: booting the outcome screen hooks its buttons and Retry uses confirm.
Live (only when asked): click buttons in the Sanctuary and a mission; press a disabled button; block a tower placement; listen for the four sounds.

## 6. Files

| File | Change |
|---|---|
| `src/core/audio/ui_audio_binder.gd` (new) | the binder |
| `src/core/audio/audio_cue_dispatcher.gd` | create the binder; wire the two denial events + rate limit |
| `assets/audio/sfx/ui_*.wav`, `assets/data/audio/cues/ui_*.tres`, `assets/data/audio/audio_cue_map.tres`, `assets/audio/sfx/SOURCES.md`, `assets/audio/sfx/LICENSE.txt` (if needed), `assets/source/audio/ui_*/` | content |
| UI scripts (few) | `set_meta` annotations |
| docs | `audio-system.md`, `production/qa/audio-cue-listening-pass.md`, `active.md` |
