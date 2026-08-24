extends Node3D

## Hybrid 3D-world / 2D-creature swarm rendering pilot (ADR-0038 Story 1-4).
## Prototype-quality code -- hardcoded values, no data-driven config, no
## dependency injection. See README.md for the questions this answers.
##
## Story 4 (2026-08-24): capacity is now fixed at MAX_INSTANCE_COUNT,
## matching the production design's own "preallocate once, never resize
## instance_count at runtime" rule (ADR-0038 Dense batch algorithm) --
## set_active_count() varies MultiMesh.visible_instance_count instead,
## exactly the mechanism ADR-0038 names for exposing "the dense live
## prefix." This lets the 50/100/150/200 stress steps measure the real
## production pattern, not a reallocation this pilot would otherwise be
## the only thing ever doing.

const MAX_INSTANCE_COUNT: int = 200
const RESERVED_SPECIAL_SLOTS: int = 5  # last 5 slots: slope + occlusion test cases, hand-placed, never part of the random scatter
const ATLAS_COLS: int = 2
const ATLAS_ROWS: int = 2
const FRAME_COUNT: int = ATLAS_COLS * ATLAS_ROWS
const SCATTER_RADIUS: float = 8.0
const BODY_HEIGHT: float = 1.0
const BODY_WIDTH: float = 0.6
const FLASH_INTERVAL_SEC: float = 1.5
const FRAME_ADVANCE_SEC: float = 0.25

var _body_multimesh: MultiMesh
var _shadow_multimesh: MultiMesh
var _active_count: int = MAX_INSTANCE_COUNT
var _frame_timer: float = 0.0
var _current_frame: int = 0
var _flash_timer: float = 0.0


func _ready() -> void:
	var atlas_tex: ImageTexture = _build_synthetic_atlas()
	_build_body_batch(atlas_tex)
	_build_shadow_batch()
	_scatter_instances()
	_place_special_test_instances()
	set_active_count(100)  # default stress-test starting point
	print("[pilot] capacity=%d, active=%d -- body + shadow batches, 2 draw calls total for the visible swarm regardless of active count" % [MAX_INSTANCE_COUNT, _active_count])


## Story 4 stress-test control surface: varies MultiMesh.visible_instance_count
## on both batches (the dense-live-prefix mechanism ADR-0038 names), never
## MultiMesh.instance_count itself (fixed capacity, allocated once in
## _build_body_batch()/_build_shadow_batch(), per the production design's own
## "never resize at runtime" rule). The reserved special-test slots (last
## RESERVED_SPECIAL_SLOTS) are always excluded from the visible count so the
## slope/occlusion cases don't skew the random-scatter stress numbers --
## callers wanting to see them use show_special_test_instances().
func set_active_count(n: int) -> void:
	_active_count = clampi(n, 0, MAX_INSTANCE_COUNT - RESERVED_SPECIAL_SLOTS)
	_body_multimesh.visible_instance_count = _active_count
	_shadow_multimesh.visible_instance_count = _active_count


func show_special_test_instances(visible: bool) -> void:
	var count: int = MAX_INSTANCE_COUNT if visible else _active_count
	_body_multimesh.visible_instance_count = count
	_shadow_multimesh.visible_instance_count = count


## Story 4: Performance singleton snapshot for the stress-matrix evidence
## record. Draw calls and static memory are point-in-time; FPS/frame time
## are only meaningful averaged over several frames by the caller (this
## pilot does not average internally -- run_script callers should sample
## across a short await loop for a stable FPS reading).
func get_perf_snapshot() -> Dictionary:
	return {
		"active_count": _active_count,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"process_time_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_process_time_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"static_memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0),
		"video_memory_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0),
	}


