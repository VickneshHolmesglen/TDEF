extends Control

## MainMenu — the game's real boot scene (2026-08-01).
##
## Real gap closed: no Main Menu existed anywhere in this project before now
## (project.godot's `run/main_scene` booted directly into `the_gap.tscn`).
## Background art and button art are user-provided (originally
## `assets/source/main_menu/main_menu_clean.png` / `main_menu_buttons.png`;
## `assets/Art Assets/` was reorganized into `assets/source/` on 2026-08-02),
## processed via flood-fill background-keying (same technique as the
## Sanctuary watchtower/habitat art) into `assets/art/main_menu/`.
##
## Continue/New Game/Load Game/Settings/Quit button art (2026-08-02):
## originally plain-text Buttons (Continue/New Game/Load Game) or textures
## cut from the first source sheet (Settings/Quit). Replaced with a second
## user-provided sheet (`assets/source/main_menu/updated_buttons_panel_1.png`)
## that actually has all 5 — all 5 nav buttons are now TextureButton with
## baked-in text/icon art, same style as before (chamfered stone plaque).
## Upgrades/Achievements/Collection from that same sheet were left unsliced —
## same reasoning as the original Upgrades/Achievements drop above, still no
## corresponding system.
##
## UPGRADES and ACHIEVEMENTS from the source art are dropped entirely:
## neither corresponds to any system in this project's systems-index (25
## systems, no Upgrades or Achievements). ENCYCLOPEDIA is also dropped,
## deliberately — the real Encyclopedia System exists and is Approved, but
## its own GDD explicitly leaves the entry-point/screen question open
## (OQ-5, `encyclopedia.md`), specifically because a past unplanned
## UI-shell addition in this project caused cascading review problems.
## Deciding OQ-5 is not this task's call.
##
## SETTINGS opens a real volume-mixer panel (2026-08-01) — 4 sliders
## (Music/SFX/Voice/UI), reading/writing the already-fully-implemented
## `GAudioSystem.get_bus_volume_percent()`/`set_bus_volume_percent()` API
## (`design/gdd/audio-system.md` Core Rule 1, `design/accessibility-
## requirements.md`'s Basic-tier "independent volume controls" commitment —
## both already designed; this pass only adds the missing UI, no new audio
## logic). Every other Settings-relevant accessibility commitment (UI
## scaling, colorblind modes, input remapping, motion reduction, difficulty
## sliders — all "Not Started" project-wide per that doc's own matrix) is
## deliberately NOT built here.
##
## Continue / New Game / Load Game (2026-08-01, `design/ux/main-menu.md`):
## a reduced-scope implementation of that pre-existing UX spec — built
## because `SavePersistence` itself doesn't yet implement the spec's fuller
## EC-3 (crash recovery)/EC-5 (corrupt-save) mechanics (no checkpoint
## deletion, no corrupt-file rename, no slot metadata storage exist in
## `save_persistence.gd` today — confirmed by reading it before building
## anything). What IS real and used here: `SavePersistence.load_slot()`/
## `set_active_slot()`/`SAVE_PATH` (a public const), plus plain
## `FileAccess.file_exists()`/`get_modified_time()` for read-only slot-state
## checks — no new SavePersistence API was added. **Continue** loads
## whichever of the 3 slots (0-2, per `save-persistence.md`) has the most
## recent file modification time. **New Game** targets the first empty slot
## silently, or slot 0 with an Overwrite Confirmation modal if all 3 are
## full. **Load Game** shows a 3-row slot list (Occupied/Empty only — no
## timestamp/summary, since no such metadata is stored anywhere yet);
## occupied rows are clickable, empty rows are disabled.
##
## EC-3/EC-5/AC-11 UI (2026-08-23): closed. The backend (`has_pending_
## checkpoint()`, `restore_from_checkpoint()`, `LoadResult`) was built
## 2026-08-01 but never wired to any UI until now — Continue and every Load
## Game slot click route through `_load_or_offer_recovery()` /
## `_perform_load()`, which check for a pending checkpoint first (EC-3's
## Load-Save-vs-Restore-Checkpoint choice, `RecoveryChoicePanel`) and surface
## `CORRUPT_RECOVERED`/`VERSION_TOO_NEW` as a player-facing message
## (`SaveWarningPanel`) instead of silently succeeding or silently refusing.
##
## Gamepad focus rings (2026-08-01, ADR-0011 — UI Dual-Focus Handling):
## own InputModeTracker child (matching InventoryScreen's identical
## pattern, not Mission HUD's injected-tracker variant, since this screen
## has no outer owner to inject one). Every real interactive Control gets a
## FocusRingFactory ring, gated on has_focus() AND InputModeTracker.
## is_focus_ring_visible() — same rule InventoryScreen and Mission HUD
## already use, never merged into hover state.
##
## Tab-focus containment (2026-08-01; extended 2026-08-23 for the 2 new EC-3/
## EC-5/AC-11 panels): every modal panel (Settings, Load Game, Overwrite
## Confirm, Recovery Choice, Save Warning) disables the 5 top-level nav
## buttons (Continue/New Game/Load Game/Settings/Quit) for the duration it's
## open and restores them on close — Godot's automatic Tab/Shift+Tab
## traversal has no concept of "modal," so without this, Tab could cycle
## focus back onto buttons that are visually covered but not focus-excluded.
## Exactly one modal is visible at a time: Recovery Choice and Save Warning
## can both open from a Load Game slot click, so `_load_or_offer_recovery()`
## explicitly hides the Load Game panel first rather than relying solely on
## "reachable only through a disabled nav button" (that guard alone would
## have let Load Game stay visible underneath a slot-triggered panel).
##
## Display resolution + fullscreen (2026-08-05, `design/quick-specs/
## display-resolution-setting-2026-08-05.md`): 2 new Settings panel
## controls (Resolution OptionButton, Fullscreen CheckButton), independent
## of the still-open "UI scaling" accessibility item. Resolution dropdown
## is disabled while Fullscreen is checked (fullscreen always uses the
## native desktop resolution, not the dropdown value). Persisted to
## `user://display_settings.cfg`, loaded and applied at the top of
## `_ready()` so the boot window already reflects the last session's
## choice before the player sees the menu. `project.godot` also gained
## `window/stretch/mode="canvas_items"`/`aspect="keep"` in the same pass —
## required for resolution switching to scale the UI instead of
## clipping/distorting it.
##
## Menu UI scale (2026-08-05/06, `design/quick-specs/menu-ui-scale-
## 2026-08-05.md`): closes the Main-Menu half of `design/accessibility-
## requirements.md`'s "UI scaling" item (75%-150%, default 100%) — HUD
## scale stays a separate, still-open value, since no real HUD UI exists
## yet to scale. Applies `Control.scale` to each of Main Menu's own
## content groups (TitleLabel, Buttons, and each modal panel's *inner*
## children — never the full-rect ColorRect panels themselves, which
## would grow away from their own (0,0) origin and push far content
## off-screen at >100%). Persisted alongside resolution/fullscreen in the
## same `user://display_settings.cfg` (`ui_scale` key, same `display`
## section) — same lifecycle, same file, not a new one.
##
## Escape/ui_cancel (2026-08-06, `design/quick-specs/main-menu-escape-key-
## 2026-08-06.md`, user-reported gap): matches Sanctuary UI/Tarot Deck
## UI's own established `ui_cancel` convention (Godot's built-in action,
## Escape/gamepad East-B, no InputMap override needed). No modal open ->
## same path as clicking Settings. A modal open -> that modal's own
## existing Back/Cancel function, exactly as its Back/Cancel button
## already calls -- no new close logic introduced.

