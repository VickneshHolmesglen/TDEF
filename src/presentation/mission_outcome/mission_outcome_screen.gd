class_name MissionOutcomeScreen
extends CanvasLayer

## Victory / defeat overlay for a mission. Owns a MissionOutcomeStats fed by EventBus
## signals, shows after a short delay on the first terminal event of an attempt, and
## offers Retry (defeat only) and Return to Sanctuary. ADR-0001 Rule 6: every EventBus
## connection is removed in _exit_tree.

enum Mode { NONE, DEFEAT, VICTORY }

const OUTCOME_LAYER: int = 20
const DEFEAT_SHOW_DELAY_SECONDS: float = 1.5
const VICTORY_SHOW_DELAY_SECONDS: float = 0.5
const FADE_SECONDS: float = 0.25
const GROUP_NAME: StringName = &"mission_outcome_screen"
const PHASE_DEFEAT: String = "DEFEAT"
const PHASE_MISSION_COMPLETE: String = "MISSION_COMPLETE"

var _defeat_delay: float = DEFEAT_SHOW_DELAY_SECONDS
var _victory_delay: float = VICTORY_SHOW_DELAY_SECONDS
var _retry_action: Callable
var _sanctuary_action: Callable

var _stats: MissionOutcomeStats = MissionOutcomeStats.new()
var _mode: Mode = Mode.NONE
## True once a mission is running. The screen is a child of the mission scene and is freed
## with it, so it never ticks through non-mission scenes.
var _live: bool = false
var _terminal_seen: bool = false
var _show_timer: SceneTreeTimer = null
var _show_callback: Callable
var _fade_tween: Tween = null

@onready var _root: Control = $Root
@onready var _title_label: Label = %TitleLabel
@onready var _waves_value: Label = %WavesValue
@onready var _slain_value: Label = %SlainValue
@onready var _breaches_value: Label = %BreachesValue
@onready var _time_value: Label = %TimeValue
@onready var _waves_name: Label = %WavesName
@onready var _slain_name: Label = %SlainName
@onready var _breaches_name: Label = %BreachesName
@onready var _time_name: Label = %TimeName
@onready var _retry_button: Button = %RetryButton
@onready var _sanctuary_button: Button = %SanctuaryButton


## Title translation key for a mode ("" for NONE).
static func title_key(mode: Mode) -> String:
	match mode:
		Mode.DEFEAT:
			return "OUTCOME_TITLE_DEFEAT"
		Mode.VICTORY:
			return "OUTCOME_TITLE_VICTORY"
	return ""


## Button ids visible in a mode.
static func buttons_for(mode: Mode) -> Array[StringName]:
	match mode:
		Mode.DEFEAT:
			return [&"retry", &"sanctuary"]
		Mode.VICTORY:
			return [&"sanctuary"]
	return []


func _ready() -> void:
	add_to_group(GROUP_NAME)
	layer = OUTCOME_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if not _retry_action.is_valid():
		_retry_action = GMissionSelect.retry_current_mission
	if not _sanctuary_action.is_valid():
		_sanctuary_action = GSceneManager.transition_to_sanctuary
	_retry_button.pressed.connect(_on_retry_pressed)
	_sanctuary_button.pressed.connect(_on_sanctuary_pressed)
	_retry_button.focus_neighbor_right = _retry_button.get_path_to(_sanctuary_button)
	_sanctuary_button.focus_neighbor_left = _sanctuary_button.get_path_to(_retry_button)
	GEventBus.wave_started.connect(_on_wave_started)
	GEventBus.wave_completed.connect(_stats.on_wave_completed)
	GEventBus.monster_died.connect(_stats.on_monster_died)
	GEventBus.monster_breached.connect(_stats.on_monster_breached)
	GEventBus.mission_phase_changed.connect(_on_phase_changed)
	GEventBus.hero_died.connect(_on_hero_died)
	GEventBus.mission_launched.connect(_on_mission_launched)


func _exit_tree() -> void:
	_cancel_pending_show()
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
	if GEventBus.wave_started.is_connected(_on_wave_started):
		GEventBus.wave_started.disconnect(_on_wave_started)
	if GEventBus.wave_completed.is_connected(_stats.on_wave_completed):
		GEventBus.wave_completed.disconnect(_stats.on_wave_completed)
	if GEventBus.monster_died.is_connected(_stats.on_monster_died):
		GEventBus.monster_died.disconnect(_stats.on_monster_died)
	if GEventBus.monster_breached.is_connected(_stats.on_monster_breached):
		GEventBus.monster_breached.disconnect(_stats.on_monster_breached)
	if GEventBus.mission_phase_changed.is_connected(_on_phase_changed):
		GEventBus.mission_phase_changed.disconnect(_on_phase_changed)
	if GEventBus.hero_died.is_connected(_on_hero_died):
		GEventBus.hero_died.disconnect(_on_hero_died)
	if GEventBus.mission_launched.is_connected(_on_mission_launched):
		GEventBus.mission_launched.disconnect(_on_mission_launched)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _live and not _terminal_seen:
		_stats.tick(delta)


