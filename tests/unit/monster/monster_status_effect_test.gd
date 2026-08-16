## Unit tests for design/gdd/damage-status.md Formula D5 (Status Effect
## Burn/Poison DoT) and Formula D6 (Slow Effect Speed Multiplier), and their
## shared ADR-0006-amendment 5th pass (_pass1b_status_effects).
## Covers AC-26 through AC-35. Stub/fixture pattern mirrors
## monster_death_batch_accumulator_test.gd exactly.
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
		return [Vector2i(1, 0), Vector2i(2, 0)]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

const SPAWN_CELL := Vector2i(0, 0)

func _make_resource(id: StringName, base_hp: float) -> MonsterResource:
	var res := MonsterResource.new()
	res.monster_id = id
	res.display_name = "Test Monster"
	res.tier = 0
	res.base_hp = base_hp
	res.base_speed = 1.0
	res.drop_table_id = &"goblin_drops"
	res.menagerie_attraction_drop_chance = 0.05
	return res


var _mm: MonsterManager
var _stub_grid: _StubGrid
var _stub_path: _StubPathfinding


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
	for e: MonsterEntity in _mm.active_monsters:
		if is_instance_valid(e):
			e.free()
	remove_child(_mm)
	_mm.free()


func _spawn(id: StringName, base_hp: float) -> MonsterEntity:
	var res := _make_resource(id, base_hp)
	_mm._resource_table[id] = res
	return _mm.spawn_monster(id, SPAWN_CELL, 1, 1)


# ---------------------------------------------------------------------------
# AC-26: basic burn tick sequence
# ---------------------------------------------------------------------------

func test_ac26_burn_hit_creates_instance_with_correct_formula() -> void:
	var entity := _spawn(&"goblin", 200.0)

	_mm._on_tower_attacked_status(1, entity.entity_id, 0.0, false, false, "burn", 0.10, 3.0, 0.0, false)

	assert_int(entity.active_status_effects.size()).is_equal(1)
	var instance: ActiveStatusEffect = entity.active_status_effects[0]
	assert_int(instance.ticks_remaining).is_equal(3)
	# (0.10 x 200) / 3 = 6.6667
	assert_float(instance.tick_damage).is_equal_approx(6.6667, 0.001)


func test_ac26_full_duration_deals_exactly_effect_value_fraction_of_max_hp() -> void:
	var entity := _spawn(&"goblin", 200.0)
	_mm._on_tower_attacked_status(1, entity.entity_id, 0.0, false, false, "burn", 0.10, 3.0, 0.0, false)

	for i in range(3):
		_mm._pass1b_status_effects(1.0)

	# 10% of 200 max HP = 20 total damage.
	assert_float(entity.current_hp).is_equal_approx(180.0, 0.01)
	assert_int(entity.active_status_effects.size()).is_equal(0)


func test_ac26_boss_tier_hp_scales_the_same_percentage_no_separate_tuning() -> void:
	var entity := _spawn(&"boss", 500.0)
	_mm._on_tower_attacked_status(1, entity.entity_id, 0.0, false, false, "poison", 0.08, 4.0, 0.0, false)

	for i in range(4):
		_mm._pass1b_status_effects(1.0)

	# 8% of 500 max HP = 40 total damage, same percentage as a STANDARD target.
	assert_float(entity.current_hp).is_equal_approx(460.0, 0.01)


# ---------------------------------------------------------------------------
# AC-27: reapplication stacks, does not refresh
# ---------------------------------------------------------------------------

func test_ac27_second_hit_of_same_effect_type_stacks_independently() -> void:
	var entity := _spawn(&"goblin", 200.0)

	_mm._on_tower_attacked_status(1, entity.entity_id, 0.0, false, false, "burn", 0.10, 3.0, 0.0, false)
	assert_int(entity.active_status_effects.size()).is_equal(1)

	_mm._on_tower_attacked_status(2, entity.entity_id, 0.0, false, false, "burn", 0.10, 3.0, 0.0, false)

	assert_int(entity.active_status_effects.size()).is_equal(2)
	# Both instances independently retain their own full tick count -- neither
	# was reset/refreshed by the other.
	assert_int((entity.active_status_effects[0] as ActiveStatusEffect).ticks_remaining).is_equal(3)
	assert_int((entity.active_status_effects[1] as ActiveStatusEffect).ticks_remaining).is_equal(3)


