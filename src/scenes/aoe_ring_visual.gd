class_name AoeRingVisual
extends Node2D

## Purely cosmetic ground-plane detonation ring for BALLISTIC AoE weapon hits.
## design/gdd/tower.md "AoE Detonation": "Ground-plane impact ring expanding
## to AoE radius then fading (~0.4s)... this ring communicates exact AoE size
## and is a readability requirement, not decoration." Spawned by
## ProjectileVisual on BALLISTIC arrival whenever the firing weapon's
## aoe_radius_cells > 0 — plays regardless of whether damage was actually
## dealt (GDD: "Zero-damage detonations play full VFX and audio"), since this
## node has no link to damage resolution at all, only to the projectile's own
## visual arrival.
##
## Deferred (matches ProjectileVisual's own deferred scope): per-element
## particle burst layered on top — WeaponComponent has no per-element field
## yet, only archetype.

const DURATION: float = 0.4  ## seconds, per the GDD's "~0.4s" spec
const RING_WIDTH: float = 4.0

var _target_radius: float = 32.0
var _color: Color = Color.WHITE
var _elapsed: float = 0.0


## target_radius: world units (WeaponComponent.aoe_radius_cells * cell_size).
## color: the firing tower's archetype color, matching ProjectileVisual's own
## ARCHETYPE_COLORS (no distinct AoE-ring palette specified by the GDD).
func configure(target_radius: float, color: Color) -> void:
	_target_radius = target_radius
	_color = color


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = clampf(_elapsed / DURATION, 0.0, 1.0)
	var radius: float = _target_radius * t
	var color: Color = _color
	color.a = 1.0 - t
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color, RING_WIDTH, true)
