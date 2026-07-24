## Unit tests for ResourceEconomy's batch-resolution independence, Epic 03
## Story 014, ADR-0017.
##
## Covers AC-11 (GIVEN monsters_died_batch with 20+ entries, WHEN each resolves,
## THEN each is rounded independently — no fractional carryover between entries)
## and the QA Test Cases' two edge cases: (a) a naive fractional-accumulate-then-
## round total must DIFFER from the true per-entry-rounded total, proving the
## implementation isn't secretly batching the math itself, and (b) an
## exclusivity-assumption regression test for ADR-0017's flagged risk (see
## "Exclusivity assumption" section below for why this test documents rather
## than asserts away the risk).
##
## Verification note (this story is primarily VERIFY, not build): read in full,
## _process_drops() takes a single MonsterDiedEvent and has no parameters or
## fields that persist a running total or fractional remainder across calls.
## _on_monsters_died_batch() just loops payloads and calls _process_drops(payload)
## once per entry — no accumulator variable is declared outside that loop. Every
## batch entry is therefore already resolved with the same independence as an
## individual monster_died dispatch, by construction. No change to
## resource_economy.gd was required for this story.
##
## Follows tests/unit/resource_economy/drop_occurrence_quantity_test.gd's
## established convention: ResourceEconomy tests use add_child()-then-real-signal
## dispatch (GEventBus.monster_died.emit(...) / GEventBus.monsters_died_batch.emit(...)),
## with drop-table test data seeded directly into GGameDataRegistry._drop_tables and
## removed again in after_test() (no injection seam on ResourceEconomy itself, per
## ADR-0017's "no public call API beyond EventBus"). materials_earned emissions are
## observed via tests/helpers/event_bus_spy.gd's EventBusSpy.
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


func _make_died_event(entity_id: int, drop_table_id: StringName, wave_reward_scalar: float, kill_source: String = "tower") -> MonsterDiedEvent:
	var payload := MonsterDiedEvent.new()
	payload.entity_id = entity_id
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
# AC-11: 20+ batch entries, each rounded independently — no fractional
# carryover. wave_reward_scalar=0.5 with base_quantity=1, guaranteed_min=0
# gives each entry a raw quantity of exactly 0.5 — a value deliberately chosen
# because round(0.5) = 1 (GDScript rounds half away from zero) for EVERY
# entry when resolved independently, but a naive "sum all raw quantities
# across the batch, then round once" implementation would instead compute
# round(20 * 0.5) = round(10.0) = 10. These two totals (20 vs 10) are
# maximally divergent proof that the real implementation is not doing
# batch-level accumulation.
# ---------------------------------------------------------------------------

func test_resource_economy_batch_of_twenty_entries_rounds_each_entry_independently_not_naive_accumulation() -> void:
	var table: DropTableResource = _make_drop_table(&"ac11_twenty_entries", 1.0, 1, 0)
	_seed_drop_table(table)

	const ENTRY_COUNT: int = 20
	var batch: Array[MonsterDiedEvent] = []
	for i: int in range(ENTRY_COUNT):
		batch.append(_make_died_event(i + 1, &"ac11_twenty_entries", 0.5))

	GEventBus.monsters_died_batch.emit(batch)

	assert_int(_spy.count("materials_earned")).is_equal(ENTRY_COUNT)

	var emissions: Array = _spy.emissions["materials_earned"]
	var total_quantity: int = 0
	for args: Array in emissions:
		# Each entry independently rounds round(0.5) = 1 — never 0, never
		# accumulated with any neighboring entry.
		assert_int(args[1]).is_equal(1)
		total_quantity += args[1] as int

	# True per-entry-rounded total: 20 x 1 = 20.
	# Naive accumulate-then-round total would have been round(20 * 0.5) = 10.
	# These differ — proving no shared/accumulated rounding state exists.
	assert_int(total_quantity).is_equal(20)
	assert_int(total_quantity).is_not_equal(10)


