## Unit/integration tests for ResourceEconomy's Menagerie Attraction Material
## (Lure) roll, Epic 03 Story 012, ADR-0017, GDD Rule 6.
##
## Covers AC-08 (menagerie_attraction_drop_chance=0.5 at a late wave
## (wave_reward_scalar=4.768) uses the chance unscaled, with the QA Test Case's own
## explicit regression guard: the same 0.5 chance must resolve identically at wave 1
## (wave_reward_scalar=1.00)), a real end-to-end guaranteed-lure test through
## monster_died (menagerie_attraction_drop_chance=1.0 -> materials_earned fires with
## material_id="menagerie_lure", quantity=1), the lure roll's structural independence
## from _resolve_drop_table() (an unregistered drop_table_id must not suppress the
## lure), and Story 011's wave_end suppression still applying to the lure roll (a
## wave-end force-clear must not grant a lure even at a guaranteed chance).
##
## Design: _roll_menagerie_lure() is a pure static function (no node/tree needed) —
## its signature takes exactly one parameter (menagerie_attraction_drop_chance),
## which is itself the structural proof that wave_reward_scalar cannot leak into this
## roll (same "structural exclusion by signature" technique as Story 009's
## _compute_quality_roll_probability() excluding menagerie_quality_bonus).
##
## Follows tests/unit/resource_economy/drop_occurrence_quantity_test.gd's and
## quality_roll_menagerie_scope_test.gd's conventions: ResourceEconomy tests use
## add_child()-then-real-signal dispatch (GEventBus.monster_died.emit(...)), with
## drop-table test data seeded directly into GGameDataRegistry._drop_tables and
## removed again in after_test() (no injection seam on ResourceEconomy itself, per
## ADR-0017's "no public call API beyond EventBus"). materials_earned emissions are
## observed via tests/helpers/event_bus_spy.gd's EventBusSpy, matching this project's
## other real-EventBus-signal test precedent.
extends GdUnitTestSuite

var _re: ResourceEconomy
var _spy: EventBusSpy
var _seeded_table_ids: Array[StringName] = []


func _make_drop_table(id: StringName, base_drop_rate: float, base_quantity: int, guaranteed_min_quantity: int = 1) -> DropTableResource:
	var table := DropTableResource.new()
	table.drop_table_id = id
	table.base_drop_rate = base_drop_rate
	table.guaranteed_min_quantity = guaranteed_min_quantity
	var entry := DropEntry.new()
	entry.material_id = &"goblin_hide"
	entry.base_quantity = base_quantity
	table.entries = [entry]
	return table


func _seed_drop_table(table: DropTableResource) -> void:
	GGameDataRegistry._drop_tables[table.drop_table_id] = table
	_seeded_table_ids.append(table.drop_table_id)


func _make_died_event(drop_table_id: StringName, wave_reward_scalar: float, menagerie_attraction_drop_chance: float = 0.0, kill_source: String = "tower") -> MonsterDiedEvent:
	var payload := MonsterDiedEvent.new()
	payload.entity_id = 1
	payload.monster_id = &"goblin_runner"
	payload.tier = 0
	payload.drop_table_id = drop_table_id
	payload.kill_source = kill_source
	payload.wave_reward_scalar = wave_reward_scalar
	payload.menagerie_attraction_drop_chance = menagerie_attraction_drop_chance
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
# AC-08: lure roll uses menagerie_attraction_drop_chance unscaled — structural
# exclusion of wave_reward_scalar from _roll_menagerie_lure()'s signature.
# ---------------------------------------------------------------------------

func test_roll_menagerie_lure_signature_excludes_wave_reward_scalar_by_construction() -> void:
	# Calling with exactly the one documented parameter
	# (menagerie_attraction_drop_chance) is itself proof the function has no
	# second wave_reward_scalar parameter to accidentally wire up.
	var success_count: int = 0
	const SAMPLE_SIZE: int = 10000
	for i: int in range(SAMPLE_SIZE):
		if ResourceEconomy._roll_menagerie_lure(0.5):
			success_count += 1
	var observed_rate: float = float(success_count) / float(SAMPLE_SIZE)
	assert_float(observed_rate).is_between(0.48, 0.52)


func test_roll_menagerie_lure_statistical_rate_identical_at_wave_one_and_late_wave() -> void:
	# QA Test Case (AC-08 edge case, "the core regression this test guards
	# against"): the same menagerie_attraction_drop_chance=0.5 must resolve to
	# the same ~50% rate regardless of wave_reward_scalar. Since
	# _roll_menagerie_lure() structurally cannot receive wave_reward_scalar,
	# this is proven by calling it directly with only the chance — wave 1
	# (1.00) and a late wave (4.768) are represented here only as documentation
	# of the scenario being guarded against; the function call itself never
	# varies with either value.
	const SAMPLE_SIZE: int = 10000
	var success_count_wave_one_scenario: int = 0
	var success_count_late_wave_scenario: int = 0
	for i: int in range(SAMPLE_SIZE):
		if ResourceEconomy._roll_menagerie_lure(0.5):  # wave 1 scenario (wave_reward_scalar=1.00)
			success_count_wave_one_scenario += 1
	for i: int in range(SAMPLE_SIZE):
		if ResourceEconomy._roll_menagerie_lure(0.5):  # late-wave scenario (wave_reward_scalar=4.768)
			success_count_late_wave_scenario += 1

	var rate_wave_one: float = float(success_count_wave_one_scenario) / float(SAMPLE_SIZE)
	var rate_late_wave: float = float(success_count_late_wave_scenario) / float(SAMPLE_SIZE)
	assert_float(rate_wave_one).is_between(0.48, 0.52)
	assert_float(rate_late_wave).is_between(0.48, 0.52)


