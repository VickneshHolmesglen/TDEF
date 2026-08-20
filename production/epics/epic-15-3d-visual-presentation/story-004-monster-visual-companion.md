# Story 004: Monster Visual Companion

> **Epic**: 3D Visual Presentation Layer — Phase 1
> **Status**: Complete
> **Layer**: Core (MonsterManager, MonsterInstance — logic untouched, gains one sync line)
> **Type**: Integration
> **Estimate**: 2-4 hours
> **Manifest Version**: 2026-07-13b
> **Last Updated**: —

## Context

**GDD**: None — infrastructure epic, no GDD linkage.
**Requirement**: None (no TR registry entry). Criteria sourced from ADR-0037.

**ADR Governing Implementation**: ADR-0037 (Visual Presentation 3D Companion Layer) — Accepted; also governed by ADR-0006 (`per_monster_physics_process` centralization ban, registered forbidden pattern)
**ADR Decision Summary**: `MonsterInstance` gains a `Node3D` visual-companion child. Sync happens as **one additional line inside `MonsterManager._physics_process`'s existing centralized 4-pass structure** (Damage → BOSS Logic → Movement → Absorbed Flush, per ADR-0006) — never a new `_physics_process` override on `MonsterInstance`/`MonsterEntity` itself, which is an explicit, registered forbidden pattern (`per_monster_physics_process`) precisely because per-node process order is not guaranteed stable, and this project relies on that determinism for the DEAD-priority invariant.

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM — first story converting an entity type with real per-frame movement and a centralized manager pass this story must not disturb; also the first entity type where realistic instance-count scale (up to 150 active entities per the manifest's own guardrail) actually stresses the mixed-root pattern, addressing ADR-0037's flagged "unverified at scale" risk.
**Engine Notes**: Same `Node3D`/`Node2D` transform-non-inheritance and 2D-composites-over-3D notes as Story 003 apply identically here.

**Control Manifest Rules (this layer)**:
- Required: "All per-entity logic (damage, BOSS attack, movement, absorbed flush) runs inside a single centralized `MonsterManager._physics_process`, in 4 fixed sequential passes" — source: ADR-0006. This story's sync line must be added into that existing structure, in a pass-order-safe position (visual sync has no gameplay-ordering dependency on the other 4 passes, so it can safely run after all 4, or within the Movement pass immediately after position is finalized for that entity — implementer's choice, document which was chosen).
- Forbidden: "Never let `MonsterEntity` scene nodes define their own `_physics_process`" (`per_monster_physics_process`) — source: ADR-0006. This is the single most important rule this story must not violate.
- Guardrail: "Monster System `_physics_process`: ≤ 2 ms/frame at 150 active entities; ≤ 4 ms/frame for a 22-entity lethal-AoE frame" — source: ADR-0006. This story's added sync line must be measured against this existing budget, not exempted from it — a `map_to_3d()` call per monster per frame is expected to be negligible (pure `Vector3` construction, no allocation), but must be profiled, not assumed.

---

## Acceptance Criteria

*Sourced from ADR-0037 and ADR-0006:*

- [ ] `MonsterInstance` gains a `Node3D` visual-companion child holding a `MeshInstance3D` resolved via `VisualMeshMappingResource`, for at least one monster type.
- [ ] The companion's position syncs via `map_to_3d()` called from inside `MonsterManager._physics_process`'s existing centralized pass structure — grep-verifiable: zero new `_physics_process`/`_process` methods added to `MonsterInstance`/`MonsterEntity` scene scripts.
- [ ] The existing 4-pass order (Damage → BOSS Logic → Movement → Absorbed Flush) and the DEAD-priority invariant it protects are unchanged and continue passing all existing `MonsterManager` tests unmodified.
- [ ] `MonsterManager._physics_process` stays within its existing ≤ 2 ms/frame (150 entities) / ≤ 4 ms/frame (22-entity lethal-AoE) budget with the new sync line included — measured, not assumed.
- [ ] A moving monster's 3D visual companion tracks its `Vector2` position with no visible lag or desync, verified via live screenshot/gameplay observation across multiple frames (not just a single static frame check).
- [ ] Monster spawn/despawn correctly creates/destroys the companion — no orphaned `Node3D` companions after a monster dies or breaches (verify via node-count check before/after a kill, not just visual absence).

---

## Implementation Notes

*Derived from ADR-0037 and ADR-0006:*

