## Integration tests for Hero movement & position tracking (S4-04, story-002,
## ADR-0010). Covers Rule 26 (omnidirectional movement), Rule 27 (collision with
## BLOCKED/tower-occupied cells), Rule 28 (grid-cell-change position tracking +
## hero_position_changed emission), and AC-14 (structural/negative check here —
## complemented by a live-engine manual verification, closed 2026-07-07, in
## production/qa/evidence/hero-goal-cell-evidence.md).
##
## SCOPE BOUNDARY (Rule 27 fixture — same pattern as S4-01's stub-fixture tests):
## No tilemap/Grid-cell-type-to-collision-shape mapping exists yet — that's S4-09's
## job (mission scene assembly). This suite proves the real collision MECHANICS that
## story-002 owns: a Hero (CharacterBody2D, real collision shape built in _ready())
## is physically stopped by a StaticBody2D obstacle via move_and_slide(). It does
## NOT prove that a BLOCKED Grid cell or a placed tower actually has a collider at
## that position in the shipped game — that integration is S4-09's responsibility.
## The two Rule-27 tests below (environment obstacle / tower-occupied obstacle) are
## intentionally mechanically identical: Rule 27's two sub-cases resolve to the same
## physics behavior (a body on COLLISION_LAYER_ENVIRONMENT blocks the hero), so one
## fixture mechanism legitimately covers both semantic edge cases.
##
## Rule 27 fixture note: hero._process() (input polling) is disabled via
## set_process(false) after add_child() so the real Input singleton (no keys
## pressed in a headless test run) doesn't overwrite the directly-set
## _input_direction test seam every frame. This does not weaken Rule 26 coverage —
## Rule 26's own tests call _handle_movement() directly and do not depend on
## _process() at all.
extends GdUnitTestSuite

const CELL_SIZE: float = 64.0  # matches GGrid._cell_size default and MonsterManager.CELL_SIZE

var _hero: Hero
var _obstacle: StaticBody2D
var _spy: EventBusSpy


func after_test() -> void:
	if _spy != null:
		_spy.disconnect_all()
		_spy = null
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null
	if _obstacle != null and is_instance_valid(_obstacle):
		if _obstacle.is_inside_tree():
			_obstacle.get_parent().remove_child(_obstacle)
		_obstacle.free()
	_obstacle = null


func _make_hero() -> Hero:
	_hero = Hero.new()
	add_child(_hero)  # triggers _ready(): collision shape + layer/mask set up
	_hero._base_stats[&"move_speed"] = 200.0
	return _hero


func _make_obstacle(center: Vector2, half_extents: Vector2) -> StaticBody2D:
	_obstacle = StaticBody2D.new()
	_obstacle.collision_layer = Hero.COLLISION_LAYER_ENVIRONMENT
	_obstacle.collision_mask = 0
	_obstacle.global_position = center
	var shape := RectangleShape2D.new()
	shape.size = half_extents * 2.0
	var collision_shape := CollisionShape2D.new()
	collision_shape.shape = shape
	_obstacle.add_child(collision_shape)
	add_child(_obstacle)
	return _obstacle


# ---------------------------------------------------------------------------
# Rule 26: movement velocity
# ---------------------------------------------------------------------------

func test_movement_single_axis_input_sets_velocity_along_axis_only() -> void:
	# Given: Hero with move_speed = 200.0, directional input (right)
	var hero := _make_hero()
	hero._input_direction = Vector2(1.0, 0.0)

	# When: _handle_movement() runs (the movement half of _physics_process)
	hero._handle_movement()

	# Then: velocity.x ~= 200.0, velocity.y = 0.0 (normalized single-axis)
	assert_float(hero.velocity.x).is_equal_approx(200.0, 0.01)
	assert_float(hero.velocity.y).is_equal_approx(0.0, 0.0001)


