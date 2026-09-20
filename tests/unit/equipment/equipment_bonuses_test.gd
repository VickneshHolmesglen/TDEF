extends GdUnitTestSuite

## Unit tests for EquipmentBonuses (equipment-display spec §3.1-3.2, AC-2..AC-5).

const SWORD: String = "res://assets/data/items/iron_sword.tres"
const HELM: String = "res://assets/data/items/iron_helm.tres"
const RING_A: String = "res://assets/data/items/iron_band.tres"


func before_test() -> void:
	GInventory.reset_to_defaults()


func after_test() -> void:
	GInventory.reset_to_defaults()


func _equip(slot: String, path: String, overrides: Dictionary[StringName, float]) -> void:
	assert_bool(GInventory.equip_item(slot, load(path), overrides)).is_true()


func _contents(item_id: String, overrides: Dictionary, runes: Array[String] = []) -> Dictionary:
	return {"item_id": item_id, "stat_overrides": overrides, "imbued_runes": runes, "rune_slot_count": 2}


func test_fan_out_list_has_14_unique_stats() -> void:
	assert_int(EquipmentBonuses.FAN_OUT_STATS.size()).is_equal(14)
	assert_int(Hero.EQUIPMENT_FAN_OUT_STATS.size()).is_equal(14)


func test_item_stats_override_wins_over_base() -> void:
	var stats: Dictionary = EquipmentBonuses.item_stats(_contents("iron_helm", {&"max_hp": 99.0, &"armor": 9.0}))
	assert_float(stats[&"max_hp"]).is_equal_approx(99.0, 0.0001)
	assert_float(stats[&"armor"]).is_equal_approx(9.0, 0.0001)


func test_item_stats_falls_back_to_base_stats_when_no_override() -> void:
	var base: Dictionary = (load(HELM) as ItemDefinitionResource).base_stats
	var stats: Dictionary = EquipmentBonuses.item_stats(_contents("iron_helm", {}))
	assert_float(stats[&"max_hp"]).is_equal_approx(base[&"max_hp"], 0.0001)


func test_item_stats_unregistered_item_is_empty() -> void:
	assert_dict(EquipmentBonuses.item_stats(_contents("no_such_item", {&"armor": 5.0}))).is_empty()


func test_compute_sums_two_items_sharing_a_stat() -> void:
	var a: Dictionary = _contents("iron_helm", {&"max_hp": 10.0, &"armor": 4.0})
	var b: Dictionary = _contents("lucky_charm_trinket", {&"physical_attack": 6.0, &"armor": 3.0})
	var r: Dictionary = EquipmentBonuses.compute([a, b])
	assert_float(r["flat"][&"armor"]).is_equal_approx(7.0, 0.0001)
	assert_float(r["flat"][&"max_hp"]).is_equal_approx(10.0, 0.0001)
	assert_bool((r["additive"] as Dictionary).is_empty()).is_true()


func test_compute_constellation_rune_fans_out_additive() -> void:
	var shape_id: String = "cross_plus"
	var c: Dictionary = _contents("iron_helm", {&"max_hp": 10.0, &"armor": 4.0}, ["rune_%s" % shape_id])
	var r: Dictionary = EquipmentBonuses.compute([c])
	assert_int((r["additive"] as Dictionary).size()).is_equal(14)
	assert_float(r["additive"][&"luck"]).is_equal_approx(EquipmentForge.RUNE_ADDITIVE_BONUS, 0.0001)


func test_compute_skips_empty_and_unregistered_entries() -> void:
	var r: Dictionary = EquipmentBonuses.compute([{}, _contents("no_such_item", {&"armor": 5.0})])
	assert_bool((r["flat"] as Dictionary).is_empty()).is_true()


func test_compute_equipped_matches_hero_result() -> void:
	_equip("main_hand", SWORD, {&"physical_attack": 6.0})
	_equip("helmet", HELM, {&"max_hp": 10.0, &"armor": 4.0})
	var r: Dictionary = EquipmentBonuses.compute_equipped()
	var hero: Hero = Hero.new()
	add_child(hero)
	assert_float(hero.get_effective_stat(&"armor") - hero._base_stats.get(&"armor", 0.0)).is_equal_approx(r["flat"][&"armor"], 0.0001)
	remove_child(hero)
	hero.free()


func test_preview_swap_reports_gain_loss_and_omits_zero() -> void:
	_equip("helmet", HELM, {&"max_hp": 10.0, &"armor": 4.0})
	var candidate: Dictionary = _contents("iron_helm", {&"max_hp": 10.0, &"armor": 12.0})
	var d: Dictionary = EquipmentBonuses.preview_swap("helmet", candidate)
	assert_float(d["flat"][&"armor"]).is_equal_approx(8.0, 0.0001)
	assert_bool((d["flat"] as Dictionary).has(&"max_hp")).is_false()


func test_preview_swap_includes_changed_inherited_stat() -> void:
	_equip("helmet", HELM, {&"max_hp": 10.0, &"armor": 4.0})
	var candidate: Dictionary = _contents("iron_helm", {&"armor": 4.0})
	var base: Dictionary = (load(HELM) as ItemDefinitionResource).base_stats
	var d: Dictionary = EquipmentBonuses.preview_swap("helmet", candidate)
	# candidate still inherits base max_hp since only armor is overridden
	assert_float(d["flat"][&"max_hp"]).is_equal_approx(base[&"max_hp"] - 10.0, 0.0001)


func test_preview_swap_into_empty_slot_equals_full_stats() -> void:
	var candidate: Dictionary = _contents("iron_helm", {&"max_hp": 10.0, &"armor": 4.0})
	var d: Dictionary = EquipmentBonuses.preview_swap("helmet", candidate)
	assert_float(d["flat"][&"armor"]).is_equal_approx(4.0, 0.0001)


func test_target_slot_for_ring_prefers_first_empty() -> void:
	assert_str(EquipmentBonuses.target_slot_for("ring")).is_equal("ring_1")
	_equip("ring_1", RING_A, {&"physical_attack": 1.0, &"crit_chance": 0.01})
	assert_str(EquipmentBonuses.target_slot_for("ring")).is_equal("ring_2")
	_equip("ring_2", RING_A, {&"physical_attack": 1.0, &"crit_chance": 0.01})
	assert_str(EquipmentBonuses.target_slot_for("ring")).is_equal("ring_1")


func test_target_slot_for_unknown_category_is_empty() -> void:
	assert_str(EquipmentBonuses.target_slot_for("banana")).is_equal("")
	assert_str(EquipmentBonuses.target_slot_for("weapon")).is_equal("main_hand")
