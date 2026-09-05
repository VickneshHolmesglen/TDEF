extends GdUnitTestSuite

## tower.md Rule 23 (TowerWaveSummary) tests — TD-tower-010 regression coverage.
## Covers: HP reset on wave_completed, per-wave counter accuracy, counter
## reset on the next wave_started, AURA/SCATTER-specific fields, and
## one-summary-per-active-tower.

# ---------------------------------------------------------------------------
# Stubs (mirrors tower_combat_test.gd's own stubs — see that file's comments
# for why each override exists)
# ---------------------------------------------------------------------------

class _StubGrid extends RefCounted:
	const CELL_SIZE: float = 64.0

	func is_footprint_placeable(_top_left: Vector2i, _size: Vector2i) -> bool:
		return true

	func place_tower(_tower_id: int, _top_left: Vector2i, _size: Vector2i) -> int:
		return OK

	func remove_tower(_tower_id: int) -> void:
		pass

	func cell_to_world(cell: Vector2i) -> Vector2:
		return Vector2(cell.x * CELL_SIZE + CELL_SIZE * 0.5, cell.y * CELL_SIZE + CELL_SIZE * 0.5)

	func world_to_cell(world_pos: Vector2) -> Vector2i:
		return Vector2i(int(floor(world_pos.x / CELL_SIZE)), int(floor(world_pos.y / CELL_SIZE)))


class _StubPath extends RefCounted:
	func would_block_all_paths(_cells: Array) -> bool:
		return false


class _StubProjectileManager extends ProjectileManager:
	func fire(tower_id: int, _projectile_type: StringName, _origin: Vector2,
			target_entity_id: int, target_position: Vector2, damage_payload: Dictionary) -> bool:
		var arrival_cell: Vector2i = _tower_system.world_to_cell(target_position)
		_tower_system.on_projectile_arrived(tower_id, target_entity_id, arrival_cell, damage_payload)
		return true


# ---------------------------------------------------------------------------
# Setup helpers
# ---------------------------------------------------------------------------

const DELTA: float = 1.0 / 60.0
const BLUEPRINT_ID := &"test_tower"

var _ts: TowerSystem
var _spy: EventBusSpy


func _make_ts() -> TowerSystem:
	var ts := TowerSystem.new()
	ts._grid = _StubGrid.new()
	ts._pathfinding = _StubPath.new()
	var pm := _StubProjectileManager.new()
	pm._tower_system = ts
	ts._projectile_manager = pm
	return ts


func _make_data(weapon_damage: float = 35.0, attack_speed: float = 2.0,
		hp_base: float = 100.0, targeting_mode: String = "LOWEST_HP",
		archetype: String = "physical") -> TowerBlueprintData:
	var d := TowerBlueprintData.new()
	d.tower_id = BLUEPRINT_ID
	d.placement_cost = 10
	d.foundation = FoundationComponent.new()
	d.foundation.archetype = archetype
	d.foundation.tier = 1
	d.foundation.footprint = Vector2i(1, 1)
	d.foundation.tier_dps_multiplier = 1.0
	d.foundation.tier_boss_dps_multiplier = 1.0
	d.foundation.hp_base = hp_base
	d.foundation.tier_multiplier = 1.0
	d.weapon = WeaponComponent.new()
	d.weapon.weapon_damage = weapon_damage
	d.weapon.attack_speed = attack_speed
	d.weapon.projectile_type = "BEAM"  # immediate/synchronous — see tower_combat_test.gd's own comment
	d.focus = FocusComponent.new()
	d.focus.attack_range_cells = 10
	d.focus.cone_half_angle = 180.0
	d.focus.targeting_mode = targeting_mode
	d.power = PowerComponent.new()
	return d


func _place(ts: TowerSystem, data: TowerBlueprintData, cell: Vector2i = Vector2i(8, 6)) -> int:
	ts._tower_table[data.tower_id] = data
	GEventBus.resources_changed.emit(9999, &"test_setup")
	ts._current_phase = TowerSystem.Phase.INTERMISSION
	ts.place_tower(data.tower_id, cell)
	if ts.placed_towers.is_empty():
		return -1
	return ts.placed_towers.keys()[0] as int


func before_test() -> void:
	GMissionEconomy._on_grid_initialized(0, 0, 0.0)
	_ts = _make_ts()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.tower_wave_summary)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	_ts.free()
	_ts = null
	GMissionEconomy._on_grid_initialized(0, 0, 0.0)

# ---------------------------------------------------------------------------
# Rule 23: HP reset on wave_completed
# ---------------------------------------------------------------------------

func test_wave_completed_resets_damaged_tower_hp_to_max() -> void:
	var data: TowerBlueprintData = _make_data(35.0, 2.0, 200.0)
	var tower_id: int = _place(_ts, data)

	_ts._on_boss_tower_attack_attempted(99, tower_id, 150.0, 1)
	var state: TowerMissionState = _ts.placed_towers[tower_id] as TowerMissionState
	assert_float(state.current_hp).is_equal_approx(50.0, 0.001)

	_ts._on_wave_completed(1, 0, false)

	assert_float(state.current_hp).is_equal_approx(200.0, 0.001)


func test_wave_completed_summary_max_hp_matches_foundation_formula() -> void:
	var data: TowerBlueprintData = _make_data(35.0, 2.0, 200.0)
	_place(_ts, data)

	_ts._on_wave_completed(1, 0, false)

	assert_bool(_spy.was_emitted("tower_wave_summary")).is_true()
	var emissions: Array = _spy.emissions.get("tower_wave_summary", []) as Array
	var summary: TowerWaveSummary = emissions[0][0] as TowerWaveSummary
	assert_float(summary.max_hp).is_equal_approx(200.0, 0.001)

