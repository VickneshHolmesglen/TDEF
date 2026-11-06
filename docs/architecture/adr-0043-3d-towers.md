# ADR-0043: 3D Towers in the HD-2D World

## Status

Accepted (user-directed, 2026-11-07). Supersedes the 2026-11-05 "HD-2D locked, 2D sprite units" note in ADR-0042 for towers. First of three steps toward a 3D game: towers (this ADR), then real 3D terrain, then 3D hero and monsters (separate ADRs when designed).

## Date

2026-11-07

## Last Verified

2026-11-07 (pilot live in The Gap: commit 807fdf92; look comparison spike, smooth picked)

## Decision Makers

User (direction, look, behaviour); Claude Code (architecture).

## Summary

Placed towers render as live 3D models inside the existing Hd2dScenery 3D world, built in Blender by `tools/asset-pipeline/blender/tower_kit.py`. The crown turns to aim and sweeps like a sentry when idle. Detail grows with Foundation tier (T1-T4) and veterancy rank (0-3). `TowerInstance` keeps its public API and falls back to the 2D layered sprites for any tower whose pieces are not modelled yet. The Inventory shows 3D icons and a rotating 3D assembly preview.

## Engine Compatibility

| Field | Value |
|---|---|
| Engine | Godot 4.6.2 |
| Domain | Rendering (3D under 2D canvas), asset import (glTF) |
| Knowledge risk | LOW: glb import, `Node3D`, `SubViewport` are stable 4.x APIs |
| References | `docs/engine-reference/godot/VERSION.md` (`Light3D.layers` vs `Camera3D.cull_mask` gotcha) |
| Verification | Pilot + spike live-checked via Godot MCP on 4.6.2.stable |

Every `VisualInstance3D` a tower creates must sit on `Hd2dScenery.RENDER_LAYER`, or the scenery camera ignores it.

## ADR Dependencies

| Relation | ADR |
|---|---|
| Depends on | ADR-0042 (Hd2dScenery: camera, sun, `to_world()`) |
| Amends | ADR-0042 status (HD-2D lock lifted for towers) |
| Related | ADR-0008 (tower components), ADR-0040 (old 3D camera cutover, removed 2026-11-05; not revived) |

## Context

### Problem Statement

The user found that Claude Code models well in Blender (MCP, Blender 5.1) and decided to move the game to 3D, towers first. A pilot showed a live 3D tower fits the HD-2D world's light and shadow better than painted sprites.

### Current State

Towers are three stacked 2D sprites (Base/Shaft/Top) laid out with a hand-measured seat table (`LAYER_SEAT_FRACTIONS`), plus 6 weapon crowns. Hd2dScenery already renders 3D grass, trees and props under the 2D canvas with an orthographic camera at 50 degree pitch.

### Constraints

- Keep the fixed tilted orthographic camera (user decision).
- Aiming is visual only; no combat change.
- No SubViewport per placed tower.
- 2D hero and monsters stay on top of 3D towers until units go 3D (user accepted).

### Requirements

- Crown aims at its target; slow sentry sweep when idle; per-piece idle motion as data.
- Detail grows with tier and veterancy rank.
- 3D in the Inventory, slowly rotating.

## Decision

### Architecture

```
mission_scene.gd / the_gap.gd
   └─ TowerInstance (Node2D, unchanged API) ── 2D overlays: chevrons, perk badge, HP bars, particles
         │ set_scenery(Hd2dScenery) + configure(..., tier)
         └─ TowerModel3D (Node3D, child of Hd2dScenery at to_world(position))
               ├─ base_<shape>.glb ── Seat
               ├─ shaft_<shape>.glb ── Seat
               └─ crown (weapon_<key>.glb or top_<shape>.glb) ── Crown pivot
                     TowerAim (pure maths) + TowerCrownMotion (data)
```

### Key Interfaces

- `TowerModel3D.has_models(shape, crown_key) -> bool`, `build(shape, crown_key, tier, z_stretch, rng_seed)`, `set_tier()`, `set_rank()`, `aim_at()`, `play_punch()`, `play_hit_flash()`, `play_remove()`.
- `TowerInstance.set_scenery()`, `configure(..., tier: int = 1)`, `play_targeting_orientation(..., target: Node2D = null)`.
- glb contract: root named after the piece, front +Z, `Seat` on bases/shafts, `Crown` pivot on crowns, `Tier2`/`Tier3`/`Tier4` detail groups.

### Implementation Guidelines

See `docs/superpowers/specs/2026-11-07-3d-towers-design.md` and `docs/superpowers/plans/2026-11-07-3d-towers.md`.

## Alternatives Considered

### Alternative 1: Blender renders as 2D sprites

- **Description**: Model in Blender, render each piece to a pixel sprite, keep the 2D runtime.
- **Pros**: No engine change; keeps HD-2D lock.
- **Cons**: No live aiming; does not move toward the 3D goal.
- **Rejection Reason**: User wants a 3D game and aiming crowns.

### Alternative 2: Pixelated 3D towers

- **Description**: Live models drawn through a low-res render to match pixel units.
- **Pros**: Matches today's pixel-art units.
- **Cons**: Needs a shared low-res render path and faked shadows; likely dropped once units go 3D.
- **Rejection Reason**: User compared both live and picked smooth.

## Consequences

### Positive

- Crowns aim and keep watch; real light and shadow; any piece fits any piece via `Seat` nodes (no seat table, no adaptor caps).
- One model per piece with tier groups (33 files, not 132).

### Negative

- 2D hero/monsters draw over towers even when behind them, until project 3.
- Two render paths (2D fallback + 3D) coexist during the rollout.

### Neutral

- Painted tower art stays until every piece is modelled; retiring it needs separate approval.

## Risks

| Risk | Mitigation |
|---|---|
| Draw calls with many towers | Join meshes per material on export; measure in a full wave |
| HUD overlays drift from the 3D model | Overlays anchor to `TowerModel3D.screen_height_px()`; live-checked |

## Performance Implications

| Metric | Before | Expected | Budget |
|---|---|---|---|
| Draw calls per tower | 3 sprites | ~7 materials x pieces after join | 200 total per frame |

## Migration Plan

1. TowerModel3D + wiring with the pilot pieces; others fall back to 2D.
2. Model the remaining pieces in batches.
3. Retire the 2D path (separate approval).

**Rollback plan**: don't call `set_scenery()`; every tower renders 2D as before.

## Validation Criteria

- Tower model/aim unit tests pass; mission-scene and tower-build-panel suites pass.
- Live: placed towers sweep out of sync, track during a wave, overlays aligned, remove/destroy leave nothing in the scenery.

## GDD Requirements Addressed

| GDD | Requirement |
|---|---|
| `design/gdd/tower.md` | Visual/Audio Requirements: IDLE, TARGETING, ATTACKING, removed/destroyed presentation |
| `design/quick-specs/tower-veterancy-2026-11-04.md` | Rank shown on the tower |

## Related

- ADR-0042 HD-2D scenery layer
- `design/art/3d-art-pipeline.md`
