class_name ArmoredHitSparkVFX
extends Node2D

## design/gdd/monster.md "Archetype Tag Visual Feedback" → "Armored Hit
## Effect": "When a tower deals damage to an armored entity, the 50%
## mitigation must be visually distinguishable from an unmitigated hit...
## Required visual (one of): Metallic spark burst: 2-4 particles,
## silver/grey palette, at the hit point — distinct from the standard
## damage-flash white." (The other GDD-sanctioned option, a shield-flash
## sprite overlay, was not chosen — a standalone particle burst matches
## every other VFX node this session already built, and needs no access to
## the target MonsterEntity's own sprite internals.)
##
## "Hero damage is unaffected: Hero hits on armored entities use no
## mitigation and therefore no armored-hit visual. The armored visual is
## tower-hit-only." — this node is only ever spawned from ProjectileVisual's
## own is_armored flag (sourced from tower_attacked), never from any
## hero-attack path.
##
## No configure() needed — every field is fixed by the GDD's own spec
## (fixed particle count, fixed silver/grey color), so this just configures
## itself in _ready().

const DURATION: float = 0.25
const SPARK_COLOR: Color = Color(0.75, 0.78, 0.82)  ## silver/grey — distinct from a plain white flash

var _elapsed: float = 0.0

@onready var _particles: CPUParticles2D = $CPUParticles2D


func _ready() -> void:
	_particles.amount = 3  ## mid of the GDD's 2-4 particle spec
	_particles.lifetime = DURATION
	_particles.one_shot = true
	_particles.explosiveness = 1.0
	_particles.direction = Vector2.RIGHT
	_particles.spread = 180.0
	_particles.initial_velocity_min = 30.0
	_particles.initial_velocity_max = 70.0
	_particles.scale_amount_min = 1.5
	_particles.scale_amount_max = 3.0
	_particles.color = SPARK_COLOR

	var ramp := Gradient.new()
	ramp.set_color(0, Color(SPARK_COLOR, 1.0))
	ramp.set_color(1, Color(SPARK_COLOR, 0.0))
	_particles.color_ramp = ramp

	_particles.restart()
	_particles.emitting = true


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION:
		queue_free()
