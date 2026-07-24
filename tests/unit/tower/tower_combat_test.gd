extends GdUnitTestSuite

## Tower combat tests.
## Covers: AC-9 through AC-22, AC-29.
## DPS formula, range/cone, HP/destruction, targeting, monster cache.

# ---------------------------------------------------------------------------
# Stubs
# ---------------------------------------------------------------------------

class _StubGrid extends RefCounted:
	var towers_placed: Array[int] = []
	var towers_removed: Array[int] = []

	func is_footprint_placeable(_top_left: Vector2i, _size: Vector2i) -> bool:
		return true

	func place_tower(tower_id: int, _top_left: Vector2i, _size: Vector2i) -> int:
		towers_placed.append(tower_id)
		return OK

	func remove_tower(tower_id: int) -> void:
		towers_removed.append(tower_id)


class _StubPath extends RefCounted:
	func would_block_all_paths(_cells: Array) -> bool:
		return false


# ---------------------------------------------------------------------------
# Setup helpers
# ---------------------------------------------------------------------------

const DELTA: float = 1.0 / 60.0
const BLUEPRINT_ID := &"test_tower"

var _ts: TowerSystem
var _grid: _StubGrid
var _spy: EventBusSpy


func _make_ts() -> TowerSystem:
	var ts := TowerSystem.new()
	ts._grid = _StubGrid.new()
	ts._pathfinding = _StubPath.new()
	return ts


func _make_data(weapon_damage: float = 35.0, attack_speed: float = 2.0,
		tier_dps_mult: float = 1.0, range_cells: int = 4,
		cone: float = 180.0, tier: int = 1,
		hp_base: float = 100.0, hp_mult: float = 1.0) -> TowerBlueprintData:
	var d := TowerBlueprintData.new()
	d.tower_id = BLUEPRINT_ID
	d.placement_cost = 10
	d.foundation = FoundationComponent.new()
	d.foundation.archetype = "physical"
	d.foundation.tier = tier
	d.foundation.footprint = Vector2i(1, 1)
	d.foundation.tier_dps_multiplier = tier_dps_mult
	d.foundation.tier_boss_dps_multiplier = 1.0 if tier < 4 else 2.0
	d.foundation.hp_base = hp_base
	d.foundation.tier_multiplier = hp_mult
	d.weapon = WeaponComponent.new()
	d.weapon.weapon_damage = weapon_damage
	d.weapon.attack_speed = attack_speed
	d.focus = FocusComponent.new()
	d.focus.attack_range_cells = range_cells
	d.focus.cone_half_angle = cone
	d.power = PowerComponent.new()
	return d


func _place(ts: TowerSystem, data: TowerBlueprintData, cell: Vector2i = Vector2i(8, 6)) -> int:
	ts._tower_table[data.tower_id] = data
	GEventBus.resources_changed.emit(9999, &"test_setup")  # seeds GMissionEconomy
	ts._current_phase = TowerSystem.Phase.INTERMISSION
	ts.place_tower(data.tower_id, cell)
	if ts.placed_towers.is_empty():
		return -1
	return ts.placed_towers.keys()[0] as int


func before_test() -> void:
	# Reset the real GMissionEconomy Autoload to a known 0 baseline before
	# seeding — same convention as tests/integration/core/mission_economy_test.gd.
	GEventBus.mission_launched.emit("test_mission", PackedStringArray(), 1)
	_ts = _make_ts()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.tower_attacked)
	_spy.watch(GEventBus.tower_destroyed)
	_spy.watch(GEventBus.tower_damaged)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	_ts.free()  # TD-tower-002 fix: _ts is a Node, never added to the tree — .free() (not queue_free()) frees it immediately, closing the orphan-node gap
	_ts = null
	GEventBus.mission_launched.emit("test_mission", PackedStringArray(), 1)  # reset GMissionEconomy for next suite

# ---------------------------------------------------------------------------
# AC-9/10: DPS formula
# ---------------------------------------------------------------------------

func test_compute_dps_t1_returns_70() -> void:
	var data: TowerBlueprintData = _make_data(35.0, 2.0, 1.0)
	assert_float(_ts.compute_dps(data.weapon, data.foundation)).is_equal_approx(70.0, 0.001)


