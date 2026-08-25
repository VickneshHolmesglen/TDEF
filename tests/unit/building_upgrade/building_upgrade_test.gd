## Unit tests for BuildingUpgrade (player-requested, design/gdd/building-upgrade.md).
##
## BuildingUpgrade reads 4 real upstream systems directly (no injection seam,
## matching Crafting's/EquipmentForge's own established "read the domain
## Autoload/instance directly" convention): GDefenseBuilding, GInventory,
## GMenagerie, and (ADR-0035, 2026-08-12) GTarot — all 4 are now real
## Autoloads. Real content used: upgrade_watchtower_reinforced
## (assets/data/building_upgrades/), which requires
## building=habitat_expansion_tier_1, creature=glimmer_hare,
## tarot=iron_resolve.
##
## GDefenseBuilding/GInventory/GMenagerie/GTarot are real, persistent
## Autoloads — TD-test-004 convention: reset directly in
## before_test()/after_test() rather than instantiating isolated copies
## (matches mission_economy_test.gd's own established pattern for this
## class of cross-suite state).
extends GdUnitTestSuite

const UPGRADE_ID: StringName = &"upgrade_watchtower_reinforced"
const TARGET_STRUCTURE: StringName = &"habitat_expansion_tier_1"  ## note: the .tres targets watchtower_tier_1; this const is for the REQUIREMENT's own "building" entry
const REQUIRED_SPECIES: StringName = &"glimmer_hare"
const REQUIRED_TAROT_CARD: StringName = &"iron_resolve"

var _building_upgrade: BuildingUpgrade


func before_test() -> void:
	_building_upgrade = BuildingUpgrade.new()
	add_child(_building_upgrade)  # triggers _ready(): GSavePersistence.register(), _seed_purchasable_state()
	GDefenseBuilding.reset_to_defaults()
	GMenagerie.reset_to_defaults()
	GInventory.reset_to_defaults()
	GTarot.reset_to_defaults()


func after_test() -> void:
	if _building_upgrade != null and is_instance_valid(_building_upgrade):
		remove_child(_building_upgrade)
		_building_upgrade.free()
	_building_upgrade = null
	GDefenseBuilding.reset_to_defaults()
	GMenagerie.reset_to_defaults()
	GInventory.reset_to_defaults()
	GTarot.reset_to_defaults()


func _build_watchtower() -> void:
	GDefenseBuilding._structure_ledger[&"watchtower_tier_1"] = true


## resolve_upgrade() also checks material_cost (12 Common per the real
## .tres) via GInventory.has_items_by_rarity() -- distinct from the
## `requirements` gate (Rule 2), which is never consumed. common_scrap is a
## real Common-rarity Material item, same one used by crafting-panel_test.gd.
func _seed_material_cost() -> void:
	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"common_scrap")
	GInventory.add_stackable(definition, 12)


func _satisfy_building_requirement() -> void:
	GDefenseBuilding._structure_ledger[TARGET_STRUCTURE] = true


func _satisfy_creature_requirement() -> void:
	var creature := CreatureInstance.new()
	creature.creature_id = 1
	creature.species = REQUIRED_SPECIES
	creature.state = CreatureInstance.CreatureState.HABITAT
	GMenagerie._creatures.append(creature)


# ---------------------------------------------------------------------------
# Content sanity — the real .tres this whole suite exercises
# ---------------------------------------------------------------------------

func test_real_upgrade_content_loads_and_validates() -> void:
	var upgrade: BuildingUpgradeResource = GGameDataRegistry.get_building_upgrade(UPGRADE_ID)
	assert_object(upgrade).is_not_null()
	assert_array(upgrade.validate()).is_empty()
	assert_that(upgrade.target_structure_id).is_equal(&"watchtower_tier_1")


# ---------------------------------------------------------------------------
# Rule 3 — Visibility gated on target_structure_id being BUILT
# ---------------------------------------------------------------------------

func test_not_visible_before_target_structure_is_built() -> void:
	assert_bool(_building_upgrade.is_visible(UPGRADE_ID)).is_false()


func test_visible_once_target_structure_is_built() -> void:
	_build_watchtower()
	assert_bool(_building_upgrade.is_visible(UPGRADE_ID)).is_true()


# ---------------------------------------------------------------------------
# Rule 4 — Purchasability: all requirements + both costs
# ---------------------------------------------------------------------------

func test_not_purchasable_when_structure_not_built_even_with_other_requirements_met() -> void:
	_satisfy_building_requirement()
	_satisfy_creature_requirement()
	assert_bool(_building_upgrade.can_purchase(UPGRADE_ID)).is_false()


func test_not_purchasable_when_only_some_requirements_met() -> void:
	_build_watchtower()
	_satisfy_building_requirement()
	# creature and tarot requirements still unmet
	assert_bool(_building_upgrade.can_purchase(UPGRADE_ID)).is_false()


