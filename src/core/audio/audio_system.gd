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


func _ready() -> void:
	_configure_buses()
	_load_settings_from_disk()
	if music_ambient == null:
		music_ambient = MusicAmbientController.new()
		music_ambient.name = &"MusicAmbientController"
	if music_ambient.get_parent() == null:
		add_child(music_ambient)
	if cue_dispatcher == null:
		cue_dispatcher = AudioCueDispatcher.new()
		cue_dispatcher.name = &"AudioCueDispatcher"
	if cue_dispatcher.get_parent() == null:
		add_child(cue_dispatcher)


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
