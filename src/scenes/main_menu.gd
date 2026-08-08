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
## occupied rows are clickable, empty rows are disabled. EC-3/EC-5 UI
## (crash-recovery dialog, corrupt-save warning badge) are NOT built —
## their own backend doesn't exist, so building the UI for them would
## present functionality that doesn't actually work.
##
## Gamepad focus rings (2026-08-01, ADR-0011 — UI Dual-Focus Handling):
## own InputModeTracker child (matching InventoryScreen's identical
## pattern, not Mission HUD's injected-tracker variant, since this screen
## has no outer owner to inject one). Every real interactive Control gets a
## FocusRingFactory ring, gated on has_focus() AND InputModeTracker.
## is_focus_ring_visible() — same rule InventoryScreen and Mission HUD
## already use, never merged into hover state.
##
## Tab-focus containment (2026-08-01): every modal panel (Settings, Load
## Game, Overwrite Confirm) disables the 5 top-level nav buttons
## (Continue/New Game/Load Game/Settings/Quit) for the duration it's open
## and restores them on close — Godot's automatic Tab/Shift+Tab traversal
## has no concept of "modal," so without this, Tab could cycle focus back
## onto buttons that are visually covered but not focus-excluded. Exactly
## one modal can be open at a time (each modal's own open path only
## reachable through a nav button, which is itself disabled while any
## other modal is open), so a single shared disable/restore pair is safe.
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
const DISPLAY_SETTINGS_PATH: String = "user://display_settings.cfg"
const DISPLAY_SETTINGS_SECTION: String = "display"

const UI_SCALE_MIN: float = 75.0
const UI_SCALE_MAX: float = 150.0
const UI_SCALE_DEFAULT: float = 100.0

@onready var _settings_panel: Control = $SettingsPanel
@onready var _load_game_panel: Control = $LoadGamePanel
@onready var _overwrite_confirm_panel: Control = $OverwriteConfirmPanel
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
	_load_game_back_button.pressed.connect(_on_load_game_back_pressed)
	_overwrite_yes_button.pressed.connect(_on_overwrite_yes_pressed)
	_overwrite_cancel_button.pressed.connect(_on_overwrite_cancel_pressed)
	for slot: int in range(SAVE_SLOT_COUNT):
		_slot_buttons[slot].pressed.connect(_on_slot_button_pressed.bind(slot))

	_settings_panel.visible = false
	_load_game_panel.visible = false
	_overwrite_confirm_panel.visible = false

	_build_focus_ring(_continue_button)
	_build_focus_ring(_new_game_button)
	_build_focus_ring(_load_game_button)
	_build_focus_ring(_settings_button)
	_build_focus_ring(_quit_button)
	_build_focus_ring(_settings_back_button)
	_build_focus_ring(_load_game_back_button)
	_build_focus_ring(_overwrite_yes_button)
	_build_focus_ring(_overwrite_cancel_button)
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
	GSavePersistence.load_slot(slot)
	GSceneManager.transition_to_sanctuary()


func _on_new_game_pressed() -> void:
	var slot: int = _first_empty_slot()
	if slot != -1:
		GSavePersistence.start_new_game(slot)
		GSceneManager.transition_to_sanctuary()
		return
	_pending_overwrite_slot = 0
	_overwrite_message_label.text = "This will overwrite Slot %d. Continue?" % (_pending_overwrite_slot + 1)
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
		button.text = "Slot %d — %s" % [slot + 1, "Occupied" if exists else "Empty"]
		button.disabled = not exists
		button.focus_mode = Control.FOCUS_ALL if exists else Control.FOCUS_NONE


func _on_slot_button_pressed(slot: int) -> void:
	GSavePersistence.load_slot(slot)
	GSceneManager.transition_to_sanctuary()


func _on_load_game_back_pressed() -> void:
	_load_game_panel.visible = false
	_set_nav_buttons_focusable(true)
	_load_game_button.grab_focus()


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
