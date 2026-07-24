class_name MusicAmbientController
extends Node

## Music/Ambient state machine — Story 002 (epic-12-audio-system).
##
## GDD source: design/gdd/audio-system.md — Core Rule 2, States and
## Transitions table, AC Group 2. No dedicated ADR exists yet (matches
## Story 001's own precedent).
##
## Owns 4 Music Energy levels (`Contemplative`/`Measured`/`Urgent`/
## `Measured-urgent`) driven by `GEventBus.mission_phase_changed` and
## `GEventBus.wave_countdown_warning`. No audio asset exists yet to actually
## play (matches this project's "no art/content yet" convention: Diorama's
## ColorRects, Tarot's plain-text tags), but the timing/state mechanism
## itself is fully real and live-verifiable, not a stub.
##
## Crossfade/duck timing is a manually-tracked countdown driven by
## `advance_time()` (real per-frame `_process(delta)` calls in production;
## tests call it directly with explicit deltas, per this project's own
## "no time-dependent assertions" standard) rather than a `Tween` — this is
## a deliberate choice over the Story 002-original `Tween`-based design:
## Story 006 (Pause Behavior) needs a *freeze* that genuinely stops time
## from advancing, and `Tween.custom_step()` explicitly ignores a tween's
## own paused state (per Godot's own docs, it's a manual override for
## testing/scrubbing) — making a real, testable freeze impossible on top of
## it. A plain countdown that `advance_time()` only decrements while
## `_paused == false` is freeze-able for real and remains just as
## deterministically testable.
##
## No new Autoload is introduced — this is instantiated and added as a child
## by `AudioSystem._ready()`, matching the GDD's own single "Audio System"
## architectural module (bus management + music-cue state under one roof).

## AC-3: the SCOUT->WAVE_ACTIVE anticipatory crossfade's scheduled duration
## equals the `wave_countdown_warning` signal's own `seconds_remaining` value
## at the moment it fires — this makes the crossfade's completion time
## exactly match the countdown reaching 0, satisfying this story's own QA
## Test Case for AC-3 ("scheduled completion time equals the countdown's own
## remaining-time-to-zero") literally. The GDD's separate "3.5s Tuning Knob
## default" describes the expected real-world value once real wave-timing
## content exists and the 10-second warning point is tuned to typically
## start the audible fade ~3.5s before zero — that tuning is out of this
## story's scope (no real content to tune against yet); this session
## implements the general mechanism the QA spec actually describes.
const WAVE_ACTIVE_TO_INTERMISSION_DUCK_SECONDS: float = 0.4

const AMBIENT_COMBAT_LAYER_FADE_OUT_SECONDS: float = 2.0

enum MusicState { CONTEMPLATIVE, MEASURED, URGENT, MEASURED_URGENT }

var _music_state: MusicState = MusicState.CONTEMPLATIVE

## AC-5 support: the position/state of the currently-playing stem, tracked
## as an opaque counter that only advances on a genuine crossfade/cut, never
## on a same-phase retrigger.
var _stem_epoch: int = 0

var _transitioning: bool = false
var _crossfade_remaining_seconds: float = 0.0
var _last_transition_duration: float = 0.0
var _last_transition_was_hard_cut: bool = false

## AC-6: the Ambient base bed is created exactly once and never touched
## again — this counter proves that (should never exceed 1).
var _ambient_base_bed_start_count: int = 0
var _ambient_combat_layer_active: bool = false
var _ambient_combat_layer_fading_out: bool = false
var _ambient_combat_layer_fade_out_remaining_seconds: float = 0.0

## Story 006 (Pause Behavior): while true, `advance_time()` is a no-op — any
## in-flight transition/fade freezes exactly where it is, per
## `design/accessibility-requirements.md`'s "pausable at any frame, no
## penalty" commitment.
var _paused: bool = false


func _ready() -> void:
	GEventBus.mission_phase_changed.connect(_on_mission_phase_changed)
	GEventBus.wave_countdown_warning.connect(_on_wave_countdown_warning)
	_ambient_base_bed_start_count += 1


func _exit_tree() -> void:
	if GEventBus.mission_phase_changed.is_connected(_on_mission_phase_changed):
		GEventBus.mission_phase_changed.disconnect(_on_mission_phase_changed)
	if GEventBus.wave_countdown_warning.is_connected(_on_wave_countdown_warning):
		GEventBus.wave_countdown_warning.disconnect(_on_wave_countdown_warning)


func _process(delta: float) -> void:
	advance_time(delta)


## The single place time actually elapses for this controller's in-flight
## transition/fade. Production code reaches this via `_process()`; tests
## call it directly with explicit deltas (deterministic, no real waits).
## A no-op while `_paused` (Story 006's freeze).
func advance_time(delta: float) -> void:
	if _paused:
		return

	if _transitioning:
		_crossfade_remaining_seconds -= delta
		if _crossfade_remaining_seconds <= 0.0:
			_transitioning = false
			_crossfade_remaining_seconds = 0.0

	if _ambient_combat_layer_fading_out:
		_ambient_combat_layer_fade_out_remaining_seconds -= delta
		if _ambient_combat_layer_fade_out_remaining_seconds <= 0.0:
			_ambient_combat_layer_fading_out = false
			_ambient_combat_layer_fade_out_remaining_seconds = 0.0
			_ambient_combat_layer_active = false


