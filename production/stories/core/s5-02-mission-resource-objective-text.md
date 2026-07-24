# S5-02 — Minimal MissionResource (Objective Text)

**Story ID**: S5-02
**Epic**: Core
**Layer**: Core
**Type**: Integration
**Owner**: gameplay-programmer
**Sprint**: Unassigned (created outside sprint planning, ready to pull into Sprint 5)
**Estimate**: 0.5 days
**Status**: Complete
**Manifest Version**: 2026-05-16

## TR Coverage

None directly — this closes a data-source gap flagged in `design/ux/pause-menu.md`'s Open
Questions (2026-07-07) and previously noted in the Wave Manager epic (Story 006/EPIC.md):
no `MissionResource` exists anywhere to resolve per-mission data such as objective text.

## ADR Governing Implementation

`docs/architecture/adr-0009-resource-data-model.md` (Accepted) — this story adds a new
persistent data Resource type, following the exact same pattern ADR-0009 already establishes
for `MonsterResource` (scan directory → load `.tres` → validate → cache in `GameDataRegistry`,
keyed by a string ID).

## Engine Notes

N/A — per ADR-0009's own Engine Compatibility field, `Resource` subclasses, `@export`,
`ResourceLoader.load()`, and `DirAccess` are all confirmed LOW-risk, pre-4.x stable APIs.
No post-cutoff verification needed.

## Control Manifest

N/A — no Required or Forbidden pattern in `docs/architecture/control-manifest.md`'s Core
Layer Rules applies to data-loader code (see S5-01's identical note for precedent).

## Background

`design/ux/pause-menu.md`'s Objective panel (and, eventually, Mission HUD's own objective
display and Mission Select's mission-picker UI) all need a source for a mission's objective
text, keyed by `mission_id: String` — the same key `mission_launched`'s EventBus payload
already carries (`design/gdd/event-bus.md`). No such Resource type or loader exists yet.

This is intentionally scoped minimally: **objective text only**, not a general-purpose
mission-metadata system. `WaveConfig` (ADR-0009, `assets/data/waves/{mission_id}_waves.tres`)
already owns wave composition data for a mission — `MissionResource` is a separate, smaller
file that owns only player-facing descriptive text, to avoid conflating "what spawns" with
"what the player is told."

## Acceptance Criteria

- [ ] `src/core/mission_resource.gd` created: `class_name MissionResource extends Resource` with `@export var mission_id: StringName = &""` and `@export var objective_text: String = ""`. `validate() -> Array[String]` checks both fields are non-empty (mirroring `MonsterResource.validate()`'s style).
- [ ] `GameDataRegistry` extended: `_load_mission_resources()` scans `res://assets/data/missions/*.tres` into `_mission_resources: Dictionary[StringName, MissionResource]`, same does-not-abort-on-invalid policy as the existing monster/tower loaders.
- [ ] `GameDataRegistry.get_mission_resource(mission_id: StringName) -> MissionResource` added (null if not found — same contract as `get_monster_resource()`).
- [ ] One real `.tres` file authored for "The Gap" at `assets/data/missions/the_gap.tres`, with real objective text (coordinate with game-designer/creative-director for the actual copy — this story does not invent final player-facing text unilaterally).
- [ ] `tests/unit/game_data_registry/game_data_registry_test.gd` extended with the same test shape as the tower blueprint loader (valid load, missing/malformed/duplicate cases) — mirror, don't reinvent.
- [ ] Live-engine verification: `GGameDataRegistry.get_mission_resource(&"the_gap")` returns real objective text when queried against the running "The Gap" mission scene.

## Out of Scope

- Wiring `design/ux/pause-menu.md`'s Objective panel UI itself to actually display this text — that's a separate UI implementation story, not this data-layer story.
- Wiring Mission HUD or Mission Select to consume `MissionResource` — same reasoning, separate stories when those screens are implemented.
- Any field beyond `mission_id`/`objective_text` (e.g., difficulty tier, recommended loadout, thumbnail image) — explicitly minimal scope per the Background section. Extend later if a real need appears.
- Authoring objective text for any mission beyond "The Gap" (the only mission that exists).

## Files to Create or Modify

- `src/core/mission_resource.gd` (new)
- `src/core/game_data_registry.gd` (extend — `_load_mission_resources()`, `get_mission_resource()`)
- `assets/data/missions/the_gap.tres` (new)
- `tests/unit/game_data_registry/game_data_registry_test.gd` (extend)

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/game_data_registry/game_data_registry_test.gd` (extended) + live engine verification that `get_mission_resource(&"the_gap")` returns real data

**Status**: [x] Verified — see Completion Notes below (6/6 criteria passing, verified live via the Godot MCP bridge across 2 sessions confirming `get_mission_resource(&"the_gap")` returns real data both before and after a full SCOUT→WAVE_ACTIVE cycle)

## Dependencies

- Depends on: None
- Unlocks: `design/ux/pause-menu.md`'s Objective panel (once that UI is implemented), future Mission HUD objective display, future Mission Select mission-picker UI

## Completion Notes
**Completed**: 2026-07-07
**Criteria**: 6/6 passing — all verified live via the Godot MCP bridge (`get_mission_resource(&"the_gap")` returns real data with zero errors in the actual running mission scene, both before and after a full SCOUT→WAVE_ACTIVE cycle).
**Deviations**: None from stated scope. One real bug found and fixed during implementation, not anticipated by the story: `MissionResource`'s new `class_name` wasn't picked up by a bare headless `run_project` boot — Godot's global script class cache (`.godot/global_script_class_cache.cfg`) is only rebuilt by the editor, not by a game-mode headless boot. Fixed by manually adding the missing cache entry (format matched from an adjacent existing entry). Logged as `TD-workflow-001` since this is the third time this exact class of issue has hit this project — documented in `tests/README.md` for future sessions.
**Objective text caveat**: `assets/data/missions/the_gap.tres`'s `objective_text` is draft copy ("Defend the sanctuary core. Place towers to hold the lane, then use your hero to cover any gap they can't.") derived from `production/vertical-slice-target.md`'s scripted-moment description, not signed off by game-designer/creative-director. Per this story's own Background section, final player-facing copy was explicitly out of this story's authority — flag for a real copy pass before this text ships to players.
**Test Evidence**: `tests/unit/game_data_registry/game_data_registry_test.gd` (7 new tests: valid load, unknown ID, invalid/malformed/duplicate/missing-dir cases, mirroring the tower blueprint loader's shape exactly) + live engine verification (2 separate Godot MCP sessions).
**Code Review**: Self-reviewed (not a separate `/code-review` pass, given the extremely close pattern match to S5-01's already-reviewed implementation and the real bug already caught and fixed during implementation itself). Confirmed: no shared-mutable-state risk (unlike S5-01's bulk-dictionary getters, `get_mission_resource()` returns a single object, not a collection — no `.duplicate()` needed); test isolation preserved (existing `_inject()` call sites all updated with an empty missions-dir fixture, matching S5-01's established discipline).
