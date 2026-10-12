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
## (fire/frost/poison/lightning/arcane) color ARE covered — see
## _spawn_aoe_ring() and ELEMENT_COLORS. Per-element flight-trail particles
## ARE covered — see ELEMENT_TRAIL_CONFIGS and _tail_points() for why
## lightning is deliberately excluded from the particle trail.

const FLIGHT_SPEED: float = 900.0   ## world units/sec — BALLISTIC/HOMING travel time
const BEAM_DURATION: float = 0.15   ## seconds a BEAM stays visible
const HOMING_ARC_HEIGHT: float = 24.0  ## world units, curve bulge at flight midpoint
const TAIL_FRACTION: float = 0.08   ## fraction of flight behind the head for the trailing tail
const JAGGED_SEGMENTS: int = 3      ## midpoints along lightning's tail, jittered every frame
const JAGGED_JITTER: float = 6.0    ## world units, max perpendicular offset per jagged midpoint

## design/gdd/tower.md "Archetype projectile color language" table.
## Support/AURA towers never fire a projectile (Rule 5a), so "support" was
## absent here until 2026-09-01, when hero-skill-build.md's UI Requirements
## ("Archetype identity per slot" — Support warm gold) needed a canonical
## color for a non-projectile consumer (hero_skill_build_screen.gd) — added
## here rather than a second, competing table, matching this constant's own
## established "the same visual vocabulary, every consumer" role (see its
## callers' doc comments across tower_instance.gd/aoe_ring_visual.gd/
## mission_scene.gd/tower_destroy_vfx.gd).
const ARCHETYPE_COLORS: Dictionary[String, Color] = {
	"physical": Color(0.494, 0.522, 0.565),   ## Fieldstone Grey — matches project palette
	"ranged": Color(0.42, 0.28, 0.16),        ## brown / wood / metal
	"elemental": Color(0.65, 0.85, 1.0),      ## ice blue — generic fallback for an unset/unrecognized element
	"support": Color(0.85, 0.7, 0.25),        ## warm gold — non-projectile archetype, added 2026-09-01
}

## design/gdd/tower.md "Elemental sub-type color language" table — Fire,
## Frost (MVP scope), Poison, Lightning (Vertical Slice scope), and Arcane
## (Alpha scope) all have real colors now. WeaponComponent.element for any
## unrecognized value falls through to ARCHETYPE_COLORS["elemental"] above.
const ELEMENT_COLORS: Dictionary[String, Color] = {
	"fire": Color(0.85, 0.35, 0.1),      ## red-orange
	"frost": Color(0.65, 0.85, 1.0),     ## ice blue / white
	"poison": Color(0.42, 0.8, 0.15),    ## acid green
	"lightning": Color(0.95, 0.9, 0.35), ## electric yellow / white
	"arcane": Color(0.55, 0.25, 0.75),   ## purple / violet
}

## design/gdd/tower.md "Elemental sub-type color language" table's own Visual
## signature column: fire=ember/heat, frost=crystalline/snowflake, poison=drip,
## arcane=geometric fragments/no physical material. Lightning ("jagged arc, no
## smooth trail") is deliberately absent — a smooth continuous particle trail
## would contradict its own defined signature; see _tail_points() for how
## lightning is differentiated instead.
## "orbit_min"/"orbit_max" (optional, default 0 via .get() in
## _start_trail_particles) drive CPUParticles2D.orbit_velocity — arcane's own
## "no physical material" signature: fragments circle the flight path instead
## of moving directly outward like the other 3 elements' straightforward drift.
const ELEMENT_TRAIL_CONFIGS: Dictionary[String, Dictionary] = {
	"fire": {
		"amount": 8, "lifetime": 0.3,
		"velocity_min": 5.0, "velocity_max": 20.0,
		"gravity": Vector2(0.0, -30.0),  ## embers drift upward
		"scale_min": 2.0, "scale_max": 4.0,
	},
	"frost": {
		"amount": 6, "lifetime": 0.35,
		"velocity_min": 5.0, "velocity_max": 15.0,
		"gravity": Vector2.ZERO,  ## crystalline fragments hang, don't drift
		"scale_min": 1.5, "scale_max": 3.0,
	},
	"poison": {
		"amount": 6, "lifetime": 0.4,
		"velocity_min": 5.0, "velocity_max": 10.0,
		"gravity": Vector2(0.0, 40.0),  ## drip particles fall
		"scale_min": 2.0, "scale_max": 3.5,
	},
	"arcane": {
		"amount": 7, "lifetime": 0.4,
		"velocity_min": 2.0, "velocity_max": 8.0,
		"gravity": Vector2.ZERO,  ## no physical material -- nothing pulls on it
		"scale_min": 2.0, "scale_max": 3.5,
		"orbit_min": 1.5, "orbit_max": 3.5,
	},
}

