## Unit tests for AudioCueDispatcher's real Formula F2 distance wiring (audio follow-up: spatial
## distance wiring). The dispatcher connects to the real GEventBus, so these emit the real signals
## directly, matching tests/integration/audio/data-driven-cue-dispatch_test.gd's own pattern.
extends GdUnitTestSuite

var _dispatcher: AudioCueDispatcher


func before_test() -> void:
	_dispatcher = AudioCueDispatcher.new()
	add_child(_dispatcher)
	var map := AudioCueMap.new()
	map.entries = [_fixture_entry(&"tower_attacked", true), _fixture_entry(&"tower_placed", true),
			_fixture_entry(&"hero_damage_taken", true), _fixture_entry(&"hero_skill_activated", true)]
	_dispatcher.set_cue_map(map)


func after_test() -> void:
	if _dispatcher != null and is_instance_valid(_dispatcher):
		_dispatcher.free()
	_dispatcher = null


func _fixture_entry(event_name: StringName, spatial: bool) -> AudioCueEntry:
	var entry := AudioCueEntry.new()
	entry.event_name = event_name
	entry.bus = &"SFX"
	entry.spatial = spatial
	entry.volume_db_offset = 0.0
	return entry


func _expected_volume(distance: float) -> float:
	return clampf(1.0 - maxf(distance, 0.0) / AudioCueDispatcher.MAX_AUDIBLE_RADIUS, 0.0, 1.0)


func _placed_event(tower_id: int, cell: Vector2i) -> TowerPlacedEvent:
	var payload := TowerPlacedEvent.new()
	payload.tower_id = tower_id
	payload.grid_position = cell
	return payload


func test_tower_placed_before_any_hero_position_is_known_dispatches_at_full_volume() -> void:
	GEventBus.tower_placed.emit(_placed_event(1, Vector2i(5, 5)))
	assert_float(_dispatcher.get_last_effective_volume_linear()).is_equal_approx(1.0, 0.0001)


func test_tower_placed_uses_the_real_distance_to_the_hero() -> void:
	GEventBus.hero_position_changed.emit(Vector2i(0, 0))
	GEventBus.tower_placed.emit(_placed_event(1, Vector2i(3, 4)))  # length 5
	assert_float(_dispatcher.get_last_effective_volume_linear()).is_equal_approx(_expected_volume(5.0), 0.001)


func test_tower_attacked_uses_the_cached_position_from_tower_placed() -> void:
	GEventBus.hero_position_changed.emit(Vector2i(0, 0))
	GEventBus.tower_placed.emit(_placed_event(7, Vector2i(6, 8)))  # length 10
	GEventBus.tower_attacked.emit(7, 1, 10.0, false, false, "", 0.0, 0.0, 0.0, false)
	assert_float(_dispatcher.get_last_effective_volume_linear()).is_equal_approx(_expected_volume(10.0), 0.001)


func test_tower_attacked_for_an_unknown_tower_id_falls_back_to_the_hero_cell() -> void:
	GEventBus.hero_position_changed.emit(Vector2i(0, 0))
	GEventBus.tower_attacked.emit(999, 1, 10.0, false, false, "", 0.0, 0.0, 0.0, false)
	assert_float(_dispatcher.get_last_effective_volume_linear()).is_equal_approx(1.0, 0.0001)


func test_tower_removed_erases_the_cached_position() -> void:
	GEventBus.hero_position_changed.emit(Vector2i(0, 0))
	GEventBus.tower_placed.emit(_placed_event(3, Vector2i(10, 0)))
	GEventBus.tower_removed.emit(3, Vector2i(10, 0), "physical", "")
	GEventBus.tower_attacked.emit(3, 1, 10.0, false, false, "", 0.0, 0.0, 0.0, false)
	# Falls back to the hero cell (distance 0) now that the tower's own position is gone.
	assert_float(_dispatcher.get_last_effective_volume_linear()).is_equal_approx(1.0, 0.0001)


func test_mission_launched_resets_both_the_hero_cell_and_the_tower_cache() -> void:
	GEventBus.hero_position_changed.emit(Vector2i(0, 0))
	GEventBus.tower_placed.emit(_placed_event(5, Vector2i(3, 4)))

	# Named handler called directly (not emitted on the real bus) so this test doesn't also
	# trigger every other autoload's own mission_launched reaction (WaveManager, MissionSelect, ...).
	_dispatcher._on_mission_launched("the_gap", PackedStringArray(), 1)

	# Unknown hero cell again: a tower_attacked for the (now-forgotten) tower falls back to full volume.
	GEventBus.tower_attacked.emit(5, 1, 10.0, false, false, "", 0.0, 0.0, 0.0, false)
	assert_float(_dispatcher.get_last_effective_volume_linear()).is_equal_approx(1.0, 0.0001)


func test_hero_damage_taken_always_dispatches_at_full_volume_regardless_of_hero_position() -> void:
	GEventBus.hero_position_changed.emit(Vector2i(50, 50))  # far from the grid origin; irrelevant
	GEventBus.hero_damage_taken.emit(10, 0)
	assert_float(_dispatcher.get_last_effective_volume_linear()).is_equal_approx(1.0, 0.0001)


func test_hero_skill_activated_always_dispatches_at_full_volume_regardless_of_cast_target() -> void:
	GEventBus.hero_position_changed.emit(Vector2i(0, 0))
	GEventBus.hero_skill_activated.emit("fireball", Vector2(5000.0, 5000.0))  # a far-away cast target
	assert_float(_dispatcher.get_last_effective_volume_linear()).is_equal_approx(1.0, 0.0001)
