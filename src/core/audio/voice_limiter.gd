class_name VoiceLimiter
extends RefCounted

## Per-family voice caps, oldest-voice stealing, and bus-wide concurrent-cue
## ducking — Story 004 (epic-12-audio-system).
##
## GDD source: design/gdd/audio-system.md — Core Rule 5, Formula F1, AC Group 4.
##
## Direct-instantiation Logic class (`.new()`, no `add_child()` needed —
## matches this project's Story 001 convention), since voice bookkeeping is
## pure state/math with no scene-tree or EventBus dependency of its own.
## `AudioCueDispatcher` (Story 003) is the caller that invokes
## `trigger_voice()` per dispatched cue — wiring that call is this story's
## own natural follow-up, not duplicated here to keep this class narrowly
## testable in isolation.

## Tuning Knobs defaults (design/gdd/audio-system.md). 4 of these 6 are
## explicitly flagged as placeholders pending real content (OQ-8) — the
## mechanism below is generic against whatever cap is configured per
## family, not hardcoded to only Combat Impact/Discovery Fanfare.
const DEFAULT_FAMILY_CAPS: Dictionary[StringName, int] = {
	&"discovery_fanfare": 1,
	&"progress_blip": 4,
	&"denial_rejection": 3,
	&"activation_confirm": 4,
	&"ui_confirm_cancel": 6,
	&"combat_impact": 12,
	&"hero_death": 2,
}

const DUCK_COEFFICIENT: float = 0.05  ## Formula F1's `k`
const DUCK_FLOOR: float = 0.3  ## Formula F1's `D_floor`

## Sidechain ducking (Core Rule 5) — a separate, cross-bus mechanism from
## Formula F1 (which operates *within* the SFX bus across its own voices).
const SFX_TO_AMBIENT_DUCK_DB: float = -6.0
const UI_TO_MUSIC_AND_SFX_DUCK_DB: float = -4.0

## Formula F3 (design/quick-specs/sidechain-ducking-timing-2026-07-31.md) —
## attack/hold/release envelope timing for the 2 sidechain duck relationships
## above. Each relationship runs an independent ATTACKING -> HELD -> RELEASING
## state machine; a retrigger while already ducked resets the hold countdown
## rather than re-running the attack ramp (the anti-"pumping" rule).
const SFX_TO_AMBIENT: StringName = &"sfx_to_ambient"
const UI_TO_MUSIC_AND_SFX: StringName = &"ui_to_music_and_sfx"

const SFX_TO_AMBIENT_ATTACK_TIME: float = 0.015
const SFX_TO_AMBIENT_RELEASE_DELAY: float = 0.15
const SFX_TO_AMBIENT_RELEASE_TIME: float = 0.25

const UI_TO_MUSIC_AND_SFX_ATTACK_TIME: float = 0.01
const UI_TO_MUSIC_AND_SFX_RELEASE_DELAY: float = 0.08
const UI_TO_MUSIC_AND_SFX_RELEASE_TIME: float = 0.18

enum SidechainState { RESTING, ATTACKING, HELD, RELEASING }

## Per-relationship duck amount / attack / release-delay / release-time,
## looked up by the two StringName keys above — keeps the state machine
## below generic against either relationship rather than duplicating it.
const _SIDECHAIN_CONFIG: Dictionary[StringName, Dictionary] = {
	&"sfx_to_ambient": {
		"duck_db": SFX_TO_AMBIENT_DUCK_DB,
		"attack_time": SFX_TO_AMBIENT_ATTACK_TIME,
		"release_delay": SFX_TO_AMBIENT_RELEASE_DELAY,
		"release_time": SFX_TO_AMBIENT_RELEASE_TIME,
	},
	&"ui_to_music_and_sfx": {
		"duck_db": UI_TO_MUSIC_AND_SFX_DUCK_DB,
		"attack_time": UI_TO_MUSIC_AND_SFX_ATTACK_TIME,
		"release_delay": UI_TO_MUSIC_AND_SFX_RELEASE_DELAY,
		"release_time": UI_TO_MUSIC_AND_SFX_RELEASE_TIME,
	},
}

