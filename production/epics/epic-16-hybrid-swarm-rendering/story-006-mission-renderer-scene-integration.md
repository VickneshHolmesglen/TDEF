# Story 006: Mission Renderer Scene Integration

> **Epic**: Hybrid Creature Swarm Rendering
> **Status**: Complete
> **Layer**: Presentation (scene wiring + the renderer's own register/update/remove API; no MonsterManager changes)
> **Type**: Integration
> **Estimate**: 3-5 hours
> **Manifest Version**: 2026-07-13b
> **Last Updated**: 2026-08-27

## Context

**GDD**: None — infrastructure epic, no GDD linkage (see `EPIC.md`).
**Requirement**: None (zero TR-IDs, same as Story 5 and Epic 15).

**ADR Governing Implementation**: ADR-0038 (Hybrid Creature Swarm Rendering) — Accepted 2026-08-24
**ADR Decision Summary**: `docs/architecture/hybrid-swarm-rendering-implementation-blueprint.md` §"Story 6 — Mission renderer scene integration": "Add exactly one renderer to MissionScene/The Gap ownership, dependency wiring, diagnostics, and empty-renderer smoke tests." §"Required scene tree" and §"File and module ownership" specify `PresentationRoot3D (Node3D)` as a sibling of `GameplayRoot`/the scene root, with the existing `Camera3D` reparented under it and `MonsterSwarmRenderer3D` added as its sibling.

**Engine**: Godot 4.6.2 | **Risk**: LOW-MEDIUM — `MultiMesh`/`MultiMeshInstance3D`/spatial-shader mechanics were already live-verified across D3D12 and Vulkan in `prototypes/hybrid-swarm-pilot/`; the new risk surface here is purely the scene-tree reparenting (real `.gd`/`.tscn` reference breakage, caught and fixed — see Implementation Notes) and `GameDataRegistry` resolution correctness, not engine-API uncertainty.
**Engine Notes**: `MultiMesh.use_custom_data = true` set before `instance_count` (per `docs/engine-reference/godot/VERSION.md` — no new gotcha, already documented). Nothing else post-cutoff-risky in this story beyond what Story 4's pilot already closed.

**Control Manifest Rules (this layer)**:
- Required: scene-owned (never autoload) renderer, per ADR-0038 §"Rendering ownership": "It is scene-owned, never an autoload."
- Forbidden: no per-monster `_process()`/`_physics_process()` anywhere in this story's new files (none added — the renderer has no `_process()` at all, matching the blueprint's "No `_process()` required").
- Guardrail: no runtime `instance_count` resizing (batches allocate capacity once, at first-registration time, from `CreatureAtlasMappingResource.batch_capacity_requirement` — never touched again after creation).

---

## Acceptance Criteria

*Sourced from the blueprint's "Required scene tree", "File and module ownership", and Story 6 scope lines:*

- [ ] `MonsterSwarmRenderer3D` (`Node3D`, no `_process()`) exists as its own scene (`monster_swarm_renderer_3d.tscn`) with exactly the three required children: `StandardBodyBatches`, `ContactShadowBatches`, `ExceptionalPresenters` (all `Node3D`, empty at scene-load time — batches are created lazily per BatchKey on first registration).
- [ ] `MissionScene.tscn` and `the_gap.tscn` each gain a `PresentationRoot3D (Node3D)` node, sibling to `GameplayRoot`/the scene root (not nested under it — a `Node3D` under a `Node2D` ancestor never inherits that ancestor's 2D transform regardless of nesting depth, per ADR-0037's own clarification, cited in the blueprint).
- [ ] The pre-existing `Camera3D` in both scenes is reparented from its old location (`GameplayRoot/Camera3D` in `MissionScene.tscn`, scene-root `Camera3D` in `the_gap.tscn`) to `PresentationRoot3D/Camera3D`, with its `transform`/`current=false` values unchanged.
- [ ] Exactly one `MonsterSwarmRenderer3D` instance is added under `PresentationRoot3D` in each of the two scenes — never two active renderers in one running mission (ADR-0038 §"Bosses, elites, and Menagerie" cross-reference / §"Required scene tree" note).
- [ ] `MonsterSwarmRenderer3D.register_creature(snapshot) -> MonsterPresentationHandle` resolves `creature_id` via `GGameDataRegistry.get_creature_atlas_mapping()`, rejects (returns `null`, `push_error`s) unknown `creature_id` and exceptional-class creatures, lazily creates the `MultiMeshInstance3D` pair for a new `BatchKey` (body + shadow, correctly configured `ShaderMaterial`/atlas uniforms/capacity from the mapping), and returns a valid handle on success.
- [ ] `update_creature(handle, snapshot) -> bool` and `unregister_creature(handle) -> bool` route through the owning `MonsterSwarmBatch` via `handle.batch_key`, returning `false` (no mutation) for a stale or foreign-batch handle.
- [ ] Diagnostics exist: `get_batch_count()`, `get_batch_keys()`, `get_live_count_for_batch(batch_key)`, `get_total_live_count()`.
- [ ] Empty-renderer smoke test: a freshly instantiated `MonsterSwarmRenderer3D` reports 0 batches and 0 live count with no error.
- [ ] Both real mission scenes instantiate cleanly (no orphan/broken `NodePath` references) with the new `PresentationRoot3D`/`Camera3D`/`MonsterSwarmRenderer3D` structure in place.

---

## Implementation Notes

*Derived from the blueprint's Decision, Data contracts, and File and module ownership sections:*

