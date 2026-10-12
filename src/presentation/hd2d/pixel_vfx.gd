class_name PixelVfx
extends RefCounted

## Pixel-art styling for 2D VFX (ADR-0042, HD-2D effects pass 2026-10-12).
##
## The scenery and every unit sprite are pixel art at about PIXEL map px per
## pixel; smooth effects (anti-aliased arcs, rotating sub-pixel sparks, soft
## alpha fades) read as a different art style on top of them. These helpers
## restyle an effect in place without changing what it does:
##   * particles: square, unrotated, sized in whole pixels, colour/alpha fade
##     in a few hard steps, motion updated at a low fixed rate (no smoothing)
##   * rings: drawn as pixel blocks on the PIXEL grid
##   * trails: hard-edged lines whose width is a whole number of pixels

## Map px per art pixel -- matches the scenery ground and the sprite pass.
const PIXEL: float = 3.0
## Particle motion update rate; low and un-interpolated = visibly stepped.
const PARTICLE_FPS: int = 20
## Alpha steps of the fade ramp (1.0 -> 0.0 in this many hard bands).
const FADE_STEPS: int = 4


## Square, whole-pixel, stepped-fade particles. Call after the emitter's own
## setup (it reads the existing colour/ramp and size range).
static func style_particles(p: CPUParticles2D) -> void:
	p.angle_min = 0.0
	p.angle_max = 0.0
	p.angular_velocity_min = 0.0
	p.angular_velocity_max = 0.0
	p.scale_amount_min = maxf(snappedf(p.scale_amount_min, PIXEL), PIXEL)
	p.scale_amount_max = maxf(snappedf(p.scale_amount_max, PIXEL), p.scale_amount_min)
	p.fixed_fps = PARTICLE_FPS
	p.fract_delta = false
	var start: Color = p.color
	var end: Color = Color(start, 0.0)
	if p.color_ramp != null and p.color_ramp.get_point_count() >= 2:
		start = p.color_ramp.get_color(0)
		end = p.color_ramp.get_color(p.color_ramp.get_point_count() - 1)
	p.color_ramp = stepped_ramp(start, end)


## A Gradient that holds `start` then jumps through FADE_STEPS - 1 hard bands
## to `end` (constant interpolation: no smooth blend between bands).
static func stepped_ramp(start: Color, end: Color) -> Gradient:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array()
	g.colors = PackedColorArray()
	for i in FADE_STEPS:
		var t: float = float(i) / float(FADE_STEPS)
		g.add_point(t, start.lerp(end, t))
	return g


## Ring of PIXEL-sized blocks on the PIXEL grid around `centre` (local space
## of `ci`). `width` is rounded to whole pixels.
static func draw_pixel_ring(ci: CanvasItem, centre: Vector2, radius: float, width: float, color: Color) -> void:
	if radius <= 0.0 or color.a <= 0.0:
		return
	var rows: int = maxi(1, roundi(width / PIXEL))
	var seen: Dictionary = {}
	for row in rows:
		var r: float = radius + (float(row) - float(rows - 1) * 0.5) * PIXEL
		if r <= 0.0:
			continue
		var steps: int = maxi(8, ceili(TAU * r / PIXEL))
		for i in steps:
			var a: float = TAU * float(i) / float(steps)
			var cell := Vector2i(floori((centre.x + cos(a) * r) / PIXEL), floori((centre.y + sin(a) * r) / PIXEL))
			if seen.has(cell):
				continue
			seen[cell] = true
			ci.draw_rect(Rect2(Vector2(cell) * PIXEL, Vector2(PIXEL, PIXEL)), color, true)


## Hard-edged trail: no anti-aliasing, square joints/caps, width in whole pixels.
static func style_line(line: Line2D) -> void:
	line.antialiased = false
	line.joint_mode = Line2D.LINE_JOINT_SHARP
	line.begin_cap_mode = Line2D.LINE_CAP_NONE
	line.end_cap_mode = Line2D.LINE_CAP_NONE
	line.width = maxf(snappedf(line.width, PIXEL), PIXEL)
