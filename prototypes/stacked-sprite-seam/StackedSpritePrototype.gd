# PROTOTYPE — NOT FOR PRODUCTION
# Question: Does stacked-sprite-with-shadow technique produce objects that sit ON
#           the ground plane at the game's oblique angle in Godot 4.6.2?
#           What is the minimum layer count before depth reads as convincing?
# Date: 2026-05-19

extends Node2D

# --- Tuning knobs (tweak these to test different configurations) ---
const TILE_SIZE       := Vector2(64, 48)   # slightly shorter Y = oblique feel
const GRID_COLS       := 7
const GRID_ROWS       := 6
const LAYER_OFFSET_Y  := -4               # px per layer upward (height illusion)
const TOWER_LAYERS    := 8
const ENEMY_LAYERS    := 4
const LAYER_TAPER     := 0.4              # px width/height lost per layer (slight taper)

# Tile palette — alternating to simulate terrain variation
const TILE_COLORS := [
	Color(0.33, 0.52, 0.22),  # grass base
	Color(0.38, 0.57, 0.26),  # grass light
	Color(0.29, 0.47, 0.19),  # grass shadow
	Color(0.52, 0.44, 0.28),  # dirt patch
]

# Tower palette (stone — grey, bottom-to-top)
const TOWER_SHADOW_COLOR := Color(0.0,  0.0,  0.0,  0.40)
const TOWER_BASE_COLOR   := Color(0.42, 0.42, 0.48)
const TOWER_TOP_COLOR    := Color(0.78, 0.76, 0.80)

# Enemy palette (red, bottom-to-top)
const ENEMY_SHADOW_COLOR := Color(0.0,  0.0,  0.0,  0.35)
const ENEMY_BASE_COLOR   := Color(0.55, 0.12, 0.12)
const ENEMY_TOP_COLOR    := Color(1.00, 0.40, 0.30)


func _ready() -> void:
	_build_grid()

	# Tower: 8 layers at grid centre
	_build_stacked_object(
		Vector2(3, 2),
		TOWER_LAYERS,
		Vector2(38, 38),
		TOWER_SHADOW_COLOR, TOWER_BASE_COLOR, TOWER_TOP_COLOR,
		"Tower  (%d layers, %dpx/layer)" % [TOWER_LAYERS, abs(LAYER_OFFSET_Y)]
	)

	# Enemy: 4 layers — tests whether the technique scales down
	_build_stacked_object(
		Vector2(1, 3),
		ENEMY_LAYERS,
		Vector2(24, 26),
		ENEMY_SHADOW_COLOR, ENEMY_BASE_COLOR, ENEMY_TOP_COLOR,
		"Enemy  (%d layers)" % ENEMY_LAYERS
	)

	# Second tower with fewer layers for direct comparison
	_build_stacked_object(
		Vector2(5, 2),
		4,
		Vector2(38, 38),
		TOWER_SHADOW_COLOR, TOWER_BASE_COLOR, TOWER_TOP_COLOR,
		"Tower  (4 layers — compare)"
	)

	_build_instructions()


func _build_grid() -> void:
	for row in GRID_ROWS:
		for col in GRID_COLS:
			var rect := ColorRect.new()
			rect.size = TILE_SIZE - Vector2(2.0, 2.0)  # 2px gap = grid lines
			rect.position = Vector2(col * TILE_SIZE.x + 1.0, row * TILE_SIZE.y + 1.0)
			rect.color = TILE_COLORS[(row + col) % TILE_COLORS.size()]
			rect.z_index = 0
			add_child(rect)


func _build_stacked_object(
	grid_pos: Vector2,
	layer_count: int,
	footprint: Vector2,
	shadow_color: Color,
	base_color: Color,
	top_color: Color,
	label_text: String
) -> void:
	# Pixel origin: centre the footprint within its tile
	var origin := Vector2(
		grid_pos.x * TILE_SIZE.x + (TILE_SIZE.x - footprint.x) * 0.5,
		grid_pos.y * TILE_SIZE.y + (TILE_SIZE.y - footprint.y) * 0.5
	)

	# Ground shadow — sits flat on the tile, anchors the object visually
	var shadow := ColorRect.new()
	shadow.size = Vector2(footprint.x * 1.15, footprint.y * 0.30)
	shadow.position = origin + Vector2(footprint.x * -0.075, footprint.y * 0.78)
	shadow.color = shadow_color
	shadow.z_index = 1
	add_child(shadow)

	# Stack layers bottom (0) to top (layer_count-1)
	for i in layer_count:
		var t := float(i) / float(max(layer_count - 1, 1))
		var taper := i * LAYER_TAPER
		var layer := ColorRect.new()
		layer.size = footprint - Vector2(taper, taper)
		# Re-centre horizontally as the layer tapers
		layer.position = origin + Vector2(taper * 0.5, float(i) * LAYER_OFFSET_Y)
		layer.color = base_color.lerp(top_color, t)
		layer.z_index = 2 + i
		add_child(layer)

	# Label below the object
	var lbl := Label.new()
	lbl.text = label_text
	lbl.position = origin + Vector2(-8.0, TILE_SIZE.y * 0.9)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6))
	lbl.z_index = 50
	add_child(lbl)


func _build_instructions() -> void:
	var bg := ColorRect.new()
	bg.size = Vector2(GRID_COLS * TILE_SIZE.x, 72.0)
	bg.position = Vector2(0.0, GRID_ROWS * TILE_SIZE.y)
	bg.color = Color(0.05, 0.05, 0.08)
	bg.z_index = 40
	add_child(bg)

	var info := Label.new()
	info.text = (
		"PROTOTYPE — Stacked Sprite Seam Validation\n"
		+ "Left: Tower 8 layers | Right: Tower 4 layers (compare depth) | Mid-left: Enemy 4 layers\n"
		+ "Evaluate: Do objects sit ON tiles or float? Does shadow ground them? Which layer count reads as 3D?"
	)
	info.position = Vector2(8.0, GRID_ROWS * TILE_SIZE.y + 6.0)
	info.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	info.z_index = 50
	add_child(info)
