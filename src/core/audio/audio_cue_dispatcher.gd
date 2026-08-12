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

## Story 004 (Ducking and Voice Limiting): registers a voice against its
## family's cap on every dispatch. Wiring this into the live dispatch path
## was deliberately deferred by Story 004's own Definition of Done (Story
## 003 owns triggering a cue; Story 004 only owns what happens once a
## family is at/beyond capacity) — this closes that documented follow-up.
var voice_limiter: VoiceLimiter = VoiceLimiter.new()

var _last_played_event: StringName = &""
var _last_played_bus: StringName = &""
var _last_effective_volume_linear: float = 0.0
var _dispatch_count: int = 0
var _last_dispatch_voice_id: int = -1

## Stored so `_exit_tree()` can actually disconnect the anonymous lambdas
## `_connect_all_events()` wires below — a bare `.connect(func...)` call has
## no reference to disconnect later, which would silently violate this
## project's own EventBus Rule 6 ("every subscriber MUST disconnect in
## `_exit_tree()`") the moment this node is ever created/freed outside the
## permanent Autoload tree (e.g. in a future test or refactor).
var _connected_signals: Array[Signal] = []
var _connected_callables: Array[Callable] = []


func _ready() -> void:
	if cue_map == null:
		cue_map = AudioCueMap.new()
	_rebuild_lookup()
	_connect_all_events()


## Ticks Formula F3's sidechain duck envelopes once per frame. Uses this
## project's default `PROCESS_MODE_INHERIT` — while `get_tree().paused` is
## true (`PauseMenu`'s own mechanism), this simply stops being called, which
## is exactly Core Rule 7's "freeze exactly where it is" requirement with no
## bespoke pause-handling needed here.
func _process(delta: float) -> void:
	voice_limiter.tick_sidechain(delta)


func _exit_tree() -> void:
	for i in range(_connected_signals.size()):
		if _connected_signals[i].is_connected(_connected_callables[i]):
			_connected_signals[i].disconnect(_connected_callables[i])
	_connected_signals.clear()
	_connected_callables.clear()


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
	if not _connected_signals.is_empty():
		return
	_wire(GEventBus.mission_phase_changed, func(_a: String, _b: String, _c: float) -> void: dispatch_cue(&"mission_phase_changed"))
	_wire(GEventBus.wave_countdown_warning, func(_a: int) -> void: dispatch_cue(&"wave_countdown_warning"))
	_wire(GEventBus.hero_skill_activated, func(_a: String, _b: Vector2) -> void: dispatch_cue(&"hero_skill_activated"))
	_wire(GEventBus.hero_class_unlocked, func(_a: StringName, _b: bool) -> void: dispatch_cue(&"hero_class_unlocked"))
	_wire(GEventBus.tower_placed, func(_a: Variant) -> void: dispatch_cue(&"tower_placed"))
	_wire(GEventBus.tower_attacked, func(_a: int, _b: int, _c: float, _d: bool, _e: bool) -> void: dispatch_cue(&"tower_attacked"))
	_wire(GEventBus.pre_placement_perk_activated, func(_a: int, _b: String) -> void: dispatch_cue(&"pre_placement_perk_activated"))
	_wire(GEventBus.boss_died, func(_a: int, _b: StringName, _c: int, _d: String) -> void: dispatch_cue(&"boss_died"))
	_wire(GEventBus.hero_damage_taken, func(_a: int, _b: int) -> void: dispatch_cue(&"hero_damage_taken"))
	_wire(GEventBus.constellation_activated, func(_a: String, _b: Vector2i, _c: String, _d: float) -> void: dispatch_cue(&"constellation_activated"))
	_wire(GEventBus.component_crafted, func(_a: String, _b: String, _c: int) -> void: dispatch_cue(&"component_crafted"))
	_wire(GEventBus.component_repaired, func(_a: String, _b: String) -> void: dispatch_cue(&"component_repaired"))
	_wire(GEventBus.sanctuary_structure_built, func(_a: String, _b: String) -> void: dispatch_cue(&"sanctuary_structure_built"))
	_wire(GEventBus.hero_equipment_crafted, func(_a: String, _b: String, _c: int) -> void: dispatch_cue(&"hero_equipment_crafted"))
	# Story 004 (TR-buildupgrade-004, Rule 6a, AC-9): reuses this exact
	# generic-dispatch mechanism rather than adding chime logic inside
	# BuildingUpgrade.resolve_upgrade() -- Rule 6's "emits and does nothing
	# further" contract means the purchase-confirmation cue belongs entirely
	# to whoever already owns generic EventBus->audio dispatch, matching how
	# sanctuary_structure_built (the closest sibling, Defense Building's own
	# tech-node-unlock feedback) is wired the exact same way one line above.
	# AC-10a's own no-op-if-unmapped guarantee means this is safe to wire
	# even before a real "structure_upgraded" AudioCueMap entry is authored.
	_wire(GEventBus.structure_upgraded, func(_a: String, _b: String) -> void: dispatch_cue(&"structure_upgraded"))
	_wire(GEventBus.game_paused, func() -> void: dispatch_cue(&"game_paused"))
	_wire(GEventBus.game_unpaused, func() -> void: dispatch_cue(&"game_unpaused"))


func _wire(event_signal: Signal, callable: Callable) -> void:
	event_signal.connect(callable)
	_connected_signals.append(event_signal)
	_connected_callables.append(callable)


## The single generic dispatch entry point (Core Rule 4). `distance` only
## matters for cues marked `spatial == true` (Formula F2); ignored otherwise.
## AC-10a: an event with no matching map entry is a silent no-op — never an
## error. Cues with a `polyphony_group` also get Formula F1's concurrent-cue
## ducking applied, evaluated against the bus-wide voice count *after* this
## dispatch's own voice is registered (Formula F1's `N` is defined as
## "including this one"). Every dispatch also registers a Formula F3
## sidechain trigger against whichever cross-bus relationship its `bus`
## qualifies for (`&"SFX"` -> SFX_TO_AMBIENT, `&"UI"` -> UI_TO_MUSIC_AND_SFX)
## — the actual duck envelope is ticked separately, once per frame, by
## `_process()`.
func dispatch_cue(event_name: StringName, distance: float = 0.0) -> void:
	if not _lookup.has(event_name):
		return

	var entry: AudioCueEntry = _lookup[event_name]
	var base_volume: float = db_to_linear(entry.volume_db_offset)
	var effective_volume: float = base_volume
	if entry.spatial:
		effective_volume = base_volume * _world_space_attenuation(distance)

	_last_dispatch_voice_id = -1
	if entry.polyphony_group != &"":
		_last_dispatch_voice_id = voice_limiter.trigger_voice(entry.polyphony_group)
		var total_active_voices: int = voice_limiter.get_total_active_voice_count()
		effective_volume = VoiceLimiter.compute_ducked_volume(effective_volume, total_active_voices)

	if entry.bus == &"SFX":
		voice_limiter.trigger_sidechain(VoiceLimiter.SFX_TO_AMBIENT)
	elif entry.bus == &"UI":
		voice_limiter.trigger_sidechain(VoiceLimiter.UI_TO_MUSIC_AND_SFX)

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


## Test/inspection accessor (Story 004 wiring) — the voice ID
## `voice_limiter` assigned to the most recent dispatch, or -1 if that
## dispatch's entry had no `polyphony_group` (or was a lookup miss).
func get_last_dispatch_voice_id() -> int:
	return _last_dispatch_voice_id
