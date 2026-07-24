extends Node2D

## No class_name declared here: this script is only ever referenced via its
## $GridVisual node path from the_gap.gd (untyped @onready var) — a fresh
## class_name would need a project class-cache rescan to resolve in a purely
## headless run (confirmed via a real failing run during this story's own
## verification pass), which is an avoidable fragility for a single-consumer
## script. Not needed for correctness either way.

## Purely visual grid rendering for "The Gap" mission scene (S4-09).
##
## Deliberately NOT a TileMap/TileSet node. docs/engine-reference/godot/VERSION.md
## flags Godot 4.4-4.6 TileMap/TileSet API changes as a knowledge-gap risk for
## this LLM's training data — since this is purely cosmetic (Grid/GridConfig
## remain the sole gameplay-logic authority regardless of how cells are drawn;
## see grid.gd's own class doc comment), a simple renderer avoids that risk
## entirely at zero gameplay cost.
##
## TD-render-001 fix (2026-07-07): the original implementation called
## draw_rect() twice per cell inside _draw() (fill + outline) — for a 16x12
## grid that's 384 draw_rect() calls, re-issued every redraw. Live measurement
## via the Godot MCP bridge found this alone accounted for ~387 of the game's
## total per-frame draw calls, ~1.9x over the 200 draw-call budget in
## .claude/docs/technical-preferences.md — and it was flat regardless of
## monster count, since the grid never changes after configure(). Fixed by
## rendering the grid ONCE into an Image at configure() time (the grid is
## genuinely static per-mission — GridConfig never changes after mission
## launch) and displaying it via a single draw_texture() call. This is a CPU
## Image write, not a GPU draw call, so cell count no longer costs anything
## per frame — total cost drops from 384 draw calls to 1, regardless of grid
## size. The Image-based border blend approximates the original alpha=0.25
## black outline by pre-blending it into solid border pixel colors (Image
## pixels are opaque final values, not alpha-composited at render time the
## way _draw()'s draw_rect() was).
##
## Populated once from the same GridConfig the_gap.gd builds and passes to
## GGrid.initialize() — this script never reads GGrid itself, so there is no
## risk of this visual layer silently drifting from, or being mistaken for,
## the authoritative Grid data store.

var cols: int = 0
var rows: int = 0
var cell_size: float = 64.0
var cells: Dictionary = {}  # Vector2i -> Grid.CellType (int)

const COLOR_BY_TYPE := {
	0: Color(0.55, 0.55, 0.55),   # PLACEABLE
	1: Color(0.75, 0.65, 0.35),   # PATH
	2: Color(0.2, 0.8, 0.2),      # SPAWN
	3: Color(0.9, 0.2, 0.2),      # GOAL
	4: Color(0.15, 0.15, 0.15),   # BLOCKED
}

const OUTLINE_ALPHA: float = 0.25  ## matches the original draw_rect() outline alpha
const OUTLINE_WIDTH_PX: int = 1

var _texture: ImageTexture = null


func configure(p_cols: int, p_rows: int, p_cell_size: float, p_cells: Dictionary) -> void:
	cols = p_cols
	rows = p_rows
	cell_size = p_cell_size
	cells = p_cells
	_texture = _build_grid_texture()
	queue_redraw()


## Renders the full grid into a single Image once. Border pixels use a
## pre-blended color (base color lerped toward black by OUTLINE_ALPHA) to
## visually approximate the original per-cell alpha-composited outline,
## since Image.fill_rect() writes opaque final pixel values rather than
## alpha-compositing against whatever's beneath it.
func _build_grid_texture() -> ImageTexture:
	var px_width: int = int(cols * cell_size)
	var px_height: int = int(rows * cell_size)
	var image := Image.create(px_width, px_height, false, Image.FORMAT_RGBA8)
	var cell_px: int = int(cell_size)
	for row: int in range(rows):
		for col: int in range(cols):
			var cell := Vector2i(col, row)
			var cell_type: int = cells.get(cell, 4)  # BLOCKED default, matches Grid.get_cell_type()
			var color: Color = COLOR_BY_TYPE.get(cell_type, Color.MAGENTA)
			var outline_color: Color = color.lerp(Color.BLACK, OUTLINE_ALPHA)
			var origin_x: int = col * cell_px
			var origin_y: int = row * cell_px
			image.fill_rect(Rect2i(origin_x, origin_y, cell_px, cell_px), color)
			# Four thin border strips approximate the original 1px outline.
			image.fill_rect(Rect2i(origin_x, origin_y, cell_px, OUTLINE_WIDTH_PX), outline_color)
			image.fill_rect(Rect2i(origin_x, origin_y + cell_px - OUTLINE_WIDTH_PX, cell_px, OUTLINE_WIDTH_PX), outline_color)
			image.fill_rect(Rect2i(origin_x, origin_y, OUTLINE_WIDTH_PX, cell_px), outline_color)
			image.fill_rect(Rect2i(origin_x + cell_px - OUTLINE_WIDTH_PX, origin_y, OUTLINE_WIDTH_PX, cell_px), outline_color)
	return ImageTexture.create_from_image(image)


func _draw() -> void:
	if _texture != null:
		draw_texture(_texture, Vector2.ZERO)
