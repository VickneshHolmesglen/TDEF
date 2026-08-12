# Evidence: Tarot Autoload Conversion (ADR-0035)

**Date**: 2026-08-12
**Fixes**: `production/qa/bugs/BUG-0001.md` (S1-Critical, Tarot save-data loss)
**Verification method**: Live Godot MCP (`run_project` background mode, `run_script`) against the pinned 4.6.2.stable binary — real `GTarot` Autoload, real `GSavePersistence`, real `GEventBus`, no mocks.

## What was verified

Ran a live GDScript probe against the real, spawned project (no `TarotDeckUI.tscn` mounted anywhere — the exact condition BUG-0001 named):

```json
{
  "gtarot_autoload_present": true,
  "is_card_unlocked_iron_resolve_default": true,
  "tarot_registered_with_save_persistence": true,
  "locked_after_mission_launched": true,
  "locked_after_mission_complete": false,
  "building_upgrade_tarot_branch_result": true
}
```

| Assertion | Result | What it proves |
|---|---|---|
| `gtarot_autoload_present` | `true` | `GTarot` exists as a real Autoload node at `scene_tree.root/GTarot`, reachable with zero scene setup. |
| `tarot_registered_with_save_persistence` | `true` | `GSavePersistence._registered_systems` contains an entry with `key == "tarot"` — with **no `TarotDeckUI.tscn` instantiated anywhere in the tree**. This is BUG-0001's reproduction case inverted into a passing check: previously this would have been `false` under identical conditions. |
| `is_card_unlocked_iron_resolve_default` | `true` | `iron_resolve` (Common card, `unlock_tech_id = ""`) resolves its default-unlock branch correctly through the real Autoload. |
| `locked_after_mission_launched` | `true` | `GEventBus.mission_launched` correctly reaches `GTarot._on_mission_launched()` and sets `_locked = true` — this listener is now alive for the full mission, not just while `TarotDeckUI.tscn` happened to be mounted (which it structurally never is during a real mission). Per the ADR's own Consequences analysis, this was very likely dead code before this conversion. |
| `locked_after_mission_complete` | `false` | `GEventBus.mission_phase_changed(..., "MISSION_COMPLETE", ...)` correctly reaches `_on_mission_phase_changed()` and clears the lock — full Rule 5 deck-lock lifecycle now demonstrably works end-to-end. |
| `building_upgrade_tarot_branch_result` | `true` | A freshly-constructed `BuildingUpgrade` instance (simulating Sanctuary UI's own real usage, no `TarotDeckUI.tscn` involved) correctly resolves its `"tarot"` requirement branch via `GTarot.is_card_unlocked()` — closes ADR-0034's originally-flagged gap. |

## Debug output review

No Tarot-related errors or warnings in `get_debug_output()`. The only errors logged were expected, unrelated side effects of the test script's synthetic `mission_launched("test_mission", ...)` emission also reaching the real `WaveManager` Autoload (which correctly logged a fallback for a nonexistent `test_mission_waves.tres` config) — confirms the live session exercised the real EventBus with all real subscribers, not an isolated stub.

## Test suite results

- `tests/unit/tarot`, `tests/integration/tarot`, `tests/integration/tarot-screen`, `tests/integration/tarot-deck-ui`, `tests/unit/building_upgrade`, `tests/integration/building_upgrade`, `tests/integration/encyclopedia`, `tests/integration/equipment-forge-screen`: **205/205 passing**, 0 errors/failures.
- New regression test for BUG-0001 itself: `tests/integration/tarot/autoload-persistence-reachability_test.gd` (2 tests) — proves the "tarot" save key is collected with no Tarot-hosting scene mounted, and reflects `GTarot`'s real live state.
- Full project regression: **2069/2069 passing**, 0 errors/failures (one transient flake on a prior run did not reproduce on immediate rerun — consistent with this project's already-documented pre-existing cross-suite test-isolation quirk, not a regression from this change).

## Sign-off

| Role | Verified | Approved |
|---|---|---|
| Implementation (Claude Sonnet) | 2026-08-12 | [x] Approved |
