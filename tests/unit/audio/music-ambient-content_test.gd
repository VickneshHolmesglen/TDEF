extends GdUnitTestSuite

## Content-integrity tests for the placeholder music/ambient stems and their
## wiring (music-ambient-stems spec §8: AC-1, AC-13/14 provenance, AudioSystem wiring).

const MAP_PATH: String = "res://assets/data/audio/music_ambient_map.tres"
const SOURCES_PATH: String = "res://assets/audio/sfx/SOURCES.md"
const STEM_FIELDS: Array[StringName] = [
	&"contemplative", &"measured", &"urgent", &"measured_urgent",
	&"ambient_base_bed", &"ambient_combat_layer",
]


func test_real_map_has_all_six_slots_filled_with_loopable_length_streams() -> void:
	var map: MusicAmbientMap = load(MAP_PATH) as MusicAmbientMap
	assert_object(map).is_not_null()
	for field: StringName in STEM_FIELDS:
		var stream: AudioStream = map.get(field) as AudioStream
		assert_object(stream).override_failure_message("%s is null" % field).is_not_null()
		assert_bool(stream is AudioStreamOggVorbis).override_failure_message("%s is not Ogg Vorbis" % field).is_true()
		assert_float(stream.get_length()).override_failure_message("%s is under 8 s" % field).is_greater_equal(8.0)


func test_sources_log_records_every_stem_as_synthesized() -> void:
	var sources: String = FileAccess.get_file_as_string(SOURCES_PATH)
	for field: StringName in STEM_FIELDS:
		assert_str(sources).override_failure_message("%s not in SOURCES.md" % field).contains(String(field))
	assert_str(sources).contains("synthesized")


func test_audio_system_applies_the_real_map_to_the_controller_it_creates() -> void:
	var audio: AudioSystem = AudioSystem.new()
	add_child(audio)
	assert_bool(audio.music_ambient.is_stem_playing(MusicAmbientController.MusicState.CONTEMPLATIVE)).is_true()
	assert_bool(audio.music_ambient.is_ambient_base_playing()).is_true()
	remove_child(audio)
	audio.free()