func test_compute_dps_t2_mult_1_6_returns_112() -> void:
	var data: TowerBlueprintData = _make_data(35.0, 2.0, 1.6)
	assert_float(_ts.compute_dps(data.weapon, data.foundation)).is_equal_approx(112.0, 0.001)


func test_compute_dps_t3_mult_2_4_returns_168() -> void:
	var data: TowerBlueprintData = _make_data(35.0, 2.0, 2.4)
	assert_float(_ts.compute_dps(data.weapon, data.foundation)).is_equal_approx(168.0, 0.001)


func test_compute_dps_t4_mult_4_0_returns_280() -> void:
	var data: TowerBlueprintData = _make_data(35.0, 2.0, 4.0)
	assert_float(_ts.compute_dps(data.weapon, data.foundation)).is_equal_approx(280.0, 0.001)

# ---------------------------------------------------------------------------
# AC-11: Continuous fire 10 seconds T1 (70 dps) → 700 total damage
# ---------------------------------------------------------------------------

func test_continuous_fire_t1_10_seconds_total_damage_700() -> void:
	var data: TowerBlueprintData = _make_data(35.0, 2.0, 1.0)
	_place(_ts, data, Vector2i(8, 6))

	# Inject a monster in range so the tower has a target
	_ts._monster_cache[1] = {"cell": Vector2i(10, 6), "hp": 9999.0, "is_armored": false}
	_ts._current_phase = TowerSystem.Phase.WAVE_ACTIVE

	# 600 frames = 10 seconds at delta = 1/60
	for _i: int in range(600):
		_ts._tick_combat(DELTA)
	await get_tree().process_frame  # Flush deferred tower_attacked emits (ADR-0001 Rule 2)

	var total_damage: float = 0.0
	var emissions: Array = _spy.emissions.get("tower_attacked", []) as Array
	for emission: Array in emissions:
		total_damage += emission[2] as float  # damage_amount is arg index 2

	# 20 attacks × 35 damage = 700 (timer starts at 0, fires on frame 1)
	assert_float(total_damage).is_between(699.0, 701.0)


# ---------------------------------------------------------------------------
# AC-12: Continuous fire 10 seconds T2 (112 dps) → 1120 total damage
# ---------------------------------------------------------------------------

func test_continuous_fire_t2_10_seconds_total_damage_1120() -> void:
	var data: TowerBlueprintData = _make_data(35.0, 2.0, 1.6)
	_place(_ts, data, Vector2i(8, 6))

	_ts._monster_cache[1] = {"cell": Vector2i(10, 6), "hp": 9999.0, "is_armored": false}
	_ts._current_phase = TowerSystem.Phase.WAVE_ACTIVE

	for _i: int in range(600):
		_ts._tick_combat(DELTA)
	await get_tree().process_frame  # Flush deferred tower_attacked emits (ADR-0001 Rule 2)

	var total_damage: float = 0.0
	var emissions: Array = _spy.emissions.get("tower_attacked", []) as Array
	for emission: Array in emissions:
		total_damage += emission[2] as float

	# 20 attacks × 56 damage = 1120
	assert_float(total_damage).is_between(1119.0, 1121.0)

# ---------------------------------------------------------------------------
# AC-13: Range=4, cone=180°, Chebyshev=5 → out of range
# ---------------------------------------------------------------------------

func test_is_in_range_chebyshev5_range4_cone180_returns_false() -> void:
	var data: TowerBlueprintData = _make_data(35.0, 2.0, 1.0, 4, 180.0)
	# Tower at (8,6), enemy at (13,6): Chebyshev = |13-8| = 5 > 4
	assert_bool(_ts.is_in_range(Vector2i(8, 6), Vector2i(13, 6), data.focus)).is_false()

# ---------------------------------------------------------------------------
# AC-14: Narrow cone 30° bonus +2: Chebyshev=5 ≤ effective_range=6 → in range
# ---------------------------------------------------------------------------

