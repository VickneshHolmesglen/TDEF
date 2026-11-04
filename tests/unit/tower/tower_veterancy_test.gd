## Tower veterancy (design/quick-specs/tower-veterancy-2026-11-04.md): towers
## rank up at 10/30/60 credited kills, +8% damage per rank, per mission.
extends GdUnitTestSuite

var _ts: TowerSystem
var _spy: EventBusSpy


func before_test() -> void:
	_ts = TowerSystem.new()  # never enters the tree: handlers are called directly
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.tower_ranked_up)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	_ts.free()


func _place(tower_id: int) -> TowerMissionState:
	var state := TowerMissionState.new()
	state.tower_id = tower_id
	_ts.placed_towers[tower_id] = state
	return state


func _death(killer_tower_id: int) -> MonsterDiedEvent:
	var ev := MonsterDiedEvent.new()
	ev.entity_id = 100 + _spy.count("tower_ranked_up")
	ev.killer_tower_id = killer_tower_id
	return ev


func test_tower_veterancy_rank_for_kills_uses_thresholds() -> void:
	assert_int(TowerSystem.veterancy_rank_for_kills(0)).is_equal(0)
	assert_int(TowerSystem.veterancy_rank_for_kills(9)).is_equal(0)
	assert_int(TowerSystem.veterancy_rank_for_kills(10)).is_equal(1)
	assert_int(TowerSystem.veterancy_rank_for_kills(30)).is_equal(2)
	assert_int(TowerSystem.veterancy_rank_for_kills(500)).is_equal(3)


func test_tower_veterancy_multiplier_is_eight_percent_per_rank() -> void:
	assert_float(TowerSystem.veterancy_multiplier(0)).is_equal_approx(1.0, 0.0001)
	assert_float(TowerSystem.veterancy_multiplier(3)).is_equal_approx(1.24, 0.0001)


func test_tower_veterancy_tenth_kill_ranks_up_once() -> void:
	# Arrange
	var state: TowerMissionState = _place(4)
	# Act
	for i: int in 10:
		_ts._on_monster_died(_death(4))
	# Assert
	assert_int(state.kills).is_equal(10)
	assert_int(state.rank).is_equal(1)
	assert_int(_spy.count("tower_ranked_up")).is_equal(1)
	assert_array((_spy.emissions["tower_ranked_up"] as Array)[0]).is_equal([4, 1])


func test_tower_veterancy_batched_deaths_are_credited() -> void:
	# Arrange
	var state: TowerMissionState = _place(2)
	var batch: Array[MonsterDiedEvent] = []
	for i: int in 30:
		batch.append(_death(2))
	# Act
	_ts._on_monsters_died_batch(batch)
	# Assert: thresholds 10 and 30 both crossed
	assert_int(state.rank).is_equal(2)
	assert_int(_spy.count("tower_ranked_up")).is_equal(2)


func test_tower_veterancy_non_tower_or_sold_tower_kills_credit_nobody() -> void:
	var state: TowerMissionState = _place(1)
	_ts._on_monster_died(_death(-1))  # hero kill
	_ts._on_monster_died(_death(99))  # tower no longer placed
	assert_int(state.kills).is_equal(0)
	assert_int(_spy.count("tower_ranked_up")).is_equal(0)


func test_tower_veterancy_batched_death_leaves_the_target_cache() -> void:
	_ts._monster_cache[7] = {"cell": Vector2i.ZERO, "hp": 1.0}
	var ev := MonsterDiedEvent.new()
	ev.entity_id = 7
	var batch: Array[MonsterDiedEvent] = [ev]
	_ts._on_monsters_died_batch(batch)
	assert_bool(_ts._monster_cache.has(7)).is_false()
