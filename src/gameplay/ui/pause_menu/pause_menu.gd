extends CanvasLayer

## Pause Menu — ADR-0014 (Accepted 2026-07-08), closes TD-pause-001.
##
## GDD source: design/gdd/event-bus.md Pause System section.
## UX source: design/ux/pause-menu.md.
##
## Settings/Objective/Quit to Main Menu (2026-08-23): the original 2026-07-08
## scope-down deferred these 3 buttons specifically because none of Settings,
## Objective, or a Main Menu scene existed as systems yet. All 3 now do
## (Main Menu's Settings panel, MissionResource.objective_text's display path
## closing TD-mission-001, and src/scenes/main_menu.gd/.tscn) — this closes
## the deferral, matching the GDD's full button set (Resume, Settings,
## Objective, Quit to Sanctuary, Quit to Main Menu).
##
## Settings sub-panel is scoped to exactly what design/accessibility-
## requirements.md's Basic-tier "Independent volume controls" commitment asks
## for here specifically ("Four independent sliders... Exposed in main
## settings and pause menu") — the 4 Music/SFX/Voice/UI sliders, wired to the
## same GAudioSystem API main_menu.gd already uses. Display resolution/
## fullscreen/UI-scale are Main-Menu-only extras, not part of this
## commitment, and deliberately not duplicated here.
##
## Objective sub-panel reads the mission_id cached from GEventBus.
## mission_launched (not MissionSelect's private _runtime_mission_id field —
## matching how SavePersistence/WaveManager already source this the same way)
## against GGameDataRegistry.get_mission_resource().objective_text.
##
## Quit to Main Menu gets its own confirmation dialog (GDD Interaction Map:
## "You'll lose progress in this attempt. Continue?"), matching the spec.
## Quit to Sanctuary's existing no-confirmation behavior is intentionally
## left unchanged here — it already shipped without one under the 2026-07-08
## reduced scope, and retrofitting a behavior change to already-shipped,
## already-relied-upon UI is out of scope for adding these 3 new buttons.
##
## No focus-ring system here (unlike Main Menu's FocusRingFactory usage) —
## this file never had one before this pass, and introducing a new UI
## paradigm to a single overlay screen is disproportionate to this scope.
## Tab/gamepad navigation still works via each panel's own Control tree;
## only the "which button set is focusable right now" containment matters,
## handled the same way as button focus_mode toggling below.
##
## SceneTree.paused is the single source of truth for "the game is paused" — every
## other node in the tree uses the default process_mode (PROCESS_MODE_INHERIT) and
## halts automatically. This node is the ONLY process_mode override in the codebase:
## PROCESS_MODE_ALWAYS keeps it receiving input and rendering while the tree is paused.
##
## No class_name declared — deliberately, per TD-workflow-001 (a recurring Godot
## 4.6.2 class-cache fragility where a fresh class_name isn't picked up by a bare
## headless boot). This scene is only ever instanced directly, never referenced by
## static type, so a class_name is not needed.

const VOLUME_BUSES: Array[StringName] = [&"Music", &"SFX", &"Voice", &"UI"]

@onready var _dim_overlay: ColorRect = $DimOverlay
@onready var _button_stack: VBoxContainer = $ButtonStack
@onready var _resume_button: Button = $ButtonStack/ResumeButton
@onready var _settings_button: Button = $ButtonStack/SettingsButton
@onready var _objective_button: Button = $ButtonStack/ObjectiveButton
@onready var _quit_to_sanctuary_button: Button = $ButtonStack/QuitToSanctuaryButton
@onready var _quit_to_main_menu_button: Button = $ButtonStack/QuitToMainMenuButton

@onready var _settings_panel: Control = $SettingsPanel
@onready var _settings_back_button: Button = $SettingsPanel/SettingsContent/BackButton

@onready var _objective_panel: Control = $ObjectivePanel
@onready var _objective_text_label: Label = $ObjectivePanel/ObjectiveContent/ObjectiveTextLabel
@onready var _objective_back_button: Button = $ObjectivePanel/ObjectiveContent/BackButton