func test_movement_diagonal_input_normalizes_velocity_magnitude() -> void:
	# Edge case: diagonal input -> velocity.length() ~= 200.0 (normalized, not 200 x sqrt(2))
	var hero := _make_hero()
	hero._input_direction = Vector2(1.0, 1.0)  # unnormalized raw diagonal

	hero._handle_movement()

	assert_float(hero.velocity.length()).is_equal_approx(200.0, 0.01)


func test_movement_zero_input_produces_zero_velocity() -> void:
	# Edge case: no input -> Vector2.ZERO.normalized() must not error and velocity stays zero.
	var hero := _make_hero()
	hero._input_direction = Vector2.ZERO

	hero._handle_movement()

	assert_vector(hero.velocity).is_equal(Vector2.ZERO)


func test_process_reads_real_input_singleton_and_sets_input_direction() -> void:
	# Regression (found during code review): all other tests set _input_direction
	# directly or disable _process() via set_process(false), so the real
	# Input.get_vector() polling path -- the one actually used every frame in
	# the shipped game -- had zero coverage. Input.action_press()/release()
	# set the Input singleton's action state directly and work in headless
	# mode (unlike real InputEvent dispatch, which gdUnit4 warns is not
	# transported headless).
	var hero := _make_hero()

	Input.action_press(&"move_right")
	hero._process(0.016)
	assert_vector(hero._input_direction).is_equal_approx(Vector2(1.0, 0.0), Vector2(0.0001, 0.0001))
	Input.action_release(&"move_right")

	Input.action_press(&"move_up")
	hero._process(0.016)
	assert_vector(hero._input_direction).is_equal_approx(Vector2(0.0, -1.0), Vector2(0.0001, 0.0001))
	Input.action_release(&"move_up")

	hero._process(0.016)
	assert_vector(hero._input_direction).is_equal(Vector2.ZERO)


# ---------------------------------------------------------------------------
# Rule 27: collision with BLOCKED / tower-occupied cells (see scope boundary
# note in the file header — same StaticBody2D fixture mechanism for both).
# ---------------------------------------------------------------------------

func test_rule27_hero_blocked_by_environment_obstacle_stops_at_boundary() -> void:
	# Given: Hero positioned to the left of a BLOCKED-cell-representative obstacle
	var hero := _make_hero()
	hero.global_position = Vector2(0.0, 0.0)
	hero.set_process(false)  # see file header note — avoids real-Input overwrite
	hero._input_direction = Vector2(1.0, 0.0)  # input drives hero toward the obstacle

	var obstacle_center := Vector2(100.0, 0.0)
	_make_obstacle(obstacle_center, Vector2(32.0, 32.0))  # 64x64, one grid cell

	# When: physics runs until the hero settles against the obstacle
	for _tick: int in range(120):
		await get_tree().physics_frame

	# Then: hero stops at the cell boundary -- does not enter the obstacle interior.
	var obstacle_left_edge: float = obstacle_center.x - 32.0
	assert_float(hero.global_position.x).is_less(obstacle_left_edge)
	# Sanity: the hero actually moved (proves the fixture isn't just stuck at start).
	assert_float(hero.global_position.x).is_greater(50.0)


func test_rule27_hero_blocked_by_tower_occupied_obstacle_stops_at_boundary() -> void:
	# Edge case: tower-occupied PLACEABLE cell also blocks movement. Mechanically
	# identical to the environment-obstacle case above (see file header scope note) --
	# both are a COLLISION_LAYER_ENVIRONMENT body blocking move_and_slide().
	var hero := _make_hero()
	hero.global_position = Vector2(0.0, 0.0)
	hero.set_process(false)
	hero._input_direction = Vector2(1.0, 0.0)

	var obstacle_center := Vector2(100.0, 0.0)
	_make_obstacle(obstacle_center, Vector2(32.0, 32.0))  # stands in for a placed tower's body

	for _tick: int in range(120):
		await get_tree().physics_frame

	var obstacle_left_edge: float = obstacle_center.x - 32.0
	assert_float(hero.global_position.x).is_less(obstacle_left_edge)
	assert_float(hero.global_position.x).is_greater(50.0)