var _family_caps: Dictionary[StringName, int] = DEFAULT_FAMILY_CAPS.duplicate()

var _sidechain_state: Dictionary[StringName, SidechainState] = {
	&"sfx_to_ambient": SidechainState.RESTING,
	&"ui_to_music_and_sfx": SidechainState.RESTING,
}
var _sidechain_db_offset: Dictionary[StringName, float] = {
	&"sfx_to_ambient": 0.0,
	&"ui_to_music_and_sfx": 0.0,
}
var _sidechain_phase_elapsed: Dictionary[StringName, float] = {
	&"sfx_to_ambient": 0.0,
	&"ui_to_music_and_sfx": 0.0,
}
var _sidechain_phase_start_db: Dictionary[StringName, float] = {
	&"sfx_to_ambient": 0.0,
	&"ui_to_music_and_sfx": 0.0,
}
var _sidechain_release_timer: Dictionary[StringName, float] = {
	&"sfx_to_ambient": 0.0,
	&"ui_to_music_and_sfx": 0.0,
}

## Per family: an Array[int] of active voice IDs, oldest first (index 0).
## Dictionary values stay plain `Array` (not `Array[int]`) -- nested typed
## generics (`Dictionary[K, Array[V]]`) do not parse on this project's
## pinned Godot 4.6.2 (confirmed: `Dictionary[StringName, Array[int]]`
## throws a parser error at load). Individual local variables below are
## still typed `Array[int]` where the engine does support it.
var _active_voices: Dictionary[StringName, Array] = {}

var _next_voice_id: int = 0
var _last_stolen_voice_id: int = -1


## Overrides a family's cap (e.g. for tests, or once OQ-8's placeholders are
## replaced with tuned real values).
func set_family_cap(family: StringName, cap: int) -> void:
	_family_caps[family] = cap


func get_family_cap(family: StringName) -> int:
	return _family_caps.get(family, -1)


## AC-11: registers a new voice trigger for `family`. If the family is
## already at its cap, the oldest-started voice is stolen (stopped) and
## replaced — the new trigger always gets a voice; it is never dropped.
## Returns the new voice's ID.
func trigger_voice(family: StringName) -> int:
	if not _active_voices.has(family):
		_active_voices[family] = []
	var voices: Array = _active_voices[family]

	_last_stolen_voice_id = -1
	var cap: int = _family_caps.get(family, -1)
	# Real bug found during /code-review (2026-08-13): a family cap of 0
	# (a plausible future OQ-8 tuning value, meaning "fully muted") made
	# voices.size() (0) >= cap (0) true on the very first trigger, calling
	# pop_front() on an empty array -- returns null, which crashes assigning
	# to this statically-typed int field. Not empty guards against this.
	if cap >= 0 and voices.size() >= cap and not voices.is_empty():
		_last_stolen_voice_id = voices.pop_front()

	_next_voice_id += 1
	voices.append(_next_voice_id)
	return _next_voice_id


## Marks `voice_id` as finished (e.g. the underlying player stopped
## naturally) — removes it from its family's active list. No-op if the
## voice was already stolen/removed.
func release_voice(family: StringName, voice_id: int) -> void:
	if not _active_voices.has(family):
		return
	(_active_voices[family] as Array).erase(voice_id)


func get_active_voice_count(family: StringName) -> int:
	if not _active_voices.has(family):
		return 0
	return (_active_voices[family] as Array).size()


## Formula F1's `N` — simultaneous SFX-bus voices across every family
## combined, not just one. `AudioCueDispatcher` calls this after
## `trigger_voice()` so the newly-triggered voice is already counted,
## matching Formula F1's own variable description ("including this one").
func get_total_active_voice_count() -> int:
	var total: int = 0
	for family: StringName in _active_voices:
		total += (_active_voices[family] as Array).size()
	return total


## Test/inspection accessor — the voice ID stolen by the most recent
## `trigger_voice()` call, or -1 if that call didn't need to steal.
func get_last_stolen_voice_id() -> int:
	return _last_stolen_voice_id


