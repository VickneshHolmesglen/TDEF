extends GdUnitTestSuite

## Unit tests for MonsterManager's Hero attacks (hero-damage spec §4.2, AC-2/3/5).
## Stub/fixture pattern mirrors monster_boss_test.gd. The grid stub lets each test place
## the monster's cell and towers at chosen Chebyshev distances.

class _StubGrid extends RefCounted:
	var monster_cell: Vector2i = Vector2i(0, 0)
	## tower_id -> Chebyshev distance from the monster; a tower is "in range" of radius r
	## when its distance <= r (matches Grid.get_towers_in_range's semantics).
	var towers_at_distance: Dictionary = {}

	func get_cell_type(_cell: Vector2i) -> int:
		return Grid.CellType.SPAWN

	func cell_to_world(cell: Vector2i) -> Vector2:
		return Vector2(float(cell.x) * 64.0, float(cell.y) * 64.0)

	func world_to_cell(_pos: Vector2) -> Vector2i:
		return monster_cell

	func get_towers_in_range(_center: Vector2i, radius: int) -> Array[int]:
		var out: Array[int] = []
		for id: int in towers_at_distance:
			if int(towers_at_distance[id]) <= radius:
				out.append(id)
		return out


class _StubPathfinding extends RefCounted:
	func find_path(_from: Vector2i, _tier: int) -> Array[Vector2i]:
		return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
				Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0), Vector2i(8, 0), Vector2i(9, 0)]


const SPAWN_CELL := Vector2i(0, 0)
const HERO_NEAR := Vector2i(1, 0)  # Chebyshev distance 1 from the monster at (0,0)
const HERO_FAR := Vector2i(9, 9)

var _mm: MonsterManager
var _grid: _StubGrid
var _spy: EventBusSpy


func before_test() -> void:
	_grid = _StubGrid.new()
	_mm = MonsterManager.new()
	add_child(_mm)  # BEFORE overriding DI seams (see monster_boss_test.gd)
	_mm._grid = _grid
	_mm._pathfinding = _StubPathfinding.new()
	_mm._is_wave_active = true
	_mm._current_wave_index = 1
	_mm._hero_alive = true
	_mm._hero_cell = HERO_NEAR
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_incoming_damage)
	_spy.watch(GEventBus.monster_hero_attack_winding_up)
	_spy.watch(GEventBus.monster_hero_attack_resolved)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _mm != null and is_instance_valid(_mm):
		for e: MonsterEntity in _mm.active_monsters:
			if is_instance_valid(e):
				e.free()
		for e: MonsterEntity in _mm.spawning_entities:
			if is_instance_valid(e):
				e.free()
		remove_child(_mm)
		_mm.free()
	_mm = null


func _make_attacker(tier: int, damage: float, interval: float, range_cells: int, windup: float) -> MonsterResource:
	var res := MonsterResource.new()
	res.monster_id = &"attacker_test"
	res.display_name = "Attacker"
	res.tier = tier
	res.base_hp = 500.0
	res.base_speed = 0.5
	res.base_damage = damage
	res.base_attack_interval = interval
	res.boss_attack_range_cells = range_cells
	res.hero_attack_windup_seconds = windup
	res.drop_table_id = &"goblin_drops"
	return res


func _spawn(res: MonsterResource) -> MonsterEntity:
	_mm._resource_table[res.monster_id] = res
	return _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)


func _elite() -> MonsterEntity:
	return _spawn(_make_attacker(1, 30.0, 2.5, 2, 1.0))


# --- cache and lifecycle ---------------------------------------------------

func test_position_changed_updates_the_hero_cell_cache() -> void:
	_mm._on_hero_position_changed(Vector2i(4, 7))
	assert_bool(_mm._hero_cell == Vector2i(4, 7)).is_true()


func test_wave_started_marks_the_hero_alive() -> void:
	_mm._hero_alive = false
	_mm._on_wave_started(1, 6, 1.0)
	assert_bool(_mm._hero_alive).is_true()


