class_name GroundShadow
extends Node2D

## Soft contact shadow under a 2D unit (ADR-0042 unit pass, 2026-10-12).
##
## The HD-2D scenery is lit and shadowed in 3D, but heroes, monsters and
## towers are 2D sprites drawn on top of it, so without this they float. Two
## stacked ellipses (dark core, faint rim) sit at the sprite's feet, nudged
## toward the lower right to agree with the scenery sun (upper-left). Drawn
## behind the host's sprite via a relative z_index of -1.

const CORE_COLOR := Color(0.0, 0.0, 0.0, 0.34)
const RIM_COLOR := Color(0.0, 0.0, 0.0, 0.14)
## Shadow height as a fraction of its width (the ground is seen at ~50 deg).
const FLATTEN: float = 0.36
## Offset away from the scenery sun, as a fraction of the shadow width.
const SUN_OFFSET := Vector2(0.12, 0.04)
const SEGMENTS: int = 20

var _half_width: float = 12.0


## Adds (or resizes) the shadow under `host`. `width` is the shadow's full
## width in 2D px; `foot_y` is the sprite's bottom edge relative to `host`.
static func attach(host: Node2D, width: float, foot_y: float) -> GroundShadow:
	var shadow: GroundShadow = host.get_node_or_null(^"GroundShadow") as GroundShadow
	if shadow == null:
		shadow = GroundShadow.new()
		shadow.name = "GroundShadow"
		shadow.z_index = -1
		host.add_child(shadow)
	shadow.set_size(width, foot_y)
	return shadow


## Resizes in place: full `width` in px, centred `foot_y` px below the host.
func set_size(width: float, foot_y: float) -> void:
	_half_width = maxf(width * 0.5, 2.0)
	position = Vector2(_half_width * 2.0 * SUN_OFFSET.x, foot_y + _half_width * 2.0 * SUN_OFFSET.y)
	queue_redraw()


func _draw() -> void:
	draw_on(self, Vector2.ZERO, _half_width)


## Draws the same shadow onto any CanvasItem from its own _draw(), for hosts
## that are not Node2Ds (the Sanctuary's TownBuildingView buttons). `centre`
## is the shadow centre in `ci`'s local coords, sun offset not applied.
static func draw_on(ci: CanvasItem, centre: Vector2, half_width: float) -> void:
	_draw_ellipse(ci, centre, Vector2(half_width * 1.25, half_width * 1.25 * FLATTEN), RIM_COLOR)
	_draw_ellipse(ci, centre, Vector2(half_width, half_width * FLATTEN), CORE_COLOR)


static func _draw_ellipse(ci: CanvasItem, centre: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in SEGMENTS:
		var a: float = TAU * float(i) / float(SEGMENTS)
		pts.append(centre + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	ci.draw_colored_polygon(pts, color)
