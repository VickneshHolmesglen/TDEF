# ADR-0015: Collision Layer Convention

## Status

Accepted

## Date

2026-07-08

## Last Verified

2026-07-08

## Decision Makers

lead-programmer (extracted from `hero.gd`'s existing doc comment, no new decision made)

## Summary

Story-002 (S4-04, Hero Movement) established this project's first collision-layer
convention, documented only in `src/core/hero/hero.gd`'s class doc comment. This ADR
promotes that convention to a tooling-visible architectural record (`/architecture-review`
and the control manifest generator do not read source doc comments), closing `TD-adr-002`.
No behavior changes — this is a documentation promotion, not a new decision.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Physics |
| **Knowledge Risk** | LOW — `collision_layer`/`collision_mask` bitmask semantics and `move_and_slide()` are stable since Godot 4.0 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | Any future `CharacterBody2D`/`StaticBody2D`/tilemap collision work must conform to this layer table |
| **Blocks** | None |
| **Ordering Note** | None |

## Context

### Problem Statement

Collision layers are cross-system architectural surface — any future system that adds a
physics body (BLOCKED-cell tilemap collision, tower physics bodies) must agree on the same
layer numbering as Hero, or Hero's `collision_mask` silently stops matching. A source doc
comment in `hero.gd` is not discoverable by `/architecture-review` or the control manifest
generator, so this contract was invisible to project tooling.

### Current State

`hero.gd` defines `COLLISION_LAYER_ENVIRONMENT = 1` and `COLLISION_LAYER_HERO = 2`. Hero
sets `collision_layer = 2`, `collision_mask = 1` (`hero.gd:326-327`). **Layer 1 is currently
unoccupied**: grep-confirmed as of this ADR — no `CollisionShape2D`/`StaticBody2D` exists
anywhere in `src/core/tower/` (TowerSystem is a plain `Node`, no physics body), and the
BLOCKED-cell tilemap in `the_gap.tscn` (`GridVisual`) is a pure visual `Node2D` with no
collision shapes. In practice, Hero's `move_and_slide()` currently resolves against nothing
and moves unobstructed. Monsters are `Area2D` (`monster_entity.gd:2`) and never participate
in this layer system regardless of layer/mask — confirmed intentional, not a gap.

### Constraints

- Any future BLOCKED-cell tilemap collision or tower physics body must use
  `COLLISION_LAYER_ENVIRONMENT = 1` to be seen by Hero's existing `collision_mask`.
- Monsters must never be added to layer 1 or 2 — they are deliberately collision-exempt
  from this system (Area2D, GDD-specified no blocking behavior).

## Decision

### Chosen Approach: Two-layer bitmask, Hero-authoritative

| Layer | Value | Occupants | Status |
|-------|-------|-----------|--------|
| 1 | Environment | BLOCKED-cell tilemap collision shapes (not yet built), tower physics bodies (not yet built) | Reserved, unoccupied |
| 2 | Hero | Hero (`CharacterBody2D`) | Active |

Hero: `collision_layer = 2`, `collision_mask = 1` — collides against environment only;
never blocks or is blocked by monsters (Area2D, exempt from this system entirely).

### Implementation Guidelines

- Any future system adding a physics body that Hero must be blocked by (tilemap collision,
  tower bodies) must set `collision_layer = 1` (or reference
  `Hero.COLLISION_LAYER_ENVIRONMENT` if accessible) — do not invent a new layer number.
- Do not add monsters to this layer system — their exemption is deliberate.

## Alternatives Considered

### Alternative 1: Per-system independent layers (no shared convention)

- **Description**: Each future system picks its own collision layer without a shared table.
- **Cons**: Directly caused the gap this ADR closes — the architecture specialist flagged
  during S4-04 code review that S4-09 (mission scene assembly) would need this exact
  contract; a source doc comment alone was invisible to `/architecture-review` tooling.
- **Rejection Reason**: Already causes cross-system architectural risk; this ADR is the fix.

## Consequences

### Positive

- Layer convention is now tooling-visible (`/architecture-review`, control manifest).
- Zero code changes — pure documentation promotion of an already-shipped, already-correct
  convention.

### Negative

- None — no behavior change.

### Neutral

- Layer 1 remains unoccupied until a real BLOCKED-tilemap collision shape or tower physics
  body is built; Hero movement is currently unobstructed in practice. This is a pre-existing
  gap, not introduced or worsened by this ADR.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| A future system invents a new layer number instead of reusing layer 1 | Low | Medium — Hero would move through it unobstructed | This ADR + Implementation Guidelines is the mitigation |

## Performance Implications

Not applicable — no code change.

## Migration Plan

Not applicable — documentation only.

**Rollback plan**: Delete this ADR; the convention still lives in `hero.gd`'s doc comment
either way.

## Validation Criteria

- [x] Collision-layer table is recorded in `docs/architecture/` (this ADR)
- [x] `hero.gd`'s doc comment updated to reference this ADR

## GDD Requirements Addressed

Foundational — no direct GDD requirement. Enables: any future system implementing
`design/gdd/pathfinding.md`'s BLOCKED-cell geometry or `design/gdd/tower.md`'s physical
tower footprint as a real collision body.

## Related

- `src/core/hero/hero.gd` (`COLLISION_LAYER_ENVIRONMENT`, `COLLISION_LAYER_HERO`)
- `docs/tech-debt-register.md` TD-adr-002 (closed by this ADR)
