class_name MonsterSwarmRenderer3D
extends Node3D

## Scene-owned façade (ADR-0038 §"Rendering ownership"; blueprint
## "monster_swarm_renderer_3d.gd") for standard-creature swarm rendering.
## Resolves CreatureAtlasMappingResource lookups, lazily creates/owns one
## MonsterSwarmBatch per BatchKey, and exposes the register/update/
## unregister API + diagnostics that MonsterManager's post-Pass-3
## presentation-sync step will call starting in Story 7.
##
## This story (6) only wires the renderer itself into the scene tree and
## proves it against direct register/update/unregister calls (empty-renderer
## smoke tests) — no MonsterManager/MonsterInstance code calls this yet.
## Exactly one renderer instance is scene-owned per mission, never an
## autoload (ADR-0038: "It is scene-owned, never an autoload").
##
## Exceptional creatures (presentation_class == PRESENTATION_CLASS_EXCEPTIONAL,
## e.g. bosses) are explicitly rejected by register_creature() here — they
## get a capped individual BossCreaturePresenter3D instead (ADR-0038
## §"Bosses, elites, and Menagerie"), which is Story 9's scope, not this
## renderer's batch lifecycle.

@onready var _standard_body_batches: Node3D = $StandardBodyBatches
@onready var _contact_shadow_batches: Node3D = $ContactShadowBatches

const BODY_SHADER: Shader = preload("res://src/shaders/creature_swarm_body.gdshader")
const SHADOW_SHADER: Shader = preload("res://src/shaders/creature_contact_shadow.gdshader")

## BatchKey (String) -> MonsterSwarmBatch. Lazily populated the first time a
## creature of that BatchKey is registered.
var _batches: Dictionary = {}


## Builds the String form of ADR-0038's BatchKey tuple
## (creature_family_atlas_id, mesh_layout_id, material_shader_variant_id,
## render_mode_id) from a mapping. A plain joined String (not a custom
## RefCounted class) so it works directly as a Dictionary key with value
## equality — GDScript Dictionary keys compare custom RefCounted instances
## by reference, which a tuple-equality BatchKey must not do.
static func make_batch_key(mapping: CreatureAtlasMappingResource) -> String:
	return "%s|%s|%s|%s" % [mapping.family_atlas_id, mapping.mesh_layout_id, mapping.shader_variant_id, mapping.render_mode_id]


## Registers entity_id as a new live standard creature. Returns null (and
## push_error()s) if creature_id is unknown, is exceptional-class, or the
## resolved batch is at capacity (never resized at runtime, per ADR-0038).
func register_creature(snapshot: MonsterPresentationSnapshot) -> MonsterPresentationHandle:
	var mapping: CreatureAtlasMappingResource = GGameDataRegistry.get_creature_atlas_mapping(snapshot.creature_id)
	if mapping == null:
		push_error("[MonsterSwarmRenderer3D] register_creature: unknown creature_id '%s'" % snapshot.creature_id)
		return null
	if mapping.presentation_class != CreatureAtlasMappingResource.PRESENTATION_CLASS_STANDARD:
		push_error("[MonsterSwarmRenderer3D] register_creature: creature_id '%s' is exceptional-class -- use the boss/elite presenter path instead (ADR-0038 Bosses/elites/Menagerie), not the standard swarm batch." % snapshot.creature_id)
		return null

	var batch: MonsterSwarmBatch = _get_or_create_batch(mapping)
	var body_xform: Transform3D = snapshot.world_transform
	var body_custom := Color(snapshot.atlas_frame, snapshot.hit_flash, snapshot.status_mask, snapshot.facing_variant)
	var shadow_xform: Transform3D = _make_shadow_transform(snapshot.world_transform)

	return batch.register(snapshot.entity_id, body_xform, body_custom, shadow_xform)


## Updates a live creature's transform/custom state. Returns false if the
## handle is stale or belongs to an unknown batch — never mutates whatever
## entity currently occupies that slot (ADR-0038's named failure mode for a
## stale handle).
func update_creature(handle: MonsterPresentationHandle, snapshot: MonsterPresentationSnapshot) -> bool:
	if handle == null or not _batches.has(handle.batch_key):
		return false
	var batch: MonsterSwarmBatch = _batches[handle.batch_key]
	var body_xform: Transform3D = snapshot.world_transform
	var body_custom := Color(snapshot.atlas_frame, snapshot.hit_flash, snapshot.status_mask, snapshot.facing_variant)
	var shadow_xform: Transform3D = _make_shadow_transform(snapshot.world_transform)
	return batch.update(handle, body_xform, body_custom, shadow_xform)


