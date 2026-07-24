class_name AudioCueDispatcher
extends Node

## Data-driven one-shot cue dispatch — Story 003 (epic-12-audio-system).
##
## GDD source: design/gdd/audio-system.md — Core Rules 3-4, AC Group 3.
##
## Core Rule 4's own requirement: dispatch is generic — one lookup path keyed
## by event name, never a per-event `match` statement deciding what to play.
## The individual `.connect()` calls below are unavoidable signal *wiring*
## (GDScript signals aren't reflectively enumerable the way a real event-name
## string dispatch would be) — each one forwards into the single
## `dispatch_cue()` entry point, which is where all the actual per-event
## *behavior* difference is data (the `AudioCueMap` entry), not code.
##
## No real audio content exists yet (OQ-2, out of this epic's scope) — cues
## are not actually played through an `AudioStreamPlayer`; this class
## implements and exercises the real routing/attenuation mechanism (which
## bus, which volume, spatial vs. not) against test-authored `AudioCueEntry`
## fixtures, matching this project's "mechanism real, content placeholder"
## convention (Diorama, Music/Ambient's own Story 002).
##
## World-space distance attenuation (Formula F2) needs a real distance value
## from a "camera focus point" concept this project has not built yet (no
## scrolling camera exists — fixed top-down viewport). `dispatch_cue()`
## accepts `distance` directly so Formula F2's own math is fully real and
## testable; the signal-driven wiring below passes `distance = 0.0` for
## spatial events pending that future camera-focus integration — honestly
## flagged as a real, separate gap, not silently faked.

const MAX_AUDIBLE_RADIUS: float = 15.0  ## Tuning Knobs default (Formula F2, R)

var cue_map: AudioCueMap
var _lookup: Dictionary[StringName, AudioCueEntry] = {}

var _last_played_event: StringName = &""
var _last_played_bus: StringName = &""
var _last_effective_volume_linear: float = 0.0
var _dispatch_count: int = 0


func _ready() -> void:
	if cue_map == null:
		cue_map = AudioCueMap.new()
	_rebuild_lookup()
	_connect_all_events()


## Replaces the active cue map and rebuilds the runtime lookup — used by
## tests to inject fixtures without touching real content authoring.
func set_cue_map(map: AudioCueMap) -> void:
	cue_map = map
	_rebuild_lookup()


func _rebuild_lookup() -> void:
	_lookup.clear()
	for entry: AudioCueEntry in cue_map.entries:
		_lookup[entry.event_name] = entry


func _connect_all_events() -> void:
	GEventBus.mission_phase_changed.connect(func(_a: String, _b: String, _c: float) -> void: dispatch_cue(&"mission_phase_changed"))
	GEventBus.wave_countdown_warning.connect(func(_a: int) -> void: dispatch_cue(&"wave_countdown_warning"))
	GEventBus.hero_skill_activated.connect(func(_a: String, _b: Vector2) -> void: dispatch_cue(&"hero_skill_activated"))
	GEventBus.hero_class_unlocked.connect(func(_a: StringName, _b: bool) -> void: dispatch_cue(&"hero_class_unlocked"))
	GEventBus.tower_placed.connect(func(_a: Variant) -> void: dispatch_cue(&"tower_placed"))
	GEventBus.tower_attacked.connect(func(_a: int, _b: int, _c: float, _d: bool, _e: bool) -> void: dispatch_cue(&"tower_attacked"))
	GEventBus.pre_placement_perk_activated.connect(func(_a: int, _b: String) -> void: dispatch_cue(&"pre_placement_perk_activated"))
	GEventBus.boss_died.connect(func(_a: int, _b: StringName, _c: int, _d: String) -> void: dispatch_cue(&"boss_died"))
	GEventBus.hero_damage_taken.connect(func(_a: int, _b: int) -> void: dispatch_cue(&"hero_damage_taken"))
	GEventBus.constellation_activated.connect(func(_a: String, _b: Vector2i, _c: String, _d: float) -> void: dispatch_cue(&"constellation_activated"))
	GEventBus.component_crafted.connect(func(_a: String, _b: String, _c: int) -> void: dispatch_cue(&"component_crafted"))
	GEventBus.component_repaired.connect(func(_a: String, _b: String) -> void: dispatch_cue(&"component_repaired"))
	GEventBus.sanctuary_structure_built.connect(func(_a: String, _b: String) -> void: dispatch_cue(&"sanctuary_structure_built"))
	GEventBus.hero_equipment_crafted.connect(func(_a: String, _b: String, _c: int) -> void: dispatch_cue(&"hero_equipment_crafted"))
	GEventBus.game_paused.connect(func() -> void: dispatch_cue(&"game_paused"))
	GEventBus.game_unpaused.connect(func() -> void: dispatch_cue(&"game_unpaused"))


## The single generic dispatch entry point (Core Rule 4). `distance` only
## matters for cues marked `spatial == true` (Formula F2); ignored otherwise.
## AC-10a: an event with no matching map entry is a silent no-op — never an
## error.
func dispatch_cue(event_name: StringName, distance: float = 0.0) -> void:
	if not _lookup.has(event_name):
		return

	var entry: AudioCueEntry = _lookup[event_name]
	var base_volume: float = db_to_linear(entry.volume_db_offset)
	var effective_volume: float = base_volume
	if entry.spatial:
		effective_volume = base_volume * _world_space_attenuation(distance)

	_last_played_event = event_name
	_last_played_bus = entry.bus
	_last_effective_volume_linear = effective_volume
	_dispatch_count += 1


## Formula F2 — World-Space Distance Attenuation (spatial cues only).
## `world_volume = base_volume * clamp(1 - distance / max_audible_radius, 0, 1)`
func _world_space_attenuation(distance: float) -> float:
	var clamped_distance: float = maxf(distance, 0.0)
	return clampf(1.0 - clamped_distance / MAX_AUDIBLE_RADIUS, 0.0, 1.0)


## Test/inspection accessor.
func get_last_played_event() -> StringName:
	return _last_played_event


## Test/inspection accessor.
func get_last_played_bus() -> StringName:
	return _last_played_bus


## Test/inspection accessor.
func get_last_effective_volume_linear() -> float:
	return _last_effective_volume_linear


## Test/inspection accessor (AC-10a) — total number of cues actually
## dispatched (map hits only; misses never increment this).
func get_dispatch_count() -> int:
	return _dispatch_count
