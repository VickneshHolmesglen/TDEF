# Story 007: MonsterManager Standard Swarm Migration

> **Epic**: Hybrid Creature Swarm Rendering
> **Status**: In Review
> **Layer**: Core (monster simulation) + Presentation (swarm registration/sync)
> **Type**: Integration
> **Estimate**: 4-6 hours
> **Manifest Version**: 2026-07-13b
> **Last Updated**: 2026-08-24

## Context

**GDD**: None — infrastructure epic, no GDD linkage (see `EPIC.md`).
**Requirement**: None (zero TR-IDs).

**ADR Governing Implementation**: ADR-0038 (Hybrid Creature Swarm Rendering) — Accepted 2026-08-24; ADR-0006 (centralized `_physics_process`, 4/5-pass architecture) — Accepted, this story adds a use of the existing Pass 3c slot, never a new pass or per-node override.
**ADR Decision Summary**: `docs/architecture/hybrid-swarm-rendering-implementation-blueprint.md` §"Story 7 — MonsterManager standard swarm migration": "Add spawn handles and post-Pass-3 sync; migrate standard monsters; remove standard mesh companion construction/sync; preserve all simulation behavior." §"MonsterManager frame ordering" specifies the presentation-sync step must run after Pass 3 (movement/DEAD/BREACHED resolution) and before Pass 4, draining pending registrations, updating survivors, and unregistering resolved entities via swap-remove — never inserted inside damage/status/boss rules.

