# Epic: 3D Visual Presentation Layer — Phase 1 (Entity Conversion)

> **Layer**: Presentation
> **GDD**: None — infrastructure epic, not GDD-driven. ADR-0037's own "GDD Requirements Addressed" table is explicitly N/A ("This ADR is not driven by a specific GDD requirement... foundational infrastructure for a presentation-layer technology change the user requested directly").
> **Architecture Module**: New — spans Hero/Tower/Monster/Projectile/Grid scene files additively (each gains a `Node3D` visual-companion child), without changing any of their owned Core-layer simulation logic. See ADR-0037's Architecture Diagram.
> **Status**: Complete (2026-08-20) — all 6 stories Complete, code-reviewed, zero regressions. See Definition of Done below for what's verified vs. still deferred to a human/live session.
> **Stories**: 6 created — see table below

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Visual Mesh Mapping Foundation](story-001-visual-mesh-mapping-foundation.md) | Logic | Complete | ADR-0037 |
| 002 | [Grid/Terrain Visual Companion](story-002-grid-terrain-visual-companion.md) | Visual/Feel | Complete | ADR-0037 |
| 003 | [Tower Visual Companion + Camera3D](story-003-tower-camera3d.md) | Integration | Complete | ADR-0037 |
| 004 | [Monster Visual Companion](story-004-monster-visual-companion.md) | Integration | Complete | ADR-0037, ADR-0006 |
| 005 | [Hero Visual Companion](story-005-hero-visual-companion.md) | Integration | Complete | ADR-0037 |
| 006 | [Projectile Visual Companion](story-006-projectile-visual-companion.md) | Integration | Complete | ADR-0037 (ADR-0019 target infrastructure never existed — see Completion Notes, `TD-tower-005`) |

## Overview

This epic implements Phase 1 of the 2D→3D visual pivot: giving the game's core gameplay entities (grid/terrain, towers, monsters, hero, projectiles) a 3D visual representation via the Visual Companion pattern established in ADR-0037, while their `Vector2`-based simulation logic (position, movement, `AStar2D` pathfinding) remains completely untouched. This is Phase 1 of a longer, explicitly-phased roadmap (Phase 0 = ADR-0037 itself, already Accepted; Phases 2-6 = interaction/picking, VFX/shaders, rendering polish, 3D art pipeline, and content re-authoring, each out of scope here and each requiring its own later epic).

The source art for this phase is a third-party placeholder pack ("Tower Defense Models," Kenney-style, sci-fi-neutral) validated via a throwaway spike (`prototypes/3d-tower-defense-kit-spike/`) — this epic's Definition of Done does not include replacing that placeholder art with game-specific fantasy models; that is explicitly Phase 6 (Content re-authoring), a separate future epic.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| ADR-0037: Visual Presentation 3D Companion Layer | `Node2D`-rooted gameplay entities gain a `Node3D` visual-companion child (mesh only); position synced from the unchanged `Vector2` sim inside each system's already-centralized update pass (never a new per-node override, protecting ADR-0006/ADR-0019's ordering guarantees). Mesh resolution is data-driven via a new `VisualMeshMappingResource` (typed `PackedScene` export, `GameDataRegistry`-backed, following ADR-0009's convention). | MEDIUM (core mechanism is LOW/live-verified; MEDIUM reflects adjacent post-cutoff rendering changes explicitly deferred past this epic) |

## GDD Requirements

None — this epic has zero TR-IDs. Completion is measured against ADR-0037's own **Validation Criteria** section instead of a GDD's Acceptance Criteria:
- A converted entity type renders its 3D visual companion at visually-correct position/scale matching its `Vector2` position at all times during gameplay (live screenshot comparison, not just static scene inspection).
- No entity's `Vector2 position` or pathfinding behavior changes measurably — existing unit/integration tests for that entity type continue passing unmodified.
- `VisualMeshMappingResource.validate()` correctly fails boot for a missing/invalid mesh mapping (unit test, mirroring `RecipeResource`/`ItemDefinitionResource` validation test patterns).
- Memory and load-time impact measured at realistic ~100-monster mission scale stays within the project's existing budgets (`technical-preferences.md`: 200 draw calls/frame, 1GB memory ceiling).

## Story Breakdown (planned — see `/create-stories` for the authoritative implementable files)

Ordered per ADR-0037's Migration Plan (static/simple first, pooling last):

| # | Story | Depends on | Scope |
|---|-------|------------|-------|
| 1 | Visual mesh mapping foundation | — | `VisualMeshMappingResource` (`class_name`, `Resource`, `GameDataRegistry`-backed, `validate()`), the shared `map_to_3d(pos2d, layer_height) -> Vector3` utility, and initial `.tres` mapping entries pointing at the "Tower Defense Models" placeholder pack |
| 2 | Grid/terrain visual companion | 1 | `TheGap`'s `GridVisual` gains a `Node3D` companion for ground/tile rendering — static, no per-frame sync needed |
| 3 | Tower + camera | 1, 2 | `TowerInstance` visual companion; `Camera3D` added to `MissionScene`/`the_gap.tscn` (fixed, non-rotating, framing decided at implementation time per ADR-0037) |
| 4 | Monster visual companion | 1, 3 | `MonsterInstance` companion, synced inside `MonsterManager`'s existing centralized `_physics_process` pass (one added line, no new override — protects ADR-0006) |
| 5 | Hero visual companion | 1, 3 | `Hero` companion, synced inside `Hero`'s existing `_physics_process` |
| 6 | Projectile visual companion | 1, 4 | Pooled `ProjectileVisual` companion, synced inside `ProjectileManager`'s existing centralized pass (last — ADR-0019's re-acquisition/pooling timing is the most complex case) |