func _unhandled_input(event: InputEvent) -> void:
	if is_showing() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_sanctuary_pressed()


## Currently shown mode (NONE while hidden).
func get_mode() -> Mode:
	return _mode


## True while the overlay is visible.
func is_showing() -> bool:
	return _mode != Mode.NONE


## True while a delayed show is scheduled but has not fired.
func is_show_pending() -> bool:
	return _show_timer != null


## The run statistics owned by this screen.
func get_stats() -> MissionOutcomeStats:
	return _stats


## Entry for a terminal event; the first one of an attempt wins.
func _on_terminal_event(mode: Mode) -> void:
	if _terminal_seen or mode == Mode.NONE:
		return
	_terminal_seen = true
	var delay: float = _defeat_delay if mode == Mode.DEFEAT else _victory_delay
	if delay <= 0.0:
		_show(mode)
		return
	_show_callback = _show.bind(mode)
	_show_timer = get_tree().create_timer(delay, true)
	_show_timer.timeout.connect(_show_callback)


func _on_phase_changed(_previous: String, new_phase: String, _timestamp: float) -> void:
	if new_phase == PHASE_DEFEAT:
		_on_terminal_event(Mode.DEFEAT)
	elif new_phase == PHASE_MISSION_COMPLETE:
		_on_terminal_event(Mode.VICTORY)
	else:
		_reset_attempt_state()


func _on_hero_died() -> void:
	_on_terminal_event(Mode.DEFEAT)


func _on_mission_launched(_id: String, _modifiers: PackedStringArray, _tier: int) -> void:
	_stats.reset()
	_reset_attempt_state()
	_live = true


func _on_wave_started(wave_number: int, total_waves: int, difficulty: float) -> void:
	_live = true
	_stats.on_wave_started(wave_number, total_waves, difficulty)


func _on_retry_pressed() -> void:
	_hide()
	_terminal_seen = false
	# Stats and _live restart when mission_launched arrives from the retry seam.
	if _retry_action.is_valid():
		_retry_action.call()


func _on_sanctuary_pressed() -> void:
	if _sanctuary_action.is_valid():
		_sanctuary_action.call()


func _reset_attempt_state() -> void:
	_cancel_pending_show()
	_terminal_seen = false
	_hide()


func _cancel_pending_show() -> void:
	if _show_timer != null and _show_callback.is_valid() and _show_timer.timeout.is_connected(_show_callback):
		_show_timer.timeout.disconnect(_show_callback)
	_show_timer = null
	_show_callback = Callable()


func _hide() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
	_mode = Mode.NONE
	visible = false


func _show(mode: Mode) -> void:
	_show_timer = null
	_show_callback = Callable()
	_mode = mode
	_title_label.text = tr(title_key(mode))
	_waves_name.text = tr("OUTCOME_STAT_WAVES")
	_slain_name.text = tr("OUTCOME_STAT_SLAIN")
	_breaches_name.text = tr("OUTCOME_STAT_BREACHES")
	_time_name.text = tr("OUTCOME_STAT_TIME")
	_retry_button.text = tr("OUTCOME_BUTTON_RETRY")
	_sanctuary_button.text = tr("OUTCOME_BUTTON_SANCTUARY")
	_waves_value.text = "%d / %d" % [_stats.waves_cleared, _stats.total_waves]
	_slain_value.text = str(_stats.monsters_slain)
	_breaches_value.text = str(_stats.breaches)
	_time_value.text = MissionOutcomeStats.format_time(_stats.elapsed_seconds)
	var buttons: Array[StringName] = buttons_for(mode)
	_retry_button.visible = buttons.has(&"retry")
	_sanctuary_button.visible = buttons.has(&"sanctuary")
	visible = true
	if _retry_button.visible:
		_retry_button.grab_focus()
	else:
		_sanctuary_button.grab_focus()
	if ReduceMotion.enabled():
		_root.modulate.a = 1.0
	else:
		_root.modulate.a = 0.0
		_fade_tween = create_tween()
		_fade_tween.tween_property(_root, "modulate:a", 1.0, FADE_SECONDS)
