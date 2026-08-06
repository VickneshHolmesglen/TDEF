## Integration tests for Inventory slot icon + rarity-frame rendering
## (2026-08-06, design/quick-specs/inventory-slot-icons-2026-08-06.md).
## Exercises the real GInventory/GGameDataRegistry Autoloads and the 13 real
## material ItemDefinitionResource files authored in the immediately prior
## extract (design/quick-specs/wire-materials-into-inventory-2026-08-06.md).
##
## The icon-present path has no real icon art yet (Phase 3, still to come) --
## temporarily injects a synthetic ItemDefinitionResource with a real
## Texture2D directly into GGameDataRegistry's own _item_definitions
## dictionary (GDScript's underscore prefix is a convention, not true
## privacy) to prove that specific rendering branch, then removes it.
extends GdUnitTestSuite

const GOBLIN_HIDE: StringName = &"goblin_hide"  # Common, no icon yet
const GOBLIN_FANG: StringName = &"goblin_fang"  # Rare, no icon yet
const FAKE_ICON_ITEM_ID: StringName = &"test_fake_icon_material"

var _runner: GdUnitSceneRunner
var _screen: Control
var _injected_definition: bool = false


func before_test() -> void:
	GInventory.reset_to_defaults()


func after_test() -> void:
	GInventory.reset_to_defaults()
	if _injected_definition:
		GGameDataRegistry._item_definitions.erase(FAKE_ICON_ITEM_ID)
		_injected_definition = false


func _mount() -> void:
	_runner = scene_runner("res://src/gameplay/ui/inventory_screen/InventoryScreen.tscn")
	_screen = _runner.scene() as Control


func _slot(index: int) -> Button:
	return _screen.get_node("MainLayout/LeftPanel/SlotGrid/Slot%d" % index) as Button


func test_empty_slot_has_no_text_no_frame_no_icon() -> void:
	_mount()

	var slot: Button = _slot(0)
	var frame: RarityFrame = slot.get_node("RarityFrame")
	var icon: TextureRect = slot.get_node("ItemIcon")

	assert_str(slot.text).is_equal("")
	assert_str(frame.rarity).is_equal("")
	assert_bool(icon.visible).is_false()


func test_common_material_with_no_icon_falls_back_to_existing_text_and_shows_circle_frame() -> void:
	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(GOBLIN_HIDE)
	GInventory.add_stackable(definition, 3)
	_mount()

	var slot: Button = _find_slot_showing(String(GOBLIN_HIDE))
	assert_object(slot).is_not_null()
	assert_str(slot.text).is_equal("goblin_hide x3")

	var frame: RarityFrame = slot.get_node("RarityFrame")
	assert_str(frame.rarity).is_equal("Common")

	var icon: TextureRect = slot.get_node("ItemIcon")
	assert_bool(icon.visible).is_false()


func test_rare_material_shows_diamond_frame_rarity() -> void:
	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(GOBLIN_FANG)
	GInventory.add_stackable(definition, 1)
	_mount()

	var slot: Button = _find_slot_showing(String(GOBLIN_FANG))
	assert_object(slot).is_not_null()

	var frame: RarityFrame = slot.get_node("RarityFrame")
	assert_str(frame.rarity).is_equal("Rare")


func test_item_with_a_real_icon_hides_text_and_shows_icon_plus_quantity() -> void:
	var fake_definition := ItemDefinitionResource.new()
	fake_definition.item_id = FAKE_ICON_ITEM_ID
	fake_definition.item_type = &"Material"
	fake_definition.display_name = "Test Fake Icon Material"
	fake_definition.is_unique_instance = false
	fake_definition.rarity = "Common"
	fake_definition.icon = load("res://assets/art/ui/gold_coin.png")
	GGameDataRegistry._item_definitions[FAKE_ICON_ITEM_ID] = fake_definition
	_injected_definition = true

	GInventory.add_stackable(fake_definition, 5)
	_mount()

	var slot: Button = _find_slot_showing(String(FAKE_ICON_ITEM_ID))
	assert_object(slot).is_not_null()
	assert_str(slot.text).is_equal("")

	var icon: TextureRect = slot.get_node("ItemIcon")
	assert_bool(icon.visible).is_true()
	assert_object(icon.texture).is_not_null()

	var quantity_label: Label = slot.get_node("QuantityLabel")
	assert_bool(quantity_label.visible).is_true()
	assert_str(quantity_label.text).is_equal("x5")


func test_non_material_item_type_has_no_rarity_frame() -> void:
	var equipment: ItemDefinitionResource = ItemDefinitionResource.new()
	equipment.item_id = &"test_fake_equipment"
	equipment.item_type = &"Equipment"
	equipment.display_name = "Test Fake Equipment"
	equipment.is_unique_instance = true
	equipment.equipment_category = "weapon"
	GGameDataRegistry._item_definitions[&"test_fake_equipment"] = equipment
	_injected_definition = true

	GInventory.add_unique_item(equipment)
	_mount()

	var slot: Button = _find_slot_showing(String(&"test_fake_equipment"))
	assert_object(slot).is_not_null()
	var frame: RarityFrame = slot.get_node("RarityFrame")
	assert_str(frame.rarity).is_equal("")

	GGameDataRegistry._item_definitions.erase(&"test_fake_equipment")


func _find_slot_showing(item_id: String) -> Button:
	for i: int in range(GInventory.get_slot_count()):
		var contents: Dictionary = GInventory.get_slot_contents(i)
		if not contents.is_empty() and contents["item_id"] == item_id:
			return _slot(i)
	return null