# ---------------------------------------------------------------------------
# Rule 28: cell boundary emission
# ---------------------------------------------------------------------------

func test_position_tracking_first_call_emits_current_cell() -> void:
	# Given: fresh Hero (_prev_cell sentinel = (-1,-1)) positioned in cell (5,5)
	var hero := _make_hero()
	hero.global_position = GGrid.cell_to_world(Vector2i(5, 5))
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_position_changed)

	# When: _update_position_tracking() runs (the tracking half of _physics_process)
	hero._update_position_tracking()
	await get_tree().process_frame  # flush the deferred emit (ADR-0001 Rule 2)

	# Then: hero_position_changed fires once with Vector2i(5, 5)
	assert_int(_spy.count("hero_position_changed")).is_equal(1)
	var args: Array = (_spy.emissions["hero_position_changed"] as Array)[0] as Array
	assert_vector(Vector2(args[0] as Vector2i)).is_equal(Vector2(Vector2i(5, 5)))


func test_position_tracking_sub_cell_movement_does_not_emit() -> void:
	# Edge case: sub-cell movement within the same cell -- NO emission.
	var hero := _make_hero()
	hero.global_position = GGrid.cell_to_world(Vector2i(5, 5))
	hero._update_position_tracking()
	await get_tree().process_frame

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_position_changed)

	# Nudge a few world units -- still inside cell (5,5) at cell_size=64.
	hero.global_position += Vector2(5.0, 5.0)
	hero._update_position_tracking()
	await get_tree().process_frame

	assert_int(_spy.count("hero_position_changed")).is_equal(0)


func test_position_tracking_cell_change_emits_once_with_new_cell() -> void:
	# Given: Hero at cell (5, 5); _prev_cell = Vector2i(5, 5)
	var hero := _make_hero()
	hero.global_position = GGrid.cell_to_world(Vector2i(5, 5))
	hero._update_position_tracking()
	await get_tree().process_frame

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_position_changed)

	# When: hero moves to cell (6, 5) in the next frame
	hero.global_position = GGrid.cell_to_world(Vector2i(6, 5))
	hero._update_position_tracking()
	await get_tree().process_frame

	# Then: hero_position_changed fires once with Vector2i(6, 5)
	assert_int(_spy.count("hero_position_changed")).is_equal(1)
	var args: Array = (_spy.emissions["hero_position_changed"] as Array)[0] as Array
	assert_vector(Vector2(args[0] as Vector2i)).is_equal(Vector2(Vector2i(6, 5)))


func test_position_tracking_return_to_previous_cell_emits_again() -> void:
	# Edge case: hero returns to the same cell next frame after going over a
	# boundary -- emission on change, not on a "seen before" count.
	var hero := _make_hero()
	hero.global_position = GGrid.cell_to_world(Vector2i(5, 5))
	hero._update_position_tracking()
	await get_tree().process_frame

	hero.global_position = GGrid.cell_to_world(Vector2i(6, 5))
	hero._update_position_tracking()
	await get_tree().process_frame

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_position_changed)

	hero.global_position = GGrid.cell_to_world(Vector2i(5, 5))
	hero._update_position_tracking()
	await get_tree().process_frame

	assert_int(_spy.count("hero_position_changed")).is_equal(1)
	var args: Array = (_spy.emissions["hero_position_changed"] as Array)[0] as Array
	assert_vector(Vector2(args[0] as Vector2i)).is_equal(Vector2(Vector2i(5, 5)))


# ---------------------------------------------------------------------------
# AC-14: structural/negative check (automatable slice only -- see file header
# and story Test Evidence section for the deferred manual evidence doc).
# ---------------------------------------------------------------------------

func test_ac14_hero_script_has_no_body_entered_handler_or_breach_emission() -> void:
	var file := FileAccess.open("res://src/core/hero/hero.gd", FileAccess.READ)
	assert_object(file).is_not_null()
	var source: String = file.get_as_text()
	file.close()

	assert_bool(source.contains("monster_breached")).is_false()
	assert_bool(source.contains("body_entered")).is_false()