## AC-5: identical previous/new phase never retriggers anything.
func _on_mission_phase_changed(previous_phase: String, new_phase: String, _timestamp: float) -> void:
	if previous_phase == new_phase:
		return

	match new_phase:
		"SANCTUARY", "MISSION_COMPLETE", "DEFEAT":
			_ambient_combat_layer_active = false
			_ambient_combat_layer_fading_out = false
			_begin_crossfade(MusicState.CONTEMPLATIVE, 1.0)
		"SCOUT":
			_begin_crossfade(MusicState.MEASURED, 1.0)
		"WAVE_ACTIVE":
			if _music_state != MusicState.URGENT:
				_begin_crossfade(MusicState.URGENT, 1.0)
			elif _transitioning:
				# Resync fallback (Edge Cases/OQ-9): the anticipatory
				# crossfade from the countdown warning already resolved
				# the logical state to URGENT -- snap the in-flight fade
				# to completion immediately rather than letting it play out.
				_transitioning = false
				_crossfade_remaining_seconds = 0.0
			_ambient_combat_layer_active = true
			_ambient_combat_layer_fading_out = false
		"INTERMISSION":
			_begin_hard_duck(MusicState.MEASURED_URGENT, WAVE_ACTIVE_TO_INTERMISSION_DUCK_SECONDS)
			_ambient_combat_layer_fading_out = true
			_ambient_combat_layer_fade_out_remaining_seconds = AMBIENT_COMBAT_LAYER_FADE_OUT_SECONDS


## AC-3: begins the SCOUT->WAVE_ACTIVE anticipatory crossfade, scheduled to
## finish exactly when the countdown reaches 0.
func _on_wave_countdown_warning(seconds_remaining: int) -> void:
	if _music_state != MusicState.MEASURED:
		return
	_begin_crossfade(MusicState.URGENT, maxf(float(seconds_remaining), 0.01))


func _begin_crossfade(target_state: MusicState, duration: float) -> void:
	_last_transition_was_hard_cut = false
	_last_transition_duration = duration
	_stem_epoch += 1
	_music_state = target_state
	_transitioning = true
	_crossfade_remaining_seconds = duration


## AC-4: the WAVE_ACTIVE -> INTERMISSION relief transition — a fast duck/cut
## under the Tuning Knobs' 0.2-0.5s window, never a multi-second crossfade.
func _begin_hard_duck(target_state: MusicState, duration: float) -> void:
	_last_transition_was_hard_cut = true
	_last_transition_duration = duration
	_stem_epoch += 1
	_music_state = target_state
	_transitioning = true
	_crossfade_remaining_seconds = duration


## Test/inspection accessor.
func get_music_state() -> MusicState:
	return _music_state


## Test/inspection accessor — true while a crossfade or duck/cut is in flight.
func is_transitioning() -> bool:
	return _transitioning


## Test/inspection accessor — the duration of the most recently *scheduled*
## transition (crossfade or duck/cut), whether or not it has finished yet.
func get_last_transition_duration() -> float:
	return _last_transition_duration


## Test/inspection accessor — true if the most recently scheduled transition
## was the WAVE_ACTIVE->INTERMISSION hard duck/cut, false if it was a
## standard crossfade.
func get_last_transition_was_hard_cut() -> bool:
	return _last_transition_was_hard_cut


## Test/inspection accessor (AC-5) — increments on every genuine
## crossfade/cut, never on a same-phase retrigger.
func get_stem_epoch() -> int:
	return _stem_epoch


## Test/inspection accessor (AC-6) — must never exceed 1 across any number
## of state transitions; the Ambient base bed is created once and never
## restarted.
func get_ambient_base_bed_start_count() -> int:
	return _ambient_base_bed_start_count


## Test/inspection accessor.
func is_ambient_combat_layer_active() -> bool:
	return _ambient_combat_layer_active


## Test/inspection accessor.
func is_ambient_combat_layer_fading_out() -> bool:
	return _ambient_combat_layer_fading_out


## Test/inspection accessor (Story 006, AC-15a) — seconds remaining on the
## in-flight transition, frozen exactly in place while paused.
func get_crossfade_remaining_seconds() -> float:
	return _crossfade_remaining_seconds


## Story 006 (Pause Behavior), AC-15a: freezes any in-flight transition/fade
## exactly where it is — `advance_time()` becomes a no-op until resumed.
func freeze_transition() -> void:
	_paused = true


## Story 006 (Pause Behavior), AC-15a: resumes exactly where freeze left off.
func resume_transition() -> void:
	_paused = false


## Test/inspection accessor.
func is_frozen() -> bool:
	return _paused


## Test seam — forces the in-flight transition to complete immediately
## without waiting real time, so tests can assert post-transition state
## deterministically (this project's tests avoid time-dependent assertions
## per `.claude/rules/test-standards.md`). Unlike `advance_time()`, this
## deliberately ignores `_paused` — it is a hard test-only override, not a
## simulation of real elapsed time.
func force_finish_transition() -> void:
	_transitioning = false
	_crossfade_remaining_seconds = 0.0
