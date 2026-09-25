extends GdUnitTestSuite

## Content-integrity tests for the nine authored equipment sets (equipment-
## set-bonuses spec §3.7/§4, AC-8). EXPECTED is the spec's authoritative table;
## editing a set in data must be a deliberate edit here too.

const EXPECTED: Dictionary[StringName, Dictionary] = {
	&"set_iron": {"members": [&"iron_sword", &"iron_helm", &"iron_greaves", &"iron_buckler", &"iron_band"],
		"bonuses": {2: {&"armor": 8.0}, 4: {&"max_hp": 50.0, &"physical_attack": 3.0}}},
	&"set_leather": {"members": [&"leather_gloves", &"leather_jerkin", &"leather_leggings"],
		"bonuses": {2: {&"move_speed": 8.0}, 3: {&"luck": 0.03}}},
	&"set_reinforced": {"members": [&"reinforced_helm", &"reinforced_plate", &"reinforced_boots", &"reinforced_gauntlets"],
		"bonuses": {2: {&"max_hp": 40.0}, 4: {&"armor": 12.0, &"physical_attack": 4.0}}},
	&"set_goblin": {"members": [&"goblin_fang_circlet", &"goblin_claw_gauntlets", &"goblin_raider_leggings", &"goblin_signet"],
		"bonuses": {2: {&"luck": 0.04}, 4: {&"crit_chance": 0.06, &"move_speed": 15.0}}},
	&"set_brute": {"members": [&"brutes_war_helm", &"brutes_bulwark_plate", &"brute_gauntlets", &"brute_legguards", &"brute_core_band"],
		"bonuses": {2: {&"max_hp": 60.0}, 4: {&"armor": 25.0}, 5: {&"max_hp": 100.0}}},
	&"set_sentinel": {"members": [&"sentinel_visor", &"sentinel_ward", &"sentinels_aegis", &"sentinels_lance", &"sentinels_striders"],
		"bonuses": {2: {&"attack_range": 16.0}, 4: {&"cdr": 0.05, &"elemental_resist_fire": 0.06, &"elemental_resist_frost": 0.06}}},
	&"set_troll": {"members": [&"troll_hide_mantle", &"trollhide_buckler", &"trollhide_striders", &"trollmarrow_band"],
		"bonuses": {2: {&"max_hp": 60.0}, 4: {&"lifesteal": 0.02, &"max_hp": 80.0}}},
	&"set_warlord": {"members": [&"warlords_battleplate", &"warlords_greatblade", &"warlords_greaves", &"warlords_legguards", &"warlords_standard_amulet"],
		"bonuses": {2: {&"physical_attack": 5.0}, 4: {&"max_hp": 80.0, &"armor": 15.0}, 5: {&"additive_bonus_total": 0.05}}},
	&"set_lurker": {"members": [&"lurker_claw_gauntlets", &"lurker_fang_blade"],
		"bonuses": {2: {&"crit_chance": 0.05, &"lifesteal": 0.015}}},
}


func test_exactly_the_nine_expected_sets_exist() -> void:
	var all: Dictionary = GGameDataRegistry.get_all_equipment_sets()
	assert_int(all.size()).is_equal(9)
	for set_id: StringName in EXPECTED:
		assert_bool(all.has(set_id)).override_failure_message("%s missing" % set_id).is_true()


func test_every_set_passes_validate() -> void:
	for set_res: EquipmentSetResource in GGameDataRegistry.get_all_equipment_sets().values():
		assert_array(set_res.validate()).override_failure_message(String(set_res.set_id)).is_empty()


func test_members_and_bonuses_match_the_spec_table_exactly() -> void:
	for set_id: StringName in EXPECTED:
		var set_res: EquipmentSetResource = GGameDataRegistry.get_equipment_set(set_id)
		var expected: Dictionary = EXPECTED[set_id]
		assert_int(set_res.member_item_ids.size()).override_failure_message("%s member count" % set_id).is_equal((expected["members"] as Array).size())
		for member: StringName in expected["members"]:
			assert_bool(set_res.member_item_ids.has(member)).override_failure_message("%s missing member %s" % [set_id, member]).is_true()
		var exp_bonuses: Dictionary = expected["bonuses"]
		assert_int(set_res.bonuses.size()).override_failure_message("%s threshold count" % set_id).is_equal(exp_bonuses.size())
		for threshold: int in exp_bonuses:
			assert_bool(set_res.bonuses.has(threshold)).override_failure_message("%s missing threshold %d" % [set_id, threshold]).is_true()
			var exp_delta: Dictionary = exp_bonuses[threshold]
			var got: Dictionary = set_res.bonuses[threshold]
			assert_int(got.size()).override_failure_message("%s@%d key count" % [set_id, threshold]).is_equal(exp_delta.size())
			for stat: StringName in exp_delta:
				assert_float(float(got[stat])).override_failure_message("%s@%d.%s" % [set_id, threshold, stat]).is_equal_approx(float(exp_delta[stat]), 0.0001)