func test_ac27_two_stacked_instances_deal_roughly_double_damage() -> void:
	var entity := _spawn(&"goblin", 200.0)
	_mm._on_tower_attacked_status(1, entity.entity_id, 0.0, false, false, "burn", 0.10, 3.0, 0.0, false)
	_mm._on_tower_attacked_status(2, entity.entity_id, 0.0, false, false, "burn", 0.10, 3.0, 0.0, false)

	for i in range(3):
		_mm._pass1b_status_effects(1.0)

	# 2 x 10% of 200 = 40 total damage.
	assert_float(entity.current_hp).is_equal_approx(160.0, 0.02)


# ---------------------------------------------------------------------------
# AC-28: unrecognized effect_type (for the DoT path) is a no-op.
# "slow" is a recognized effect overall (see AC-31+) but must never create a
# DoT instance -- it's a separate mechanism entirely.
# ---------------------------------------------------------------------------

func test_ac28_slow_effect_type_creates_no_dot_instance() -> void:
	var entity := _spawn(&"goblin", 200.0)

	_mm._on_tower_attacked_status(1, entity.entity_id, 0.0, false, false, "slow", 0.15, 2.0, 0.0, false)

	assert_int(entity.active_status_effects.size()).is_equal(0)
	assert_int(entity.active_slow_effects.size()).is_equal(1)


