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


# ---------------------------------------------------------------------------
# Capstone lines (equipment-set-effects spec §3.7, AC-13)
# ---------------------------------------------------------------------------

func _fx(type: StringName, params: Dictionary) -> Dictionary:
	return {&"name": "Test", &"type": type, &"params": params}


func test_describe_kill_stack_buff_mentions_stat_stacks_and_duration() -> void:
	var text: String = PanelScript.describe_effect(_fx(&"on_kill_stack_buff",
		{&"stats": {&"physical_attack": 0.03}, &"max_stacks": 10, &"duration": 6.0}))
	assert_str(text).contains(PanelScript.stat_label(&"physical_attack"))
	assert_str(text).contains("3%")
	assert_str(text).contains("10")
	assert_str(text).contains("6s")


func test_describe_crit_status_mentions_the_dot_and_its_size() -> void:
	var text: String = PanelScript.describe_effect(_fx(&"on_crit_status",
		{&"effect_type": "poison", &"effect_value": 0.06, &"effect_duration": 4.0}))
	assert_str(text).contains(tr("SET_EFFECT_STATUS_POISON"))
	assert_str(text).contains("6%")
	assert_str(text).contains("4s")


func test_describe_timed_buffs_mention_stats_and_duration() -> void:
	var wave: String = PanelScript.describe_effect(_fx(&"on_wave_start_buff",
		{&"stats": {&"physical_attack": 0.35, &"attack_range": 0.15}, &"duration": 10.0}))
	assert_str(wave).contains("35%")
	assert_str(wave).contains("15%")
	assert_str(wave).contains("10s")
	var skill: String = PanelScript.describe_effect(_fx(&"on_skill_cast_buff",
		{&"stats": {&"attack_range": 0.2}, &"duration": 5.0}))
	assert_str(skill).contains(PanelScript.stat_label(&"attack_range"))
	assert_str(skill).contains("5s")


func test_describe_phase_state_lists_every_phase() -> void:
	var text: String = PanelScript.describe_effect(_fx(&"phase_state",
		{&"stats": {&"move_speed": 0.3}, &"phases": ["SCOUT", "INTERMISSION"]}))
	assert_str(text).contains(tr("SET_EFFECT_PHASE_SCOUT"))
	assert_str(text).contains(tr("SET_EFFECT_PHASE_INTERMISSION"))
	assert_str(text).contains("30%")


## The exact line the panel renders for a set's capstone at `threshold`.
## get_body_text() strips BBCode, so earned/muted styling is asserted on the
## raw RichTextLabel text (_body.text) instead.
func _capstone_line(set_id: StringName, threshold: int) -> String:
	var effect: Dictionary = GGameDataRegistry.get_equipment_set(set_id).effects[threshold]
	return "  " + tr("SET_EFFECT_CAPSTONE_LINE") % [threshold, effect[&"name"], PanelScript.describe_effect(effect)]


func test_bonuses_state_shows_an_earned_capstone_unmuted() -> void:
	_equip("gloves", "lurker_claw_gauntlets")
	_equip("main_hand", "lurker_fang_blade")
	_panel.show_bonuses()
	var line: String = _capstone_line(&"set_lurker", 2)
	assert_str(_panel.get_body_text()).contains("Venom Strike")
	assert_str(_panel._body.text).contains(line)
	assert_str(_panel._body.text).not_contains("[color=%s]%s[/color]" % [PanelScript.COLOR_MUTED, line])


func test_bonuses_state_shows_an_unearned_capstone_muted() -> void:
	_equip("helmet", "brutes_war_helm")
	_equip("gloves", "brute_gauntlets")
	_panel.show_bonuses()
	var line: String = _capstone_line(&"set_brute", 5)
	assert_str(_panel.get_body_text()).contains("Juggernaut")
	assert_str(_panel._body.text).contains("[color=%s]%s[/color]" % [PanelScript.COLOR_MUTED, line])


func test_a_set_with_no_pieces_equipped_shows_no_capstone() -> void:
	_panel.show_bonuses()
	assert_str(_panel.get_body_text()).not_contains("Juggernaut")