func test_every_member_is_a_real_equipment_item_and_no_item_is_in_two_sets() -> void:
	var seen: Dictionary = {}
	for set_res: EquipmentSetResource in GGameDataRegistry.get_all_equipment_sets().values():
		for member: StringName in set_res.member_item_ids:
			var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(member)
			assert_object(def).override_failure_message("%s: unknown item %s" % [set_res.set_id, member]).is_not_null()
			assert_str(def.equipment_category).override_failure_message("%s is not equipment" % member).is_not_empty()
			assert_bool(seen.has(member)).override_failure_message("%s is in two sets" % member).is_false()
			seen[member] = set_res.set_id


# ---------------------------------------------------------------------------
# Capstone effects (equipment-set-effects spec §3.9/§4, AC-14)
# ---------------------------------------------------------------------------

const EXPECTED_EFFECTS: Dictionary[StringName, Dictionary] = {
	&"set_troll": {"threshold": 4, "name": "Troll's Frenzy", "type": &"on_kill_stack_buff",
		"params": {&"stats": {&"physical_attack": 0.03}, &"max_stacks": 10, &"duration": 6.0}},
	&"set_lurker": {"threshold": 2, "name": "Venom Strike", "type": &"on_crit_status",
		"params": {&"effect_type": "poison", &"effect_value": 0.06, &"effect_duration": 4.0}},
	&"set_goblin": {"threshold": 4, "name": "Ember Raid", "type": &"on_crit_status",
		"params": {&"effect_type": "burn", &"effect_value": 0.08, &"effect_duration": 3.0}},
	&"set_brute": {"threshold": 5, "name": "Juggernaut", "type": &"on_wave_start_buff",
		"params": {&"stats": {&"physical_attack": 0.35, &"attack_range": 0.15}, &"duration": 10.0}},
	&"set_warlord": {"threshold": 5, "name": "Battle Cry", "type": &"on_wave_start_buff",
		"params": {&"stats": {&"physical_attack": 0.20, &"magic_attack": 0.20}, &"duration": 15.0}},
	&"set_iron": {"threshold": 4, "name": "Steel Reflex", "type": &"on_skill_cast_buff",
		"params": {&"stats": {&"physical_attack": 0.15}, &"duration": 5.0}},
	&"set_reinforced": {"threshold": 4, "name": "Braced Stance", "type": &"on_skill_cast_buff",
		"params": {&"stats": {&"attack_range": 0.20}, &"duration": 6.0}},
	&"set_sentinel": {"threshold": 4, "name": "Overwatch", "type": &"phase_state",
		"params": {&"stats": {&"attack_range": 0.20}, &"phases": ["WAVE_ACTIVE"]}},
	&"set_leather": {"threshold": 3, "name": "Fleet-Footed", "type": &"phase_state",
		"params": {&"stats": {&"move_speed": 0.30}, &"phases": ["SCOUT", "INTERMISSION"]}},
}


func test_every_set_has_exactly_one_capstone_at_its_top_threshold() -> void:
	for set_res: EquipmentSetResource in GGameDataRegistry.get_all_equipment_sets().values():
		var sid: String = String(set_res.set_id)
		assert_int(set_res.effects.size()).override_failure_message("%s effect count" % sid).is_equal(1)
		var top: int = 0
		for threshold: int in set_res.bonuses:
			top = maxi(top, threshold)
		assert_bool(set_res.effects.has(top)).override_failure_message("%s capstone not at top threshold %d" % [sid, top]).is_true()


func test_capstones_match_the_spec_table_exactly() -> void:
	assert_int(EXPECTED_EFFECTS.size()).is_equal(9)
	for set_id: StringName in EXPECTED_EFFECTS:
		var set_res: EquipmentSetResource = GGameDataRegistry.get_equipment_set(set_id)
		var expected: Dictionary = EXPECTED_EFFECTS[set_id]
		var threshold: int = expected["threshold"]
		assert_bool(set_res.effects.has(threshold)).override_failure_message("%s threshold" % set_id).is_true()
		var actual: Dictionary = set_res.effects[threshold]
		assert_str(String(actual[&"name"])).override_failure_message("%s name" % set_id).is_equal(expected["name"])
		assert_bool(actual[&"type"] == expected["type"]).override_failure_message("%s type" % set_id).is_true()
		assert_bool(actual[&"params"] == expected["params"]).override_failure_message("%s params" % set_id).is_true()
