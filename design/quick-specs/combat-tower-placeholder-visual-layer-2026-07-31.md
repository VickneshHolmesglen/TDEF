# Quick Design Spec: Combat Tower Placeholder Visual Layer

**Type**: Addition
**System**: Tower System
**GDD Reference**: `design/gdd/tower.md` — Visual/Audio Requirements section
**Date**: 2026-07-31

## Change Summary

Adds a minimal visual-representation layer for combat towers, which currently have **zero** visual presence anywhere in the game — `TowerSystem` is pure data/logic (Grid occupancy + `TowerMissionState`), and `the_gap.gd`'s tower-placement handler calls `place_tower()` and creates nothing visible. This mirrors the already-Accepted `MonsterManager`/`the_gap.gd` monster-visual pattern (ADR-0006): a placeholder `ColorRect`, colored per the GDD's own Archetype Color Language table, created on `tower_placed` and freed on `tower_removed`/`tower_destroyed`.

## Motivation

Real placeable-tower art doesn't exist yet (a separate, larger content gap — 4 real blueprints, no sprites for any of them). But towers being *completely invisible* blocks even the most basic manual verification of tower placement, combat, and destruction — the one real playable mission scene (`the_gap.tscn`) currently cannot visually demonstrate its own core loop for towers the way it already can for monsters. This closes that specific gap with the same "mechanism real, content placeholder" discipline already used everywhere else in this project (Diorama, monster visuals, Music/Ambient Story 002).

## Design Delta

No existing GDD rule is being changed — `tower.md`'s Visual/Audio Requirements section already fully specifies the *real* target visual behavior (IDLE/TARGETING/ATTACKING/DESTROYED states, per-archetype animation, projectile VFX). This spec implements only the static IDLE-state placeholder slice of that section — a `ColorRect` at rest, correctly colored and positioned — deliberately deferring every state-specific animation (targeting orientation, attack flash, destruction VFX, projectile visuals) to when real content/art exists, exactly as `tower.md`'s own Asset Volume Flags section already anticipates as future content-authoring work.

## New Rules / Values

1. `the_gap.gd` subscribes to `GEventBus.tower_placed`, `GEventBus.tower_removed`, `GEventBus.tower_destroyed` (mirroring its existing `_wire()`-based subscription pattern for the 16 events it already handles).
2. On `tower_placed(payload: TowerPlacedEvent)`:
   - Create a `ColorRect` sized to `payload.footprint * CELL_SIZE` (matching `MonsterEntity`'s existing footprint-to-world-size convention).
   - Position it at the world-space top-left of `payload.grid_position` via `GGrid.cell_to_world(payload.grid_position)`.
   - Color it via a new `_color_for_tower_archetype(archetype: String) -> Color` helper, using `tower.md`'s own Archetype Color Language table (Physical: grey/silver `Color(0.6, 0.6, 0.65)`; Ranged: brown/wood `Color(0.55, 0.4, 0.25)`; Elemental: per-sub-type — MVP scope only needs Fire `Color(0.85, 0.35, 0.1)` and Frost `Color(0.6, 0.85, 0.95)`, since Poison/Lightning/Arcane are Vertical-Slice/Alpha-tier per the GDD and this project has no elemental sub-type field on `TowerBlueprintData` yet to distinguish them anyway — default any other/unrecognized `"elemental"` value to Frost's color as a safe fallback; Support: warm gold `Color(0.9, 0.75, 0.3)`; unrecognized archetype: magenta, matching this project's existing "loud, obviously-wrong" fallback convention seen in `grid_visual.gd`).
   - `mouse_filter = Control.MOUSE_FILTER_IGNORE` (matches the monster-visual precedent — clicks must reach the grid/placement input, not be swallowed by the placeholder).
   - Store the node in a new `_tower_visuals: Dictionary` keyed by `payload.tower_id`, so it can be found and freed later.
3. On `tower_removed(tower_id, ...)` / `tower_destroyed(tower_id, ...)`: look up and `queue_free()` the corresponding visual, erase it from `_tower_visuals`.
4. No animation, no state transitions (IDLE→TARGETING→ATTACKING→DESTROYED visual differences), no projectile VFX — explicitly out of scope, per Out of Scope below.

## Affected Systems

| System | Impact | Action Required |
|--------|--------|-----------------|
| `src/gameplay/missions/the_gap/the_gap.gd` | New subscriptions (`tower_placed`/`tower_removed`/`tower_destroyed`), new `_tower_visuals` dict, new `_on_tower_placed()`/`_on_tower_removed()`/`_on_tower_destroyed()` handlers, new `_color_for_tower_archetype()` helper | Implement |
| `src/core/tower/tower_system.gd` | None — stays pure data/logic, no scene involvement, matching its own established boundary | No action |
| `tower.md` | None — this implements a documented-but-deferred slice of the existing Visual/Audio Requirements section, doesn't change any rule | No action |

## Acceptance Criteria

- [ ] Placing a tower via the existing debug left-click handler makes a correctly-colored, correctly-sized, correctly-positioned rect appear at that grid cell
- [ ] The rect's color matches `tower.md`'s Archetype Color Language table for the tower's real `archetype` value (verify against at least `archer`=physical/grey, `frostbolt_turret`=elemental/frost-blue, `rally_banner`=support/gold)
- [ ] Removing or destroying a tower removes exactly its own visual, not another tower's
- [ ] Placing multiple towers in the same frame/session produces one correctly-tracked visual per tower, no orphaned or duplicate rects
- [ ] No regression: monster visuals, tower placement input, and Grid occupancy all continue to work exactly as before

## Out of Scope

- Any state-specific visual (TARGETING orientation, ATTACKING flash, DESTROYED VFX sequence, HP bar on boss-hit) — the placeholder is one flat, unchanging rect for the tower's entire IDLE lifetime
- Projectile visuals, AoE detonation rings, placement-preview cone-arc overlays — all separately specified in `tower.md` and all real content-authoring work, not part of this mechanism-only pass
- Real sprite art — this is the placeholder layer the real art (once mapped to the actual 4-tower roster) will replace later, exactly as `diorama.gd`'s `ColorRect`s are waiting on real Sanctuary structure art
- Elemental sub-type color distinction beyond Fire/Frost — `TowerBlueprintData.foundation.archetype` currently only stores the string `"elemental"`, not a specific element; a real per-element field would need its own design decision (not decided here) before Poison/Lightning/Arcane could get distinct placeholder colors

## GDD Update Required?

**No** — `tower.md`'s Visual/Audio Requirements section already fully specifies the target behavior this is a deliberately-scoped placeholder slice of; no rule changes.
