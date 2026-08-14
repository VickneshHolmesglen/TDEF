extends Node2D

## No class_name declared here: this script is only ever referenced via its
## $GridVisual node path from the_gap.gd (untyped @onready var) — a fresh
## class_name would need a project class-cache rescan to resolve in a purely
## headless run (confirmed via a real failing run during this story's own
## verification pass), which is an avoidable fragility for a single-consumer
## script. Not needed for correctness either way.

## Purely visual grid rendering, shared by every mission scene that owns a
## $GridVisual node (the_gap.tscn, MissionScene.tscn).
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
## size.
##
## Populated once from the same GridConfig the mission scene builds/loads and
## passes to GGrid.initialize() — this script never reads GGrid itself, so
## there is no risk of this visual layer silently drifting from, or being
## mistaken for, the authoritative Grid data store.

var cols: int = 0
var rows: int = 0
var cell_size: float = 64.0
var cells: Dictionary = {}  # Vector2i -> Grid.CellType (int)

## Real terrain art (2026-08-08, design/art/asset-generation-prompts.md's
## terrain batch) — replaces the original flat-solid-color placeholder fill.
## One shared tile per Grid.CellType, reused across every mission (per user's
## own scope decision at the time — not per-mission bespoke terrain). Source
## images are native ChatGPT-generation resolution (1254x1254) — resized
## once per configure() call to cell_px, never per-cell, per this project's
## own "always scale new art explicitly" lesson (design/art/asset-generation-
## prompts.md's own recurring-bug-class note).
##
## 2026-08-15 update in progress: player asked for per-mission environment
## flavour, reversing the "shared across every mission" decision above for
## Placeable/Path/Blocked (Spawn/Goal stay shared — see
## assets/art-generation-requests-2026-08-15-mission-terrain.md's own scope
## note). Not yet wired — the art for this doesn't exist yet; this file
## still renders the single shared set below until it does.
const TEXTURE_BY_TYPE := {
	0: preload("res://assets/art/terrain/placeable.png"),  # PLACEABLE
	1: preload("res://assets/art/terrain/path.png"),       # PATH
	2: preload("res://assets/art/terrain/spawn.png"),      # SPAWN
	3: preload("res://assets/art/terrain/goal.png"),       # GOAL
	4: preload("res://assets/art/terrain/blocked.png"),    # BLOCKED
}

## Cell-boundary outline width, kept from the flat-color-fill era — real
## terrain texture is visually busier than a flat fill, so a visible seam
## still matters for tower-placement readability (art bible 3.2's
## figure/ground discipline: "the terrain is too tall/busy" test).
const OUTLINE_COLOR: Color = Color(0.0, 0.0, 0.0)
const OUTLINE_WIDTH_PX: int = 1

var _texture: ImageTexture = null


func configure(p_cols: int, p_rows: int, p_cell_size: float, p_cells: Dictionary) -> void:
	cols = p_cols
	rows = p_rows
	cell_size = p_cell_size
	cells = p_cells
	_texture = _build_grid_texture()
	queue_redraw()


## Renders the full grid into a single Image once (TD-render-001's own
## established "one Image, not N draw_rect() calls" pattern — unchanged by
## the switch from flat color to real texture). Each of the 5 terrain
## textures is resized to cell_px exactly once up front, then blitted per
## cell — resizing per-cell (192 times on a 16x12 grid) would repeat the
## same expensive resize for no benefit, since every cell of a given type
## uses the identical scaled-down source.
func _build_grid_texture() -> ImageTexture:
	var px_width: int = int(cols * cell_size)
	var px_height: int = int(rows * cell_size)
	var image := Image.create(px_width, px_height, false, Image.FORMAT_RGB8)
	var cell_px: int = int(cell_size)

	var scaled_by_type: Dictionary = {}
	for cell_type: int in TEXTURE_BY_TYPE:
		var source_image: Image = (TEXTURE_BY_TYPE[cell_type] as Texture2D).get_image()
		source_image = source_image.duplicate()
		source_image.resize(cell_px, cell_px, Image.INTERPOLATE_LANCZOS)
		if source_image.get_format() != Image.FORMAT_RGB8:
			source_image.convert(Image.FORMAT_RGB8)
		scaled_by_type[cell_type] = source_image

	for row: int in range(rows):
		for col: int in range(cols):
			var cell := Vector2i(col, row)
			var cell_type: int = cells.get(cell, 4)  # BLOCKED default, matches Grid.get_cell_type()
			var tile: Image = scaled_by_type.get(cell_type, scaled_by_type[4])
			var origin_x: int = col * cell_px
			var origin_y: int = row * cell_px
			image.blit_rect(tile, Rect2i(0, 0, cell_px, cell_px), Vector2i(origin_x, origin_y))
			# Thin border strips keep cell boundaries readable against busy
			# real terrain texture — art bible 3.2's figure/ground discipline.
			image.fill_rect(Rect2i(origin_x, origin_y, cell_px, OUTLINE_WIDTH_PX), OUTLINE_COLOR)
			image.fill_rect(Rect2i(origin_x, origin_y + cell_px - OUTLINE_WIDTH_PX, cell_px, OUTLINE_WIDTH_PX), OUTLINE_COLOR)
			image.fill_rect(Rect2i(origin_x, origin_y, OUTLINE_WIDTH_PX, cell_px), OUTLINE_COLOR)
			image.fill_rect(Rect2i(origin_x + cell_px - OUTLINE_WIDTH_PX, origin_y, OUTLINE_WIDTH_PX, cell_px), OUTLINE_COLOR)
	return ImageTexture.create_from_image(image)


func _draw() -> void:
	if _texture != null:
		draw_texture(_texture, Vector2.ZERO)