## Definition of Done

**Verified and closed (2026-08-20):**
- All 6 stories implemented, code-reviewed (godot-gdscript-specialist + qa-tester, every story), and closed via `/story-done`.
- Every story's own automated test suite passes: Story 001 (18 tests), 002 (5), 003 (16), 004 (8), 005 (7), 006 (9) — **63 new tests total**, all green on the pinned `Godot 4.6.2.stable` binary.
- Zero regressions anywhere touched: pre-existing suites re-run and confirmed passing after each story — Monster (100/100), Hero (119/119), Tower (70/70), MissionScene/TheGap integration (25/25) — none of this epic's changes altered any entity's `Vector2` position or pathfinding behavior.
- `VisualMeshMappingResource.validate()` fails boot loudly for missing/invalid mappings — verified (Story 001).
- `Sprite2D`/`AnimatedSprite2D` nodes were never removed for any entity type — both `Camera2D` (active) and `Camera3D` (present, `current=false`) coexist in both mission scenes exactly as the Migration Plan specifies; no premature cutover occurred.
- Every story's `RecipeResource`/`Resource`-pattern data (`.tres` mesh mappings) is data-driven, matching ADR-0009's established convention — confirmed by code review each time.

**Explicitly deferred to a human/live session (never fabricated — each story's own evidence doc says so plainly):**
- Live visual-correctness screenshots for all 5 entity types (grid, tower, monster, hero, projectile) — the underlying position math is proven exact by automated tests; the *rendered* look (scale, mesh orientation, camera framing) is unverified.
- Performance/memory measurement at realistic mission scale (~100 monsters, MVP tile count, all 5 companion types simultaneously active) against the 200-draw-call/1GB budgets — every story flagged this as "expected cheap, not measured," never claimed as verified.
- `Camera3D`'s exact framing/transform values were only tuning-task starting points (Story 003), never live-compared against the old `Camera2D` view or HUD layout assumptions.

**New open item surfaced by this epic, tracked separately (not part of this epic's own scope):**
- `TD-tower-005` (`docs/tech-debt-register.md`): ADR-0019 (Projectile Pooling Strategy) was discovered during Story 006 to have never been implemented — `TR-tower-007` remains open, `TowerSystem` still deals instant damage with no pool/flight-delay system. Story 006 was redirected to build against the real per-shot `ProjectileVisual` lifecycle instead; the pool-specific acceptance criteria were honestly marked N/A rather than faked. This is a real, separate architectural gap for a future decision (implement ADR-0019 for real, or formally revise it) — explicitly not something this visual-presentation epic should or did resolve.
- `TD-visualpres-001`: `the_gap.tscn` is missing `BreachFlashOverlay` HUD nodes that `mission_hud.gd` unconditionally expects — found during Story 003's live verification, pre-existing and unrelated to this epic's own changes.
- A genuine, permanent engine-knowledge finding: `#` comment lines inside `.tscn` `[node]`/`[resource]` blocks are unsafe in Godot 4.6.2 (silent property corruption or hard parse failure) — now documented in `docs/engine-reference/godot/VERSION.md` for the whole project, not just this epic.

## Next Step

Phase 1 (this epic) is complete. **Update (2026-08-26)**: Phases 2-5 have since been built and live-verified in follow-up work (tracked via ADR-0039 §3D Interaction and Picking Layer, ADR-0040 §3D Camera Cutover Capability, and `design/art/3d-art-pipeline.md` for Phase 5) rather than as separate formal epics — this section is kept accurate rather than rewritten, since this epic's own scope and Definition of Done above remain Phase 1 only:

- **Phase 2 (picking)**: `Picking3D` utility built (ground-plane and tower raycasts), gated behind `ENABLE_3D_PRESENTATION_MODE` (see Phase 4). Live-verified via Godot MCP — a real bug (`collide_with_areas` missing on the raycast query) was found and fixed in the process.
- **Phase 3 (VFX/shaders → `spatial`)**: `hit_flash_spatial.gdshader` ported for `TowerInstance`'s 3D companion, wired to the same `play_hit_flash()` trigger as the 2D flash.
- **Phase 4 (camera cutover)**: `ENABLE_3D_PRESENTATION_MODE` toggle built in both `mission_scene.gd`/`the_gap.gd`, still `false` by default (this remains a deliberate, live-verified-but-unshipped capability, not a default behavior change). The exact "live Godot MCP session rendering everything and switching `Camera3D.current = true`" this section used to recommend has now happened multiple times — it found and fixed two real bugs (`Camera3D`'s baked rotation pointed at the sky, not the grid; disabling `Camera2D` alone doesn't hide 2D content, since Godot composites 2D/3D independently — both now fixed).
- **Phase 5 (3D art pipeline)**: documented in `design/art/3d-art-pipeline.md` — a process definition, not new content; flags the open tension between this epic's placeholder pack and `art-bible.md`'s original "Hero is the only 3D exception" framing (unresolved, needs a visual-direction decision, not an engineering one).
- **Phase 6 (content re-authoring)**: still not started — genuinely blocked on real 3D art generation, which no session so far has been able to perform.

Whether/when to actually flip `ENABLE_3D_PRESENTATION_MODE` to `true` by default remains an open decision for whoever owns the visual-direction call in Phase 5's still-open OQ-1 (`design/art/3d-art-pipeline.md`) — the capability is now real and tested, not yet shipped.