const VOLUME_BUSES: Array[StringName] = [&"Music", &"SFX", &"Voice", &"UI"]
const SAVE_SLOT_COUNT: int = 3

## Curated, not a dynamic probe of the display's supported modes — matches
## this project's existing "fixed curated list" pattern (e.g. the 3-slot
## save system). Index into this array is what gets persisted.
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
## Rooted at UserDataPaths.root() so gdUnit4 runs never touch real settings.
static var DISPLAY_SETTINGS_PATH: String = UserDataPaths.root() + "display_settings.cfg"
const DISPLAY_SETTINGS_SECTION: String = "display"

const UI_SCALE_MIN: float = 75.0
const UI_SCALE_MAX: float = 150.0
const UI_SCALE_DEFAULT: float = 100.0

@onready var _settings_panel: Control = $SettingsPanel
@onready var _load_game_panel: Control = $LoadGamePanel
@onready var _overwrite_confirm_panel: Control = $OverwriteConfirmPanel
@onready var _recovery_choice_panel: Control = $RecoveryChoicePanel
@onready var _save_warning_panel: Control = $SaveWarningPanel
@onready var _input_mode_tracker: InputModeTracker = $InputModeTracker

var _continue_button: TextureButton
var _new_game_button: TextureButton
var _load_game_button: TextureButton
var _settings_button: TextureButton
var _quit_button: TextureButton
var _settings_back_button: Button
var _load_game_back_button: Button
var _overwrite_message_label: Label
var _overwrite_yes_button: Button
var _overwrite_cancel_button: Button
var _recovery_load_save_button: Button
var _recovery_restore_checkpoint_button: Button
var _save_warning_message_label: Label
var _save_warning_ok_button: Button

## Slot EC-3's recovery choice panel is currently open for — set by
## _on_continue_pressed()/_on_slot_button_pressed() before showing the
## panel, read by both of the panel's own button handlers.
var _pending_recovery_slot: int = -1

## True when the save-warning panel's OK button should proceed to Sanctuary
## (EC-5 CORRUPT_RECOVERED — the load actually succeeded, just with reset
## defaults) vs. just dismiss back to the menu (AC-11 VERSION_TOO_NEW — the
## load was aborted, file left untouched, nothing to proceed into).
var _save_warning_should_proceed: bool = false

