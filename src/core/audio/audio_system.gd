class_name AudioSystem
extends Node

## Audio System — Mix Bus Architecture (Story 001, epic-12-audio-system).
##
## GDD source: design/gdd/audio-system.md — Core Rule 1, AC Group 1.
## No dedicated ADR exists yet (matches Sanctuary UI/Tarot Deck UI's own
## precedent) — this story scopes directly from the GDD's own Core Rule 1.
##
## Constructs the real Godot `AudioServer` bus graph procedurally at
## `_ready()`, since this project has no authored `default_bus_layout.tres`
## (confirmed by search — only the engine's own built-in "Master" bus exists
## before this system runs). 4 player-facing buses (Music, SFX, Voice, UI)
## send to the engine's built-in Master bus; **Ambient** is a 5th, internal
## (non-player-facing) bus that sends to Music specifically, so it inherits
## Music's own volume automatically (GDD: "a true child bus under Music").
##
## Player-facing volume is a `[0, 100]` percentage (AC-1), not a raw dB
## value — this class is the sole owner of the percent-to-dB conversion
## (`linear_to_db(percent / 100.0)`), so nothing outside this file needs to
## reason about decibels. Percent state is tracked in `_bus_volumes` as the
## authoritative source of truth (not read back from `AudioServer`'s own dB
## storage), since repeated float dB<->linear round-trips would accumulate
## precision drift over many player adjustments.
##
## Idempotent bus creation: `_ready()` only adds a bus if a bus of that name
## doesn't already exist, so re-entering a scene (or, in tests, calling
## `_ready()`'s logic more than once against the same running process) never
## duplicates the graph. Matches this project's own "direct instantiation,
## no add_child()" unit-test convention (`AudioSystem.new()` never fires
## `_ready()`, so tests call `_configure_buses()` directly instead).
##
## Sidechain ducking application (2026-08-06, closes a real gap found while
## investigating a user-reported issue -- Formula F3's attack/hold/release
## envelope was fully implemented and unit-tested in `VoiceLimiter`, and
## `AudioCueDispatcher._process()` was already ticking it every frame, but
## nothing ever read the resulting `get_sidechain_db_offset()` and applied it
## to real `AudioServer` output -- the math ran correctly in total isolation
## from anything audible). `_process()` re-applies both relationships' current
## offset to their affected bus(es) every frame via `set_bus_volume_db_direct()`
## -- never `set_bus_volume_percent()`, same reasoning as `PauseDuckController`
## (a duck must never be mistaken for, or overwrite, the player's persisted
## volume preference). Deliberately does NOT own ticking the envelope itself
## (that stays exactly where `AudioCueDispatcher`'s own doc comment and its
## `test_dispatchers_own_process_actually_ticks_the_sidechain_envelope_over_a_
## real_frame` test already establish it) -- a one-node-processing-order frame
## of lag between tick and apply is imperceptible at these envelope timescales
## (10-400ms) and not worth entangling two already-separately-owned concerns.
## Known, undocumented minor edge case NOT solved here: `PauseDuckController`
## snapshots pre-pause volume from `_bus_volumes` (the percent preference)
## only, not any sidechain offset active at the instant of pause -- both
## freeze correctly while paused (`PROCESS_MODE_INHERIT`), but a sidechain
## duck active right as pause begins is not accounted for in the pre-pause
## snapshot. Not in Formula F3's or Core Rule 7's Edge Cases, not invented
## here -- flagged honestly rather than silently glossed over.

## The 4 player-facing buses (Core Rule 1) — order matches the GDD's own
## listing. Voice is reserved/silent today (no VO content exists or is
## planned at MVP/Alpha scope, OQ-6) but must still exist and be settable.
const PLAYER_BUSES: Array[StringName] = [&"Music", &"SFX", &"Voice", &"UI"]

## Internal, non-player-facing bus — sends to Music specifically, inheriting
## its volume automatically. Not in PLAYER_BUSES; not independently settable
## by the player (GDD: "a real node in the bus graph, inheriting Music's
## volume automatically", not a 5th slider).
const AMBIENT_BUS: StringName = &"Ambient"

const DEFAULT_VOLUME_PERCENT: float = 80.0

## Story 005: volume is a device/session preference, not per-save-slot
## progress — it lives in its own small `ConfigFile`, entirely outside
## `GSavePersistence`/`SaveRestorer` (Core Rule 6's own explicit boundary,
## enforced by this class simply never registering with that system).
const AUDIO_SETTINGS_PATH: String = "user://audio_settings.cfg"
const AUDIO_SETTINGS_SECTION: String = "buses"

