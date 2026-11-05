extends GdUnitTestSuite

## Menagerie Rehoming (design/quick-specs/menagerie-rehoming-2026-11-05.md):
## temperament rolls, HABITAT trait bonuses, the gold-paid Rehome, pity,
## unlock, persisted RNG and legacy saves. A fresh tree-less Menagerie per
## test; Sanctuary gold and the MissionSelect ledger are restored afterwards.

var _menagerie: Menagerie
var _spy: EventBusSpy
var _saved_gold: int = 0
var _saved_ledger: Dictionary = {}


func before_test() -> void:
	_menagerie = Menagerie.new()
	_menagerie._rng.seed = 12345
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.creature_rehomed)
	_spy.watch(GEventBus.sanctuary_gold_changed)
	_saved_gold = GSanctuaryGold.get_balance()
	_saved_ledger = GMissionSelect._completion_ledger.duplicate(true)


func after_test() -> void:
	_spy.disconnect_all()
	GSanctuaryGold._balance = _saved_gold
	GMissionSelect._completion_ledger = _saved_ledger
	_menagerie.free()


func _add(species: StringName, state: CreatureInstance.CreatureState, trait_id: StringName = Temperament.SCHOLAR, grade: int = 1) -> CreatureInstance:
	var creature := CreatureInstance.new()
	creature.creature_id = _menagerie._next_creature_id
	_menagerie._next_creature_id += 1
	creature.species = species
	creature.state = state
	creature.trait_id = trait_id
	creature.grade = grade
	_menagerie._creatures.append(creature)
	return creature


func _unlock() -> void:
	GMissionSelect.record_completion("the_gap", DifficultyRewards.BRUTAL_TIER + 1, 100.0)


func test_rehoming_grade_roll_matches_weights() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var counts: Array[int] = [0, 0, 0, 0, 0]
	# Act
	for i: int in 10000:
		counts[Temperament.roll_grade(rng) - 1] += 1
	# Assert: within 1 percentage point of 40/30/18/9/3
	for g: int in 5:
		assert_float(counts[g] / 100.0).is_equal_approx(float(Temperament.GRADE_WEIGHTS[g]), 1.0)


func test_rehoming_rolls_stay_in_the_species_tier_pool() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for tier: int in [1, 2, 3]:
		for i: int in 50:
			var rolled: Dictionary = Temperament.roll(tier, rng)
			assert_bool(Temperament.POOLS[tier].has(rolled[&"trait"])).is_true()


func test_rehoming_trait_bonus_sums_habitat_only_and_caps() -> void:
	# Arrange: Scholar 5/4/2 stars in HABITAT, a 5-star in RESERVE
	_add(&"glimmer_hare", CreatureInstance.CreatureState.HABITAT, Temperament.SCHOLAR, 5)
	_add(&"glimmer_hare", CreatureInstance.CreatureState.HABITAT, Temperament.SCHOLAR, 4)
	_add(&"glimmer_hare", CreatureInstance.CreatureState.HABITAT, Temperament.SCHOLAR, 2)
	_add(&"glimmer_hare", CreatureInstance.CreatureState.RESERVE, Temperament.SCHOLAR, 5)
	# Assert
	assert_float(_menagerie.trait_bonus(Temperament.SCHOLAR)).is_equal_approx(0.15, 0.0001)
	for i: int in 12:
		_add(&"glimmer_hare", CreatureInstance.CreatureState.HABITAT, Temperament.FORAGER_COMMON, 5)
	assert_float(_menagerie.forager_bonus("Common")).is_equal_approx(Temperament.TRAIT_CAP, 0.0001)