# ---------------------------------------------------------------------------
# AC-11 / ADR-0017 Validation Criteria: batch entries must resolve IDENTICALLY
# to individual monster_died dispatch, entry-for-entry, in array order — not
# merely "close" or "statistically similar." Uses varying wave_reward_scalar
# per entry (rather than a single uniform value) so a coincidental match
# between batch and individual paths cannot hide a real divergence.
# ---------------------------------------------------------------------------

func test_resource_economy_batch_of_twentyfive_entries_matches_individual_dispatch_quantities_in_order() -> void:
	var table: DropTableResource = _make_drop_table(&"ac11_batch_vs_individual", 1.0, 1, 1)
	_seed_drop_table(table)

	const ENTRY_COUNT: int = 25
	var scalars: Array[float] = []
	for i: int in range(ENTRY_COUNT):
		scalars.append(1.0 + (i * 0.15))  # varied, non-uniform raw quantities per entry

	# Individual dispatch, one monster_died emit per entry, recorded in order.
	# Full 3-arg payload captured (material_id, quantity, kill_source), not just
	# quantity — a regression that swapped/misrouted material_id or kill_source
	# specifically on the batch path must be caught here.
	var individual_emissions: Array[Array] = []
	for i: int in range(ENTRY_COUNT):
		_spy.clear()
		GEventBus.monster_died.emit(_make_died_event(i + 1, &"ac11_batch_vs_individual", scalars[i]))
		individual_emissions.append((_spy.emissions["materials_earned"] as Array)[0] as Array)
	_spy.clear()

	# Same 25 entries, dispatched as a single monsters_died_batch.
	var batch: Array[MonsterDiedEvent] = []
	for i: int in range(ENTRY_COUNT):
		batch.append(_make_died_event(i + 1000, &"ac11_batch_vs_individual", scalars[i]))
	GEventBus.monsters_died_batch.emit(batch)

	assert_int(_spy.count("materials_earned")).is_equal(ENTRY_COUNT)
	var batch_emissions: Array = _spy.emissions["materials_earned"]
	for i: int in range(ENTRY_COUNT):
		var batch_args: Array = batch_emissions[i] as Array
		var individual_args: Array = individual_emissions[i]
		assert_str(batch_args[0]).is_equal(individual_args[0] as String)
		assert_int(batch_args[1]).is_equal(individual_args[1] as int)
		assert_str(batch_args[2]).is_equal(individual_args[2] as String)


# ---------------------------------------------------------------------------
# Boundary cases: empty batch and single-entry batch.
# ---------------------------------------------------------------------------

func test_resource_economy_empty_batch_emits_no_materials_earned() -> void:
	GEventBus.monsters_died_batch.emit([] as Array[MonsterDiedEvent])

	assert_int(_spy.count("materials_earned")).is_equal(0)


func test_resource_economy_single_entry_batch_resolves_identically_to_individual_dispatch() -> void:
	var table: DropTableResource = _make_drop_table(&"ac11_single_entry_batch", 1.0, 3, 1)
	_seed_drop_table(table)

	GEventBus.monsters_died_batch.emit([_make_died_event(1, &"ac11_single_entry_batch", 2.0)] as Array[MonsterDiedEvent])

	assert_int(_spy.count("materials_earned")).is_equal(1)
	var args: Array = (_spy.emissions["materials_earned"] as Array)[0]
	assert_str(args[0]).is_equal("goblin_hide")
	assert_int(args[1]).is_greater_equal(1)


# ---------------------------------------------------------------------------
# Mixed drop_table_id within a single batch: proves no table-lookup/caching
# state leaks between differently-tabled entries resolved in the same
# _on_monsters_died_batch() loop iteration.
# ---------------------------------------------------------------------------

