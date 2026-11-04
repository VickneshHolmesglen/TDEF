# Early wave call (gold for skipped intermission)

Date: 2026-11-04. Status: **built** (overnight autonomy pass). Source idea: Kingdom Rush's "call the next wave early" bonus, a genre-wide mechanic, adapted to this game's INTERMISSION.

## Rule

Pressing Ready during INTERMISSION with at least `EARLY_CALL_MIN_SECONDS` (1.0 s) left calls the next wave early:

- WaveManager emits `wave_called_early(wave_number, seconds_skipped, wave_reward_scalar)` before the INTERMISSION -> PRE_WAVE transition (`wave_reward_scalar` = the last wave's).
- ResourceEconomy pays **Formula 5b**: `early_call_gold = round(seconds_skipped x 0.35 x wave_reward_scalar)` as `resources_changed(gold, "early_call_grant")`.
- The Ready button shows the live payout during INTERMISSION: "Call Early +N" (`HUD_READY_CALL_EARLY`), computed with the same static `ResourceEconomy.early_call_gold()`, so preview and payout cannot drift.

Ready in SCOUT or PRE_WAVE ("Start Now") is unchanged and pays nothing.

## Why these numbers

A full 30 s skip at scalar 1.0 pays ~10-11 gold, half of `BASE_WAVE_GOLD` (20). The cost is real: the player loses up to 30 s of building time (PRE_WAVE locks the build controls), and the next wave arrives before towers placed with the bonus can matter. Worth taking when the defence is clearly ahead, never worth more than the wave itself. Bounded: one payout per intermission, so it cannot be farmed.

## Docs

`resource-economy.md` Rule 10b (new gold source), `wave-manager.md` Rule 12 note.

## Verification

`tests/integration/wave_manager/early_wave_call_test.gd` (formula, payout, < 1 s no-op, SCOUT/PRE_WAVE no-op). Live on the_gap: 26.8 s left, button "Call Early +9", gold 50 -> 59, phase PRE_WAVE.