func test_rehoming_replaces_in_place_and_spends_gold() -> void:
	# Arrange
	_unlock()
	GSanctuaryGold._balance = 1000
	var stag: CreatureInstance = _add(&"aurora_stag", CreatureInstance.CreatureState.HABITAT)
	stag.happiness = 100.0
	var index: int = _menagerie._creatures.find(stag)
	# Act
	var new_id: int = _menagerie.rehome_creature(stag.creature_id)
	# Assert
	assert_int(new_id).is_not_equal(stag.creature_id)
	var fresh: CreatureInstance = _menagerie.get_creature(new_id)
	assert_int(_menagerie._creatures.find(fresh)).is_equal(index)
	assert_object(_menagerie.get_creature(stag.creature_id)).is_null()
	assert_str(String(fresh.species)).is_equal("aurora_stag")
	assert_int(fresh.state).is_equal(CreatureInstance.CreatureState.HABITAT)
	assert_float(fresh.happiness).is_equal(Menagerie.STARTING_HAPPINESS)
	assert_bool(Temperament.POOLS[3].has(fresh.trait_id)).is_true()
	assert_int(GSanctuaryGold.get_balance()).is_equal(400)
	assert_int(_spy.count("creature_rehomed")).is_equal(1)


func test_rehoming_rejected_when_short_locked_or_in_pen() -> void:
	# Arrange
	var stag: CreatureInstance = _add(&"aurora_stag", CreatureInstance.CreatureState.HABITAT)
	GSanctuaryGold._balance = 5000
	# Locked before any Ascension clear
	assert_int(_menagerie.rehome_creature(stag.creature_id)).is_equal(-1)
	_unlock()
	# Short by one
	GSanctuaryGold._balance = 599
	assert_int(_menagerie.rehome_creature(stag.creature_id)).is_equal(-1)
	assert_int(GSanctuaryGold.get_balance()).is_equal(599)
	# In a breeding pen
	GSanctuaryGold._balance = 5000
	stag.state = CreatureInstance.CreatureState.BREEDING_PEN
	assert_int(_menagerie.rehome_creature(stag.creature_id)).is_equal(-1)
	assert_int(_spy.count("creature_rehomed")).is_equal(0)


func test_rehoming_pity_guarantees_high_grade_after_threshold() -> void:
	# Arrange
	_unlock()
	GSanctuaryGold._balance = 100000
	var hare: CreatureInstance = _add(&"glimmer_hare", CreatureInstance.CreatureState.RESERVE)
	_menagerie._rehomes_since_high_grade = Menagerie.PITY_THRESHOLD
	# Act
	var new_id: int = _menagerie.rehome_creature(hare.creature_id)
	# Assert
	assert_int(_menagerie.get_creature(new_id).grade).is_greater_equal(Temperament.HIGH_GRADE)
	assert_int(_menagerie.get_rehomes_since_high_grade()).is_equal(0)


func test_rehoming_roll_survives_save_reload() -> void:
	# Arrange
	_unlock()
	GSanctuaryGold._balance = 100000
	_add(&"duskfang_fox", CreatureInstance.CreatureState.RESERVE)
	var saved: Dictionary = _menagerie.get_save_data()
	var first: CreatureInstance = _menagerie.get_creature(_menagerie.rehome_creature(0))
	# Act: reload the earlier save and rehome again
	assert_bool(_menagerie.restore_save_data(saved)).is_true()
	var second: CreatureInstance = _menagerie.get_creature(_menagerie.rehome_creature(0))
	# Assert
	assert_str(String(second.trait_id)).is_equal(String(first.trait_id))
	assert_int(second.grade).is_equal(first.grade)


func test_rehoming_legacy_save_gets_deterministic_capped_temperament() -> void:
	# Arrange: a pre-feature save entry has no trait_id/grade
	var data: Dictionary = {
		"creatures": [{"creature_id": 4, "species": "aurora_stag", "state": 1, "happiness": 80.0, "missions_since_tended": 0}],
		"breeding_pens": [{"occupant_ids": [], "breeding_missions_remaining": -1}, {"occupant_ids": [], "breeding_missions_remaining": -1}],
		"habitat_capacity": 4, "next_creature_id": 5,
	}
	# Act
	assert_bool(_menagerie.restore_save_data(data)).is_true()
	var a: CreatureInstance = _menagerie.get_creature(4)
	var trait_a: StringName = a.trait_id
	var grade_a: int = a.grade
	assert_bool(_menagerie.restore_save_data(data)).is_true()
	# Assert
	assert_bool(Temperament.POOLS[3].has(trait_a)).is_true()
	assert_int(grade_a).is_less_equal(3)
	assert_str(String(_menagerie.get_creature(4).trait_id)).is_equal(String(trait_a))
	assert_int(_menagerie.get_creature(4).grade).is_equal(grade_a)