## Music/ambient stem map (music-ambient-stems spec §3.2). Loaded here, not
## by MusicAmbientController, so controller tests stay content-free. Missing
## file = silent, as before.
const MUSIC_AMBIENT_MAP_PATH: String = "res://assets/data/audio/music_ambient_map.tres"

## Authoritative percent-volume state per player-facing bus, `[0, 100]`.
## AudioServer's own bus volume_db is a derived effect of this, never the
## other way around.
var _bus_volumes: Dictionary[StringName, float] = {}

## Story 002: the Music/Ambient state machine. Owned here (not a separate
## Autoload) since the GDD frames bus management and music-cue state as one
## architectural module ("Audio System").
var music_ambient: MusicAmbientController

## Story 003: the data-driven one-shot cue dispatcher.
var cue_dispatcher: AudioCueDispatcher

## Story 006: pause-time bus ducking and crossfade freeze.
var pause_duck: PauseDuckController


func _ready() -> void:
	_configure_buses()
	_load_settings_from_disk()
	var created_music_ambient: bool = false
	if music_ambient == null:
		music_ambient = MusicAmbientController.new()
		music_ambient.name = &"MusicAmbientController"
		created_music_ambient = true
	if music_ambient.get_parent() == null:
		add_child(music_ambient)
	if created_music_ambient and ResourceLoader.exists(MUSIC_AMBIENT_MAP_PATH):
		music_ambient.set_stream_map(load(MUSIC_AMBIENT_MAP_PATH) as MusicAmbientMap)
	if cue_dispatcher == null:
		cue_dispatcher = AudioCueDispatcher.new()
		cue_dispatcher.name = &"AudioCueDispatcher"
	if cue_dispatcher.get_parent() == null:
		add_child(cue_dispatcher)
	if pause_duck == null:
		pause_duck = PauseDuckController.new()
		pause_duck.name = &"PauseDuckController"
	pause_duck.audio_system = self
	pause_duck.music_ambient = music_ambient
	if pause_duck.get_parent() == null:
		add_child(pause_duck)


## Naturally stops running while `get_tree().paused` is true
## (`PROCESS_MODE_INHERIT`, this project's standard pause convention) --
## matches `AudioCueDispatcher._process()`'s own envelope-tick freeze, so the
## two never fight over the same bus during pause.
func _process(_delta: float) -> void:
	_apply_sidechain_ducking()


func _apply_sidechain_ducking() -> void:
	if cue_dispatcher == null:
		return
	var vl: VoiceLimiter = cue_dispatcher.voice_limiter
	var ui_offset_db: float = vl.get_sidechain_db_offset(VoiceLimiter.UI_TO_MUSIC_AND_SFX)
	var sfx_offset_db: float = vl.get_sidechain_db_offset(VoiceLimiter.SFX_TO_AMBIENT)

	set_bus_volume_db_direct(&"Music", linear_to_db(get_bus_volume_percent(&"Music") / 100.0) + ui_offset_db)
	set_bus_volume_db_direct(&"SFX", linear_to_db(get_bus_volume_percent(&"SFX") / 100.0) + ui_offset_db)

	# Ambient has no player-facing percent (class doc comment) -- its own
	# resting dB is always 0.0 (unity gain), it inherits Music's volume
	# purely through the bus send graph, not a matching dB value.
	var ambient_index: int = AudioServer.get_bus_index(AMBIENT_BUS)
	if ambient_index != -1:
		AudioServer.set_bus_volume_db(ambient_index, sfx_offset_db)


## Builds the bus graph if it doesn't already exist, and applies the
## default volume to every player-facing bus. Safe to call more than once —
## `_ensure_bus_exists()` is a no-op for a bus that's already there.
func _configure_buses() -> void:
	for bus_name: StringName in PLAYER_BUSES:
		_ensure_bus_exists(bus_name, &"Master")
		if not _bus_volumes.has(bus_name):
			_bus_volumes[bus_name] = DEFAULT_VOLUME_PERCENT
		_apply_volume_to_server(bus_name)
	_ensure_bus_exists(AMBIENT_BUS, &"Music")


## Creates `bus_name` sending to `send_to_bus` if no bus of that name exists
## yet. `send_to_bus` must already exist (Master always does; Music must be
## created before Ambient — `_configure_buses()`'s own call order guarantees
## this).
func _ensure_bus_exists(bus_name: StringName, send_to_bus: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var index: int = AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, send_to_bus)


