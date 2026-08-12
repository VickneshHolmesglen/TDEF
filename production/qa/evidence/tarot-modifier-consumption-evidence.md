# Evidence: Tarot Modifier Consumption (ADR-0036)

**Date**: 2026-08-12
**Unblocks**: Epic 07 Tarot Story 006's AC-37/AC-38
**Verification method**: Live Godot MCP (`run_project` background mode, `run_script`) against the pinned 4.6.2.stable binary — real `GTarot`, `GWaveManager`, `GEventBus`, no mocks.

## What was verified

Drove the real Tarot → EventBus → Wave Manager chain end-to-end: equipped the real `bountiful_harvest` card (`tarot_reward_scalar_mult`, `base_modifier_value = 1.75`) on `GTarot`, emitted a real `mission_launched` + `mission_phase_changed(SCOUT)` sequence, then transitioned `GWaveManager` to `WAVE_ACTIVE`.

```json
{
  "card_equipped": true,
  "reward_multiplier_raw": 1.75,
  "wave_reward_scalar_final": 1.75
}
```

| Assertion | Result | What it proves |
|---|---|---|
| `card_equipped` | `true` | `GTarot.equip_card()` works against the real registry-loaded card. |
| `reward_multiplier_raw` | `1.75` | `GWaveManager._on_mission_modifier_applied()` correctly received the real `mission_modifier_applied` event Tarot's own `_resolve_scout_modifiers()` emitted at SCOUT entry, and F2's running product correctly reflects the single equipped card's Tier-0 effective value (`1.75 × mastery_scalar(1.00) = 1.75`). |
| `wave_reward_scalar_final` | `1.75` | F3's full composition (`natural(1.0, wave 1) × 1.75 + rune_bonus(0.0, not discovered) = 1.75`) computed correctly inside the real `_transition_to(WAVE_ACTIVE)` call path — not just in an isolated unit test. |

## Debug output review

The only errors logged were expected artifacts of driving `mission_launched`/`mission_phase_changed` synthetically without a real Grid/mission map loaded (`PathfindingSystem: mission map has no SPAWN cells`, `WaveManager: 0 spawn cells`) — unrelated to the Tarot modifier consumption logic itself. No errors from `_on_mission_modifier_applied()`, Tarot's own emission path, or the F2/F3 composition.

## Test suite results

- `tests/unit/wave_manager/wave_manager_reward_scalar_test.gd`: 29/29 passing (8 new — `tarot_reward_scalar_mult` single/2-card/rune-bonus composition, hard-ceiling clamp, `tarot_difficulty_growth_rate` REPLACE + `[0.10, 0.25]` clamp + multi-card data-error discard, `tarot_wave_config_override` always-fallback path).
- `tests/unit/monster/monster_tarot_speed_scalar_test.gd`: 6/6 passing (new file — confirms the old bug's string never matches, F2 single/2-card multiplicative stacking, boundary clamp, and the retry-reset regression found during this ADR's own validation).
- Full project regression: **2084/2084 passing**, 0 errors/failures.

## Real bugs found and fixed during this ADR's authoring/validation (not pre-existing test gaps — genuine defects)

1. **Monster System's existing `_on_mission_modifier_applied()` handler never fired for a real Tarot event.** It checked `modifier_type == "monster_speed_scalar"`, a string that matches nothing Tarot ever emits (the real registered value is `"tarot_speed_scalar_mult"`). Confirmed via the corrected test's own "old bug string never matches" case.
2. **Even if the string had matched, it did a last-write-wins overwrite, not F2's multiplicative aggregate.** A second equipped card targeting the same type would have silently discarded the first's contribution.
3. **Retry-reset gap**: `MonsterManager` is a static `MissionScene` child, never destroyed/recreated between attempts — `MissionSelect.retry_current_mission()` reuses the same instance. Without an explicit reset (added to `_on_wave_started()`'s existing wave-1 special case), a retried mission would have compounded the speed-scalar product against the failed attempt's stale value.
4. **Missing `[0.10, 0.25]` clamp on `tarot_difficulty_growth_rate`'s REPLACE override** — a mastery-scaled card (e.g. Grim Resolve at Tier 4: `0.25 × 1.75 = 0.4375`) would otherwise silently exceed the validated range with no correction, since `_validate_difficulty_growth_rate()` only logs and only runs once at mission launch, before the override applies.

All 4 found and fixed during `godot-specialist` validation of ADR-0036, before any production code was written against the flawed draft.

## Sign-off

| Role | Verified | Approved |
|---|---|---|
| Implementation (Claude Sonnet) | 2026-08-12 | [x] Approved |
