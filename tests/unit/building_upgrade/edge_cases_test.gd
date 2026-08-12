## Unit tests for Story 005 (TR-buildupgrade-001/002, ADR-0034): edge-case
## regression coverage for behavior the shipped Story 001 code already
## produces structurally -- this story is test-only, confirming existing
## behavior rather than adding new production code (per its own
## Implementation Notes).
##
## Uses the real GGameDataRegistry-loaded upgrade_watchtower_reinforced
## content (requirements: building=habitat_expansion_tier_1,
## creature=glimmer_hare, tarot=iron_resolve), matching
## building_upgrade_test.gd's/content_validation_test.gd's own established
## real-content convention. GTarot is a real Autoload (ADR-0035), reset
## directly in before_test()/after_test() like the other 3 upstream
## Autoloads. AC-11 additionally registers one test-only second
## BuildingUpgradeResource directly into the registry (see
## SHARED_REQUIREMENT_UPGRADE_ID) so the "two upgrades share a requirement"
## claim is driven through the real can_purchase() registry path rather
## than a permanent new .tres file. _requirement_satisfied() is called
## directly where isolating a single branch (GDScript's underscore-prefix
## convention, not true privacy -- same direct-access pattern this project
## already uses for other "private" test seams, e.g. GTarot._card_unlocked).
extends GdUnitTestSuite

const UPGRADE_ID: StringName = &"upgrade_watchtower_reinforced"
const TARGET_STRUCTURE: StringName = &"watchtower_tier_1"
const REQUIRED_BUILDING: StringName = &"habitat_expansion_tier_1"
const REQUIRED_SPECIES: StringName = &"glimmer_hare"
const REQUIRED_TAROT_CARD: StringName = &"iron_resolve"

## Test-only second upgrade (AC-11), sharing UPGRADE_ID's "building"
## requirement. Registered directly into GGameDataRegistry's private
## ledger (the same direct-dict test-seam convention this file already
## uses for GDefenseBuilding._structure_ledger/Tarot._card_unlocked) so
## it is reachable through the REAL can_purchase(upgrade_id) registry
## lookup, not just the isolated _requirement_satisfied() branch --
## avoids authoring a permanent new .tres content file, which is out of
## this test-only story's scope.
const SHARED_REQUIREMENT_UPGRADE_ID: StringName = &"test_shared_requirement_upgrade"

var _building_upgrade: BuildingUpgrade


func before_test() -> void:
	GDefenseBuilding.reset_to_defaults()
	GInventory.reset_to_defaults()
	GMenagerie.reset_to_defaults()
	GTarot.reset_to_defaults()
	_building_upgrade = BuildingUpgrade.new()
	add_child(_building_upgrade)


func after_test() -> void:
	if _building_upgrade != null and is_instance_valid(_building_upgrade):
		remove_child(_building_upgrade)
		_building_upgrade.free()
	_building_upgrade = null
	GGameDataRegistry._building_upgrades.erase(SHARED_REQUIREMENT_UPGRADE_ID)
	GDefenseBuilding.reset_to_defaults()
	GInventory.reset_to_defaults()
	GMenagerie.reset_to_defaults()
	GTarot.reset_to_defaults()


## Registers SHARED_REQUIREMENT_UPGRADE_ID (AC-11's "upgrade B") directly
## into the registry, sharing UPGRADE_ID's own "building" requirement
## entry (REQUIRED_BUILDING). No prerequisite, no cost, and its own
## target_structure_id is already built by _satisfy_building_requirement()
## so is_visible() passes independent of what happens to UPGRADE_ID.
func _register_shared_requirement_upgrade() -> void:
	var second_upgrade := BuildingUpgradeResource.new()
	second_upgrade.upgrade_id = SHARED_REQUIREMENT_UPGRADE_ID
	second_upgrade.target_structure_id = TARGET_STRUCTURE
	second_upgrade.requirements = {"building": REQUIRED_BUILDING}
	second_upgrade.gold_cost = 0
	GGameDataRegistry._building_upgrades[SHARED_REQUIREMENT_UPGRADE_ID] = second_upgrade


func _satisfy_building_requirement() -> void:
	GDefenseBuilding._structure_ledger[TARGET_STRUCTURE] = true
	GDefenseBuilding._structure_ledger[REQUIRED_BUILDING] = true