func _apply_volume_to_server(bus_name: StringName) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	var percent: float = _bus_volumes.get(bus_name, DEFAULT_VOLUME_PERCENT)
	AudioServer.set_bus_volume_db(index, linear_to_db(percent / 100.0))


## AC-1: sets `bus_name`'s player-facing volume, `[0, 100]`. Out-of-range
## values are clamped, never rejected outright — matches this project's own
## "no validation-blocking on tuning-style inputs" convention (e.g.
## Mission Select's `set_difficulty_tier()`).
func set_bus_volume_percent(bus_name: StringName, percent: float) -> void:
	if not PLAYER_BUSES.has(bus_name):
		push_error("AudioSystem: '%s' is not a player-facing bus." % bus_name)
		return
	_bus_volumes[bus_name] = clampf(percent, 0.0, 100.0)
	_apply_volume_to_server(bus_name)


## AC-1/AC-2: returns `bus_name`'s current player-facing volume, `[0, 100]`.
## Reads this class's own authoritative state, never `AudioServer`'s derived
## dB value (see class doc comment).
func get_bus_volume_percent(bus_name: StringName) -> float:
	return _bus_volumes.get(bus_name, DEFAULT_VOLUME_PERCENT)


## Test/inspection accessor — confirms the real bus graph was actually
## constructed (name + parent-send routing), not merely that this class's
## own `_bus_volumes` dictionary looks right.
func bus_exists(bus_name: StringName) -> bool:
	return AudioServer.get_bus_index(bus_name) != -1


## Test/inspection accessor — the real `AudioServer` bus a given bus name
## currently sends to, or `&""` if the bus doesn't exist.
func get_bus_send(bus_name: StringName) -> StringName:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index == -1:
		return &""
	return AudioServer.get_bus_send(index)


## Story 006: sets `bus_name`'s real, currently-audible `AudioServer` volume
## directly, **without** touching `_bus_volumes` (the authoritative
## persisted-preference state). Exists specifically so `PauseDuckController`
## can duck Music/SFX during pause without corrupting the player's real
## volume preference — if `save_settings_to_disk()` ran while paused and
## ducking had gone through `set_bus_volume_percent()` instead, the ducked
## (not the real) value would be permanently written to
## `user://audio_settings.cfg`. No-op if `bus_name` doesn't exist.
func set_bus_volume_db_direct(bus_name: StringName, volume_db: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index != -1:
		AudioServer.set_bus_volume_db(index, volume_db)


## Test/inspection accessor — the real, currently-audible `AudioServer`
## volume for `bus_name`, as a `[0, 100]` percent. Unlike
## `get_bus_volume_percent()` (which reads the authoritative persisted
## preference, unaffected by pause-ducking), this reflects whatever is
## actually audible right now — the two intentionally diverge while paused.
func get_bus_volume_db_direct(bus_name: StringName) -> float:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index == -1:
		return 0.0
	return AudioServer.get_bus_volume_db(index)


## Story 005, AC-13/Fresh-install default: loads saved volumes from
## `user://audio_settings.cfg` if it exists, overriding Story 001's in-memory
## 80% defaults. A missing file (fresh install) is not an error — the
## existing in-memory defaults are simply left as-is.
func _load_settings_from_disk() -> void:
	var config := ConfigFile.new()
	var err: Error = config.load(AUDIO_SETTINGS_PATH)
	if err != OK:
		return
	for bus_name: StringName in PLAYER_BUSES:
		if config.has_section_key(AUDIO_SETTINGS_SECTION, bus_name):
			var percent: float = config.get_value(AUDIO_SETTINGS_SECTION, bus_name, DEFAULT_VOLUME_PERCENT)
			set_bus_volume_percent(bus_name, percent)


## Story 005: persists the current 4 player-facing bus volumes to
## `user://audio_settings.cfg`. Never registered with `GSavePersistence` —
## this is the entire point of Core Rule 6 (a device/session preference,
## not per-save-slot progress).
func save_settings_to_disk() -> Error:
	var config := ConfigFile.new()
	for bus_name: StringName in PLAYER_BUSES:
		config.set_value(AUDIO_SETTINGS_SECTION, bus_name, get_bus_volume_percent(bus_name))
	return config.save(AUDIO_SETTINGS_PATH)