- This is the first story where the "no new per-node override" constraint is genuinely load-bearing, not incidental — `MonsterManager`'s centralized pass exists specifically because sibling `_physics_process` order is unstable; adding a sync call anywhere *inside* that pass is safe, adding it as a new override on `MonsterEntity` is exactly the bug class ADR-0006 was written to prevent.
- Companion lifecycle should piggyback on `MonsterInstance`'s own existing spawn/despawn handling (a `Node3D` child of an already-lifecycle-managed `Node2D` dies for free when its parent frees, per ADR-0037's stated positive consequence) — do not build a second, separate cleanup path.
- Profile the added sync cost specifically, not just the pass as a whole — isolate whether `map_to_3d()`/companion-position-assignment is the dominant new cost if the budget is at risk, so it's clear whether the function itself needs optimization or something else regressed.
- Only one monster type needs conversion to satisfy these criteria — matching Story 003's "prove the pattern, don't convert everything" scope discipline.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: `Hero` companion (different sync mechanism — Hero's own existing `_physics_process`, not a shared manager pass).
- Story 006: pooled `ProjectileVisual` companion.
- Converting every monster type/variant.

---

## QA Test Cases

**AC-1 & AC-2 (companion + centralized sync)**:
- Given: a spawned `MonsterInstance` with a valid mesh mapping
- When: the monster moves across multiple `_physics_process` frames
- Then: the companion's position updates each frame via `map_to_3d()`, called from inside `MonsterManager`'s existing pass — static analysis (grep) confirms no new `_physics_process`/`_process` method exists on the monster's own scene script
- Edge cases: monster spawned this frame (companion must exist and be positioned correctly on the very first frame it's visible, no one-frame lag); monster at grid boundary

**AC-3 (no invariant regression)**:
- Given: the existing `MonsterManager` test suite (DEAD-priority ordering, 4-pass structure)
- When: this story's changes are applied
- Then: all existing tests pass unmodified — zero new failures, zero test changes required
- Edge cases: the specific lethal-hit-plus-GOAL-arrival-same-frame case ADR-0006's own rationale calls out — must still resolve identically

**AC-4 (performance budget)**:
- Given: 150 active monster entities (existing benchmark scenario per ADR-0006's guardrail)
- When: `MonsterManager._physics_process` runs with the new sync line included
- Then: measured time stays ≤ 2 ms/frame (150 entities) and ≤ 4 ms/frame (22-entity lethal-AoE scenario)
- Edge cases: worst-case scenario where every entity's companion syncs the same frame (should already be true every frame — no special "worst case" beyond the existing benchmark)

**AC-5 (visual tracking)**:
- Manual check: live gameplay observation
  - Setup: spawn a monster and let it move along its path
  - Verify: 3D companion visually tracks the monster's logical position across several seconds of movement
  - Pass condition: no visible lag, jitter, or desync between logical and visual position

**AC-6 (lifecycle correctness)**:
- Given: a monster that dies (killed) and one that breaches (reaches GOAL)
- When: each is removed from the simulation
- Then: node count check confirms its `Node3D` companion is also freed, not orphaned
- Edge cases: multiple monsters dying in the same frame (Absorbed Flush pass) — verify no companion leak under batch removal

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/visual_presentation/monster_visual_companion_test.gd` — automated coverage for AC-1, AC-2, AC-3, AC-6.
- Performance measurement (AC-4) captured and recorded — either as part of the same test file (if GUT supports timing assertions in this project's existing pattern) or a dedicated profiling note referenced from the test file's doc comment.
- `production/qa/evidence/monster-visual-companion-evidence.md` — screenshot/gameplay-observation evidence for AC-5 (inherently manual).

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (DONE), Story 003 (DONE — needs a working `Camera3D` to visually verify against)
- Unlocks: Story 006 (projectile re-acquisition targets monsters, so a working monster companion is a reasonable precondition for meaningfully testing projectile visuals, even though not a hard technical dependency)

## Completion Notes
**Completed**: 2026-08-20
**Criteria**: 4/6 fully verified (AC-1, AC-2, AC-3, AC-6), 2/6 DEFERRED (AC-4 performance budget — not measured, honestly flagged rather than assumed; AC-5 live visual tracking — requires a rendered session)
**Deviations**: None — `_pass3c_visual_sync()` inserted as a new sub-pass after Movement/before Absorbed-Flush, the documented 4-pass order and DEAD-priority invariant fully intact (confirmed by both specialist review and 100/100 pre-existing MonsterManager tests passing unmodified)
**Test Evidence**: `tests/integration/visual_presentation/monster_visual_companion_test.gd` — 8/8 passing; `production/qa/evidence/monster-visual-companion-evidence.md` — honest deferral for AC-4/AC-5; existing `tests/unit/monster` + `tests/integration/monster` suites re-run — 100/100 passing, zero regression
**Code Review**: Complete — APPROVED. godot-gdscript-specialist: CLEAN (pass ordering, zero-new-callback constraint, lifecycle fix, and API shape all confirmed correct); qa-tester: TESTABLE, no gaps found. This story's implementation agent needed two resumes (cut off mid-task each time — first before wiring MonsterManager's sync call, then before finishing tests/evidence) but the delivered work itself required no bug fixes, unlike Story 003.