## Index matches slot number (0-2).
var _slot_buttons: Array[Button] = []

## Set when Overwrite Confirmation opens from New Game targeting a full
## slot set — always 0 in this reduced-scope pass (see class doc comment),
## but stored rather than hardcoded at the Yes-button call site so a future
## multi-slot-target New Game flow doesn't have to hunt for this.
var _pending_overwrite_slot: int = 0

## Keyed by bus name (matches VOLUME_BUSES) -> the row's HSlider/ValueLabel.
var _volume_sliders: Dictionary[StringName, HSlider] = {}
var _volume_value_labels: Dictionary[StringName, Label] = {}

var _resolution_option: OptionButton
var _fullscreen_check: CheckButton
var _selected_resolution_index: int = 0

var _ui_scale_slider: HSlider
var _ui_scale_value_label: Label

## Main Menu's own content groups -- title, nav buttons, and each modal
## panel's inner children (never the full-rect ColorRect panels
## themselves; see class doc comment). Populated in _ready().
var _scalable_controls: Array[Control] = []

## Every focus-ringed Control -> its ring, one dictionary instead of one
## var pair per Control — too many real interactive Controls on this
## screen now (5 nav buttons + 4 sliders + 3 slot rows + 5 modal buttons)
## for the old one-pair-per-button approach from an earlier, smaller pass.
var _focus_rings: Dictionary[Control, Panel] = {}