func test_is_in_range_cone30_grants_plus2_range() -> void:
	var data: TowerBlueprintData = _make_data(35.0, 2.0, 1.0, 4, 30.0)
	# Effective range = 4+2 = 6; Chebyshev = 5 ≤ 6 → true
	assert_bool(_ts.is_in_range(Vector2i(8, 6), Vector2i(13, 6), data.focus)).is_true()

# ---------------------------------------------------------------------------
# AC-15: Cone=90° (no bonus): Chebyshev=5 > range=4 → out of range
# ---------------------------------------------------------------------------

func test_is_in_range_cone90_no_bonus_chebyshev5_returns_false() -> void:
	var data: TowerBlueprintData = _make_data(35.0, 2.0, 1.0, 4, 90.0)
	assert_bool(_ts.is_in_range(Vector2i(8, 6), Vector2i(13, 6), data.focus)).is_false()

# ---------------------------------------------------------------------------
# AC-16: Chebyshev exactly == attack_range_cells → in range (inclusive)
# ---------------------------------------------------------------------------

func test_is_in_range_chebyshev_equals_range_returns_true() -> void:
	var data: TowerBlueprintData = _make_data(35.0, 2.0, 1.0, 4, 180.0)
	# Tower (8,6), enemy (12,6): Chebyshev = 4 == 4 → true
	assert_bool(_ts.is_in_range(Vector2i(8, 6), Vector2i(12, 6), data.focus)).is_true()

# ---------------------------------------------------------------------------
# AC-17: Chebyshev == attack_range_cells + 1 → out of range
# ---------------------------------------------------------------------------

func test_is_in_range_chebyshev_one_past_range_returns_false() -> void:
	var data: TowerBlueprintData = _make_data(35.0, 2.0, 1.0, 4, 180.0)
	# Tower (8,6), enemy (13,6): Chebyshev = 5 = 4+1 → false
	assert_bool(_ts.is_in_range(Vector2i(8, 6), Vector2i(13, 6), data.focus)).is_false()

# ---------------------------------------------------------------------------
# AC-18: hp_base=220, tier_multiplier=1.5 → max_hp=330.0
# ---------------------------------------------------------------------------

func test_tower_max_hp_formula_220_x_1_5_equals_330() -> void:
	var data: TowerBlueprintData = _make_data(35.0, 2.0, 1.0, 4, 180.0, 1, 220.0, 1.5)
	var tower_id: int = _place(_ts, data)
	assert_int(tower_id).is_not_equal(-1)
	var state: TowerMissionState = _ts.placed_towers[tower_id] as TowerMissionState
	assert_float(state.max_hp).is_equal_approx(330.0, 0.001)
	assert_float(state.current_hp).is_equal_approx(330.0, 0.001)

# ---------------------------------------------------------------------------
# AC-19: Tower at 120 HP takes 120 damage → DESTROYED, tower_destroyed fires
# ---------------------------------------------------------------------------

func test_boss_lethal_damage_destroys_tower_and_emits_tower_destroyed() -> void:
	var data: TowerBlueprintData = _make_data(35.0, 2.0, 1.0, 4, 180.0, 1, 120.0, 1.0)
	var tower_id: int = _place(_ts, data)

	_ts._on_boss_tower_attack_attempted(99, tower_id, 120.0, 1)

	assert_bool(_spy.was_emitted("tower_destroyed")).is_true()
	assert_bool(_spy.was_emitted("tower_damaged")).is_false()
	assert_bool(_ts.placed_towers.has(tower_id)).is_false()
	var ts_grid: _StubGrid = _ts._grid as _StubGrid
	assert_bool(tower_id in ts_grid.towers_removed).is_true()


func test_boss_non_lethal_damage_emits_tower_damaged_not_destroyed() -> void:
	var data: TowerBlueprintData = _make_data(35.0, 2.0, 1.0, 4, 180.0, 1, 200.0, 1.0)
	var tower_id: int = _place(_ts, data)

	_ts._on_boss_tower_attack_attempted(99, tower_id, 50.0, 1)

	assert_bool(_spy.was_emitted("tower_damaged")).is_true()
	assert_bool(_spy.was_emitted("tower_destroyed")).is_false()
	assert_bool(_ts.placed_towers.has(tower_id)).is_true()

