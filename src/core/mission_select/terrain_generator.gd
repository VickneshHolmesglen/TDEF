## TerrainGenerator — fills GridConfig.heights and GridConfig.water from a
## TerrainProfile after MapGenerator has carved the lanes (spec
## 2026-11-07-3d-terrain §5.2). Uses only the rng it is given, so the same
## seed always gives the same terrain (Daily Challenge, tests).
##
## Rivers first: each is a top-to-bottom meandering band. Consecutive rows'
## runs always share a column, so the band is a 4-connected wall from the top
## to the bottom of the interior and the left-to-right lane must cross it: the
## crossed PATH cells become fords. Hills then grow as random blobs over dry
## PLACEABLE cells (never on PATH/SPAWN/GOAL, but free to touch the lane);
## level 2 is a level-1 cell whose four neighbours are all hills.
##
## Example: TerrainGenerator.apply(config, entry.terrain_profile, rng)
class_name TerrainGenerator
extends RefCounted

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


## Writes config.heights and config.water. A null profile leaves them empty.
static func apply(config: GridConfig, profile: TerrainProfile, rng: RandomNumberGenerator) -> void:
	var heights: Dictionary[Vector2i, int] = {}
	var water: Dictionary[Vector2i, bool] = {}
	if profile == null:
		config.heights = heights
		config.water = water
		return
	var floor_share: float = TerrainTuning.load_default().min_buildable_share
	var interior: int = maxi(1, (config.cols - 2) * (config.rows - 2))

	# Rivers: the planned width, narrowed to 1 and then fewer rivers if the
	# map would drop below the buildable floor. Hills never reduce buildable
	# cells (towers may stand on hills), so only water is trimmed. The rng
	# draws for the river shapes happen once, so narrowing keeps the courses.
	var shapes: Array[Dictionary] = []
	for i: int in profile.river_count:
		shapes.append(_river_shape(config, i, profile.river_count, rng))
	var width: int = profile.river_width_cells
	var count: int = profile.river_count
	while true:
		water = _carve_rivers(config, shapes, count, width)
		if _buildable(config, water) / float(interior) >= floor_share:
			break
		if width > 1:
			width = 1
		elif count > 1:
			count -= 1
		else:
			break

	if profile.max_height_level > 0 and profile.hill_coverage > 0.0:
		heights = _grow_hills(config, profile, water, rng)
	config.heights = heights
	config.water = water


## Course of river `index` of `total`: a base column in its own slice of the
## board plus a sine meander. Returns {base, amp, freq, phase}.
static func _river_shape(config: GridConfig, index: int, total: int, rng: RandomNumberGenerator) -> Dictionary:
	var lo: int = 3
	var hi: int = config.cols - 4
	var slice: float = float(hi - lo) / total
	var base: float = lo + slice * index + rng.randf_range(0.3, 0.7) * slice
	var amp: float = rng.randf_range(0.8, 1.8)
	if total > 1:
		# Twin rivers stay centred in their own half with a gentler meander, so
		# their smoothed beds never merge into one lake (live-found 2026-11-08).
		base = lo + slice * (index + 0.5)
		amp = minf(amp, 1.0)
	return {
		"base": base,
		"amp": amp,
		"freq": rng.randf_range(0.45, 0.75),
		"phase": rng.randf_range(0.0, TAU),
	}


static func _carve_rivers(config: GridConfig, shapes: Array[Dictionary], count: int, width: int) -> Dictionary[Vector2i, bool]:
	var water: Dictionary[Vector2i, bool] = {}
	for i: int in count:
		var s: Dictionary = shapes[i]
		var prev: int = -1
		# Interior rows carve the river; the BLOCKED border rows get water too
		# (looks only: never walkable) so the river visibly runs off the board.
		for y: int in range(0, config.rows):
			var c: int = roundi(s.base + s.amp * sin(y * s.freq + s.phase))
			c = clampi(c, 2, config.cols - 2 - width)
			var from: int = c if prev < 0 else mini(c, prev)
			var to: int = (c if prev < 0 else maxi(c, prev)) + width - 1
			for x: int in range(from, to + 1):
				var cell := Vector2i(x, y)
				var ct: int = config.cells.get(cell, Grid.CellType.BLOCKED)
				if ct == Grid.CellType.PLACEABLE or ct == Grid.CellType.PATH or ct == Grid.CellType.BLOCKED:
					water[cell] = true
			prev = c
	return water


static func _buildable(config: GridConfig, water: Dictionary[Vector2i, bool]) -> int:
	var n: int = 0
	for cell: Vector2i in config.cells:
		if config.cells[cell] == Grid.CellType.PLACEABLE and not water.has(cell):
			n += 1
	return n


static func _grow_hills(config: GridConfig, profile: TerrainProfile, water: Dictionary[Vector2i, bool],
		rng: RandomNumberGenerator) -> Dictionary[Vector2i, int]:
	var candidates: Array[Vector2i] = []
	for y: int in range(1, config.rows - 1):
		for x: int in range(1, config.cols - 1):
			var cell := Vector2i(x, y)
			if config.cells.get(cell, -1) == Grid.CellType.PLACEABLE and not water.has(cell):
				candidates.append(cell)
	var heights: Dictionary[Vector2i, int] = {}
	if candidates.is_empty():
		return heights
	var non_path: int = 0
	for cell: Vector2i in config.cells:
		if config.cells[cell] == Grid.CellType.PLACEABLE:
			non_path += 1
	var target: int = roundi(profile.hill_coverage * non_path)
	var clusters: int = maxi(1, rng.randi_range(profile.hill_clusters_min, profile.hill_clusters_max))
	var seeds: Array[Vector2i] = candidates
	if profile.hills_ring_edges:
		seeds = candidates.filter(func(c: Vector2i) -> bool:
			return c.x <= 2 or c.y <= 2 or c.x >= config.cols - 3 or c.y >= config.rows - 3)
		if seeds.is_empty():
			seeds = candidates
	var allowed: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in candidates:
		allowed[cell] = true

	for k: int in clusters:
		var budget: int = (target - heights.size()) / (clusters - k)
		if budget <= 0:
			break
		var start: Vector2i = seeds[rng.randi_range(0, seeds.size() - 1)]
		if heights.has(start):
			continue
		var frontier: Array[Vector2i] = [start]
		var grown: int = 0
		while grown < budget and not frontier.is_empty():
			var pick: int = rng.randi_range(0, frontier.size() - 1)
			var cell: Vector2i = frontier[pick]
			frontier.remove_at(pick)
			if heights.has(cell):
				continue
			heights[cell] = 1
			grown += 1
			for d: Vector2i in DIRS:
				if allowed.has(cell + d) and not heights.has(cell + d):
					frontier.append(cell + d)

	if profile.max_height_level >= 2:
		var peaks: Array[Vector2i] = []
		for cell: Vector2i in heights:
			if DIRS.all(func(d: Vector2i) -> bool: return heights.has(cell + d)):
				peaks.append(cell)
		for cell: Vector2i in peaks:
			heights[cell] = 2
	return heights