const AoeRingVisualScene: PackedScene = preload("res://src/scenes/AoeRingVisual.tscn")
const ArmoredHitSparkVFXScene: PackedScene = preload("res://src/scenes/ArmoredHitSparkVFX.tscn")

## Epic 15 Story 006 (ADR-0037): shared mesh-mapping id for every
## ProjectileVisual instance, regardless of archetype/element/projectile_type
## — mirrors MonsterInstance.MONSTER_MESH_ENTITY_ID's "one shared id proves
## the pattern" judgment call (only one projectile type needs conversion to
## satisfy this story's Acceptance Criteria, matching the scope discipline
## Stories 003-005 already established). Resolves to
## assets/data/visual_meshes/projectile_bolt.tres (weapon-ammo-bullet.glb,
## Kenney-style Phase 1 placeholder art, per this epic's own scope note that
## replacing placeholder art is a separate future Phase 6).
const PROJECTILE_MESH_ENTITY_ID: StringName = &"projectile_bolt"

## World units, small positive offset (not 0.0 like the ground-anchored
## Tower/Monster/Hero/Tile companions) — ADR-0037's Decision: "VFX/floating
## elements get a small positive offset." A flying projectile is the first
## airborne (not ground-anchored) companion in this epic; this exact value is
## an unverified Phase 1 placeholder tuning choice, not derived from any
## live-queried AABB data or GDD requirement (out of scope here per the
## story's own "Out of Scope" section — VFX/impact visual work is Phase 3).
const PROJECTILE_LAYER_HEIGHT: float = 20.0

var _projectile_type: String = "BALLISTIC"
var _target_entity: Node2D = null   ## weak by convention — validity checked every frame, never assumed
var _target_last_known: Vector2 = Vector2.ZERO
var _start_position: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0
var _flight_duration: float = 0.2
var _color: Color = Color.WHITE
var _aoe_radius: float = 0.0   ## world units; 0 = no detonation ring (BALLISTIC single-target or non-BALLISTIC)
var _element: String = ""      ## forwarded to the AoE ring for its own per-element particle burst
var _is_armored: bool = false  ## design/gdd/monster.md "Armored Hit Effect" — spawns a spark on arrival

@onready var _line: Line2D = $Line2D
@onready var _trail_particles: CPUParticles2D = $TrailParticles2D

## Epic 15 Story 006 (ADR-0037): this instance's Node3D visual-companion
## subtree, built once by _build_visual_companion() (see that method's own
## doc comment for why "once" is correct here, unlike a rebuild-guarded
## precedent). Null until configure() runs; may remain null afterward if the
## mesh mapping was missing/invalid (see _build_visual_companion()).
var _visual_companion: Node3D = null


## archetype: FoundationComponent.archetype ("physical"/"ranged"/"elemental").
## projectile_type: WeaponComponent.projectile_type ("HOMING"/"BALLISTIC"/"BEAM").
## target: the live MonsterEntity being fired at — may already be null/freed
## by the time this is called (same-frame death race); handled gracefully.
## aoe_radius: world units (already cell-size-scaled by the caller). Only
## meaningful for BALLISTIC — WeaponComponent.aoe_radius_cells is BALLISTIC-only
## per its own doc comment, but this is re-checked at arrival time regardless.
## element: WeaponComponent.element — only consulted when archetype is
## "elemental"; ignored (and harmless if non-empty) for every other archetype.
## is_armored: tower_attacked's own is_armored flag (pre-resolved by Tower
## System — this node never reads monster state directly, matching D&S's
## own "never reads monster state directly" convention). Hero hits never
## set this — see ArmoredHitSparkVFX's own doc comment for why.
func configure(archetype: String, projectile_type: String, start_pos: Vector2, target: Node2D,
		aoe_radius: float = 0.0, element: String = "", is_armored: bool = false) -> void:
	_projectile_type = projectile_type
	_start_position = start_pos
	global_position = start_pos
	_target_entity = target
	_target_last_known = target.global_position if is_instance_valid(target) else start_pos
	_aoe_radius = aoe_radius
	_element = element
	_is_armored = is_armored

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
		if ELEMENT_TRAIL_CONFIGS.has(element):
			_start_trail_particles(ELEMENT_TRAIL_CONFIGS[element] as Dictionary)
	PixelVfx.style_line(_line)

	# Epic 15 Story 006 (ADR-0037): builds the 3D visual companion, seeded at
	# _start_position, so a projectile fired this frame has a correctly-placed
	# companion on its very first visible frame — no one-frame lag before
	# _process()'s first sync call. See _build_visual_companion()'s own doc
	# comment for why this project's real per-shot create/destroy lifecycle
	# (not a reused pool — see that method's doc comment for the ADR-0019 gap
	# this deviates from) makes "build once, here" the correct call site.
	_build_visual_companion()


