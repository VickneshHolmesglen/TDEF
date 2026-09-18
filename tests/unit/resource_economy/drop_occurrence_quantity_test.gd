## Unit/integration tests for ResourceEconomy's Formula 1 (drop occurrence roll) and
## Formula 2 (drop quantity) resolution, Epic 03 Story 008, ADR-0017.
##
## Covers AC-01 (worked-example quantity: base_quantity=1, wave_reward_scalar=4.768,
## menagerie_quality_bonus=1.3 -> round(6.198) = 6, plus the wave-1 minimum-scale
## edge case), AC-02 (guaranteed_min_quantity floor on a successful roll, distinct
## from a failed roll staying at 0 total drops), and AC-12 (base_drop_rate=0.45's
## occurrence rate over a 10,000-sample statistical test, isolated to Formula 1 only).
##
## Design: _compute_drop_quantity()/_roll_drop_occurs() are pure static functions on
## ResourceEconomy (no RNG in the quantity formula, no node/tree needed) — AC-01/AC-02's
## exact-math assertions call them directly, with no need to force a real random roll.
## The end-to-end (real GEventBus.monster_died signal -> materials_earned emission)
## half of AC-01/AC-02 uses DropTableResource.base_drop_rate = 1.0/0.0 to make the
## OCCURRENCE roll deterministic via data (real, unseeded randf() always satisfies
## `< 1.0` and never satisfies `< 0.0`) — not an injected/seeded RNG, matching
## test-standards.md and this project's existing hero.gd randf() precedent. AC-12 is
## the one place real randomness is exercised over its full, load-bearing 10,000-loop
## sample size (do not reduce it — the tolerance math depends on that n).
##
## Follows tests/unit/resource_economy/drop_table_schema_registry_test.gd's
## conventions: ResourceEconomy tests use add_child()-then-real-signal dispatch
## (GEventBus.monster_died.emit(...)), with drop-table test data seeded directly into
## GGameDataRegistry._drop_tables and removed again in after_test() (no injection seam
## on ResourceEconomy itself, per ADR-0017's "no public call API beyond EventBus").
## materials_earned emissions are observed via tests/helpers/event_bus_spy.gd's
## EventBusSpy, matching this project's other real-EventBus-signal test precedent.
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
# AC-01: quantity formula worked example (pure function, no RNG involved)
# ---------------------------------------------------------------------------

func test_compute_drop_quantity_worked_example_rounds_to_six() -> void:
	# base_quantity=1, wave_reward_scalar=4.768, menagerie_quality_bonus=1.3
	# -> round(1 * 4.768 * 1.3) = round(6.198) = 6
	var quantity: int = ResourceEconomy._compute_drop_quantity(1, 4.768, 1.3, 1)
	assert_int(quantity).is_equal(6)


func test_compute_drop_quantity_wave_one_minimum_scale_edge_case() -> void:
	# wave_reward_scalar=1.00 (wave 1), neutral quality bonus, base_quantity=1
	# -> round(1 * 1.0 * 1.0) = 1
	var quantity: int = ResourceEconomy._compute_drop_quantity(1, 1.0, 1.0, 1)
	assert_int(quantity).is_equal(1)


# ---------------------------------------------------------------------------
# AC-02: quantity floor enforcement (pure function, no RNG involved)
# ---------------------------------------------------------------------------

func test_compute_drop_quantity_floors_to_guaranteed_minimum_not_zero() -> void:
	# base_quantity=1, wave_reward_scalar=0.1 -> round(0.1) = 0, floored to 1.
	var quantity: int = ResourceEconomy._compute_drop_quantity(1, 0.1, 1.0, 1)
	assert_int(quantity).is_equal(1)


func test_compute_drop_quantity_floor_respects_configured_guaranteed_minimum() -> void:
	# Same rounds-to-zero input, but guaranteed_min_quantity=3 -> floor is 3, not 1.
	var quantity: int = ResourceEconomy._compute_drop_quantity(1, 0.1, 1.0, 3)
	assert_int(quantity).is_equal(3)


# ---------------------------------------------------------------------------
# AC-01 / AC-02: end-to-end via the real monster_died signal, with occurrence
# made deterministic via base_drop_rate = 1.0 (guaranteed success) / 0.0
# (guaranteed failure) — data-driven determinism, not a seeded RNG.
# ---------------------------------------------------------------------------

