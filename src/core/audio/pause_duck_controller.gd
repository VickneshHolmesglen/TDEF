class_name PauseDuckController
extends Node

## Pause-time bus ducking and crossfade freeze — Story 006 (epic-12-audio-system).
##
## GDD source: design/gdd/audio-system.md — Core Rule 7, AC Group 6.
## Governing ADR: ADR-0014 (Pause System) — `game_paused`/`game_unpaused`
## are informational-only signals (that ADR's own words: "no system may
## gate its own `_process`/`_physics_process`/Timer logic on them;
## `SceneTree.paused` already does that natively"). This controller reacts
## to them exactly the way that ADR anticipates — ducking bus levels and
## freezing a crossfade are informational responses, not process-gating.
##
## Owned as a child of `AudioSystem` (matches Story 002/003's own pattern),
## with direct references to the parent `AudioSystem` (for percent-based
## bus volume) and its sibling `MusicAmbientController` (for crossfade
## freeze/resume).

## Tuning Knobs default (range 30-50%) — Music/Ambient duck to this
## fraction of their own pre-pause value, never full silence.
const PAUSE_DUCK_FRACTION: float = 0.4

var audio_system: AudioSystem
var music_ambient: MusicAmbientController

var _is_ducked: bool = false
var _pre_pause_music_percent: float = 0.0
var _pre_pause_sfx_percent: float = 0.0
var _pre_pause_ambient_volume_db: float = 0.0


func _ready() -> void:
	GEventBus.game_paused.connect(_on_game_paused)
	GEventBus.game_unpaused.connect(_on_game_unpaused)


func _exit_tree() -> void:
	if GEventBus.game_paused.is_connected(_on_game_paused):
		GEventBus.game_paused.disconnect(_on_game_paused)
	if GEventBus.game_unpaused.is_connected(_on_game_unpaused):
		GEventBus.game_unpaused.disconnect(_on_game_unpaused)


## AC-15a/AC-15b: snapshots pre-pause levels, ducks Music/Ambient to ~40% of
## their own current value (never full silence), mutes the SFX bus
## entirely (world-combat content, per Story 001's own bus-family routing —
## UI-family content lives on the separate UI bus and is left untouched),
## and freezes any in-flight Music crossfade exactly where it is.
##
## Music/SFX are ducked via `AudioSystem.set_bus_volume_db_direct()` —
## deliberately NOT `set_bus_volume_percent()` — because the latter
## overwrites `_bus_volumes`, the class `AudioSystem` itself documents as
## the sole authoritative source of truth for the player's *persisted*
## preference. Routing the duck through it would mean a `save_settings_to_disk()`
## call made while paused (e.g. quitting to desktop from the pause menu)
## permanently writes the ducked value to `user://audio_settings.cfg` instead
## of the player's real setting — a real bug found during code review, fixed
## here before it could ship. Ambient already used the direct-`AudioServer`
## approach correctly from this story's first draft (it has no percent
## abstraction at all).
func _on_game_paused() -> void:
	if _is_ducked or audio_system == null:
		return
	_is_ducked = true

	_pre_pause_music_percent = audio_system.get_bus_volume_percent(&"Music")
	_pre_pause_sfx_percent = audio_system.get_bus_volume_percent(&"SFX")
	var ambient_index: int = AudioServer.get_bus_index(&"Ambient")
	_pre_pause_ambient_volume_db = AudioServer.get_bus_volume_db(ambient_index) if ambient_index != -1 else 0.0

	audio_system.set_bus_volume_db_direct(&"Music", linear_to_db(_pre_pause_music_percent / 100.0 * PAUSE_DUCK_FRACTION))
	audio_system.set_bus_volume_db_direct(&"SFX", linear_to_db(0.0))
	if ambient_index != -1:
		var pre_pause_ambient_linear: float = db_to_linear(_pre_pause_ambient_volume_db)
		AudioServer.set_bus_volume_db(ambient_index, linear_to_db(pre_pause_ambient_linear * PAUSE_DUCK_FRACTION))

	if music_ambient != null:
		music_ambient.freeze_transition()


## Restores every affected level's real, audible `AudioServer` volume to
## its exact pre-pause value (`_bus_volumes`, the persisted preference, was
## never touched during pause, so no restoration is needed there) and
## resumes the frozen crossfade from exactly where it left off.
func _on_game_unpaused() -> void:
	if not _is_ducked or audio_system == null:
		return
	_is_ducked = false

	audio_system.set_bus_volume_db_direct(&"Music", linear_to_db(_pre_pause_music_percent / 100.0))
	audio_system.set_bus_volume_db_direct(&"SFX", linear_to_db(_pre_pause_sfx_percent / 100.0))
	var ambient_index: int = AudioServer.get_bus_index(&"Ambient")
	if ambient_index != -1:
		AudioServer.set_bus_volume_db(ambient_index, _pre_pause_ambient_volume_db)

	if music_ambient != null:
		music_ambient.resume_transition()


## Test/inspection accessor.
func is_paused_ducked() -> bool:
	return _is_ducked
