class_name Picking3D
extends RefCounted

## Raycast-based 3D picking utility for ADR-0039 (3D Interaction and Picking
## Layer, Epic 15 Phase 2). Stateless static utility — same convention as
## VisualMath (src/core/visual_presentation/visual_math.gd): RefCounted, no
## instance state.
##
## DORMANT BY CONSTRUCTION: nothing in this file is called by any live game
## code path as of this commit. Every call site is gated behind
## `ENABLE_3D_PRESENTATION_MODE` (defined per-scene in mission_scene.gd /
## the_gap.gd, default false, ADR-0040 — supersedes ADR-0039's original
## standalone `ENABLE_3D_PICKING`) — see ADR-0039's Decision section,
## "Dormancy" subsection, for why: this was built during a work session under
## an explicit "no live testing" constraint, so the currently-shipping 2D
## input pipeline (Grid.world_to_cell() via Camera2D) must remain the only
## reachable path until a future session live-verifies this mechanism.
##
## Collision layer table (3D-only namespace — see ADR-0039 Constraints for
## why this does NOT share numbering semantics with ADR-0015's 2D table):
const PICKING_LAYER_GROUND: int = 1
const PICKING_LAYER_TOWER: int = 2
const PICKING_LAYER_HERO: int = 4  ## reserved, unoccupied — see ADR-0039


## Casts a ray from the camera through a screen-space mouse position and
## returns Godot's own raw PhysicsDirectSpaceState3D.intersect_ray() result
## (a Dictionary shaped `{position, normal, collider, ...}`, or `{}` on a
## miss). No new dictionary shape invented — callers already know how to
## read Godot's native ray-hit result.
##
## `mask` restricts the raycast to a specific picking layer (see the
## PICKING_LAYER_* constants above) — always pass a single layer, never the
## default all-layers mask, so a ground-plane pick can never accidentally
## resolve to a tower and vice versa.
static func pick_ray(camera: Camera3D, mouse_pos: Vector2, space_state: PhysicsDirectSpaceState3D, mask: int) -> Dictionary:
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_target: Vector3 = ray_origin + camera.project_ray_normal(mouse_pos) * camera.far
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_target, mask)
	return space_state.intersect_ray(query)


## Raycasts against PICKING_LAYER_GROUND only and converts a hit's world
## position back to a grid cell via VisualMath.map_to_2d() + Grid's own
## world_to_cell(). Returns Vector2i(-1, -1) on a miss — matches Grid's own
## established "invalid cell" sentinel (see mission_scene.gd's
## tower_placement_preview_updated usage) rather than inventing a new one.
static func pick_ground_cell(camera: Camera3D, mouse_pos: Vector2, space_state: PhysicsDirectSpaceState3D) -> Vector2i:
	var hit: Dictionary = pick_ray(camera, mouse_pos, space_state, PICKING_LAYER_GROUND)
	if hit.is_empty():
		return Vector2i(-1, -1)
	return GGrid.world_to_cell(VisualMath.map_to_2d(hit["position"]))


## Raycasts against PICKING_LAYER_TOWER only and returns the hit Area3D's
## owning TowerInstance (read from its "owner_tower" metadata, set when the
## Area3D is constructed — see TowerInstance._build_visual_companion()).
## Returns null on a miss or if the hit collider carries no such metadata.
##
## Returns the TowerInstance node itself, not an int id — TowerInstance
## (src/core/tower/tower_instance.gd) was verified to carry no tower_id field
## at all as of this ADR (it is presentation-only, "no link yet to
## TowerSystem/TowerMissionState" per its own header comment). See ADR-0039's
## Decision section for the full rationale.
static func pick_tower(camera: Camera3D, mouse_pos: Vector2, space_state: PhysicsDirectSpaceState3D) -> Node2D:
	var hit: Dictionary = pick_ray(camera, mouse_pos, space_state, PICKING_LAYER_TOWER)
	if hit.is_empty():
		return null
	var collider: Object = hit.get("collider")
	if collider == null or not (collider is Node):
		return null
	var owner_tower: Variant = (collider as Node).get_meta("owner_tower", null)
	return owner_tower as Node2D
