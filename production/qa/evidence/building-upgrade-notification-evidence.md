# QA Evidence: Building Upgrade PURCHASABLE Notification & Purchase Feedback (AC-8, AC-9)

**Story**: `production/epics/epic-14-building-upgrade/story-004-purchasable-notification-and-purchase-feedback.md`
**Date**: 2026-08-12
**Engine**: Godot 4.6.2.stable.official, driven live via the Godot MCP bridge (`run_project` on `src/presentation/sanctuary_ui/SanctuaryUI.tscn`, `run_script`, `take_screenshot`)
**Status**: Advisory evidence, closing the manual/visual verification this story's Test Evidence section required. Automated coverage already exists (7 tests in `tests/integration/building_upgrade/purchasable_notification_test.gd`, plus a new badge-level test in `tests/integration/sanctuary-ui/connection-badges_test.gd` added during `/code-review`) and remains the primary evidence for exact-emission-count/state-transition correctness — this doc covers what only a live running engine can prove.

---

## What was verified

- AC-8: `building_upgrade_became_purchasable` drives a real Sanctuary UI Connection Badge on the Equipment Forge tab, in the real running scene tree (not a mocked/injected screen).
- A genuine, pre-existing project limitation was rediscovered live: the full requirement->PURCHASABLE->badge chain cannot be demonstrated end-to-end in the real `SanctuaryUI.tscn` scene today, because Tarot has no live instance reachable from Sanctuary UI (BUG-0001, filed earlier this session) — `upgrade_watchtower_reinforced`'s own `"tarot"` requirement (`iron_resolve`) therefore fails closed even with every other requirement satisfied. This is not a Story 004 defect; it's the same pre-existing gap already tracked.

## Method

1. Launched the real `SanctuaryUI.tscn` scene live via the Godot MCP bridge (background mode) — this scene's own `BuildingUpgrade` node (a real child, not injected) is the one actually exercised, not a test double.
2. Satisfied `watchtower_tier_1` (visibility) and `habitat_expansion_tier_1` (the `"building"` requirement) via `run_script`; confirmed `is_badge_visible(4)` starts `false`.
3. Seeded a real `glimmer_hare` creature into `GMenagerie` and emitted `creature_acquired` — confirmed `can_purchase()` still returned `false`, tracing to the `"tarot"` requirement's known fail-closed gap (not something this story can fix — see Notes).
4. Emitted `GEventBus.building_upgrade_became_purchasable` directly to isolate and verify Story 004's own contribution (the badge-trigger wiring) independent of the pre-existing Tarot blocker: confirmed `is_badge_visible(4)` flips to `true`, `get_badge_count(4)` reads `1`.
5. Cross-checked the same badge Label node's own `visible`/`position` properties directly, and repeated the same check against the pre-existing `sanctuary_structure_built` -> Defense Building badge trigger for comparison.

## Results

| Check | Result |
|---|---|
| Badge hidden before `building_upgrade_became_purchasable` fires | **Confirmed** (`is_badge_visible(4) == false`) |
| Badge visible immediately after `building_upgrade_became_purchasable` fires | **Confirmed** (`is_badge_visible(4) == true`, count `1`) |
| Badge `Label` node itself reports `visible == true` with text `"1"` | **Confirmed** |
| Tab strip renders exactly 6 rooms (Overview/Inventory & Crafting/Menagerie/Defense Building/Forge/Loadout), no stray "Assemble Towers" tab | **Confirmed** (screenshot) |
| Runtime errors during the run | **0** |

**Observation, not a Story 004 defect**: the badge Label's own screen position (`(319, 0)` relative to a `320×56` button) sits at the very right edge of its parent button and is not visually distinguishable in the captured screenshot at this window size. Traced this to the pre-existing Connection Badge mechanism itself (Epic 10, Story 003) — the *identical* position was confirmed for the already-shipped `sanctuary_structure_built` → Defense Building badge trigger too, so this is a systemic characteristic of the badge positioning logic that predates and is unrelated to this story's own change. Not filed as a new bug (low severity, cosmetic, affects all 4 badge triggers equally) — flagged here for whoever next touches Connection Badge visual polish.

## Verdict

**PASS** for AC-8's own scope (the new trigger correctly drives the existing, real Connection Badge mechanism). The full requirement-to-badge chain remains blocked end-to-end by the separately-tracked BUG-0001 (Tarot unreachable from Sanctuary UI), not by anything in this story.

## Notes

- AC-9 (purchase confirmation chime) is not independently re-verified here beyond what `tests/integration/building_upgrade/purchasable_notification_test.gd::test_audio_cue_dispatcher_is_wired_to_structure_upgraded` already covers — Audio System's real cue *content* authoring is separate, deferred Full Vision-tier work project-wide (per Epic 12's own Definition of Done); this story's own scope is the *dispatch wiring*, already proven both by that automated test and by the fact that `dispatch_cue()` never touches real playback nodes at all (confirmed by reading `audio_cue_dispatcher.gd` directly during implementation) — there is no live audio behavior to screenshot or capture.
