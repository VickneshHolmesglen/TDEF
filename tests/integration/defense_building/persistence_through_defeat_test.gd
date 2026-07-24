## Integration tests for Story 024 (TR-defbuild-003, ADR-0024): the
## Sanctuary-only phase lock (AC-28), DEFEAT-transition persistence (AC-29),
## and full save/reload round-trip fidelity (AC-30).
##
## This is the mechanical proof of the GDD's central "only ever grows" Player
## Fantasy premise (see defense_building.gd's Sanctuary-only-scope doc
## comment) — not a routine persistence test. AC-29/AC-30 specifically guard
## against the class of bug Grid's own DEFEAT/OUTCOME handler has (Grid
## clears _occupancy on those phases) — DefenseBuilding's ledgers must never
## be touched by a phase transition, only gated against NEW writes.
##
## DefenseBuilding is instantiated directly (DefenseBuilding.new(), no
## add_child()) so _ready() never fires — GSavePersistence.register() is
## never called, avoiding pollution of the real Autoload's
## _registered_systems list across test runs. Persistence round-trips
## (AC-30) call get_save_data()/restore_save_data() directly between two
## local instances, matching inventory tests' established convention
## (slot_stack_model_test.gd) — no live GSavePersistence file I/O involved.
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
# AC-28: LOCKED during any non-SANCTUARY context — no ledger write possible.
# ---------------------------------------------------------------------------

func test_locked_by_default_before_any_scene_transition_observed() -> void:
	# Safe-default: LOCKED until an explicit SANCTUARY transition is seen
	# (defense_building.gd's own doc comment explains why — this project's
	# main_scene boots directly into a mission, TD-project-001).
	assert_bool(_defense_building.is_locked()).is_true()


func test_locked_during_mission_context() -> void:
	_defense_building._on_scene_transition_completed("MISSION", "the_gap")
	assert_bool(_defense_building.is_locked()).is_true()


func test_unlocked_during_sanctuary_context() -> void:
	_defense_building._on_scene_transition_completed("SANCTUARY", "")
	assert_bool(_defense_building.is_locked()).is_false()


func test_resolve_tech_unlock_rejected_while_locked_zero_side_effects() -> void:
	_defense_building._on_scene_transition_completed("MISSION", "the_gap")
	var result: bool = _defense_building.resolve_tech_unlock(TECH_PRODUCTION_2)

	assert_bool(result).is_false()
	assert_bool(_defense_building.is_tech_unlocked(TECH_PRODUCTION_2)).is_false()
	assert_bool(_spy.was_emitted("resources_changed")).is_false()
	assert_bool(_spy.was_emitted("tech_unlocked")).is_false()


func test_resolve_structure_build_rejected_while_locked_zero_side_effects() -> void:
	_defense_building._on_scene_transition_completed("MISSION", "the_gap")
	var result: bool = _defense_building.resolve_structure_build(HABITAT_TIER_1)

	assert_bool(result).is_false()
	assert_bool(_defense_building.can_build_structure(HABITAT_TIER_1)).is_true()  # still eligible, never attempted
	assert_bool(_spy.was_emitted("resources_changed")).is_false()
	assert_bool(_spy.was_emitted("sanctuary_structure_built")).is_false()


# ---------------------------------------------------------------------------
# AC-29: DEFEAT never reverts, decrements, or resets ledger state — only new
# writes are blocked while locked, existing entries are untouched.
# ---------------------------------------------------------------------------

func test_defeat_transition_does_not_revert_already_unlocked_or_built_state() -> void:
	# Unlock + build while in Sanctuary.
	_defense_building._on_scene_transition_completed("SANCTUARY", "")
	_defense_building.resolve_tech_unlock(TECH_PRODUCTION_2)
	_defense_building.resolve_structure_build(HABITAT_TIER_1)
	assert_bool(_defense_building.is_tech_unlocked(TECH_PRODUCTION_2)).is_true()
	assert_bool(_defense_building._structure_ledger[HABITAT_TIER_1]).is_true()

	# Enter a mission (locks). Unlike Grid's occupancy.clear() on DEFEAT/
	# OUTCOME, DefenseBuilding's own transition handler must NOT touch either
	# ledger at all — confirmed by re-reading state immediately after.
	_defense_building._on_scene_transition_completed("MISSION", "the_gap")
	assert_bool(_defense_building.is_tech_unlocked(TECH_PRODUCTION_2)).is_true()
	assert_bool(_defense_building._structure_ledger[HABITAT_TIER_1]).is_true()


# ---------------------------------------------------------------------------
# AC-30: full save/reload round-trip fidelity after a DEFEAT-adjacent
# session.
# ---------------------------------------------------------------------------

func test_save_reload_round_trip_preserves_unlocked_and_built_state_after_defeat() -> void:
	_defense_building._on_scene_transition_completed("SANCTUARY", "")
	_defense_building.resolve_tech_unlock(TECH_PRODUCTION_2)
	_defense_building.resolve_structure_build(HABITAT_TIER_1)
	_defense_building._on_scene_transition_completed("MISSION", "the_gap")  # DEFEAT-adjacent

	var data: Dictionary = _defense_building.get_save_data()

	var restored := DefenseBuilding.new()
	var ok: bool = restored.restore_save_data(data)

	assert_bool(ok).is_true()
	assert_bool(restored.is_tech_unlocked(TECH_PRODUCTION_2)).is_true()
	assert_bool(restored._structure_ledger[HABITAT_TIER_1]).is_true()
	restored.free()


func test_get_save_data_returns_only_primitive_types() -> void:
	_defense_building._on_scene_transition_completed("SANCTUARY", "")
	_defense_building.resolve_tech_unlock(TECH_PRODUCTION_2)
	var data: Dictionary = _defense_building.get_save_data()

	for key: Variant in data:
		assert_bool(key is String).is_true()
	var tech_ledger: Variant = data["tech_ledger"]
	assert_bool(tech_ledger is Dictionary).is_true()
	for key: Variant in (tech_ledger as Dictionary):
		assert_bool(key is String).is_true()
		assert_bool((tech_ledger as Dictionary)[key] is bool).is_true()


func test_restore_save_data_rejects_malformed_data_and_returns_false() -> void:
	var ok: bool = _defense_building.restore_save_data({"tech_ledger": "not_a_dictionary", "structure_ledger": {}})
	assert_bool(ok).is_false()


func test_reset_to_defaults_clears_both_ledgers() -> void:
	_defense_building._on_scene_transition_completed("SANCTUARY", "")
	_defense_building.resolve_tech_unlock(TECH_PRODUCTION_2)
	_defense_building.reset_to_defaults()
	assert_int(_defense_building._tech_ledger.size()).is_equal(0)
	assert_int(_defense_building._structure_ledger.size()).is_equal(0)
