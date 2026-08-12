class_name StructureCastShadow
extends Control

## Cast-shadow layer for a Diorama structure sprite — closes the art bible's
## Principle 1 ("Everything Has Weight and Depth") requirement that objects
## use stacked sprite layers with a cast-shadow sprite beneath them, not a
## single sprite alone. Pure `_draw()`-based view component, no EventBus
## subscriptions of its own — matches TowerMasteryArc's established
## "pure view component" convention (src/core/tower_mastery/tower_mastery_arc.gd).
##
## A code-drawn soft ellipse rather than a generated texture: the art bible's
## own design test ("if removing the shadow sprite makes the object look
## pasted onto the ground, the layering is insufficient") is about the
## PRESENCE of a distinct ground-contact layer, not requiring a hand-painted
## shadow asset specifically — this closes the structural gap immediately
## without a new ChatGPT-generation round-trip for a shape this simple to
## draw procedurally. Ground-plane contact shadow only (no cast-direction
## lean) — this diorama has no established light-direction convention to
## cast toward yet.

const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.4)

## Ellipse size, in local pixels — sized to sit under the structure sprite's
## base, not its full silhouette (a wide, flat ellipse reads as ground
## contact; a shape matching the sprite's own width/height would read as a
## second copy of the sprite, not a shadow).
var ellipse_size: Vector2 = Vector2(48.0, 16.0)


## Real gap found live (2026-08-13): Godot 4.6 already has a native
## CanvasItem.draw_ellipse(position, width, height, color, ...) method —
## post-LLM-training-cutoff, undocumented in this project's own
## docs/engine-reference/godot/VERSION.md until now (no Autoload-adjacent
## risk item covers CanvasItem drawing APIs). An earlier draft of this file
## defined its own same-named draw_ellipse() polygon-approximation helper,
## which Godot rejected as an incompatible override of the native method
## (signature mismatch, "Warning treated as error" at compile time) rather
## than silently shadowing it. Uses the real native method directly.
func _draw() -> void:
	draw_ellipse(size / 2.0, size.x, size.y, SHADOW_COLOR)
