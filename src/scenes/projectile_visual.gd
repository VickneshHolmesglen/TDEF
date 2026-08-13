class_name ProjectileVisual
extends Node2D

## Purely cosmetic flight-path visual for `tower_attacked` events (visual-only
## first pass per design/gdd/tower.md's "Projectile Types" section). Damage
## still resolves the way it always has via damage_status.gd's one-frame
## deferral — this node does NOT gate or delay damage delivery, matching
## Rule 20's "visual attack animations are cosmetic" framing.
##
## Deferred to a later, fully-scoped pass (not attempted here): HOMING
## re-acquisition when the original target dies before impact (this pass
## just dissipates), and instance pooling (spawned/freed per-shot like
## TowerInstance/MonsterInstance already are — acceptable at this project's
## current concurrent-tower scale, revisit if the GDD's 80 shots/sec peak
## becomes a real profiled cost). AoE detonation rings and per-element
## (fire/frost/poison/lightning) color ARE covered — see _spawn_aoe_ring()
## and ELEMENT_COLORS. Arcane is Alpha scope per the GDD's own staging and
## falls back to the generic elemental color.

const FLIGHT_SPEED: float = 900.0   ## world units/sec — BALLISTIC/HOMING travel time
const BEAM_DURATION: float = 0.15   ## seconds a BEAM stays visible
const HOMING_ARC_HEIGHT: float = 24.0  ## world units, curve bulge at flight midpoint
const TAIL_FRACTION: float = 0.08   ## fraction of flight behind the head for the trailing tail

## design/gdd/tower.md "Archetype projectile color language" table.
## Support/AURA towers never fire a projectile (Rule 5a) so are absent here.
const ARCHETYPE_COLORS: Dictionary[String, Color] = {
	"physical": Color(0.494, 0.522, 0.565),   ## Fieldstone Grey — matches project palette
	"ranged": Color(0.42, 0.28, 0.16),        ## brown / wood / metal
	"elemental": Color(0.65, 0.85, 1.0),      ## ice blue — generic fallback for an unset/unrecognized element
}

## design/gdd/tower.md "Elemental sub-type color language" table — Fire,
## Frost (MVP scope) and Poison, Lightning (Vertical Slice scope) all have
## real colors. Arcane is Alpha scope and has none yet; WeaponComponent.element
## == "arcane" (or any unrecognized value) falls through to
## ARCHETYPE_COLORS["elemental"] above.
const ELEMENT_COLORS: Dictionary[String, Color] = {
	"fire": Color(0.85, 0.35, 0.1),      ## red-orange
	"frost": Color(0.65, 0.85, 1.0),     ## ice blue / white
	"poison": Color(0.42, 0.8, 0.15),    ## acid green
	"lightning": Color(0.95, 0.9, 0.35), ## electric yellow / white
}

const AoeRingVisualScene: PackedScene = preload("res://src/scenes/AoeRingVisual.tscn")

var _projectile_type: String = "BALLISTIC"
var _target_entity: Node2D = null   ## weak by convention — validity checked every frame, never assumed
var _target_last_known: Vector2 = Vector2.ZERO
var _start_position: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0
var _flight_duration: float = 0.2
var _color: Color = Color.WHITE
var _aoe_radius: float = 0.0   ## world units; 0 = no detonation ring (BALLISTIC single-target or non-BALLISTIC)
var _element: String = ""      ## forwarded to the AoE ring for its own per-element particle burst

@onready var _line: Line2D = $Line2D


