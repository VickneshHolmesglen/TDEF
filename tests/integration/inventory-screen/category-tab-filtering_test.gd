## Integration tests for the Inventory & Crafting screen's category tabs
## (design/gdd/inventory.md Rule 3, player-requested 2026-08-10). Each
## TAB_ORDER entry (Equipment, TowerComponent, Material, CraftedGood) is a
## real toggle button that filters the slot grid to that item_type.
##
## Rule 3 / this screen's own doc comment: tabs are a view over ONE shared
## slot pool (capacity/locks/expansion are never per-category) -- an EMPTY
## slot isn't yet assigned to any category and stays visible on every tab;
## only OCCUPIED slots hide when their item's item_type doesn't match the
## active tab. Real item data used throughout: warding_band (Equipment),
## iron_foundation_component (TowerComponent), common_scrap (Material),
## healing_salve (CraftedGood).
extends GdUnitTestSuite

var _runner: GdUnitSceneRunner
var _screen: Control


func before_test() -> void:
	GInventory.reset_to_defaults()
	_runner = scene_runner("res://src/gameplay/ui/inventory_screen/InventoryScreen.tscn")
	_screen = _runner.scene() as Control


func after_test() -> void:
	GInventory.reset_to_defaults()


func _slot_button(index: int) -> Button:
	var slot_buttons: Array = _screen.get("_slot_buttons")
	return slot_buttons[index] as Button


func _tab_button(tab: StringName) -> Button:
	var tab_buttons: Dictionary = _screen.get("_tab_buttons")
	return tab_buttons[tab] as Button


func _press_tab(tab: StringName) -> void:
	_tab_button(tab).pressed.emit()


# ---------------------------------------------------------------------------
# Default state
# ---------------------------------------------------------------------------

func test_tab_strip_has_one_real_toggle_button_per_tab_order_entry() -> void:
	for tab: StringName in Inventory.TAB_ORDER:
		var button: Button = _tab_button(tab)
		assert_object(button).is_not_null()
		assert_bool(button.toggle_mode).is_true()


func test_first_tab_is_active_by_default() -> void:
	assert_bool(_tab_button(Inventory.TAB_ORDER[0]).button_pressed).is_true()


func test_all_slots_visible_by_default_when_inventory_is_empty() -> void:
	for i: int in range(GInventory.get_slot_count()):
		assert_bool(_slot_button(i).visible).is_true()


# ---------------------------------------------------------------------------
# Filtering: empty slots always visible, occupied slots gated by item_type
# ---------------------------------------------------------------------------

func test_empty_slots_stay_visible_on_every_tab() -> void:
	for tab: StringName in Inventory.TAB_ORDER:
		_press_tab(tab)
		for i: int in range(GInventory.get_slot_count()):
			assert_bool(_slot_button(i).visible).is_true()


func test_material_slot_hidden_on_equipment_tab_visible_on_material_tab() -> void:
	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"common_scrap")
	GInventory.add_stackable(definition, 5)

	_press_tab(&"Equipment")
	assert_bool(_slot_button(0).visible).is_false()

	_press_tab(&"Material")
	assert_bool(_slot_button(0).visible).is_true()


func test_equipment_item_hidden_on_material_tab_visible_on_equipment_tab() -> void:
	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"warding_band")
	GInventory.add_unique_item(definition)

	_press_tab(&"Material")
	assert_bool(_slot_button(0).visible).is_false()

	_press_tab(&"Equipment")
	assert_bool(_slot_button(0).visible).is_true()


func test_tower_component_and_crafted_good_each_visible_only_on_their_own_tab() -> void:
	var foundation: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"iron_foundation_component")
	GInventory.add_unique_item(foundation)
	var salve: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"healing_salve")
	GInventory.add_stackable(salve, 3)

	# Two distinct occupied slots now exist -- exactly one visible per tab.
	_press_tab(&"TowerComponent")
	assert_int(_visible_occupied_count()).is_equal(1)

	_press_tab(&"CraftedGood")
	assert_int(_visible_occupied_count()).is_equal(1)


func _visible_occupied_count() -> int:
	var count: int = 0
	for i: int in range(GInventory.get_slot_count()):
		var contents: Dictionary = GInventory.get_slot_contents(i)
		# A locked, not-yet-filled InventorySlot (Rule 5's pre-locked
		# mandatory equip slots) returns a non-empty Dictionary with
		# item_id == "" -- not actually "occupied" for this count's purpose.
		if (contents.get("item_id", "") as String) != "" and _slot_button(i).visible:
			count += 1
	return count


# ---------------------------------------------------------------------------
# Live refresh — filter recomputes when inventory contents change
# ---------------------------------------------------------------------------

func test_switching_tabs_back_and_forth_updates_visibility_live() -> void:
	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"common_scrap")
	GInventory.add_stackable(definition, 5)
	_press_tab(&"Material")
	assert_bool(_slot_button(0).visible).is_true()

	_press_tab(&"Equipment")
	assert_bool(_slot_button(0).visible).is_false()

	_press_tab(&"Material")
	assert_bool(_slot_button(0).visible).is_true()


func test_item_added_after_tab_selected_updates_visibility_without_switching_tabs() -> void:
	_press_tab(&"CraftedGood")
	var salve: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"healing_salve")

	GInventory.add_stackable(salve, 3)  # fires the real item_added signal

	assert_bool(_slot_button(0).visible).is_true()


func test_item_fully_consumed_reverts_slot_to_visible_on_every_tab() -> void:
	var salve: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"healing_salve")
	GInventory.add_stackable(salve, 3)
	_press_tab(&"Equipment")
	assert_bool(_slot_button(0).visible).is_false()

	GInventory.consume_by_type("CraftedGood", 3)  # empties the slot

	assert_bool(_slot_button(0).visible).is_true()
