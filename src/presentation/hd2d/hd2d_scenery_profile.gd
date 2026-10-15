class_name Hd2dSceneryProfile
extends Resource

## Per-mission look for the HD-2D scenery layer (ADR-0042). Pure data: which
## textures, how dense, how the light and camera sit. Hd2dScenery reads it;
## nothing here touches gameplay. One .tres per mission under
## assets/data/hd2d/.

@export_group("Ground")
@export var ground_grass: Texture2D
@export var ground_dirt: Texture2D
@export var ground_stone: Texture2D
## 2D map px per ground-texture pixel (bigger = chunkier pixels).
@export var ground_texel_px: float = 3.0
## Radius, in cells, of the flagstone patch under the spawn and goal.
@export var landmark_radius_cells: float = 1.25
## > 0 scrolls and sparkles the lane texture (a river lane, The Narrows).
@export var lane_shimmer: float = 0.0
## Lane texture repeat factor (> 1 shrinks cobbles/slabs on the road).
@export var lane_scale: float = 1.0

@export_group("Grass")
@export var grass_cards: Array[Texture2D] = []
## Tufts per cell at full patch density (patches follow low-frequency noise).
@export var grass_per_cell: float = 5.0
## Multiplier on that density for cells inside the playable grid (keeps the
## field readable; the borders stay lush).
@export var grass_inner_factor: float = 0.55
@export var grass_height_px: float = 14.0
@export var grass_sway_px: float = 3.5
@export var flower_card: Texture2D
@export var flowers_per_cell: float = 1.2
@export var bush_card: Texture2D
@export var bush_count: int = 18
## Per-instance colour multiplier for grass tufts.
@export var grass_tint: Color = Color(1.04, 1.0, 0.82)
## Cards scattered tight along the lane banks (reeds, dry tufts); empty = none.
@export var lane_edge_cards: Array[Texture2D] = []
@export var lane_edge_per_cell: float = 0.0
@export var lane_edge_height_px: float = 40.0

@export_group("Trees and props")
@export var leaf_cards: Array[Texture2D] = []
@export var pine_card: Texture2D
@export var bark: Texture2D
@export var wood: Texture2D
@export var ruin_bricks: Texture2D
@export var rock: Texture2D
@export var broadleaf_count: int = 14
@export var pine_count: int = 6
@export var rock_count: int = 14
@export var fence_along_top: bool = true
@export var ruins_at_landmarks: bool = true
@export var ruin_tint: Color = Color.WHITE
## Multiplier on tree leaf clumps and pines.
@export var foliage_tint: Color = Color.WHITE
## Tall rock spires on the blocked border / off-map (uses `rock`).
@export var spire_count: int = 0
@export var spire_height_px: Vector2 = Vector2(70.0, 150.0)
## Emissive crystal clusters on the blocked border / off-map, each with a light.
@export var crystal_clusters: int = 0
@export var crystal_color: Color = Color(0.45, 0.75, 1.0)

@export_group("Kit models")
## CC0 Kenney Nature Kit meshes (assets/art/hd2d/kit/), reskinned with the
## textures below so they share the pixel look. Each list replaces one
## primitive stand-in; an empty list keeps the primitive. Placement is
## unchanged either way -- only the mesh differs.
@export var kit_rocks: Array[PackedScene] = []
@export var kit_spires: Array[PackedScene] = []
@export var kit_pines: Array[PackedScene] = []
## Landmark pillars (intact and broken) and the fallen blocks around them.
@export var kit_columns: Array[PackedScene] = []
@export var kit_rubble: Array[PackedScene] = []
## Stumps, logs and mushrooms on the blocked border / off-map.
@export var kit_debris: Array[PackedScene] = []
@export var debris_count: int = 0
## Rock body texture for kit rocks and spires (falls back to `rock`).
@export var kit_rock_texture: Texture2D
## Multiplier on kit rock/spire stone: Kenney boulders catch full sun on
## broad faces, so they read brighter than the primitives they replace.
@export var kit_rock_tint: Color = Color(0.8, 0.8, 0.78)
## Mossy stone for kit rubble (falls back to `ruin_bricks`).
@export var kit_rubble_texture: Texture2D
## Opaque needle mass for kit pines (required when kit_pines is set).
@export var kit_foliage: Texture2D

@export_group("Light and camera")
## Camera tilt below horizontal. The ground is stretched by 1/sin(pitch) so
## it still lines up 1:1 with the 2D map (see Hd2dScenery.to_world()).
@export_range(20.0, 89.0) var camera_pitch_deg: float = 50.0
@export var sun_color: Color = Color(1.0, 0.86, 0.66)
@export var sun_energy: float = 1.35
@export var sun_rotation_deg: Vector3 = Vector3(-52.0, -38.0, 0.0)
@export var ambient_color: Color = Color(0.5, 0.56, 0.68)
@export var ambient_energy: float = 0.42
@export var exposure: float = 0.92
@export var saturation: float = 0.9
@export var contrast: float = 1.12
@export var background_color: Color = Color(0.12, 0.16, 0.1)
## Tint for the 2D gameplay layer (units, towers, VFX) so sprites take on the
## mission's light; applied by the mission scene as a CanvasModulate.
@export var unit_tint: Color = Color.WHITE
@export var rng_seed: int = 20261011


## Load-time validation (registry convention: returns error strings).
func validate() -> Array[String]:
	var errors: Array[String] = []
	if ground_grass == null or ground_dirt == null or ground_stone == null:
		errors.append("ground_grass, ground_dirt and ground_stone are required")
	if grass_cards.is_empty():
		errors.append("grass_cards must not be empty")
	if leaf_cards.is_empty() and broadleaf_count > 0:
		errors.append("leaf_cards must not be empty when broadleaf_count > 0")
	if ground_texel_px <= 0.0:
		errors.append("ground_texel_px must be positive")
	if not kit_pines.is_empty() and kit_foliage == null:
		errors.append("kit_foliage is required when kit_pines is set")
	if debris_count > 0 and kit_debris.is_empty():
		errors.append("kit_debris must not be empty when debris_count > 0")
	return errors