func _satisfy_creature_requirement() -> void:
	var creature := CreatureInstance.new()
	creature.creature_id = 1
	creature.species = REQUIRED_SPECIES
	creature.state = CreatureInstance.CreatureState.HABITAT
	GMenagerie._creatures.append(creature)


func _satisfy_tarot_requirement() -> void:
	GTarot._card_unlocked[REQUIRED_TAROT_CARD] = true


func _seed_material_cost() -> void:
	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"common_scrap")
	GInventory.add_stackable(definition, 12)


# ---------------------------------------------------------------------------
# AC-10 / AC-10b -- an unrecognized id in any of the 4 requirement
# categories resolves false safely, never crashes.
# ---------------------------------------------------------------------------

func test_unrecognized_building_id_resolves_false() -> void:
	assert_bool(_building_upgrade._requirement_satisfied("building", &"not_a_real_structure")).is_false()


func test_unrecognized_equipment_id_resolves_false() -> void:
	assert_bool(_building_upgrade._requirement_satisfied("equipment", &"not_a_real_item")).is_false()


func test_unrecognized_tarot_id_resolves_false() -> void:
	assert_bool(_building_upgrade._requirement_satisfied("tarot", &"not_a_real_card")).is_false()


func test_unrecognized_creature_id_resolves_false() -> void:
	assert_bool(_building_upgrade._requirement_satisfied("creature", &"not_a_real_species")).is_false()


## AC-10: confirms the full can_purchase() path (not just the isolated
## _requirement_satisfied() branch AC-10b covers) also never reaches
## PURCHASABLE via an unrecognized requirement. GGameDataRegistry.get_
## building_upgrade() returns the live, shared BuildingUpgradeResource
## instance (never a copy), so its "building" entry is temporarily
## corrupted to a nonexistent structure_id and restored after -- this
## drives the real registry-backed can_purchase(upgrade_id) path without
## authoring new content, which the story's own scope disallows.
func test_upgrade_with_unrecognized_requirement_never_reaches_purchasable_via_can_purchase() -> void:
	_satisfy_creature_requirement()
	_satisfy_tarot_requirement()

	var upgrade: BuildingUpgradeResource = GGameDataRegistry.get_building_upgrade(UPGRADE_ID)
	var original_building_requirement: StringName = upgrade.requirements["building"]
	upgrade.requirements["building"] = &"not_a_real_structure"

	GDefenseBuilding._structure_ledger[TARGET_STRUCTURE] = true  # visible

	assert_bool(_building_upgrade.can_purchase(UPGRADE_ID)).is_false()

	upgrade.requirements["building"] = original_building_requirement


# ---------------------------------------------------------------------------
# AC-11 -- two upgrades sharing an identical requirements entry: purchasing
# one must not affect the other's OWN can_purchase() evaluation of that
# shared entry (Rule 5's non-consumption guarantee, tested at the public
# can_purchase() level per the story's own QA Test Case/Implementation
# Notes, not just the isolated _requirement_satisfied() branch).
# ---------------------------------------------------------------------------

func test_purchasing_one_upgrade_leaves_a_second_upgrades_shared_requirement_purchasable() -> void:
	_register_shared_requirement_upgrade()
	_satisfy_building_requirement()
	_satisfy_creature_requirement()
	_satisfy_tarot_requirement()
	_seed_material_cost()

	# Upgrade B (SHARED_REQUIREMENT_UPGRADE_ID) is purchasable BEFORE upgrade
	# A (UPGRADE_ID) is purchased -- its only requirement, the shared
	# "building" entry, is satisfied.
	assert_bool(_building_upgrade.can_purchase(SHARED_REQUIREMENT_UPGRADE_ID)).is_true()

	var resolved: bool = _building_upgrade.resolve_upgrade(UPGRADE_ID)
	assert_bool(resolved).is_true()

	# Upgrade B's own can_purchase() evaluation is unaffected by A's
	# purchase -- resolve_upgrade() never consumed/mutated the shared
	# "building" entry's underlying state.
	assert_bool(_building_upgrade.can_purchase(SHARED_REQUIREMENT_UPGRADE_ID)).is_true()