func test_hero_died_clears_windups_and_stops_targeting() -> void:
	var elite := _elite()
	_mm._pass2b_hero_attacks(0.1)  # starts a wind-up
	assert_float(elite.hero_windup_remaining).is_greater(0.0)
	_mm._on_hero_died()
	assert_bool(_mm._hero_alive).is_false()
	assert_float(elite.hero_windup_remaining).is_equal(0.0)
	assert_int(elite.boss_locked_target_id).is_equal(-1)


func test_new_subscriptions_are_disconnected_on_exit() -> void:
	var pos_baseline: int = GEventBus.hero_position_changed.get_connections().size()
	var died_baseline: int = GEventBus.hero_died.get_connections().size()
	remove_child(_mm)  # _exit_tree disconnects (ADR-0001 Rule 6)
	assert_int(GEventBus.hero_position_changed.get_connections().size()).is_equal(pos_baseline - 1)
	assert_int(GEventBus.hero_died.get_connections().size()).is_equal(died_baseline - 1)
	_mm.free()
	_mm = null  # after_test guards on null (a second _exit_tree would disconnect twice)


# --- elite wind-up ---------------------------------------------------------

func test_elite_with_hero_in_range_starts_a_windup_and_announces_it() -> void:
	var elite := _elite()
	_mm._pass2b_hero_attacks(0.1)
	assert_float(elite.hero_windup_remaining).is_greater(0.0)
	assert_int(elite.boss_locked_target_id).is_equal(MonsterManager.HERO_TARGET_ID)
	await get_tree().process_frame  # emitted deferred (ADR-0001 Rule 2)
	assert_int(_spy.count("monster_hero_attack_winding_up")).is_equal(1)
	var args: Array = (_spy.emissions["monster_hero_attack_winding_up"] as Array)[0] as Array
	assert_int(args[0]).is_equal(elite.entity_id)
	assert_float(args[1]).is_equal_approx(1.0, 0.0001)


func test_elite_does_not_wind_up_when_the_hero_is_out_of_range() -> void:
	var elite := _elite()
	_mm._hero_cell = HERO_FAR
	_mm._pass2b_hero_attacks(0.1)
	assert_float(elite.hero_windup_remaining).is_equal(0.0)
	await get_tree().process_frame  # emitted deferred (ADR-0001 Rule 2)
	assert_int(_spy.count("monster_hero_attack_winding_up")).is_equal(0)


func test_elite_does_not_wind_up_when_the_hero_is_dead_or_position_unknown() -> void:
	var elite := _elite()
	_mm._hero_alive = false
	_mm._pass2b_hero_attacks(0.1)
	assert_float(elite.hero_windup_remaining).is_equal(0.0)
	_mm._hero_alive = true
	_mm._hero_cell = Vector2i(-1, -1)
	_mm._pass2b_hero_attacks(0.1)
	assert_float(elite.hero_windup_remaining).is_equal(0.0)


func test_standard_and_zero_damage_elites_never_wind_up() -> void:
	var standard := _spawn(_make_attacker(0, 0.0, 0.0, 0, 0.0))
	_mm._pass2b_hero_attacks(0.1)
	assert_float(standard.hero_windup_remaining).is_equal(0.0)
	var quiet_res := _make_attacker(1, 0.0, 0.0, 0, 0.0)
	quiet_res.monster_id = &"quiet_elite"
	var quiet := _spawn(quiet_res)
	_mm._pass2b_hero_attacks(0.1)
	assert_float(quiet.hero_windup_remaining).is_equal(0.0)
	await get_tree().process_frame  # emitted deferred (ADR-0001 Rule 2)
	assert_int(_spy.count("monster_hero_attack_winding_up")).is_equal(0)


# --- fire / whiff ----------------------------------------------------------

