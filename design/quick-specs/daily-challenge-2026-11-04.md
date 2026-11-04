# Daily Challenge (seeded run per day)

Date: 2026-11-04. Status: **built** (overnight autonomy pass). Source idea: the seeded daily run from roguelites (Slay the Spire's Daily Climb, Spelunky's daily challenge), which suits this game because its maps are already procedurally generated per launch (`procedural-paths-2026-11-03.md`).

## Rules

- **One setup per UTC calendar day**, rolled by `DailyChallenge.roll(date, unlocked maps)`:
  - the map, from the maps the player can launch (sorted, so the pick is stable);
  - the run modifiers: `extend_waves` and `difficulty_growth_boost`, each at off/low/high, at least one on (a daily is meant to be harder than a normal run);
  - the tier: the best tier the player has cleared on that map (Normal if none), so the daily sits at their proven level plus the modifiers.
- **Same board all day.** The date seeds `MapGenerator.generate`, so every attempt that day, retries included, plays the same layout. Normal runs stay fresh per launch.
- **Changing the setup ends the daily.** Pressing a tier or modifier after choosing the daily makes it a normal run (`set_difficulty_tier` / `set_run_modifier` clear the daily flag). Retrying a defeated daily keeps it.
- **Reward, first clear of the day only:** `5 + min(streak - 1, 7)` Ascendant Shards (5 to 12), delivered through Mission Select's held-shard path (safe with a full bag). Repeat clears that day pay nothing extra. The normal completion record and ascension shards still apply.
- **Streak:** +1 when yesterday's daily was cleared, otherwise it restarts at 1. Persisted in Mission Select's save data (`daily: {last_cleared, streak}`); older saves load with no record.

## UI

First card in Mission Select's map grid: "Daily Challenge / <map> · <tier> / First clear: +N shards" (or "Cleared today"), plus "Streak: N" once there is one. Pressing it selects the setup; the config panel title reads "Daily Challenge: <map>".

## Why these numbers

Shards buy extra rune slots (40, then 120). A daily player earns the first slot in about a week, which rewards the habit without outpacing Ascension, where one Ascension 1 first clear alone pays 12.

## Not done

No online leaderboard (no backend); the daily is per save. The map pool is the player's unlocked maps, so two players on the same date can get different maps.

## Verification

`tests/unit/mission-select/daily-challenge_test.gd` (date keys, deterministic roll, a modifier always on, same layout all day, streak/shard maths, select flow, setup change ends the daily, first clear only once, save round trip + legacy save). `mission_select_screen_test.gd`: card is first and selects the daily. Live: real save, card "Daily Challenge | The Gap · Normal | First clear: +5 shards"; selecting it set Extend Waves Low and could launch.