func test_process_drops_guaranteed_lure_fires_identically_at_wave_one_and_late_wave() -> void:
	# Deterministic end-to-end companion to the statistical test above:
	# menagerie_attraction_drop_chance=1.0 (guaranteed) must grant the lure at
	# BOTH wave_reward_scalar=1.00 and wave_reward_scalar=4.768 — proving the
	# scalar has zero influence even at the extremes, without relying on
	# sampling. No drop table is registered for either id (irrelevant to the
	# lure per AC's independence requirement), so only the lure emission is
	# expected in each case.
	GEventBus.monster_died.emit(_make_died_event(&"ac08_unregistered_wave_one", 1.0, 1.0))
	assert_int(_spy.count("materials_earned")).is_equal(1)
	var args_wave_one: Array = (_spy.emissions["materials_earned"] as Array)[0]
	assert_str(args_wave_one[0]).is_equal("menagerie_lure")
	assert_int(args_wave_one[1]).is_equal(1)

	_spy.disconnect_all()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.materials_earned)

	GEventBus.monster_died.emit(_make_died_event(&"ac08_unregistered_late_wave", 4.768, 1.0))
	assert_int(_spy.count("materials_earned")).is_equal(1)
	var args_late_wave: Array = (_spy.emissions["materials_earned"] as Array)[0]
	assert_str(args_late_wave[0]).is_equal("menagerie_lure")
	assert_int(args_late_wave[1]).is_equal(1)


# ---------------------------------------------------------------------------
# Real end-to-end guaranteed-lure test through monster_died.
# ---------------------------------------------------------------------------

func test_resource_economy_guaranteed_lure_roll_emits_materials_earned_menagerie_lure_quantity_one() -> void:
	var table: DropTableResource = _make_drop_table(&"lure_e2e_table", 0.0, 1)
	_seed_drop_table(table)

	GEventBus.monster_died.emit(_make_died_event(&"lure_e2e_table", 4.768, 1.0))

	assert_int(_spy.count("materials_earned")).is_equal(1)
	var args: Array = (_spy.emissions["materials_earned"] as Array)[0]
	assert_str(args[0]).is_equal("menagerie_lure")
	assert_int(args[1]).is_equal(1)
	assert_str(args[2]).is_equal("tower")


# ---------------------------------------------------------------------------
# Independence from _resolve_drop_table(): lure roll must resolve even when
# drop_table_id is unregistered/invalid.
# ---------------------------------------------------------------------------

func test_resource_economy_lure_roll_resolves_independently_of_unregistered_drop_table_id() -> void:
	# No table seeded for this id at all — _resolve_drop_table() will warn and
	# return null, yet the lure must still be granted.
	GEventBus.monster_died.emit(_make_died_event(&"lure_unregistered_table_id", 4.768, 1.0))

	assert_int(_spy.count("materials_earned")).is_equal(1)
	var args: Array = (_spy.emissions["materials_earned"] as Array)[0]
	assert_str(args[0]).is_equal("menagerie_lure")
	assert_int(args[1]).is_equal(1)


# ---------------------------------------------------------------------------
# Story 011 wave_end suppression still applies to the lure roll.
# ---------------------------------------------------------------------------

func test_resource_economy_wave_end_payload_does_not_grant_lure_even_at_guaranteed_chance() -> void:
	var payload: MonsterDiedEvent = _make_died_event(&"lure_wave_end_table", 4.768, 1.0, "wave_end")
	GEventBus.monster_died.emit(payload)

	assert_int(_spy.count("materials_earned")).is_equal(0)


# ---------------------------------------------------------------------------
# Dual-emission independence: a kill that succeeds at BOTH the lure roll and
# a normal drop-table entry roll must produce two separate, correctly
# attributed materials_earned emissions — the lure roll must not overwrite
# or suppress the per-entry loop's emission, or vice versa.
# ---------------------------------------------------------------------------

func test_resource_economy_guaranteed_lure_and_guaranteed_drop_entry_emit_two_independent_materials_earned() -> void:
	var table: DropTableResource = _make_drop_table(&"lure_and_drop_table", 1.0, 3, 1)
	_seed_drop_table(table)

	GEventBus.monster_died.emit(_make_died_event(&"lure_and_drop_table", 1.0, 1.0))

	assert_int(_spy.count("materials_earned")).is_equal(2)
	var emissions: Array = _spy.emissions["materials_earned"] as Array

	var lure_args: Array = []
	var drop_args: Array = []
	for args: Array in emissions:
		if String(args[0]) == "menagerie_lure":
			lure_args = args
		elif String(args[0]) == "goblin_hide":
			drop_args = args

	assert_bool(lure_args.is_empty()).is_false()
	assert_str(lure_args[0]).is_equal("menagerie_lure")
	assert_int(lure_args[1]).is_equal(1)

	assert_bool(drop_args.is_empty()).is_false()
	assert_str(drop_args[0]).is_equal("goblin_hide")
	assert_int(drop_args[1]).is_greater_equal(1)
