extends GdUnitTestSuite

## Unit tests for ItemDefinitionResource's skill_modifier item_type and
## requires_tag field (hero-skill-build.md Rule 13, 2026-09-02 — closes that
## GDD's flagged Inventory gap). Scoped to the new rules only; this class's
## other validate() rules (equipment_category, component_resource_path) have
## no pre-existing dedicated test file and are out of scope here.

func _make_skill_modifier(requires_tag: String) -> ItemDefinitionResource:
	var item := ItemDefinitionResource.new()
	item.item_id = &"test_modifier"
	item.item_type = &"skill_modifier"
	item.display_name = "Test Modifier"
	item.is_unique_instance = true
	item.requires_tag = requires_tag
	return item


func test_skill_modifier_is_a_valid_item_type() -> void:
	assert_array(ItemDefinitionResource.VALID_ITEM_TYPES).contains(&"skill_modifier")


func test_skill_modifier_with_valid_requires_tag_passes_validation() -> void:
	var item: ItemDefinitionResource = _make_skill_modifier("Melee")
	assert_array(item.validate()).is_empty()


func test_skill_modifier_with_any_requires_tag_passes_validation() -> void:
	var item: ItemDefinitionResource = _make_skill_modifier("any")
	assert_array(item.validate()).is_empty()


func test_skill_modifier_with_empty_requires_tag_fails_validation() -> void:
	var item: ItemDefinitionResource = _make_skill_modifier("")
	assert_array(item.validate()).is_not_empty()


func test_skill_modifier_with_invalid_requires_tag_fails_validation() -> void:
	var item: ItemDefinitionResource = _make_skill_modifier("NotARealTag")
	assert_array(item.validate()).is_not_empty()


func test_non_skill_modifier_with_nonempty_requires_tag_fails_validation() -> void:
	var item := ItemDefinitionResource.new()
	item.item_id = &"test_material"
	item.item_type = &"Material"
	item.display_name = "Test Material"
	item.requires_tag = "Melee"
	assert_array(item.validate()).is_not_empty()


func test_material_item_with_no_requires_tag_passes_validation() -> void:
	var item := ItemDefinitionResource.new()
	item.item_id = &"test_material"
	item.item_type = &"Material"
	item.display_name = "Test Material"
	assert_array(item.validate()).is_empty()