func _ready() -> void:
	_continue_button = $Buttons/ContinueButton
	_new_game_button = $Buttons/NewGameButton
	_load_game_button = $Buttons/LoadGameButton
	_settings_button = $Buttons/SettingsButton
	_quit_button = $Buttons/QuitButton
	_settings_back_button = $SettingsPanel/SettingsContent/BackButton
	_load_game_back_button = $LoadGamePanel/LoadGameContent/BackButton
	_overwrite_message_label = $OverwriteConfirmPanel/OverwriteContent/MessageLabel
	_overwrite_yes_button = $OverwriteConfirmPanel/OverwriteContent/ConfirmButtons/YesButton
	_overwrite_cancel_button = $OverwriteConfirmPanel/OverwriteContent/ConfirmButtons/CancelButton
	_recovery_load_save_button = $RecoveryChoicePanel/RecoveryContent/ChoiceButtons/LoadSaveButton
	_recovery_restore_checkpoint_button = $RecoveryChoicePanel/RecoveryContent/ChoiceButtons/RestoreCheckpointButton
	_save_warning_message_label = $SaveWarningPanel/SaveWarningContent/MessageLabel
	_save_warning_ok_button = $SaveWarningPanel/SaveWarningContent/OkButton
	_resolution_option = $SettingsPanel/SettingsContent/DisplaySettings/ResolutionRow/OptionButton
	_fullscreen_check = $SettingsPanel/SettingsContent/DisplaySettings/FullscreenRow/CheckButton
	_ui_scale_slider = $SettingsPanel/SettingsContent/DisplaySettings/UiScaleRow/Slider
	_ui_scale_value_label = $SettingsPanel/SettingsContent/DisplaySettings/UiScaleRow/ValueLabel
	_slot_buttons = [
		$LoadGamePanel/LoadGameContent/Slots/Slot0Button,
		$LoadGamePanel/LoadGameContent/Slots/Slot1Button,
		$LoadGamePanel/LoadGameContent/Slots/Slot2Button,
	]
	# Each panel's real content lives inside one wrapper Control per panel
	# (SettingsContent/LoadGameContent/OverwriteContent) specifically so UI
	# Scale can scale that ONE wrapper per panel as a rigid group -- scaling
	# each inner block separately (the first version of this feature) left
	# fixed sibling offsets unchanged while their rendered size grew,
	# causing real overlap at >100% (caught live via Godot MCP before
	# shipping). TitleLabel/Buttons have no such sibling-overlap risk (nothing
	# else occupies the space below them at their max size) so they stay
	# scaled directly, not wrapped.
	_scalable_controls = [
		$TitleLabel, $Buttons,
		$SettingsPanel/SettingsContent,
		$LoadGamePanel/LoadGameContent,
		$OverwriteConfirmPanel/OverwriteContent,
		$RecoveryChoicePanel/RecoveryContent,
		$SaveWarningPanel/SaveWarningContent,
	]

	# Loaded and applied first so the real window already reflects the
	# last session's choice before the rest of the menu is set up.
	_setup_display_settings()

	_continue_button.pressed.connect(_on_continue_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_load_game_button.pressed.connect(_on_load_game_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_settings_back_button.pressed.connect(_on_settings_back_pressed)
	_settings_back_button.set_meta(UiAudioBinder.META_KEY, UiAudioBinder.KIND_CANCEL)
	_load_game_back_button.pressed.connect(_on_load_game_back_pressed)
	_load_game_back_button.set_meta(UiAudioBinder.META_KEY, UiAudioBinder.KIND_CANCEL)
	_overwrite_yes_button.pressed.connect(_on_overwrite_yes_pressed)
	_overwrite_cancel_button.pressed.connect(_on_overwrite_cancel_pressed)
	_overwrite_cancel_button.set_meta(UiAudioBinder.META_KEY, UiAudioBinder.KIND_CANCEL)
	_recovery_load_save_button.pressed.connect(_on_recovery_load_save_pressed)
	_recovery_restore_checkpoint_button.pressed.connect(_on_recovery_restore_checkpoint_pressed)
	_save_warning_ok_button.pressed.connect(_on_save_warning_ok_pressed)
	for slot: int in range(SAVE_SLOT_COUNT):
		_slot_buttons[slot].pressed.connect(_on_slot_button_pressed.bind(slot))

	_settings_panel.visible = false
	_load_game_panel.visible = false
	_overwrite_confirm_panel.visible = false
	_recovery_choice_panel.visible = false
	_save_warning_panel.visible = false
	for panel: Control in [_settings_panel, _load_game_panel, _overwrite_confirm_panel, _recovery_choice_panel, _save_warning_panel]:
		panel.visibility_changed.connect(_on_overlay_visibility_changed.bind(panel))
		_style_overlay_controls(panel)

	_build_focus_ring(_continue_button)
	_build_focus_ring(_new_game_button)
	_build_focus_ring(_load_game_button)
	_build_focus_ring(_settings_button)
	_build_focus_ring(_quit_button)
	_build_focus_ring(_settings_back_button)
	_build_focus_ring(_load_game_back_button)
	_build_focus_ring(_overwrite_yes_button)
	_build_focus_ring(_overwrite_cancel_button)
	_build_focus_ring(_recovery_load_save_button)
	_build_focus_ring(_recovery_restore_checkpoint_button)
	_build_focus_ring(_save_warning_ok_button)
	_build_focus_ring(_resolution_option)
	_build_focus_ring(_fullscreen_check)
	_build_focus_ring(_ui_scale_slider)
	for slot_button: Button in _slot_buttons:
		_build_focus_ring(slot_button)

	for bus_name: StringName in VOLUME_BUSES:
		var row: HBoxContainer = $SettingsPanel/SettingsContent/VolumeSliders.get_node(_row_name(bus_name))
		var slider: HSlider = row.get_node("Slider")
		var value_label: Label = row.get_node("ValueLabel")
		_volume_sliders[bus_name] = slider
		_volume_value_labels[bus_name] = value_label
		_build_focus_ring(slider)
		slider.value = GAudioSystem.get_bus_volume_percent(bus_name)
		value_label.text = "%d%%" % int(slider.value)
		slider.value_changed.connect(_on_volume_slider_changed.bind(bus_name))

	# One connection for the whole screen, fanning out inside the handler —
	# matching inventory_screen.gd's own established rationale (Signal.
	# connect() dedups by (target, method) only, not .bind() arguments, so
	# per-Control connections to the same method would silently drop after
	# the first).
	_input_mode_tracker.input_mode_changed.connect(_on_input_mode_changed)

	_configure_continue_new_game_load_state()

	# Backdrop drift, fireflies, title/button entrance (after the Continue/Load
	# visibility decision above, which the entrance reads).
	var ambience := MainMenuAmbience.new()
	ambience.name = "Ambience"
	add_child(ambience)
	ambience.setup($Background, $TitleLabel, $Buttons)


## No modal open -> same path as clicking Settings. A modal open -> that
## modal's own existing Back/Cancel function, exactly as its Back/Cancel
## button already calls (see class doc comment).
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _settings_panel.visible:
		_on_settings_back_pressed()
	elif _load_game_panel.visible:
		_on_load_game_back_pressed()
	elif _overwrite_confirm_panel.visible:
		_on_overwrite_cancel_pressed()
	elif _recovery_choice_panel.visible:
		_on_recovery_cancel_pressed()
	elif _save_warning_panel.visible:
		_on_save_warning_ok_pressed()
	else:
		_on_settings_pressed()
	get_viewport().set_input_as_handled()


## GIVEN at least one of the 3 slots has a save file, THEN Continue and
## Load Game are shown (Continue primary/first) and grab initial focus.
## GIVEN no slot has a save file, THEN Continue/Load Game are hidden and
## New Game becomes the first visible (and focused) button in the
## VBoxContainer automatically, since VBoxContainer skips hidden children —
## no explicit reordering needed to match the UX spec's "New Game promoted
## to primary when no save exists" rule.
func _configure_continue_new_game_load_state() -> void:
	var has_save: bool = _most_recent_occupied_slot() != -1
	_continue_button.visible = has_save
	_load_game_button.visible = has_save
	if has_save:
		_continue_button.grab_focus()
	else:
		_new_game_button.grab_focus()


func _slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(SavePersistence.SAVE_PATH % slot)


## Returns the occupied slot with the most recent file modification time,
## or -1 if no slot has a save file. Matches the UX spec's "Continue...
## Loads the most recent save_slot_N.dat directly."
func _most_recent_occupied_slot() -> int:
	var best_slot: int = -1
	var best_time: int = -1
	for slot: int in range(SAVE_SLOT_COUNT):
		if not _slot_exists(slot):
			continue
		var modified_time: int = FileAccess.get_modified_time(SavePersistence.SAVE_PATH % slot)
		if modified_time > best_time:
			best_time = modified_time
			best_slot = slot
	return best_slot


## Local "YYYY-MM-DD HH:MM" of the slot's .dat modification time.
func _slot_saved_at_text(slot: int) -> String:
	var unix_utc: int = FileAccess.get_modified_time(SavePersistence.SAVE_PATH % slot)
	var bias_minutes: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var t: Dictionary = Time.get_datetime_dict_from_unix_time(unix_utc + bias_minutes * 60)
	return "%04d-%02d-%02d %02d:%02d" % [t.year, t.month, t.day, t.hour, t.minute]


func _first_empty_slot() -> int:
	for slot: int in range(SAVE_SLOT_COUNT):
		if not _slot_exists(slot):
			return slot
	return -1


## `bus_name` (e.g. &"SFX") -> its row node's name in SettingsPanel/
## VolumeSliders (e.g. "SfxRow") — the .tscn's own node-naming convention.
func _row_name(bus_name: StringName) -> String:
	var s: String = String(bus_name)
	return s.substr(0, 1) + s.substr(1).to_lower() + "Row"


func _build_focus_ring(control: Control) -> void:
	var ring: Panel = FocusRingFactory.build(control)
	_focus_rings[control] = ring
	control.focus_entered.connect(_update_focus_ring.bind(control))
	control.focus_exited.connect(_update_focus_ring.bind(control))


func _on_continue_pressed() -> void:
	var slot: int = _most_recent_occupied_slot()
	if slot == -1:
		return  # unreachable in practice -- button is only visible/focusable when a save exists
	_load_or_offer_recovery(slot)


func _on_new_game_pressed() -> void:
	var slot: int = _first_empty_slot()
	if slot != -1:
		GSavePersistence.start_new_game(slot)
		GSceneManager.transition_to_sanctuary()
		return
	_pending_overwrite_slot = 0
	_overwrite_message_label.text = tr("MAIN_MENU_OVERWRITE_CONFIRM") % (_pending_overwrite_slot + 1)
	_overwrite_confirm_panel.visible = true
	_set_nav_buttons_focusable(false)
	_overwrite_yes_button.grab_focus()


func _on_overwrite_yes_pressed() -> void:
	GSavePersistence.start_new_game(_pending_overwrite_slot)
	GSceneManager.transition_to_sanctuary()


func _on_overwrite_cancel_pressed() -> void:
	_overwrite_confirm_panel.visible = false
	_set_nav_buttons_focusable(true)
	_new_game_button.grab_focus()


func _on_load_game_pressed() -> void:
	_refresh_load_game_slots()
	_load_game_panel.visible = true
	_set_nav_buttons_focusable(false)
	var first_occupied: int = _most_recent_occupied_slot()
	if first_occupied != -1:
		_slot_buttons[first_occupied].grab_focus()
	else:
		_load_game_back_button.grab_focus()


## Empty rows are disabled (not just visually — FOCUS_NONE too), matching
## the UX spec's "Load Game... nothing to load" framing: an empty slot is
## not a valid Load Game target, not a smaller/greyed version of one.
func _refresh_load_game_slots() -> void:
	for slot: int in range(SAVE_SLOT_COUNT):
		var button: Button = _slot_buttons[slot]
		var exists: bool = _slot_exists(slot)
		# Occupied slots also show when they were saved, so three identical rows
		# are distinguishable (2026-10-04 smoke check).
		var status: String = tr("MAIN_MENU_SLOT_EMPTY")
		if exists:
			status = "%s  ·  %s" % [tr("MAIN_MENU_SLOT_OCCUPIED"), tr("MAIN_MENU_SLOT_SAVED_AT") % _slot_saved_at_text(slot)]
		button.text = tr("MAIN_MENU_SLOT_LABEL") % [slot + 1, status]
		button.disabled = not exists
		button.focus_mode = Control.FOCUS_ALL if exists else Control.FOCUS_NONE


func _on_slot_button_pressed(slot: int) -> void:
	_load_or_offer_recovery(slot)


func _on_load_game_back_pressed() -> void:
	_load_game_panel.visible = false
	_set_nav_buttons_focusable(true)
	_load_game_button.grab_focus()


# ---------------------------------------------------------------------------
# EC-3 (crash recovery) / EC-5 (corrupt save) / AC-11 (version mismatch)
# design/gdd/save-persistence.md -- TD-save-002, backend built 2026-08-01,
# UI closed here 2026-08-23.
# ---------------------------------------------------------------------------

## Entry point for both Continue and a Load Game slot click. Hides the Load
## Game panel first (it may still be open if this came from a slot click) so
## only one modal is ever visible at a time, matching this screen's existing
## invariant. EC-3: if a checkpoint is pending for this slot, the player
## chooses Load Save vs. Restore Checkpoint before anything loads. Otherwise
## goes straight to _perform_load().
func _load_or_offer_recovery(slot: int) -> void:
	_load_game_panel.visible = false
	if GSavePersistence.has_pending_checkpoint(slot):
		_pending_recovery_slot = slot
		_recovery_choice_panel.visible = true
		_set_nav_buttons_focusable(false)
		_recovery_load_save_button.grab_focus()
	else:
		_perform_load(slot)


## The actual load_slot() call, with its LoadResult routed to the right
## player-facing outcome -- SUCCESS proceeds silently (the pre-existing
## behavior), CORRUPT_RECOVERED and VERSION_TOO_NEW now surface EC-5/AC-11's
## required player-facing message instead of loading (or refusing to load)
## silently.
func _perform_load(slot: int) -> void:
	var result: SavePersistence.LoadResult = GSavePersistence.load_slot(slot)
	match result:
		SavePersistence.LoadResult.SUCCESS:
			GSceneManager.transition_to_sanctuary()
		SavePersistence.LoadResult.CORRUPT_RECOVERED:
			# EC-5: the load DID succeed (every system reset to defaults,
			# sanctuary_state_restored already fired) -- proceed on OK.
			_show_save_warning(tr("MAIN_MENU_SAVE_WARNING_DEFAULT"), true)
		SavePersistence.LoadResult.VERSION_TOO_NEW:
			# AC-11: load was aborted, file left untouched -- stay at the menu on OK.
			_show_save_warning(tr("MAIN_MENU_SAVE_WARNING_VERSION_TOO_NEW"), false)
		_:
			pass  # NOT_FOUND unreachable here -- every caller already confirmed the slot exists


func _on_recovery_load_save_pressed() -> void:
	_recovery_choice_panel.visible = false
	_perform_load(_pending_recovery_slot)


func _on_recovery_restore_checkpoint_pressed() -> void:
	_recovery_choice_panel.visible = false
	var slot: int = _pending_recovery_slot
	var result: SavePersistence.LoadResult = GSavePersistence.restore_from_checkpoint(slot)
	match result:
		SavePersistence.LoadResult.SUCCESS:
			GSceneManager.transition_to_sanctuary()
		SavePersistence.LoadResult.CHECKPOINT_CORRUPT:
			# EC-3's own spec: a corrupt checkpoint does NOT trigger EC-5's
			# reset-to-defaults -- it's discarded and we fall back to
			# load_slot(), since a good .dat likely still exists.
			_perform_load(slot)
		_:
			pass


func _on_recovery_cancel_pressed() -> void:
	_recovery_choice_panel.visible = false
	_pending_recovery_slot = -1
	_set_nav_buttons_focusable(true)
	if _continue_button.visible:
		_continue_button.grab_focus()
	else:
		_new_game_button.grab_focus()


func _show_save_warning(message: String, should_proceed_on_ok: bool) -> void:
	_save_warning_message_label.text = message
	_save_warning_should_proceed = should_proceed_on_ok
	_save_warning_panel.visible = true
	_set_nav_buttons_focusable(false)
	_save_warning_ok_button.grab_focus()


func _on_save_warning_ok_pressed() -> void:
	_save_warning_panel.visible = false
	if _save_warning_should_proceed:
		GSceneManager.transition_to_sanctuary()
		return
	_set_nav_buttons_focusable(true)
	if _continue_button.visible:
		_continue_button.grab_focus()
	else:
		_new_game_button.grab_focus()


func _on_settings_pressed() -> void:
	_settings_panel.visible = true
	_set_nav_buttons_focusable(false)
	_volume_sliders[VOLUME_BUSES[0]].grab_focus()


func _on_settings_back_pressed() -> void:
	_settings_panel.visible = false
	_set_nav_buttons_focusable(true)
	_settings_button.grab_focus()


func _set_nav_buttons_focusable(focusable: bool) -> void:
	var mode: Control.FocusMode = Control.FOCUS_ALL if focusable else Control.FOCUS_NONE
	_continue_button.focus_mode = mode
	_new_game_button.focus_mode = mode
	_load_game_button.focus_mode = mode
	_settings_button.focus_mode = mode
	_quit_button.focus_mode = mode


func _on_quit_pressed() -> void:
	get_tree().quit()


## AC-1 (audio-system.md): writes through GAudioSystem's own authoritative
## percent state immediately (audible change on drag), then persists to
## disk on every change rather than only on panel close — a device
## preference should never be silently lost if the player closes the app
## without pressing Back (e.g. Alt+F4), and ConfigFile.save() to a small
## 4-key file is cheap enough per-change to not need debouncing.
func _on_volume_slider_changed(value: float, bus_name: StringName) -> void:
	GAudioSystem.set_bus_volume_percent(bus_name, value)
	_volume_value_labels[bus_name].text = "%d%%" % int(value)
	GAudioSystem.save_settings_to_disk()


## Populates the Resolution dropdown from RESOLUTIONS, loads any persisted
## display preference (defaults to index 0 / windowed if none exists yet),
## and applies it to the real window. Wires the 2 controls' signals last,
## after `.selected`/`.button_pressed` are set from the loaded values, so
## loading a saved preference doesn't re-trigger a redundant save.
func _setup_display_settings() -> void:
	for resolution: Vector2i in RESOLUTIONS:
		_resolution_option.add_item("%dx%d" % [resolution.x, resolution.y])

	var config: ConfigFile = ConfigFile.new()
	var loaded: bool = config.load(DISPLAY_SETTINGS_PATH) == OK
	_selected_resolution_index = config.get_value(DISPLAY_SETTINGS_SECTION, "resolution_index", 0) if loaded else 0
	var is_fullscreen: bool = config.get_value(DISPLAY_SETTINGS_SECTION, "fullscreen", false) if loaded else false
	var ui_scale: float = config.get_value(DISPLAY_SETTINGS_SECTION, "ui_scale", UI_SCALE_DEFAULT) if loaded else UI_SCALE_DEFAULT
	ui_scale = clampf(ui_scale, UI_SCALE_MIN, UI_SCALE_MAX)

	_resolution_option.selected = _selected_resolution_index
	_fullscreen_check.button_pressed = is_fullscreen
	_resolution_option.disabled = is_fullscreen
	_apply_display_settings(_selected_resolution_index, is_fullscreen)

	_ui_scale_slider.value = ui_scale
	_ui_scale_value_label.text = "%d%%" % int(ui_scale)
	_apply_ui_scale(ui_scale)

	_resolution_option.item_selected.connect(_on_resolution_selected)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_ui_scale_slider.value_changed.connect(_on_ui_scale_changed)


## Fullscreen always uses the native desktop resolution — `resolution_index`
## only matters while windowed.
func _apply_display_settings(resolution_index: int, is_fullscreen: bool) -> void:
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(RESOLUTIONS[resolution_index])


func _on_resolution_selected(index: int) -> void:
	_selected_resolution_index = index
	_apply_display_settings(_selected_resolution_index, _fullscreen_check.button_pressed)
	_save_display_settings()


## Disables the Resolution dropdown while Fullscreen is checked (its value
## is meaningless in fullscreen) and restores it, at the previously
## selected resolution, when unchecked.
func _on_fullscreen_toggled(pressed: bool) -> void:
	_resolution_option.disabled = pressed
	_apply_display_settings(_selected_resolution_index, pressed)
	_save_display_settings()


func _save_display_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(DISPLAY_SETTINGS_SECTION, "resolution_index", _selected_resolution_index)
	config.set_value(DISPLAY_SETTINGS_SECTION, "fullscreen", _fullscreen_check.button_pressed)
	config.set_value(DISPLAY_SETTINGS_SECTION, "ui_scale", _ui_scale_slider.value)
	config.save(DISPLAY_SETTINGS_PATH)


## Scales each of Main Menu's own content groups uniformly around its own
## top-left origin -- never the full-rect ColorRect panel backgrounds
## themselves (see class doc comment for why).
func _apply_ui_scale(percent: float) -> void:
	var factor: float = percent / 100.0
	for control: Control in _scalable_controls:
		control.scale = Vector2(factor, factor)
	for panel: Control in [_settings_panel, _load_game_panel, _overwrite_confirm_panel, _recovery_choice_panel, _save_warning_panel]:
		if panel.visible:
			_center_overlay_content(panel.get_child(0) as Control)


# ---------------------------------------------------------------------------
# Overlay cards (2026-10-10 UI pass): each overlay's content used to sit at a
# fixed top-left offset over a near-black dim, leaving most of the screen
# empty. Its content wrapper is now centered on screen (accounting for UI
# Scale, which scales the wrapper from its own origin) on a chrome card.
# Computed on every show because some overlays set their message text just
# before showing.
# ---------------------------------------------------------------------------

const OVERLAY_CARD_PADDING: float = 32.0
## Backdrop alpha behind an open overlay: enough to quiet the menu art, not hide it.
const OVERLAY_DIM_ALPHA: float = 0.78
## How far an overlay card rises into place as it fades in.
const OVERLAY_RISE_PX: float = 14.0
var _overlay_cards: Dictionary[Control, Panel] = {}


func _on_overlay_visibility_changed(panel: Control) -> void:
	if panel.visible:
		_center_overlay_content.call_deferred(panel.get_child(0) as Control)


func _center_overlay_content(content: Control) -> void:
	var card: Panel = _overlay_cards.get(content)
	var bounds := Rect2()
	var has_bounds: bool = false
	for child: Node in content.get_children():
		if child == card or not (child is Control) or not (child as Control).visible:
			continue
		var control: Control = child as Control
		var control_size: Vector2 = control.size.max(control.get_combined_minimum_size())
		# Single-line labels are authored with generous fixed widths; measure
		# their text instead so the card hugs what's actually drawn.
		if control is Label and (control as Label).autowrap_mode == TextServer.AUTOWRAP_OFF:
			control_size.x = control.get_combined_minimum_size().x
		var rect := Rect2(control.position, control_size)
		bounds = bounds.merge(rect) if has_bounds else rect
		has_bounds = true
	if not has_bounds:
		return
	bounds = bounds.grow(OVERLAY_CARD_PADDING)

	if card == null:
		card = Panel.new()
		card.name = "OverlayCard"
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 2026-10-25 AAA UI pass: the studded HD-2D skin frame, matching every in-game
		# panel, instead of a flat 1 px outline box.
		card.add_theme_stylebox_override("panel", ShellChromeStyle.skin_panel(true))
		content.add_child(card)
		content.move_child(card, 0)
		_overlay_cards[content] = card
	card.position = bounds.position
	card.size = bounds.size

	var screen_center: Vector2 = get_viewport_rect().size / 2.0
	content.position = screen_center - bounds.get_center() * content.scale
	_play_overlay_entrance(content.get_parent() as Control, content)


## Overlays fade in while their card rises a few pixels into place, rather than
## popping on. Animates the backdrop's modulate and the content's position only:
## content.scale belongs to the UI-scale setting (_scalable_controls).
func _play_overlay_entrance(backdrop: Control, content: Control) -> void:
	if backdrop == null or ReduceMotion.enabled():
		return
	var rest_y: float = content.position.y
	backdrop.modulate.a = 0.0
	content.position.y = rest_y + OVERLAY_RISE_PX
	var tween: Tween = backdrop.create_tween().set_parallel(true)
	tween.tween_property(backdrop, "modulate:a", 1.0, ShellChromeStyle.MOTION_SETTLE_SEC)
	tween.tween_property(content, "position:y", rest_y, ShellChromeStyle.MOTION_SETTLE_SEC * 1.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## TD-ui-003 (2026-10-11): the overlays' buttons, sliders and labels were
## Godot's default grey theme on top of the chrome card. They now use the same
## ShellChromeStyle tokens as the Sanctuary shell -- outline buttons, with the
## one "go ahead" action per dialog filled (Yes / Load Save / OK).
func _style_overlay_controls(root: Node) -> void:
	var primary: Array[Button] = [_overwrite_yes_button, _recovery_load_save_button, _save_warning_ok_button]
	# Dim the menu art behind the dialog rather than blacking it out: the scene stays
	# present, the dialog reads as layered on top of it.
	if root is ColorRect:
		(root as ColorRect).color = Color(0.02, 0.03, 0.06, OVERLAY_DIM_ALPHA)
	for node: Node in root.find_children("*", "Control", true, false):
		if node is Label:
			if (node as Label).theme_type_variation == &"TitleLabel":
				continue  # keeps the theme's gold Cinzel heading
			(node as Label).add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
		elif node is Button:
			var button: Button = node as Button
			button.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
			button.add_theme_color_override("font_hover_color", Color.WHITE)
			if button is CheckButton:
				continue  # keeps its own switch art; a box around it reads as a second button
			var filled: bool = primary.has(button)
			# HD-2D skin frames per state (2026-10-25), primary actions in the amber
			# "active" frame; previously flat chrome boxes, the one place the skin
			# never reached.
			var skin_states: Dictionary = {
				"normal": &"active" if filled else &"normal",
				"hover": &"active" if filled else &"hover",
				"pressed": &"pressed",
				"hover_pressed": &"pressed",
				"disabled": &"disabled",
			}
			for state: String in skin_states:
				var box: StyleBoxTexture = ShellChromeStyle.skin_button(skin_states[state])
				# Without side padding, long labels ("Load Last Sanctuary Save") ran
				# into the border.
				box.content_margin_left = 20.0
				box.content_margin_right = 20.0
				button.add_theme_stylebox_override(state, box)
			button.add_theme_color_override("font_disabled_color", Color(ShellChromeStyle.UI_PARCHMENT, 0.4))
		elif node is HSlider:
			var track := StyleBoxFlat.new()
			track.bg_color = ShellChromeStyle.UI_CHROME.darkened(0.4)
			track.set_corner_radius_all(3)
			track.content_margin_top = 3.0
			track.content_margin_bottom = 3.0
			var fill: StyleBoxFlat = track.duplicate()
			fill.bg_color = ShellChromeStyle.UI_ACCENT
			node.add_theme_stylebox_override("slider", track)
			node.add_theme_stylebox_override("grabber_area", fill)
			node.add_theme_stylebox_override("grabber_area_highlight", fill)


func _on_ui_scale_changed(value: float) -> void:
	_apply_ui_scale(value)
	_ui_scale_value_label.text = "%d%%" % int(value)
	_save_display_settings()


func _update_focus_ring(control: Control) -> void:
	var ring: Panel = _focus_rings[control]
	ring.visible = control.has_focus() and _input_mode_tracker.is_focus_ring_visible()


func _on_input_mode_changed(_mode: InputModeTracker.InputMode) -> void:
	for control: Control in _focus_rings:
		_update_focus_ring(control)
