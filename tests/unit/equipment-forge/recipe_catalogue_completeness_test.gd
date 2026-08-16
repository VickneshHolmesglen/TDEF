## Regression guard for two content gaps found and fixed 2026-08-07: the
## accessory equip-slot had zero Equipment Recipes (commit 9f0b589,
## recipe_warding_band), and only 2 of the 5 real Menagerie species had a
## Sacrifice Recipe (commit b0ebd3a, added mossback_toad/emberwing_moth/
## duskfang_fox).
##
## Exercises the real GGameDataRegistry Autoload (both recipe types are
## static, boot-loaded content).
extends GdUnitTestSuite

## equipment-forge.md Rule 1's fixed slot-category vocabulary. Expanded
## 2026-08-16 (player-requested) from the old 4-category weapon/armor/
## accessory/trinket vocabulary alongside the 5->10 equip-slot expansion —
## 5 new item+recipe pairs (offhand/helmet/gloves/pants/boots) were authored
## specifically to keep this completeness guarantee intact.
const EQUIP_SLOT_CATEGORIES: Array[String] = [
	"weapon", "offhand", "helmet", "chest", "gloves", "pants", "boots", "neck", "ring",
]

## menagerie.md Core Rule 1's fixed 5-species roster.
const MENAGERIE_SPECIES: Array[StringName] = [
	&"glimmer_hare", &"mossback_toad", &"emberwing_moth", &"duskfang_fox", &"aurora_stag",
]


## equipment-forge.md Tuning Knobs: "fewer than 4 recipes leaves at least one
## of the 5 equip-slot categories with no craftable path at all" -- the real
## bug this guards against wasn't the total count, it was one category
## (accessory) sitting at zero while others had two.
func test_every_equip_slot_category_has_at_least_one_recipe() -> void:
	var recipes: Dictionary[StringName, EquipmentRecipeResource] = GGameDataRegistry.get_all_equipment_recipes()
	var slots_covered: Dictionary = {}
	for recipe_id: StringName in recipes:
		slots_covered[recipes[recipe_id].output_slot] = true

	for slot: String in EQUIP_SLOT_CATEGORIES:
		assert_bool(slots_covered.has(slot)) \
			.override_failure_message("equip-slot category '%s' has zero Equipment Recipes — no craftable path exists for it" % slot) \
			.is_true()


## equipment-forge.md Rule 18: "one recipe per species (5 total at Alpha,
## matching Menagerie's roster)."
func test_every_menagerie_species_has_exactly_one_sacrifice_recipe() -> void:
	var recipes: Dictionary[StringName, SacrificeRecipeResource] = GGameDataRegistry.get_all_sacrifice_recipes()
	var species_covered: Dictionary = {}
	for recipe_id: StringName in recipes:
		var required: StringName = recipes[recipe_id].required_species
		assert_bool(species_covered.has(required)) \
			.override_failure_message("species '%s' has more than one Sacrifice Recipe (%s)" % [required, recipe_id]) \
			.is_false()
		species_covered[required] = true

	for species: StringName in MENAGERIE_SPECIES:
		assert_bool(species_covered.has(species)) \
			.override_failure_message("species '%s' has no Sacrifice Recipe" % species) \
			.is_true()

	assert_int(recipes.size()).is_equal(MENAGERIE_SPECIES.size())