func test_elite_fires_exactly_once_when_the_windup_completes() -> void:
	var elite := _elite()
	_mm._pass2b_hero_attacks(0.5)  # scan + start wind-up (1.0 s), tick 0.5
	assert_int(_spy.count("hero_incoming_damage")).is_equal(0)
	_mm._pass2b_hero_attacks(0.5)  # wind-up reaches 0 -> fires
	assert_int(_spy.count("hero_incoming_damage")).is_equal(1)
	var ev: HeroIncomingDamageEvent = (_spy.emissions["hero_incoming_damage"] as Array)[0][0] as HeroIncomingDamageEvent
	assert_float(ev.amount).is_equal_approx(30.0, 0.0001)
	assert_str(ev.damage_type).is_equal("physical")
	assert_int(ev.source_type).is_equal(0)
	assert_int(ev.source_entity_id).is_equal(elite.entity_id)
	assert_float(elite.hero_windup_remaining).is_equal(0.0)
	assert_int(elite.boss_locked_target_id).is_equal(-1)
	assert_float(elite.boss_attack_cooldown_remaining).is_greater(0.0)


func test_a_hero_who_left_range_during_the_windup_is_a_whiff() -> void:
	var elite := _elite()
	_mm._pass2b_hero_attacks(0.5)
	_mm._hero_cell = HERO_FAR  # the Hero dodges
	_mm._pass2b_hero_attacks(0.5)
	assert_int(_spy.count("hero_incoming_damage")).is_equal(0)
	assert_float(elite.hero_windup_remaining).is_equal(0.0)
	assert_float(elite.boss_attack_cooldown_remaining).is_greater(0.0)  # the cooldown is still spent


func test_no_new_windup_while_the_cooldown_is_running() -> void:
	var elite := _elite()
	elite.boss_attack_cooldown_remaining = 2.0
	_mm._elite_scan(elite)
	assert_float(elite.hero_windup_remaining).is_equal(0.0)
	elite.boss_attack_cooldown_remaining = 0.0
	_mm._elite_scan(elite)
	assert_float(elite.hero_windup_remaining).is_greater(0.0)


func test_a_monster_killed_mid_windup_never_fires() -> void:
	var elite := _elite()
	_mm._pass2b_hero_attacks(0.5)
	elite.lifecycle_state = MonsterEntity.State.DEAD
	_mm._pass2b_hero_attacks(0.5)
	assert_int(_spy.count("hero_incoming_damage")).is_equal(0)


func test_the_cooldown_ticks_down_for_elites() -> void:
	var elite := _elite()
	_mm._hero_cell = HERO_FAR
	elite.boss_attack_cooldown_remaining = 2.0
	_mm._pass2b_hero_attacks(0.5)
	assert_float(elite.boss_attack_cooldown_remaining).is_equal_approx(1.5, 0.0001)


# ---------------------------------------------------------------------------
# Boss targeting: closest of Hero or tower (spec §3, §4.2, AC-4)
# ---------------------------------------------------------------------------

func _boss() -> MonsterEntity:
	return _spawn(_make_attacker(2, 60.0, 3.0, 3, 1.0))


func test_boss_targets_the_hero_when_strictly_closer_than_the_closest_tower() -> void:
	var boss := _boss()
	_mm._hero_cell = Vector2i(1, 0)          # Hero distance 1
	_grid.towers_at_distance = {42: 2}        # closest tower distance 2
	_mm._pass2_boss_logic(1.0 / 60.0)
	assert_int(boss.boss_locked_target_id).is_equal(MonsterManager.HERO_TARGET_ID)
	assert_float(boss.hero_windup_remaining).is_equal_approx(1.0, 0.0001)
	assert_int(boss.boss_attack_prepare_remaining).is_equal(0)
	await get_tree().process_frame  # emitted deferred (ADR-0001 Rule 2)
	assert_int(_spy.count("monster_hero_attack_winding_up")).is_equal(1)


