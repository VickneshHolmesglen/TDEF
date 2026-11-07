## TerrainTuning — every tunable number for hills and water in one data
## resource (spec 2026-11-07-3d-terrain §4). Read via load_default().
class_name TerrainTuning
extends Resource

const DEFAULT_PATH: String = "res://assets/data/terrain/terrain_tuning.tres"

## Extra placement cost per height level, as a share of the base cost.
@export var hill_cost_per_level: float = 0.25
## Cells added to every tower range per height level.
@export var hill_range_per_level: int = 1
## Ground-monster speed multiplier while standing in water.
@export var water_monster_speed_mult: float = 0.6
## Hero move-speed multiplier while the water debuff is active.
@export var water_hero_speed_mult: float = 0.7
## Seconds the hero's water debuff lasts after leaving the water.
@export var water_hero_linger_seconds: float = 3.0
## Generation floor: share of interior cells that must stay buildable.
@export var min_buildable_share: float = 0.40
## Visual height of one level, in cells (presentation only).
@export var height_per_level_cells: float = 0.5

static var _cached: TerrainTuning


## The shipped tuning, or code defaults if the .tres is missing.
static func load_default() -> TerrainTuning:
	if _cached == null:
		if ResourceLoader.exists(DEFAULT_PATH):
			_cached = load(DEFAULT_PATH) as TerrainTuning
		if _cached == null:
			_cached = TerrainTuning.new()
	return _cached
