# Story 005: Hero Visual Companion

> **Epic**: 3D Visual Presentation Layer — Phase 1
> **Status**: Complete
> **Layer**: Core (Hero — logic untouched, gains one sync line)
> **Type**: Integration
> **Estimate**: 2-4 hours
> **Manifest Version**: 2026-07-13b
> **Last Updated**: —

## Context

**GDD**: None — infrastructure epic, no GDD linkage.
**Requirement**: None (no TR registry entry). Criteria sourced from ADR-0037.

**ADR Governing Implementation**: ADR-0037 (Visual Presentation 3D Companion Layer) — Accepted
**ADR Decision Summary**: `Hero` (root type `CharacterBody2D`, per the coupling survey) gains a `Node3D` visual-companion child, synced via `map_to_3d()` from inside `Hero`'s own **existing** `_physics_process` — this is not a centrally-managed entity like Monster/Projectile, so the "no new override" constraint here means "add one line to the method that already exists," not "route through a separate manager."

**Engine**: Godot 4.6.2 | **Risk**: LOW-MEDIUM — pattern already proven by Stories 003/004; Hero is a single instance (not a pooled/many-instance case), so this story is lower-risk than Story 004's scale concern, but is the first `CharacterBody2D` (rather than plain `Node2D`/`Area2D`) root converted — confirm the mixed-root pattern holds for a `CharacterBody2D` root specifically, not just `Node2D`/`Area2D`.
**Engine Notes**: Same `Node3D`/`Node2D` transform-non-inheritance and 2D-composites-over-3D notes as Stories 003/004 apply identically here. `CharacterBody2D`'s own physics/movement (`move_and_slide()` etc.) is entirely 2D-internal and unaffected by this story — the companion is purely additive.

**Control Manifest Rules (this layer)**:
- Required: N/A — no existing manifest rule specifically governs Hero's update-method structure the way ADR-0006 governs Monster's centralized pass; Hero's existing single-instance `_physics_process` is not a forbidden-pattern target.
- Forbidden: N/A.
- Guardrail: N/A beyond the project-wide 200 draw-call/frame budget (single instance, negligible marginal cost).

---

## Acceptance Criteria

*Sourced from ADR-0037:*

- [ ] `Hero` gains a `Node3D` visual-companion child holding a `MeshInstance3D` resolved via `VisualMeshMappingResource`.
- [ ] The companion's position syncs via `map_to_3d()` called from inside `Hero`'s existing `_physics_process` — no new callback added (verify: same method count as before this story).
- [ ] Hero's existing 2D movement/combat logic (whatever `CharacterBody2D`-specific behavior currently exists) is completely unchanged and passes all existing Hero tests unmodified.
- [ ] The 3D companion visually tracks Hero's movement with no lag/desync across multiple frames of real movement (walking, not just standing still), verified via live screenshot/gameplay observation.
- [ ] The mixed-root pattern is confirmed to work for a `CharacterBody2D` root specifically (not just the `Node2D`/`Area2D` roots already verified in Stories 002-004) — flag explicitly in test evidence if any `CharacterBody2D`-specific quirk is found.

---

## Implementation Notes

*Derived from ADR-0037:*

- Hero is architecturally simpler than Monster for this story's purposes — there's no centralized-manager constraint to route through, just one line added to an already-existing single-instance update method.
- Watch specifically for whether `CharacterBody2D`'s internal collision/physics processing interacts oddly with a `Node3D` child in any way not already covered by the `Node2D`/`Area2D` cases proven in Stories 002-004 — this is the one genuinely new engine-surface question this story answers that the others don't.
- Same absolute-position-assignment caveat as prior stories: `map_to_3d()`'s output is not relative to Hero's own `Node2D`/`CharacterBody2D` transform.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: pooled `ProjectileVisual` companion (Hero's own projectiles, if any, are out of scope here — this story is Hero's own visual body only).
- Any Hero equipment/gear visual representation (a separate, later concern — not part of ADR-0037's Phase 1 scope, which is entity bodies, not equipped-item visuals).

---

## QA Test Cases

**AC-1 & AC-2 (companion + sync)**:
- Given: Hero with a valid mesh mapping
- When: Hero moves across multiple `_physics_process` frames
- Then: companion position updates each frame via `map_to_3d()`; static analysis confirms no new `_physics_process`/`_process` method added to Hero's script
- Edge cases: Hero at mission start (companion must exist and be correctly positioned from the first visible frame)

**AC-3 (no regression)**:
- Given: existing Hero test suite (movement, combat, `CharacterBody2D`-specific behavior)
- When: this story's changes are applied
- Then: all existing tests pass unmodified
- Edge cases: N/A — pure regression check

**AC-4 (visual tracking)**:
- Manual check: live gameplay observation
  - Setup: move Hero across the mission area
  - Verify: companion visually tracks Hero's position with no lag/jitter
  - Pass condition: no visible desync across several seconds of movement, including direction changes

**AC-5 (CharacterBody2D-specific verification)**:
- Manual check: live gameplay observation, specifically watching for any `CharacterBody2D`-related visual anomaly
  - Setup: trigger Hero's normal movement/collision behavior (walking into a wall/obstacle if applicable, normal pathing otherwise)
  - Verify: no companion-position anomaly correlated with `CharacterBody2D`-specific physics events (e.g. collision resolution)
  - Pass condition: companion tracking remains correct through any such event; if an anomaly is found, document it explicitly rather than silently working around it

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/visual_presentation/hero_visual_companion_test.gd` — automated coverage for AC-1, AC-2, AC-3.
- `production/qa/evidence/hero-visual-companion-evidence.md` — screenshot/gameplay-observation evidence for AC-4, AC-5.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (DONE), Story 003 (DONE — needs a working `Camera3D`)
- Unlocks: None directly (Story 006 depends on Story 004, not this story) — but completing this story alongside Story 004 gives the epic's Definition of Done a fuller mid-epic visual-verification picture (grid + tower + monster + hero all simultaneously visible).

## Completion Notes
**Completed**: 2026-08-20
**Criteria**: 3/5 fully verified (AC-1, AC-2, AC-3 — including the story's own specifically-called-out "confirm mixed-root pattern holds for CharacterBody2D" target, closed via a real move_and_slide() collision test), 2/5 DEFERRED (AC-4 visual tracking, AC-5 CharacterBody2D-specific live observation — both require a rendered session)
**Deviations**: None — unlike Story 003's TowerInstance, Hero already had a genuine pre-existing `_physics_process()` (movement, grid tracking, Tower-Synced Class proximity per ADR-0010), so the sync call was added there directly exactly as ADR-0037 literally describes, no judgment call needed
**Test Evidence**: `tests/integration/visual_presentation/hero_visual_companion_test.gd` — 7/7 passing; `production/qa/evidence/hero-visual-companion-evidence.md` — honest deferral for AC-4/AC-5; existing `tests/unit/hero` + `tests/integration/hero` suites re-run — 119/119 passing, zero regression
**Code Review**: Complete — APPROVED. godot-gdscript-specialist: CLEAN (ready()-call-site, physics-process ordering, lifecycle fix, sync placement all confirmed correct); qa-tester: TESTABLE, no gaps. Cleanest story of the epic so far — implementation needed one resume (cut off before writing tests/evidence, same as every prior story) but zero real bugs, unlike Stories 002/003.
