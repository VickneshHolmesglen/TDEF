class_name MainMenuAmbience
extends Node

## Ambient life for the Main Menu (2026-10-25 AAA UI pass). The painted backdrop
## used to be a still image under still buttons; this adds:
##   * a slow Ken Burns drift on the painting (scale + slight pan, ping-pong)
##   * pixel-styled fireflies drifting up through the valley (PixelVfx, so they
##     match the in-mission particle style)
##   * an entrance: the title settles in from above, then the buttons fade and
##     slide in one after another
##
## Pure presentation: touches only modulate/position/scale of the nodes it is
## handed and adds one particle emitter under the backdrop (so the fireflies
## draw above the painting and below the title and buttons). Honors
## ReduceMotion: with reduced motion on, nothing moves and no particles spawn.
##
## Usage (from MainMenu._ready()):
##   var ambience := MainMenuAmbience.new()
##   add_child(ambience)
##   ambience.setup($Background, $TitleLabel, $Buttons)

const DRIFT_SECONDS: float = 26.0
const DRIFT_SCALE: float = 1.045
const DRIFT_PAN: Vector2 = Vector2(-14.0, -6.0)
const TITLE_DROP_PX: float = 18.0
const TITLE_IN_SECONDS: float = 0.7
const BUTTON_SLIDE_PX: float = 36.0
const BUTTON_IN_SECONDS: float = 0.35
const BUTTON_STAGGER_SECONDS: float = 0.07
const FIREFLY_COLOR: Color = Color(1.0, 0.95, 0.6, 1.0)


## Starts everything. Safe to call once; does nothing under ReduceMotion.
func setup(backdrop: Control, title: Control, buttons: Container) -> void:
	if ReduceMotion.enabled():
		return
	_start_drift(backdrop)
	_add_fireflies(backdrop)
	_play_entrance(title, buttons)


## The pivot must stay centered: scaling about the center grows the painting
## past every edge by more than DRIFT_PAN, so the pan never opens a gap. The
## backdrop is full-rect, and its size may not be laid out yet in _ready(), so
## the viewport size stands in and resizes keep the pivot current.
func _start_drift(backdrop: Control) -> void:
	backdrop.pivot_offset = backdrop.get_viewport_rect().size * 0.5
	backdrop.resized.connect(func() -> void: backdrop.pivot_offset = backdrop.size * 0.5)
	var rest: Vector2 = backdrop.position
	var drift: Tween = backdrop.create_tween().set_loops()
	drift.set_parallel(true)
	drift.tween_property(backdrop, "scale", Vector2.ONE * DRIFT_SCALE, DRIFT_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.tween_property(backdrop, "position", rest + DRIFT_PAN, DRIFT_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.chain().tween_property(backdrop, "scale", Vector2.ONE, DRIFT_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.parallel().tween_property(backdrop, "position", rest, DRIFT_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _add_fireflies(backdrop: Control) -> void:
	var area: Vector2 = backdrop.get_viewport_rect().size
	var flies := CPUParticles2D.new()
	flies.name = "Fireflies"
	flies.amount = 34
	flies.lifetime = 7.0
	flies.preprocess = 7.0  # already in the air on the first frame
	flies.position = Vector2(area.x * 0.62, area.y * 0.72)
	flies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flies.emission_rect_extents = Vector2(area.x * 0.4, area.y * 0.22)
	flies.direction = Vector2(0.2, -1.0)
	flies.spread = 35.0
	flies.gravity = Vector2(0.0, -4.0)
	flies.initial_velocity_min = 6.0
	flies.initial_velocity_max = 18.0
	flies.scale_amount_min = 3.0
	flies.scale_amount_max = 6.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(FIREFLY_COLOR, 0.0))
	ramp.set_color(1, Color(FIREFLY_COLOR, 0.0))
	ramp.add_point(0.25, FIREFLY_COLOR)
	ramp.add_point(0.7, Color(FIREFLY_COLOR, 0.6))
	flies.color_ramp = ramp
	PixelVfx.style_particles(flies)
	# style_particles() replaces the ramp with a start->end stepped fade; keep
	# its stepped look but fade in as well as out, so flies don't pop on.
	flies.color_ramp = _stepped_in_out(FIREFLY_COLOR)
	backdrop.add_child(flies)


## Hard-banded ramp: clear -> dim -> full -> dim -> clear.
static func _stepped_in_out(color: Color) -> Gradient:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.12, 0.3, 0.75, 0.9])
	g.colors = PackedColorArray([Color(color, 0.0), Color(color, 0.4), color, Color(color, 0.4), Color(color, 0.0)])
	return g


func _play_entrance(title: Control, buttons: Container) -> void:
	var title_rest: float = title.position.y
	title.modulate.a = 0.0
	title.position.y = title_rest - TITLE_DROP_PX
	var title_in: Tween = title.create_tween().set_parallel(true)
	title_in.tween_property(title, "modulate:a", 1.0, TITLE_IN_SECONDS)
	title_in.tween_property(title, "position:y", title_rest, TITLE_IN_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Only buttons visible now take part; a hidden one (Continue with no save)
	# must not be left at alpha 0 in case it is shown later.
	var entering: Array[Control] = []
	for child: Node in buttons.get_children():
		if child is Control and (child as Control).visible:
			entering.append(child as Control)
			(child as Control).modulate.a = 0.0
	# Wait one frame so the container has laid its children out before their
	# positions are read as the slide-in rest points.
	await get_tree().process_frame
	var delay: float = TITLE_IN_SECONDS * 0.4
	for button: Control in entering:
		if not is_instance_valid(button):
			continue
		var rest_x: float = button.position.x
		button.position.x = rest_x - BUTTON_SLIDE_PX
		var slide: Tween = button.create_tween().set_parallel(true)
		slide.tween_property(button, "modulate:a", 1.0, BUTTON_IN_SECONDS).set_delay(delay)
		slide.tween_property(button, "position:x", rest_x, BUTTON_IN_SECONDS).set_delay(delay) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		delay += BUTTON_STAGGER_SECONDS
