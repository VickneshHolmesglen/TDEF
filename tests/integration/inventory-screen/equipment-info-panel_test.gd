extends GdUnitTestSuite

## Integration tests for the Equipment tab's info panel wiring (equipment-
## display spec §3.4, AC-6, AC-7, AC-9). Uses the real InventoryScreen scene.

const HELM: String = "res://assets/data/items/iron_helm.tres"

var _runner: GdUnitSceneRunner
var _screen: Control


func before_test() -> void:
	GInventory.reset_to_defaults()
	_runner = scene_runner("res://src/gameplay/ui/inventory_screen/InventoryScreen.tscn")
	_screen = _runner.scene() as Control


func after_test() -> void:
	GInventory.reset_to_defaults()


func _panel() -> PanelContainer:
	return _screen.get_node("MainLayout/LeftPanel/EquipmentRow/EquipmentInfoPanel") as PanelContainer


func _header_text() -> String:
	return (_panel().get_child(0).get_child(0) as Label).text


func _slot_button(inventory_index: int) -> Button:
	return _screen.get_node("MainLayout/LeftPanel/SlotGrid/Slot%d" % inventory_index) as Button


func test_panel_exists_and_defaults_to_bonuses() -> void:
	assert_object(_panel()).is_not_null()
	assert_str(_panel().get_body_text()).contains(tr("INVENTORY_INFO_NO_BONUSES"))


func test_paperdoll_lives_inside_the_equipment_row() -> void:
	assert_object(_screen.get_node("MainLayout/LeftPanel/EquipmentRow/EquipmentPaperdoll")).is_not_null()


func test_focus_on_equipped_item_slot_shows_card_and_leaving_restores_bonuses() -> void:
	GInventory.equip_item("helmet", load(HELM), {&"max_hp": 10.0, &"armor": 4.0})
	var button: Button = _slot_button(Inventory.EQUIPMENT_SLOT_INDEX["helmet"])
	button.focus_entered.emit()
	assert_str(_header_text()).is_equal("Iron Helm")
	button.focus_exited.emit()
	assert_str(_header_text()).is_equal(tr("INVENTORY_INFO_BONUSES_HEADER"))


func test_hover_on_empty_slot_shows_bonuses_state() -> void:
	_slot_button(0).mouse_entered.emit()
	assert_str(_header_text()).is_equal(tr("INVENTORY_INFO_BONUSES_HEADER"))


func test_paperdoll_hover_shows_card_for_equipped_item() -> void:
	GInventory.equip_item("helmet", load(HELM), {&"max_hp": 10.0, &"armor": 4.0})
	var paperdoll: Control = _screen.get_node("MainLayout/LeftPanel/EquipmentRow/EquipmentPaperdoll")
	paperdoll.emit_signal(&"slot_info_requested", "helmet")
	assert_str(_header_text()).is_equal("Iron Helm")
	assert_str(_panel().get_body_text()).contains("+10")
	paperdoll.emit_signal(&"slot_info_cleared")
	assert_str(_header_text()).is_equal(tr("INVENTORY_INFO_BONUSES_HEADER"))


func test_equip_event_updates_visible_panel_without_tab_switch() -> void:
	assert_str(_panel().get_body_text()).contains(tr("INVENTORY_INFO_NO_BONUSES"))
	GInventory.equip_item("helmet", load(HELM), {&"max_hp": 10.0, &"armor": 4.0})
	assert_str(_panel().get_body_text()).contains("+10")


func test_paperdoll_still_refreshes_on_equip_after_screen_mount() -> void:
	GInventory.equip_item("helmet", load(HELM), {&"max_hp": 10.0, &"armor": 4.0})
	var frame: Panel = _screen.get_node("MainLayout/LeftPanel/EquipmentRow/EquipmentPaperdoll").find_child("Slot_helmet", true, false)
	assert_bool((frame.get_node("Icon") as TextureRect).visible or (frame.get_node("FallbackLabel") as Label).text == "Iron Helm").is_true()


func test_panel_visible_only_on_equipment_tab() -> void:
	_screen._on_tab_pressed(&"Equipment")
	assert_bool(_panel().visible).is_true()
	_screen._on_tab_pressed(&"TowerComponent")
	assert_bool(_panel().visible).is_false()
	_screen._on_tab_pressed(&"Equipment")
	assert_bool(_panel().visible).is_true()
