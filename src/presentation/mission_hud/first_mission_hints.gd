class_name FirstMissionHints
extends PanelContainer
## Short coaching card for a player's first mission: build, start the wave, use
## the hero, then what intermission is for. Each step is advanced by the real
## gameplay event it teaches, so a player who already knows moves past quickly.
##
## Shown once per install: completion is stored in UserDataPaths.root() +
## "tutorial.cfg" (a device preference like the audio and display settings, not
## save data). Pure presentation: subscribes to EventBus, owns no gameplay
## state, never takes input.
##
## Mounted by MissionHud._ready(). Honors ReduceMotion (fade only, no slide).

const SETTINGS_SECTION: String = "tutorial"
const SETTINGS_KEY: String = "first_mission_hints_done"
const CARD_WIDTH: float = 560.0
const BOTTOM_MARGIN: float = 24.0
## Horizontal room taken by the skin panel's content margins (both sides).
const CARD_PADDING: float = 40.0
const FADE_SECONDS: float = 0.25
const SLIDE_PX: float = 16.0
## Informational steps (nothing to do) retire after this many real seconds.
const INFO_HOLD_SECONDS: float = 9.0

enum Step { NONE, BUILD, READY, HERO, INTERMISSION, DONE }

static var SETTINGS_PATH: String = UserDataPaths.root() + "tutorial.cfg"

var _step: Step = Step.NONE
var _title: Label
var _body: Label
var _tween: Tween


static func is_completed() -> bool:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return false
	return config.get_value(SETTINGS_SECTION, SETTINGS_KEY, false)


static func mark_completed() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)  # a missing file is fine: start empty
	config.set_value(SETTINGS_SECTION, SETTINGS_KEY, true)
	config.save(SETTINGS_PATH)


## Clears the flag so the hints play again (tests, a future "replay tips" option).
static func reset_completed() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	config.set_value(SETTINGS_SECTION, SETTINGS_KEY, false)
	config.save(SETTINGS_PATH)


func _ready() -> void:
	name = "FirstMissionHints"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	add_theme_stylebox_override("panel", ShellChromeStyle.skin_panel(true))
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -CARD_WIDTH * 0.5
	offset_right = CARD_WIDTH * 0.5
	offset_top = -BOTTOM_MARGIN
	offset_bottom = -BOTTOM_MARGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	_title = Label.new()
	_title.uppercase = true
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", ShellChromeStyle.UI_ACCENT)
	box.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A wrapping Label measures its minimum height at its minimum width; without
	# a fixed width that is 0, every word wraps onto its own line and the card
	# grew to fill the screen (live-caught 2026-11-02).
	_body.custom_minimum_size = Vector2(CARD_WIDTH - CARD_PADDING, 0)
	_body.add_theme_font_size_override("font_size", 17)
	_body.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
	box.add_child(_body)

	if is_completed():
		_step = Step.DONE
		return
	GEventBus.mission_phase_changed.connect(_on_mission_phase_changed)
	GEventBus.tower_placed.connect(_on_tower_placed)
	GEventBus.wave_started.connect(_on_wave_started)
	GEventBus.wave_completed.connect(_on_wave_completed)


func _exit_tree() -> void:
	if GEventBus.mission_phase_changed.is_connected(_on_mission_phase_changed):
		GEventBus.mission_phase_changed.disconnect(_on_mission_phase_changed)
	if GEventBus.tower_placed.is_connected(_on_tower_placed):
		GEventBus.tower_placed.disconnect(_on_tower_placed)
	if GEventBus.wave_started.is_connected(_on_wave_started):
		GEventBus.wave_started.disconnect(_on_wave_started)
	if GEventBus.wave_completed.is_connected(_on_wave_completed):
		GEventBus.wave_completed.disconnect(_on_wave_completed)


func get_step() -> Step:
	return _step


func _on_mission_phase_changed(_previous_phase: String, new_phase: String, _timestamp: float) -> void:
	match new_phase:
		"SCOUT":
			if _step == Step.NONE:
				_show(Step.BUILD)
		"MISSION_COMPLETE", "DEFEAT":
			_finish()


func _on_tower_placed(_payload: TowerPlacedEvent) -> void:
	if _step == Step.BUILD:
		_show(Step.READY)


func _on_wave_started(wave_number: int, _total_waves: int, _difficulty: float) -> void:
	if wave_number == 1 and _step in [Step.NONE, Step.BUILD, Step.READY]:
		_show(Step.HERO)
		_retire_after_hold()


func _on_wave_completed(_wave_number: int, _enemies_remaining: int, _was_boss_breached: bool) -> void:
	if _step == Step.HERO:
		_show(Step.INTERMISSION)
		_retire_after_hold()


func _show(step: Step) -> void:
	_step = step
	var keys: Array[StringName] = keys_for(step)
	_title.text = tr(keys[0])
	_body.text = tr(keys[1])
	_animate_in()


static func keys_for(step: Step) -> Array[StringName]:
	match step:
		Step.BUILD:
			return [&"HINT_BUILD_TITLE", &"HINT_BUILD_BODY"]
		Step.READY:
			return [&"HINT_READY_TITLE", &"HINT_READY_BODY"]
		Step.HERO:
			return [&"HINT_HERO_TITLE", &"HINT_HERO_BODY"]
		Step.INTERMISSION:
			return [&"HINT_INTERMISSION_TITLE", &"HINT_INTERMISSION_BODY"]
	return [&"", &""]


## Real-time hold (ignore_time_scale), so 3x speed does not rush the reading time.
func _retire_after_hold() -> void:
	var step_at_start: Step = _step
	var timer: SceneTreeTimer = get_tree().create_timer(INFO_HOLD_SECONDS, true, false, true)
	timer.timeout.connect(func() -> void:
		if _step != step_at_start:
			return
		if _step == Step.INTERMISSION:
			_finish()
		else:
			_animate_out())


func _finish() -> void:
	if _step == Step.DONE:
		return
	var was_shown: bool = _step != Step.NONE
	_step = Step.DONE
	if was_shown:
		mark_completed()
	_animate_out()


func _animate_in() -> void:
	_kill_tween()
	visible = true
	modulate.a = 0.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, FADE_SECONDS)
	if not ReduceMotion.enabled():
		var rest_y: float = position.y
		position.y = rest_y + SLIDE_PX
		_tween.tween_property(self, "position:y", rest_y, FADE_SECONDS) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _animate_out() -> void:
	if not visible:
		return
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(func() -> void: visible = false)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
