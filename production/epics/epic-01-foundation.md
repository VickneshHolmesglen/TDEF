# Epic 01 — Foundation Layer

**Phase**: Pre-Production → Production
**Status**: Complete (all 6 Foundation autoloads implemented and tested — Sprint 4)
**Owner**: Technical Director
**Target Milestone**: Vertical Slice (playable)
**Created**: 2026-05-19
**Last Updated**: 2026-07-20 (real bug found and fixed: `GridConfig.cells` was missing `@export`, silently breaking .tres-authored grid layouts — see note below)

> **Real bug found and fixed 2026-07-20**: `GridConfig.cells` (`src/foundation/grid/grid_config.gd`) was declared without `@export`, so no GridConfig authored as a `.tres` file could ever actually persist its cell layout — `ResourceSaver.save()` silently dropped the field despite the class's own doc comment explicitly claiming ".tres authoring" was supported. Discovered while investigating a real-launch-pipeline error surfaced during Mission HUD's Story 012 (DEFEAT Retry) live verification: `assets/data/missions/entries/the_gap_entry.tres` (Mission Select's real shipped mission entry) had 0 cells in its `grid_config`, meaning the real Mission Select launch/retry pipeline (`confirm_launch()`/`retry_current_mission()`) handed WaveManager a 0-spawn-cell grid and hard-failed with an immediate `MISSION_COMPLETE` bypass instead of a real playable mission — `the_gap.tscn`'s own direct-boot debug path was unaffected (it builds its `GridConfig` programmatically at runtime, never touching this `.tres`), which is why this was never caught by normal dev-testing. Fixed by adding `@export`, then regenerating `the_gap_entry.tres`'s grid_config to match `the_gap.gd`'s own programmatic layout exactly (verified byte-for-byte via a live MCP script that instantiated `TheGap` and called its own `_build_grid_config()` directly). 3 new regression tests added (`tests/unit/grid/grid_config_persistence_test.gd`, `tests/integration/mission-select/the-gap-entry-content_test.gd`). Full regression re-confirmed clean: 1479/1479, 0 errors, 1 pre-existing unrelated failure. **`assets/data/missions/entries/the_narrows_entry.tres` has the same underlying 0-cells symptom but was NOT fixed** — no real scene exists for "the_narrows" (only `the_gap` has a playable scene under `src/gameplay/missions/`), it's used only as a second mission_id in Mission Select unit tests that don't touch grid content, so fabricating level geometry for it would be inventing content without a design basis.

> **Real bug found and fixed 2026-07-20 (companion to the GridConfig fix above)**: `SceneManager.transition_to_sanctuary()` (Autoload #6, ADR-0002) is called automatically on 3 real, live-triggered paths — `hero_died`, `mission_phase_changed(new_phase="MISSION_COMPLETE")`, and the Pause Menu's "Quit to Sanctuary" button — but `res://src/scenes/SanctuaryScene.tscn` never existed anywhere in this project (a known gap dating to S4-01/S4-09, tracked only in code comments, never actually closed). Every one of those 3 paths hard-errored in real play. **Fixed**: created a minimal connective-tissue stub (`src/scenes/sanctuary_scene.gd` + `SanctuaryScene.tscn` — a single centered placeholder Label, no `class_name` per `pause_menu.gd`'s own TD-workflow-001 precedent) that satisfies `SceneManager`'s contract without designing the real Sanctuary UI system (`systems-index.md` #24, still genuinely "Not Started" — not changed by this fix). Deliberately does NOT wire a "launch mission" round-trip button — `SceneManager`'s `_mission_scene_path` default (`res://src/scenes/MissionScene.tscn`) has the identical "never existed" gap, and deciding what that generic path should point to is a Mission-Select-UI design question, out of scope here. 1 new regression test (`test_transition_to_sanctuary_loads_the_real_shipped_scene`, `tests/integration/foundation/scene_manager_transition_test.gd` — the one test in that file that doesn't inject a stub, deliberately exercising the real shipped scene). Live-MCP-verified: a real `hero_died` emission against the running `the_gap.tscn` correctly landed on the real `SanctuaryScene`, screenshot-confirmed legible, zero errors. Full project regression re-confirmed clean.

## Goal

Implement the 6 Foundation autoloads (EventBus, Save & Persistence, Grid,
Pathfinding, GameDataRegistry, SceneManager) to the depth required for the
Vertical Slice to run. All Foundation systems must be stable before any
Core-layer system begins implementation.

> **Updated 2026-07-03**: GameDataRegistry and SceneManager added to this
> epic's scope. Both were introduced by ADR-0002's 2026-05-24 revision and
> ADR-0009 (Accepted 2026-05-24) as required Foundation Autoloads (positions
> 5 and 6 in the 7-Autoload boot order), but neither has a dedicated GDD
> document or a systems-index.md entry — they are pure architecture-layer
> constructs. Their requirements below are sourced directly from ADR-0002 and
> ADR-0009 text rather than a GDD, consistent with how other ADR-only
> requirements are handled elsewhere in this project (e.g. Hero's Skill
> System story explicitly notes "ADR: N/A — implemented per hero.md
> directly"). Surfaced while running `/story-readiness` on Sprint 4's S4-01.

## Scope

| System | GDD | ADRs | Status |
|--------|-----|------|--------|
| EventBus | `design/gdd/event-bus.md` | ADR-0001 | Designed |
| Save & Persistence | `design/gdd/save-persistence.md` | ADR-0003 | Designed |
| Grid System | `design/gdd/grid-system.md` | ADR-0005 | Designed |
| Pathfinding | `design/gdd/pathfinding.md` | ADR-0004 | Designed (revised, pending re-review) |
| GameDataRegistry | None — ADR-only | ADR-0009 | Implemented (2026-07-03) — `src/core/game_data_registry.gd`, `tests/unit/game_data_registry/` |
| SceneManager | None — ADR-only | ADR-0002 (revised) | Implemented (2026-07-03) — `src/core/scene_manager.gd`, `tests/unit/scene_manager/`, `tests/integration/foundation/scene_manager_transition_test.gd` |

## Out of Scope

- Core layer systems (Hero, Tower, Monster, D&S, Wave Manager) — Epic 02
- UI/HUD implementation — Epic 04
- Networking — deferred post-MVP

## Acceptance Criteria

- [x] All 4 core-data autoloads boot in correct order (EventBus → Save → Grid → Pathfinding) — Sprint 2
- [x] All 6 autoloads boot in correct order per ADR-0002's revised table (EventBus → Save → Grid → Pathfinding → GameDataRegistry → SceneManager) — verified via `tests/integration/foundation/foundation_boot_order_test.gd` (Sprint 4)
- [x] EventBus: all catalogued events emit without error in test harness
- [x] Grid: 16×12 cell grid initialises; cell type read API returns correct values
- [x] Pathfinding: `templates_ready` fires after spawn→goal route pre-computation
- [x] Save: atomic write (.tmp → .dat) succeeds; 3-slot restore_order verified
- [x] GameDataRegistry: preloads all `MonsterResource` and `TowerPerkRegistry` entries at boot; data available to WaveManager/Monster System before any mission scene loads (ADR-0009)
- [x] SceneManager: owns SANCTUARY↔MISSION scene transitions per ADR-0002's OQ-3 resolution; no other system calls `get_tree().change_scene_to_packed()` directly
- [x] All 4 core-data systems pass unit tests (`tests/unit/`)
- [x] GameDataRegistry and SceneManager pass unit + integration tests (`tests/unit/game_data_registry/`, `tests/unit/scene_manager/`, `tests/integration/foundation/`)
- [ ] Foundation traceability: TR coverage for GameDataRegistry/SceneManager still not formally tracked — both predate/postdate the TR registry's GDD-driven scope (they are ADR-only constructs with no GDD). Not re-verified as part of this doc-accuracy pass (S5-07); flag for a future `/architecture-review` pass if exact TR-ID coverage numbers are needed.

## Dependencies

- ADR-0001, ADR-0003, ADR-0004, ADR-0005 — all Accepted ✅
- ADR-0002 (revised 2026-05-24), ADR-0009 (Accepted 2026-05-24) — both Accepted ✅
- Pathfinding GDD re-review — Sprint 1 item (S1-06) — Complete
- Control manifest — complete ✅

## Estimated Sprints

Core-data systems (EventBus, Save, Grid, Pathfinding): Complete (Sprint 2).
GameDataRegistry + SceneManager: Complete (Sprint 4, 2026-07-03) — was
required before "The Gap" mission scene could be assembled (S4-09, also
Complete).

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| S2-01 | [EventBus Autoload](../stories/foundation/s2-01-eventbus.md) | Integration | Complete | ADR-0001 |
| S2-02 | [Save & Persistence Autoload](../stories/foundation/s2-02-save-persistence.md) | Integration | Complete | ADR-0003 |
| S2-03 | [Grid System Autoload](../stories/foundation/s2-03-grid-system.md) | Logic | Complete | ADR-0005 |
| S2-04 | [Pathfinding Autoload](../stories/foundation/s2-04-pathfinding.md) | Integration | Complete | ADR-0004 |
| S4-01 | [SceneManager Autoload](../stories/foundation/s4-01-scene-manager.md) | Integration | Complete | ADR-0002 |
| S4-02 | [GameDataRegistry Autoload](../stories/foundation/s4-02-game-data-registry.md) | Integration | Complete | ADR-0009 |

**Story dependency order**: S4-02 → S4-01 (GameDataRegistry must boot at position
5 before SceneManager can boot at position 6)
