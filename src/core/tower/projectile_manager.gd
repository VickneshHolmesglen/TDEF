class_name ProjectileManager
extends Node

## ADR-0019: Projectile Pooling Strategy. Scene-instanced child of
## TowerSystem's own node tree -- NOT an Autoload, NOT a scene-tree peer
## system. Only TowerSystem ever calls fire()/reacquire helpers; no other
## system references this node. This is an intra-system relationship (same
## domain as TowerSystem._monster_cache), not a cross-system reference, so
## no new EventBus contract is needed for TowerSystem<->ProjectileManager
## communication itself -- only for the new fire-time/arrival-time visual
## split (see event_bus.gd's tower_projectile_fired doc comment).
##
## Fixed-size pool, pre-instantiated once at _ready(), never grown at
## runtime (ADR-0019 Constraints: zero-allocation hot path). A single
## centralized _physics_process pass drives every active Projectile --
## mirrors MonsterManager's centralized-update pattern (ADR-0006) and
## Projectile itself defines no per-instance _physics_process.

## ceil(max_active_towers_homing(32) x max_attack_speed(4.0) x base_flight_time_sec(0.5) x 3.0)
const POOL_SIZE: int = 192
const MAX_REACQUISITIONS_PER_FRAME: int = 8
const BASE_FLIGHT_TIME_SEC: float = 0.5

var _pool: Array[Projectile] = []
var _free_indices: Array[int] = []
var _reacquisitions_this_frame: int = 0

## Set by TowerSystem immediately after instancing this node (before
## add_child(), so it's valid from this node's own _ready() onward). Not a
## cross-system reference -- ProjectileManager is TowerSystem's own owned
## child, per ADR-0019's Ownership section.
var _tower_system: TowerSystem = null


func _ready() -> void:
	for i: int in POOL_SIZE:
		var p := Projectile.new()
		p.visible = false
		p.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(p)
		_pool.append(p)
		_free_indices.append(i)


## Acquires a free pool slot and arms it for flight. Returns false (shot
## silently dropped, tower's own attack timer still resets per TowerSystem's
## existing _tick_combat contract) if the pool is exhausted -- never grows
## the pool at runtime. push_warning() has no debug/release gating in Godot
## (fires in both build types per ADR-0019's own note) -- acceptable here
## since pool exhaustion is exactly the kind of tuning signal that should
## stay visible rather than being silently swallowed.
func fire(tower_id: int, projectile_type: StringName, origin: Vector2,
		target_entity_id: int, target_position: Vector2, damage_payload: Dictionary) -> bool:
	if _free_indices.is_empty():
		push_warning("ProjectileManager: pool exhausted (%d/%d in flight), shot dropped" % [POOL_SIZE, POOL_SIZE])
		return false
	var idx: int = _free_indices.pop_back()
	var p: Projectile = _pool[idx]
	p.activate(idx, tower_id, projectile_type, origin, target_entity_id, target_position,
			BASE_FLIGHT_TIME_SEC, damage_payload)
	p.visible = true
	p.process_mode = Node.PROCESS_MODE_INHERIT
	return true


func _physics_process(delta: float) -> void:
	_reacquisitions_this_frame = 0
	for p: Projectile in _pool:
		if p.active:
			_update_projectile(p, delta)


## In-flight update per ADR-0019's Decision. HOMING projectiles track their
## live target's world position every frame while it's still cached; on
## death/loss, attempt a throttled re-acquisition bounded to the firing
## tower's own range/cone (via TowerSystem.reacquire_target(), the
## previously-unwired _get_best_target() dispatch surface built for exactly
## this purpose). BALLISTIC never re-targets -- it always continues to its
## fixed target_position captured at fire time.
func _update_projectile(p: Projectile, delta: float) -> void:
	p.elapsed += delta

	if p.projectile_type == &"HOMING":
		var live_position: Variant = _tower_system.get_cached_monster_world_position(p.target_entity_id)
		if live_position != null:
			p.target_position = live_position as Vector2
		else:
			if _reacquisitions_this_frame < MAX_REACQUISITIONS_PER_FRAME:
				_reacquisitions_this_frame += 1
				var new_target: int = _tower_system.reacquire_target(p.tower_id)
				if new_target != -1:
					p.target_entity_id = new_target
					var new_position: Variant = _tower_system.get_cached_monster_world_position(new_target)
					if new_position != null:
						p.target_position = new_position as Vector2
				else:
					_release(p)
					return
			# else: this frame's re-acquisition budget is exhausted -- the
			# projectile continues drifting toward its last tracked position
			# and retries re-acquisition next frame (ADR-0019: "retries...
			# rather than being denied outright").

	var t: float = clampf(p.elapsed / p.flight_time, 0.0, 1.0)
	p.global_position = p.global_position.lerp(p.target_position, t)

	if p.elapsed >= p.flight_time:
		var arrival_cell: Vector2i = _tower_system.world_to_cell(p.global_position)
		_tower_system.on_projectile_arrived(p.tower_id, p.target_entity_id, arrival_cell, p.damage_payload)
		_release(p)


func _release(p: Projectile) -> void:
	p.active = false
	p.visible = false
	p.process_mode = Node.PROCESS_MODE_DISABLED
	_free_indices.push_back(p.pool_index)
