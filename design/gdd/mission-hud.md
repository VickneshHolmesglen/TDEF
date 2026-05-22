# Mission HUD System

> **Status**: Skeleton — awaiting full design. Created to close broken dependency reference from `pathfinding.md` and `wave-manager.md`.
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-05-22
> **Implements Pillar**: Placement is the Puzzle (spatial feedback layer)

## Overview

The Mission HUD is the player's primary heads-up display during a mission. It owns all player-facing feedback that is not part of the world itself: route-preview overlays, blocked-placement indicators, phase announcements, wave progress, hero stats, and deferred-routing notifications. It is the visual and communicative layer that makes the Pathfinding System's silent routing computations legible to the player.

This document is a skeleton. Sections marked **[TO BE DESIGNED]** require a full design session before implementation. The Dependencies section is complete — it reflects confirmed signal contracts from Pathfinding, Wave Manager, and Tower systems.

## Player Fantasy

**[TO BE DESIGNED]**

Placeholder intent: The player feels in command. Every placement they make produces immediate, legible feedback: the route shifts, the blocked zone highlights, the horde responds. The HUD amplifies strategic decisions without cluttering tactical attention.

## Detailed Rules

**[TO BE DESIGNED]**

### Confirmed Signal Contracts (from dependency GDDs)

The following contracts are fixed and must be honoured by the Mission HUD implementation. They are documented here to prevent the dependency GDDs from referencing an undesigned system.

**PC-1 — `path_invalidated(affected_cells: Array[Vector2i])` (Pathfinding GDD Rule 10, OQ-5):**
- Subscribe via EventBus.
- On receipt: call `PathfindingSystem.get_path(spawn_cell, 0)` to obtain the updated route. `affected_cells` is the union of changed-walkability cells (the tower footprint) — it is NOT the route. Do not render `affected_cells` directly as a route line.
- Re-render the route-preview overlay with the new path.
- Do NOT re-render during WAVE_ACTIVE — placement is locked during active waves and `path_invalidated` cannot fire in that phase, so this constraint is self-enforcing. If `path_invalidated` is somehow received during WAVE_ACTIVE, discard without re-rendering.

**PC-2 — `tower_placement_blocked(blocked_cells: Array[Vector2i], primary_blocking_cell: Vector2i)` (Pathfinding GDD Rule 10):**
- Subscribe via EventBus.
- On receipt: highlight `blocked_cells` to indicate the rejected footprint.
- If `primary_blocking_cell != Vector2i(-1, -1)`: highlight `primary_blocking_cell` distinctively (e.g., brighter color, pulsing outline) to anchor player attention to the specific load-bearing constraint cell.
- If `primary_blocking_cell == Vector2i(-1, -1)`: highlight all `blocked_cells` uniformly — the footprint as a whole is the constraint, no single cell is individually load-bearing.

**PC-3 — `tower_destroyed(tower_id, grid_position, footprint)` during WAVE_ACTIVE (Pathfinding GDD EC-11):**
- Subscribe via EventBus.
- On receipt during WAVE_ACTIVE: display a player-visible communication indicating "Path update queued for next intermission."
- The specific presentation (banner, pop-over, audio cue) is to be determined during full HUD design.

**PC-4 — Wave progress and phase transitions:**
- **[TO BE DESIGNED]** — subscribe to `mission_phase_changed` and display current phase, wave number, and wave timer.

## Formulas

**[TO BE DESIGNED]**

No formulas currently specified. Route-preview overlay rendering does not involve game-logic formulas.

## Edge Cases

**[TO BE DESIGNED]**

## Dependencies

#### Systems this GDD depends on

| System | GDD | What Mission HUD requires |
|--------|-----|--------------------------|
| Pathfinding System | `design/gdd/pathfinding.md` | `path_invalidated` (route update), `tower_placement_blocked` (rejected placement visual), `get_path()` direct call to obtain updated route on `path_invalidated` receipt |
| EventBus System | `design/gdd/event-bus.md` | All HUD subscriptions route through EventBus |
| Wave Manager | `design/gdd/wave-manager.md` | Wave progress, phase change notifications |
| Tower System | `design/gdd/tower.md` | `tower_destroyed` for BOSS-induced stale routing notification (PC-3) |

#### Systems that depend on this GDD

None currently identified. Mission HUD is a leaf consumer — it reads from systems but other systems do not depend on it.

#### Bidirectionality notes

- Pathfinding GDD lists Mission HUD as a consumer of `path_invalidated`, `tower_placement_blocked`, and `tower_destroyed`. This GDD confirms those contracts (PC-1, PC-2, PC-3). ✅
- Wave Manager GDD lists Mission HUD as a consumer of wave progress events. Cross-reference required when Wave Manager GDD is reviewed. [PENDING]

## Tuning Knobs

**[TO BE DESIGNED]**

## Acceptance Criteria

**[TO BE DESIGNED]**

Placeholder: all three signal contracts (PC-1, PC-2, PC-3) must have corresponding ACs covering: correct rendering on receipt, correct non-rendering in suppressed phases, and correct `affected_cells` vs route rendering distinction for PC-1.
