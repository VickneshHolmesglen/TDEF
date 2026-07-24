# S5-01 — MonsterManager & TowerSystem Production Data Loaders (TD-data-001)

**Story ID**: S5-01
**Epic**: Core
**Layer**: Core
**Type**: Integration
**Owner**: gameplay-programmer
**Sprint**: Unassigned (created outside sprint planning, ready to pull into Sprint 5)
**Estimate**: 0.75 days
**Status**: Complete
**Manifest Version**: 2026-05-16

## TR Coverage

None directly — this closes `TD-data-001` in `docs/tech-debt-register.md`, a High-severity
architectural gap discovered during S4-09 (Assemble The Gap Mission Scene), not a GDD requirement.

## ADR Governing Implementation

`docs/architecture/adr-0009-resource-data-model.md` (Accepted) — governs `GameDataRegistry`'s
load-once-at-boot pattern, per-resource `validate()` contract, and the "no other system loads
these resource types by path directly" rule this story extends to `TowerData`.

## Engine Notes

N/A — per ADR-0009's own Engine Compatibility field: "`Resource` subclasses, `@export`,
`ResourceLoader.load()`, `DirAccess` are all pre-4.x stable APIs. `DirAccess.get_files_at()`
static method available since Godot 4.0." Confirmed LOW knowledge risk — no post-cutoff
verification needed.

## Control Manifest

N/A — the Core Layer Rules in `docs/architecture/control-manifest.md` cover Hero/Monster/
WaveManager scene-node and physics patterns specifically; no Required or Forbidden pattern
there applies to `GameDataRegistry`-style data-loading code.

## Background

`TD-data-001` (logged 2026-07-05, High severity): neither `MonsterManager._resource_table` nor
`TowerSystem._tower_table` has a production loader. Both dictionaries carry doc comments claiming
they're "populated from disk in production," but nothing does this outside unit tests, which
inject the dictionaries directly. `src/gameplay/missions/the_gap/the_gap.gd` currently works
around this with scene-local `_wire_monster_data()` / `_wire_tower_data()` methods that manually
copy specific IDs from `GGameDataRegistry` into the two systems — a stopgap that every future
mission scene would otherwise have to duplicate.

`GameDataRegistry` (`src/core/game_data_registry.gd`) already has the exact pattern to extend:
`_load_monster_resources()` scans `res://assets/data/monsters/*.tres` into `_monster_resources`,
keyed by `monster_id`, with `push_error()`-per-invalid-file (not abort-boot) semantics. This story
adds an equivalent path for `TowerData` blueprints and exposes both tables in bulk so
`MonsterManager` and `TowerSystem` can self-populate at `_ready()` without per-scene wiring.

## Acceptance Criteria