func test_ac28_empty_effect_type_creates_no_instance() -> void:
	var entity := _spawn(&"goblin", 200.0)

	_mm._on_tower_attacked_status(1, entity.entity_id, 0.0, false, false, "", 0.0, 0.0, 0.0, false)

	assert_int(entity.active_status_effects.size()).is_equal(0)
	assert_int(entity.active_slow_effects.size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-29: a killing tick routes through the normal death path
# ---------------------------------------------------------------------------

func test_ac29_killing_tick_sets_dead_and_buffers_a_death_with_tower_kill_source() -> void:
	var entity := _spawn(&"goblin", 10.0)
	_mm._on_tower_attacked_status(1, entity.entity_id, 0.0, false, false, "burn", 1.0, 1.0, 0.0, false)  # tick_damage = 10.0

	_mm._pass1b_status_effects(1.0)

	assert_int(entity.lifecycle_state).is_equal(MonsterEntity.State.DEAD)
	assert_float(entity.current_hp).is_equal(0.0)
	assert_that(entity.last_hit_source).is_equal(&"tower")
	assert_int(_mm._pending_deaths.size()).is_equal(1)
	var died: MonsterDiedEvent = _mm._pending_deaths[0] as MonsterDiedEvent
	assert_that(died.kill_source).is_equal(&"tower")


# ---------------------------------------------------------------------------
# AC-30: target dies with other instances still pending (EC-14)
# ---------------------------------------------------------------------------

func test_ac30_death_mid_effect_discards_remaining_instances_without_error() -> void:
	var entity := _spawn(&"goblin", 20.0)
	# Two instances, each with tick_damage=10.0 -- both tick in the same
	# _pass1b_status_effects(1.0) call (single STATUS_TICK_INTERVAL boundary).
	_mm._on_tower_attacked_status(1, entity.entity_id, 0.0, false, false, "burn", 0.50, 1.0, 0.0, false)
	_mm._on_tower_attacked_status(2, entity.entity_id, 0.0, false, false, "burn", 0.50, 1.0, 0.0, false)
	assert_int(entity.active_status_effects.size()).is_equal(2)

	_mm._pass1b_status_effects(1.0)

	assert_int(entity.lifecycle_state).is_equal(MonsterEntity.State.DEAD)
	assert_float(entity.current_hp).is_equal(0.0)
	# Exactly one death buffered, not two -- the second instance's tick never ran.
	assert_int(_mm._pending_deaths.size()).is_equal(1)


func test_ac30_status_application_on_already_dead_entity_is_rejected() -> void:
	var entity := _spawn(&"goblin", 10.0)
	entity.lifecycle_state = MonsterEntity.State.DEAD

	_mm._on_tower_attacked_status(1, entity.entity_id, 0.0, false, false, "burn", 0.50, 1.0, 0.0, false)

	assert_int(entity.active_status_effects.size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-31: Slow effect -- basic application
# ---------------------------------------------------------------------------

func test_ac31_slow_hit_creates_instance_with_correct_formula() -> void:
	var entity := _spawn(&"goblin", 200.0)

	_mm._on_tower_attacked_status(1, entity.entity_id, 0.0, false, false, "slow", 0.15, 2.0, 0.0, false)

	assert_int(entity.active_slow_effects.size()).is_equal(1)
	var instance: ActiveSlowEffect = entity.active_slow_effects[0]
	assert_float(instance.remaining_duration).is_equal_approx(2.0, 0.001)
	# max(0.05, 1.0 - 0.15) = 0.85
	assert_float(instance.speed_multiplier).is_equal_approx(0.85, 0.001)


# ---------------------------------------------------------------------------
# AC-32: Slow effect -- effective speed reduction during movement
# ---------------------------------------------------------------------------

func test_ac32_effective_speed_reflects_active_slow_without_mutating_scaled_speed() -> void:
	var entity := _spawn(&"goblin", 200.0)
	entity.scaled_speed = 2.0
	_mm._on_tower_attacked_status(1, entity.entity_id, 0.0, false, false, "slow", 0.15, 2.0, 0.0, false)

	assert_float(_mm._effective_speed(entity)).is_equal_approx(1.7, 0.001)
	# scaled_speed itself is never mutated by the slow application.
	assert_float(entity.scaled_speed).is_equal_approx(2.0, 0.001)


func test_ac32_no_active_slow_effective_speed_equals_scaled_speed() -> void:
	var entity := _spawn(&"goblin", 200.0)
	entity.scaled_speed = 2.0

	assert_float(_mm._effective_speed(entity)).is_equal_approx(2.0, 0.001)


# ---------------------------------------------------------------------------
# AC-33: Slow effect -- multiplicative stacking
# ---------------------------------------------------------------------------

func test_ac33_two_slow_hits_combine_multiplicatively_not_additively() -> void:
	var entity := _spawn(&"goblin", 200.0)
	entity.scaled_speed = 2.0
	_mm._on_tower_attacked_status(1, entity.entity_id, 0.0, false, false, "slow", 0.15, 2.0, 0.0, false)
	_mm._on_tower_attacked_status(2, entity.entity_id, 0.0, false, false, "slow", 0.15, 2.0, 0.0, false)

	assert_int(entity.active_slow_effects.size()).is_equal(2)
	# 2.0 x 0.85 x 0.85 = 1.445, NOT 2.0 x 0.70 = 1.40 (the rejected additive alternative).
	assert_float(_mm._effective_speed(entity)).is_equal_approx(1.445, 0.001)


# ---------------------------------------------------------------------------
# AC-34: Slow effect -- speed_multiplier_floor prevents a full stop
# ---------------------------------------------------------------------------

func test_ac34_extreme_effect_value_is_clamped_by_the_floor() -> void:
	var entity := _spawn(&"goblin", 200.0)

	_mm._on_tower_attacked_status(1, entity.entity_id, 0.0, false, false, "slow", 0.99, 2.0, 0.0, false)

	var instance: ActiveSlowEffect = entity.active_slow_effects[0]
	# max(0.05, 1.0 - 0.99) = max(0.05, 0.01) = 0.05 -- the floor wins.
	assert_float(instance.speed_multiplier).is_equal_approx(0.05, 0.001)


# ---------------------------------------------------------------------------
# AC-35: Slow effect -- duration decay and expiry (no ticks)
# ---------------------------------------------------------------------------

func test_ac35_slow_instance_decays_and_expires_after_its_duration() -> void:
	var entity := _spawn(&"goblin", 200.0)
	entity.scaled_speed = 2.0
	_mm._on_tower_attacked_status(1, entity.entity_id, 0.0, false, false, "slow", 0.15, 1.5, 0.0, false)

	_mm._pass1b_status_effects(1.0)
	assert_float((entity.active_slow_effects[0] as ActiveSlowEffect).remaining_duration).is_equal_approx(0.5, 0.001)
	assert_int(entity.active_slow_effects.size()).is_equal(1)

	_mm._pass1b_status_effects(1.0)
	assert_int(entity.active_slow_effects.size()).is_equal(0)
	assert_float(_mm._effective_speed(entity)).is_equal_approx(2.0, 0.001)
