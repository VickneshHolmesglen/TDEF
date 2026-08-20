# Story 001: Visual Mesh Mapping Foundation

> **Epic**: 3D Visual Presentation Layer — Phase 1
> **Status**: Complete
> **Layer**: Presentation (new data type; consumed by Core-layer entity scenes)
> **Type**: Logic
> **Estimate**: 2-4 hours
> **Manifest Version**: 2026-07-13b
> **Last Updated**: 2026-08-20

## Context

**GDD**: None — infrastructure epic, no GDD linkage (see `EPIC.md`).
**Requirement**: None (no TR registry entry — this epic has zero TR-IDs). Acceptance criteria below are sourced directly from ADR-0037's Decision, Key Interfaces, and Validation Criteria sections instead.

**ADR Governing Implementation**: ADR-0037 (Visual Presentation 3D Companion Layer) — Accepted
**ADR Decision Summary**: Introduces a `VisualMeshMappingResource` (`class_name`, extends `Resource`, `GameDataRegistry`-backed, `validate()` per ADR-0009's convention) mapping `entity_or_component_id: StringName` to a **typed** `mesh_scene: PackedScene` export (not a string path — matches `ItemDefinitionResource.icon: Texture2D`'s existing precedent, confirmed by godot-specialist review and now registered as `resource_asset_reference_fields` in `docs/registry/architecture.yaml`). Also introduces the shared `map_to_3d(pos2d: Vector2, layer_height: float) -> Vector3` pure function: `Vector3(pos2d.x, layer_height, pos2d.y)`.

