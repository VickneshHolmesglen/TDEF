class_name DailyChallenge
extends RefCounted

## Daily Challenge (design/quick-specs/daily-challenge-2026-11-04.md): one
## seeded run per calendar day (UTC). The date picks the map (from the maps
## the player has unlocked), the run modifiers, and the procedural layout, so
## every attempt that day, retries included, plays the same board. Pure and
## static: MissionSelect owns the state (streak, last clear) and the launch.

## Shards granted for the first clear of a day, plus one per streak day
## (capped), delivered through MissionSelect's held-shard path.
const CLEAR_SHARDS: int = 5
const STREAK_BONUS_CAP: int = 7

## Modifier steps the daily may roll, mirroring Mission Select's steppers
## (mission-select.md Rule 5). At least one modifier is always on: a daily is
## meant to be harder than a normal run of the same map.
const MODIFIER_STEPS: Dictionary[StringName, Array] = {
	&"extend_waves": [0.0, 1.0, 2.0],
	&"difficulty_growth_boost": [0.0, 0.03, 0.05],
}


## "YYYY-MM-DD" (UTC) for a unix timestamp.
static func date_key(unix_time: float) -> String:
	var d: Dictionary = Time.get_date_dict_from_unix_time(int(unix_time))
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]


## The day before `key` ("YYYY-MM-DD"), for streak continuity.
static func previous_date_key(key: String) -> String:
	var unix: int = Time.get_unix_time_from_datetime_string(key + "T12:00:00")
	return date_key(float(unix - 86400))


## Deterministic seed for a date (stable across sessions and machines).
static func seed_for(key: String) -> int:
	return hash("sanctuary_daily_" + key)


## A seeded generator for `key`; `salt` separates independent draws (the map
## layout must not shift when the modifier roll logic changes).
static func rng_for(key: String, salt: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for(key) + salt
	return rng


## Today's setup: {mission_id, modifiers: Dictionary[StringName, float]}.
## `candidate_mission_ids` = the maps the player can launch; sorted first so
## the pick does not depend on Dictionary order. Empty -> empty mission_id.
static func roll(key: String, candidate_mission_ids: Array[String]) -> Dictionary:
	var ids: Array[String] = candidate_mission_ids.duplicate()
	ids.sort()
	var rng: RandomNumberGenerator = rng_for(key, 1)
	var mission_id: String = ids[rng.randi_range(0, ids.size() - 1)] if not ids.is_empty() else ""
	var modifiers: Dictionary[StringName, float] = {}
	var any_on: bool = false
	for modifier_id: StringName in [&"extend_waves", &"difficulty_growth_boost"]:
		var steps: Array = MODIFIER_STEPS[modifier_id]
		var value: float = steps[rng.randi_range(0, steps.size() - 1)]
		modifiers[modifier_id] = value
		any_on = any_on or value != 0.0
	if not any_on:
		modifiers[&"extend_waves"] = 1.0
	return {"mission_id": mission_id, "modifiers": modifiers}


## Streak after clearing `key`, given the previous last-cleared date and
## streak: +1 when yesterday was cleared, unchanged when today already was,
## otherwise a fresh 1.
static func next_streak(key: String, last_cleared: String, streak: int) -> int:
	if last_cleared == key:
		return streak
	if last_cleared == previous_date_key(key):
		return streak + 1
	return 1


## Shards for a first clear of the day at `streak` (after the clear).
static func clear_shards(streak: int) -> int:
	return CLEAR_SHARDS + mini(maxi(streak - 1, 0), STREAK_BONUS_CAP)