func test_boss_targets_the_tower_when_it_is_closer_than_the_hero() -> void:
	var boss := _boss()
	_mm._hero_cell = Vector2i(2, 0)          # Hero distance 2
	_grid.towers_at_distance = {42: 1}        # tower distance 1
	_mm._pass2_boss_logic(1.0 / 60.0)
	assert_int(boss.boss_locked_target_id).is_equal(42)
	assert_int(boss.boss_attack_prepare_remaining).is_greater(0)
	assert_float(boss.hero_windup_remaining).is_equal(0.0)


func test_a_tie_goes_to_the_tower() -> void:
	var boss := _boss()
	_mm._hero_cell = Vector2i(2, 0)
	_grid.towers_at_distance = {42: 2}
	_mm._pass2_boss_logic(1.0 / 60.0)
	assert_int(boss.boss_locked_target_id).is_equal(42)
	assert_float(boss.hero_windup_remaining).is_equal(0.0)


func test_boss_targets_the_hero_when_no_tower_is_in_range() -> void:
	var boss := _boss()
	_mm._hero_cell = Vector2i(2, 0)
	_grid.towers_at_distance = {}
	_mm._pass2_boss_logic(1.0 / 60.0)
	assert_int(boss.boss_locked_target_id).is_equal(MonsterManager.HERO_TARGET_ID)


func test_boss_targets_the_tower_when_the_hero_is_out_of_range() -> void:
	var boss := _boss()
	_mm._hero_cell = HERO_FAR
	_grid.towers_at_distance = {42: 2}
	_mm._pass2_boss_logic(1.0 / 60.0)
	assert_int(boss.boss_locked_target_id).is_equal(42)
	assert_float(boss.hero_windup_remaining).is_equal(0.0)


func test_boss_ignores_a_dead_or_unknown_hero() -> void:
	var boss := _boss()
	_grid.towers_at_distance = {42: 2}
	_mm._hero_alive = false
	_mm._pass2_boss_logic(1.0 / 60.0)
	assert_int(boss.boss_locked_target_id).is_equal(42)


func test_boss_with_nothing_in_range_does_nothing() -> void:
	var boss := _boss()
	_mm._hero_cell = HERO_FAR
	_grid.towers_at_distance = {}
	_mm._pass2_boss_logic(1.0 / 60.0)
	assert_int(boss.boss_locked_target_id).is_equal(-1)
	assert_float(boss.hero_windup_remaining).is_equal(0.0)
	assert_int(boss.boss_attack_prepare_remaining).is_equal(0)


func test_boss_hero_attack_fires_with_the_boss_damage() -> void:
	var boss := _boss()
	_mm._hero_cell = Vector2i(1, 0)
	_grid.towers_at_distance = {}
	_mm._pass2_boss_logic(1.0 / 60.0)      # scan -> Hero locked
	_mm._pass2b_hero_attacks(1.0)          # wind-up (1.0 s) completes
	assert_int(_spy.count("hero_incoming_damage")).is_equal(1)
	var ev: HeroIncomingDamageEvent = (_spy.emissions["hero_incoming_damage"] as Array)[0][0] as HeroIncomingDamageEvent
	assert_float(ev.amount).is_equal_approx(60.0, 0.0001)
	assert_int(ev.source_entity_id).is_equal(boss.entity_id)
	assert_float(boss.boss_attack_cooldown_remaining).is_greater(0.0)


func test_boss_hero_whiff_when_the_hero_leaves_range() -> void:
	var boss := _boss()
	_mm._hero_cell = Vector2i(1, 0)
	_grid.towers_at_distance = {}
	_mm._pass2_boss_logic(1.0 / 60.0)
	_mm._hero_cell = HERO_FAR
	_mm._pass2b_hero_attacks(1.0)
	assert_int(_spy.count("hero_incoming_damage")).is_equal(0)
	assert_float(boss.boss_attack_cooldown_remaining).is_greater(0.0)


