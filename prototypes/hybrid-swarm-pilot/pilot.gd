extends Node3D

## Hybrid 3D-world / 2D-creature swarm rendering pilot (ADR-0038 Story 1-3).
## Prototype-quality code -- hardcoded values, no data-driven config, no
## dependency injection. See README.md for the questions this answers.

const INSTANCE_COUNT: int = 60
const ATLAS_COLS: int = 2
const ATLAS_ROWS: int = 2
const FRAME_COUNT: int = ATLAS_COLS * ATLAS_ROWS
const SCATTER_RADIUS: float = 6.0
const BODY_HEIGHT: float = 1.0
const BODY_WIDTH: float = 0.6
const FLASH_INTERVAL_SEC: float = 1.5
const FRAME_ADVANCE_SEC: float = 0.25

var _body_multimesh: MultiMesh
var _shadow_multimesh: MultiMesh
var _instance_positions: Array[Vector3] = []
var _frame_timer: float = 0.0
var _current_frame: int = 0
var _flash_timer: float = 0.0


func _ready() -> void:
	var atlas_tex: ImageTexture = _build_synthetic_atlas()
	_build_body_batch(atlas_tex)
	_build_shadow_batch()
	_scatter_instances()
	print("[pilot] %d instances spawned -- body + shadow batches, 2 draw calls total for the swarm" % INSTANCE_COUNT)


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
	_body_multimesh.instance_count = INSTANCE_COUNT

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
	_shadow_multimesh.instance_count = INSTANCE_COUNT

	var shader := load("res://prototypes/hybrid-swarm-pilot/creature_contact_shadow.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "ShadowBatch"
	mmi.multimesh = _shadow_multimesh
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## Q3/Q4 raw material: scatter instances across a disc so overlap/culling/
## draw-call behavior at a modest count can actually be observed, not just
## a tidy grid that avoids the interesting cases.
func _scatter_instances() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345  # deterministic -- same scatter every run, easier to compare screenshots
	_instance_positions.clear()
	for i: int in INSTANCE_COUNT:
		var angle: float = rng.randf_range(0.0, TAU)
		var radius: float = sqrt(rng.randf()) * SCATTER_RADIUS  # sqrt for uniform area density, not center-biased
		var pos := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		_instance_positions.append(pos)

		var body_xform := Transform3D(Basis(), pos + Vector3(0.0, BODY_HEIGHT * 0.5, 0.0))
		_body_multimesh.set_instance_transform(i, body_xform)
		_body_multimesh.set_instance_custom_data(i, Color(0.0, 0.0, 0.0, 0.0))  # frame=0, flash=0, status=0, facing=right

		var shadow_basis := Basis(Vector3(1, 0, 0), -PI / 2.0)
		var shadow_xform := Transform3D(shadow_basis, pos + Vector3(0.0, 0.02, 0.0))
		_shadow_multimesh.set_instance_transform(i, shadow_xform)


func _process(delta: float) -> void:
	_frame_timer += delta
	if _frame_timer >= FRAME_ADVANCE_SEC:
		_frame_timer = 0.0
		_current_frame = (_current_frame + 1) % FRAME_COUNT
		_apply_frame_to_all()

	_flash_timer += delta
	if _flash_timer >= FLASH_INTERVAL_SEC:
		_flash_timer = 0.0
		_pulse_random_flash()


## Q2: every instance advances the same frame in lockstep here (simplest
## proof the write path works at all) -- a real implementation would stagger
## per-instance animation phase (ADR-0038 Story 3/Consequences: "modest
## animation phase offsets"), deliberately not attempted in this pilot pass.
func _apply_frame_to_all() -> void:
	for i: int in INSTANCE_COUNT:
		var current: Color = _body_multimesh.get_instance_custom_data(i)
		_body_multimesh.set_instance_custom_data(i, Color(float(_current_frame), current.g, current.b, current.a))


## Q2: proves per-instance flash is independent -- only ~15% of instances
## flash at once, chosen fresh each pulse, so a screenshot shows some
## instances flashed white and most not, at the same shared frame index.
func _pulse_random_flash() -> void:
	var rng := RandomNumberGenerator.new()
	for i: int in INSTANCE_COUNT:
		var current: Color = _body_multimesh.get_instance_custom_data(i)
		var flash: float = 1.0 if rng.randf() < 0.15 else 0.0
		var status: float = 1.0 if (i % 7 == 0) else 0.0  # fixed subset, proves the z-channel independently too
		_body_multimesh.set_instance_custom_data(i, Color(current.r, flash, status, current.a))