**Engine**: Godot 4.6.2 | **Risk**: LOW for this story specifically (pure data Resource + pure function, no rendering/scene-tree interaction — the MEDIUM rating on ADR-0037 as a whole concerns later phases' rendering changes, not this story)
**Engine Notes**: Typed `Dictionary[StringName, int]`-style typed exports are already verified working in this project (per `VERSION.md`); `PackedScene` as a typed `@export` field is a stable pre-4.x API, no post-cutoff risk.

**Control Manifest Rules (this layer)**:
- Required: `Resource` subclass + `GameDataRegistry` loading + `validate() -> Array[String]` boot-time validation — same convention as every other data Resource (`RecipeResource`, `ItemDefinitionResource`), source: ADR-0009.
- Forbidden: N/A for this story (no per-node process overrides, no rendering code yet).
- Guardrail: N/A (no runtime performance surface in this story — pure data + pure function).

---

## Acceptance Criteria

*Sourced from ADR-0037 (Decision, Key Interfaces, Validation Criteria):*

- [ ] `VisualMeshMappingResource` class exists with fields `entity_or_component_id: StringName` and `mesh_scene: PackedScene` (typed export, not a string path).
- [ ] `validate() -> Array[String]` confirms `entity_or_component_id` is non-empty and `mesh_scene` is assigned (non-null); returns a populated array (not silently passing) for either violation.
- [ ] `GameDataRegistry` loads and validates all `VisualMeshMappingResource` `.tres` files at boot, alongside every other data Resource type — a missing/invalid mesh mapping fails boot loudly (per ADR-0037's Risks section: "rather than silently falling back to invisible").
- [ ] Shared `map_to_3d(pos2d: Vector2, layer_height: float) -> Vector3` function exists and returns `Vector3(pos2d.x, layer_height, pos2d.y)` exactly — pure function, no side effects, no heap allocation (per `engine-code.md`'s zero-allocation-hot-path rule, since this will be called every frame per entity in later stories).
- [ ] At least one real `.tres` mapping entry exists (e.g. `assets/data/visual_meshes/tower_round.tres`, a new file this story creates) whose `mesh_scene` points at the imported `PackedScene` for `res://assets/Tower Defense Models/GLB format/tower-round-base.glb` (the actual on-disk source asset — verify this exact path before wiring the reference), proving the full load→validate→resolve path works end-to-end, not just in isolation.

---

## Implementation Notes

*Derived from ADR-0037's Decision and Key Interfaces:*

- Follow `RecipeResource`/`ItemDefinitionResource`'s exact existing file structure and boot-load pattern in `GameDataRegistry` — do not invent a new loading mechanism.
- `mesh_scene: PackedScene` must be a typed `@export`, not `@export var mesh_scene_path: String`. This was explicitly corrected during ADR-0037's engine-specialist review — do not revert to the string-path form.
- The real source asset for the proof-of-pipeline `.tres` (AC-5) lives at `res://assets/Tower Defense Models/GLB format/tower-round-base.glb` — confirm this path resolves in the editor before wiring `mesh_scene` to it; the folder name contains spaces, which Godot handles fine in `res://` paths but is worth double-checking on first use.
- `map_to_3d()`'s exact location (which file/class it lives in) is not fixed by the ADR — pick something consistent with this project's existing shared-utility conventions (e.g. alongside other pure math helpers, not buried inside a specific entity script, since Stories 002-006 all call it).
- Do not add any rendering/scene-tree code in this story — this is the data-layer foundation only. `Node3D`/`MeshInstance3D` instantiation from these mappings is Story 002's scope onward.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: actually instantiating a `MeshInstance3D` from a `VisualMeshMappingResource` mapping and attaching it to `TheGap`'s `GridVisual`.
- Stories 003-006: `Camera3D`, per-entity-type `VisualCompanion3D` nodes, and the centralized-pass sync calls to `map_to_3d()`.

---

## QA Test Cases

**AC-1 & AC-2 (Resource shape + validation)**:
- Given: a `VisualMeshMappingResource` instance with `entity_or_component_id = &""` and `mesh_scene = null`
- When: `validate()` is called
- Then: returns a non-empty `Array[String]` containing an error for each violated field
- Edge cases: valid `entity_or_component_id` but null `mesh_scene` (should still fail); valid `mesh_scene` but empty id (should still fail); both valid (should return `[]`)

**AC-3 (GameDataRegistry boot integration)**:
- Given: a `.tres` file with an invalid `VisualMeshMappingResource` (e.g. null `mesh_scene`) placed in the loaded data directory
- When: `GameDataRegistry` boots
- Then: boot fails loudly (matching the existing failure behavior for an invalid `RecipeResource`/`ItemDefinitionResource` — not a new failure mode, reuse the existing one)
- Edge cases: multiple invalid files at once (all errors surfaced, not just the first)

**AC-4 (map_to_3d pure function)**:
- Given: `pos2d = Vector2(3.5, -2.0)`, `layer_height = 0.21`
- When: `map_to_3d(pos2d, layer_height)` is called
- Then: returns `Vector3(3.5, 0.21, -2.0)` exactly
- Edge cases: `Vector2.ZERO` input; negative `layer_height`; repeated calls produce identical output (pure function, no hidden state)

**AC-5 (end-to-end real mapping)**:
- Given: a real `.tres` mapping entry for one placeholder mesh
- When: `GameDataRegistry` is queried for that `entity_or_component_id`
- Then: returns a `VisualMeshMappingResource` whose `mesh_scene.instantiate()` produces a valid `Node3D`-derived node with no runtime error

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/visual_presentation/visual_mesh_mapping_resource_test.gd` — must exist and pass, covering AC-1 through AC-5 above.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (first story in the epic)
- Unlocks: Story 002, and transitively Stories 003-006 (all call `map_to_3d()` and resolve mesh mappings through this story's `VisualMeshMappingResource`)

## Completion Notes
**Completed**: 2026-08-20
**Criteria**: 5/5 passing
**Deviations**: None
**Test Evidence**: `tests/unit/visual_presentation/visual_mesh_mapping_resource_test.gd` — 18/18 passing
**Code Review**: Complete — APPROVED (godot-gdscript-specialist: CLEAN; qa-tester: TESTABLE, one gap found and fixed — duplicate-key push_error was asserted by name but not content)