- [ ] `GameDataRegistry.get_all_monster_resources() -> Dictionary[StringName, MonsterResource]` added — returns the existing `_monster_resources` cache (already populated by `_load_monster_resources()`)
- [ ] `GameDataRegistry._load_tower_blueprints()` added, scanning `res://assets/data/towers/blueprints/*.tres` into a new `_tower_blueprints: Dictionary[StringName, TowerData]` keyed by `tower_id`, calling `TowerData.validate()` per file (log `push_error()`, do not abort boot — same pattern as `_load_monster_resources()`)
- [ ] `GameDataRegistry.get_tower_blueprint(tower_id: StringName) -> TowerData` and `get_all_tower_blueprints() -> Dictionary[StringName, TowerData]` added
- [ ] `assets/data/towers/blueprint_archer.tres` moved to `assets/data/towers/blueprints/blueprint_archer.tres` (matches the monsters/ directory convention; `perk_registry.tres` stays at its current path — it's a single registry file, not a per-tower blueprint)
- [ ] `MonsterManager._ready()`: if `_resource_table.is_empty()`, populate it from `GGameDataRegistry.get_all_monster_resources()`. If non-empty (test injection already happened before `add_child()`), leave it untouched — this is the same test-seam convention `GameDataRegistry._inject()` already establishes elsewhere in this codebase.
- [ ] `TowerSystem._ready()`: same `is_empty()` guard, populating `_tower_table` from `GGameDataRegistry.get_all_tower_blueprints()`
- [ ] `_player_gold` wiring is explicitly OUT OF SCOPE for this story (see Out of Scope) — do not add a hardcoded seed value to production code
- [ ] `src/gameplay/missions/the_gap/the_gap.gd`'s `_wire_monster_data()` and `_wire_tower_data()` methods are removed once the above loaders make them redundant — `the_gap.gd`'s `_player_gold = 500` debug seed is kept (still the only source until Resource Economy System exists) but moved to a clearly-marked scene-local stopgap comment, not deleted
- [ ] Full existing test suite still passes with 0 new failures and 0 new orphans (existing tests that inject `_resource_table`/`_tower_table` directly before `add_child()` must continue to work unchanged, per the `is_empty()` guard above)
- [ ] "The Gap" mission scene still boots and completes at least one wave cycle with real (registry-sourced, not scene-wired) monster and tower data — verify via live engine run (Godot MCP or manual editor run), not just headless tests

## Out of Scope

- `_player_gold` / Resource Economy System wiring — Resource Economy System is `Not Started` per `design/gdd/systems-index.md`; `TowerSystem._player_gold` has no production source until that system exists. This story only fixes the *tower blueprint data* loader, not the *player currency* source.
- Any change to `TowerData` or `MonsterResource`'s own fields or `validate()` logic
- Any new tower blueprints beyond the existing `blueprint_archer.tres` (content authoring is a separate concern)
- Skill/Ultimate data (`TD-hero-002`'s `SkillResource` pipeline) — a separate, related but distinct gap

## Files to Create or Modify

- `src/core/game_data_registry.gd` (extend — `_load_tower_blueprints()`, `get_tower_blueprint()`, `get_all_tower_blueprints()`, `get_all_monster_resources()`)
- `src/core/monster/monster_manager.gd` (`_ready()` — add `is_empty()`-guarded production load)
- `src/core/tower/tower_system.gd` (`_ready()` — add `is_empty()`-guarded production load)
- `assets/data/towers/blueprint_archer.tres` → moved to `assets/data/towers/blueprints/blueprint_archer.tres`
- `src/gameplay/missions/the_gap/the_gap.gd` (remove `_wire_monster_data()`/`_wire_tower_data()`, keep `_player_gold` seed with an updated comment)
- `tests/unit/game_data_registry/game_data_registry_test.gd` (extend — cover the new tower blueprint loader, mirroring existing monster-loader test cases: valid load, missing file, malformed file, duplicate `tower_id`)

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/game_data_registry/game_data_registry_test.gd` (extended) + a live engine verification that "The Gap" still boots and plays with registry-sourced data (per the last acceptance criterion above)

**Status**: [x] Verified — see Completion Notes below (9 new `game_data_registry_test.gd` tests + 1 each in `monster_spawn_test.gd`/`tower_placement_test.gd`, plus 3 live-engine Godot MCP sessions confirming self-populate, dictionary isolation, and a full SCOUT→WAVE_ACTIVE cycle with registry-sourced data)

## Dependencies

- Depends on: None
- Unlocks: any future mission scene beyond "The Gap" — currently every new mission scene would need to reinvent `the_gap.gd`'s `_wire_monster_data()`/`_wire_tower_data()` stopgap; this story makes that unnecessary
- Related, not blocking: `TD-hero-002` (SkillResource pipeline — same shape of gap, different system, not addressed here)

## Completion Notes
**Completed**: 2026-07-07
**Criteria**: 10/11 passing, 1 advisory (full automated regression suite not re-run — gdUnit4 headless runner unreachable from this environment, `TD-test-003`; substituted with targeted live-engine verification via the Godot MCP bridge for every code path this story touches)
**Deviations**: None blocking. Advisory: `tests/unit/monster/monster_spawn_test.gd` and `tests/unit/tower/tower_placement_test.gd` were modified beyond the original file list, both required by `/code-review` findings (missing TowerSystem self-populate coverage; a test-isolation regression where `_resource_table` briefly aliased the live `GameDataRegistry` cache). 5 new fixture `.tres` files added under `tests/fixtures/game_data_registry/tower_blueprints_*/`.
**Test Evidence**: `tests/unit/game_data_registry/game_data_registry_test.gd` (9 new tests) + `tests/unit/monster/monster_spawn_test.gd` (1 new test) + `tests/unit/tower/tower_placement_test.gd` (1 new test) + live engine verification (3 separate Godot MCP sessions confirming self-populate, dictionary isolation, and a full SCOUT→WAVE_ACTIVE cycle with registry-sourced data, zero runtime errors each time)
**Code Review**: Complete — round 1 found 1 real bug (shared mutable Dictionary between GameDataRegistry and its consumers, fixed via `.duplicate()`) and 2 real coverage/isolation gaps (both fixed); round 2 verdict APPROVED
**Tech debt closed**: `TD-data-001` (High severity) — marked closed in `docs/tech-debt-register.md` with full resolution notes
