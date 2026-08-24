class_name MonsterPresentationSnapshot
extends RefCounted

## Compact immutable-per-publish presentation input for one standard
## creature (ADR-0038 §"Dense handles and lifecycle"; blueprint Data
## contracts → PresentationSnapshot). Built by the presentation-sync step
## (Story 7's post-Pass-3 MonsterManager hook) and handed to
## MonsterSwarmRenderer3D.register_creature()/update_creature().
##
## Contains no HP, movement velocity, path, target, or mutable gameplay
## object reference — ADR-0038's own constraint ("Presentation never writes
## gameplay state") means this must never become a channel back INTO
## simulation, so it deliberately carries nothing simulation would need to
## read back.

## The monster entity this snapshot presents.
var entity_id: int = -1

## Data-registry key resolving this creature's CreatureAtlasMappingResource
## (atlas, batch-key components, world dimensions, foot anchor).
var creature_id: StringName = &""

## World-space transform, already including VisualMath.map_to_3d() and the
## mapping's foot-anchor offset — the renderer applies this as-is, it does
## not re-derive position from a 2D coordinate.
var world_transform: Transform3D = Transform3D.IDENTITY

## Atlas frame index as exactly representable small integer float
## (INSTANCE_CUSTOM.x contract).
var atlas_frame: float = 0.0

## Hit-flash amount, normalized 0.0..1.0 (INSTANCE_CUSTOM.y contract).
var hit_flash: float = 0.0

## Integer status/variant bit mask encoded as a float
## (INSTANCE_CUSTOM.z contract) — schema versioned by the creature's
## CreatureAtlasMappingResource.status_mask_schema_version.
var status_mask: float = 0.0

## Facing/animation variant index encoded as a float
## (INSTANCE_CUSTOM.w contract).
var facing_variant: float = 0.0


func _init(p_entity_id: int, p_creature_id: StringName, p_world_transform: Transform3D, p_atlas_frame: float, p_hit_flash: float, p_status_mask: float, p_facing_variant: float) -> void:
	entity_id = p_entity_id
	creature_id = p_creature_id
	world_transform = p_world_transform
	atlas_frame = p_atlas_frame
	hit_flash = p_hit_flash
	status_mask = p_status_mask
	facing_variant = p_facing_variant