# ---------------------------------------------------------------------------
# AC-20: Sell refund = round(30 × 0.4) = 12
# ---------------------------------------------------------------------------

func test_sell_tower_refunds_40_percent_rounded() -> void:
	var data: TowerBlueprintData = _make_data()
	data.placement_cost = 30
	_ts._tower_table[data.tower_id] = data
	GEventBus.resources_changed.emit(100, &"test_setup")
	_ts._current_phase = TowerSystem.Phase.INTERMISSION
	_ts.place_tower(data.tower_id, Vector2i(5, 5))
	var tower_id: int = _ts.placed_towers.keys()[0] as int
	var gold_after_place: int = GMissionEconomy.get_gold_balance()  # 70

	_ts.sell_tower(tower_id)

	# round(30 * 0.4) = 12
	assert_int(GMissionEconomy.get_gold_balance()).is_equal(gold_after_place + 12)

# ---------------------------------------------------------------------------
# AC-22: Focus=LOWEST_HP targeting selects enemy with lower HP
# ---------------------------------------------------------------------------

func test_find_lowest_hp_target_selects_lower_hp_enemy() -> void:
	var data: TowerBlueprintData = _make_data(35.0, 2.0, 1.0, 10, 180.0)
	_place(_ts, data, Vector2i(0, 0))
	var tower_id: int = _ts.placed_towers.keys()[0] as int
	var state: TowerMissionState = _ts.placed_towers[tower_id] as TowerMissionState

	# Two enemies in range — B has lower HP
	_ts._monster_cache[10] = {"cell": Vector2i(3, 3), "hp": 500.0, "is_armored": false}
	_ts._monster_cache[20] = {"cell": Vector2i(4, 4), "hp": 100.0, "is_armored": false}

	_ts._current_phase = TowerSystem.Phase.WAVE_ACTIVE
	_ts._tick_combat(DELTA)
	await get_tree().process_frame  # Flush deferred tower_attacked emit (ADR-0001 Rule 2)

	# Should have fired at entity_id=20 (lower HP)
	var emissions: Array = _spy.emissions.get("tower_attacked", []) as Array
	assert_int(emissions.size()).is_greater_equal(1)
	var target_id: int = emissions[0][1] as int  # arg index 1 = target_monster_id
	assert_int(target_id).is_equal(20)

# ---------------------------------------------------------------------------
# AC-29: Monster cache built from EventBus subscriptions (no direct refs)
# ---------------------------------------------------------------------------

func test_monster_spawned_populates_cache() -> void:
	var payload := MonsterSpawnedEvent.new()
	payload.entity_id = 7
	payload.monster_id = &"goblin"
	payload.wave_index = 1
	payload.grid_position = Vector2i(3, 4)
	payload.hp_max = 300.0

	_ts._on_monster_spawned(payload)

	assert_bool(_ts._monster_cache.has(7)).is_true()
	var entry: Dictionary = _ts._monster_cache[7] as Dictionary
	assert_int((entry["cell"] as Vector2i).x).is_equal(3)
	assert_int((entry["cell"] as Vector2i).y).is_equal(4)


func test_monster_cell_entered_updates_cache_position() -> void:
	_ts._monster_cache[7] = {"cell": Vector2i(1, 1), "hp": 100.0, "is_armored": false}

	_ts._on_monster_cell_entered(7, Vector2i(5, 5), 3)

	var entry: Dictionary = _ts._monster_cache[7] as Dictionary
	assert_int((entry["cell"] as Vector2i).x).is_equal(5)
	assert_int((entry["cell"] as Vector2i).y).is_equal(5)


func test_monster_died_removes_cache_entry() -> void:
	_ts._monster_cache[7] = {"cell": Vector2i(3, 4), "hp": 100.0, "is_armored": false}

	var died_payload := MonsterDiedEvent.new()
	died_payload.entity_id = 7
	_ts._on_monster_died(died_payload)

	assert_bool(_ts._monster_cache.has(7)).is_false()
