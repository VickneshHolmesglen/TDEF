# Story 006: Projectile Visual Companion

> **Epic**: 3D Visual Presentation Layer — Phase 1
> **Status**: Complete
> **Layer**: Feature (ProjectileManager, pooled Projectile — logic untouched, gains one sync line)
> **Type**: Integration
> **Estimate**: 2-4 hours
> **Manifest Version**: 2026-07-13b
> **Last Updated**: —

## Context

**GDD**: None — infrastructure epic, no GDD linkage.
**Requirement**: None (no TR registry entry). Criteria sourced from ADR-0037.

**ADR Governing Implementation**: ADR-0037 (Visual Presentation 3D Companion Layer) — Accepted; also governed by ADR-0019 (`per_projectile_physics_process` centralization ban, registered forbidden pattern; pooling strategy)
**ADR Decision Summary**: Pooled `Projectile` instances (plain `Node2D`, 192-slot fixed pool, warmed up once at mission start per ADR-0019) each gain a `Node3D` visual-companion child. Sync happens as one additional line inside `ProjectileManager`'s existing single centralized `_physics_process` pass over the entire pool — never a new per-instance override, the identical constraint Story 004 applied to `MonsterManager`, now applied to `ProjectileManager`. This is deliberately the **last** story in the epic, per ADR-0037's own Migration Plan ordering rationale: pooling/re-acquisition timing (release/reuse toggling `visible = false` + `process_mode = Node.PROCESS_MODE_DISABLED`) is the most complex interaction with a visual layer of any entity type in this epic.

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM-HIGH — this is the entity type with the most unusual lifecycle in the project (pool release/reuse via `visible`+`process_mode` toggling rather than actual node creation/destruction), and the companion's visibility/process state must correctly mirror the pooled projectile's own release/reuse toggling, or a "dead" pooled slot could show a stale visible mesh.
**Engine Notes**: Same `Node3D`/`Node2D` transform-non-inheritance and 2D-composites-over-3D notes as prior stories apply. Additionally: per the existing pool design (`docs/registry/architecture.yaml`'s `api_decisions` entry for this system), release/reuse requires **both** `visible = false` and `process_mode = Node.PROCESS_MODE_DISABLED` on the 2D pooled node — "visible alone does not stop a child AnimatedSprite2D's internal animation timer from advancing." This story's `Node3D` companion needs the equivalent double-toggle applied to itself (its own `visible` and, if it has any internal per-frame behavior, `process_mode`) on release/reuse — do not assume toggling only the 2D parent's `visible` is sufficient for the 3D child.

**Control Manifest Rules (this layer)**:
- Required: "`ProjectileManager` owns a single **centralized** `_physics_process` pass over the entire pool, mirroring `MonsterManager`'s pattern" — source: ADR-0019. "Re-acquisition throttle: `MAX_REACQUISITIONS_PER_FRAME = 8`, counter reset each `_physics_process` call" — source: ADR-0019, unrelated to this story's sync addition but must not be disturbed by it.
- Forbidden: "Never give a pooled `Projectile` its own `_physics_process`... a stray per-instance `_physics_process` on any `Projectile`/`ProjectileManager` script is a static-analysis (grep) validation failure" — source: ADR-0019. Identical stakes to Story 004's Monster constraint.
- Guardrail: "`ProjectileManager._physics_process` iterates the full 192-slot pool each frame, skipping inactive slots (`if p.active`)... estimated well under 0.1 ms/frame at MVP entity counts" — source: ADR-0019. This story's sync line must respect the same `if p.active` skip — an inactive pooled slot's companion should not be synced (and should be hidden per the visibility/process_mode note above), not merely synced-but-invisible-by-accident.

---

## Acceptance Criteria

*Sourced from ADR-0037 and ADR-0019:*

- [ ] Each pooled `Projectile` gains a `Node3D` visual-companion child holding a `MeshInstance3D` resolved via `VisualMeshMappingResource`, for at least one projectile type.
- [ ] The companion's position syncs via `map_to_3d()` called from inside `ProjectileManager._physics_process`'s existing centralized pass, gated by the same `if p.active` check the pass already uses — grep-verifiable: zero new `_physics_process`/`_process` methods added to `Projectile`/`ProjectileManager`.
- [ ] On pool release (projectile arrives/despawns), the companion's `visible` is set `false` in the same operation that sets the 2D pooled node's `visible = false` + `process_mode = Node.PROCESS_MODE_DISABLED` — no stale visible mesh from a released slot.
- [ ] On pool reuse (a released slot is claimed for a new shot), the companion's `visible` is restored and its position correctly reflects the new shot's starting position on the very first frame it's active again — no one-frame flash at the old (previous shot's) position.
- [ ] `ProjectileManager._physics_process`'s existing re-acquisition throttle (`MAX_REACQUISITIONS_PER_FRAME = 8`) and centralized-pass structure are unchanged and pass all existing tests unmodified.
- [ ] Estimated per-frame cost of the added sync stays consistent with the existing "well under 0.1 ms/frame at MVP entity counts" guardrail — measured, not assumed, same as Story 004's measurement requirement.
- [ ] A fired projectile's 3D companion visually tracks its 2D flight path with no lag/desync, verified via live screenshot/gameplay observation across an actual shot's full flight.