func test_resource_economy_guaranteed_success_roll_emits_materials_earned_with_worked_example_quantity() -> void:
	var table: DropTableResource = _make_drop_table(&"ac01_worked_example", 1.0, 1)
	_seed_drop_table(table)
	_re._menagerie_quality_bonus = 1.3

	GEventBus.monster_died.emit(_make_died_event(&"ac01_worked_example", 4.768))

	assert_int(_spy.count("materials_earned")).is_equal(1)
	var args: Array = (_spy.emissions["materials_earned"] as Array)[0]
	assert_str(args[0]).is_equal("goblin_hide")
	assert_int(args[1]).is_equal(6)
	assert_str(args[2]).is_equal("tower")


func test_resource_economy_guaranteed_success_roll_below_floor_still_reports_guaranteed_minimum() -> void:
	var table: DropTableResource = _make_drop_table(&"ac02_floor", 1.0, 1, 1)
	_seed_drop_table(table)

	GEventBus.monster_died.emit(_make_died_event(&"ac02_floor", 0.1))

	assert_int(_spy.count("materials_earned")).is_equal(1)
	var args: Array = (_spy.emissions["materials_earned"] as Array)[0]
	assert_int(args[1]).is_equal(1)


func test_resource_economy_guaranteed_failure_roll_emits_no_materials_earned() -> void:
	# base_drop_rate=0.0 -> Formula 1 always fails: total drops = 0, distinct from
	# the AC-02 floor (which only applies once a drop has already occurred).
	var table: DropTableResource = _make_drop_table(&"ac02_failed_roll", 0.0, 1)
	_seed_drop_table(table)

	GEventBus.monster_died.emit(_make_died_event(&"ac02_failed_roll", 4.768))

	assert_int(_spy.count("materials_earned")).is_equal(0)


func test_resource_economy_resolves_batch_entries_independently_no_shared_rounding_state() -> void:
	var table: DropTableResource = _make_drop_table(&"ac01_batch", 1.0, 1)
	_seed_drop_table(table)
	_re._menagerie_quality_bonus = 1.3

	var batch: Array[MonsterDiedEvent] = [
		_make_died_event(&"ac01_batch", 4.768, "tower"),
		_make_died_event(&"ac01_batch", 4.768, "tower"),
	]
	GEventBus.monsters_died_batch.emit(batch)

	assert_int(_spy.count("materials_earned")).is_equal(2)
	var emissions: Array = _spy.emissions["materials_earned"]
	for entry_args: Array in emissions:
		assert_int(entry_args[1]).is_equal(6)


## TD-econ-004 gap 2: existing coverage only proves independence ACROSS
## separate monster_died/batch events against single-entry tables. No test
## proved Rule 9's "no shared/accumulated rounding state" for MULTIPLE
## DropEntry items within ONE table on a single kill.
func test_resource_economy_resolves_multiple_entries_in_one_table_independently_on_a_single_kill() -> void:
	var table := DropTableResource.new()
	table.drop_table_id = &"multi_entry_single_kill"
	table.base_drop_rate = 1.0  # guaranteed occurrence for both entries
	table.guaranteed_min_quantity = 1

	var entry_a := DropEntry.new()
	entry_a.material_id = &"goblin_hide"
	entry_a.base_quantity = 1
	var entry_b := DropEntry.new()
	entry_b.material_id = &"goblin_fang"
	entry_b.base_quantity = 3
	table.entries = [entry_a, entry_b]
	_seed_drop_table(table)

	# base_quantity=1, wave_reward_scalar=4.768, no Menagerie bonus -> round(4.768) = 5
	# base_quantity=3, same scalar -> round(14.304) = 14
	GEventBus.monster_died.emit(_make_died_event(&"multi_entry_single_kill", 4.768, "tower"))

	assert_int(_spy.count("materials_earned")).is_equal(2)
	var emissions: Array = _spy.emissions["materials_earned"]
	var by_material: Dictionary = {}
	for entry_args: Array in emissions:
		by_material[entry_args[0]] = entry_args[1]
	assert_int(by_material.get("goblin_hide", -1)).is_equal(5)
	assert_int(by_material.get("goblin_fang", -1)).is_equal(14)


