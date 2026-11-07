## TerrainProfile — a map's terrain character (spec 2026-11-07-3d-terrain §5.1).
## TerrainGenerator reads it after MapGenerator carves the lanes; the layout
## changes every launch, the character stays.
class_name TerrainProfile
extends Resource

## Target share of interior non-path cells raised into hills (0..0.5).
@export_range(0.0, 0.5) var hill_coverage: float = 0.0
## Highest height level hills reach (0 = no hills, 1 or 2).
@export_range(0, 2) var max_height_level: int = 1
## Number of hill blobs, picked between these (inclusive).
@export var hill_clusters_min: int = 1
@export var hill_clusters_max: int = 1
## Seed hill blobs on the outer interior ring, so hills ring the board (a bowl).
@export var hills_ring_edges: bool = false
## Rivers running top to bottom across the board (0..2).
@export_range(0, 2) var river_count: int = 0
## River width in cells (1 = stream, 2 = wide river).
@export_range(1, 2) var river_width_cells: int = 1


## Returns validation errors. Empty array means the profile is valid.
func validate() -> Array[String]:
	var errors: Array[String] = []
	if hill_coverage < 0.0 or hill_coverage > 0.5:
		errors.append("hill_coverage must be 0..0.5 (got %f)" % hill_coverage)
	if max_height_level < 0 or max_height_level > GridConfig.MAX_HEIGHT_LEVEL:
		errors.append("max_height_level must be 0..2 (got %d)" % max_height_level)
	if hill_clusters_min < 0 or hill_clusters_max < hill_clusters_min:
		errors.append("hill_clusters range invalid (%d..%d)" % [hill_clusters_min, hill_clusters_max])
	if river_count < 0 or river_count > 2:
		errors.append("river_count must be 0..2 (got %d)" % river_count)
	if river_width_cells < 1 or river_width_cells > 2:
		errors.append("river_width_cells must be 1..2 (got %d)" % river_width_cells)
	return errors