---

## Implementation Notes

*Derived from ADR-0037 and ADR-0019:*

- This is explicitly the highest-risk story in the epic (per its own Risk rating above and ADR-0037's Migration Plan rationale for ordering it last) — the pool's release/reuse toggling is a real, already-documented gotcha in this codebase (the `AnimatedSprite2D`-timer case cited in the registry), and this story's companion sync must not reintroduce an equivalent bug for the 3D layer.
- Test release→reuse cycling explicitly, not just steady-state "projectile flying" behavior — the stale-visible-mesh failure mode only shows up across a release/reuse transition, not in a single static frame.
- If the companion has zero internal per-frame behavior of its own (a static `MeshInstance3D` with no child `AnimationPlayer`/similar), the `process_mode` half of the double-toggle may be unnecessary for the companion specifically — verify and document which half actually matters for this story's specific companion structure, rather than blindly copying both toggles without confirming they're both load-bearing here.
- Only one projectile type needs conversion to satisfy these criteria, matching the scope discipline of Stories 003-005.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Converting every projectile type/variant.
- Any VFX/impact-effect visual work (dissolve/hit-flash shader conversion to `spatial` is explicitly Phase 3, a separate future epic per `EPIC.md`'s Overview).

---

## QA Test Cases

**AC-1 & AC-2 (companion + centralized sync)**:
- Given: an active pooled projectile with a valid mesh mapping
- When: the projectile moves across multiple `_physics_process` frames
- Then: companion position updates via `map_to_3d()`, called from inside `ProjectileManager`'s existing pass, gated by `if p.active`; static analysis confirms no new per-instance callback
- Edge cases: projectile fired this frame (companion correctly positioned from first active frame); projectile re-acquiring a target mid-flight (position continues updating correctly through re-acquisition)

**AC-3 & AC-4 (release/reuse toggling)**:
- Given: a pooled projectile slot cycling through fire → flight → release → reuse
- When: release occurs (arrival/despawn)
- Then: companion `visible = false` in the same operation as the 2D node's release toggle — verify via node-state inspection immediately after release, not just visual absence
- When: the same slot is reused for a new shot
- Then: companion `visible` restored and positioned at the new shot's start point on the first active frame — no visible flash at the stale prior position
- Edge cases: rapid release→reuse within a small number of frames (mass-kill event stress case, matching ADR-0019's own throttle rationale); multiple slots releasing/reusing in the same frame

**AC-5 (no invariant regression)**:
- Given: existing `ProjectileManager` test suite (pooling, re-acquisition throttle, centralized pass)
- When: this story's changes are applied
- Then: all existing tests pass unmodified
- Edge cases: the `MAX_REACQUISITIONS_PER_FRAME = 8` throttle specifically — confirm this story's sync addition doesn't change the counter's behavior

**AC-6 (performance budget)**:
- Given: the full 192-slot pool with a representative number of active projectiles (MVP entity counts)
- When: `ProjectileManager._physics_process` runs with the new sync line included
- Then: measured time stays consistent with "well under 0.1 ms/frame" — profile before/after this story's change to confirm no meaningful regression
- Edge cases: mass-kill event triggering many simultaneous release/reuse transitions in one frame

**AC-7 (visual tracking)**:
- Manual check: live gameplay observation
  - Setup: fire a projectile at a target and observe its full flight
  - Verify: 3D companion tracks the 2D flight path with no lag/jitter, including at arrival/impact
  - Pass condition: no visible desync across the full shot lifecycle

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/visual_presentation/projectile_visual_companion_test.gd` — automated coverage for AC-1 through AC-6 (especially AC-3/AC-4's release/reuse cycling, the story's highest-risk area).
- Performance measurement (AC-6) recorded alongside the test file, same pattern as Story 004.
- `production/qa/evidence/projectile-visual-companion-evidence.md` — screenshot/gameplay-observation evidence for AC-7.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (DONE), Story 004 (DONE — projectiles target monsters, and this story's release/reuse timing is best verified against real monster-hit scenarios)
- Unlocks: None further within this epic — this is the last story. Completing it closes the epic's Definition of Done (all 6 stories `Complete`, ADR-0037 Validation Criteria verified per entity type).

## Completion Notes
**Completed**: 2026-08-20
**Criteria**: 4/8 fully verified against the real codebase (AC-1, AC-2, companion-lifecycle-no-orphan, AC-4's underlying "no stale-position flash" concern), 3/8 marked **N/A** (pool release/reuse toggling, rapid release-reuse cycling, multi-slot-same-frame — no pool exists to test, see below), 2/8 DEFERRED (AC-6 performance, AC-7 live visual tracking — require a rendered/profiled session)

**MAJOR FINDING, not a routine deviation**: `ProjectileManager`/pooled `Projectile` (ADR-0019, Accepted) was **never implemented** in this codebase — confirmed by grep (zero matches for `class_name ProjectileManager`, `POOL_SIZE`, `_free_indices`) and independently re-confirmed by both code-review specialists. `TowerSystem._try_attack()` still fires `tower_attacked` instantly for every shot; `TR-tower-007` remains open. Story 006 and its governing ADR were written against infrastructure that does not exist. **Decision made this session (coordinator-approved, not the implementing agent's unilateral call)**: building the real pool was rejected as out of scope — it would be a substantive gameplay-timing change (introduces a real flight delay before damage lands), not a visual-presentation change, and would violate this epic's own hard "zero gameplay-logic changes" boundary held by every other story. The story was redirected to implement and test the companion against the REAL create-per-shot/destroy-per-shot `ProjectileVisual` lifecycle instead, with the pool-specific ACs honestly marked N/A rather than fabricated. **Logged durably as `TD-tower-005` in `docs/tech-debt-register.md`** — a real, separate, open item for future decision (implement ADR-0019 for real, or formally revise it to match the shipped instant-damage model), explicitly outside this epic's own scope.

**Test Evidence**: `tests/integration/visual_presentation/projectile_visual_companion_test.gd` — 9/9 passing; `production/qa/evidence/projectile-visual-companion-evidence.md` — the ADR-0019 finding stated first, before any AC table; existing suites re-run for regression — 39/39 (visual_presentation), 70/70 (tower), mission-scene integration all passing, zero regression
**Code Review**: Complete — APPROVED. godot-gdscript-specialist: CLEAN, independently re-verified the "no pool exists" claim rather than trusting it, confirmed the N/A framing is honest not evasive. qa-tester: TESTABLE, same independent re-verification, found one traceability nit (AC-4's real-lifecycle-equivalent coverage wasn't cross-referenced in the evidence table) — fixed. This is the highest-risk story in the epic per its own original notes, and the actual risk that materialized (a missing dependency system) was different from the anticipated risk (pool timing bugs) — handled by stopping and asking rather than guessing, the correct response to a genuine architecture-vs-reality conflict.
