## Integration test: Defense Building's real resolve_tech_unlock() flow
## unlocking a real Tarot card end-to-end — not a direct ledger poke.
##
## Drives GDefenseBuilding.resolve_tech_unlock() through its actual
## eligibility + materials dual-gate (defense_building.gd) and confirms
## Tarot.is_card_unlocked()/equip_card() observe the result immediately,
## with no caching/reconciliation step required (is_card_unlocked() is a
## live pull-based check).
##
## GDefenseBuilding/GInventory are real, persistent Autoloads — reset
## directly in before_test()/after_test() (TD-test-004 convention, matches
## currency_dual_gate_test.gd's own resolve_tech_unlock() setup).
extends GdUnitTestSuite

## Rare rarity, unlock_tech_id = &"tech_production_2", gold_cost=50,
## material_costs={Common: 15} (assets/data/tarot/card_bountiful_harvest.tres,
## assets/data/defense_building/tech_nodes/tech_production_2.tres).
const GATED_CARD: StringName = &"bountiful_harvest"
const GATED_CARD_TECH: StringName = &"tech_production_2"

var _tarot: Tarot


func before_test() -> void:
	_tarot = Tarot.new()
	GDefenseBuilding.reset_to_defaults()
	GDefenseBuilding._is_sanctuary = true  # resolve_tech_unlock() rejects outside Sanctuary
	GInventory.reset_to_defaults()
	GInventory.add_stackable(GGameDataRegistry.get_item_definition(&"common_scrap"), 15)


func after_test() -> void:
	if _tarot != null and is_instance_valid(_tarot):
		_tarot.free()
	_tarot = null
	GDefenseBuilding.reset_to_defaults()
	GInventory.reset_to_defaults()


func test_resolving_the_real_tech_unlock_unlocks_and_makes_the_matching_card_equippable() -> void:
	assert_bool(_tarot.is_card_unlocked(GATED_CARD)).is_false()
	assert_bool(_tarot.equip_card(GATED_CARD)).is_false()

	var resolved: bool = GDefenseBuilding.resolve_tech_unlock(GATED_CARD_TECH)

	assert_bool(resolved).is_true()
	assert_bool(_tarot.is_card_unlocked(GATED_CARD)).is_true()
	assert_bool(_tarot.equip_card(GATED_CARD)).is_true()
	assert_int(_tarot.get_active_card_count()).is_equal(1)


func test_a_rejected_tech_unlock_leaves_the_matching_card_locked() -> void:
	GInventory.reset_to_defaults()  # remove the 15 Common seeded above -> insufficient materials

	var resolved: bool = GDefenseBuilding.resolve_tech_unlock(GATED_CARD_TECH)

	assert_bool(resolved).is_false()
	assert_bool(_tarot.is_card_unlocked(GATED_CARD)).is_false()
