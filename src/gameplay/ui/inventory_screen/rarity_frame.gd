class_name RarityFrame
extends Control

## Shape-first, color-second rarity frame around an Inventory slot's icon
## (design/quick-specs/inventory-slot-icons-2026-08-06.md), reusing
## crafting.md's own already-established convention rather than inventing a
## new one: circle=Common/Fieldstone-Grey, hexagon=Uncommon/Scout-Blue,
## diamond=Rare/Herald-Gold. Outline only, never filled, so the icon/text
## underneath a slot stays fully visible. Frame shape is the primary rarity
## signal (colorblind-safe on its own); border color is confirmatory only.
##
## No art asset needed -- drawn procedurally via _draw(), so this renders
## correctly even for the 13 materials that have real rarity data today but
## no icon art yet (Phase 3, still to come).

const FIELDSTONE_GREY: Color = Color(0x7E / 255.0, 0x85 / 255.0, 0x90 / 255.0)
const SCOUT_BLUE: Color = Color(0x2D / 255.0, 0x5F / 255.0, 0x8A / 255.0)
const HERALD_GOLD: Color = Color(0xF5 / 255.0, 0xC0 / 255.0, 0x1A / 255.0)

const LINE_WIDTH: float = 2.0
const MARGIN: float = 2.0  ## inset from the slot's own edge so the frame doesn't clip

## "" | Common | Uncommon | Rare -- matches ItemDefinitionResource.rarity's
## own vocabulary exactly. "" draws nothing (no rarity data, e.g. Equipment/
## TowerComponent/CraftedGood today).
var rarity: String = "":
	set(value):
		rarity = value
		queue_redraw()


func _draw() -> void:
	match rarity:
		"Common":
			_draw_circle_outline(FIELDSTONE_GREY)
		"Uncommon":
			_draw_hexagon_outline(SCOUT_BLUE)
		"Rare":
			_draw_diamond_outline(HERALD_GOLD)
		_:
			pass


func _draw_circle_outline(color: Color) -> void:
	var center: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) / 2.0 - MARGIN
	draw_arc(center, radius, 0.0, TAU, 32, color, LINE_WIDTH, true)


func _draw_hexagon_outline(color: Color) -> void:
	draw_polyline(_regular_polygon_points(6, -PI / 2.0), color, LINE_WIDTH, true)


func _draw_diamond_outline(color: Color) -> void:
	draw_polyline(_regular_polygon_points(4, -PI / 2.0), color, LINE_WIDTH, true)


## Points for a regular polygon inscribed within this Control's bounds,
## starting at start_angle and proceeding clockwise, with the first point
## repeated at the end so draw_polyline() closes the shape.
func _regular_polygon_points(sides: int, start_angle: float) -> PackedVector2Array:
	var center: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) / 2.0 - MARGIN
	var points := PackedVector2Array()
	for i: int in range(sides + 1):
		var angle: float = start_angle + TAU * float(i % sides) / float(sides)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
