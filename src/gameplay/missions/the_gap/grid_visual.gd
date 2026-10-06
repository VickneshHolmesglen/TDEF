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

## Epic 15 Story 002 (ADR-0037, Visual Presentation 3D Companion Layer): the
## entity_or_component_id every grid tile resolves its 3D mesh through, via
## GGameDataRegistry.get_visual_mesh_mapping(). A single shared id for every
## cell regardless of Grid.CellType — the story's own QA Test Cases describe
## this as "the tile type" (singular): this story proves the pipeline with one
## uniform ground-plane mesh per cell, not a per-CellType mesh set (a future
## content-authoring concern, out of this story's scope).
const TILE_MESH_ENTITY_ID: StringName = &"tile_straight"

## Y-height for ground/tile visuals per ADR-0037's layer_height table
## ("ground/tile = 0" — the ground plane itself, never read by gameplay logic).
const TILE_LAYER_HEIGHT: float = 0.0

## Node3D visual-companion subtree (ADR-0037's Visual Companion pattern)
## holding one MeshInstance3D per grid tile. Built once by
## _build_visual_companion(), called from configure() — grid tiles are static
## once placed (Story 002's Implementation Notes: "tiles are static... never
## touch it again per-frame"), so unlike moving-entity companions (Stories
## 003-006) this needs no per-frame sync step. A Node3D child of this Node2D
## does NOT inherit this node's 2D transform (Node2D/Node3D are separate
## transform hierarchies in Godot — ADR-0037's "Important engine
## clarification"); VisualMath.map_to_3d()'s output is assigned directly as
## each tile's absolute world position, never offset against anything.
var _visual_companion: Node3D = null

## Real terrain art (2026-08-08, design/art/asset-generation-prompts.md's
## terrain batch) — replaces the original flat-solid-color placeholder fill.
## Fallback set: used for SPAWN/GOAL always (universal landmarks, not
## biome-specific — see the per-mission note below) and for
## PLACEABLE/PATH/BLOCKED on any mission absent from
## TEXTURE_BY_TYPE_BY_MISSION (graceful degradation, matches this project's
## "content can lag code" tolerance). Source images are native
## ChatGPT-generation resolution — resized once per configure() call to
## cell_px, never per-cell, per this project's own "always scale new art
## explicitly" lesson (design/art/asset-generation-prompts.md's own
## recurring-bug-class note).
const TEXTURE_BY_TYPE := {
	0: preload("res://assets/art/terrain/placeable.png"),  # PLACEABLE
	1: preload("res://assets/art/terrain/path.png"),       # PATH
	2: preload("res://assets/art/terrain/spawn.png"),      # SPAWN
	3: preload("res://assets/art/terrain/goal.png"),       # GOAL
	4: preload("res://assets/art/terrain/blocked.png"),    # BLOCKED
}

## Per-mission environment flavour (player-requested 2026-08-15, assets/
## art-generation-requests-2026-08-15-mission-terrain.md): reskins
## PLACEABLE/PATH/BLOCKED per mission, matching each mission's own
## Mission-Select card-icon biome. SPAWN/GOAL are deliberately absent from
## every entry here — they stay on the shared TEXTURE_BY_TYPE set above for
## every mission (functional landmarks -- "an entry," "the exit" -- not
## biome-specific, per that batch's own scope note).
const TEXTURE_BY_TYPE_BY_MISSION: Dictionary[String, Dictionary] = {
	"the_gap": {
		0: preload("res://assets/art/terrain/the_gap_placeable.png"),
		1: preload("res://assets/art/terrain/the_gap_path.png"),
		4: preload("res://assets/art/terrain/the_gap_blocked.png"),
	},
	"the_foothills": {
		0: preload("res://assets/art/terrain/the_foothills_placeable.png"),
		1: preload("res://assets/art/terrain/the_foothills_path.png"),
		4: preload("res://assets/art/terrain/the_foothills_blocked.png"),
	},
	"the_hollow": {
		0: preload("res://assets/art/terrain/the_hollow_placeable.png"),
		1: preload("res://assets/art/terrain/the_hollow_path.png"),
		4: preload("res://assets/art/terrain/the_hollow_blocked.png"),
	},
	"the_narrows": {
		0: preload("res://assets/art/terrain/the_narrows_placeable.png"),
		1: preload("res://assets/art/terrain/the_narrows_path.png"),
		4: preload("res://assets/art/terrain/the_narrows_blocked.png"),
	},
}

