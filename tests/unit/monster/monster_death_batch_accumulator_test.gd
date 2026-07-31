## Unit tests for ADR-0033 (Monster Death Batch Accumulator) — the Validation
## Criteria the ADR itself calls for: threshold-crossing batching, common-case
## individual emission, and the emitter-side exclusivity guarantee TD-econ-006
## originally asked for. Fixture/stub pattern mirrors
## monster_manager_debt_coverage_test.gd exactly.
extends GdUnitTestSuite

# ---------------------------------------------------------------------------
# Stubs
# ---------------------------------------------------------------------------

class _StubGrid extends RefCounted:
	func get_cell_type(_cell: Vector2i) -> int:
		return Grid.CellType.SPAWN

	func cell_to_world(cell: Vector2i) -> Vector2:
		return Vector2(float(cell.x) * 64.0, float(cell.y) * 64.0)

	func world_to_cell(pos: Vector2) -> Vector2i:
		return Vector2i(int(pos.x / 64.0), int(pos.y / 64.0))

	func get_towers_in_range(_center: Vector2i, _radius: int) -> Array[int]:
		return []


class _StubPathfinding extends RefCounted:
	func find_path(_from: Vector2i, _tier: int) -> Array[Vector2i]:
		return [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

const SPAWN_CELL := Vector2i(0, 0)

func _make_resource(id: StringName = &"goblin", base_hp: float = 100.0, tier: int = 0) -> MonsterResource:
	var res := MonsterResource.new()
	res.monster_id = id
	res.display_name = "Test Monster"
	res.tier = tier
	res.base_hp = base_hp
	res.base_speed = 1.0
	res.drop_table_id = &"goblin_drops"
	res.menagerie_attraction_drop_chance = 0.05
	if tier == 2:
		res.base_damage = 50.0
		res.base_attack_interval = 3.0
		res.boss_attack_range_cells = 3
	return res


var _mm: MonsterManager
var _stub_grid: _StubGrid
var _stub_path: _StubPathfinding
var _spy: EventBusSpy


func before_test() -> void:
	_stub_grid = _StubGrid.new()
	_stub_path = _StubPathfinding.new()
	_mm = MonsterManager.new()
	add_child(_mm)
	_mm._grid = _stub_grid
	_mm._pathfinding = _stub_path
	_mm._is_wave_active = true
	_mm._current_wave_index = 1
	_mm._resource_table = {}
	_mm.set_physics_process(false)


func after_test() -> void:
	if _spy != null:
		_spy.disconnect_all()
		_spy = null
	for e: MonsterEntity in _mm.active_monsters:
		if is_instance_valid(e):
			e.free()
	for e: MonsterEntity in _mm.spawning_entities:
		if is_instance_valid(e):
			e.free()
	remove_child(_mm)
	_mm.free()


## Kills `count` freshly-spawned goblins in one Pass 1 call by injecting
## lethal MonsterDamageTaken payloads for each — returns the spawned entities'
## IDs in spawn order.
func _kill_n_goblins(count: int) -> Array[int]:
	var res := _make_resource(&"goblin", 10.0)
	_mm._resource_table[res.monster_id] = res
	var ids: Array[int] = []
	for i in range(count):
		var entity := _mm.spawn_monster(res.monster_id, SPAWN_CELL, 1, 1)
		ids.append(entity.entity_id)
		var dmg := MonsterDamageTaken.new()
		dmg.entity_id = entity.entity_id
		dmg.amount = 9999
		dmg.source_type = 0
		_mm._pending_damage.append(dmg)
	return ids


# ---------------------------------------------------------------------------
# Threshold crossing: > DEATH_BATCH_THRESHOLD (20) deaths in one frame
# ---------------------------------------------------------------------------

func test_pass4_batches_deaths_above_threshold_emits_batch_not_individual() -> void:
	var ids := _kill_n_goblins(21)  # 21 > 20 threshold

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.monster_died)
	_spy.watch(GEventBus.monsters_died_batch)

	_mm._pass1_damage()
	_mm._pass4_death_and_absorbed_flush()

	assert_int(_spy.count("monster_died")).is_equal(0)
	assert_int(_spy.count("monsters_died_batch")).is_equal(1)
	var payloads: Array[MonsterDiedEvent] = (_spy.emissions["monsters_died_batch"] as Array)[0][0] as Array[MonsterDiedEvent]
	assert_int(payloads.size()).is_equal(21)
	var payload_ids: Array[int] = []
	for p: MonsterDiedEvent in payloads:
		payload_ids.append(p.entity_id)
	for id: int in ids:
		assert_bool(payload_ids.has(id)).is_true()


