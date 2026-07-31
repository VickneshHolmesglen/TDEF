extends Control

## MainMenu — the game's real boot scene (2026-08-01).
##
## Real gap closed: no Main Menu existed anywhere in this project before now
## (project.godot's `run/main_scene` booted directly into `the_gap.tscn`).
## Background art and button art are user-provided (`assets/Art Assets/Main
## Menu Clean.png` / `Main Menu Buttons.png`), processed via flood-fill
## background-keying (same technique as the Sanctuary watchtower/habitat
## art) into `assets/art/main_menu/`.
##
## Only 3 of the source art's 6 buttons are wired — PLAY, SETTINGS, QUIT.
## UPGRADES and ACHIEVEMENTS are dropped entirely: neither corresponds to
## any system in this project's systems-index (25 systems, no Upgrades or
## Achievements). ENCYCLOPEDIA is also dropped, deliberately — the real
## Encyclopedia System exists and is Approved, but its own GDD explicitly
## leaves the entry-point/screen question open (OQ-5, `encyclopedia.md`),
## specifically because a past unplanned UI-shell addition in this project
## caused cascading review problems. Deciding OQ-5 is not this task's call.
##
## PLAY calls GSceneManager.transition_to_sanctuary() directly — the same
## real, already-working entry point Tarot Deck UI's own return path and
## every hero_died/mission_complete/pause-menu-quit trigger already use
## (see sanctuary_scene.gd's own doc comment). No new SceneManager API
## needed.
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
## deliberately NOT built here — each is its own real implementation effort
## across other systems, not something to fold silently into this pass.
##
## Gamepad focus rings (2026-08-01, ADR-0011 — UI Dual-Focus Handling):
## own InputModeTracker child (matching InventoryScreen's identical
## pattern, not Mission HUD's injected-tracker variant, since this screen
## has no outer owner to inject one). Every real interactive Control
## (PLAY/SETTINGS/QUIT, the 4 volume sliders, and Back) gets a
## FocusRingFactory ring, gated on has_focus() AND InputModeTracker.
## is_focus_ring_visible() — same rule InventoryScreen and Mission HUD
## already use, never merged into hover state. PLAY grabs initial
## keyboard/gamepad focus on open — no prior screen in this project does
## this, but a menu that opens with nothing focused is unnavigable by
## gamepad/keyboard alone until the player first moves the mouse, which
## would violate ui-code.md's "support both keyboard/mouse AND gamepad
## input for all interactive elements" for the very first frame.
##
## Tab-focus containment (2026-08-01): the Settings panel previously didn't
## trap Tab-focus — Godot's automatic Tab/Shift+Tab traversal has no
## concept of "modal," so with the underlying buttons still
## focus_mode=FOCUS_ALL, pressing Tab while the panel was open could cycle
## focus back onto them (visually covered but not focus-excluded). Fixed
## by setting PLAY/SETTINGS/QUIT to FOCUS_NONE for the duration the panel
## is open and restoring FOCUS_ALL on close, so only the panel's own
## Controls (4 sliders + Back) are reachable while it's up.

const VOLUME_BUSES: Array[StringName] = [&"Music", &"SFX", &"Voice", &"UI"]

@onready var _settings_panel: Control = $SettingsPanel
@onready var _input_mode_tracker: InputModeTracker = $InputModeTracker

var _play_button: TextureButton
var _settings_button: TextureButton
var _quit_button: TextureButton
var _back_button: Button

## Keyed by bus name (matches VOLUME_BUSES) -> the row's HSlider/ValueLabel.
var _volume_sliders: Dictionary[StringName, HSlider] = {}
var _volume_value_labels: Dictionary[StringName, Label] = {}

## Every focus-ringed Control -> its ring, one dictionary instead of one
## var pair per Control — 8 real interactive Controls on this screen now
## (3 nav buttons + 4 sliders + Back) makes the old one-pair-per-button
## approach from the smaller 2026-08-01 pass unwieldy to extend further.
var _focus_rings: Dictionary[Control, Panel] = {}


func _ready() -> void:
	_play_button = $Buttons/PlayButton
	_settings_button = $Buttons/SettingsButton
	_quit_button = $Buttons/QuitButton
	_back_button = $SettingsPanel/BackButton

	_play_button.pressed.connect(_on_play_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_back_button.pressed.connect(_on_settings_back_pressed)
	_settings_panel.visible = false

	_build_focus_ring(_play_button)
	_build_focus_ring(_settings_button)
	_build_focus_ring(_quit_button)
	_build_focus_ring(_back_button)

	for bus_name: StringName in VOLUME_BUSES:
		var row: HBoxContainer = $SettingsPanel/VolumeSliders.get_node(_row_name(bus_name))
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

	_play_button.grab_focus()


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


func _on_play_pressed() -> void:
	GSceneManager.transition_to_sanctuary()


func _on_settings_pressed() -> void:
	_settings_panel.visible = true
	_set_underlying_buttons_focusable(false)
	_volume_sliders[VOLUME_BUSES[0]].grab_focus()


func _on_settings_back_pressed() -> void:
	_settings_panel.visible = false
	_set_underlying_buttons_focusable(true)
	_settings_button.grab_focus()


func _set_underlying_buttons_focusable(focusable: bool) -> void:
	var mode: Control.FocusMode = Control.FOCUS_ALL if focusable else Control.FOCUS_NONE
	_play_button.focus_mode = mode
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


func _update_focus_ring(control: Control) -> void:
	var ring: Panel = _focus_rings[control]
	ring.visible = control.has_focus() and _input_mode_tracker.is_focus_ring_visible()


func _on_input_mode_changed(_mode: InputModeTracker.InputMode) -> void:
	for control: Control in _focus_rings:
		_update_focus_ring(control)
