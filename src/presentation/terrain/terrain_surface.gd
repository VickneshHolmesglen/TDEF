## TerrainSurface — the smooth ground height under the 3D scenery (spec
## 2026-11-07-3d-terrain §6.1/§6.4). Presentation only: gameplay reads cell
## levels from Grid; this turns them into rolling slopes (mockup B) and answers
## "how high is the ground here" and "which ground point is under this screen
## point".
##
## Heights are in 2D px, like Hd2dScenery.to_world(p, h). A point raised by h
## draws higher on screen by h × cos(pitch).
##
## Example:
##   var surface := TerrainSurface.from_config(config, TerrainTuning.load_default())
##   if surface != null: print(surface.height_at(Vector2(300, 200)))
class_name TerrainSurface
extends RefCounted

## Height samples per cell side.
const SUB: int = 8
## Gaussian smoothing, in cells (mockup B smoothed over about one cell).
const SIGMA_CELLS: float = 0.45
## Lane samples farther than this (cells) from any non-lane cell are pinned
## flat; closer ones blend toward flat (smoothstep) so the lane reads clearly.
const LANE_PIN_CELLS: float = 0.3
const RIVER_BED_CELLS: float = -0.15
## Water sits high enough in the blurred bed that a 1-cell river shows about
## one cell wide (live-tuned 2026-11-08: -0.04 spilled ~1.6 cells wide); fords
## sit just under it so the lane shows a shallow crossing.
const FORD_BED_CELLS: float = -0.09
const WATER_LEVEL_CELLS: float = -0.07

var _cell: float = 64.0
var _nx: int = 0
var _ny: int = 0
var _h: PackedFloat32Array = PackedFloat32Array()
var _max_h: float = 0.0
var _min_h: float = 0.0
var _water: Dictionary[Vector2i, bool] = {}


## A surface for `config`, or null when it has no hills and no water (flat
## maps keep today's flat ground).
static func from_config(config: GridConfig, tuning: TerrainTuning) -> TerrainSurface:
	if config == null or (config.heights.is_empty() and config.water.is_empty()):
		return null
	var s := TerrainSurface.new()
	s._build(config, tuning)
	return s


## Smoothed ground height (2D px) at 2D point `p`; clamped to the grid edge outside.
func height_at(p2d: Vector2) -> float:
	var fx: float = clampf(p2d.x / _cell * SUB, 0.0, float(_nx - 1))
	var fy: float = clampf(p2d.y / _cell * SUB, 0.0, float(_ny - 1))
	var x0: int = mini(int(fx), _nx - 2)
	var y0: int = mini(int(fy), _ny - 2)
	var tx: float = fx - x0
	var ty: float = fy - y0
	var a: float = lerpf(_h[y0 * _nx + x0], _h[y0 * _nx + x0 + 1], tx)
	var b: float = lerpf(_h[(y0 + 1) * _nx + x0], _h[(y0 + 1) * _nx + x0 + 1], tx)
	return lerpf(a, b, ty)


## Height of the water surface (2D px), just below flat ground.
func water_level() -> float:
	return WATER_LEVEL_CELLS * _cell


## True if 2D point `p` lies on a water cell (river or ford).
func is_water(p2d: Vector2) -> bool:
	return _water.has(Vector2i((p2d / _cell).floor()))


## 2D px rect covering every water cell; zero-size when there is no water.
func water_bounds() -> Rect2:
	if _water.is_empty():
		return Rect2()
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for c: Vector2i in _water:
		lo = lo.min(c)
		hi = hi.max(c)
	return Rect2(Vector2(lo) * _cell, Vector2(hi - lo + Vector2i.ONE) * _cell)


## Highest smoothed height on the map (2D px).
func max_height() -> float:
	return _max_h


## How far up the screen the ground at `p` is drawn: height × cos(pitch).
func screen_lift(p2d: Vector2, pitch_deg: float) -> float:
	return height_at(p2d) * cos(deg_to_rad(pitch_deg))


## The ground point drawn at `screen_p` (a flat-ground 2D position): p.x =
## screen_p.x and p.y − screen_lift(p) = screen_p.y. Where several ground
## points share the screen spot, the one nearest the camera (largest y) is
## the visible one and is returned.
func screen_to_ground(screen_p: Vector2, pitch_deg: float) -> Vector2:
	var c: float = cos(deg_to_rad(pitch_deg))
	var step: float = _cell / SUB
	var lo: float = screen_p.y + minf(0.0, _min_h * c) - step
	var y: float = screen_p.y + _max_h * c + step
	var f_prev: float = _offset(screen_p, y, c)
	while y > lo:
		var y_next: float = y - step
		var f: float = _offset(screen_p, y_next, c)
		if f_prev >= 0.0 and f <= 0.0:
			var a: float = y_next
			var b: float = y
			for i: int in 20:
				var m: float = (a + b) * 0.5
				if _offset(screen_p, m, c) <= 0.0:
					a = m
				else:
					b = m
			return Vector2(screen_p.x, (a + b) * 0.5)
		y = y_next
		f_prev = f
	return screen_p


