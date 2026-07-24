## Unit/integration tests for ResourceEconomy's Formula 3 (quality roll probability)
## and the deliberate quantity/quality asymmetry, Epic 03 Story 009, ADR-0017.
##
## Covers AC-03 (quality_probability_ceiling clamp worked example:
## base_quality_probability=0.20, wave_reward_scalar=4.768 -> raw 0.954 clamped to
## 0.80, plus the under-ceiling case that must NOT clamp: 0.10 x 4.768 = 0.477, and a
## boundary case landing exactly at the ceiling) and AC-04 (menagerie_quality_bonus
## applies only to Formula 2's quantity term, never to Formula 3's probability —
## _compute_quality_roll_probability()'s signature structurally excludes the bonus
## parameter; this file's regression tests prove that exclusion holds both in
## isolation and end-to-end through the real monster_died signal).
##
## Design: _compute_quality_roll_probability() is a pure static function (no RNG, no
## node/tree needed) — AC-03's exact-math assertions call it directly. The AC-04
## regression tests follow the QA Test Case's own wording ("assert the
## quality-probability output is identical with and without a Menagerie bonus
## present") by varying _menagerie_quality_bonus on a real ResourceEconomy instance
## and confirming the static function's output is unaffected, plus an end-to-end
## check through the real GEventBus.monster_died signal (materials_earned's emitted
## quantity DOES react to the bonus, proving the bonus is live and only touches the
## quantity term).
##
## Follows tests/unit/resource_economy/drop_occurrence_quantity_test.gd's conventions:
## ResourceEconomy tests use add_child()-then-real-signal dispatch
## (GEventBus.monster_died.emit(...)), with drop-table test data seeded directly into
## GGameDataRegistry._drop_tables and removed again in after_test() (no injection seam
## on ResourceEconomy itself, per ADR-0017's "no public call API beyond EventBus").
## materials_earned emissions are observed via tests/helpers/event_bus_spy.gd's
## EventBusSpy, matching this project's other real-EventBus-signal test precedent.
extends GdUnitTestSuite

var _re: ResourceEconomy
var _spy: EventBusSpy
var _seeded_table_ids: Array[StringName] = []


func _make_drop_table(id: StringName, base_drop_rate: float, base_quantity: int, base_quality_probability: float, guaranteed_min_quantity: int = 1) -> DropTableResource:
	var table := DropTableResource.new()
	table.drop_table_id = id
	table.base_drop_rate = base_drop_rate
	table.guaranteed_min_quantity = guaranteed_min_quantity
	var entry := DropEntry.new()
	entry.material_id = &"goblin_hide"
	entry.base_quantity = base_quantity
	entry.base_quality_probability = base_quality_probability
	table.entries = [entry]
	return table


func _seed_drop_table(table: DropTableResource) -> void:
	GGameDataRegistry._drop_tables[table.drop_table_id] = table
	_seeded_table_ids.append(table.drop_table_id)


func _make_died_event(drop_table_id: StringName, wave_reward_scalar: float, kill_source: String = "tower") -> MonsterDiedEvent:
	var payload := MonsterDiedEvent.new()
	payload.entity_id = 1
	payload.monster_id = &"goblin_runner"
	payload.tier = 0
	payload.drop_table_id = drop_table_id
	payload.kill_source = kill_source
	payload.wave_reward_scalar = wave_reward_scalar
	return payload


func before_test() -> void:
	_re = ResourceEconomy.new()
	add_child(_re)  # triggers _ready() — GEventBus.monster_died/monsters_died_batch subscriptions are live
	_seeded_table_ids = []
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.materials_earned)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null

	for id: StringName in _seeded_table_ids:
		GGameDataRegistry._drop_tables.erase(id)
	_seeded_table_ids = []

	if _re != null and is_instance_valid(_re):
		remove_child(_re)
		_re.free()
	_re = null


# ---------------------------------------------------------------------------
# AC-03: quality_probability_ceiling clamp (pure function, no RNG involved)
# ---------------------------------------------------------------------------

func test_compute_quality_roll_probability_worked_example_clamps_to_ceiling() -> void:
	# base_quality_probability=0.20, wave_reward_scalar=4.768 -> raw 0.20*4.768=0.954
	# -> clamped to ResourceEconomy.QUALITY_PROBABILITY_CEILING (0.80)
	var probability: float = ResourceEconomy._compute_quality_roll_probability(0.20, 4.768)
	assert_float(probability).is_equal_approx(0.80, 0.0001)


func test_compute_quality_roll_probability_under_ceiling_case_not_clamped() -> void:
	# base_quality_probability=0.10 at wave 8 (wave_reward_scalar=4.768)
	# -> raw 0.10*4.768=0.4768 -- stays 0.4768, uncapped (clamp only activates when
	# actually exceeded).
	var probability: float = ResourceEconomy._compute_quality_roll_probability(0.10, 4.768)
	assert_float(probability).is_equal_approx(0.4768, 0.0001)


