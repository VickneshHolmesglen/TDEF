class_name PixelLockGlyph
extends Control

## A small padlock drawn in hard-edged pixel blocks, for "locked" states (habitat
## slots, tech tiers, skills). Drawn rather than textured so it scales cleanly at any
## size and matches the HD-2D pixel UI without a new art asset.
##
## The glyph is a 10x12 grid of logical pixels scaled to fit the control, centered.
##
## Usage:
##   var lock := PixelLockGlyph.new()
##   lock.custom_minimum_size = Vector2(40, 48)
##   lock.color = Color(ShellChromeStyle.UI_PARCHMENT, 0.3)
##   parent.add_child(lock)

const GRID_W: int = 10
const GRID_H: int = 12

## Row strings, '#' = filled. Shackle on top, body with a keyhole below.
const PATTERN: PackedStringArray = [
	"..######..",
	".##....##.",
	".#......#.",
	".#......#.",
	".#......#.",
	"##########",
	"##########",
	"####..####",
	"####..####",
	"#####.####",
	"##########",
	"##########",
]

## Glyph color; the keyhole is left transparent.
@export var color: Color = Color(1, 1, 1, 0.3):
	set(value):
		color = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var cell: float = floorf(minf(size.x / GRID_W, size.y / GRID_H))
	if cell < 1.0:
		return
	var origin := ((size - Vector2(GRID_W, GRID_H) * cell) / 2.0).floor()
	for y: int in GRID_H:
		var row: String = PATTERN[y]
		for x: int in GRID_W:
			if row[x] == "#":
				draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), color)
