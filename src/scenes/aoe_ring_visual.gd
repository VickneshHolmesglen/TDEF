class_name AoeRingVisual
extends Node2D

## Purely cosmetic ground-plane detonation ring for BALLISTIC AoE weapon hits.
## design/gdd/tower.md "AoE Detonation": "Ground-plane impact ring expanding
## to AoE radius then fading (~0.4s)... this ring communicates exact AoE size
## and is a readability requirement, not decoration. Per-element particle
## burst layered on top." Spawned by ProjectileVisual on BALLISTIC arrival
## whenever the firing weapon's aoe_radius_cells > 0 — plays regardless of
## whether damage was actually dealt (GDD: "Zero-damage detonations play full
## VFX and audio"), since this node has no link to damage resolution at all,
## only to the projectile's own visual arrival.
##
## Element particle signatures follow tower.md's "Elemental sub-type color
## language" table's own Visual signature column (fire=ember/heat, frost=
## crystalline/snowflake, poison=cloud puff, lightning=fast sharp burst).
## Arcane has no assigned signature yet (Alpha scope) and gets no particle
## burst, matching ProjectileVisual's own ELEMENT_COLORS fallback treatment.
## Non-elemental archetypes (physical/ranged BALLISTIC AoE) never call
## configure() with a recognized element, so they get the ring only, exactly
## as before this pass — the GDD's particle-burst mandate is elemental-only.

const DURATION: float = 0.4  ## seconds, per the GDD's "~0.4s" spec
const RING_WIDTH: float = 4.0

## Per-element one-shot burst parameters. Color is NOT duplicated here — it
## always comes from the same `color` configure() already receives for the
## ring itself (ProjectileVisual's own ELEMENT_COLORS), so ring and particles
## can never desync in hue.
const ELEMENT_PARTICLE_CONFIGS: Dictionary[String, Dictionary] = {
	"fire": {
		"amount": 16, "lifetime": 0.5,
		"velocity_min": 40.0, "velocity_max": 90.0,
		"gravity": Vector2(0.0, -60.0),  ## heat rises
		"scale_min": 3.0, "scale_max": 6.0,
	},
	"frost": {
		"amount": 14, "lifetime": 0.6,
		"velocity_min": 20.0, "velocity_max": 50.0,
		"gravity": Vector2(0.0, 40.0),  ## snowflakes settle
		"scale_min": 2.0, "scale_max": 4.0,
	},
	"poison": {
		"amount": 10, "lifetime": 0.7,  ## slow, lingering cloud puff
		"velocity_min": 10.0, "velocity_max": 30.0,
		"gravity": Vector2.ZERO,
		"scale_min": 5.0, "scale_max": 9.0,
	},
	"lightning": {
		"amount": 10, "lifetime": 0.25,  ## fast, sharp, gone almost instantly
		"velocity_min": 80.0, "velocity_max": 160.0,
		"gravity": Vector2.ZERO,
		"scale_min": 1.5, "scale_max": 3.0,
	},
}

var _target_radius: float = 32.0
var _color: Color = Color.WHITE
var _elapsed: float = 0.0
## DURATION unless an element burst is active and its own lifetime runs
## longer — the ring's own fade timing (_draw()) is never affected by this,
## only how long this node stays alive to let the particle burst finish.
var _self_destruct_time: float = DURATION

@onready var _particles: CPUParticles2D = $CPUParticles2D


## target_radius: world units (WeaponComponent.aoe_radius_cells * cell_size).
## color: the firing tower's archetype/element color, matching
## ProjectileVisual's own ARCHETYPE_COLORS/ELEMENT_COLORS (no distinct
## AoE-ring palette specified by the GDD).
## element: WeaponComponent.element — only recognized values in
## ELEMENT_PARTICLE_CONFIGS get a particle burst; anything else (including
## "" for non-elemental archetypes, and "arcane") gets the ring only.
func configure(target_radius: float, color: Color, element: String = "") -> void:
	_target_radius = target_radius
	_color = color
	_self_destruct_time = DURATION
	if ELEMENT_PARTICLE_CONFIGS.has(element):
		_spawn_particle_burst(color, ELEMENT_PARTICLE_CONFIGS[element] as Dictionary)


func _spawn_particle_burst(color: Color, config: Dictionary) -> void:
	var lifetime: float = config["lifetime"] as float
	_self_destruct_time = maxf(_self_destruct_time, lifetime)

	_particles.amount = config["amount"] as int
	_particles.lifetime = lifetime
	_particles.one_shot = true
	_particles.explosiveness = 1.0
	_particles.direction = Vector2.RIGHT
	_particles.spread = 180.0  ## full radial burst, combined with direction above
	_particles.initial_velocity_min = config["velocity_min"] as float
	_particles.initial_velocity_max = config["velocity_max"] as float
	_particles.gravity = config["gravity"] as Vector2
	_particles.scale_amount_min = config["scale_min"] as float
	_particles.scale_amount_max = config["scale_max"] as float
	_particles.color = color

	var ramp := Gradient.new()
	ramp.set_color(0, Color(color, 1.0))
	ramp.set_color(1, Color(color, 0.0))
	_particles.color_ramp = ramp

	_particles.restart()
	_particles.emitting = true


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _self_destruct_time:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = clampf(_elapsed / DURATION, 0.0, 1.0)
	var radius: float = _target_radius * t
	var color: Color = _color
	color.a = 1.0 - t
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color, RING_WIDTH, true)
