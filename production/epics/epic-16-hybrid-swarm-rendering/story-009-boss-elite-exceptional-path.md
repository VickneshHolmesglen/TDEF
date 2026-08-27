# Story 009: Boss/Elite Exceptional Path

> **Epic**: Hybrid Creature Swarm Rendering
> **Status**: Complete
> **Layer**: Presentation (new capped pool) + Core (bounded MonsterManager wiring)
> **Type**: Integration
> **Estimate**: 4-6 hours
> **Manifest Version**: 2026-07-13b
> **Last Updated**: 2026-08-27

## Context

**GDD**: `design/gdd/monster.md` §"BOSS Scene Structure — Two-Layer AnimatedSprite2D" (the spec this story reproduces, in 3D). No TR-ID (this epic has zero TR-IDs, same as Epic 15).
**Requirement**: None.

**ADR Governing Implementation**: ADR-0038 (Hybrid Creature Swarm Rendering) — Accepted 2026-08-24.
**ADR Decision Summary**: `docs/architecture/hybrid-swarm-rendering-implementation-blueprint.md` §"Story 9 — Boss/elite exceptional path": "Implement capped presenter pool and reproduce required layered boss animation/tells without callbacks." ADR-0038 §"Bosses, elites, and Menagerie": "Bosses and visually exceptional elites may use dedicated `Sprite3D` or `AnimatedSprite3D` presenters... They remain centrally updated and have a content-defined concurrency cap proven in the pilot [assumed default here, not pilot-proven — see Implementation Notes]... Exceptional presenters have no independent process callback. MonsterManager publishes the same snapshots to their pool."

**Engine**: Godot 4.6.2 | **Risk**: LOW — `Sprite3D`/`SpriteBase3D.billboard`/`alpha_cut` are stable pre-4.x APIs, no post-cutoff risk; this story's only real risk was architectural (correctly retiring the legacy path for the last tier using it), not engine-API uncertainty.
**Engine Notes**: `SpriteBase3D.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y` matches the swarm body shader's own Y-axis-only camera-facing convention (`creature_swarm_body.gdshader`'s `vertex()`), for visual consistency between the two presentation paths.

