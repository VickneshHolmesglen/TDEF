extends GdUnitTestSuite

## Hero skill status cue (design/quick-specs/status-pips-2026-11-03.md): a
## skill hit that leaves a status plays hero_status_<effect> (or the generic
## hero_status_applied), rate-limited so an area cast makes one sound.

var _dispatcher: AudioCueDispatcher


func before_test() -> void:
	_dispatcher = AudioCueDispatcher.new()
	add_child(_dispatcher)
	var map := AudioCueMap.new()
	map.entries = [_entry(&"hero_status_applied"), _entry(&"hero_status_dot_burn")]
	_dispatcher.set_cue_map(map)


func after_test() -> void:
	if _dispatcher != null and is_instance_valid(_dispatcher):
		_dispatcher.free()
	_dispatcher = null


func _entry(event_name: StringName) -> AudioCueEntry:
	var entry := AudioCueEntry.new()
	entry.event_name = event_name
	entry.bus = &"SFX"
	entry.polyphony_group = &""
	entry.spatial = false
	return entry


func _hit(skill_id: StringName) -> void:
	var payload := HeroSkillAttackEvent.new()
	payload.skill_id = skill_id
	payload.target_id = 1
	_dispatcher._dispatch_hero_status(payload.skill_id)


func _reopen_window() -> void:
	_dispatcher._last_hero_status_msec = Time.get_ticks_msec() - AudioCueDispatcher.HERO_STATUS_MIN_GAP_MSEC - 1


func test_hero_status_uses_the_effect_variant_when_authored() -> void:
	_hit(&"elem_firestorm")  # dot_burn
	assert_that(_dispatcher.get_last_played_event()).is_equal(&"hero_status_dot_burn")


func test_hero_status_falls_back_to_the_generic_cue() -> void:
	_hit(&"elem_static_field")  # stun: no variant in this map
	assert_that(_dispatcher.get_last_played_event()).is_equal(&"hero_status_applied")


func test_hero_status_silent_for_effects_that_leave_no_status() -> void:
	_hit(&"elem_arc_lightning")  # chain
	_hit(&"phys_last_stand")     # lifesteal_bonus
	assert_int(_dispatcher.get_dispatch_count()).is_equal(0)


func test_hero_status_area_cast_makes_one_sound_per_window() -> void:
	for i: int in range(6):
		_hit(&"elem_poison_nova")
	assert_int(_dispatcher.get_dispatch_count()).is_equal(1)
	_reopen_window()
	_hit(&"elem_poison_nova")
	assert_int(_dispatcher.get_dispatch_count()).is_equal(2)


func test_hero_status_is_wired_to_the_real_signal() -> void:
	var payload := HeroSkillAttackEvent.new()
	payload.skill_id = &"phys_rending_throw"  # armor_shred
	GEventBus.hero_skill_attacked.emit(payload)
	assert_that(_dispatcher.get_last_played_event()).is_equal(&"hero_status_applied")