## AC-12, Formula F1 (Concurrent-Cue Ducking): `ducked_volume = base_volume
## * max(duck_floor, 1 - duck_coefficient * (active_voice_count - 1))`.
## Independent of, and composable with, per-family caps above (Core Rule 5's
## own scope clarification — do not conflate the two mechanisms).
static func compute_ducked_volume(base_volume: float, active_voice_count: int, duck_coefficient: float = DUCK_COEFFICIENT, duck_floor: float = DUCK_FLOOR) -> float:
	var factor: float = maxf(duck_floor, 1.0 - duck_coefficient * float(active_voice_count - 1))
	return base_volume * factor


## Formula F3 — registers a qualifying trigger for `relationship`
## (`SFX_TO_AMBIENT` or `UI_TO_MUSIC_AND_SFX`). RESTING -> ATTACKING on the
## first trigger; every trigger (regardless of current state) resets the
## hold countdown. A trigger arriving mid-RELEASING cancels the release and
## re-enters HELD from the current partially-released dB — it never snaps
## back to the full duck amount first.
func trigger_sidechain(relationship: StringName) -> void:
	var config: Dictionary = _SIDECHAIN_CONFIG[relationship]
	var state: SidechainState = _sidechain_state[relationship]

	if state == SidechainState.RESTING:
		_sidechain_state[relationship] = SidechainState.ATTACKING
		_sidechain_phase_elapsed[relationship] = 0.0
		_sidechain_phase_start_db[relationship] = _sidechain_db_offset[relationship]
	elif state == SidechainState.RELEASING:
		_sidechain_state[relationship] = SidechainState.HELD

	_sidechain_release_timer[relationship] = config["release_delay"]


## Formula F3 — advances both sidechain relationships by `delta` seconds.
## Called once per frame by `AudioCueDispatcher`; naturally stops advancing
## while the game is paused (Core Rule 7's freeze requirement) simply by not
## being called, matching this project's own `get_tree().paused` +
## `PROCESS_MODE_INHERIT` pause convention rather than needing bespoke
## pause-handling logic here.
func tick_sidechain(delta: float) -> void:
	_advance_one_sidechain(SFX_TO_AMBIENT, delta)
	_advance_one_sidechain(UI_TO_MUSIC_AND_SFX, delta)


func _advance_one_sidechain(relationship: StringName, delta: float) -> void:
	var config: Dictionary = _SIDECHAIN_CONFIG[relationship]
	var state: SidechainState = _sidechain_state[relationship]

	match state:
		SidechainState.ATTACKING:
			_sidechain_phase_elapsed[relationship] += delta
			var t: float = clampf(_sidechain_phase_elapsed[relationship] / float(config["attack_time"]), 0.0, 1.0)
			_sidechain_db_offset[relationship] = lerpf(_sidechain_phase_start_db[relationship], config["duck_db"], t)
			if t >= 1.0:
				_sidechain_state[relationship] = SidechainState.HELD

		SidechainState.HELD:
			_sidechain_release_timer[relationship] -= delta
			if _sidechain_release_timer[relationship] <= 0.0:
				_sidechain_state[relationship] = SidechainState.RELEASING
				_sidechain_phase_elapsed[relationship] = 0.0
				_sidechain_phase_start_db[relationship] = _sidechain_db_offset[relationship]

		SidechainState.RELEASING:
			_sidechain_phase_elapsed[relationship] += delta
			var t: float = clampf(_sidechain_phase_elapsed[relationship] / float(config["release_time"]), 0.0, 1.0)
			_sidechain_db_offset[relationship] = lerpf(_sidechain_phase_start_db[relationship], 0.0, t)
			if t >= 1.0:
				_sidechain_state[relationship] = SidechainState.RESTING
				_sidechain_db_offset[relationship] = 0.0

		SidechainState.RESTING:
			pass


## Test/inspection + real-consumer accessor — the current dB offset for
## `relationship` (0.0 at rest, the relationship's full duck amount when
## HELD, an in-between ramp value while ATTACKING/RELEASING).
func get_sidechain_db_offset(relationship: StringName) -> float:
	return _sidechain_db_offset[relationship]


## Test/inspection accessor.
func get_sidechain_state(relationship: StringName) -> SidechainState:
	return _sidechain_state[relationship]