func test_pass4_exactly_twenty_one_is_the_minimum_that_triggers_batching() -> void:
	# Formula 2 / ADR-0033: threshold is strict > 20, so 21 is the boundary.
	_kill_n_goblins(21)

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.monster_died)
	_spy.watch(GEventBus.monsters_died_batch)

	_mm._pass1_damage()
	_mm._pass4_death_and_absorbed_flush()

	assert_bool(_spy.was_emitted("monsters_died_batch")).is_true()
	assert_bool(_spy.was_emitted("monster_died")).is_false()


# ---------------------------------------------------------------------------
# Common case: <= DEATH_BATCH_THRESHOLD (20) deaths — individual emission
# ---------------------------------------------------------------------------

func test_pass4_emits_individually_at_exactly_the_threshold() -> void:
	# Exactly 20 (not > 20) must NOT trigger batching — regression guard for
	# the strict-greater-than boundary.
	var ids := _kill_n_goblins(20)

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.monster_died)
	_spy.watch(GEventBus.monsters_died_batch)

	_mm._pass1_damage()
	_mm._pass4_death_and_absorbed_flush()

	assert_int(_spy.count("monster_died")).is_equal(20)
	assert_int(_spy.count("monsters_died_batch")).is_equal(0)
	var emitted_ids: Array[int] = []
	for emission: Array in (_spy.emissions["monster_died"] as Array):
		var ev: MonsterDiedEvent = emission[0] as MonsterDiedEvent
		emitted_ids.append(ev.entity_id)
	for id: int in ids:
		assert_bool(emitted_ids.has(id)).is_true()


func test_pass4_single_death_emits_individually_common_case() -> void:
	_kill_n_goblins(1)

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.monster_died)
	_spy.watch(GEventBus.monsters_died_batch)

	_mm._pass1_damage()
	_mm._pass4_death_and_absorbed_flush()

	assert_int(_spy.count("monster_died")).is_equal(1)
	assert_bool(_spy.was_emitted("monsters_died_batch")).is_false()


# ---------------------------------------------------------------------------
# Emitter-side exclusivity guarantee (the test TD-econ-006 originally asked
# for, now meaningful per ADR-0033's own Validation Criteria).
# ---------------------------------------------------------------------------

func test_emit_death_never_emits_monster_died_synchronously_only_buffers() -> void:
	_kill_n_goblins(1)

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.monster_died)
	_spy.watch(GEventBus.monsters_died_batch)

	_mm._pass1_damage()

	# Before Pass 4 runs, NEITHER signal has fired yet — proves _emit_death()
	# itself never emits either signal directly, only buffers into
	# _pending_deaths. This is the structural guarantee that makes mutual
	# exclusivity possible at all.
	assert_int(_spy.count("monster_died")).is_equal(0)
	assert_int(_spy.count("monsters_died_batch")).is_equal(0)
	assert_int(_mm._pending_deaths.size()).is_equal(1)

	_mm._pass4_death_and_absorbed_flush()

	assert_int(_spy.count("monster_died")).is_equal(1)
	assert_int(_mm._pending_deaths.size()).is_equal(0)


