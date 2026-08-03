## Unit tests for Story 023 (TR-defbuild-001, resolution-ordering half;
## ADR-0024): Tier-1-ungated structure symmetry (AC-23), synchronous
## fixed-order resolution (AC-24), and no-intermediate-state confirmation
## (AC-25).
##
## Exercises the real, authored res://assets/data/defense_building/ content
## via the GGameDataRegistry Autoload (no fixture injection), same rationale
## as every other defense_building test.
##
## AC-24 scope note: resolve_tech_unlock()/resolve_structure_build() execute
## 5 of ADR-0024 Rule 9's 6 sub-steps synchronously — (a) eligibility,
## (b) materials-check, (c) gold debit, (e) ledger write, (f) domain event
## emission. Step (d), material consumption, remains deliberately deferred
## (see defense_building.gd's class doc comment and resolve_tech_unlock()'s
## own doc comment for the full rationale — a genuine GDD-level open design
## question, not something this story invents a resolution for). These tests
## verify the 5 implemented steps happen synchronously in one call; they do
## not assert anything about step (d), consistent with that deferral.
##
## AC-25 interpretation note: these tests assert the terminal state is
## already readable immediately upon the resolve call's return — a stronger
## proof than "next frame" (frame-0 truth implies frame-1 truth), and avoids
## needing a live SceneTree/`await get_tree().process_frame` harness for
## what is fundamentally synchronous, non-deferred GDScript logic (no
## `await`/`call_deferred` appears anywhere in either resolve method).
##
## TD-defbuild-002 RESOLVED (Sprint 6, S6-06b): see currency_dual_gate_test.gd's
## class doc comment for the full explanation — real material_costs are
## rarity-keyed, and DefenseBuilding now checks them via
## Inventory.has_items_by_rarity() (ItemDefinitionResource.rarity, a genuine
## aggregation axis separate from item_type). GInventory (the real Autoload)
## is seeded with real, schema-valid Material items whose `rarity` field is
## properly set; reset in before_test()/after_test() to avoid leaking into
## other test files.
extends GdUnitTestSuite

const TECH_PRODUCTION_2: StringName = &"tech_production_2"
const HABITAT_TIER_1: StringName = &"habitat_expansion_tier_1"
const HABITAT_TIER_2: StringName = &"habitat_expansion_tier_2"
const HABITAT_TIER_3: StringName = &"habitat_expansion_tier_3"
const HABITAT_TIER_4: StringName = &"habitat_expansion_tier_4"
const WATCHTOWER_TIER_1: StringName = &"watchtower_tier_1"

var _defense_building: DefenseBuilding
var _spy: EventBusSpy


## has_items_by_rarity() resolves rarity via
## GGameDataRegistry.get_item_definition(slot.item_id) — a fabricated
## item_id is never in the registry and silently fails to count (found via
## live MCP verification). Returns the genuine registered `common_scrap`
## (rarity=Common) / `iron_ore` (rarity=Uncommon) definition instead.
func _make_rarity_definition(rarity: StringName) -> ItemDefinitionResource:
	var item_id: StringName = &"common_scrap" if rarity == &"Common" else &"iron_ore"
	return GGameDataRegistry.get_item_definition(item_id)


func before_test() -> void:
	_defense_building = DefenseBuilding.new()
	# Story 024 gates resolve_*() on is_locked() (defaults true/LOCKED since
	# _ready() never fires without add_child()) — these tests are about
	# resolution ordering, not phase-lock behavior, so force the Sanctuary
	# context directly (see persistence_through_defeat_test.gd, Story 024,
	# for the actual lock-behavior tests).
	_defense_building._is_sanctuary = true
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.resources_changed)
	_spy.watch(GEventBus.tech_unlocked)
	_spy.watch(GEventBus.sanctuary_structure_built)
	GInventory.reset_to_defaults()
	GInventory.add_stackable(_make_rarity_definition(&"Common"), 100)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _defense_building != null and is_instance_valid(_defense_building):
		_defense_building.free()
	_defense_building = null
	GInventory.reset_to_defaults()


# ---------------------------------------------------------------------------
# AC-23: exactly one ungated entry point per structure family, from a fresh
# (empty tech ledger) state.
# ---------------------------------------------------------------------------

