extends GdUnitTestSuite

## Content-integrity test for the audio cue map (audio-cue-list spec §4/§10,
## AC-1..AC-5). SPEC is the spec's authoritative table; SHIPPED_TIERS lists
## which priority tiers have real content committed -- append 1, 2, 3 as each
## tier ships (each tier is independently shippable).

const CUE_MAP_PATH: String = "res://assets/data/audio/audio_cue_map.tres"
const SFX_DIR: String = "res://assets/audio/sfx/"
const SOURCES_PATH: String = "res://assets/audio/sfx/SOURCES.md"

const SHIPPED_TIERS: Array[int] = [1]

const EXISTING: Array[StringName] = [
	&"skill_unlocked", &"tower_mastery_proximity_entered", &"tower_mastery_proximity_exited",
]

## tier, family, bus, spatial, variants (0 = single stream, N>=3 = randomizer)
const SPEC: Dictionary[StringName, Dictionary] = {
	&"tower_attacked": {"tier": 1, "family": &"combat_impact", "bus": &"SFX", "spatial": true, "variants": 4},
	&"hero_damage_taken": {"tier": 1, "family": &"combat_impact", "bus": &"SFX", "spatial": true, "variants": 3},
	&"hero_skill_activated": {"tier": 1, "family": &"combat_impact", "bus": &"SFX", "spatial": true, "variants": 0},
	&"tower_placed": {"tier": 1, "family": &"activation_confirm", "bus": &"SFX", "spatial": true, "variants": 0},
	&"wave_countdown_warning": {"tier": 1, "family": &"combat_impact", "bus": &"SFX", "spatial": false, "variants": 0},
	&"boss_died": {"tier": 1, "family": &"discovery_fanfare", "bus": &"UI", "spatial": false, "variants": 0},
	&"component_crafted": {"tier": 2, "family": &"progress_blip", "bus": &"UI", "spatial": false, "variants": 0},
	&"hero_equipment_crafted": {"tier": 2, "family": &"progress_blip", "bus": &"UI", "spatial": false, "variants": 0},
	&"component_repaired": {"tier": 2, "family": &"ui_confirm_cancel", "bus": &"UI", "spatial": false, "variants": 0},
	&"sanctuary_structure_built": {"tier": 2, "family": &"activation_confirm", "bus": &"UI", "spatial": false, "variants": 0},
	&"structure_upgraded": {"tier": 2, "family": &"activation_confirm", "bus": &"UI", "spatial": false, "variants": 0},
	&"constellation_activated": {"tier": 2, "family": &"discovery_fanfare", "bus": &"UI", "spatial": false, "variants": 0},
	&"pre_placement_perk_activated": {"tier": 3, "family": &"activation_confirm", "bus": &"SFX", "spatial": false, "variants": 0},
	&"hero_class_unlocked": {"tier": 3, "family": &"progress_blip", "bus": &"UI", "spatial": false, "variants": 0},
	&"game_paused": {"tier": 3, "family": &"ui_confirm_cancel", "bus": &"UI", "spatial": false, "variants": 0},
	&"game_unpaused": {"tier": 3, "family": &"ui_confirm_cancel", "bus": &"UI", "spatial": false, "variants": 0},
}


func _entries() -> Dictionary:
	var map: AudioCueMap = load(CUE_MAP_PATH) as AudioCueMap
	assert_object(map).is_not_null()
	var by_event: Dictionary = {}
	for entry: AudioCueEntry in map.entries:
		assert_bool(by_event.has(entry.event_name)).override_failure_message("duplicate event_name %s" % entry.event_name).is_false()
		by_event[entry.event_name] = entry
	return by_event


func _shipped_events() -> Array[StringName]:
	var out: Array[StringName] = []
	for event: StringName in SPEC:
		if SHIPPED_TIERS.has(SPEC[event]["tier"] as int):
			out.append(event)
	return out


func test_spec_table_has_16_new_cues() -> void:
	assert_int(SPEC.size()).is_equal(16)


func test_every_entry_is_well_formed() -> void:
	for event: StringName in _entries():
		var entry: AudioCueEntry = _entries()[event]
		assert_object(entry.stream).override_failure_message("%s has null stream" % event).is_not_null()
		assert_bool(entry.bus == &"SFX" or entry.bus == &"UI").override_failure_message("%s bad bus %s" % [event, entry.bus]).is_true()
		assert_bool(VoiceLimiter.DEFAULT_FAMILY_CAPS.has(entry.polyphony_group)).override_failure_message("%s bad family %s" % [event, entry.polyphony_group]).is_true()


func test_existing_three_cues_still_mapped() -> void:
	var by_event: Dictionary = _entries()
	for event: StringName in EXISTING:
		assert_bool(by_event.has(event)).override_failure_message("%s missing" % event).is_true()


func test_mission_phase_changed_is_deliberately_unmapped() -> void:
	assert_bool(_entries().has(&"mission_phase_changed")).is_false()


func test_shipped_tier_entries_match_the_spec_table() -> void:
	var by_event: Dictionary = _entries()
	for event: StringName in _shipped_events():
		assert_bool(by_event.has(event)).override_failure_message("%s not in map" % event).is_true()
		var entry: AudioCueEntry = by_event[event]
		var spec: Dictionary = SPEC[event]
		assert_str(String(entry.polyphony_group)).override_failure_message("%s family" % event).is_equal(String(spec["family"]))
		assert_str(String(entry.bus)).override_failure_message("%s bus" % event).is_equal(String(spec["bus"]))
		assert_bool(entry.spatial).override_failure_message("%s spatial" % event).is_equal(spec["spatial"] as bool)
		var variants: int = spec["variants"] as int
		if variants >= 3:
			assert_bool(entry.stream is AudioStreamRandomizer).override_failure_message("%s should be a randomizer" % event).is_true()
			assert_int((entry.stream as AudioStreamRandomizer).streams_count).override_failure_message("%s variants" % event).is_greater_equal(variants)
		else:
			assert_bool(entry.stream is AudioStreamRandomizer).override_failure_message("%s should be a plain stream" % event).is_false()


func test_shipped_tier_files_exist_and_are_logged() -> void:
	var sources: String = FileAccess.get_file_as_string(SOURCES_PATH)
	for event: StringName in _shipped_events():
		var variants: int = SPEC[event]["variants"] as int
		if variants >= 3:
			for i: int in range(1, variants + 1):
				assert_bool(FileAccess.file_exists(SFX_DIR + "%s_v%d.wav" % [event, i])).override_failure_message("%s_v%d.wav missing" % [event, i]).is_true()
		else:
			assert_bool(FileAccess.file_exists(SFX_DIR + "%s.wav" % event)).override_failure_message("%s.wav missing" % event).is_true()
		assert_str(sources).override_failure_message("%s not in SOURCES.md" % event).contains(String(event))