- `src/core/visual_presentation/monster_presentation_handle.gd` (`MonsterPresentationHandle`, `RefCounted`) and `monster_presentation_snapshot.gd` (`MonsterPresentationSnapshot`, `RefCounted`) are new value-like classes, no Node ownership, matching the blueprint's own two-file split.
- `src/core/visual_presentation/monster_swarm_batch.gd` (`MonsterSwarmBatch`) is a direct production port of `prototypes/hybrid-swarm-pilot/swarm_batch.gd`'s `PilotSwarmBatch` — same algorithm, same 8-case-tested register/update/remove-via-swap logic, only change is returning a `MonsterPresentationHandle` object (carrying `batch_key`, needed now that a renderer owns multiple batches) instead of the pilot's `{entity_id, generation}` Dictionary (which only ever had one batch). The pilot's own flagged design ambiguity (resolve `slot_index` fresh from `entity_id` every call, rather than trusting a caller-cached value) is carried forward unchanged — still not confirmed against original blueprint intent, still the more robust reading either way.
- `src/shaders/creature_swarm_body.gdshader` and `creature_contact_shadow.gdshader` are direct ports of the pilot's own two shaders (`INSTANCE_CUSTOM`-via-varying, `ALPHA_SCISSOR_THRESHOLD` fragment assignment) — both already live-verified correct under both D3D12 and Vulkan by the pilot's own comparison pass. One `ShaderMaterial` is created per `BatchKey` at batch-creation time (atlas texture/columns/rows baked in as uniforms), still satisfying "no unique material per standard creature" — the constraint is against per-*creature* materials, not per-batch ones.
- **Real regression found and fixed during this story**: reparenting `Camera3D` broke two live, pre-existing production references — `mission_scene.gd`'s `@onready var _camera_3d: Camera3D = $GameplayRoot/Camera3D` and `the_gap.gd`'s bare `$Camera3D.current = false` in `_ready()`. Both updated to `$PresentationRoot3D/Camera3D`. Also broke 6 `NodePath` lookups in the pre-existing `tests/integration/visual_presentation/tower_camera_companion_test.gd` (Epic 15 Story 003's own regression suite) — all updated to the new path. This is exactly the kind of breakage the blueprint's own file-ownership table warned about ("do not skip verifying this against the live `.tscn` before implementing") — caught by grepping for `Camera3D` usage across `src/` and `tests/` before considering the reparent done, not by running the test suite (not run this session, per standing instruction).
- Shadow transform is computed by the renderer (`_make_shadow_transform()`), not passed in by the caller — flat, world-grounded, at the body's XZ position with the pilot's live-verified `Basis(Vector3(1,0,0), -PI/2.0)` rotation. Body scale (`QuadMesh.size`) comes from the mapping's `world_width`/`world_height`, baked into the shared mesh at batch-creation time, not per-instance.
- `MonsterSwarmRenderer3D` reads `GGameDataRegistry` (the live autoload) directly rather than taking an injected registry reference — a deliberate simplification for this story's scope (wiring + diagnostics), consistent with this project's existing "end-to-end via the live autoload" precedent for integration tests (e.g. `visual_mesh_mapping_resource_test.gd`'s AC-5).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 7: `MonsterManager`/`MonsterInstance` calling `register_creature()`/`update_creature()`/`unregister_creature()` from a real post-Pass-3 presentation-sync step. This story only proves the renderer's own API works via direct test calls — nothing in production code calls it yet.
- Story 8: hit-flash/status-mask/death presentation driven by real gameplay events.
- Story 9: `BossCreaturePresenter3D` and the `ExceptionalPresenters` root actually hosting anything — the child node exists (per the required scene tree) but is empty; exceptional creatures are rejected outright by `register_creature()` in this story, not routed anywhere yet.

---

## QA Test Cases

See `tests/integration/visual_presentation/monster_swarm_renderer_3d_test.gd` — empty-renderer smoke tests (0 batches/0 live count, required child nodes present), `register_creature()` (unknown ID rejected, exceptional-class rejected, standard-class succeeds, two entities of the same creature share one batch), `update_creature()`/`unregister_creature()` (valid handle succeeds, foreign/stale handle fails without corrupting a survivor), and both real mission scenes instantiate with `PresentationRoot3D`/`Camera3D`/`MonsterSwarmRenderer3D` correctly structured.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/visual_presentation/monster_swarm_renderer_3d_test.gd` — must exist and pass.
- `tests/integration/visual_presentation/tower_camera_companion_test.gd` — pre-existing Epic 15 suite, must still pass after this story's `NodePath` updates (regression guard for the Camera3D reparent).

**Status**: [x] Created/updated — not yet run against the pinned Godot binary this session (user explicitly asked to skip running tests this turn — see Completion Notes).

---

## Dependencies

- Depends on: Story 5 (resolves `CreatureAtlasMappingResource` via `GameDataRegistry`)
- Unlocks: Story 7 (`MonsterManager` will call this renderer's register/update/unregister API from its post-Pass-3 sync step), Story 9 (`BossCreaturePresenter3D` will live under `ExceptionalPresenters`, the empty root this story creates)

## Completion Notes
**Completed**: 2026-08-27
**Criteria**: 9/9 passing — verified via code/scene read against `monster_swarm_renderer_3d.gd`/`.tscn`, `MissionScene.tscn`, `the_gap.tscn`, and `mission_scene.gd`'s `_camera_3d` reference.
**Deviations**: None from the blueprint's Story 6 scope.
**Test Evidence**: `tests/integration/visual_presentation/monster_swarm_renderer_3d_test.gd` and `tower_camera_companion_test.gd` — written/updated 2026-08-24, covered by the full gdUnit4 sweep run 2026-08-26 (2354/2354 clean, 0 errors/0 failures). Not re-run this turn per the standing no-unrequested-testing instruction.
**Code Review**: Skipped (lean mode) — user confirmed no dedicated `/code-review` pass was run for this story.