## Q1/Q2 raw material: a 2x2 atlas, each quadrant a flat, distinguishable
## color, so atlas-frame selection is visually obvious in a screenshot
## without needing real illustrated creature art (explicitly out of scope
## for this pilot -- see README.md).
func _build_synthetic_atlas() -> ImageTexture:
	const CELL_PX: int = 32
	var img := Image.create(CELL_PX * ATLAS_COLS, CELL_PX * ATLAS_ROWS, false, Image.FORMAT_RGBA8)
	var colors: Array[Color] = [
		Color(0.85, 0.25, 0.25, 1.0),  # frame 0 -- red
		Color(0.25, 0.55, 0.85, 1.0),  # frame 1 -- blue
		Color(0.35, 0.75, 0.35, 1.0),  # frame 2 -- green
		Color(0.85, 0.75, 0.2, 1.0),   # frame 3 -- yellow
	]
	for row: int in ATLAS_ROWS:
		for col: int in ATLAS_COLS:
			var frame_index: int = row * ATLAS_COLS + col
			var color: Color = colors[frame_index % colors.size()]
			img.fill_rect(Rect2i(col * CELL_PX, row * CELL_PX, CELL_PX, CELL_PX), color)
	return ImageTexture.create_from_image(img)


func _build_body_batch(atlas_tex: ImageTexture) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(BODY_WIDTH, BODY_HEIGHT)

	_body_multimesh = MultiMesh.new()
	_body_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_body_multimesh.use_custom_data = true
	_body_multimesh.mesh = quad
	_body_multimesh.instance_count = MAX_INSTANCE_COUNT

	var shader := load("res://prototypes/hybrid-swarm-pilot/creature_swarm_body.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("atlas_tex", atlas_tex)
	mat.set_shader_parameter("atlas_cols", ATLAS_COLS)
	mat.set_shader_parameter("atlas_rows", ATLAS_ROWS)

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "BodyBatch"
	mmi.multimesh = _body_multimesh
	mmi.material_override = mat
	add_child(mmi)


func _build_shadow_batch() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(BODY_WIDTH * 0.9, BODY_WIDTH * 0.9)
	# QuadMesh faces +Z by default; laid flat via each instance's own
	# transform (a -90 deg rotation around X in _scatter_instances()), not
	# via any mesh-level orientation property -- QuadMesh has none.

	_shadow_multimesh = MultiMesh.new()
	_shadow_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_shadow_multimesh.mesh = quad
	_shadow_multimesh.instance_count = MAX_INSTANCE_COUNT

	var shader := load("res://prototypes/hybrid-swarm-pilot/creature_contact_shadow.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "ShadowBatch"
	mmi.multimesh = _shadow_multimesh
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## Q3/Q4/Story 4: scatter the random-test slots across a disc so overlap/
## culling/draw-call behavior at each active count can actually be
## observed, not just a tidy grid that avoids the interesting cases. Fills
## slots [0, MAX_INSTANCE_COUNT - RESERVED_SPECIAL_SLOTS) -- the last
## RESERVED_SPECIAL_SLOTS are left for _place_special_test_instances().
func _scatter_instances() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345  # deterministic -- same scatter every run, easier to compare screenshots/runs
	var random_slot_count: int = MAX_INSTANCE_COUNT - RESERVED_SPECIAL_SLOTS
	for i: int in random_slot_count:
		var angle: float = rng.randf_range(0.0, TAU)
		var radius: float = sqrt(rng.randf()) * SCATTER_RADIUS  # sqrt for uniform area density, not center-biased
		var pos := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		_set_instance_at(i, pos, false)


## Story 4 slope/occlusion cases (Core Question Q3/new): 2 instances placed
## on the ramp backdrop object (slope grounding check) and 3 instances
## placed directly behind the Tower backdrop object as seen from the fixed
## camera (occlusion/depth-test check). Always in the last
## RESERVED_SPECIAL_SLOTS slots, excluded from the stress-count measurement
## by default (see set_active_count()'s own doc comment) so they don't
## skew the numbers, but toggleable via show_special_test_instances(true).
func _place_special_test_instances() -> void:
	var base: int = MAX_INSTANCE_COUNT - RESERVED_SPECIAL_SLOTS
	# Slope cases: on the Ramp backdrop object (see pilot.tscn), which rises
	# from y=0 to y=1.2 along its local Z. Hand-placed at 2 different heights
	# along the slope to check the shadow batch's flat Y-offset assumption
	# (investigation-2026-08-24-hybrid-swarm-rendering.md §5) visibly breaks
	# down off a flat plane -- expected, not a bug, but worth seeing directly
	# rather than assuming.
	_set_instance_at(base + 0, Vector3(-9.0, 0.3, -6.5), true)
	_set_instance_at(base + 1, Vector3(-9.0, 0.9, -8.0), true)
	# Occlusion cases: directly behind the Tower backdrop object (at
	# world (-6, 0, -3), see pilot.tscn) from the fixed camera's viewpoint --
	# depth-testing should hide these correctly, no special code needed if
	# GeometryInstance3D depth-writing/testing works as expected for a
	# MultiMesh batch mixed with regular opaque meshes in the same scene.
	_set_instance_at(base + 2, Vector3(-6.0, 0.5, -6.5), true)
	_set_instance_at(base + 3, Vector3(-6.3, 0.5, -6.8), true)
	_set_instance_at(base + 4, Vector3(-5.7, 0.5, -6.6), true)


func _set_instance_at(slot: int, pos: Vector3, on_slope: bool) -> void:
	var body_xform := Transform3D(Basis(), pos + Vector3(0.0, BODY_HEIGHT * 0.5, 0.0))
	_body_multimesh.set_instance_transform(slot, body_xform)
	_body_multimesh.set_instance_custom_data(slot, Color(2.0 if on_slope else 0.0, 0.0, 0.0, 0.0))  # slope/occlusion cases start on frame 2 (green) to stand out

	var shadow_basis := Basis(Vector3(1, 0, 0), -PI / 2.0)
	var shadow_y: float = pos.y - (BODY_HEIGHT * 0.5) + 0.02  # shadow sits at the body's own ground contact point, not always world y=0.02 -- still flat/unslanted regardless of what it's resting near, per the investigation's own "flat shadow-decal" recommendation
	var shadow_xform := Transform3D(shadow_basis, Vector3(pos.x, shadow_y, pos.z))
	_shadow_multimesh.set_instance_transform(slot, shadow_xform)


func _process(delta: float) -> void:
	_frame_timer += delta
	if _frame_timer >= FRAME_ADVANCE_SEC:
		_frame_timer = 0.0
		_current_frame = (_current_frame + 1) % FRAME_COUNT
		_apply_frame_to_random_slots()

	_flash_timer += delta
	if _flash_timer >= FLASH_INTERVAL_SEC:
		_flash_timer = 0.0
		_pulse_random_flash()


## Q2: every random-scatter instance advances the same frame in lockstep
## here (simplest proof the write path works at all) -- a real
## implementation would stagger per-instance animation phase (ADR-0038
## Story 3/Consequences: "modest animation phase offsets"), deliberately
## not attempted in this pilot pass. Special test slots are excluded --
## they keep their fixed frame so they stay visually identifiable across
## the whole run.
func _apply_frame_to_random_slots() -> void:
	var random_slot_count: int = MAX_INSTANCE_COUNT - RESERVED_SPECIAL_SLOTS
	for i: int in random_slot_count:
		var current: Color = _body_multimesh.get_instance_custom_data(i)
		_body_multimesh.set_instance_custom_data(i, Color(float(_current_frame), current.g, current.b, current.a))


## Q2: proves per-instance flash is independent -- only ~15% of instances
## flash at once, chosen fresh each pulse, so a screenshot shows some
## instances flashed white and most not, at the same shared frame index.
func _pulse_random_flash() -> void:
	var rng := RandomNumberGenerator.new()
	var random_slot_count: int = MAX_INSTANCE_COUNT - RESERVED_SPECIAL_SLOTS
	for i: int in random_slot_count:
		var current: Color = _body_multimesh.get_instance_custom_data(i)
		var flash: float = 1.0 if rng.randf() < 0.15 else 0.0
		var status: float = 1.0 if (i % 7 == 0) else 0.0  # fixed subset, proves the z-channel independently too
		_body_multimesh.set_instance_custom_data(i, Color(current.r, flash, status, current.a))
