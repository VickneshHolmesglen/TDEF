# Wave report (post-wave tower breakdown)

Date: 2026-11-05. Status: **built**. Source idea: per-tower damage/pop counters (Bloons TD 6's pop count, the damage meters of MMO raids), which this game already half-designed: `tower.md` Rule 23 has TowerSystem emit `tower_wave_summary` once per tower at `wave_completed` for "the Endless Theorist post-wave feedback surface", and `mission-hud.md` registers it as the HUD's job but left the display unbuilt. Nothing consumed the event until now.

## Player value

Between waves the player decides what to build, sell or move. The report answers the questions that decision needs: which towers carried the wave, which sat idle (badly placed or out-ranged), and whether the killing blows land where the damage does.

## Rules

- **Shown** at the end of every wave (deferred one frame after `wave_completed`, so every tower's summary has arrived), during INTERMISSION. **Hidden** when the next wave starts, on SCOUT (retry) and on MISSION_COMPLETE/DEFEAT (the outcome screens own the screen then).
- One row per tower that has a summary, sorted by damage dealt, highest first. At most 8 rows, then "+N more".
- Row: archetype badge, tower name (the blueprint display name, carried on `TowerPlacedEvent.display_name`, a field added for this; weapon id as fallback), rank chevrons if it has a veterancy rank, a bar of its share of the wave's total tower damage, damage, kills this wave (`MonsterDiedEvent.killer_tower_id`), and idle share.
  - **Idle share** = `idle_ticks / (shots_fired + idle_ticks)`: the fraction of attack opportunities with no target in range. At 50% or more the value turns warning-coloured: that tower is mostly waiting.
  - Support (aura) towers deal no damage: they show "N pulses" (`aura_applications_this_wave`) instead of damage, and no idle share.
- **Tower numbers (added 2026-11-05):** rows are numbered 1..8 and the same number floats over that tower in the world (a small archetype-ringed badge at `world_position + (0, -44)`, re-projected every frame through the canvas transform so it follows camera pans) while the report is open. Identical tower names can then be matched to the map. A tower sold or destroyed after the wave keeps its row but loses its badge (`tower_removed` / `tower_destroyed` erase it).
- Pure presentation: subscribes to EventBus only, emits nothing, never takes input (mouse filter ignore), so it can never block placement clicks.
- No save data; no tuning beyond `MAX_ROWS` (8) and `IDLE_WARN_RATIO` (0.5).

## Verification

`tests/integration/mission-hud/wave-report_test.gd`: row building (sort, share, idle ratio, support rows, kill counting from single and batched deaths, row cap), show after wave end / hide on wave start and terminal phases. Live: the_gap with three towers, one wave, screenshot of the panel.