## archetype: FoundationComponent.archetype ("physical"/"ranged"/"elemental").
## projectile_type: WeaponComponent.projectile_type ("HOMING"/"BALLISTIC"/"BEAM").
## target: the live MonsterEntity being fired at — may already be null/freed
## by the time this is called (same-frame death race); handled gracefully.
## aoe_radius: world units (already cell-size-scaled by the caller). Only
## meaningful for BALLISTIC — WeaponComponent.aoe_radius_cells is BALLISTIC-only
## per its own doc comment, but this is re-checked at arrival time regardless.
## element: WeaponComponent.element — only consulted when archetype is
## "elemental"; ignored (and harmless if non-empty) for every other archetype.
func configure(archetype: String, projectile_type: String, start_pos: Vector2, target: Node2D,
		aoe_radius: float = 0.0, element: String = "") -> void:
	_projectile_type = projectile_type
	_start_position = start_pos
	global_position = start_pos
	_target_entity = target
	_target_last_known = target.global_position if is_instance_valid(target) else start_pos
	_aoe_radius = aoe_radius
	_element = element

	if archetype == "elemental" and ELEMENT_COLORS.has(element):
		_color = ELEMENT_COLORS[element]
	else:
		_color = ARCHETYPE_COLORS.get(archetype, Color.WHITE)
	_line.default_color = _color

	if projectile_type == "BEAM":
		_flight_duration = BEAM_DURATION
		_line.width = 5.0
	else:
		_flight_duration = maxf(_start_position.distance_to(_target_last_known) / FLIGHT_SPEED, 0.05)
		_line.width = 3.0


func _process(delta: float) -> void:
	_elapsed += delta
	match _projectile_type:
		"BEAM":
			_update_beam()
		"HOMING":
			_update_homing()
		_:
			_update_ballistic()
	if _elapsed >= _flight_duration:
		if _projectile_type == "BALLISTIC" and _aoe_radius > 0.0:
			_spawn_aoe_ring()
		queue_free()


## design/gdd/tower.md "AoE Detonation": plays on every BALLISTIC AoE arrival,
## including zero-damage detonations — this node has no knowledge of whether
## damage was actually dealt, it fires purely off the projectile's own visual
## arrival, which is exactly the always-play behavior the GDD requires.
func _spawn_aoe_ring() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var ring: Node2D = AoeRingVisualScene.instantiate()
	parent.add_child(ring)
	ring.global_position = global_position
	ring.configure(_aoe_radius, _color, _element)


## Instant connection, persists for BEAM_DURATION, then cuts — no travel.
func _update_beam() -> void:
	var target_pos: Vector2 = _target_entity.global_position if is_instance_valid(_target_entity) else _target_last_known
	_line.points = [to_local(_start_position), to_local(target_pos)]


## Straight flight path to the target's fire-time position (Rule 19: BALLISTIC
## continues to the last-known position, it does not re-track a moving target).
func _update_ballistic() -> void:
	var t: float = clampf(_elapsed / _flight_duration, 0.0, 1.0)
	global_position = _start_position.lerp(_target_last_known, t)
	var tail_t: float = maxf(t - TAIL_FRACTION, 0.0)
	_line.points = [to_local(_start_position.lerp(_target_last_known, tail_t)), Vector2.ZERO]


## Curved flight path that tracks the live target each frame. If the target
## is freed mid-flight (died), dissipates on the spot — trail fades over the
## remaining short window, no detonation. Full re-acquisition-on-death
## (GDD Rule 19) is out of scope for this visual-only pass.
func _update_homing() -> void:
	if not is_instance_valid(_target_entity):
		_flight_duration = minf(_flight_duration, _elapsed + 0.2)
		return
	_target_last_known = _target_entity.global_position

	var t: float = clampf(_elapsed / _flight_duration, 0.0, 1.0)
	var to_target: Vector2 = _target_last_known - _start_position
	var perp: Vector2 = to_target.orthogonal().normalized() if to_target.length_squared() > 0.0 else Vector2.ZERO

	var head_bulge: float = sin(t * PI) * HOMING_ARC_HEIGHT
	global_position = _start_position.lerp(_target_last_known, t) + perp * head_bulge

	var tail_t: float = maxf(t - TAIL_FRACTION, 0.0)
	var tail_bulge: float = sin(tail_t * PI) * HOMING_ARC_HEIGHT
	var tail_pos: Vector2 = _start_position.lerp(_target_last_known, tail_t) + perp * tail_bulge
	_line.points = [to_local(tail_pos), Vector2.ZERO]
