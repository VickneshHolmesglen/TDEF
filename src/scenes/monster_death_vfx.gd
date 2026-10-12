class_name MonsterDeathVFX
extends Node2D

## Purely cosmetic monster-death VFX. design/gdd/monster.md "Death VFX —
## death_vfx_scene Specification": "Instantiated at entity.global_position...
## when lifecycle_state = DEAD. Self-terminates and queue-frees after
## playing. Monster System does not manage VFX lifecycle after
## instantiation. Death VFX is NOT instantiated on breach." Spawned by
## mission_scene.gd's monster_died/monsters_died_batch subscriptions —
## MonsterManager's own entity is already queue_free()'d independently of
## this node; there is nothing here to coordinate with it.
##
## Per-tier minimum content (GDD table):
##   STANDARD (0.3-0.5s): particle burst (8-12) + sprite dissolve
##   ELITE    (0.4-0.7s): particle burst (12-20, silver/cold-white) + sprite
##                        dissolve + shockwave ring (~1 cell diameter)
##   BOSS     (0.8-1.2s): particle burst (20-30, aura color) + sprite
##                        dissolve + shockwave ring (~2 cell diameter) +
##                        screen micro-shake (triggered by the caller —
##                        mission_scene.gd owns the camera reference, not
##                        this node; see _on_monster_died's own comment)
## "Sprite dissolve" is a fading ghost copy of the monster's own real
## texture (MonsterInstance.MONSTER_TEXTURES) at its death position, not a
## copy of the live (already-freeing) entity — matches the GDD's own
## "Monster System does not manage VFX lifecycle" independence note.

const TIER_CONFIGS: Dictionary[int, Dictionary] = {
	0: {  ## STANDARD
		"duration": 0.4, "dissolve_duration": 0.25,
		"color": Color(0.9, 0.6, 0.1),  ## matches this project's existing monster base-palette convention
		"amount": 10, "velocity_min": 20.0, "velocity_max": 50.0,
		"scale_min": 2.0, "scale_max": 4.0,
		"ring_diameter": 0.0,  ## no shockwave ring at STANDARD
	},
	1: {  ## ELITE
		"duration": 0.55, "dissolve_duration": 0.25,
		"color": Color(0.784, 0.847, 0.909),  ## silver / cold-white, GDD's own #C8D8E8 provisional value
		"amount": 16, "velocity_min": 30.0, "velocity_max": 70.0,
		"scale_min": 2.5, "scale_max": 5.0,
		"ring_diameter": 64.0,  ## ~1 cell
		"ring_duration": 0.5,  ## fades fully before the GDD's 0.7s ceiling
	},
	2: {  ## BOSS
		"duration": 1.0, "dissolve_duration": 0.3,
		"color": Color(0.55, 0.1, 0.15),  ## deep crimson boss-aura color
		"amount": 25, "velocity_min": 40.0, "velocity_max": 100.0,
		"scale_min": 4.0, "scale_max": 7.0,
		"ring_diameter": 128.0,  ## ~2 cells
		"ring_duration": 0.6,
	},
}

const AoeRingVisualScene: PackedScene = preload("res://src/scenes/AoeRingVisual.tscn")

var _elapsed: float = 0.0
var _self_destruct_time: float = 0.4

@onready var _particles: CPUParticles2D = $CPUParticles2D
@onready var _dissolve_sprite: Sprite2D = $DissolveSprite
const DISSOLVE_SHADER: Shader = preload("res://src/shaders/dissolve.gdshader")


## monster_id/tier: from MonsterDiedEvent — tier selects TIER_CONFIGS (any
## unrecognized value falls back to STANDARD's config, matching this
## session's established unrecognized-value-fallback convention).
func configure(monster_id: StringName, tier: int) -> void:
	var config: Dictionary = TIER_CONFIGS.get(tier, TIER_CONFIGS[0]) as Dictionary
	_self_destruct_time = config["duration"] as float

	_spawn_dissolve_ghost(monster_id, tier, config)
	_spawn_particle_burst(config)
	if (config.get("ring_diameter", 0.0) as float) > 0.0:
		_spawn_shockwave_ring(config)


func _spawn_dissolve_ghost(monster_id: StringName, tier: int, config: Dictionary) -> void:
	var texture: Texture2D = MonsterInstance.MONSTER_TEXTURES.get(monster_id, null) as Texture2D
	if texture == null:
		return
	_dissolve_sprite.texture = texture
	var target_long_edge: float = MonsterInstance.TARGET_LONG_EDGE_BY_TIER.get(tier, 64.0) as float
	var longest_edge: float = maxf(texture.get_width(), texture.get_height())
	_dissolve_sprite.scale = Vector2.ONE * (target_long_edge / longest_edge)

	var dissolve_duration: float = config["dissolve_duration"] as float
	# HD-2D effects pass: the ghost breaks apart in blocks the size of the
	# sprite's own art pixels (dissolve.gdshader) instead of a smooth fade.
	# Pixel sprites are 46 px on the long edge (80 for bosses), see
	# tools/asset-pipeline/hd2d/pixelate_sprites.py.
	var art_long_edge: float = 80.0 if tier >= 2 else 46.0
	var mat := ShaderMaterial.new()
	mat.shader = DISSOLVE_SHADER
	mat.set_shader_parameter(&"cells", Vector2(texture.get_size()) * (art_long_edge / longest_edge))
	mat.set_shader_parameter(&"dissolve_amount", 0.0)
	_dissolve_sprite.material = mat
	var tween := create_tween()
	tween.tween_property(mat, "shader_parameter/dissolve_amount", 1.0, dissolve_duration)


func _spawn_particle_burst(config: Dictionary) -> void:
	var color: Color = config["color"] as Color
	_particles.amount = config["amount"] as int
	_particles.lifetime = _self_destruct_time
	_particles.one_shot = true
	_particles.explosiveness = 1.0
	_particles.direction = Vector2.RIGHT
	_particles.spread = 180.0
	_particles.initial_velocity_min = config["velocity_min"] as float
	_particles.initial_velocity_max = config["velocity_max"] as float
	_particles.scale_amount_min = config["scale_min"] as float
	_particles.scale_amount_max = config["scale_max"] as float
	_particles.color = color

	var ramp := Gradient.new()
	ramp.set_color(0, Color(color, 1.0))
	ramp.set_color(1, Color(color, 0.0))
	_particles.color_ramp = ramp
	PixelVfx.style_particles(_particles)

	_particles.restart()
	_particles.emitting = true


func _spawn_shockwave_ring(config: Dictionary) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var ring: Node2D = AoeRingVisualScene.instantiate()
	parent.add_child(ring)
	ring.global_position = global_position
	var radius: float = (config["ring_diameter"] as float) * 0.5
	ring.configure(radius, config["color"] as Color, "", config["ring_duration"] as float)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _self_destruct_time:
		queue_free()
