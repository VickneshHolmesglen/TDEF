class_name MissionOutcomeStats
extends RefCounted

## Per-mission counters shown on the mission outcome screen. Pure data: the owning
## screen wires EventBus signals to the on_* handlers and calls tick() each frame.

## Highest wave number completed this mission.
var waves_cleared: int = 0
## Total waves in the mission, as reported by the latest wave_started.
var total_waves: int = 0
## Monsters killed this mission.
var monsters_slain: int = 0
## Monsters that reached the sanctuary this mission.
var breaches: int = 0
## Seconds elapsed this mission.
var elapsed_seconds: float = 0.0


## Zeroes every counter.
func reset() -> void:
	waves_cleared = 0
	total_waves = 0
	monsters_slain = 0
	breaches = 0
	elapsed_seconds = 0.0


## wave_started handler: records the mission's total wave count.
func on_wave_started(_wave_number: int, total: int, _difficulty: float) -> void:
	total_waves = total


## wave_completed handler: waves_cleared only ever grows (max semantics).
func on_wave_completed(wave_number: int, _enemies_remaining: int, _boss_breached: bool) -> void:
	waves_cleared = maxi(waves_cleared, wave_number)


## monster_died handler: counts one kill.
func on_monster_died(_payload: MonsterDiedEvent) -> void:
	monsters_slain += 1


## monster_breached handler: counts one breach.
func on_monster_breached(_entity_id: int, _monster_id: StringName, _tier: int) -> void:
	breaches += 1


## Advances the mission clock; negative deltas are ignored.
func tick(delta: float) -> void:
	if delta > 0.0:
		elapsed_seconds += delta


## Formats seconds as "M:SS" (floored, never negative; minutes are not capped).
static func format_time(seconds: float) -> String:
	var total: int = maxi(0, floori(seconds))
	return "%d:%02d" % [total / 60, total % 60]
