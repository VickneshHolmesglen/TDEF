class_name TownBuildingView
extends Button

## One Sanctuary town building in the OVERVIEW diorama (sanctuary town
## buildings spec, 2026-10-07, §4). Shows its current tier's art when the
## SanctuaryBuildingResource has a texture for it; otherwise draws a clearly-
## placeholder block whose height grows with the tier, a roof band, its name
## and 5 tier pips, so growth already reads before Codex art lands. Focusable
## (keyboard/gamepad) as well as clickable; the Diorama owns what a press does.
##
## Example:
##   var view := TownBuildingView.new()
##   view.setup(load("res://assets/data/sanctuary_buildings/armoury.tres"))
##   view.set_progress(0.45)  # tier 3

const ROOF_COLOR_DARKEN: float = 0.35
const PIP_RADIUS: float = 3.5
const PIP_GAP: float = 10.0
const MIN_HEIGHT_FRACTION: float = 0.55  ## tier 1 block height; tier 5 fills the footprint
const POP_SCALE: float = 1.12
const POP_SECONDS: float = 0.18

var building: SanctuaryBuildingResource = null
var tier: int = 1
var score: float = 0.0

var _art: TextureRect = null
var _name_label: Label = null
var _pop_tween: Tween = null


func setup(res: SanctuaryBuildingResource) -> void:
	building = res
	name = "Building_%s" % res.building_id
	flat = true
	focus_mode = Control.FOCUS_ALL
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())  # _draw() owns the focus highlight
	# Own scale pop on tier-up; keep the global hover/press scaling off it.
	set_meta(ButtonFeedbackBinder.META_KEY, ButtonFeedbackBinder.KIND_NONE)
	size = res.footprint
	custom_minimum_size = res.footprint
	position = res.position - Vector2(res.footprint.x * 0.5, res.footprint.y)
	pivot_offset = Vector2(res.footprint.x * 0.5, res.footprint.y)  # pops grow from the ground up
	if res.target_state == &"":
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	_art = TextureRect.new()
	_art.name = "Art"
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.text = tr(res.name_key)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.add_theme_color_override("font_color", ShellChromeStyle.UI_PARCHMENT)
	_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_name_label.add_theme_constant_override("outline_size", 4)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)
	_apply_tier_visual()


## Updates the score and tier (tier_for). Returns true when the tier rose.
func set_progress(new_score: float) -> bool:
	score = clampf(new_score, 0.0, 1.0)
	var new_tier: int = SanctuaryProgress.tier_for(score)
	var rose: bool = new_tier > tier
	tier = new_tier
	_apply_tier_visual()
	return rose


## True when the current tier shows real art rather than the placeholder.
func has_tier_art() -> bool:
	return building != null and building.tier_textures.size() >= tier and building.tier_textures[tier - 1] != null


## Height of the placeholder block for the current tier, in pixels.
func placeholder_height() -> float:
	var t: float = float(tier - 1) / float(SanctuaryProgress.TIER_COUNT - 1)
	return size.y * lerpf(MIN_HEIGHT_FRACTION, 1.0, t)


## Small scale pop (skipped under reduce-motion).
func play_tier_up() -> void:
	if ReduceMotion.enabled():
		return
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	scale = Vector2.ONE
	_pop_tween = create_tween()
	_pop_tween.tween_property(self, "scale", Vector2.ONE * POP_SCALE, POP_SECONDS * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_property(self, "scale", Vector2.ONE, POP_SECONDS * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _apply_tier_visual() -> void:
	if building == null:
		return
	_art.texture = building.tier_textures[tier - 1] if has_tier_art() else null
	_art.visible = _art.texture != null
	# Name sits just under the building's top so it never floats in empty air.
	var top: float = 0.0 if has_tier_art() else size.y - placeholder_height()
	_name_label.position = Vector2(0.0, top + 4.0)
	_name_label.size = Vector2(size.x, 18.0)
	queue_redraw()


func _draw() -> void:
	if building == null:
		return
	var focus_highlight: bool = has_focus() or is_hovered()
	if not has_tier_art():
		var h: float = placeholder_height()
		var w: float = size.x * 0.82
		var body := Rect2(Vector2((size.x - w) * 0.5, size.y - h), Vector2(w, h))
		draw_rect(body, building.placeholder_color)
		var roof := Rect2(body.position, Vector2(w, h * 0.18))
		draw_rect(roof, building.placeholder_color.darkened(ROOF_COLOR_DARKEN))
		draw_rect(body, Color(0, 0, 0, 0.6), false, 2.0)
		# Tier pips along the base: filled up to the current tier.
		var row_width: float = PIP_GAP * float(SanctuaryProgress.TIER_COUNT - 1)
		var origin := Vector2(size.x * 0.5 - row_width * 0.5, size.y - 9.0)
		for i: int in SanctuaryProgress.TIER_COUNT:
			var c := Vector2(origin.x + PIP_GAP * float(i), origin.y)
			if i < tier:
				draw_circle(c, PIP_RADIUS, Color(1.0, 0.85, 0.4))
			else:
				draw_arc(c, PIP_RADIUS, 0.0, TAU, 12, Color(1, 1, 1, 0.55), 1.0)
	if focus_highlight:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.9, 0.55, 0.9), false, 2.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT \
			or what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT:
		queue_redraw()
