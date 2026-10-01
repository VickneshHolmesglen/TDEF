## Unit tests for AudioCueDispatcher's per-skill/per-effect-type cue variants (audio follow-up).
## The dispatcher connects to the real GEventBus, matching the project's established dispatcher
## test pattern (tests/integration/audio/data-driven-cue-dispatch_test.gd).
extends GdUnitTestSuite

var _dispatcher: AudioCueDispatcher


func before_test() -> void:
	_dispatcher = AudioCueDispatcher.new()
	add_child(_dispatcher)


func after_test() -> void:
	if _dispatcher != null and is_instance_valid(_dispatcher):
		_dispatcher.free()
	_dispatcher = null


func _entry(event_name: StringName) -> AudioCueEntry:
	var entry := AudioCueEntry.new()
	entry.event_name = event_name
	entry.bus = &"SFX"
	entry.volume_db_offset = 0.0
	return entry


func test_dispatch_with_variant_prefers_the_variant_when_a_cue_entry_exists_for_it() -> void:
	var map := AudioCueMap.new()
	map.entries = [_entry(&"generic"), _entry(&"specific")]
	_dispatcher.set_cue_map(map)

	_dispatcher._dispatch_with_variant(&"specific", &"generic")

	assert_that(_dispatcher.get_last_played_event()).is_equal(&"specific")


func test_dispatch_with_variant_falls_back_when_no_entry_exists_for_it() -> void:
	var map := AudioCueMap.new()
	map.entries = [_entry(&"generic")]
	_dispatcher.set_cue_map(map)

	_dispatcher._dispatch_with_variant(&"specific", &"generic")

	assert_that(_dispatcher.get_last_played_event()).is_equal(&"generic")


func test_dispatch_with_variant_treats_an_empty_variant_name_as_always_falling_back() -> void:
	var map := AudioCueMap.new()
	map.entries = [_entry(&"generic")]
	_dispatcher.set_cue_map(map)

	_dispatcher._dispatch_with_variant(&"", &"generic")

	assert_that(_dispatcher.get_last_played_event()).is_equal(&"generic")


func test_hero_skill_activated_routes_to_a_skill_specific_cue_when_one_is_authored() -> void:
	var map := AudioCueMap.new()
	map.entries = [_entry(&"hero_skill_activated"), _entry(&"hero_skill_activated_fireball")]
	_dispatcher.set_cue_map(map)

	GEventBus.hero_skill_activated.emit("fireball", Vector2.ZERO)

	assert_that(_dispatcher.get_last_played_event()).is_equal(&"hero_skill_activated_fireball")


func test_hero_skill_activated_falls_back_to_the_generic_cue_for_an_unauthored_skill() -> void:
	var map := AudioCueMap.new()
	map.entries = [_entry(&"hero_skill_activated"), _entry(&"hero_skill_activated_fireball")]
	_dispatcher.set_cue_map(map)

	GEventBus.hero_skill_activated.emit("frost_nova", Vector2.ZERO)

	assert_that(_dispatcher.get_last_played_event()).is_equal(&"hero_skill_activated")


func test_tower_attacked_routes_to_an_effect_specific_cue_when_one_is_authored() -> void:
	var map := AudioCueMap.new()
	map.entries = [_entry(&"tower_attacked"), _entry(&"tower_attacked_burn")]
	_dispatcher.set_cue_map(map)

	GEventBus.tower_attacked.emit(1, 1, 10.0, false, false, "burn", 0.1, 2.0, 0.0, false)

	assert_that(_dispatcher.get_last_played_event()).is_equal(&"tower_attacked_burn")


func test_tower_attacked_falls_back_to_the_generic_cue_for_an_unauthored_effect() -> void:
	var map := AudioCueMap.new()
	map.entries = [_entry(&"tower_attacked"), _entry(&"tower_attacked_burn")]
	_dispatcher.set_cue_map(map)

	GEventBus.tower_attacked.emit(1, 1, 10.0, false, false, "slow", 0.15, 2.0, 0.0, false)

	assert_that(_dispatcher.get_last_played_event()).is_equal(&"tower_attacked")


func test_tower_attacked_with_no_effect_type_dispatches_the_generic_cue() -> void:
	var map := AudioCueMap.new()
	map.entries = [_entry(&"tower_attacked")]
	_dispatcher.set_cue_map(map)

	GEventBus.tower_attacked.emit(1, 1, 10.0, false, false, "", 0.0, 0.0, 0.0, false)

	assert_that(_dispatcher.get_last_played_event()).is_equal(&"tower_attacked")


func test_real_cue_map_has_no_variant_entries_yet_so_real_skills_and_effects_share_the_generic_cue() -> void:
	# Honest content status (OQ-2): the mechanism exists, but no per-skill/per-effect-type
	# variant has been authored. If this starts failing, update the session notes, not this test.
	var real_map: AudioCueMap = load("res://assets/data/audio/audio_cue_map.tres")
	for entry: AudioCueEntry in real_map.entries:
		assert_str(String(entry.event_name)).is_not_equal("hero_skill_activated_fireball")
		assert_str(String(entry.event_name)).is_not_equal("tower_attacked_burn")
