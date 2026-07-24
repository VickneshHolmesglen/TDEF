## Unit tests for Story 012 (TR-equipforge-003, ADR-0025): rune slot model
## (AC-13) and the Available Rune Ledger (AC-14/AC-15).
##
## EquipmentForge is instantiated directly (EquipmentForge.new(), no
## add_child()) — matching this system's established test convention.
extends GdUnitTestSuite

var _forge: EquipmentForge


func before_test() -> void:
	_forge = EquipmentForge.new()


func after_test() -> void:
	if _forge != null and is_instance_valid(_forge):
		_forge.free()
	_forge = null


# ---------------------------------------------------------------------------
# AC-13: rune_slot_count per output_slot matches Rule 11's table exactly
# ---------------------------------------------------------------------------

func test_rune_slot_count_table_matches_rule_11() -> void:
	# EquipmentRecipeResource.RUNE_SLOT_COUNT_FOR_SLOT is the single source of
	# truth (fixed by the Story 015 batch code review — this test previously
	# read a duplicate, differently-keyed EquipmentForge constant that has
	# since been removed; see equipment_forge.gd's own doc comment).
	assert_int(EquipmentRecipeResource.RUNE_SLOT_COUNT_FOR_SLOT["weapon"]).is_equal(2)
	assert_int(EquipmentRecipeResource.RUNE_SLOT_COUNT_FOR_SLOT["armor"]).is_equal(2)
	assert_int(EquipmentRecipeResource.RUNE_SLOT_COUNT_FOR_SLOT["accessory"]).is_equal(1)
	assert_int(EquipmentRecipeResource.RUNE_SLOT_COUNT_FOR_SLOT["trinket"]).is_equal(1)


func test_freshly_crafted_item_rune_slot_count_matches_table_via_recipe() -> void:
	# recipe_iron_sword's own rune_slot_count (Story 009 content, weapon slot)
	# must match the fixed table this story validates independently.
	var recipe: EquipmentRecipeResource = GGameDataRegistry.get_equipment_recipe(&"recipe_iron_sword")
	assert_object(recipe).is_not_null()
	assert_int(recipe.rune_slot_count).is_equal(EquipmentRecipeResource.RUNE_SLOT_COUNT_FOR_SLOT[recipe.output_slot])


func test_all_alpha_equipment_recipes_match_rune_slot_count_table() -> void:
	for recipe: EquipmentRecipeResource in GGameDataRegistry.get_all_equipment_recipes().values():
		var expected: int = EquipmentRecipeResource.RUNE_SLOT_COUNT_FOR_SLOT[recipe.output_slot]
		assert_int(recipe.rune_slot_count).is_equal(expected)


# ---------------------------------------------------------------------------
# AC-14: constellation_rune_discovered/tarot_rune_discovered populate the ledger
# ---------------------------------------------------------------------------

func test_constellation_rune_discovered_adds_available_entry() -> void:
	_forge._on_constellation_rune_discovered("rune_triad_line", "pattern_triad_line")

	var entry: Dictionary = _forge.get_available_rune(&"rune_triad_line")
	assert_bool(entry.is_empty()).is_false()
	assert_str(entry["rune_source"] as String).is_equal("constellation")
	assert_bool(entry.has("stat_delta")).is_true()


func test_tarot_rune_discovered_adds_available_entry_with_tarot_source() -> void:
	_forge._on_tarot_rune_discovered("rune_iron_resolve", "iron_resolve")

	var entry: Dictionary = _forge.get_available_rune(&"rune_iron_resolve")
	assert_bool(entry.is_empty()).is_false()
	assert_str(entry["rune_source"] as String).is_equal("tarot")


func test_stat_delta_is_equipment_forge_authored_not_source_derived() -> void:
	# The same rune_id discovered via Constellation gets Equipment Forge's own
	# authored stat_delta — deliberately decoupled from whatever internal
	# bonus_value Constellation itself computes (never read/passed here).
	_forge._on_constellation_rune_discovered("rune_cross_plus", "pattern_cross_plus")
	var entry: Dictionary = _forge.get_available_rune(&"rune_cross_plus")
	var stat_delta: Dictionary = entry["stat_delta"] as Dictionary
	assert_float(stat_delta["additive_bonus_total"] as float).is_between(0.02, 0.08)


func test_rune_discovered_twice_does_not_duplicate_or_overwrite_entry() -> void:
	_forge._on_constellation_rune_discovered("rune_triad_line", "pattern_triad_line")
	var first_entry: Dictionary = _forge.get_available_rune(&"rune_triad_line")

	_forge._on_constellation_rune_discovered("rune_triad_line", "pattern_triad_line")
	var second_entry: Dictionary = _forge.get_available_rune(&"rune_triad_line")

	assert_that(first_entry).is_equal(second_entry)


func test_get_available_rune_returns_empty_for_unknown_rune() -> void:
	assert_dict(_forge.get_available_rune(&"rune_never_discovered")).is_empty()


# ---------------------------------------------------------------------------
# AC-15: creature_sacrificed never adds a new entry to available_runes
# ---------------------------------------------------------------------------

func test_creature_sacrificed_never_populates_available_runes() -> void:
	# Equipment Forge does not even subscribe to creature_sacrificed —
	# Story 014's sacrifice resolution flow consumes a Menagerie-sourced
	# rune directly via Menagerie.request_sacrifice()'s own return value,
	# never through this ledger. Emitting the real signal here proves the
	# structural exclusion: nothing reacts to it, so nothing is added.
	GEventBus.creature_sacrificed.emit(1, 42)

	assert_int(_forge._available_runes.size()).is_equal(0)