## Scattered decorative props (player-requested 2026-08-15, assets/
## art-generation-requests-2026-08-15-mission-props.md): cutout icons with
## real alpha, unlike the opaque terrain tiles above — blended (not blitted)
## onto a random subset of PLACEABLE cells purely for visual variety. Never
## placed on PATH/SPAWN/GOAL/BLOCKED — those cells communicate function
## (walkable lane, landmark, impassable), and a decorative prop sitting on
## top would muddy that read. A mission absent from this dict simply gets no
## props (graceful degradation, same as the terrain dict above).
const PROP_TEXTURES_BY_MISSION: Dictionary[String, Array] = {
	"the_gap": [
		preload("res://assets/art/props/the_gap_rock_rubble.png"),
		preload("res://assets/art/props/the_gap_cracked_shards.png"),
	],
	"the_foothills": [
		preload("res://assets/art/props/the_foothills_grass_tuft.png"),
		preload("res://assets/art/props/the_foothills_shrub_clump.png"),
	],
	"the_hollow": [
		preload("res://assets/art/props/the_hollow_crystal_shards.png"),
		preload("res://assets/art/props/the_hollow_root_growth.png"),
	],
	"the_narrows": [
		preload("res://assets/art/props/the_narrows_river_stones.png"),
		preload("res://assets/art/props/the_narrows_reed_cluster.png"),
	],
}

## Fraction of PLACEABLE cells that get a scattered prop. Low by design --
## this is texture variety, not clutter; a player must still read every
## PLACEABLE cell as open buildable ground at a glance (art bible 3.2's
## figure/ground discipline).
const PROP_DENSITY: float = 0.18
## Prop rendered at this fraction of cell_px, centered in the cell -- small
## enough to read as ground dressing, never large enough to be mistaken for
## a placed tower or a blocking obstacle.
const PROP_SCALE: float = 0.55

## No cell-boundary outlines (removed 2026-10-06 at the user's request): the
## terrain reads as continuous ground. Placement readability comes from the
## placement preview's footprint highlight instead of permanent gridlines.

var _texture: ImageTexture = null


## mission_id: selects the per-mission terrain/prop sets above; "" (or any
## mission absent from those dicts) falls back to the shared set. rng:
## injectable for deterministic tests; a fresh randomized generator is used
## if omitted -- matches MapGenerator's own convention.
func configure(p_cols: int, p_rows: int, p_cell_size: float, p_cells: Dictionary, p_mission_id: String = "", p_rng: RandomNumberGenerator = null) -> void:
	cols = p_cols
	rows = p_rows
	cell_size = p_cell_size
	cells = p_cells
	if p_rng == null:
		p_rng = RandomNumberGenerator.new()
		p_rng.randomize()
	_texture = _build_grid_texture(p_mission_id, p_rng)
	queue_redraw()
	_build_visual_companion()


## Renders the full grid into a single Image once (TD-render-001's own
## established "one Image, not N draw_rect() calls" pattern — unchanged by
## the switch from flat color to real texture, and by the later addition of
## per-mission terrain/props below). Each terrain texture is resized to
## cell_px exactly once up front, then blitted per cell — resizing per-cell
## would repeat the same expensive resize for no benefit, since every cell
## of a given type uses the identical scaled-down source.
func _build_grid_texture(mission_id: String, rng: RandomNumberGenerator) -> ImageTexture:
	var px_width: int = int(cols * cell_size)
	var px_height: int = int(rows * cell_size)
	# FORMAT_RGBA8, not RGB8: Image.blend_rect() (used below for prop
	# stamping) requires src and dst to share the exact same format --
	# discovered as a real bug via live MCP testing (every blend_rect call
	# failed with "Condition \"format != p_src->format\" is true" when this
	# was RGB8 against the props' own RGBA8). The terrain itself stays fully
	# opaque either way; RGBA8 just carries an unused alpha channel for it.
	var image := Image.create(px_width, px_height, false, Image.FORMAT_RGBA8)
	var cell_px: int = int(cell_size)

	var texture_by_type: Dictionary = TEXTURE_BY_TYPE.duplicate()
	texture_by_type.merge(TEXTURE_BY_TYPE_BY_MISSION.get(mission_id, {}), true)  # overwrite_existing -- mission-specific PLACEABLE/PATH/BLOCKED replace the shared defaults; SPAWN/GOAL are absent from every mission entry so they're untouched

	var scaled_by_type: Dictionary = {}
	for cell_type: int in texture_by_type:
		var source_image: Image = (texture_by_type[cell_type] as Texture2D).get_image()
		source_image = source_image.duplicate()
		source_image.resize(cell_px, cell_px, Image.INTERPOLATE_LANCZOS)
		if source_image.get_format() != Image.FORMAT_RGBA8:
			source_image.convert(Image.FORMAT_RGBA8)
		scaled_by_type[cell_type] = source_image

	var prop_pool: Array = PROP_TEXTURES_BY_MISSION.get(mission_id, [])
	var prop_px: int = int(cell_size * PROP_SCALE)
	var prop_offset: int = int((cell_px - prop_px) / 2.0)
	var scaled_props: Array = []
	for prop_texture: Texture2D in prop_pool:
		var prop_image: Image = prop_texture.get_image().duplicate()
		prop_image.resize(prop_px, prop_px, Image.INTERPOLATE_LANCZOS)
		if prop_image.get_format() != Image.FORMAT_RGBA8:
			prop_image.convert(Image.FORMAT_RGBA8)
		scaled_props.append(prop_image)

	for row: int in range(rows):
		for col: int in range(cols):
			var cell := Vector2i(col, row)
			var cell_type: int = cells.get(cell, 4)  # BLOCKED default, matches Grid.get_cell_type()
			var tile: Image = scaled_by_type.get(cell_type, scaled_by_type[4])
			var origin_x: int = col * cell_px
			var origin_y: int = row * cell_px
			image.blit_rect(tile, Rect2i(0, 0, cell_px, cell_px), Vector2i(origin_x, origin_y))
			if cell_type == 0 and not scaled_props.is_empty() and rng.randf() < PROP_DENSITY:
				var prop: Image = scaled_props[rng.randi_range(0, scaled_props.size() - 1)]
				image.blend_rect(prop, Rect2i(0, 0, prop_px, prop_px), Vector2i(origin_x + prop_offset, origin_y + prop_offset))
	return ImageTexture.create_from_image(image)


