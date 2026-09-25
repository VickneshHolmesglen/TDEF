extends GdUnitTestSuite

## Unit tests for SetEffectResolver (equipment-set-effects spec §3.3, AC-2).
## Pure: takes equipped-contents lists, never touches GInventory.


func _c(item_id: String) -> Dictionary:
	return {"item_id": item_id, "stat_overrides": {}, "imbued_runes": [], "rune_slot_count": 0}


func _list(item_ids: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item_id: String in item_ids:
		out.append(_c(item_id))
	return out


func test_no_pieces_yields_no_effects() -> void:
	assert_array(SetEffectResolver.active_effects(_list([]))).is_empty()


func test_below_threshold_yields_no_effect() -> void:
	assert_array(SetEffectResolver.active_effects(_list(["lurker_fang_blade"]))).is_empty()


func test_lurker_capstone_activates_at_two_pieces() -> void:
	var effects: Array[Dictionary] = SetEffectResolver.active_effects(_list(["lurker_claw_gauntlets", "lurker_fang_blade"]))
	assert_int(effects.size()).is_equal(1)
	var effect: Dictionary = effects[0]
	assert_bool(effect[&"key"] == &"set_lurker:2").is_true()
	assert_bool(effect[&"set_id"] == &"set_lurker").is_true()
	assert_int(effect[&"threshold"]).is_equal(2)
	assert_str(String(effect[&"name"])).is_equal("Venom Strike")
	assert_bool(effect[&"type"] == &"on_crit_status").is_true()
	assert_float(float((effect[&"params"] as Dictionary)[&"effect_value"])).is_equal_approx(0.06, 0.0001)


func test_capstone_is_only_at_the_top_threshold() -> void:
	var four: Array[String] = ["brutes_war_helm", "brutes_bulwark_plate", "brute_gauntlets", "brute_legguards"]
	assert_array(SetEffectResolver.active_effects(_list(four))).is_empty()
	var five: Array[String] = four.duplicate()
	five.append("brute_core_band")
	var effects: Array[Dictionary] = SetEffectResolver.active_effects(_list(five))
	assert_int(effects.size()).is_equal(1)
	assert_bool(effects[0][&"key"] == &"set_brute:5").is_true()


func test_identical_items_count_once() -> void:
	assert_array(SetEffectResolver.active_effects(_list(["lurker_fang_blade", "lurker_fang_blade"]))).is_empty()


func test_two_sets_yield_two_effects_sorted_by_set_id() -> void:
	var items: Array[String] = [
		"lurker_claw_gauntlets", "lurker_fang_blade",
		"goblin_fang_circlet", "goblin_claw_gauntlets", "goblin_raider_leggings", "goblin_signet",
	]
	var effects: Array[Dictionary] = SetEffectResolver.active_effects(_list(items))
	assert_int(effects.size()).is_equal(2)
	assert_bool(effects[0][&"set_id"] == &"set_goblin").is_true()
	assert_bool(effects[1][&"set_id"] == &"set_lurker").is_true()


func test_effect_key_format() -> void:
	assert_bool(SetEffectResolver.effect_key(&"set_troll", 4) == &"set_troll:4").is_true()


func test_effects_for_set_returns_declared_effects() -> void:
	var declared: Dictionary = SetEffectResolver.effects_for_set(&"set_brute")
	assert_int(declared.size()).is_equal(1)
	assert_bool(declared.has(5)).is_true()


func test_effects_for_unknown_set_is_empty() -> void:
	assert_bool(SetEffectResolver.effects_for_set(&"set_nope").is_empty()).is_true()
