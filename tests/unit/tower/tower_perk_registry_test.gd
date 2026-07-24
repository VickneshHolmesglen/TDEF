## Unit tests for TowerPerkRegistry.validate() (S4-02, ADR-0009).
## Schema: design/gdd/tower.md Rule 12a.
extends GdUnitTestSuite


func _make_full_entries() -> Dictionary:
	return {
		"DAMAGE_BOOST": {
			"label": "Damage Boost",
			"description": "Weapon DPS multiplied by (1.0 + perk_power).",
			"archetype_restrictions": ["Physical", "Ranged", "Elemental"],
		},
		"RANGE_BOOST": {
			"label": "Range Boost",
			"description": "attack_range_cells increased.",
			"archetype_restrictions": ["Physical", "Ranged", "Elemental"],
		},
		"SPEED_BOOST": {
			"label": "Speed Boost",
			"description": "attack_speed multiplied, capped at 4.0.",
			"archetype_restrictions": ["Physical", "Ranged", "Elemental"],
		},
		"AURA_EXTEND": {
			"label": "Aura Extend",
			"description": "aura_radius_cells increased, clamped to 6.",
			"archetype_restrictions": ["Support"],
		},
	}


func test_validate_missing_speed_boost_entry_returns_error() -> void:
	var registry := TowerPerkRegistry.new()
	var entries: Dictionary = _make_full_entries()
	entries.erase("SPEED_BOOST")
	registry.entries = entries
	var errors: Array[String] = registry.validate()
	assert_array(errors).contains("Missing required perk_type entry: SPEED_BOOST")


func test_validate_missing_damage_boost_entry_returns_error() -> void:
	var registry := TowerPerkRegistry.new()
	var entries: Dictionary = _make_full_entries()
	entries.erase("DAMAGE_BOOST")
	registry.entries = entries
	var errors: Array[String] = registry.validate()
	assert_array(errors).contains("Missing required perk_type entry: DAMAGE_BOOST")


func test_validate_entry_with_empty_label_returns_error() -> void:
	var registry := TowerPerkRegistry.new()
	var entries: Dictionary = _make_full_entries()
	entries["RANGE_BOOST"]["label"] = ""
	registry.entries = entries
	var errors: Array[String] = registry.validate()
	assert_array(errors).contains("RANGE_BOOST: missing or empty label")


func test_validate_entry_missing_archetype_restrictions_returns_error() -> void:
	var registry := TowerPerkRegistry.new()
	var entries: Dictionary = _make_full_entries()
	entries["AURA_EXTEND"].erase("archetype_restrictions")
	registry.entries = entries
	var errors: Array[String] = registry.validate()
	assert_array(errors).contains("AURA_EXTEND: missing archetype_restrictions")


func test_validate_all_four_perk_types_present_and_valid_returns_empty_array() -> void:
	var registry := TowerPerkRegistry.new()
	registry.entries = _make_full_entries()
	var errors: Array[String] = registry.validate()
	assert_array(errors).is_empty()


func test_validate_empty_entries_returns_error_for_all_four_types() -> void:
	var registry := TowerPerkRegistry.new()
	registry.entries = {}
	var errors: Array[String] = registry.validate()
	assert_int(errors.size()).is_equal(4)


func test_validate_non_dictionary_entry_returns_error_not_crash() -> void:
	# Regression: a malformed .tres could author a perk_type key pointing at
	# a non-Dictionary value (e.g. a stray String). validate() must catch
	# this itself rather than throwing an uncaught typed-assignment error —
	# a validator crashing on the exact bad data it exists to catch defeats
	# its purpose.
	var registry := TowerPerkRegistry.new()
	var entries: Dictionary = _make_full_entries()
	entries["DAMAGE_BOOST"] = "not a dictionary"
	registry.entries = entries
	var errors: Array[String] = registry.validate()
	assert_array(errors).contains("DAMAGE_BOOST: entry is not a Dictionary (got String)")
	# Remaining perk types after the malformed one are still checked, not skipped.
	assert_int(errors.size()).is_equal(1)