func test_monster_died_and_monsters_died_batch_are_mutually_exclusive_per_frame() -> void:
	# Never both fire for the same frame's kills, at any death count either
	# side of the threshold — the exact guarantee resource-economy.md/
	# ADR-0017 depends on.
	for count: int in [1, 5, 20, 21, 30]:
		_mm._pending_deaths.clear()
		_kill_n_goblins(count)

		_spy = EventBusSpy.new()
		_spy.watch(GEventBus.monster_died)
		_spy.watch(GEventBus.monsters_died_batch)

		_mm._pass1_damage()
		_mm._pass4_death_and_absorbed_flush()

		var individual_fired: bool = _spy.was_emitted("monster_died")
		var batch_fired: bool = _spy.was_emitted("monsters_died_batch")
		assert_bool(individual_fired and batch_fired).is_false()
		assert_bool(individual_fired or batch_fired).is_true()

		_spy.disconnect_all()
		_spy = null
		for e: MonsterEntity in _mm.active_monsters:
			if is_instance_valid(e):
				e.free()
		_mm.active_monsters.clear()
		_mm._entity_lookup.clear()


# ---------------------------------------------------------------------------
# boss_died stays immediate/unbatched regardless of batching (ADR-0033
# Constraints — boss kills are not part of the batching problem).
# ---------------------------------------------------------------------------

func test_boss_died_still_emits_immediately_even_when_part_of_a_batched_frame() -> void:
	var boss_res := _make_resource(&"boss_test", 10.0, 2)
	_mm._resource_table[boss_res.monster_id] = boss_res
	var boss_entity := _mm.spawn_monster(boss_res.monster_id, SPAWN_CELL, 1, 1)
	var boss_dmg := MonsterDamageTaken.new()
	boss_dmg.entity_id = boss_entity.entity_id
	boss_dmg.amount = 9999
	boss_dmg.source_type = 0
	_mm._pending_damage.append(boss_dmg)

	_kill_n_goblins(20)  # + 1 boss = 21 total pending deaths -> triggers batching

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.boss_died)
	_spy.watch(GEventBus.monster_died)
	_spy.watch(GEventBus.monsters_died_batch)

	_mm._pass1_damage()

	# boss_died already fired during Pass 1 -- immediate, unaffected by the
	# still-pending batching decision.
	assert_int(_spy.count("boss_died")).is_equal(1)
	assert_int(_spy.count("monster_died")).is_equal(0)
	assert_int(_spy.count("monsters_died_batch")).is_equal(0)

	_mm._pass4_death_and_absorbed_flush()

	assert_int(_spy.count("monsters_died_batch")).is_equal(1)
	var payloads: Array[MonsterDiedEvent] = (_spy.emissions["monsters_died_batch"] as Array)[0][0] as Array[MonsterDiedEvent]
	assert_int(payloads.size()).is_equal(21)  # boss's own MonsterDiedEvent is included in the batch too


## Real bug found during implementation (not just a hypothetical): GDScript
## Arrays are reference types, so emit(_pending_deaths) hands every
## subscriber a live reference to the SAME array _pass4 then clears. The
## original implementation used _pending_deaths.clear() after emitting,
## which retroactively emptied whatever any subscriber held onto -- caught
## by this exact test failing during development. Fixed by reassigning to a
## fresh Array instead of clearing in place.
func test_batch_payload_array_is_not_retroactively_emptied_by_the_next_frames_reset() -> void:
	_kill_n_goblins(21)

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.monsters_died_batch)

	_mm._pass1_damage()
	_mm._pass4_death_and_absorbed_flush()

	var payloads: Array[MonsterDiedEvent] = (_spy.emissions["monsters_died_batch"] as Array)[0][0] as Array[MonsterDiedEvent]
	assert_int(payloads.size()).is_equal(21)

	# Simulate a second frame's worth of buffering-and-flushing after the
	# first batch already fired -- the PREVIOUSLY emitted array must remain
	# exactly as it was, not be silently emptied by _pass4 preparing for the
	# next frame.
	_kill_n_goblins(1)
	_mm._pass1_damage()
	_mm._pass4_death_and_absorbed_flush()

	assert_int(payloads.size()).is_equal(21)