**Engine**: Godot 4.6.2 | **Risk**: LOW — no new engine API surface; this story wires already-verified pieces (Story 5's registry, Story 6's renderer) into already-shipped, already-tested gameplay code (`monster_manager.gd`, ADR-0006's passes).
**Engine Notes**: None new — `MultiMesh`/shader risk was closed by the pilot and Stories 5-6.

**Control Manifest Rules (this layer)**:
- Required: presentation sync stays inside `MonsterManager`'s existing centralized `_physics_process()` — reuses the pre-existing `_pass3c_visual_sync()` call site, does not add a new pass or per-node callback.
- Forbidden: no per-monster `_process()`/`_physics_process()` (ADR-0006's `per_monster_physics_process` forbidden pattern — verified by the pre-existing `monster_visual_companion_test.gd`'s own source-text-scan regression guard, which this story does not touch). No write-back from presentation into simulation state (`swarm_handle`/`monster_instance` are presentation-only fields, never read by any damage/movement/boss logic).
- Guardrail: registration/update/unregister calls are all `null`-safe against a missing `_swarm_renderer` (e.g. a unit test that never calls `set_swarm_renderer()`) — presentation absence must never break or alter simulation results, matching `monster_instance`'s own pre-existing "non-fatal to spawning" policy.

---

## Acceptance Criteria

*Sourced from the blueprint's Story 7 scope line, "MonsterManager frame ordering", and "Migration from shipped ADR-0037 monster code" steps 4 and 6:*

- [ ] `MonsterManager.set_swarm_renderer(renderer: MonsterSwarmRenderer3D) -> void` exists; the owning scene controller (`mission_scene.gd`, `the_gap.gd`) injects the real `MonsterSwarmRenderer3D` instance from its own `_ready()` (dependency injection, not a service-locator lookup — `src/CLAUDE.md`'s "prefer DI over singletons").
- [ ] `MonsterEntity` gains a `swarm_handle: MonsterPresentationHandle` field, mirroring the existing `monster_instance` cached-reference pattern.
- [ ] `_spawn_entity()` registers STANDARD/ELITE (tier 0/1) monsters with the swarm renderer at spawn time (seeding the correct position immediately, matching the legacy companion's own "no one-frame lag" contract) and stops building the legacy `_build_visual_companion()` 3D mesh for those tiers. BOSS (tier 2) is unchanged — still builds the legacy companion, does not register with the swarm.
- [ ] `MonsterInstance.configure()` gains a `build_legacy_3d_companion: bool = true` parameter; `MonsterManager` passes `tier == 2`. Every pre-existing call site keeps its original behavior (default `true`) unless explicitly opted out.
- [ ] `_pass3c_visual_sync()` (the existing post-Pass-3 sync call site) updates a STANDARD/ELITE entity's swarm batch slot via `update_creature()`; BOSS entities fall through to the unchanged legacy `sync_visual_companion_position()` path.
- [ ] Death (`_emit_death()`), breach (`_advance_entity()`'s BREACHED branch), and forced wave-end clearing (`_on_wave_completed()`, both `active_monsters` and `spawning_entities`) all call `unregister_creature()` for any entity with a live `swarm_handle` — a dense `MultiMesh` slot has no automatic free-on-node-destruction the way the legacy companion does, so this must be explicit (the exact gap the blueprint's own "MonsterManager frame ordering" section calls out).
- [ ] Existing monster movement/damage/breach/boss/wave test suites pass unmodified in behavior (ADR-0038 Validation Criteria item 1) — no gameplay-affecting change, only presentation routing.

---

## Implementation Notes

*Derived from the blueprint's Decision, "MonsterManager frame ordering", and "Migration from shipped ADR-0037 monster code" sections:*

- Registration happens in `_spawn_entity()` immediately after building `MonsterInstance`, **regardless of SPAWNING vs. ACTIVE lifecycle state** — mirrors the legacy companion's own "seeds the companion's initial position... on its very first visible frame" contract (`monster_instance.gd`'s own doc comment). This means a `SPAWNING` entity (no path found yet) also gets a `swarm_handle`, and `_on_wave_completed()`'s `spawning_entities` cleanup loop must unregister it too — verified against the live file, not assumed.
- `_pass3c_visual_sync()` was NOT split into two methods — it now branches per-entity (`swarm_handle != null` → swarm path, else → legacy path, else → no-op), staying "one additional method called from inside MonsterManager's own existing centralized `_physics_process()`" per its own doc comment's hard constraint, unchanged from Epic 15 Story 004's original framing.
- Atlas frame / hit-flash / status-mask / facing-variant are all hardcoded `0.0` in every `MonsterPresentationSnapshot` this story constructs — real per-instance channel wiring (hit-flash on damage, status-mask on DoT/slow, facing on movement direction) is Story 8's scope ("Hit/status/death presentation migration"), explicitly out of this story.
- **Real test-suite conflict found and resolved**: `monster_visual_companion_test.gd` (Epic 15 Story 004's own regression suite) built its fixture `MonsterResource` at `tier = 0` and asserted the legacy `VisualCompanion3D` subtree exists — exactly the behavior this story removes for STANDARD tier. Rather than deferring this to a hypothetical later cleanup story (the blueprint's step 8, "replace `monster_visual_companion_test.gd` expectations with swarm tests," is nominally Story 10's job), the fixture was changed to `tier = 2` (using the real `goblin_warlord_boss` fixture) — this preserves real, live regression coverage for the path that's still actually in use (BOSS) rather than leaving a test suite that would fail against Story 7's own intended change. A new suite (`monster_swarm_migration_test.gd`) covers the STANDARD/ELITE swarm path this story actually adds.
- `MonsterSwarmRenderer3D` has no dependency-injection seam of its own (Story 6's own scope decision) — tests that need one instantiate a real `monster_swarm_renderer_3d.tscn` and register against it directly, using the live `GGameDataRegistry` fixtures Story 5 added (`goblin_runner` standard, `goblin_warlord_boss` exceptional), matching this project's "end-to-end via the live autoload" precedent.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 8: real hit-flash/status-mask/facing-variant channel wiring (currently all `0.0`), replacing the per-monster `ShaderMaterial`/`Tween` hit-flash path for STANDARD/ELITE with manager/renderer-owned decay state.
- Story 9: BOSS migration to `BossCreaturePresenter3D` — BOSS keeps its exact pre-existing legacy companion behavior in this story, completely untouched.
- Story 10: retiring `enemy_ufo_a.tres`, removing any temporary migration switch, final `monster_visual_companion_test.gd` cleanup beyond the tier fixture change this story required.

---

## QA Test Cases

See `tests/integration/visual_presentation/monster_swarm_migration_test.gd`: STANDARD spawn registers with the swarm renderer and builds no legacy companion; BOSS spawn does the opposite (registers nothing, still builds the legacy companion); position sync moves the batch slot across real `_physics_process()` frames; death, breach, and forced wave-completion all unregister cleanly with no leaked batch slots (including the batch-death multi-kill path, mirroring `monster_visual_companion_test.gd`'s own AC-6 edge case).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/visual_presentation/monster_swarm_migration_test.gd` — must exist and pass.
- `tests/integration/visual_presentation/monster_visual_companion_test.gd` — pre-existing Epic 15 suite, must still pass after its tier-2 fixture change (regression guard for the legacy BOSS path).
- Pre-existing `tests/unit/monster/*` suites (movement, spawn, boss, status effects, death batching) — must still pass unmodified, per this story's own "preserve all simulation behavior" acceptance criterion.

**Status**: [x] Created/updated — not yet run against the pinned Godot binary this session (user explicitly asked to skip running tests this turn — see Completion Notes).

---

## Dependencies

- Depends on: Story 5 (creature-atlas data), Story 6 (`MonsterSwarmRenderer3D`'s register/update/unregister API)
- Unlocks: Story 8 (hit/status/death presentation migration builds on the registration this story adds), Story 9 (BOSS migration follows the same DI/injection pattern this story establishes)

## Completion Notes
**Completed**: Not yet — code and tests written 2026-08-24, gdUnit4 run against the pinned Godot 4.6.2.stable binary has not been performed this session (user explicitly said to skip running tests). Run all three listed test suites before closing this story via `/story-done`.
**Criteria**: 7/7 authored, 0/7 live-verified
**Deviations**: `monster_visual_companion_test.gd`'s fixture tier changed from 0 to 2 (documented above) — a necessary consequence of this story's own scope, not a deviation from the blueprint's intent.
**Test Evidence**: written, not yet executed.
**Code Review**: Not yet run.
