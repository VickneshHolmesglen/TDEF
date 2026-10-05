## Unit tests for the events wired by the 2026-10-05 placeholder cue pass. Only signals with no
## autoload subscriber are emitted on the real GEventBus here, so the test never mutates
## Encyclopedia/save state as a side effect; the rest share the identical one-line forward.
extends GdUnitTestSuite

var _dispatcher: AudioCueDispatcher


func before_test() -> void:
	_dispatcher = AudioCueDispatcher.new()
	add_child(_dispatcher)
	var map := AudioCueMap.new()
	map.entries = [
		_entry(&"hero_leveled_up"), _entry(&"constellation_deactivated"), _entry(&"tower_assembled"),
		_entry(&"tower_destroyed"), _entry(&"monster_died"),
		_entry(&"mission_phase_changed_MISSION_COMPLETE"),
	]
	_dispatcher.set_cue_map(map)


func after_test() -> void:
	if _dispatcher != null and is_instance_valid(_dispatcher):
		_dispatcher.free()
	_dispatcher = null


func _entry(event_name: StringName) -> AudioCueEntry:
	var entry := AudioCueEntry.new()
	entry.event_name = event_name
	entry.bus = &"SFX"
	return entry


func test_hero_leveled_up_dispatches_its_cue() -> void:
	GEventBus.hero_leveled_up.emit(2)
	assert_that(_dispatcher.get_last_played_event()).is_equal(&"hero_leveled_up")


func test_constellation_deactivated_dispatches_its_cue() -> void:
	GEventBus.constellation_deactivated.emit("cross", "tower_removed")
	assert_that(_dispatcher.get_last_played_event()).is_equal(&"constellation_deactivated")


func test_tower_assembled_dispatches_its_cue() -> void:
	GEventBus.tower_assembled.emit("tower_1", "Archer")
	assert_that(_dispatcher.get_last_played_event()).is_equal(&"tower_assembled")


func test_tower_destroyed_dispatches_its_cue() -> void:
	GEventBus.tower_destroyed.emit(7, Vector2i(3, 4), "ranged", [], "")
	assert_that(_dispatcher.get_last_played_event()).is_equal(&"tower_destroyed")


func test_monster_deaths_in_one_burst_collapse_to_a_single_cue() -> void:
	_dispatcher._dispatch_monster_died()
	_dispatcher._dispatch_monster_died()
	_dispatcher._dispatch_monster_died()
	assert_int(_dispatcher.get_dispatch_count()).is_equal(1)
	assert_that(_dispatcher.get_last_played_event()).is_equal(&"monster_died")


func test_mission_phase_variant_plays_only_for_phases_with_a_sting() -> void:
	_dispatcher._dispatch_with_variant(&"mission_phase_changed_SCOUT", &"mission_phase_changed")
	assert_that(_dispatcher.get_last_played_event()).is_not_equal(&"mission_phase_changed_SCOUT")
	_dispatcher._dispatch_with_variant(&"mission_phase_changed_MISSION_COMPLETE", &"mission_phase_changed")
	assert_that(_dispatcher.get_last_played_event()).is_equal(&"mission_phase_changed_MISSION_COMPLETE")
