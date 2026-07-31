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
## needed. SETTINGS opens a minimal placeholder Control (no real Settings
## system exists anywhere in this project yet) rather than fabricating
## options that don't exist.
##
## Gamepad focus rings (2026-08-01, ADR-0011 — UI Dual-Focus Handling):
## own InputModeTracker child (matching InventoryScreen's identical
## pattern, not Mission HUD's injected-tracker variant, since this screen
## has no outer owner to inject one). All 4 real interactive buttons
## (PLAY/SETTINGS/QUIT plus the Settings placeholder's own Back button) get
## a FocusRingFactory ring, gated on has_focus() AND
## InputModeTracker.is_focus_ring_visible() — same rule InventoryScreen and
## Mission HUD already use, never merged into hover state. PLAY grabs
## initial keyboard/gamepad focus on open — no prior screen in this project
## does this, but a menu that opens with nothing focused is unnavigable by
## gamepad/keyboard alone until the player first moves the mouse, which
## would violate ui-code.md's "support both keyboard/mouse AND gamepad
## input for all interactive elements" for the very first frame.
##
## Tab-focus containment (2026-08-01, follow-up fix): the Settings
## placeholder previously didn't trap Tab-focus — Godot's automatic
## Tab/Shift+Tab traversal has no concept of "modal," so with the 3
## underlying buttons still focus_mode=FOCUS_ALL, pressing Tab while the
## panel was open (Back being the only focusable Control inside it) simply
## kept cycling out to whichever of PLAY/SETTINGS/QUIT was next in tree
## order — visually covered by the panel but not focus-excluded. Fixed by
## setting the 3 underlying buttons to FOCUS_NONE for the duration the
## panel is open and restoring FOCUS_ALL on close, so Back is the only
## focusable Control in the tree while the modal is up (Tab/Shift+Tab both
## just keep it focused, matching real single-focusable-element behavior).

@onready var _settings_panel: Control = $SettingsPanel
@onready var _input_mode_tracker: InputModeTracker = $InputModeTracker

var _play_button: TextureButton
var _settings_button: TextureButton
var _quit_button: TextureButton
var _back_button: Button

var _play_focus_ring: Panel
var _settings_focus_ring: Panel
var _quit_focus_ring: Panel
var _back_focus_ring: Panel


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

	_play_focus_ring = FocusRingFactory.build(_play_button)
	_settings_focus_ring = FocusRingFactory.build(_settings_button)
	_quit_focus_ring = FocusRingFactory.build(_quit_button)
	_back_focus_ring = FocusRingFactory.build(_back_button)

	_play_button.focus_entered.connect(_update_focus_ring.bind(_play_button, _play_focus_ring))
	_play_button.focus_exited.connect(_update_focus_ring.bind(_play_button, _play_focus_ring))
	_settings_button.focus_entered.connect(_update_focus_ring.bind(_settings_button, _settings_focus_ring))
	_settings_button.focus_exited.connect(_update_focus_ring.bind(_settings_button, _settings_focus_ring))
	_quit_button.focus_entered.connect(_update_focus_ring.bind(_quit_button, _quit_focus_ring))
	_quit_button.focus_exited.connect(_update_focus_ring.bind(_quit_button, _quit_focus_ring))
	_back_button.focus_entered.connect(_update_focus_ring.bind(_back_button, _back_focus_ring))
	_back_button.focus_exited.connect(_update_focus_ring.bind(_back_button, _back_focus_ring))

	# One connection for the whole screen, fanning out inside the handler —
	# matching inventory_screen.gd's own established rationale (Signal.
	# connect() dedups by (target, method) only, not .bind() arguments, so
	# per-button connections to the same method would silently drop after
	# the first).
	_input_mode_tracker.input_mode_changed.connect(_on_input_mode_changed)

	_play_button.grab_focus()


func _on_play_pressed() -> void:
	GSceneManager.transition_to_sanctuary()


func _on_settings_pressed() -> void:
	_settings_panel.visible = true
	_set_underlying_buttons_focusable(false)
	_back_button.grab_focus()


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


func _update_focus_ring(button: BaseButton, ring: Panel) -> void:
	ring.visible = button.has_focus() and _input_mode_tracker.is_focus_ring_visible()


func _on_input_mode_changed(_mode: InputModeTracker.InputMode) -> void:
	_update_focus_ring(_play_button, _play_focus_ring)
	_update_focus_ring(_settings_button, _settings_focus_ring)
	_update_focus_ring(_quit_button, _quit_focus_ring)
	_update_focus_ring(_back_button, _back_focus_ring)
