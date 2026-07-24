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
}

const DUCK_COEFFICIENT: float = 0.05  ## Formula F1's `k`
const DUCK_FLOOR: float = 0.3  ## Formula F1's `D_floor`

## Sidechain ducking (Core Rule 5) — a separate, cross-bus mechanism from
## Formula F1 (which operates *within* the SFX bus across its own voices).
const SFX_TO_AMBIENT_DUCK_DB: float = -6.0
const UI_TO_MUSIC_AND_SFX_DUCK_DB: float = -4.0

var _family_caps: Dictionary[StringName, int] = DEFAULT_FAMILY_CAPS.duplicate()

## Per family: an Array[int] of active voice IDs, oldest first (index 0).
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
	if cap >= 0 and voices.size() >= cap:
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
	return (_active_voices.get(family, []) as Array).size()


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
