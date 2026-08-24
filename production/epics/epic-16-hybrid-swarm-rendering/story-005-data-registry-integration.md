# Story 005: Data Registry Integration

> **Epic**: Hybrid Creature Swarm Rendering
> **Status**: In Review
> **Layer**: Presentation (new data type; consumed by MonsterSwarmRenderer3D in Story 6+)
> **Type**: Logic
> **Estimate**: 2-4 hours
> **Manifest Version**: 2026-07-13b
> **Last Updated**: 2026-08-24

## Context

**GDD**: None — infrastructure epic, no GDD linkage (see `EPIC.md`).
**Requirement**: None (no TR registry entry — this epic has zero TR-IDs, same as Epic 15). Acceptance criteria below are sourced from ADR-0038's Decision and Validation Criteria sections and the blueprint's "Data contracts" section instead.

**ADR Governing Implementation**: ADR-0038 (Hybrid Creature Swarm Rendering) — Accepted 2026-08-24
**ADR Decision Summary**: Introduces `CreatureAtlasMappingResource` (`class_name`, extends `Resource`, `GameDataRegistry`-backed, `validate()` per ADR-0009's convention, mirroring `VisualMeshMappingResource`) describing a creature family's atlas texture, grid, animation clips, body dimensions/foot anchor, batch-key components, presentation class, and status-mask schema version. `docs/architecture/hybrid-swarm-rendering-implementation-blueprint.md` §"Story 5 — Data registry integration": "Implement mapping Resource, fixtures, validation, duplicate handling, and registry lookup without changing live monsters."

**Engine**: Godot 4.6.2 | **Risk**: LOW for this story specifically (pure data Resource + registry wiring, no rendering/scene-tree interaction, no `MonsterManager`/`MonsterInstance` changes)
**Engine Notes**: Typed `Array[CreatureAnimationClip]` export and typed `Dictionary[StringName, CreatureAtlasMappingResource]` registry cache follow the same patterns already verified working throughout `game_data_registry.gd` (16 existing loaders of this shape). `PlaceholderTexture2D` (used only in test fixtures, not production `.tres` files) is a stable pre-4.x `Texture2D` subtype — no post-cutoff risk.

**Control Manifest Rules (this layer)**:
- Required: `Resource` subclass + `GameDataRegistry` loading + `validate() -> Array[String]` boot-time validation — same convention as every other data Resource (`VisualMeshMappingResource`, `RecipeResource`, `ItemDefinitionResource`), source: ADR-0009.
- Forbidden: N/A for this story (no per-node process overrides, no rendering code yet — that is Story 6+).
- Guardrail: N/A (no runtime performance surface in this story — pure data + boot-time load).

---

## Acceptance Criteria

*Sourced from ADR-0038's Decision (Per-instance channel budget, Body and shadow submissions, Bosses/elites/Menagerie) and the blueprint's Data contracts section:*

- [ ] `CreatureAtlasMappingResource` exists with all fields the blueprint's `CreatureAtlasMappingResource` contract requires: creature/family-atlas ID, atlas `Texture2D`, positive atlas columns/rows and frame count within grid capacity, named animation clips (start frame, frame count, positive FPS, loop flag), world width/height and foot-anchor offset, mesh-layout/shader-variant/render-mode IDs, standard-vs-exceptional presentation class, batch-capacity requirement, and status-mask schema version.
- [ ] `CreatureAnimationClip` exists as its own `Resource` subclass (clip_name, start_frame, frame_count, fps, loop) with its own `validate()`.
- [ ] `validate() -> Array[String]` fails for every case the blueprint names: missing texture, invalid frame ranges (non-positive, or exceeding grid capacity, or a clip running past the mapping's frame_count), non-positive dimensions/FPS, unknown render mode, and an exceptional-class asset with no approved presenter class.
- [ ] `validate()` also rejects duplicate animation clip names within one mapping and a null entry in `animation_clips` (defensive — not explicitly named by the blueprint but a real authoring-error case a `.tres` file could produce).
- [ ] `GameDataRegistry` scans `assets/data/creature_atlases/` at boot, loads each `.tres` as `CreatureAtlasMappingResource` keyed by `creature_id`, validates it (push_error per violation, does-not-abort — same policy as all 17 other `GameDataRegistry` loaders), and logs+overwrites on duplicate `creature_id` (last file wins, matching every existing loader's documented behavior).
- [ ] `GameDataRegistry.get_creature_atlas_mapping(creature_id) -> CreatureAtlasMappingResource` and `get_all_creature_atlas_mappings() -> Dictionary[StringName, CreatureAtlasMappingResource]` exist, following the exact `get_visual_mesh_mapping()`/`get_all_visual_mesh_mappings()` pattern (O(1) lookup, null-safe, shallow-copy `get_all_*`).
- [ ] At least one real standard-class `.tres` mapping and one real exceptional-class `.tres` mapping exist under `assets/data/creature_atlases/`, both resolving through the live `GGameDataRegistry` autoload with `validate()` returning `[]` — proving the full load→validate→resolve path end-to-end, not just in isolation (mirrors Epic 15 Story 001's AC-5).

---

## Implementation Notes

*Derived from ADR-0038's Decision and the blueprint's Data contracts / File and module ownership sections:*

- Follow `VisualMeshMappingResource`'s exact file structure, doc-comment style, and `GameDataRegistry` boot-load pattern (17th loader added to that file, not a new loading mechanism).
- `CreatureAnimationClip` is its own `Resource` subclass (not an inline struct) so `.tres` files can embed it as a `[sub_resource]`, matching the project's existing nested-Resource convention (`TowerBlueprintData`'s Foundation/Weapon/Focus/Power sub-resources).
- `presentation_class` uses two string constants (`PRESENTATION_CLASS_STANDARD` / `PRESENTATION_CLASS_EXCEPTIONAL`) rather than a raw `String`/`StringName` with no validation — `validate()` rejects any other value.
- `render_mode_id` is similarly constrained to `RENDER_MODE_ALPHA_SCISSOR` / `RENDER_MODE_ALPHA_HASH` per ADR-0038's "Body and shadow submissions" (alpha blend is explicitly reserved for separately budgeted VFX, not standard creature bodies — not a valid value here).
- `batch_capacity_requirement` validation only applies to standard-class creatures (exceptional creatures don't share a `MultiMesh` batch at all, per ADR-0038's Bosses/elites section) — the check is skipped, not zero-forced, when `presentation_class == PRESENTATION_CLASS_EXCEPTIONAL`.
- The two real fixture `.tres` files (`goblin_runner.tres`, `goblin_warlord_boss.tres`) reuse existing single-frame placeholder art (`assets/art/monsters/goblin_runner.png`, `goblin_warlord_boss.png`) as a 1x1-grid "atlas" — this is a data-layer proof fixture only, **not** final swarm-ready art. Real multi-frame atlas sheets are Codex's future generation work per `codex-art-overhaul.md`'s division of labor; do not treat these two files as ship-ready content.
- Do not add any rendering/scene-tree/`MonsterManager` code in this story — this is the data-layer foundation only, per the blueprint's own Story 5 scope ("without changing live monsters"). `MonsterSwarmRenderer3D` consuming this data is Story 6's scope.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 6: `MonsterSwarmRenderer3D`, `PresentationRoot3D` scene wiring, resolving mappings into live `MultiMesh` batches.
- Story 7: `MonsterManager`/`MonsterInstance` changes of any kind — this story does not touch either file.
- Story 9: `BossCreaturePresenter3D` — this story only names `approved_presenter_class` as a string field; the class itself does not exist yet.

---

## QA Test Cases

**AC-1, AC-2, AC-3, AC-4 (Resource shape + validation)**: see `tests/unit/visual_presentation/creature_atlas_mapping_resource_test.gd` — one test per named failure mode (missing texture, non-positive/out-of-range frame fields, non-positive world dimensions, unrecognized render mode, unrecognized presentation class, exceptional-without-presenter, non-positive batch capacity for standard, non-positive schema version, null/duplicate/out-of-range animation clips), plus a minimal-valid-resource pass case and a valid-with-clips pass case.

**AC-5 (GameDataRegistry boot integration)**:
- Given: a `.tres` file with an invalid `CreatureAtlasMappingResource` (e.g. null `atlas_texture`) placed in the loaded data directory
- When: `GameDataRegistry` boots
- Then: boot fails loudly (matching the existing failure behavior for every other invalid `GameDataRegistry`-loaded Resource — not a new failure mode)
- Edge cases: two invalid files at once (both errors surfaced); a `.tres` of the wrong Resource subtype entirely (load-time cast failure, not a validation failure); duplicate `creature_id` across two files (overwrite + push_error, does not crash)

**AC-6 (end-to-end real mapping)**:
- Given: the two real `.tres` mappings this story adds (`goblin_runner.tres` standard, `goblin_warlord_boss.tres` exceptional)
- When: `GGameDataRegistry` (live autoload) is queried for each `creature_id`
- Then: returns a `CreatureAtlasMappingResource` whose `validate()` is `[]`, with `presentation_class` matching the expected constant for each

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/visual_presentation/creature_atlas_mapping_resource_test.gd` — must exist and pass, covering AC-1 through AC-6 above.

**Status**: [x] Created — not yet run against the pinned Godot binary (see Completion Notes).

---

## Dependencies

- Depends on: None (first production story in this epic — Stories 1-4 were prototype-only, not tracked as stories per `.claude/rules/prototype-code.md`)
- Unlocks: Story 6 (`MonsterSwarmRenderer3D` resolves mappings created here), Story 9 (`BossCreaturePresenter3D` reads `approved_presenter_class` from exceptional-class mappings)

## Completion Notes
**Completed**: Not yet — code and tests written 2026-08-24, gdUnit4 run against the pinned Godot 4.6.2.stable binary has not been performed this session (per this project's standing "no unrequested testing" instruction — the user did not ask for a test run this turn). Run `tests/unit/visual_presentation/creature_atlas_mapping_resource_test.gd` before closing this story via `/story-done`.
**Criteria**: 6/6 authored, 0/6 live-verified
**Deviations**: None from the blueprint's Story 5 scope.
**Test Evidence**: `tests/unit/visual_presentation/creature_atlas_mapping_resource_test.gd` — written, not yet executed.
**Code Review**: Not yet run.
