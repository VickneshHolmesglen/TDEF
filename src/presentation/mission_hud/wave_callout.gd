class_name WaveCallout
extends Control

## Center-screen ceremony for the mission's big beats: "Wave 3 / of 5", "Final Wave",
## "Wave Cleared", a boss's arrival, and the mission's first breach. Before this the only signal a wave had started or
## ended was a small label changing in the corner status card.
##
## Pure presentation: subscribes to EventBus itself, owns no gameplay state, never takes
## input (MOUSE_FILTER_IGNORE on the whole subtree). Mounted by MissionHud._ready() so every
## mission scene gets it without a .tscn edit. Callouts queue rather than overwrite, so a
## boss spawning a moment after "Wave 5" still gets its own beat.
##
## Honors ReduceMotion: with reduced motion on, callouts fade in/out with no slide or scale.
##
## Usage: `var callout := WaveCallout.new(); hud.add_child(callout)`

const HOLD_SECONDS: float = 1.5
const IN_SECONDS: float = 0.22
const OUT_SECONDS: float = 0.35
const SLIDE_PX: float = 48.0
const RIBBON_HEIGHT: float = 116.0
## Vertical center of the ribbon as a fraction of the screen -- above the middle, so it
## reads as a headline and does not sit on top of the hero/path action in the map's center.
const RIBBON_CENTER_Y: float = 0.36
const TITLE_FONT_SIZE: int = 52
const SUBTITLE_FONT_SIZE: int = 20
const BOSS_TIER: int = 2  ## MonsterResource.tier: 0=STANDARD 1=ELITE 2=BOSS

var _queue: Array[Dictionary] = []
var _showing: bool = false
var _tween: Tween = null
var _total_waves: int = 0
var _terminal: bool = false
## Only the first breach of a mission attempt gets a callout: breaches can come
## several per wave, and a banner for each would drown out every other beat (the
## HUD's breach counter pulse and edge flash still mark each one). Reset on SCOUT,
## so a Retry warns again.
var _breach_announced: bool = false

var _ribbon: TextureRect
var _rule_top: ColorRect
var _rule_bottom: ColorRect
var _content: VBoxContainer
var _title: Label
var _subtitle: Label


func _ready() -> void:
	name = &"WaveCallout"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_build()
	visible = false
	GEventBus.wave_started.connect(_on_wave_started)
	GEventBus.wave_completed.connect(_on_wave_completed)
	GEventBus.monster_spawned.connect(_on_monster_spawned)
	GEventBus.monster_breached.connect(_on_monster_breached)
	GEventBus.mission_phase_changed.connect(_on_mission_phase_changed)


func _exit_tree() -> void:
	GEventBus.wave_started.disconnect(_on_wave_started)
	GEventBus.wave_completed.disconnect(_on_wave_completed)
	GEventBus.monster_spawned.disconnect(_on_monster_spawned)
	GEventBus.monster_breached.disconnect(_on_monster_breached)
	GEventBus.mission_phase_changed.disconnect(_on_mission_phase_changed)


## Queues a callout. `accent` tints the subtitle and rules (gold for routine beats, warning
## orange for the final wave / a boss). Public so other HUD code can reuse the ceremony.
func show_callout(title: String, subtitle: String, accent: Color = ShellChromeStyle.UI_ACCENT) -> void:
	if _terminal:
		return
	_queue.append({"title": title, "subtitle": subtitle, "accent": accent})
	if not _showing:
		_play_next()


## Test/inspection accessor: callouts waiting behind the one on screen.
func get_queued_count() -> int:
	return _queue.size()


func _build() -> void:
	_ribbon = TextureRect.new()
	_ribbon.name = &"Ribbon"
	_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ribbon.stretch_mode = TextureRect.STRETCH_SCALE
	_ribbon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ribbon.texture = _edge_fade_texture(Color(0.04, 0.05, 0.09, 0.82))
	add_child(_ribbon)

	_rule_top = _make_rule(&"RuleTop")
	_rule_bottom = _make_rule(&"RuleBottom")

	_content = VBoxContainer.new()
	_content.name = &"Content"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 0)
	add_child(_content)

	_title = Label.new()
	_title.name = &"Title"
	_title.theme_type_variation = &"TitleLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_title.add_theme_constant_override("shadow_offset_y", 3)
	_content.add_child(_title)

	_subtitle = Label.new()
	_subtitle.name = &"Subtitle"
	_subtitle.theme_type_variation = &"HeaderLabel"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", SUBTITLE_FONT_SIZE)
	_content.add_child(_subtitle)

	resized.connect(_layout)
	_layout()


func _make_rule(rule_name: StringName) -> ColorRect:
	var rule := ColorRect.new()
	rule.name = rule_name
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)
	return rule


## A horizontal strip that is opaque in the middle and fades to nothing at both ends, so the
## ribbon reads as a band of shadow across the battlefield rather than a hard-edged box.
static func _edge_fade_texture(core: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.28, 0.72, 1.0])
	var clear := Color(core.r, core.g, core.b, 0.0)
	gradient.colors = PackedColorArray([clear, core, core, clear])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 1
	return texture