func _offset(screen_p: Vector2, y: float, c: float) -> float:
	return y - height_at(Vector2(screen_p.x, y)) * c - screen_p.y


func _build(config: GridConfig, tuning: TerrainTuning) -> void:
	_cell = config.cell_size
	_water = config.water.duplicate()
	_nx = config.cols * SUB + 1
	_ny = config.rows * SUB + 1
	var level_h: float = tuning.height_per_level_cells * _cell
	var target := PackedFloat32Array()
	target.resize(_nx * _ny)
	var lane_w := PackedFloat32Array()
	lane_w.resize(_nx * _ny)
	for j: int in _ny:
		for i: int in _nx:
			var p := Vector2(float(i) / SUB, float(j) / SUB)  # in cells
			var cell := Vector2i(mini(int(p.x), config.cols - 1), mini(int(p.y), config.rows - 1))
			target[j * _nx + i] = _cell_target(config, cell, level_h)
			lane_w[j * _nx + i] = _lane_weight(config, cell, p)
	_h = _blur(target)
	for k: int in _h.size():
		if lane_w[k] > 0.0:
			_h[k] = lerpf(_h[k], target[k], lane_w[k])
		_max_h = maxf(_max_h, _h[k])
		_min_h = minf(_min_h, _h[k])


func _cell_target(config: GridConfig, cell: Vector2i, level_h: float) -> float:
	if config.water.get(cell, false):
		var ct: int = config.cells.get(cell, Grid.CellType.BLOCKED)
		return (FORD_BED_CELLS if ct == Grid.CellType.PATH else RIVER_BED_CELLS) * _cell
	return config.heights.get(cell, 0) * level_h


static func _is_lane(config: GridConfig, cell: Vector2i) -> bool:
	var ct: int = config.cells.get(cell, Grid.CellType.BLOCKED)
	return ct == Grid.CellType.PATH or ct == Grid.CellType.SPAWN or ct == Grid.CellType.GOAL


## 0 off the lane; on the lane, smoothstep of the distance (cells) to the
## nearest non-lane neighbour cell, reaching 1 at LANE_PIN_CELLS.
func _lane_weight(config: GridConfig, cell: Vector2i, p: Vector2) -> float:
	if not _is_lane(config, cell):
		return 0.0
	var d: float = 2.0
	for oy: int in range(-1, 2):
		for ox: int in range(-1, 2):
			var n := cell + Vector2i(ox, oy)
			if n == cell or n.x < 0 or n.y < 0 or n.x >= config.cols or n.y >= config.rows:
				continue
			if _is_lane(config, n):
				continue
			var dx: float = maxf(0.0, maxf(n.x - p.x, p.x - (n.x + 1)))
			var dy: float = maxf(0.0, maxf(n.y - p.y, p.y - (n.y + 1)))
			d = minf(d, sqrt(dx * dx + dy * dy))
	return smoothstep(0.0, LANE_PIN_CELLS, d)


## Separable Gaussian blur with edge clamping.
func _blur(src: PackedFloat32Array) -> PackedFloat32Array:
	var sigma: float = SIGMA_CELLS * SUB
	var r: int = ceili(sigma * 3.0)
	var kernel := PackedFloat32Array()
	var total: float = 0.0
	for k: int in range(-r, r + 1):
		var w: float = exp(-0.5 * (k / sigma) * (k / sigma))
		kernel.append(w)
		total += w
	for k: int in kernel.size():
		kernel[k] /= total
	var tmp := PackedFloat32Array()
	tmp.resize(src.size())
	for j: int in _ny:
		for i: int in _nx:
			var acc: float = 0.0
			for k: int in range(-r, r + 1):
				acc += src[j * _nx + clampi(i + k, 0, _nx - 1)] * kernel[k + r]
			tmp[j * _nx + i] = acc
	var out := PackedFloat32Array()
	out.resize(src.size())
	for j: int in _ny:
		for i: int in _nx:
			var acc: float = 0.0
			for k: int in range(-r, r + 1):
				acc += tmp[clampi(j + k, 0, _ny - 1) * _nx + i] * kernel[k + r]
			out[j * _nx + i] = acc
	return out