func test_only_one_windup_in_flight_a_hero_windup_blocks_a_tower_prepare() -> void:
	var boss := _boss()
	_mm._hero_cell = Vector2i(1, 0)
	_grid.towers_at_distance = {42: 3}
	_mm._pass2_boss_logic(1.0 / 60.0)      # Hero locked (distance 1 < 3)
	boss.boss_scan_frames_remaining = 0    # force another scan next pass
	_mm._pass2_boss_logic(1.0 / 60.0)
	assert_int(boss.boss_attack_prepare_remaining).is_equal(0)
	assert_int(boss.boss_locked_target_id).is_equal(MonsterManager.HERO_TARGET_ID)


func test_a_tower_prepare_blocks_a_hero_windup() -> void:
	var boss := _boss()
	_mm._hero_cell = HERO_FAR
	_grid.towers_at_distance = {42: 1}
	_mm._pass2_boss_logic(1.0 / 60.0)      # tower prepare starts
	_mm._hero_cell = Vector2i(1, 0)        # Hero now closer than nothing else, but a prepare is in flight
	boss.boss_scan_frames_remaining = 0
	_mm._pass2_boss_logic(1.0 / 60.0)
	assert_float(boss.hero_windup_remaining).is_equal(0.0)


# --- resolve signal (wind-up presentation spec §4.2) ------------------------

func test_a_completed_windup_that_lands_emits_resolved_with_hit_true() -> void:
	var elite := _elite()
	_mm._pass2b_hero_attacks(0.5)
	_mm._pass2b_hero_attacks(0.5)
	await get_tree().process_frame  # emitted deferred
	assert_int(_spy.count("monster_hero_attack_resolved")).is_equal(1)
	var args: Array = (_spy.emissions["monster_hero_attack_resolved"] as Array)[0] as Array
	assert_int(args[0]).is_equal(elite.entity_id)
	assert_bool(args[1]).is_true()


func test_a_whiff_emits_resolved_with_hit_false() -> void:
	_elite()
	_mm._pass2b_hero_attacks(0.5)
	_mm._hero_cell = HERO_FAR
	_mm._pass2b_hero_attacks(0.5)
	await get_tree().process_frame
	assert_int(_spy.count("monster_hero_attack_resolved")).is_equal(1)
	assert_bool((_spy.emissions["monster_hero_attack_resolved"] as Array)[0][1]).is_false()


func test_resolved_is_not_emitted_before_the_windup_completes_or_for_a_monster_killed_mid_windup() -> void:
	var elite := _elite()
	_mm._pass2b_hero_attacks(0.5)
	await get_tree().process_frame
	assert_int(_spy.count("monster_hero_attack_resolved")).is_equal(0)
	elite.lifecycle_state = MonsterEntity.State.DEAD
	_mm._pass2b_hero_attacks(0.6)
	await get_tree().process_frame
	assert_int(_spy.count("monster_hero_attack_resolved")).is_equal(0)


func test_get_monster_world_position_returns_the_entity_position_or_inf() -> void:
	var elite := _elite()
	elite.global_position = Vector2(128.0, 64.0)
	_mm._entity_lookup[elite.entity_id] = elite
	assert_vector(_mm.get_monster_world_position(elite.entity_id)).is_equal(Vector2(128.0, 64.0))
	assert_vector(_mm.get_monster_world_position(99999)).is_equal(Vector2.INF)


func test_visual_sync_drives_the_telegraph_from_the_windup_state() -> void:
	var elite := _elite()
	_mm._pass2b_hero_attacks(0.4)  # starts the 1.0 s wind-up, ticks 0.4
	_mm._pass3c_visual_sync(0.016)
	assert_bool(elite.monster_instance.is_windup_telegraph_active()).is_true()
	assert_float(elite.monster_instance.get_windup_progress()).is_equal_approx(0.4, 0.001)
	_mm._pass2b_hero_attacks(0.7)  # completes
	_mm._pass3c_visual_sync(0.016)
	assert_bool(elite.monster_instance.is_windup_telegraph_active()).is_false()
	assert_float(elite.monster_instance.get_resolve_alpha()).is_greater(0.0)