# ---------------------------------------------------------------------------
# Rule 23: counter accuracy (shots_fired, idle_ticks, damage_dealt)
# ---------------------------------------------------------------------------

func test_shots_fired_and_damage_dealt_accumulate_on_successful_attacks() -> void:
	var data: TowerBlueprintData = _make_data(35.0, 2.0, 100.0)
	var tower_id: int = _place(_ts, data, Vector2i(8, 6))
	var state: TowerMissionState = _ts.placed_towers[tower_id] as TowerMissionState

	_ts._monster_cache[1] = {"cell": Vector2i(10, 6), "hp": 9999.0, "is_armored": false}
	_ts._current_phase = TowerSystem.Phase.WAVE_ACTIVE

	# 600 frames = 10s at attack_speed=2.0 -> 20 successful attacks
	for _i: int in range(600):
		_ts._tick_combat(DELTA)
	await get_tree().process_frame

	assert_int(state.shots_fired).is_equal(20)
	assert_float(state.damage_dealt).is_equal_approx(700.0, 0.001)
	assert_int(state.idle_ticks).is_equal(0)


func test_idle_ticks_increments_when_no_target_in_range() -> void:
	var data: TowerBlueprintData = _make_data(35.0, 2.0, 100.0)
	var tower_id: int = _place(_ts, data, Vector2i(8, 6))
	var state: TowerMissionState = _ts.placed_towers[tower_id] as TowerMissionState

	# No monster in cache at all -- every attack-timer expiry finds no target.
	_ts._current_phase = TowerSystem.Phase.WAVE_ACTIVE

	for _i: int in range(60):
		_ts._tick_combat(DELTA)
	await get_tree().process_frame

	assert_int(state.shots_fired).is_equal(0)
	assert_int(state.idle_ticks).is_greater(0)

# ---------------------------------------------------------------------------
# Rule 23: counters reset on the next wave_started
# ---------------------------------------------------------------------------

func test_counters_reset_on_wave_started() -> void:
	var data: TowerBlueprintData = _make_data(35.0, 2.0, 100.0)
	var tower_id: int = _place(_ts, data, Vector2i(8, 6))
	var state: TowerMissionState = _ts.placed_towers[tower_id] as TowerMissionState

	_ts._monster_cache[1] = {"cell": Vector2i(10, 6), "hp": 9999.0, "is_armored": false}
	_ts._current_phase = TowerSystem.Phase.WAVE_ACTIVE
	_ts._tick_combat(DELTA)
	await get_tree().process_frame

	assert_int(state.shots_fired).is_greater(0)

	_ts._on_wave_started(2, 5, 1.0)

	assert_int(state.shots_fired).is_equal(0)
	assert_float(state.damage_dealt).is_equal_approx(0.0, 0.001)
	assert_int(state.idle_ticks).is_equal(0)
	assert_int(state.aura_applications_this_wave).is_equal(0)
	assert_bool(state.scatter_target_cycle.is_empty()).is_true()

# ---------------------------------------------------------------------------
# Rule 23: AURA-specific field
# ---------------------------------------------------------------------------

func test_aura_applications_increments_for_support_tower() -> void:
	var data: TowerBlueprintData = _make_data(35.0, 1.0, 100.0, "LOWEST_HP", "support")
	data.weapon.projectile_type = "AURA"
	var tower_id: int = _place(_ts, data, Vector2i(8, 6))
	var state: TowerMissionState = _ts.placed_towers[tower_id] as TowerMissionState

	_ts._current_phase = TowerSystem.Phase.WAVE_ACTIVE
	for _i: int in range(60):
		_ts._tick_combat(DELTA)

	assert_int(state.aura_applications_this_wave).is_greater(0)
	assert_int(state.shots_fired).is_equal(0)  # AURA never takes the shots_fired path

# ---------------------------------------------------------------------------
# Rule 23: SCATTER-specific field
# ---------------------------------------------------------------------------

func test_scatter_target_cycle_tracks_hit_counts_per_target() -> void:
	var data: TowerBlueprintData = _make_data(35.0, 2.0, 100.0, "SCATTER")
	var tower_id: int = _place(_ts, data, Vector2i(0, 0))
	var state: TowerMissionState = _ts.placed_towers[tower_id] as TowerMissionState

	_ts._monster_cache[10] = {"cell": Vector2i(3, 3), "hp": 9999.0, "is_armored": false}
	_ts._monster_cache[20] = {"cell": Vector2i(4, 4), "hp": 9999.0, "is_armored": false}
	_ts._current_phase = TowerSystem.Phase.WAVE_ACTIVE

	for _i: int in range(120):
		_ts._tick_combat(DELTA)
	await get_tree().process_frame

	assert_bool(state.scatter_target_cycle.has(10)).is_true()
	assert_bool(state.scatter_target_cycle.has(20)).is_true()

# ---------------------------------------------------------------------------
# Rule 23: one summary per active tower
# ---------------------------------------------------------------------------

func test_wave_completed_emits_one_summary_per_active_tower() -> void:
	var data_a: TowerBlueprintData = _make_data(35.0, 2.0, 100.0)
	data_a.tower_id = &"tower_a"
	var data_b: TowerBlueprintData = _make_data(35.0, 2.0, 100.0)
	data_b.tower_id = &"tower_b"
	_place(_ts, data_a, Vector2i(0, 0))
	_place(_ts, data_b, Vector2i(5, 5))

	_ts._on_wave_completed(1, 0, false)

	var emissions: Array = _spy.emissions.get("tower_wave_summary", []) as Array
	assert_int(emissions.size()).is_equal(2)
