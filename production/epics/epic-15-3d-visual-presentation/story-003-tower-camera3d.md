# Story 003: Tower Visual Companion + Camera3D

> **Epic**: 3D Visual Presentation Layer — Phase 1
> **Status**: Complete
> **Layer**: Presentation (Camera3D addition); Core (TowerInstance gains a companion, logic untouched)
> **Type**: Integration
> **Estimate**: 2-4 hours
> **Manifest Version**: 2026-07-13b
> **Last Updated**: —

## Context

**GDD**: None — infrastructure epic, no GDD linkage.
**Requirement**: None (no TR registry entry). Criteria sourced from ADR-0037.

**ADR Governing Implementation**: ADR-0037 (Visual Presentation 3D Companion Layer) — Accepted
**ADR Decision Summary**: `TowerInstance` gains a `Node3D` visual-companion child, synced from its existing `Vector2 position` in its own existing update method (not a new per-node override — `TowerInstance` already has one, this adds one line). A single `Camera3D` is added once to `MissionScene`/`the_gap.tscn`, fixed-angle and non-rotating (user decision, captured in ADR-0037's Decision section), sibling to the existing `Camera2D` — both may coexist; `Camera2D.enabled`/`Camera3D.current` are mutually exclusive at any moment but nothing forces an all-or-nothing cutover.

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM — this is the first story where a `Camera3D` actually goes live in the real mission scene (not a scratch/spike scene), so the interaction with the existing `CanvasLayer`-based `HUD` is genuinely being exercised for the first time, per ADR-0037's own flagged "still unverified" item.
**Engine Notes**: `Node3D` child of `Node2D` does **not** inherit the parent's 2D transform (godot-specialist finding, folded into ADR-0037) — `map_to_3d()`'s output must be set as an absolute world position on the companion node, never assumed to be relative to `TowerInstance`'s own `Node2D` position automatically. 2D `CanvasItem` content (the `HUD` `CanvasLayer`, and `TowerInstance`'s existing `Sprite2D` if still present) always composites on top of 3D viewport content — this is expected and convenient during the migration window (ADR-0037 Risks), not a bug to fix.

**Control Manifest Rules (this layer)**:
- Required: N/A for `Camera3D`/3D rendering specifically (no existing manifest rule covers 3D camera setup — this story is establishing new precedent, not following an existing one).
- Forbidden: N/A.
- Guardrail: Total scene draw calls ≤ 200/frame; this story's `Camera3D` addition itself has no draw-call cost, but makes the grid tiles (Story 002) and this story's tower mesh simultaneously visible for the first time — verify the combined total, not just this story's own contribution.

---

## Acceptance Criteria

*Sourced from ADR-0037:*

- [ ] `TowerInstance` gains a `Node3D` visual-companion child holding a `MeshInstance3D` resolved via `VisualMeshMappingResource` (Story 001), for at least one tower type.
- [ ] The companion's position syncs from `TowerInstance`'s existing `position` via `map_to_3d()`, called from `TowerInstance`'s **existing** update method — no new `_process`/`_physics_process` callback is added (per ADR-0037's constraint that this doesn't count as a "new per-node override" since one already exists).
- [ ] A single `Camera3D` exists in `MissionScene`/`the_gap.tscn`, fixed-angle, non-rotating, positioned to reproduce a comparable framing to the current `Camera2D`'s default view (per the user's confirmed camera-style decision — exact transform values are a tuning task, not a fixed number this story must match precisely).
- [ ] `Camera2D` and `Camera3D` coexist in the scene tree without error; toggling which is `current`/`enabled` does not crash or produce console errors.
- [ ] With `Camera3D.current = true`, the grid (Story 002) and this story's tower mesh are both visible together in one frame, at correct relative scale and position.
- [ ] `HUD` (`CanvasLayer`) continues rendering correctly on top of the 3D viewport content, unaffected by which camera is active (per ADR-0037's stated expectation that `CanvasLayer` compositing is unaffected by 2D-vs-3D world content).

---

## Implementation Notes

*Derived from ADR-0037:*

- This is the first story where a real `Camera3D` transform must be tuned against actual gameplay content, not a spike scene — expect to iterate the transform numbers live (screenshot, adjust, repeat), per this project's verification-driven-development practice (`src/CLAUDE.md`).
- Do not remove or disable `Camera2D` in this story — per ADR-0037's Migration Plan, no mass "flip a switch" cutover; both coexist until every entity type in this epic is converted (Story 006 is the last).
- `TowerInstance`'s pre-existing single-tower conversion here is deliberately narrow (Acceptance Criteria says "at least one tower type") — do not attempt to convert every tower variant in this story; that's a natural follow-up once the pattern is proven, not blocking for Story 004+.
- Watch for the exact gotcha ADR-0037 flags: setting the companion's position via `map_to_3d()` must be an absolute assignment, not additive/relative to the `Node2D` parent's transform.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: `MonsterInstance` companion, synced inside `MonsterManager`'s centralized pass (not a single-entity update method like `TowerInstance`'s).
- Story 005: `Hero` companion.
- Story 006: pooled `ProjectileVisual` companion and its pool-specific sync timing.
- Converting every tower variant/type — only enough to prove the pattern and give the camera something real to frame.