## ADR-0035: Tarot is now a real Autoload (GTarot), always reachable —
## this replaces the old "fails closed with no live Tarot instance" gap
## test (that premise no longer exists). iron_resolve (REQUIRED_TAROT_CARD)
## is Common content (unlock_tech_id = "" -> unlocked from the start per
## Tarot.is_card_unlocked()'s own default-unlock branch), so this proves
## the "tarot" branch genuinely reaches GTarot.is_card_unlocked() and
## reflects its real return value, rather than failing closed as it did
## before ADR-0035 (when no instance was reachable at all). An unrecognized
## tarot requirement id still fails closed safely (edge_cases_test.gd's AC-10b).
func test_tarot_requirement_resolves_via_the_real_gtarot_autoload() -> void:
	_build_watchtower()
	_satisfy_building_requirement()
	_satisfy_creature_requirement()

	assert_bool(GTarot.is_card_unlocked(REQUIRED_TAROT_CARD)).is_true()  # Common card, unlocked by default
	assert_bool(_building_upgrade.can_purchase(UPGRADE_ID)).is_true()


func test_purchasable_once_every_requirement_is_independently_satisfied() -> void:
	_build_watchtower()
	_satisfy_building_requirement()
	_satisfy_creature_requirement()

	assert_bool(_building_upgrade.can_purchase(UPGRADE_ID)).is_true()  # tarot requirement auto-satisfied (Common card)


# ---------------------------------------------------------------------------
# Rule 4/5/6 — resolve_upgrade(): dual-gated, non-destructive to requirement
# inputs, permanent ledger write, structure_upgraded emission
# ---------------------------------------------------------------------------

func test_resolve_upgrade_rejected_when_not_purchasable_zero_side_effects() -> void:
	var gold_before: int = 0  # no gold ever granted in this isolated test
	var spy := EventBusSpy.new()
	spy.watch(GEventBus.structure_upgraded)
	spy.watch(GEventBus.resources_changed)

	var resolved: bool = _building_upgrade.resolve_upgrade(UPGRADE_ID)

	assert_bool(resolved).is_false()
	assert_bool(_building_upgrade.is_purchased(UPGRADE_ID)).is_false()
	assert_int(spy.count("structure_upgraded")).is_equal(0)
	assert_int(spy.count("resources_changed")).is_equal(0)
	spy.disconnect_all()


func test_resolve_upgrade_succeeds_and_does_not_consume_requirement_inputs() -> void:
	_build_watchtower()
	_satisfy_building_requirement()
	_satisfy_creature_requirement()
	_seed_material_cost()

	var spy := EventBusSpy.new()
	spy.watch(GEventBus.structure_upgraded)
	spy.watch(GEventBus.resources_changed)

	var resolved: bool = _building_upgrade.resolve_upgrade(UPGRADE_ID)

	assert_bool(resolved).is_true()
	assert_bool(_building_upgrade.is_purchased(UPGRADE_ID)).is_true()
	assert_int(spy.count("structure_upgraded")).is_equal(1)
	var args: Array = (spy.emissions["structure_upgraded"] as Array)[0] as Array
	assert_str(args[0] as String).is_equal("watchtower_tier_1")
	assert_str(args[1] as String).is_equal(String(UPGRADE_ID))

	# Rule 5: none of the requirement inputs were consumed.
	assert_bool(GDefenseBuilding.is_structure_built(&"watchtower_tier_1")).is_true()
	assert_bool(GDefenseBuilding.is_structure_built(TARGET_STRUCTURE)).is_true()
	assert_bool(GMenagerie.has_creature_species(REQUIRED_SPECIES)).is_true()
	assert_bool(GTarot.is_card_unlocked(REQUIRED_TAROT_CARD)).is_true()

	spy.disconnect_all()


func test_resolve_upgrade_is_permanent_and_rejects_a_second_purchase() -> void:
	_build_watchtower()
	_satisfy_building_requirement()
	_satisfy_creature_requirement()
	_seed_material_cost()

	assert_bool(_building_upgrade.resolve_upgrade(UPGRADE_ID)).is_true()
	assert_bool(_building_upgrade.resolve_upgrade(UPGRADE_ID)).is_false()  # already purchased


## TD-defbuild-002 (fully resolved 2026-08-25): unlike requirements (Rule 5,
## never consumed — see the test above), material_cost IS actually spent on
## a successful resolve.
func test_resolve_upgrade_consumes_the_real_material_cost() -> void:
	_build_watchtower()
	_satisfy_building_requirement()
	_satisfy_creature_requirement()
	_seed_material_cost()  # exactly 12 Common, the real .tres cost

	var resolved: bool = _building_upgrade.resolve_upgrade(UPGRADE_ID)

	assert_bool(resolved).is_true()
	assert_bool(GInventory.has_items_by_rarity({&"Common": 1})).is_false()  # all 12 consumed, none left


# ---------------------------------------------------------------------------
# SaveRestorer round-trip
# ---------------------------------------------------------------------------

func test_save_and_restore_round_trip_preserves_purchased_ledger() -> void:
	_building_upgrade._purchased_ledger[UPGRADE_ID] = true

	var saved: Dictionary = _building_upgrade.get_save_data()
	var fresh := BuildingUpgrade.new()
	var restored: bool = fresh.restore_save_data(saved)

	assert_bool(restored).is_true()
	assert_bool(fresh.is_purchased(UPGRADE_ID)).is_true()
	fresh.free()


func test_restore_rejects_malformed_payload() -> void:
	assert_bool(_building_upgrade.restore_save_data({"purchased_ledger": "not a dictionary"})).is_false()
	assert_bool(_building_upgrade.restore_save_data({})).is_false()
