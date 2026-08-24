class_name Projectile
extends Node2D

## Pooled logical projectile — ADR-0019 (Projectile Pooling Strategy).
##
## Plain Node2D, no collision node and no visual child: arrival and
## re-acquisition are cache/ID-driven (TowerSystem._monster_cache), never
## spatial-overlap-driven, so an Area2D would add Physics-server overhead
## for zero benefit (ADR-0019 Alternative 3). The COSMETIC flight sprite
## (ProjectileVisual, already-built, already has a 3D visual companion per
## Epic 15) is a separate, still per-shot-instantiated, non-pooled node
## spawned by mission_scene.gd off the new tower_projectile_fired signal --
## deliberately NOT rebuilt from scratch as a pooled child sprite the way
## ADR-0019's original code sample sketched, since that would throw away
## already-shipped, already-tested visual work for no correctness gain.
## This class is the LOGICAL half only: it owns position/timing/damage-payload
## state and decides WHEN tower_attacked fires, never how it looks.
##
## Owned exclusively by ProjectileManager (this file's sibling) — no other
## script should reference a Projectile instance directly. All per-instance
## state is reset by activate() on acquire and cleared by
## ProjectileManager._release() on arrival/failure; nothing here defines its
## own _process()/_physics_process() (ADR-0019 Constraints: no per-instance
## physics-process, ADR-0006's per_monster_physics_process forbidden-pattern
## reasoning applied identically to projectiles).

var pool_index: int = -1
var active: bool = false
var projectile_type: StringName = &""   # &"HOMING" or &"BALLISTIC" -- BEAM/AURA never reach the pool
var tower_id: int = -1
var target_entity_id: int = -1          # HOMING only; stays valid for BALLISTIC too (arrival lookup)
var target_position: Vector2 = Vector2.ZERO  # BALLISTIC: fixed aim point. HOMING: last-known tracked position.
var elapsed: float = 0.0
var flight_time: float = 0.5            # tower.md Tuning Knob base_flight_time_sec
var damage_payload: Dictionary = {}     # damage, is_siege, effect_type, effect_value, effect_duration, armor_penetration, is_crit, aoe_radius_cells


## Resets and (re)arms this pooled slot for a new shot. Called by
## ProjectileManager.fire() only. Resets every field explicitly -- a pooled
## slot's previous shot's stale state must never leak into the next.
func activate(idx: int, p_tower_id: int, p_type: StringName, origin: Vector2,
		p_target_entity_id: int, p_target_position: Vector2, p_flight_time: float,
		p_damage_payload: Dictionary) -> void:
	pool_index = idx
	active = true
	projectile_type = p_type
	tower_id = p_tower_id
	target_entity_id = p_target_entity_id
	target_position = p_target_position
	elapsed = 0.0
	flight_time = p_flight_time
	damage_payload = p_damage_payload
	global_position = origin