func _draw() -> void:
	if _texture != null:
		draw_texture(_texture, Vector2.ZERO)


# ---------------------------------------------------------------------------
# Epic 15 Story 002 (ADR-0037): 3D visual-companion tile subtree.
# Purely additive — everything above this point (the 2D grid data/texture
# rendering this script already had) is unchanged, per ADR-0037's core
# constraint of zero simulation-code changes.
# ---------------------------------------------------------------------------

## Builds (or rebuilds) the Node3D visual-companion subtree: one MeshInstance3D
## per grid cell, resolved via GGameDataRegistry.get_visual_mesh_mapping()
## (data-driven per ADR-0037's Constraints — never a hardcoded scene
## reference), positioned via VisualMath.map_to_3d() against that cell's
## existing 2D center position (matches grid.gd's cell_to_world() convention:
## col * cell_size + cell_size * 0.5) at TILE_LAYER_HEIGHT (the ground plane).
##
## A missing/invalid mapping fails loudly (push_error) rather than silently
## rendering no tiles, per ADR-0037's Risks section policy ("rather than
## silently falling back to invisible").
##
## Called once per configure() call. If configure() is ever called again on
## an already-configured GridVisual (not this project's current the_gap.gd
## usage, but this method makes no single-call assumption), the previous
## companion subtree is freed and rebuilt from scratch rather than leaking or
## duplicating tile instances.
func _build_visual_companion() -> void:
	# Synchronous remove_child() BEFORE queue_free(), not queue_free() alone —
	# same fix as ADR-0031's Planning Cluster lifecycle bug (registered in
	# docs/registry/architecture.yaml as mission_hud_planning_cluster_lifecycle).
	# queue_free() defers removal to end-of-frame, so an immediately-following
	# add_child() of a new node with the SAME name ("VisualCompanion3D") while
	# the old one is still technically in the tree causes Godot to
	# auto-uniquify the new node's name — after the deferred free runs, zero
	# nodes are left with the expected name.
	if _visual_companion != null and is_instance_valid(_visual_companion):
		remove_child(_visual_companion)
		_visual_companion.queue_free()
	_visual_companion = Node3D.new()
	_visual_companion.name = "VisualCompanion3D"
	add_child(_visual_companion)

	var mapping: VisualMeshMappingResource = GGameDataRegistry.get_visual_mesh_mapping(TILE_MESH_ENTITY_ID)
	if mapping == null or mapping.mesh_scene == null:
		push_error("[GridVisual] No valid VisualMeshMappingResource for '%s' — grid tiles will have no 3D visual companion." % TILE_MESH_ENTITY_ID)
		return

	for cell: Vector2i in cells:
		var tile_node: Node = mapping.mesh_scene.instantiate()
		if not (tile_node is Node3D):
			push_error("[GridVisual] mesh_scene for '%s' did not instantiate as a Node3D — skipping tile at %s." % [TILE_MESH_ENTITY_ID, cell])
			tile_node.free()
			continue
		_visual_companion.add_child(tile_node)
		var cell_center_2d := Vector2(cell.x * cell_size + cell_size * 0.5, cell.y * cell_size + cell_size * 0.5)
		(tile_node as Node3D).position = VisualMath.map_to_3d(cell_center_2d, TILE_LAYER_HEIGHT)