# ---------------------------------------------------------------------------
# AC-12 [Statistical]: Formula 1's occurrence rate, isolated from full drop
# resolution. Real, unseeded randf() over the AC's own load-bearing 10,000-sample
# size — for p=0.45, n=10000, stddev ~= 0.005, so the +/-2% band is ~4 standard
# deviations; a real failure from pure chance is expected roughly 1 in 15,000+
# runs, an acceptable non-flaky bound for a CI-run statistical test.
# ---------------------------------------------------------------------------

func test_roll_drop_occurs_statistical_rate_within_two_percent_of_base_drop_rate() -> void:
	const SAMPLE_SIZE: int = 10000
	const BASE_DROP_RATE: float = 0.45
	var success_count: int = 0
	for i: int in range(SAMPLE_SIZE):
		if ResourceEconomy._roll_drop_occurs(BASE_DROP_RATE):
			success_count += 1

	var observed_rate: float = float(success_count) / float(SAMPLE_SIZE)
	assert_float(observed_rate).is_between(0.43, 0.47)


# ---------------------------------------------------------------------------
# Hero Combat & Stats Redesign (2026-09-18), Section 3.4.1: Luck boosts
# DropEntry occurrence chance directly.
# ---------------------------------------------------------------------------

func test_hero_luck_drop_bonus_increases_effective_occurrence_rate() -> void:
	const SAMPLE_SIZE: int = 10000
	const BASE_DROP_RATE: float = 0.30
	const LUCK_BONUS: float = 0.20
	_re.set_hero_luck_drop_bonus(LUCK_BONUS)
	var success_count: int = 0
	for i: int in range(SAMPLE_SIZE):
		if ResourceEconomy._roll_drop_occurs(clampf(BASE_DROP_RATE + _re._hero_luck_drop_bonus, 0.0, 1.0)):
			success_count += 1
	# Expected effective rate: 0.30 + 0.20 = 0.50
	var observed_rate: float = float(success_count) / float(SAMPLE_SIZE)
	assert_float(observed_rate).is_between(0.48, 0.52)


func test_hero_luck_drop_bonus_clamps_effective_rate_to_one() -> void:
	_re.set_hero_luck_drop_bonus(0.90)
	var table: DropTableResource = _make_drop_table(&"luck_clamp_test", 0.50, 1)
	_seed_drop_table(table)

	# 0.50 + 0.90 = 1.40, must clamp to 1.0 (guaranteed occurrence), never error.
	GEventBus.monster_died.emit(_make_died_event(&"luck_clamp_test", 1.0))

	assert_int(_spy.count("materials_earned")).is_equal(1)


func test_zero_luck_bonus_leaves_base_drop_rate_unaffected() -> void:
	# Default _hero_luck_drop_bonus = 0.0 -- no set_hero_luck_drop_bonus() call.
	var table: DropTableResource = _make_drop_table(&"no_luck_test", 0.0, 1)
	_seed_drop_table(table)

	GEventBus.monster_died.emit(_make_died_event(&"no_luck_test", 1.0))

	assert_int(_spy.count("materials_earned")).is_equal(0)


## Regression guard for the actual _process_drops() production wiring, distinct
## from the statistical test above (which calls _roll_drop_occurs() directly and
## re-implements the boosted-rate expression itself — it would still pass even if
## _process_drops() stopped reading _hero_luck_drop_bonus at all). This test drives
## the real end-to-end path: a guaranteed-failure base_drop_rate that only succeeds
## once Luck is applied, through the real monster_died signal, asserting the real
## materials_earned emission. Deterministic — no statistical tolerance band needed.
func test_hero_luck_drop_bonus_flips_guaranteed_failure_to_guaranteed_success_via_process_drops() -> void:
	var table: DropTableResource = _make_drop_table(&"luck_wiring_regression", 0.0, 1)
	_seed_drop_table(table)
	_re.set_hero_luck_drop_bonus(1.0)

	GEventBus.monster_died.emit(_make_died_event(&"luck_wiring_regression", 1.0))

	assert_int(_spy.count("materials_earned")).is_equal(1)