## Continuous emission (not one-shot like the AoE ring's burst) — particles
## stream from the projectile's current position every frame it's in flight.
## local_coords=false is required for a real trailing look: emitted particles
## must stay fixed in world space, not glued to the fast-moving emitter.
func _start_trail_particles(config: Dictionary) -> void:
	_trail_particles.amount = config["amount"] as int
	_trail_particles.lifetime = config["lifetime"] as float
	_trail_particles.one_shot = false
	_trail_particles.local_coords = false
	_trail_particles.direction = Vector2.RIGHT
	_trail_particles.spread = 180.0
	_trail_particles.initial_velocity_min = config["velocity_min"] as float
	_trail_particles.initial_velocity_max = config["velocity_max"] as float
	_trail_particles.gravity = config["gravity"] as Vector2
	_trail_particles.scale_amount_min = config["scale_min"] as float
	_trail_particles.scale_amount_max = config["scale_max"] as float
	_trail_particles.orbit_velocity_min = config.get("orbit_min", 0.0) as float
	_trail_particles.orbit_velocity_max = config.get("orbit_max", 0.0) as float
	_trail_particles.color = _color

	var ramp := Gradient.new()
	ramp.set_color(0, Color(_color, 1.0))
	ramp.set_color(1, Color(_color, 0.0))
	_trail_particles.color_ramp = ramp
	PixelVfx.style_particles(_trail_particles)

	_trail_particles.emitting = true


func _process(delta: float) -> void:
	_elapsed += delta
	match _projectile_type:
		"BEAM":
			_update_beam()
		"HOMING":
			_update_homing()
		_:
			_update_ballistic()
	# Epic 15 Story 006 (ADR-0037): the one line this story adds to
	# ProjectileVisual's EXISTING _process() (pre-existing before this story —
	# not a new callback; see _sync_visual_companion_position()'s own doc
	# comment). Runs after the match block above so the companion syncs
	# against this frame's fully-resolved global_position (each
	# _update_*() branch has already finalized it for this frame).
	_sync_visual_companion_position()
	if _elapsed >= _flight_duration:
		if _projectile_type == "BALLISTIC" and _aoe_radius > 0.0:
			_spawn_aoe_ring()
		if _is_armored:
			_spawn_armored_spark()
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


## design/gdd/monster.md "Armored Hit Effect" — plays at the hit point on
## arrival, for every projectile_type (BALLISTIC/HOMING/BEAM alike), not
## just AoE hits. Uses the target's live position if it's still around,
## falling back to the last-known position if it died mid-flight (same
## fallback convention as _update_ballistic/_update_homing use already).
func _spawn_armored_spark() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var spark: Node2D = ArmoredHitSparkVFXScene.instantiate()
	parent.add_child(spark)
	spark.global_position = _target_entity.global_position if is_instance_valid(_target_entity) else _target_last_known


## Returns the Line2D points for the trailing tail: a plain straight segment
## for every element except lightning, which gets a jittered multi-point
## zigzag instead — "Jagged arc, no smooth trail" (tower.md's own Visual
## signature for lightning) means it must NOT look like the other elements'
## smooth line, so this is a real visual differentiator, not decoration.
## Jitter is recomputed fresh every frame (not cached), producing a flickering
## look distinct from every other projectile_type's stable line.
func _tail_points(tail_local: Vector2, head_local: Vector2) -> PackedVector2Array:
	if _element != "lightning":
		return PackedVector2Array([tail_local, head_local])
	var points := PackedVector2Array()
	points.append(tail_local)
	var segment: Vector2 = head_local - tail_local
	var perp: Vector2 = segment.orthogonal().normalized() if segment.length_squared() > 0.0 else Vector2.ZERO
	for i in range(1, JAGGED_SEGMENTS + 1):
		var along: float = float(i) / float(JAGGED_SEGMENTS + 1)
		var base: Vector2 = tail_local.lerp(head_local, along)
		var jitter: float = randf_range(-JAGGED_JITTER, JAGGED_JITTER)
		points.append(base + perp * jitter)
	points.append(head_local)
	return points