@onready var _quit_confirm_panel: Control = $QuitToMainMenuConfirmPanel
@onready var _quit_confirm_yes_button: Button = $QuitToMainMenuConfirmPanel/ConfirmContent/ConfirmButtons/YesButton
@onready var _quit_confirm_cancel_button: Button = $QuitToMainMenuConfirmPanel/ConfirmContent/ConfirmButtons/CancelButton

## Keyed by bus name -> its row's HSlider/ValueLabel, matching main_menu.gd's
## own established Settings-panel pattern.
var _volume_sliders: Dictionary[StringName, HSlider] = {}
var _volume_value_labels: Dictionary[StringName, Label] = {}

## Cached from GEventBus.mission_launched — see class doc comment for why
## this is sourced from the event payload rather than MissionSelect's
## private runtime state.
var _current_mission_id: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_resume_button.pressed.connect(_on_resume_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_objective_button.pressed.connect(_on_objective_pressed)
	_quit_to_sanctuary_button.pressed.connect(_on_quit_to_sanctuary_pressed)
	_quit_to_main_menu_button.pressed.connect(_on_quit_to_main_menu_pressed)
	_settings_back_button.pressed.connect(_on_settings_back_pressed)
	_settings_back_button.set_meta(UiAudioBinder.META_KEY, UiAudioBinder.KIND_CANCEL)
	_objective_back_button.pressed.connect(_on_objective_back_pressed)
	_objective_back_button.set_meta(UiAudioBinder.META_KEY, UiAudioBinder.KIND_CANCEL)
	_quit_confirm_yes_button.pressed.connect(_on_quit_confirm_yes_pressed)
	_quit_confirm_cancel_button.pressed.connect(_on_quit_confirm_cancel_pressed)
	_quit_confirm_cancel_button.set_meta(UiAudioBinder.META_KEY, UiAudioBinder.KIND_CANCEL)
	GEventBus.mission_launched.connect(_on_mission_launched)

	for row_name: String in ["MusicRow", "SfxRow", "VoiceRow", "UiRow"]:
		var row: HBoxContainer = $SettingsPanel/SettingsContent/VolumeSliders.get_node(row_name)
		var bus_name: StringName = StringName(row_name.trim_suffix("Row"))
		# "Sfx"/"Ui" -> "SFX"/"UI" to match VOLUME_BUSES' real GAudioSystem bus names.
		if bus_name == &"Sfx":
			bus_name = &"SFX"
		elif bus_name == &"Ui":
			bus_name = &"UI"
		var slider: HSlider = row.get_node("Slider")
		var value_label: Label = row.get_node("ValueLabel")
		_volume_sliders[bus_name] = slider
		_volume_value_labels[bus_name] = value_label
		slider.value = GAudioSystem.get_bus_volume_percent(bus_name)
		value_label.text = "%d%%" % int(slider.value)
		slider.value_changed.connect(_on_volume_slider_changed.bind(bus_name))


func _exit_tree() -> void:
	_resume_button.pressed.disconnect(_on_resume_pressed)
	_settings_button.pressed.disconnect(_on_settings_pressed)
	_objective_button.pressed.disconnect(_on_objective_pressed)
	_quit_to_sanctuary_button.pressed.disconnect(_on_quit_to_sanctuary_pressed)
	_quit_to_main_menu_button.pressed.disconnect(_on_quit_to_main_menu_pressed)
	_settings_back_button.pressed.disconnect(_on_settings_back_pressed)
	_objective_back_button.pressed.disconnect(_on_objective_back_pressed)
	_quit_confirm_yes_button.pressed.disconnect(_on_quit_confirm_yes_pressed)
	_quit_confirm_cancel_button.pressed.disconnect(_on_quit_confirm_cancel_pressed)
	if GEventBus.mission_launched.is_connected(_on_mission_launched):
		GEventBus.mission_launched.disconnect(_on_mission_launched)


func _on_mission_launched(mission_id: String, _modifiers: PackedStringArray, _difficulty_tier: int) -> void:
	_current_mission_id = mission_id


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _settings_panel.visible:
		_on_settings_back_pressed()
	elif _objective_panel.visible:
		_on_objective_back_pressed()
	elif _quit_confirm_panel.visible:
		_on_quit_confirm_cancel_pressed()
	else:
		return  # no sub-panel open -- ui_cancel does nothing at the top-level Pause Menu
	get_viewport().set_input_as_handled()


## Toggle convention (UX spec): the same `pause` input both opens and closes this
## screen — pressing it again resumes without navigating to the Resume button.
func _toggle_pause() -> void:
	var new_paused: bool = not get_tree().paused
	get_tree().paused = new_paused
	visible = new_paused
	if new_paused:
		GEventBus.game_paused.emit()
	else:
		GEventBus.game_unpaused.emit()
		# Closing the whole overlay should never leave a sub-panel open for
		# next time it's re-opened via `pause`.
		_settings_panel.visible = false
		_objective_panel.visible = false
		_quit_confirm_panel.visible = false
		_set_button_stack_focusable(true)


func _on_resume_pressed() -> void:
	_toggle_pause()


func _set_button_stack_focusable(focusable: bool) -> void:
	var mode: Control.FocusMode = Control.FOCUS_ALL if focusable else Control.FOCUS_NONE
	_resume_button.focus_mode = mode
	_settings_button.focus_mode = mode
	_objective_button.focus_mode = mode
	_quit_to_sanctuary_button.focus_mode = mode
	_quit_to_main_menu_button.focus_mode = mode


# ---------------------------------------------------------------------------
# Settings sub-panel
# ---------------------------------------------------------------------------

func _on_settings_pressed() -> void:
	_settings_panel.visible = true
	_set_button_stack_focusable(false)
	_settings_back_button.grab_focus()


func _on_settings_back_pressed() -> void:
	_settings_panel.visible = false
	_set_button_stack_focusable(true)
	_settings_button.grab_focus()


## Matches main_menu.gd's own established rationale for writing through
## immediately and persisting on every change rather than only on close.
func _on_volume_slider_changed(value: float, bus_name: StringName) -> void:
	GAudioSystem.set_bus_volume_percent(bus_name, value)
	_volume_value_labels[bus_name].text = "%d%%" % int(value)
	GAudioSystem.save_settings_to_disk()


# ---------------------------------------------------------------------------
# Objective sub-panel (TD-mission-001)
# ---------------------------------------------------------------------------

func _on_objective_pressed() -> void:
	var resource: MissionResource = GGameDataRegistry.get_mission_resource(StringName(_current_mission_id))
	_objective_text_label.text = resource.objective_text if resource != null else ""
	_objective_panel.visible = true
	_set_button_stack_focusable(false)
	_objective_back_button.grab_focus()


func _on_objective_back_pressed() -> void:
	_objective_panel.visible = false
	_set_button_stack_focusable(true)
	_objective_button.grab_focus()


# ---------------------------------------------------------------------------
# Quit to Sanctuary (unchanged, no confirmation — see class doc comment)
# ---------------------------------------------------------------------------

func _on_quit_to_sanctuary_pressed() -> void:
	# Unpause before leaving — a mission scene must never hand control to
	# SceneManager while the tree is still paused.
	get_tree().paused = false
	visible = false
	GEventBus.game_unpaused.emit()
	GSceneManager.transition_to_sanctuary()


# ---------------------------------------------------------------------------
# Quit to Main Menu (new — confirmation required per the GDD)
# ---------------------------------------------------------------------------

func _on_quit_to_main_menu_pressed() -> void:
	_quit_confirm_panel.visible = true
	_set_button_stack_focusable(false)
	_quit_confirm_yes_button.grab_focus()


func _on_quit_confirm_yes_pressed() -> void:
	get_tree().paused = false
	visible = false
	GEventBus.game_unpaused.emit()
	GSceneManager.transition_to_main_menu()


func _on_quit_confirm_cancel_pressed() -> void:
	_quit_confirm_panel.visible = false
	_set_button_stack_focusable(true)
	_quit_to_main_menu_button.grab_focus()
