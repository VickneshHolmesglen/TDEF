class_name TowerDestroyVFX
extends Node2D

## Purely cosmetic tower-destruction VFX. design/gdd/tower.md "Tower DESTROYED
## (Terminal)" Visual sequence:
##   1. Red flash (1 frame)
##   2. Archetype-appropriate destruction VFX: debris burst (physical),
##      scatter (ranged), extinguish/shatter (elemental), resonance fade
##      (support)
##   3. Grid cells immediately read as PLACEABLE — no visual remnant on cells
##   4. Optional: brief camera micro-shake to punctuate the event
## Step 3 is already true by construction: TowerSystem calls
## Grid.remove_tower() and erases placed_towers BEFORE emitting
## tower_destroyed, and mission_scene.gd's handler frees the TowerInstance
## immediately and spawns this in its place — no wreckage lingers on the
## grid. Step 4 is explicitly optional and skipped (camera shake is a
## cross-cutting concern this pass doesn't need).
##
## Distinct from PlacementRejectFlash (which pulses 2-3 times over the
## footprint) — this flashes once, briefly, then a particle burst follows.
## Distinct from TowerInstance.play_remove_animation() (voluntary removal —
## calm dissolve, no flash, no debris) — this is the violent counterpart.

const FLASH_DURATION: float = 0.08  ## seconds — GDD says "1 frame"; extended slightly for visibility at 60fps
const FLASH_COLOR: Color = Color(1.0, 0.15, 0.15, 0.75)

## Color per archetype's own defined palette (ARCHETYPE_COLORS equivalents
## already established by ProjectileVisual — duplicated as literals here
## rather than cross-referencing since Support has no projectile color of
## its own to borrow, and duplicating 4 Color literals is simpler than a
## partial cross-file dependency). "elemental"'s color is a generic fallback,
## overridden by the tower's actual element via ProjectileVisual.ELEMENT_COLORS
## when recognized — see configure().
const ARCHETYPE_DESTROY_CONFIGS: Dictionary[String, Dictionary] = {
	"physical": {  ## debris burst — heavy, falls
		"color": Color(0.494, 0.522, 0.565),
		"amount": 14, "lifetime": 0.5,
		"velocity_min": 30.0, "velocity_max": 70.0,
		"gravity": Vector2(0.0, 120.0), "scale_min": 3.0, "scale_max": 6.0,
	},
	"ranged": {  ## scatter — wide, fast, lighter fall
		"color": Color(0.42, 0.28, 0.16),
		"amount": 16, "lifetime": 0.45,
		"velocity_min": 50.0, "velocity_max": 110.0,
		"gravity": Vector2(0.0, 90.0), "scale_min": 2.0, "scale_max": 4.0,
	},
	"elemental": {  ## extinguish/shatter — fast, sharp, no gravity
		"color": Color(0.65, 0.85, 1.0),  ## generic fallback, overridden by element
		"amount": 18, "lifetime": 0.4,
		"velocity_min": 60.0, "velocity_max": 140.0,
		"gravity": Vector2.ZERO, "scale_min": 3.0, "scale_max": 6.0,
	},
	"support": {  ## resonance fade — gentle, in place, no burst outward
		"color": Color(0.95, 0.75, 0.3),
		"amount": 10, "lifetime": 0.7,
		"velocity_min": 5.0, "velocity_max": 15.0,
		"gravity": Vector2.ZERO, "scale_min": 3.0, "scale_max": 5.0,
		"orbit_min": 1.0, "orbit_max": 2.0,
	},
}

var _elapsed: float = 0.0
var _self_destruct_time: float = FLASH_DURATION
var _footprint_size: Vector2 = Vector2(64.0, 64.0)

@onready var _particles: CPUParticles2D = $CPUParticles2D


## archetype: FoundationComponent.archetype. element: TowerInstance.element
## (cached at placement time — only meaningful when archetype == "elemental";
## unrecognized/empty falls back to the generic elemental color).
## footprint_size: world units — sizes the red-flash rect only.
func configure(archetype: String, element: String, footprint_size: Vector2) -> void:
	_footprint_size = footprint_size
	var config: Dictionary = ARCHETYPE_DESTROY_CONFIGS.get(archetype, ARCHETYPE_DESTROY_CONFIGS["physical"]) as Dictionary
	var color: Color = config["color"] as Color
	if archetype == "elemental" and ProjectileVisual.ELEMENT_COLORS.has(element):
		color = ProjectileVisual.ELEMENT_COLORS[element]
	_spawn_burst(color, config)


func _spawn_burst(color: Color, config: Dictionary) -> void:
	var lifetime: float = config["lifetime"] as float
	_self_destruct_time = maxf(FLASH_DURATION, lifetime)

	_particles.amount = config["amount"] as int
	_particles.lifetime = lifetime
	_particles.one_shot = true
	_particles.explosiveness = 1.0
	_particles.direction = Vector2.RIGHT
	_particles.spread = 180.0
	_particles.initial_velocity_min = config["velocity_min"] as float
	_particles.initial_velocity_max = config["velocity_max"] as float
	_particles.gravity = config["gravity"] as Vector2
	_particles.scale_amount_min = config["scale_min"] as float
	_particles.scale_amount_max = config["scale_max"] as float
	_particles.orbit_velocity_min = config.get("orbit_min", 0.0) as float
	_particles.orbit_velocity_max = config.get("orbit_max", 0.0) as float
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
	if _elapsed >= FLASH_DURATION:
		return
	var half: Vector2 = _footprint_size * 0.5
	var color: Color = FLASH_COLOR
	color.a *= 1.0 - (_elapsed / FLASH_DURATION)
	draw_rect(Rect2(-half, _footprint_size), color, true)
