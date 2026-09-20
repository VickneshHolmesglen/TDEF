extends GdUnitTestSuite

## Unit tests for equipment_info_panel.gd (equipment-display spec §3.3, §3.5,
## AC-6..AC-8, AC-10). Label assertions use tr()/the panel's own stat_label()
## so they hold whether or not the translation is loaded.

const PanelScript := preload("res://src/gameplay/ui/inventory_screen/equipment_info_panel.gd")
const HELM: String = "res://assets/data/items/iron_helm.tres"

var _panel: PanelContainer


func before_test() -> void:
	GInventory.reset_to_defaults()
	_panel = PanelScript.new()
	add_child(_panel)


func after_test() -> void:
	GInventory.reset_to_defaults()
	if _panel != null and is_instance_valid(_panel):
		remove_child(_panel)
		_panel.free()
	_panel = null


func _contents(item_id: String, overrides: Dictionary, runes: Array[String] = [], rune_slots: int = 2) -> Dictionary:
	return {"item_id": item_id, "stat_overrides": overrides, "imbued_runes": runes, "rune_slot_count": rune_slots}


func test_format_value_uses_integer_decimal_and_percent_forms() -> void:
	assert_str(PanelScript.format_value(&"max_hp", 96.0)).is_equal("+96")
	assert_str(PanelScript.format_value(&"physical_attack", 6.0)).is_equal("+6.0")
	assert_str(PanelScript.format_value(&"crit_chance", 0.056)).is_equal("+5.6%")
	assert_str(PanelScript.format_value(&"armor", -8.0)).is_equal("-8")
	assert_str(PanelScript.format_value(&"some_typo_stat", 2.0)).is_equal("+2.0")


func test_ordered_stats_follow_display_order_and_put_unknown_last() -> void:
	var order: Array[StringName] = PanelScript.ordered_stats({&"typo_stat": 1.0, &"luck": 0.1, &"max_hp": 5.0, &"armor": 2.0})
	assert_array(order).is_equal([&"max_hp", &"armor", &"luck", &"typo_stat"])


func test_bonuses_state_empty_shows_no_bonuses_line() -> void:
	_panel.show_bonuses()
	assert_str(_panel.get_body_text()).contains(tr("INVENTORY_INFO_NO_BONUSES"))


func test_bonuses_state_lists_equipped_totals() -> void:
	GInventory.equip_item("helmet", load(HELM), {&"max_hp": 96.0, &"armor": 20.0})
	_panel.show_bonuses()
	var text: String = _panel.get_body_text()
	assert_str(text).contains("+96")
	assert_str(text).contains("+20")
	assert_str(text).contains(PanelScript.stat_label(&"max_hp"))


func test_bonuses_state_shows_all_stats_row_for_fan_out_rune() -> void:
	var shape_id: String = Constellation.SHAPE_N.keys()[0]
	GInventory.equip_item("helmet", load(HELM), {&"max_hp": 10.0, &"armor": 4.0})
	# equip_item() creates the slot with 0 rune slots; give it 2 (test-only setup).
	GInventory._slots[Inventory.EQUIPMENT_SLOT_INDEX["helmet"]].rune_slot_count = 2
	var slot: Dictionary = GInventory.get_equipped_item("helmet")
	assert_bool(GInventory.apply_rune_to_item(slot["instance_id"], "rune_%s" % shape_id, {})).is_true()
	_panel.show_bonuses()
	assert_str(_panel.get_body_text()).contains(tr("INVENTORY_INFO_ALL_STATS"))
	assert_str(_panel.get_body_text()).contains("+5.0%")


func test_card_for_equipped_item_shows_name_stats_and_no_delta() -> void:
	GInventory.equip_item("helmet", load(HELM), {&"max_hp": 10.0, &"armor": 4.0})
	_panel.show_item(GInventory.get_equipped_item("helmet"), "helmet")
	var text: String = _panel.get_body_text()
	assert_str(text).contains("+10")
	assert_str(text).contains("+4")
	assert_str(text).not_contains("(")


func test_card_for_inventory_item_shows_swap_delta_with_sign() -> void:
	GInventory.equip_item("helmet", load(HELM), {&"max_hp": 10.0, &"armor": 4.0})
	_panel.show_item(_contents("iron_helm", {&"max_hp": 10.0, &"armor": 12.0}), "")
	assert_str(_panel.get_body_text()).contains("(+8)")


func test_card_shows_inherited_base_stat_delta() -> void:
	GInventory.equip_item("helmet", load(HELM), {&"max_hp": 10.0, &"armor": 4.0})
	# Only armor is overridden, so the candidate inherits base max_hp (25),
	# 15 more than the equipped 10.
	_panel.show_item(_contents("iron_helm", {&"armor": 4.0}), "")
	assert_str(_panel.get_body_text()).contains("(+15)")


func test_card_with_no_stats_shows_no_stat_bonuses_and_raw_id() -> void:
	_panel.show_item(_contents("no_such_item", {}), "")
	assert_str(_panel.get_body_text()).contains(tr("INVENTORY_INFO_NO_STATS"))
	assert_str(_panel.get_child(0).get_child(0).text).is_equal("no_such_item")


func test_card_lists_unknown_rune_and_free_rune_slots() -> void:
	_panel.show_item(_contents("iron_helm", {&"max_hp": 10.0, &"armor": 4.0}, ["rune_does_not_exist"], 3), "")
	var text: String = _panel.get_body_text()
	assert_str(text).contains(tr("INVENTORY_INFO_UNKNOWN_RUNE"))
	assert_str(text).contains(tr("INVENTORY_INFO_RUNE_SLOTS") % [2, 3])


func test_unknown_stat_key_is_rendered_not_dropped() -> void:
	_panel.show_item(_contents("iron_helm", {&"max_hp": 10.0, &"armor": 4.0, &"typo_stat": 3.0}), "helmet")
	assert_str(_panel.get_body_text()).contains("typo_stat")


func test_refresh_falls_back_to_bonuses_when_equipped_slot_emptied() -> void:
	GInventory.equip_item("helmet", load(HELM), {&"max_hp": 10.0, &"armor": 4.0})
	_panel.show_item(GInventory.get_equipped_item("helmet"), "helmet")
	GInventory.unequip_item("helmet")
	_panel.refresh()
	assert_str(_panel.get_body_text()).contains(tr("INVENTORY_INFO_NO_BONUSES"))
