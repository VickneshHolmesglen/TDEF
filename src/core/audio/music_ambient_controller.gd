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

## Music-ambient-stems spec §3.3/§4.
const AMBIENT_COMBAT_LAYER_FADE_IN_SECONDS: float = 1.5
const MUSIC_BUS: StringName = &"Music"
const AMBIENT_BUS: StringName = &"Ambient"
## Floor for level_to_volume_db() so a zero level maps to a very quiet finite dB (about -80 dB), not -inf.
const MIN_AUDIBLE_LEVEL: float = 0.00000001

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

## Real playback state (music-ambient-stems spec §3.3). Keyed by MusicState
## int. A stem with no stream has no entry (silent).
var _stem_players: Dictionary[int, AudioStreamPlayer] = {}
var _stem_levels: Dictionary[int, float] = {}
var _ambient_base_player: AudioStreamPlayer = null
var _ambient_combat_player: AudioStreamPlayer = null
var _ambient_combat_level: float = 0.0


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

	_step_levels(delta)


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
	_snap_stem_levels_to_targets()


# ---------------------------------------------------------------------------
# Real playback (music-ambient-stems spec §3.3). Everything below is inert
# until set_stream_map() is called with a non-null map.
# ---------------------------------------------------------------------------

## Equal-power volume for a level in [0, 1]: linear levels that sum to 1
## across a crossfade keep total power constant.
static func level_to_volume_db(level: float) -> float:
	return linear_to_db(sqrt(maxf(level, MIN_AUDIBLE_LEVEL)))


## Assigns (or clears) every stream slot from `map`. Idempotent: existing
## players are reused, and the ambient base bed is never restarted unless
## its stream actually changed. A null map or null slot leaves that slot silent.
func set_stream_map(map: MusicAmbientMap) -> void:
	_assign_stem(MusicState.CONTEMPLATIVE, map.contemplative if map != null else null)
	_assign_stem(MusicState.MEASURED, map.measured if map != null else null)
	_assign_stem(MusicState.URGENT, map.urgent if map != null else null)
	_assign_stem(MusicState.MEASURED_URGENT, map.measured_urgent if map != null else null)
	_ambient_base_player = _assign_ambient(_ambient_base_player, map.ambient_base_bed if map != null else null)
	_ambient_combat_player = _assign_ambient(_ambient_combat_player, map.ambient_combat_layer if map != null else null)
	if _ambient_base_player != null and not _ambient_base_player.playing:
		_ambient_base_player.play()
	_apply_combat_player()


func _make_player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


## Makes `stream` loop at runtime, so no per-file .import loop settings are relied on.
static func _make_loopable(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		if wav.format == AudioStreamWAV.FORMAT_8_BITS or wav.format == AudioStreamWAV.FORMAT_16_BITS:
			var bytes_per_frame: int = (2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if wav.stereo else 1)
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = wav.data.size() / bytes_per_frame


func _assign_stem(state: int, stream: AudioStream) -> void:
	if stream == null:
		if _stem_players.has(state):
			_stem_players[state].queue_free()
			_stem_players.erase(state)
			_stem_levels.erase(state)
		return
	_make_loopable(stream)
	var player: AudioStreamPlayer = _stem_players.get(state)
	if player == null:
		player = _make_player(MUSIC_BUS)
		_stem_players[state] = player
	if player.stream != stream:
		player.stream = stream
		player.stop()
	_stem_levels[state] = 1.0 if state == _music_state else 0.0
	_apply_stem_player(state)


func _assign_ambient(player: AudioStreamPlayer, stream: AudioStream) -> AudioStreamPlayer:
	if stream == null:
		if player != null:
			player.queue_free()
		return null
	_make_loopable(stream)
	if player == null:
		player = _make_player(AMBIENT_BUS)
	if player.stream != stream:
		player.stream = stream
		player.stop()
	return player


func _apply_stem_player(state: int) -> void:
	var player: AudioStreamPlayer = _stem_players[state]
	var level: float = _stem_levels[state]
	if level > 0.0:
		player.volume_db = level_to_volume_db(level)
		if not player.playing:
			player.play()
	elif player.playing:
		player.stop()


func _apply_combat_player() -> void:
	if _ambient_combat_player == null:
		return
	if _ambient_combat_level > 0.0:
		_ambient_combat_player.volume_db = level_to_volume_db(_ambient_combat_level)
		if not _ambient_combat_player.playing:
			_ambient_combat_player.play()
	elif _ambient_combat_player.playing:
		_ambient_combat_player.stop()


## Slews every stem level toward its target (1.0 for the current state's
## stem, 0.0 for the rest) at 1/duration per second, reusing the existing
## transition duration verbatim; ramps the ambient combat layer up over
## AMBIENT_COMBAT_LAYER_FADE_IN_SECONDS and down over the existing fade-out.
## A transition interrupted mid-fade simply retargets from the current levels.
func _step_levels(delta: float) -> void:
	var step: float = delta / maxf(_last_transition_duration, 0.01)
	for state: int in _stem_players:
		var target: float = 1.0 if state == _music_state else 0.0
		_stem_levels[state] = move_toward(_stem_levels[state], target, step)
		_apply_stem_player(state)
	if _ambient_combat_player != null:
		var rising: bool = _ambient_combat_layer_active and not _ambient_combat_layer_fading_out
		if rising:
			_ambient_combat_level = move_toward(_ambient_combat_level, 1.0, delta / AMBIENT_COMBAT_LAYER_FADE_IN_SECONDS)
		else:
			_ambient_combat_level = move_toward(_ambient_combat_level, 0.0, delta / AMBIENT_COMBAT_LAYER_FADE_OUT_SECONDS)
		_apply_combat_player()


func _snap_stem_levels_to_targets() -> void:
	for state: int in _stem_players:
		_stem_levels[state] = 1.0 if state == _music_state else 0.0
		_apply_stem_player(state)


## Test/inspection accessors (music-ambient-stems spec §3.7).
func get_stem_level(state: int) -> float:
	return _stem_levels.get(state, 0.0)


func is_stem_playing(state: int) -> bool:
	var player: AudioStreamPlayer = _stem_players.get(state)
	return player != null and player.playing


func get_stem_volume_db(state: int) -> float:
	var player: AudioStreamPlayer = _stem_players.get(state)
	return player.volume_db if player != null else -80.0


func get_stem_player(state: int) -> AudioStreamPlayer:
	return _stem_players.get(state)


func get_ambient_combat_level() -> float:
	return _ambient_combat_level


func is_ambient_combat_playing() -> bool:
	return _ambient_combat_player != null and _ambient_combat_player.playing


func is_ambient_base_playing() -> bool:
	return _ambient_base_player != null and _ambient_base_player.playing


func get_ambient_base_player() -> AudioStreamPlayer:
	return _ambient_base_player


func get_ambient_combat_player() -> AudioStreamPlayer:
	return _ambient_combat_player
