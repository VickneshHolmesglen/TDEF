## Gridless ranges (option C, ADR-0005 amendment 2026-11-04): tower range,
## splash, aura and stealth reveal are WorldRange circles between true positions
## (tower square centres, live monster positions), never cell distances.
extends GdUnitTestSuite

var _ts: TowerSystem
## entity_id -> live world position, read by the injected position source.
var _positions: Dictionary = {}
## The Hero's live position (a member: lambdas capture locals by value).
var _hero_pos: Vector2 = Vector2.INF


func before_test() -> void:
	_ts = TowerSystem.new()  # never enters the tree: no autoload wiring needed
	_positions = {}
	_ts.monster_position_source = func(id: int) -> Vector2:
		return _positions.get(id, Vector2.INF)


func after_test() -> void:
	_ts.free()


func _state(range_cells: int, projectile_type: String, at: Vector2) -> TowerMissionState:
	var state := TowerMissionState.new()
	state.tower_id = 1
	state.weapon = WeaponComponent.new()
	state.weapon.projectile_type = projectile_type
	state.focus = FocusComponent.new()
	state.focus.attack_range_cells = range_cells
	state.focus.cone_half_angle = 180.0
	state.world_position = at
	return state


func _monster(id: int, cell: Vector2i, live: Vector2) -> void:
	_ts._monster_cache[id] = {"cell": cell, "hp": 10.0, "is_armored": false, "path_step_index": 0}
	_positions[id] = live


func test_gridless_world_range_circle_keeps_the_old_square_area() -> void:
	for cells: int in [1, 3, 8]:
		var side: float = float(2 * cells + 1) * WorldRange.CELL_PX
		var r: float = WorldRange.radius_px(cells)
		assert_float(PI * r * r).is_equal_approx(side * side, 0.5)


func test_gridless_targeting_uses_live_monster_positions_not_cells() -> void:
	# Arrange: range 1 = 108 px circle around (500, 500).
	var state: TowerMissionState = _state(1, "HOMING", Vector2(500.0, 500.0))
	# Cached cell is far away but the monster is actually right next to the tower.
	_monster(1, Vector2i(30, 30), Vector2(560.0, 500.0))
	# Cached cell is next to the tower but the monster has moved out of range.
	_monster(2, Vector2i(7, 7), Vector2(650.0, 500.0))
	# Act
	var candidates: Array[int] = _ts._candidates_in_range(state)
	# Assert
	assert_array(candidates).contains_exactly([1])


func test_gridless_splash_reaches_monsters_sharing_the_primary_cell() -> void:
	# Arrange: aoe 1 = 108 px. The old Chebyshev rule skipped distance 0 (same cell).
	var state: TowerMissionState = _state(3, "BALLISTIC", Vector2(100.0, 100.0))
	state.weapon.aoe_radius_cells = 1
	_monster(1, Vector2i(5, 5), Vector2(352.0, 352.0))  # primary
	_monster(2, Vector2i(5, 5), Vector2(352.0, 352.0 + 54.0))  # same cell, half the radius away
	_monster(3, Vector2i(6, 5), Vector2(352.0 + 120.0, 352.0))  # next cell, outside 108 px
	# Act
	_ts._apply_splash_damage(state, 1, Vector2(352.0, 352.0), 100.0, false, false)
	# Assert: only monster 2, at falloff lerp(1.0, 0.4, 0.5) = 0.7.
	assert_float(state.damage_dealt).is_equal_approx(70.0, 0.5)


func test_gridless_aura_buffs_allies_by_square_centre_distance() -> void:
	# Arrange: aura 1 = 108 px around an off-grid support tower.
	var support: TowerMissionState = _state(1, "AURA", Vector2(200.0, 200.0))
	support.weapon.aura_effect_type = "damage_buff"
	support.weapon.aura_effect_value = 0.2
	support.weapon.aura_radius_cells = 1
	var near: TowerMissionState = _state(1, "HOMING", Vector2(300.0, 200.0))  # 100 px
	near.tower_id = 2
	var far: TowerMissionState = _state(1, "HOMING", Vector2(280.0, 290.0))   # 120 px (old Chebyshev 1)
	far.tower_id = 3
	_ts.placed_towers = {1: support, 2: near, 3: far}
	# Act
	_ts._apply_aura_pulse(support)
	# Assert
	assert_float(near.damage_buff_fraction).is_equal_approx(0.2, 0.0001)
	assert_float(far.damage_buff_fraction).is_equal(0.0)


func test_gridless_stealth_reveal_uses_the_live_hero_position() -> void:
	# Arrange: reveal radius 1 = 108 px.
	var state: TowerMissionState = _state(8, "HOMING", Vector2(0.0, 0.0))
	_monster(1, Vector2i(5, 5), Vector2(352.0, 352.0))
	(_ts._monster_cache[1] as Dictionary)["stealthed"] = true
	(_ts._monster_cache[1] as Dictionary)["reveal_radius"] = 1
	_hero_pos = Vector2(352.0 + 150.0, 352.0)
	_ts.hero_position_source = func() -> Vector2: return _hero_pos
	_ts._on_hero_position_changed(Vector2i(5, 5))  # the cached cell alone would reveal it
	var entry: Dictionary = _ts._monster_cache[1] as Dictionary
	# Act / Assert
	assert_bool(_ts.can_target(state, entry, 1)).is_false()
	_hero_pos = Vector2(352.0 + 80.0, 352.0)
	assert_bool(_ts.can_target(state, entry, 1)).is_true()