func test_only_habitat_tier_1_is_buildable_with_no_tech_unlocked() -> void:
	assert_bool(_defense_building.can_build_structure(HABITAT_TIER_1)).is_true()
	assert_bool(_defense_building.can_build_structure(HABITAT_TIER_2)).is_false()
	assert_bool(_defense_building.can_build_structure(HABITAT_TIER_3)).is_false()
	assert_bool(_defense_building.can_build_structure(HABITAT_TIER_4)).is_false()
	assert_bool(_defense_building.can_build_structure(WATCHTOWER_TIER_1)).is_false()


# ---------------------------------------------------------------------------
# AC-24: the implemented sub-steps execute synchronously in fixed order —
# all effects (ledger write, gold-debit emission, domain event emission) are
# observable immediately after the resolve call returns, in one statement
# sequence with no await/yield anywhere in between.
# ---------------------------------------------------------------------------

func test_resolve_tech_unlock_all_steps_observable_synchronously() -> void:
	var tech_node: TechNodeResource = GGameDataRegistry.get_tech_node(TECH_PRODUCTION_2)
	var result: bool = _defense_building.resolve_tech_unlock(TECH_PRODUCTION_2)

	# No await/yield above this line — every assertion below observes state
	# that must already be correct the instant resolve_tech_unlock() returned.
	assert_bool(result).is_true()
	assert_bool(_defense_building.is_tech_unlocked(TECH_PRODUCTION_2)).is_true()

	assert_int(_spy.count("resources_changed")).is_equal(1)
	var gold_args: Array = (_spy.emissions["resources_changed"] as Array)[0] as Array
	assert_int(gold_args[0] as int).is_equal(-tech_node.gold_cost)
	assert_that(gold_args[1] as StringName).is_equal(&"tech_unlock")

	assert_int(_spy.count("tech_unlocked")).is_equal(1)
	var event_args: Array = (_spy.emissions["tech_unlocked"] as Array)[0] as Array
	assert_str(event_args[0] as String).is_equal(String(TECH_PRODUCTION_2))
	assert_str(event_args[1] as String).is_equal(tech_node.tech_category)


func test_resolve_structure_build_all_steps_observable_synchronously() -> void:
	var structure: StructureResource = GGameDataRegistry.get_structure(HABITAT_TIER_1)
	var result: bool = _defense_building.resolve_structure_build(HABITAT_TIER_1)

	assert_bool(result).is_true()

	assert_int(_spy.count("resources_changed")).is_equal(1)
	var gold_args: Array = (_spy.emissions["resources_changed"] as Array)[0] as Array
	assert_int(gold_args[0] as int).is_equal(-structure.gold_cost)
	assert_that(gold_args[1] as StringName).is_equal(&"structure_built")

	assert_int(_spy.count("sanctuary_structure_built")).is_equal(1)
	var event_args: Array = (_spy.emissions["sanctuary_structure_built"] as Array)[0] as Array
	assert_str(event_args[0] as String).is_equal(String(HABITAT_TIER_1))
	assert_str(event_args[1] as String).is_equal(structure.structure_type)


# ---------------------------------------------------------------------------
# AC-25: querying state immediately after a successful resolve already reads
# the terminal state — no "in progress"/polling state exists at any point.
# ---------------------------------------------------------------------------

func test_tech_unlock_state_reads_unlocked_immediately_after_resolve_no_polling() -> void:
	assert_bool(_defense_building.is_tech_unlocked(TECH_PRODUCTION_2)).is_false()
	_defense_building.resolve_tech_unlock(TECH_PRODUCTION_2)
	# Same statement sequence, zero frames elapsed — already UNLOCKED.
	assert_bool(_defense_building.is_tech_unlocked(TECH_PRODUCTION_2)).is_true()


func test_structure_build_state_reads_built_immediately_after_resolve_no_polling() -> void:
	assert_bool(_defense_building.can_build_structure(HABITAT_TIER_1)).is_true()
	_defense_building.resolve_structure_build(HABITAT_TIER_1)
	# Already BUILT — can_build_structure() now rejects it as already-built,
	# the same idempotency code path AC-27 established.
	assert_bool(_defense_building.can_build_structure(HABITAT_TIER_1)).is_false()
