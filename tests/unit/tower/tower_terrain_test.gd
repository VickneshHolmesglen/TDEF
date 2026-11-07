## Hill towers (spec 2026-11-07-3d-terrain §4.2): +25% price per level, the
## refund is 40% of the price paid, and every tower range gains +1 per level
## on top of the 8-cell cap.
extends GdUnitTestSuite

const BLUEPRINT_ID := &"hill_archer"
const CELL := 64.0
const HILL := Vector2i(3, 2)


class _StubPath extends RefCounted:
	func would_block_all_paths(_cells: Array) -> bool:
		return false


var _ts: TowerSystem


func _make_data(cost: int) -> TowerBlueprintData:
	var d := TowerBlueprintData.new()
	d.tower_id = BLUEPRINT_ID
	d.placement_cost = cost
	d.foundation = FoundationComponent.new()
	d.foundation.archetype = "physical"
	d.foundation.footprint = Vector2i.ONE
	d.foundation.hp_base = 100.0
	d.foundation.tier_multiplier = 1.0
	d.weapon = WeaponComponent.new()
	d.focus = FocusComponent.new()
	d.focus.cone_half_angle = 180.0
	d.focus.attack_range_cells = 8
	d.power = PowerComponent.new()
	return d


func before_test() -> void:
	GMissionEconomy._on_grid_initialized(0, 0, 0.0)
	GGrid.initialize(load("res://tests/unit/grid/grid_terrain_test.gd").make_config())
	_ts = TowerSystem.new()
	_ts._grid = GGrid
	_ts._pathfinding = _StubPath.new()
	_ts._tower_table[BLUEPRINT_ID] = _make_data(100)
	_ts._current_phase = TowerSystem.Phase.INTERMISSION
	GEventBus.resources_changed.emit(1000, &"test_setup")


func after_test() -> void:
	_ts.free()
	_ts = null
	var flat := GridConfig.new()
	GGrid.initialize(flat)
	GMissionEconomy._on_grid_initialized(0, 0, 0.0)


func test_hill_tower_costs_25_percent_more() -> void:
	var before: int = GMissionEconomy.get_gold_balance()
	assert_bool(_ts.place_tower_at(BLUEPRINT_ID, GGrid.cell_to_world(HILL))).is_true()
	var state: TowerMissionState = _ts.placed_towers.values()[0]
	assert_int(state.placement_cost).is_equal(125)
	assert_int(state.terrain_level).is_equal(1)
	assert_int(before - GMissionEconomy.get_gold_balance()).is_equal(125)


func test_flat_tower_costs_base() -> void:
	assert_bool(_ts.place_tower_at(BLUEPRINT_ID, GGrid.cell_to_world(Vector2i(0, 3)))).is_true()
	var state: TowerMissionState = _ts.placed_towers.values()[0]
	assert_int(state.placement_cost).is_equal(100)
	assert_int(state.terrain_level).is_equal(0)


func test_sell_refunds_40_percent_of_paid() -> void:
	_ts.place_tower_at(BLUEPRINT_ID, GGrid.cell_to_world(HILL))
	var id: int = _ts.placed_towers.keys()[0]
	var before: int = GMissionEconomy.get_gold_balance()
	assert_bool(_ts.sell_tower(id)).is_true()
	assert_int(GMissionEconomy.get_gold_balance() - before).is_equal(50)


func test_terrain_cost_and_range_formulas() -> void:
	assert_int(TowerSystem.terrain_cost(100, 0)).is_equal(100)
	assert_int(TowerSystem.terrain_cost(100, 2)).is_equal(150)
	assert_int(TowerSystem.terrain_cost(30, 1)).is_equal(38)
	assert_int(TowerSystem.terrain_range_bonus(0)).is_equal(0)
	assert_int(TowerSystem.terrain_range_bonus(2)).is_equal(2)


func test_hill_tower_attack_range_plus_one_above_cap() -> void:
	_ts.place_tower_at(BLUEPRINT_ID, GGrid.cell_to_world(HILL))
	var state: TowerMissionState = _ts.placed_towers.values()[0]
	var origin: Vector2 = state.world_position
	# Just past range 8, inside range 9.
	var far: Vector2 = origin + Vector2(WorldRange.radius_px(8) + 20.0, 0.0)
	assert_float(WorldRange.radius_px(9)).is_greater(far.x - origin.x)
	_ts.monster_position_source = func(_id: int) -> Vector2: return far
	_ts._monster_cache[1] = {"cell": Vector2i(20, 2), "hp": 10.0, "is_armored": false, "path_step_index": 0}
	assert_array(_ts._candidates_in_range(state)).contains_exactly([1])
	state.terrain_level = 0
	assert_array(_ts._candidates_in_range(state)).is_empty()


func test_hill_aura_radius_plus_one() -> void:
	var support := TowerMissionState.new()
	support.tower_id = 1
	support.terrain_level = 1
	support.weapon = WeaponComponent.new()
	support.weapon.aura_effect_type = "damage_buff"
	support.weapon.aura_effect_value = 0.2
	support.weapon.aura_radius_cells = 1
	support.world_position = Vector2(200.0, 200.0)
	var ally := TowerMissionState.new()
	ally.tower_id = 2
	ally.weapon = WeaponComponent.new()
	ally.world_position = Vector2(200.0 + WorldRange.radius_px(1) + 30.0, 200.0)
	_ts.placed_towers = {1: support, 2: ally}
	_ts._apply_aura_pulse(support)
	assert_float(ally.damage_buff_fraction).is_equal_approx(0.2, 0.0001)


func test_preview_cost_shows_hill_price() -> void:
	var preview: PlacementPreview = _ts.get_placement_preview_at(BLUEPRINT_ID, GGrid.cell_to_world(HILL))
	assert_bool(preview.valid).is_true()
	assert_int(preview.cost).is_equal(125)
	var flat: PlacementPreview = _ts.get_placement_preview_at(BLUEPRINT_ID, GGrid.cell_to_world(Vector2i(0, 3)))
	assert_int(flat.cost).is_equal(100)


func test_preview_invalid_on_mixed_heights() -> void:
	var preview: PlacementPreview = _ts.get_placement_preview_at(BLUEPRINT_ID, Vector2(3.0, 2.5) * CELL)
	assert_bool(preview.valid).is_false()
	assert_int(preview.reason).is_equal(PlacementPreview.PlacementBlockReason.FOOTPRINT_BLOCKED)


func test_hill_price_unaffordable_blocks() -> void:
	GMissionEconomy._on_grid_initialized(0, 0, 0.0)
	GEventBus.resources_changed.emit(110, &"test_setup")
	assert_bool(_ts.place_tower_at(BLUEPRINT_ID, GGrid.cell_to_world(HILL))).is_false()
	var preview: PlacementPreview = _ts.get_placement_preview_at(BLUEPRINT_ID, GGrid.cell_to_world(HILL))
	assert_int(preview.reason).is_equal(PlacementPreview.PlacementBlockReason.INSUFFICIENT_RESOURCES)
