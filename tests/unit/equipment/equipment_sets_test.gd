extends GdUnitTestSuite

## Unit tests for equipment set counting and bonuses (equipment-set-bonuses
## spec §3.3/§3.4, AC-3..AC-7). Real registry sets and real items.

const BRUTE_HELM: String = "res://assets/data/items/brutes_war_helm.tres"
const BRUTE_PLATE: String = "res://assets/data/items/brutes_bulwark_plate.tres"
const BRUTE_GAUNTLETS: String = "res://assets/data/items/brute_gauntlets.tres"
const BRUTE_LEGGUARDS: String = "res://assets/data/items/brute_legguards.tres"
const BRUTE_BAND: String = "res://assets/data/items/brute_core_band.tres"

var _hero: Hero


func before_test() -> void:
	GInventory.reset_to_defaults()


func after_test() -> void:
	GInventory.reset_to_defaults()
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null


func _c(item_id: String) -> Dictionary:
	return {"item_id": item_id, "stat_overrides": {}, "imbued_runes": [], "rune_slot_count": 0}


func _equip(slot: String, path: String) -> void:
	assert_bool(GInventory.equip_item(slot, load(path))).is_true()


func test_set_id_for_item() -> void:
	assert_str(String(EquipmentBonuses.set_id_for_item(&"brutes_war_helm"))).is_equal("set_brute")
	assert_str(String(EquipmentBonuses.set_id_for_item(&"lucky_charm_trinket"))).is_equal("")


func test_piece_counts_are_distinct_per_set_and_omit_empty_sets() -> void:
	var counts: Dictionary = EquipmentBonuses.set_piece_counts([_c("brutes_war_helm"), _c("brute_gauntlets"), _c("iron_helm")])
	assert_int(counts[&"set_brute"]).is_equal(2)
	assert_int(counts[&"set_iron"]).is_equal(1)
	assert_bool(counts.has(&"set_warlord")).is_false()


func test_two_copies_of_the_same_item_count_once() -> void:
	var counts: Dictionary = EquipmentBonuses.set_piece_counts([_c("goblin_signet"), _c("goblin_signet")])
	assert_int(counts[&"set_goblin"]).is_equal(1)


func test_unregistered_items_are_not_counted() -> void:
	assert_bool(EquipmentBonuses.set_piece_counts([_c("no_such_item")]).is_empty()).is_true()


func test_below_two_pieces_grants_nothing() -> void:
	var r: Dictionary = EquipmentBonuses.set_bonuses([_c("brutes_war_helm")])
	assert_bool((r["flat"] as Dictionary).is_empty()).is_true()
	assert_bool((r["additive"] as Dictionary).is_empty()).is_true()


func test_two_pieces_grants_only_the_two_piece_bonus() -> void:
	var r: Dictionary = EquipmentBonuses.set_bonuses([_c("brutes_war_helm"), _c("brute_gauntlets")])
	assert_float(r["flat"][&"max_hp"]).is_equal_approx(60.0, 0.0001)
	assert_bool((r["flat"] as Dictionary).has(&"armor")).is_false()


func test_bonuses_are_cumulative_at_four_pieces() -> void:
	var r: Dictionary = EquipmentBonuses.set_bonuses([_c("brutes_war_helm"), _c("brute_gauntlets"), _c("brutes_bulwark_plate"), _c("brute_legguards")])
	assert_float(r["flat"][&"max_hp"]).is_equal_approx(60.0, 0.0001)
	assert_float(r["flat"][&"armor"]).is_equal_approx(25.0, 0.0001)


func test_five_pieces_adds_the_capstone_on_top() -> void:
	var five: Array[Dictionary] = [_c("brutes_war_helm"), _c("brute_gauntlets"), _c("brutes_bulwark_plate"), _c("brute_legguards"), _c("brute_core_band")]
	var r: Dictionary = EquipmentBonuses.set_bonuses(five)
	assert_float(r["flat"][&"max_hp"]).is_equal_approx(160.0, 0.0001)
	assert_float(r["flat"][&"armor"]).is_equal_approx(25.0, 0.0001)


func test_warlord_capstone_fans_out_to_every_additive_bucket() -> void:
	var five: Array[Dictionary] = [_c("warlords_battleplate"), _c("warlords_greatblade"), _c("warlords_greaves"), _c("warlords_legguards"), _c("warlords_standard_amulet")]
	var r: Dictionary = EquipmentBonuses.set_bonuses(five)
	assert_int((r["additive"] as Dictionary).size()).is_equal(14)
	assert_float(r["additive"][&"luck"]).is_equal_approx(0.05, 0.0001)
	assert_bool((r["flat"] as Dictionary).has(&"additive_bonus_total")).is_false()


func test_compute_includes_set_bonuses_on_top_of_item_stats() -> void:
	var list: Array[Dictionary] = [_c("brutes_war_helm"), _c("brute_gauntlets")]
	var items_only_hp: float = 0.0
	for contents: Dictionary in list:
		items_only_hp += EquipmentBonuses.item_stats(contents).get(&"max_hp", 0.0)
	var r: Dictionary = EquipmentBonuses.compute(list)
	assert_float(r["flat"][&"max_hp"]).is_equal_approx(items_only_hp + 60.0, 0.0001)


func test_hero_effective_stat_reflects_the_set_bonus() -> void:
	_equip("helmet", BRUTE_HELM)
	_equip("gloves", BRUTE_GAUNTLETS)
	_hero = Hero.new()
	add_child(_hero)
	var items_only_hp: float = 0.0
	for slot: String in ["helmet", "gloves"]:
		items_only_hp += EquipmentBonuses.item_stats(GInventory.get_equipped_item(slot)).get(&"max_hp", 0.0)
	assert_float(_hero.get_effective_stat(&"max_hp")).is_equal_approx(items_only_hp + 60.0, 0.0001)


func test_preview_swap_reflects_a_threshold_being_completed() -> void:
	_equip("helmet", BRUTE_HELM)
	_equip("chest", BRUTE_PLATE)
	_equip("gloves", BRUTE_GAUNTLETS)
	var candidate: Dictionary = GInventory.get_equipped_item("gloves")
	candidate = _c("brute_legguards")
	var own_armor: float = EquipmentBonuses.item_stats(candidate).get(&"armor", 0.0)
	var d: Dictionary = EquipmentBonuses.preview_swap("pants", candidate)
	assert_float(d["flat"][&"armor"]).is_equal_approx(own_armor + 25.0, 0.0001)


func test_swapped_contents_replaces_only_the_named_slot() -> void:
	_equip("helmet", BRUTE_HELM)
	var swapped: Array[Dictionary] = EquipmentBonuses.swapped_contents("helmet", _c("iron_helm"))
	var ids: Array[String] = []
	for contents: Dictionary in swapped:
		if not contents.is_empty():
			ids.append(contents["item_id"] as String)
	assert_array(ids).is_equal(["iron_helm"])