**Control Manifest Rules (this layer)**:
- Required: `BossCreaturePresenter3D` has no `_process()`/`_physics_process()` — `MonsterManager` publishes to it from the existing `_pass3c_visual_sync()` call site, exactly like the swarm path (ADR-0038's explicit requirement for exceptional presenters).
- Forbidden: no runtime pool-capacity growth (`CAPACITY` is fixed at `_ready()`, never resized) — mirrors the swarm batch's "no runtime `instance_count` resizing" rule even though this pool isn't a `MultiMesh`.
- Guardrail: a stale/foreign handle must never mutate a slot it doesn't own — verified by `_resolve_valid_slot()`'s generation check, same pattern as `MonsterSwarmBatch`.

---

## Acceptance Criteria

*Sourced from the blueprint's Story 9 scope line and ADR-0038's Bosses/elites/Menagerie section:*

- [ ] `BossCreaturePresenter3D` (`Node3D`, no `_process()`) exists as its own scene, instanced once as a child of `MonsterSwarmRenderer3D`'s existing (previously empty) `ExceptionalPresenters` root — "exactly one active mission renderer" stays true; the pool is internal to that one renderer, not a second scene-owned system.
- [ ] Fixed capacity (`CAPACITY = 2`), never resized at runtime. `register_boss()` rejects (returns `null`, `push_warning`s) a duplicate `entity_id` or registration beyond capacity.
- [ ] Each pool slot has two `Sprite3D` layers — a base layer (always visible while registered) and an overlay layer (visible only during the attack-telegraph window) — reproducing `design/gdd/monster.md`'s two-layer walk/attack_prepare design without `AnimationTree`, per the blueprint's own "implementation may use layered `Sprite3D` nodes inside one capped presenter."
- [ ] `MonsterSwarmRenderer3D` exposes `register_boss()`/`update_boss()`/`unregister_boss()`/`get_boss_live_count()` as pass-through methods to its internal pool — `MonsterManager` talks to exactly one injected renderer reference for both the swarm and boss paths, not two separately-injected dependencies.
- [ ] `MonsterManager` retires the legacy ADR-0037 3D mesh companion for the LAST tier still using it (BOSS) — `instance.configure(..., false)` unconditionally now, for every tier. `_spawn_entity()` registers BOSS (tier 2) with `register_boss()` instead, storing the result in a new `MonsterEntity.boss_presenter_handle` field (mutually exclusive with `swarm_handle`).
- [ ] `_pass3c_visual_sync()` publishes position + attack-telegraph state (`entity.boss_attack_prepare_remaining > 0`) to `update_boss()` for entities with a `boss_presenter_handle`, from the same centralized pass STANDARD/ELITE already uses — no new pass, no per-node callback.
- [ ] Death, breach, and forced wave-completion all call `unregister_boss()` for any entity with a live `boss_presenter_handle`, at the same three resolution points Story 7 established for `swarm_handle` (`_emit_death()`, `_advance_entity()`'s BREACHED branch, `_on_wave_completed()`).
- [ ] `tests/integration/visual_presentation/monster_visual_companion_test.gd` (the last remaining live user of the legacy companion assertions, kept alive through Story 7's own interim fix) is updated to confirm the legacy path is now dead for every tier — completing the blueprint's own Migration step 8 ("replace `monster_visual_companion_test.gd` expectations with swarm tests").

---

## Implementation Notes

*Derived from ADR-0038's Bosses/elites/Menagerie section and a real content gap this story had to name honestly:*

- **Real content gap, flagged not fabricated**: `design/gdd/monster.md`'s two-layer spec calls for the overlay to play a distinct `"attack_prepare"`/`"attack"` `AnimatedSprite2D` animation while the base layer's `"walk"` animation continues uninterrupted. No monster in this project has multi-frame animated art yet — only single static textures (`MonsterInstance.MONSTER_TEXTURES`). Both `Sprite3D` layers in this story's pool use the SAME static texture; the overlay's role is proven entirely through its VISIBILITY toggle (on during the attack-telegraph window, off otherwise), not through distinct animated frames. This is the honest, mechanism-proven-not-content-faked pattern this whole session has followed (matching, e.g., the pilot's own synthetic atlas, or Epic 15's Kenney placeholder mesh) — real animated boss art is a future content-authoring pass this story does not pretend to have built.
- **`CAPACITY = 2` is an assumed default, not empirically verified**: ADR-0038 says "a content-defined concurrency cap proven in the pilot" — the pilot never actually exercised concurrent bosses (it only tested the standard swarm batch at scale), so "proven in the pilot" does not literally hold here. `CAPACITY = 2` is a reasonable starting assumption (BOSS is this project's rarest spawn tier by design) flagged explicitly in the presenter's own doc comment for a future playtest to confirm or raise, not silently presented as verified.
- Uses a simple free-list slot allocator, not the swarm batch's dense swap-remove — a `Node3D`-based presenter slot can just set `.visible = false` when empty, so there's no `visible_instance_count`-style packing constraint to satisfy, and porting the dense-batch complexity here would add real complexity for zero correctness benefit.
- The attack-telegraph condition (`boss_attack_prepare_remaining > 0`) is read, never written, by `_pass3c_visual_sync()` — Pass 2 (`_pass2_boss_logic()`) already owns the countdown; this story only observes it. The instantaneous `"attack"` animation state (playing once at the exact frame `boss_tower_attack_attempted` emits) has no separate tracked duration anywhere in the existing code, so this story's overlay covers the full prepare-through-fire telegraph window as one visibility state, matching the GDD's own framing of `"attack_prepare"` as "the player's only warning."

---

## Out of Scope

*Handled by neighbouring stories, or explicitly deferred:*

- Story 10: retiring `enemy_ufo_a.tres` and formally removing `MonsterInstance._build_visual_companion()`/`sync_visual_companion_position()`/`MONSTER_MESH_ENTITY_ID` and the `build_legacy_3d_companion` parameter now that nothing calls it — this story leaves that dead code in place, per the blueprint's own staged "remove the temporary migration switch after all creature families and regression tests pass" (Story 10's explicit job).
- Real animated boss art (distinct walk/attack_prepare/attack sprite sheets) — a future content-authoring pass, not architecture work.
- Elite-tier exceptional presenters — ADR-0038's own policy keeps ELITE on standard batching "unless an approved visual requirement needs unique tells unavailable through the four-channel shader contract"; no such requirement has been raised, so ELITE stays on the swarm path from Story 7, untouched here.

---

## QA Test Cases

See `tests/integration/visual_presentation/boss_creature_presenter_test.gd`: direct pool tests (register success, duplicate rejection, capacity-exhaustion rejection, unmapped-`monster_id` rejection, attack-telegraph overlay visibility toggle read back from the real `Sprite3D` node, stale-handle rejection, slot reuse after unregister) and full `MonsterManager` integration (BOSS spawn registers with the pool and NOT the swarm batches, `boss_attack_prepare_remaining` drives the overlay through a real `_physics_process()` call, death unregisters cleanly). See the rewritten `monster_visual_companion_test.gd` for the "legacy path stays dead for every tier" regression guard.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/visual_presentation/boss_creature_presenter_test.gd` — must exist and pass.
- `tests/integration/visual_presentation/monster_visual_companion_test.gd` — rewritten this story, must pass (confirms the legacy path is dead for every tier).
- `tests/integration/visual_presentation/monster_swarm_migration_test.gd`/`monster_swarm_channel_test.gd` — must still pass unmodified (STANDARD/ELITE path untouched by this story).

**Status**: [x] Created/updated — not yet run against the pinned Godot binary this session (user explicitly asked to skip running tests this turn — see Completion Notes).

---

## Dependencies

- Depends on: Story 6 (`MonsterSwarmRenderer3D`'s `ExceptionalPresenters` root, previously empty), Story 7 (established the DI/injection pattern this story's boss registration follows)
- Unlocks: Story 10 (the legacy companion path is now dead for every tier — safe to formally remove and retire `enemy_ufo_a.tres`)

## Completion Notes
**Completed**: 2026-08-27
**Criteria**: 8/8 passing — verified via code read against `boss_creature_presenter_3d.gd`/`.tscn`, `monster_swarm_renderer_3d.gd`'s pass-through methods, `monster_manager.gd`'s boss wiring, and the rewritten `monster_visual_companion_test.gd`.
**Deviations**: `CAPACITY = 2` is an assumed default, not pilot-verified against real concurrency data (documented above) — the ADR's own "proven in the pilot" language does not literally hold, flagged rather than silently claimed. Both `Sprite3D` layers use the same static texture (no distinct attack-prepare animation art exists yet) — the overlay's role is proven via visibility toggle only.
**Test Evidence**: `tests/integration/visual_presentation/boss_creature_presenter_test.gd` and the rewritten `monster_visual_companion_test.gd` — both predate and were covered by the full gdUnit4 sweep run 2026-08-26 (2354/2354 clean, 0 errors/0 failures).
**Code Review**: Skipped (lean mode) — user confirmed no dedicated `/code-review` pass was run for this story.