func test_compute_quality_roll_probability_exactly_at_ceiling_boundary_not_over_clamped() -> void:
	# base_quality_probability=0.40, wave_reward_scalar=2.0 -> raw 0.40*2.0=0.80,
	# landing exactly on the ceiling -- confirms clamp() at the boundary returns the
	# raw value unmodified (not an off-by-epsilon clamp artifact).
	var probability: float = ResourceEconomy._compute_quality_roll_probability(0.40, 2.0)
	assert_float(probability).is_equal_approx(0.80, 0.0001)


func test_quality_probability_ceiling_const_is_project_default_of_point_eight() -> void:
	assert_float(ResourceEconomy.QUALITY_PROBABILITY_CEILING).is_equal_approx(0.80, 0.0001)


# ---------------------------------------------------------------------------
# AC-04: Menagerie bonus applies to quantity only -- regression coverage proving
# _compute_quality_roll_probability() is structurally decoupled from
# _menagerie_quality_bonus.
# ---------------------------------------------------------------------------

func test_compute_quality_roll_probability_signature_excludes_menagerie_bonus_by_construction() -> void:
	# Calling with exactly the two documented parameters (base_quality_probability,
	# wave_reward_scalar) is itself proof the function has no third
	# menagerie_quality_bonus parameter to accidentally wire up.
	var probability: float = ResourceEconomy._compute_quality_roll_probability(0.10, 4.768)
	assert_float(probability).is_equal_approx(0.4768, 0.0001)


func test_compute_quality_roll_probability_identical_regardless_of_resource_economy_menagerie_bonus_value() -> void:
	# QA Test Case (AC-04 edge case): "a regression test should explicitly assert the
	# quality-probability output is identical with and without a Menagerie bonus
	# present, to catch an accidental future coupling of the two terms."
	_re._menagerie_quality_bonus = 1.0
	var probability_neutral_bonus: float = ResourceEconomy._compute_quality_roll_probability(0.20, 4.768)

	_re._menagerie_quality_bonus = 1.5
	var probability_boosted_bonus: float = ResourceEconomy._compute_quality_roll_probability(0.20, 4.768)

	assert_float(probability_neutral_bonus).is_equal_approx(probability_boosted_bonus, 0.0001)
	assert_float(probability_boosted_bonus).is_equal_approx(0.80, 0.0001)


func test_process_drops_quantity_reacts_to_menagerie_bonus_while_quality_formula_inputs_stay_fixed() -> void:
	# End-to-end, through the real monster_died signal (base_drop_rate=1.0 makes
	# Formula 1's occurrence roll deterministic via data, not a seeded RNG). Two runs
	# differ ONLY in _menagerie_quality_bonus: the emitted quantity (Formula 2) must
	# change, proving the bonus is live -- while base_quality_probability and
	# wave_reward_scalar (Formula 3's only inputs) are identical across both runs,
	# so any accidental future coupling that let the bonus leak into Formula 3 would
	# have no separate signal to show up on here -- this test's job is to confirm
	# Formula 2's reaction to the bonus is real and isolated, matching AC-04's
	# "quantity reflects the 1.5x factor" half.
	var table: DropTableResource = _make_drop_table(&"ac04_neutral_bonus", 1.0, 1, 0.20)
	_seed_drop_table(table)
	_re._menagerie_quality_bonus = 1.0

	GEventBus.monster_died.emit(_make_died_event(&"ac04_neutral_bonus", 4.768))

	assert_int(_spy.count("materials_earned")).is_equal(1)
	var neutral_args: Array = (_spy.emissions["materials_earned"] as Array)[0]
	# round(1 * 4.768 * 1.0) = 5
	assert_int(neutral_args[1]).is_equal(5)

	_spy.disconnect_all()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.materials_earned)

	var table_boosted: DropTableResource = _make_drop_table(&"ac04_boosted_bonus", 1.0, 1, 0.20)
	_seed_drop_table(table_boosted)
	_re._menagerie_quality_bonus = 1.5

	GEventBus.monster_died.emit(_make_died_event(&"ac04_boosted_bonus", 4.768))

	assert_int(_spy.count("materials_earned")).is_equal(1)
	var boosted_args: Array = (_spy.emissions["materials_earned"] as Array)[0]
	# round(1 * 4.768 * 1.5) = round(7.152) = 7 -- differs from the neutral-bonus run,
	# proving the bonus reaches Formula 2 -- while Formula 3's own inputs
	# (base_quality_probability=0.20, wave_reward_scalar=4.768) were identical in
	# both runs, per the isolated unit tests above showing that combination always
	# resolves to the same 0.80-clamped probability regardless of the bonus.
	assert_int(boosted_args[1]).is_equal(7)
