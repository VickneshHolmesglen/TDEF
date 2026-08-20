class_name VisualMath
extends RefCounted

## Shared pure math helpers for the 3D Visual Presentation Companion Layer
## (ADR-0037, Epic 15). Stateless static utility — mirrors this project's
## existing static-utility-class precedent (CombinedEriValidator,
## src/core/resource_economy/combined_eri_validator.gd): RefCounted, no
## instance state, callable directly without constructing a scene node or
## touching the scene tree.
##
## Placement note: ADR-0037's Key Interfaces section explicitly leaves
## map_to_3d()'s file location unfixed ("exact file location is an
## implementation detail, not fixed by this ADR"). This file is the chosen
## shared-utility home so Stories 002-006 (Camera3D, per-entity-type
## VisualCompanion3D nodes, and the centralized-pass sync calls) all import
## one canonical implementation rather than each re-deriving the formula.


## Maps a 2D gameplay-simulation position onto the 3D visual-companion plane
## (ADR-0037's Decision: "the 2D plane maps onto the 3D XZ plane, Y is
## reserved purely for visual layering, never read by gameplay logic").
##
## Pure function: no side effects, no hidden state, no heap allocation
## (engine-code.md's zero-allocation-hot-path rule — Vector3 is a value
## type). This will be called every frame per visual-companion entity
## starting in Story 002+, inside each system's already-centralized update
## pass (MonsterManager/ProjectileManager/TowerInstance/Hero — ADR-0037's
## Decision, "Position sync").
##
## IMPORTANT: the returned Vector3 is an ABSOLUTE world position, never a
## relative/local offset — a Node3D child of a Node2D parent does NOT
## inherit the parent's 2D transform (Node2D and Node3D are entirely
## separate transform hierarchies in Godot; ADR-0037's "Important engine
## clarification"). Callers must assign this directly to the visual
## companion's position, not add it to anything.
##
## Usage:
##   var world_pos: Vector3 = VisualMath.map_to_3d(monster.position, 0.0)
##   monster.visual_companion.position = world_pos
static func map_to_3d(pos2d: Vector2, layer_height: float) -> Vector3:
	return Vector3(pos2d.x, layer_height, pos2d.y)