## Unregisters a live creature via its owning batch's swap-remove. Returns
## false if the handle is stale or belongs to an unknown batch.
func unregister_creature(handle: MonsterPresentationHandle) -> bool:
	if handle == null or not _batches.has(handle.batch_key):
		return false
	var batch: MonsterSwarmBatch = _batches[handle.batch_key]
	return batch.remove(handle)


# ---------------------------------------------------------------------------
# Diagnostics
# ---------------------------------------------------------------------------

## Number of distinct BatchKeys currently allocated.
func get_batch_count() -> int:
	return _batches.size()


## All currently-allocated BatchKey strings.
func get_batch_keys() -> Array[String]:
	var keys: Array[String] = []
	for key: String in _batches:
		keys.append(key)
	return keys


## Live creature count for one BatchKey, or -1 if that batch does not exist
## (distinct from 0, which means the batch exists but is currently empty).
func get_live_count_for_batch(batch_key: String) -> int:
	if not _batches.has(batch_key):
		return -1
	var batch: MonsterSwarmBatch = _batches[batch_key]
	return batch.live_count


## Sum of live_count across every allocated batch — the renderer-wide
## "how many standard creatures are currently presented" figure.
func get_total_live_count() -> int:
	var total: int = 0
	for key: String in _batches:
		var batch: MonsterSwarmBatch = _batches[key]
		total += batch.live_count
	return total


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _get_or_create_batch(mapping: CreatureAtlasMappingResource) -> MonsterSwarmBatch:
	var key: String = make_batch_key(mapping)
	if _batches.has(key):
		return _batches[key]

	var body_quad := QuadMesh.new()
	body_quad.size = Vector2(mapping.world_width, mapping.world_height)

	var body_material := ShaderMaterial.new()
	body_material.shader = BODY_SHADER
	body_material.set_shader_parameter(&"atlas_tex", mapping.atlas_texture)
	body_material.set_shader_parameter(&"atlas_cols", mapping.atlas_columns)
	body_material.set_shader_parameter(&"atlas_rows", mapping.atlas_rows)
	body_quad.material = body_material

	var body_mm := MultiMesh.new()
	body_mm.transform_format = MultiMesh.TRANSFORM_3D
	body_mm.use_custom_data = true
	body_mm.mesh = body_quad
	body_mm.instance_count = mapping.batch_capacity_requirement

	var body_mmi := MultiMeshInstance3D.new()
	body_mmi.name = "Batch_%s" % key
	body_mmi.multimesh = body_mm
	_standard_body_batches.add_child(body_mmi)

	var shadow_quad := QuadMesh.new()
	shadow_quad.size = Vector2(mapping.world_width, mapping.world_width)

	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = SHADOW_SHADER
	shadow_quad.material = shadow_material

	var shadow_mm := MultiMesh.new()
	shadow_mm.transform_format = MultiMesh.TRANSFORM_3D
	shadow_mm.mesh = shadow_quad
	shadow_mm.instance_count = mapping.batch_capacity_requirement

	var shadow_mmi := MultiMeshInstance3D.new()
	shadow_mmi.name = "Batch_%s" % key
	shadow_mmi.multimesh = shadow_mm
	_contact_shadow_batches.add_child(shadow_mmi)

	var batch := MonsterSwarmBatch.new(key, mapping.batch_capacity_requirement, body_mm, shadow_mm)
	_batches[key] = batch
	return batch


## Lays the shadow flat on the ground beneath the body's world position —
## world-grounded, not billboarded (ADR-0038 §"Shadow stream": body and
## shadow transforms may differ in orientation). Matches
## prototypes/hybrid-swarm-pilot/pilot.gd's live-verified rotation.
func _make_shadow_transform(body_xform: Transform3D) -> Transform3D:
	var basis := Basis(Vector3(1.0, 0.0, 0.0), -PI / 2.0)
	var origin := body_xform.origin
	return Transform3D(basis, Vector3(origin.x, 0.01, origin.z))
