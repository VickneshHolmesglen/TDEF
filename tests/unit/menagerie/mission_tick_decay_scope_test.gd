## Unit tests for Story 013 (TR-menag-002, mission-tick scope; ADR-0026):
## only HABITAT creatures decay on mission_launched (AC-19); up to 10
## HABITAT creatures each fire an independent creature_happiness_changed,
## no batching (AC-42).
extends GdUnitTestSuite

var _menagerie: Menagerie
var _spy: EventBusSpy


func before_test() -> void:
	_menagerie = Menagerie.new()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.creature_happiness_changed)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _menagerie != null and is_instance_valid(_menagerie):
		_menagerie.free()
	_menagerie = null


func _add_creature(state: CreatureInstance.CreatureState, happiness: float = 70.0) -> CreatureInstance:
	var creature := CreatureInstance.new()
	creature.creature_id = _menagerie._next_creature_id
	_menagerie._next_creature_id += 1
	creature.state = state
	creature.happiness = happiness
	_menagerie._creatures.append(creature)
	return creature


# ---------------------------------------------------------------------------
# AC-19: only HABITAT creatures decay; RESERVE/BREEDING_PEN untouched.
# ---------------------------------------------------------------------------

func test_only_habitat_creature_decays_others_untouched() -> void:
	var habitat: CreatureInstance = _add_creature(CreatureInstance.CreatureState.HABITAT, 70.0)
	var reserve: CreatureInstance = _add_creature(CreatureInstance.CreatureState.RESERVE, 70.0)
	var breeding: CreatureInstance = _add_creature(CreatureInstance.CreatureState.BREEDING_PEN, 70.0)

	_menagerie._on_mission_launched("the_gap", PackedStringArray(), 1)

	assert_float(habitat.happiness).is_equal(62.0)  # 70-8
	assert_float(reserve.happiness).is_equal(70.0)   # unchanged
	assert_float(breeding.happiness).is_equal(70.0)  # unchanged
	assert_int(habitat.missions_since_tended).is_equal(1)
	assert_int(reserve.missions_since_tended).is_equal(0)


# ---------------------------------------------------------------------------
# AC-42: up to 10 HABITAT creatures each fire an independent
# creature_happiness_changed in one mission_launched — no batching.
# ---------------------------------------------------------------------------

func test_ten_habitat_creatures_each_fire_independent_happiness_changed() -> void:
	for i: int in range(10):
		_add_creature(CreatureInstance.CreatureState.HABITAT, 70.0)

	_menagerie._on_mission_launched("the_gap", PackedStringArray(), 1)

	assert_int(_spy.count("creature_happiness_changed")).is_equal(10)


## Regression test (code review, 2026-07-18): every emission in a single
## decay pass must carry the SAME, correctly-computed final aggregate bonus.
## Prior to the fix documented in _tick_decay()'s own comment,
## compute_quality_bonus() was called inside the per-creature decay loop, so
## every emission except the last carried a stale bonus computed from a
## partially-decayed HABITAT set. Two creatures at different starting
## happiness values make a stale-vs-final bonus distinguishable: post-decay
## happiness is 62.0 and 82.0 (average 72.0, bonus = clamp(1.0 + 0.5*0.72,
## 1.0, 1.5) = 1.36). The old bug would have emitted the first creature's
## event with a bonus computed while the second creature's happiness was
## still pre-decay (90.0, not 82.0) — a different, wrong value.
func test_all_emissions_in_one_decay_pass_share_the_same_final_bonus() -> void:
	_add_creature(CreatureInstance.CreatureState.HABITAT, 70.0)
	_add_creature(CreatureInstance.CreatureState.HABITAT, 90.0)

	_menagerie._on_mission_launched("the_gap", PackedStringArray(), 1)

	assert_int(_spy.count("creature_happiness_changed")).is_equal(2)
	var emissions: Array = _spy.emissions["creature_happiness_changed"] as Array
	var first_bonus: float = (emissions[0] as Array)[2] as float
	var second_bonus: float = (emissions[1] as Array)[2] as float
	assert_float(first_bonus).is_equal_approx(1.36, 0.001)
	assert_float(second_bonus).is_equal_approx(1.36, 0.001)
