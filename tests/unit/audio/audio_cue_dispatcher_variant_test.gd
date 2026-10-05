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


func test_real_cue_map_authors_a_variant_for_every_shipped_skill_and_status_effect() -> void:
	# 2026-10-05 placeholder cue pass: every skill_id in assets/data/skills/ and every Power
	# effect_type that can proc on a tower hit has its own (placeholder) variant cue.
	var real_map: AudioCueMap = load("res://assets/data/audio/audio_cue_map.tres")
	var names: Array[String] = []
	for entry: AudioCueEntry in real_map.entries:
		names.append(String(entry.event_name))
	for skill: String in ["fireball", "frost_nova", "chain_lightning", "earth_slam", "shield_bash"]:
		assert_bool(names.has("hero_skill_activated_" + skill)).override_failure_message("missing variant for %s" % skill).is_true()
	for effect: String in ["burn", "poison", "slow"]:
		assert_bool(names.has("tower_attacked_" + effect)).override_failure_message("missing variant for %s" % effect).is_true()


func test_real_cue_map_routes_fireball_to_its_variant() -> void:
	_dispatcher.set_cue_map(load("res://assets/data/audio/audio_cue_map.tres"))

	GEventBus.hero_skill_activated.emit("fireball", Vector2.ZERO)

	assert_that(_dispatcher.get_last_played_event()).is_equal(&"hero_skill_activated_fireball")