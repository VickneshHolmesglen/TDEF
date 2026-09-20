extends GdUnitTestSuite

## Panel tests for equipment sets (equipment-set-bonuses spec §3.5, AC-9/AC-10).
## Label assertions use tr() / the panel's own helpers so they hold whether or
## not the translation is loaded.

const PanelScript := preload("res://src/gameplay/ui/inventory_screen/equipment_info_panel.gd")

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


func _equip(slot: String, item_id: String) -> void:
	assert_bool(GInventory.equip_item(slot, load("res://assets/data/items/%s.tres" % item_id))).is_true()


func _c(item_id: String) -> Dictionary:
	return {"item_id": item_id, "stat_overrides": {}, "imbued_runes": [], "rune_slot_count": 0}


func test_bonuses_state_omits_the_set_section_when_no_set_piece_is_equipped() -> void:
	_panel.show_bonuses()
	assert_str(_panel.get_body_text()).not_contains(tr("INVENTORY_INFO_SET_BONUSES_HEADER"))


func test_bonuses_state_lists_a_partially_equipped_set_with_progress_and_thresholds() -> void:
	_equip("helmet", "brutes_war_helm")
	_equip("gloves", "brute_gauntlets")
	_panel.show_bonuses()
	var text: String = _panel.get_body_text()
	assert_str(text).contains(tr("INVENTORY_INFO_SET_BONUSES_HEADER"))
	assert_str(text).contains("Brute")
	assert_str(text).contains("2/5")
	assert_str(text).contains(tr("INVENTORY_INFO_SET_THRESHOLD") % 2)
	assert_str(text).contains(tr("INVENTORY_INFO_SET_THRESHOLD") % 4)
	assert_str(text).contains("+60")


func test_item_card_shows_the_set_line_with_the_would_be_count() -> void:
	_equip("helmet", "brutes_war_helm")
	_panel.show_item(_c("brute_gauntlets"), "")
	assert_str(_panel.get_body_text()).contains(tr("INVENTORY_INFO_SET_LINE") % ["Brute", 2, 5])


func test_item_card_for_an_equipped_piece_shows_the_current_count() -> void:
	_equip("helmet", "brutes_war_helm")
	_panel.show_item(GInventory.get_equipped_item("helmet"), "helmet")
	assert_str(_panel.get_body_text()).contains(tr("INVENTORY_INFO_SET_LINE") % ["Brute", 1, 5])


func test_item_card_for_a_non_set_item_has_no_set_line() -> void:
	_panel.show_item(_c("lucky_charm_trinket"), "")
	assert_str(_panel.get_body_text()).not_contains(tr("INVENTORY_INFO_SET_LINE") % ["", 0, 0])
	assert_str(_panel.get_body_text()).not_contains("Set:")


func test_swap_preview_lists_set_induced_stats_not_on_the_item_itself() -> void:
	_equip("offhand", "sentinel_ward")
	_equip("main_hand", "sentinels_lance")
	_equip("boots", "sentinels_striders")
	# sentinel_visor's own stats are max_hp / attack_range / crit_chance; the
	# 4-piece bonus adds cdr and fire/frost resist, which are NOT on the visor.
	_panel.show_item(_c("sentinel_visor"), "")
	var text: String = _panel.get_body_text()
	assert_str(text).contains(PanelScript.stat_label(&"elemental_resist_fire"))
	assert_str(text).contains("+6.0%")


func test_swap_preview_shows_a_lost_set_bonus_as_a_negative_row() -> void:
	_equip("helmet", "brutes_war_helm")
	_equip("gloves", "brute_gauntlets")
	# Swapping the equipped helmet for a non-set helmet breaks the 2-piece bonus (-60 max_hp beyond stat swap).
	_panel.show_item(_c("iron_helm"), "")
	assert_str(_panel.get_body_text()).contains("-")
