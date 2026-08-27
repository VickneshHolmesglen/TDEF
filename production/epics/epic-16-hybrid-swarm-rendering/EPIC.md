# Epic: Hybrid Creature Swarm Rendering

> **Layer**: Presentation (data layer first, then MonsterManager/renderer integration)
> **GDD**: None — infrastructure epic, not GDD-driven. Same rationale as Epic 15 (ADR-0037): ADR-0038's own "GDD Requirements Addressed" is N/A, this is a presentation-layer technology change the user requested via the art overhaul.
> **Architecture Module**: New — `src/core/visual_presentation/` (extends the Epic 15 module), `src/shaders/creature_swarm_body.gdshader` + `creature_contact_shadow.gdshader`, plus a bounded, late-story change to `src/core/monster/monster_manager.gd` and `monster_instance.gd`. See ADR-0038's Architecture Diagram.
> **Status**: All 6 stories (5-10) complete. The full architecture migration is code-complete AND every story formally closed via `/story-done`. **Live-verified 2026-08-27**: full gdUnit4 suite run against the pinned Godot binary (2355 test cases, 0 errors, 1 failure), plus a targeted live Godot MCP session confirming the Story 8 hit-flash pipeline renders correctly under the real renderer. The 1 test failure (`monster_swarm_channel_test.gd`) was root-caused to a headless-CI/`RendererDummy` `MultiMesh` test-infrastructure gap (`TD-test-007`, `docs/tech-debt-register.md`), not a code regression. **All 6 stories (005-010) formally closed via `/story-done` 2026-08-27** (all COMPLETE/COMPLETE WITH NOTES — see each story's own Completion Notes). Stories 1-4 were proven in `prototypes/hybrid-swarm-pilot/` (prototype code, not tracked as production stories per `.claude/rules/prototype-code.md` — findings feed this epic, the prototype itself is not migrated).
> **Stories**: 6 production stories planned (5-10, per the blueprint's numbering — 1-4 were pilot-only)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 005 | [Data Registry Integration](story-005-data-registry-integration.md) | Logic | Complete | ADR-0038 |
| 006 | [Mission Renderer Scene Integration](story-006-mission-renderer-scene-integration.md) | Integration | Complete | ADR-0038 |
| 007 | [MonsterManager Standard Swarm Migration](story-007-monster-manager-standard-swarm-migration.md) | Integration | Complete | ADR-0038, ADR-0006 |
| 008 | [Hit/Status/Death Presentation Migration](story-008-hit-status-death-presentation-migration.md) | Integration | Complete | ADR-0038 |
| 009 | [Boss/Elite Exceptional Path](story-009-boss-elite-exceptional-path.md) | Integration | Complete | ADR-0038 |
| 010 | [Cleanup and Production Gate](story-010-cleanup-and-production-gate.md) | Integration | Complete | ADR-0038 |

## Overview

This epic replaces ADR-0037's shipped per-monster 3D mesh companion (Epic 15 Story 004) with ADR-0038's batched `MultiMesh` swarm renderer for standard creatures, per the art overhaul's locked 3D-world/2D-creatures medium split (`design/art/codex-art-overhaul.md` §1). Hero, towers, terrain, buildings, and projectiles are untouched — ADR-0037 remains authoritative for all of those; only the monster/creature rendering path changes.

Stories 1-4 of the underlying 10-story blueprint (`docs/architecture/hybrid-swarm-rendering-implementation-blueprint.md`) were built and live-verified as a throwaway prototype (`prototypes/hybrid-swarm-pilot/`), per this project's Prototype Code Standards — that work proved the rendering approach (batching, shaders, dense-handle lifecycle, D3D12/Vulkan parity) but is not migrated directly into production code. This epic starts at Story 5, the first story that touches `src/` and `assets/data/`.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| ADR-0038: Hybrid Creature Swarm Rendering | Standard monsters render via preallocated `MultiMeshInstance3D` batches keyed by `(creature_family_atlas_id, mesh_layout_id, material_shader_variant_id, render_mode_id)`, driven by a dense-handle register/update/swap-remove lifecycle synced once per frame after ADR-0006 Pass 3. Bosses/elites use a capped individual `Sprite3D`/`AnimatedSprite3D` presenter instead. | Was HIGH pre-pilot; downgraded — pilot evidence closed every Validation Criteria item except macOS (dropped from scope, no macOS hardware/target for this project). |

## GDD Requirements

None — zero TR-IDs, same as Epic 15. Completion is measured against ADR-0038's own **Validation Criteria** section.

## Story Breakdown (blueprint-numbered — Stories 1-4 are prototype-only, not in this epic)

| # | Story | Depends on | Scope |
|---|-------|------------|-------|
| 5 | Data registry integration | — | `CreatureAtlasMappingResource`, `CreatureAnimationClip`, `GameDataRegistry` loader/lookup, fixtures, validation, duplicate handling. No live monster changes. |
| 6 | Mission renderer scene integration | 5 | Add `PresentationRoot3D`/`MonsterSwarmRenderer3D` to `MissionScene.tscn`/`the_gap.tscn`, empty-renderer smoke tests. |
| 7 | MonsterManager standard swarm migration | 5, 6 | Spawn handles, post-Pass-3 sync, remove `_build_visual_companion()` mesh path for standard monsters. Preserve all simulation behavior. |
| 8 | Hit/status/death presentation migration | 7 | Replace per-node hit material/Tween with the four-channel `INSTANCE_CUSTOM` contract; capped death presentation if required. |
| 9 | Boss/elite exceptional path | 5 | `BossCreaturePresenter3D` capped pool, reproduce required layered boss animation without callbacks. |
| 10 | Cleanup and production gate | 7, 8, 9 | Remove migration switch, retire `enemy_ufo_a.tres` (after `rg` proves no remaining reference), full regression, final art-pipeline acceptance capture. |

## Definition of Done

**Not yet started (this epic just began):**
- All 6 stories implemented, code-reviewed, and closed via `/story-done`.
- Existing monster movement/damage/death/breach/boss/wave tests pass unmodified (ADR-0038 Validation Criteria item 1).
- Whole-scene draw calls/frame timing at realistic ~100+ monster scale, measured against a real mission (not just the pilot's synthetic scatter).
- `enemy_ufo_a.tres` retired only after `rg` confirms zero remaining references.

## Next Step

Story 5 (data registry integration) is in progress. Story 6 requires deciding `MissionScene.tscn`/`the_gap.tscn`'s exact `PresentationRoot3D` reparenting per the blueprint's own verified-against-live-file notes (`hybrid-swarm-rendering-implementation-blueprint.md` §"File and module ownership") — do not skip re-verifying against the live `.tscn` before implementing, per that document's own warning.