## Instant connection, persists for BEAM_DURATION, then cuts — no travel.
func _update_beam() -> void:
	var target_pos: Vector2 = _target_entity.global_position if is_instance_valid(_target_entity) else _target_last_known
	_line.points = _tail_points(to_local(_start_position), to_local(target_pos))


## Straight flight path to the target's fire-time position (Rule 19: BALLISTIC
## continues to the last-known position, it does not re-track a moving target).
func _update_ballistic() -> void:
	var t: float = clampf(_elapsed / _flight_duration, 0.0, 1.0)
	global_position = _start_position.lerp(_target_last_known, t)
	var tail_t: float = maxf(t - TAIL_FRACTION, 0.0)
	var tail_pos: Vector2 = to_local(_start_position.lerp(_target_last_known, tail_t))
	_line.points = _tail_points(tail_pos, Vector2.ZERO)


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
	var tail_pos: Vector2 = to_local(_start_position.lerp(_target_last_known, tail_t) + perp * tail_bulge)
	_line.points = _tail_points(tail_pos, Vector2.ZERO)


# ---------------------------------------------------------------------------
# Epic 15 Story 006 (ADR-0037): 3D visual-companion subtree.
# Purely additive -- everything above this point (this file's existing 2D
# Line2D/CPUParticles2D flight-path presentation) is unchanged, per
# ADR-0037's core constraint of zero simulation-code changes.
#
# IMPORTANT DEVIATION FROM THE STORY'S OWN PREMISE, CALLED OUT EXPLICITLY
# (per this session's user-confirmed decision, logged here and in this
# story's own evidence doc):
#
# Story 006 and ADR-0019 ("Projectile Pooling Strategy," Accepted) describe a
# 192-slot POOLED `Projectile`/`ProjectileManager` system -- reused node
# instances toggled visible/process_mode on release/reuse, synced from one
# centralized ProjectileManager._physics_process() pass. That system was
# NEVER IMPLEMENTED in this codebase. ADR-0019 itself says under its own
# Migration Plan: "Greenfield -- no existing Projectile/ProjectileManager
# code to migrate" -- and, verified during this story's implementation
# (2026-08-20), that is STILL true: no ProjectileManager class, no pooled
# Projectile class, and no test file for either exists anywhere in src/ or
# tests/. TowerSystem._try_attack() (src/core/tower/tower_system.gd) still
# emits tower_attacked immediately and unconditionally for every weapon
# type -- there is no flight-time delay, no pool, no branching on
# projectile_type. TR-tower-007 (the requirement ADR-0019 exists to close)
# remains open.
#
# The ONLY real projectile-related code in this project is THIS file --
# ProjectileVisual, a purely cosmetic Node2D, freshly instantiate()'d per
# shot by mission_scene.gd's _on_tower_attacked() handler and queue_free()'d
# once its flight completes (see _process()'s own arrival check, below the
# sync call this story adds). That is a create-per-shot/destroy-per-shot
# lifecycle -- the opposite of a reused pool.
#
# Building ADR-0019's real pooling system first was explicitly considered
# and REJECTED for this story's scope: it would be a substantive gameplay
# TIMING change (introducing a real flight delay before damage lands, where
# today damage is instant) -- not a visual-presentation change, and directly
# against this epic's own non-negotiable "zero changes to gameplay
# simulation logic" boundary (ADR-0037's Constraints, upheld by every prior
# story in this epic). That decision is out of this story's authority and is
# logged as a separate, still-open item outside this epic's scope (see the
# evidence doc).
#
# Consequence for this story's scope: the companion below is built ONCE per
# ProjectileVisual instance (in configure(), mirroring TowerInstance's/
# grid_visual.gd's "build once from configure(), since the underlying
# position is fixed for this instance's lifetime after that call" precedent
# -- NOT MonsterManager's per-frame-centralized-pass precedent, which exists
# specifically to handle a many-instance REUSED pool this codebase does not
# have for projectiles), synced every frame from ProjectileVisual's own
# EXISTING _process() (pre-existing before this story, not a new callback),
# and freed automatically when ProjectileVisual itself is queue_free()'d at
# end of flight -- the same "lifecycle is free" consequence ADR-0037's
# Decision documents for every other entity type in this epic. There is no
# release/reuse toggle here because there is no reuse: every ProjectileVisual
# instance lives exactly one shot's flight, same as its companion.
# ---------------------------------------------------------------------------