func _layout() -> void:
	var center_y: float = size.y * RIBBON_CENTER_Y
	var top: float = center_y - RIBBON_HEIGHT * 0.5
	_ribbon.position = Vector2(0.0, top)
	_ribbon.size = Vector2(size.x, RIBBON_HEIGHT)
	_rule_top.position = Vector2(size.x * 0.22, top)
	_rule_top.size = Vector2(size.x * 0.56, 2.0)
	_rule_bottom.position = Vector2(size.x * 0.22, top + RIBBON_HEIGHT - 2.0)
	_rule_bottom.size = Vector2(size.x * 0.56, 2.0)
	_content.position = Vector2(0.0, top)
	_content.size = Vector2(size.x, RIBBON_HEIGHT)
	_content.pivot_offset = _content.size * 0.5


func _play_next() -> void:
	if _queue.is_empty():
		_showing = false
		visible = false
		return
	_showing = true
	var entry: Dictionary = _queue.pop_front()
	var accent: Color = entry["accent"]
	_title.text = entry["title"]
	_subtitle.text = entry["subtitle"]
	_subtitle.visible = not String(entry["subtitle"]).is_empty()
	_subtitle.add_theme_color_override("font_color", accent)
	_rule_top.color = accent
	_rule_bottom.color = accent
	visible = true
	_layout()

	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	_tween = create_tween()
	if ReduceMotion.enabled():
		_content.position.x = 0.0
		_content.scale = Vector2.ONE
		_ribbon.scale = Vector2.ONE
		_tween.tween_property(self, "modulate:a", 1.0, IN_SECONDS)
		_tween.tween_interval(HOLD_SECONDS)
		_tween.tween_property(self, "modulate:a", 0.0, OUT_SECONDS)
	else:
		# Ribbon unfolds vertically from its center line while the text slides in from the
		# right and settles; on the way out the text keeps travelling left, so the whole beat
		# reads as one motion passing across the screen.
		_ribbon.pivot_offset = Vector2(size.x * 0.5, RIBBON_HEIGHT * 0.5)
		_ribbon.scale = Vector2(1.0, 0.0)
		_content.position.x = SLIDE_PX
		_content.scale = Vector2(1.08, 1.08)
		_tween.set_parallel(true)
		_tween.tween_property(self, "modulate:a", 1.0, IN_SECONDS)
		_tween.tween_property(_ribbon, "scale:y", 1.0, IN_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_content, "position:x", 0.0, IN_SECONDS * 1.6) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_content, "scale", Vector2.ONE, IN_SECONDS * 1.6) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.set_parallel(false)
		_tween.tween_interval(HOLD_SECONDS)
		_tween.set_parallel(true)
		_tween.tween_property(self, "modulate:a", 0.0, OUT_SECONDS)
		_tween.tween_property(_content, "position:x", -SLIDE_PX, OUT_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_tween.set_parallel(false)
	_tween.tween_callback(_play_next)


func _clear() -> void:
	_queue.clear()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_showing = false
	visible = false


func _on_wave_started(wave_number: int, total_waves: int, _wave_difficulty: float) -> void:
	_total_waves = total_waves
	if wave_number >= total_waves and total_waves > 1:
		show_callout(tr("HUD_CALLOUT_FINAL_WAVE"), tr("HUD_CALLOUT_WAVE_OF") % [wave_number, total_waves], ShellChromeStyle.UI_WARNING_ORANGE)
	else:
		show_callout(tr("HUD_CALLOUT_WAVE") % wave_number, tr("HUD_CALLOUT_OF_TOTAL") % total_waves)


## The final wave's clear is the MissionOutcomeScreen's moment, not this one's.
func _on_wave_completed(wave_number: int, _enemies_remaining: int, _was_boss_breached: bool) -> void:
	if _total_waves > 0 and wave_number >= _total_waves:
		return
	show_callout(tr("HUD_CALLOUT_WAVE_CLEARED"), tr("HUD_CALLOUT_FORTIFY"))


func _on_monster_breached(_entity_id: int, _monster_id: StringName, _tier: int) -> void:
	if _breach_announced or _terminal:
		return
	_breach_announced = true
	show_callout(tr("HUD_CALLOUT_BREACH"), tr("HUD_CALLOUT_BREACH_SUBTITLE"), ShellChromeStyle.UI_WARNING_ORANGE)


func _on_monster_spawned(payload: MonsterSpawnedEvent) -> void:
	var resource: MonsterResource = GGameDataRegistry.get_monster_resource(payload.monster_id)
	if resource == null or resource.tier != BOSS_TIER:
		return
	show_callout(resource.display_name, tr("HUD_CALLOUT_BOSS"), ShellChromeStyle.UI_WARNING_ORANGE)


func _on_mission_phase_changed(_previous_phase: String, new_phase: String, _timestamp: float) -> void:
	match new_phase:
		"SCOUT":
			_terminal = false
			_breach_announced = false
			_total_waves = 0
			_clear()
		"MISSION_COMPLETE", "DEFEAT":
			_terminal = true
			_clear()