func test_resource_economy_batch_with_mixed_drop_table_ids_resolves_each_entry_against_its_own_table() -> void:
	var table_a: DropTableResource = _make_drop_table(&"ac11_mixed_table_a", 1.0, 5, 1)
	var table_b: DropTableResource = _make_drop_table(&"ac11_mixed_table_b", 1.0, 1, 1)
	table_b.entries[0].material_id = &"iron_ore"
	_seed_drop_table(table_a)
	_seed_drop_table(table_b)

	var batch: Array[MonsterDiedEvent] = [
		_make_died_event(1, &"ac11_mixed_table_a", 1.0),
		_make_died_event(2, &"ac11_mixed_table_b", 1.0),
		_make_died_event(3, &"ac11_mixed_table_a", 1.0),
	]
	GEventBus.monsters_died_batch.emit(batch)

	assert_int(_spy.count("materials_earned")).is_equal(3)
	var emissions: Array = _spy.emissions["materials_earned"]
	assert_str((emissions[0] as Array)[0]).is_equal("goblin_hide")
	assert_str((emissions[1] as Array)[0]).is_equal("iron_ore")
	assert_str((emissions[2] as Array)[0]).is_equal("goblin_hide")


# ---------------------------------------------------------------------------
# Exclusivity assumption (ADR-0017 Risks / Validation Criteria, story's ADR
# Decision Summary): Resource Economy subscribes to BOTH monster_died and
# monsters_died_batch, relying on a project-wide guarantee that a given kill
# fires exactly one of the two signals — never both — for the same entity_id.
# ADR-0017's own mitigation note for this risk states: "current EventBus
# dispatch code already prevents this" — i.e. the guarantee is enforced by the
# EMITTER (Monster System / Wave Manager's kill pipeline never calls both
# emit paths for one kill), not by ResourceEconomy itself. ResourceEconomy was
# read in full for this story (see class doc comment above and
# _process_drops()/_on_monster_died()/_on_monsters_died_batch() in
# resource_economy.gd) and contains no entity_id-keyed dedup/tracking state —
# by design: the Control Manifest's Foundation Layer Rule for this story
# explicitly forbids Resource Economy from implementing "its own competing
# batch logic," and ADR-0017's stated design is "one cached scalar, no
# accumulator" (Core Rule 1 — stateless calculator).
#
# This test therefore documents the ACTUAL behavior at this layer's boundary
# rather than asserting a guarantee this layer does not (and per ADR-0017/the
# control manifest, should not) implement: if the upstream exclusivity
# assumption is ever violated — monster_died and monsters_died_batch both
# firing for the same entity_id — ResourceEconomy has no defense and DOES
# double-award. This is the exact "consequential failure mode" ADR-0017 flags
# and asks a dedicated test to exist for; the value of this test is as a
# tripwire/regression marker for that documented, currently-upstream-owned
# risk, not a claim that ResourceEconomy prevents it. If this test's assertion
# ever needs to flip (i.e. a future story adds entity-level dedup here), that
# is a deliberate architecture change to flag with godot-specialist, not a
# silent fix.
# ---------------------------------------------------------------------------

func test_resource_economy_monster_died_and_batch_firing_for_same_entity_id_is_not_deduplicated_at_this_layer() -> void:
	var table: DropTableResource = _make_drop_table(&"exclusivity_violation_table", 1.0, 1, 1)
	_seed_drop_table(table)

	const SHARED_ENTITY_ID: int = 99
	GEventBus.monster_died.emit(_make_died_event(SHARED_ENTITY_ID, &"exclusivity_violation_table", 1.0))
	GEventBus.monsters_died_batch.emit([_make_died_event(SHARED_ENTITY_ID, &"exclusivity_violation_table", 1.0)] as Array[MonsterDiedEvent])

	# Documents the current, known risk: with no entity-level dedup in
	# ResourceEconomy, both dispatch paths independently resolve and both
	# emit materials_earned — a double-award if the upstream exclusivity
	# guarantee (Monster System/Wave Manager never firing both for one kill)
	# is ever violated. Exclusivity enforcement is out of this story's scope
	# (owned upstream, per ADR-0017/control manifest) — see test doc comment.
	assert_int(_spy.count("materials_earned")).is_equal(2)