---

## QA Test Cases

**AC-1 & AC-2 (companion + sync)**:
- Given: a placed `TowerInstance` with a `VisualMeshMappingResource` entry for its type
- When: the tower's `position` changes (e.g. during placement/repositioning, if applicable) or the scene first loads
- Then: the companion's 3D position reflects `map_to_3d(tower.position, layer_height)` exactly, updated from the tower's own existing update method (verify no new callback was added — grep for exactly one `_process`/`_physics_process` on `TowerInstance`, matching the pre-existing count)
- Edge cases: tower at grid-boundary position; tower's 2D `position` unchanged across frames (companion position should also remain stable, not drift)

**AC-3 & AC-4 (camera setup + coexistence)**:
- Given: `MissionScene`/`the_gap.tscn` with both cameras present
- When: the scene runs
- Then: no console errors; switching `current`/`enabled` between the two produces the expected view with no crash
- Edge cases: both cameras enabled simultaneously (should not crash, even if the render doesn't make sense — verify graceful, not necessarily "correct," behavior); neither camera current (should not crash)

**AC-5 (combined visual correctness)**:
- Manual check: live screenshot with `Camera3D` active
  - Setup: a mission scene with the Story 002 grid and this story's tower both present
  - Verify: tower renders at the correct grid cell, correct relative scale to the tiles
  - Pass condition: no floating/sunken/misaligned tower relative to its tile

**AC-6 (HUD unaffected)**:
- Manual check: `HUD` rendering with `Camera3D` active vs. `Camera2D` active
  - Setup: toggle between the two cameras with `HUD` visible
  - Verify: HUD elements render identically regardless of which camera/world content is active
  - Pass condition: no visual regression in HUD layout, opacity, or interactivity

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/visual_presentation/tower_camera_companion_test.gd` — automated coverage for AC-1, AC-2, AC-3, AC-4 (sync correctness, no new callback, no crash on camera coexistence).
- `production/qa/evidence/tower-camera3d-evidence.md` — screenshot evidence for AC-5, AC-6 (visual/HUD checks, which are inherently manual).

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (DONE), Story 002 (DONE — camera needs the grid to frame against)
- Unlocks: Story 004, Story 005 (both need a working `Camera3D` in the real scene to be visually verifiable)

## Completion Notes
**Completed**: 2026-08-20
**Criteria**: 4/6 fully verified (AC-1 through AC-4), 2/6 DEFERRED (AC-5 visual/screenshot check, AC-6 HUD-unaffected check — both require a live rendered session, honestly documented rather than fabricated)
**Deviations**: ADR-0037's assumption that `TowerInstance` "already has" an existing per-frame update method was found to be false (zero `_process`/`_physics_process` callbacks exist) — the sync call was placed inside `configure()` instead (Tower's actual "apply visual state" entry point, since `position` is set once before `configure()` runs and never touched again), which satisfies AC-2's "no new callback" requirement without contradicting ADR-0037's intent
**Test Evidence**: `tests/integration/visual_presentation/tower_camera_companion_test.gd` — 16/16 passing (11 original + 5 from code-review-driven additions); `production/qa/evidence/tower-camera3d-evidence.md` — honest deferral for AC-5/AC-6
**Code Review**: Complete — APPROVED. godot-gdscript-specialist: CLEAN (configure()-as-sync-point and Camera3D fix both confirmed correct); qa-tester: TESTABLE, closed the one real gap flagged (asymmetric MissionScene.tscn camera coverage) plus added non-zero-transform regression guards. **Three additional real bugs found and fixed during my own live verification, beyond what either specialist flagged**: (1) Godot auto-promotes a lone `Camera3D` to `current=true` on entering the tree regardless of the `.tscn`'s stored `current=false` — fixed by re-asserting `current = false` in both `the_gap.gd`'s and `mission_scene.gd`'s `_ready()`; (2) `#` comment lines inside a `.tscn` `[node]` block are unsafe in this engine version — one silently corrupted the `Camera3D.position` property (read back as `Vector3.ZERO`), a second (containing a backtick) caused a hard scene-load parse failure — fixed by removing all `.tscn` node-block comments project-wide in the touched files and switching to an atomic `transform = Transform3D(...)` property; now permanently documented in `docs/engine-reference/godot/VERSION.md`. Logged `TD-visualpres-001` (pre-existing, unrelated `BreachFlashOverlay` HUD gap in `the_gap.tscn`, found but out of scope to fix here) to `docs/tech-debt-register.md`.