## Builds this instance's Node3D visual-companion subtree holding a
## MeshInstance3D-bearing mesh instance, resolved via
## GGameDataRegistry.get_visual_mesh_mapping() (data-driven per ADR-0037's
## Constraints -- never a hardcoded scene reference). Seeds the companion's
## initial position from _start_position (this instance's fire-time origin)
## so a projectile fired this frame has a correctly-placed companion on its
## very first visible frame, with no one-frame lag before _process()'s first
## sync call.
##
## A missing/invalid mapping fails loudly (push_error) rather than silently
## rendering no visual, per ADR-0037's Risks section policy -- same policy
## TowerInstance/MonsterInstance/Hero/GridVisual already established.
##
## Called once from configure() (see that method, above). Every
## ProjectileVisual instance in this codebase's real per-shot
## create/destroy lifecycle (see this file's class-level Story 006 doc
## comment, above) is configure()'d exactly once, so "once" is correct here
## -- unlike the rebuild-guarded precedent Monster/Tower/Hero establish for
## their own potentially-re-configured instances, this method still includes
## the identical defensive remove_child()-before-queue_free() guard so a
## hypothetical future re-configure() call (not this project's current call
## sites) cannot leak or duplicate mesh instances.
func _build_visual_companion() -> void:
	# Synchronous remove_child() BEFORE queue_free(), not queue_free() alone
	# -- same gotcha TowerInstance's/MonsterInstance's/Hero's/GridVisual's
	# _build_visual_companion() already fixed (docs/registry/architecture.yaml's
	# mission_hud_planning_cluster_lifecycle entry): queue_free() defers
	# removal to end-of-frame, so an immediately-following add_child() of a
	# new node with the SAME name ("VisualCompanion3D") while the old one is
	# still technically in the tree causes Godot to auto-uniquify the new
	# node's name -- after the deferred free runs, zero nodes are left with
	# the expected name.
	if _visual_companion != null and is_instance_valid(_visual_companion):
		remove_child(_visual_companion)
		_visual_companion.queue_free()
	_visual_companion = Node3D.new()
	_visual_companion.name = "VisualCompanion3D"
	add_child(_visual_companion)

	var mapping: VisualMeshMappingResource = GGameDataRegistry.get_visual_mesh_mapping(PROJECTILE_MESH_ENTITY_ID)
	if mapping == null or mapping.mesh_scene == null:
		push_error("[ProjectileVisual] No valid VisualMeshMappingResource for '%s' -- projectile will have no 3D visual companion." % PROJECTILE_MESH_ENTITY_ID)
		return

	var mesh_node: Node = mapping.mesh_scene.instantiate()
	if not (mesh_node is Node3D):
		push_error("[ProjectileVisual] mesh_scene for '%s' did not instantiate as a Node3D -- no 3D visual companion." % PROJECTILE_MESH_ENTITY_ID)
		mesh_node.free()
		return
	_visual_companion.add_child(mesh_node)
	# ABSOLUTE assignment only, never additive/relative to this Node2D's own
	# transform -- a Node3D child of a Node2D parent does not inherit the
	# parent's 2D transform (ADR-0037's "Important engine clarification").
	(mesh_node as Node3D).position = VisualMath.map_to_3d(_start_position, PROJECTILE_LAYER_HEIGHT)


## Per-frame sync entry point -- called from _process() (above), which
## already existed before this story; this is the one added line, not a new
## callback (see this file's class-level Story 006 doc comment for the "no
## new callback" constraint's exact wording, since _process() is pre-existing
## and out of this story's control to remove). Computes world_position fresh
## from this instance's own global_position every call -- each
## _update_beam()/_update_ballistic()/_update_homing() branch has already
## finalized global_position for this frame by the time _process() reaches
## the call site, so no lag/desync between the 2D flight path and the 3D
## companion is possible.
##
## ABSOLUTE position assignment -- never offset against this Node2D's own
## transform (ADR-0037's "Important engine clarification"). No-op if this
## instance has no companion mesh (e.g. the mapping was missing/invalid at
## build time -- see _build_visual_companion()'s own doc comment).
func _sync_visual_companion_position() -> void:
	if _visual_companion == null or not is_instance_valid(_visual_companion):
		return
	if _visual_companion.get_child_count() == 0:
		return
	(_visual_companion.get_child(0) as Node3D).position = VisualMath.map_to_3d(global_position, PROJECTILE_LAYER_HEIGHT)
