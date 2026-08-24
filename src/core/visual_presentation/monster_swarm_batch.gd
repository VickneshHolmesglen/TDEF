class_name MonsterSwarmBatch
extends RefCounted

## Owns one dense body MultiMesh, one dense shadow MultiMesh, and the
## register/update/remove-via-swap dense-handle lifecycle for a single
## BatchKey (ADR-0038 §"Dense handles and lifecycle"; blueprint "Dense
## batch algorithm"). No gameplay queries — this class only knows about
## slots, transforms, and custom data; it never reads MonsterEntity/
## MonsterManager state directly.
##
## Live-verified algorithm: this is a direct production port of
## prototypes/hybrid-swarm-pilot/swarm_batch.gd's PilotSwarmBatch, whose 8
## test cases (register-to-capacity, overflow/duplicate rejection,
## swap-remove correctness, stale-handle rejection, repeated swap-remove,
## wave-clear, entity-ID reuse with fresh generation) all passed against
## real MultiMesh batches, not a simulation. The only change here is
## returning a MonsterPresentationHandle object (carrying batch_key, for a
## renderer that owns multiple batches) instead of the pilot's simplified
## {entity_id, generation} Dictionary (which only ever had one batch).
##
## **Design decision, not fully unambiguous in ADR-0038/the blueprint —
## carried forward from the pilot unchanged, flagged there for Codex/Story 7
## to confirm or correct**: MonsterPresentationHandle.slot_index is
## documented as a hint only. Every mutating API here resolves the real
## slot fresh from entity_id via _entity_to_slot on every call, rather than
## trusting a caller-held slot_index directly — strictly more robust
## regardless of which reading of the blueprint's "update the moved
## entity's reverse handle" language was intended, at the cost of one extra
## dictionary lookup per call (negligible next to a MultiMesh write).
## Generation is tracked per-entity (not per-slot): it changes only when
## that specific entity_id is removed, so a handle a caller holds for a
## still-live entity never spuriously goes stale from unrelated churn
## elsewhere in the batch.

const INVALID_SLOT: int = -1

## The BatchKey (as a String — see monster_swarm_renderer_3d.gd's
## make_batch_key()) this batch was created for. Every handle this batch
## issues carries this same value; MonsterSwarmRenderer3D uses it to route
## a caller's handle back to the correct MonsterSwarmBatch instance.
var batch_key: String = ""

var capacity: int = 0
var live_count: int = 0

var _body_multimesh: MultiMesh
var _shadow_multimesh: MultiMesh

var _slot_entity_id: Array[int] = []          # size=capacity; slot -> entity_id (only [0, live_count) meaningful)
var _entity_to_slot: Dictionary = {}          # entity_id(int) -> slot_index(int), live entities only
var _entity_to_generation: Dictionary = {}    # entity_id(int) -> generation(int), live entities only


func _init(p_batch_key: String, p_capacity: int, body_mm: MultiMesh, shadow_mm: MultiMesh) -> void:
	batch_key = p_batch_key
	capacity = p_capacity
	_body_multimesh = body_mm
	_shadow_multimesh = shadow_mm
	_slot_entity_id.resize(capacity)
	_slot_entity_id.fill(-1)


## Register a new live entity. Returns a MonsterPresentationHandle on
## success, or null on failure (duplicate entity_id already live, or
## capacity exhausted -- never resizes, per ADR-0038's "no runtime
## instance_count resizing" rule; a spawn that can't fit fails loudly to
## the caller instead).
func register(entity_id: int, body_xform: Transform3D, body_custom: Color, shadow_xform: Transform3D) -> MonsterPresentationHandle:
	if _entity_to_slot.has(entity_id):
		push_warning("MonsterSwarmBatch[%s].register: entity_id %d already live -- duplicate rejected" % [batch_key, entity_id])
		return null
	if live_count >= capacity:
		push_warning("MonsterSwarmBatch[%s].register: capacity %d exhausted -- registration dropped, not resized" % [batch_key, capacity])
		return null

	var slot: int = live_count
	var generation: int = (_entity_to_generation.get(entity_id, 0) as int) + 1

	_slot_entity_id[slot] = entity_id
	_entity_to_slot[entity_id] = slot
	_entity_to_generation[entity_id] = generation

	_body_multimesh.set_instance_transform(slot, body_xform)
	_body_multimesh.set_instance_custom_data(slot, body_custom)
	_shadow_multimesh.set_instance_transform(slot, shadow_xform)

	live_count += 1
	_sync_visible_count()

	return MonsterPresentationHandle.new(entity_id, batch_key, slot, generation)


## Update a live entity's transform/custom data. Returns false (no mutation
## performed) if the handle is stale -- entity_id no longer live, or the
## generation doesn't match the entity's current one (e.g. it was removed
## and never re-registered, or removed and re-registered as a NEW logical
## entity_id reuse with a bumped generation).
func update(handle: MonsterPresentationHandle, body_xform: Transform3D, body_custom: Color, shadow_xform: Transform3D) -> bool:
	var slot: int = _resolve_valid_slot(handle)
	if slot == INVALID_SLOT:
		return false
	_body_multimesh.set_instance_transform(slot, body_xform)
	_body_multimesh.set_instance_custom_data(slot, body_custom)
	_shadow_multimesh.set_instance_transform(slot, shadow_xform)
	return true


## Remove a live entity via swap-remove (ADR-0038 "Dense batch algorithm").
## Returns false if the handle is stale (see update()'s own doc comment) --
## a stale handle must never mutate whatever entity now occupies that slot,
## the exact failure mode ADR-0038's own PresentationHandle contract names.
func remove(handle: MonsterPresentationHandle) -> bool:
	var slot: int = _resolve_valid_slot(handle)
	if slot == INVALID_SLOT:
		return false

	var entity_id: int = handle.entity_id
	var last: int = live_count - 1

	if slot != last:
		var moved_entity_id: int = _slot_entity_id[last]
		# Copy the last live slot's data down into the freed slot -- the
		# moved entity's own generation is UNCHANGED (per this file's own
		# top-of-file design note); only its recorded slot_index moves,
		# transparently, via _entity_to_slot. Any handle the moved entity's
		# owner is holding stays valid with zero action required on their
		# part, since update()/remove() always resolve slot fresh.
		_body_multimesh.set_instance_transform(slot, _body_multimesh.get_instance_transform(last))
		_body_multimesh.set_instance_custom_data(slot, _body_multimesh.get_instance_custom_data(last))
		_shadow_multimesh.set_instance_transform(slot, _shadow_multimesh.get_instance_transform(last))
		_slot_entity_id[slot] = moved_entity_id
		_entity_to_slot[moved_entity_id] = slot

	# Defensively clear the now-vacated last slot -- ADR-0038 "Clear/hide
	# the old last slot defensively." A cleared slot is fully outside
	# [0, live_count) after this, so it never renders regardless, but a
	# zeroed transform/custom-data avoids leaving stale-but-invisible data
	# sitting in the MultiMesh buffer for a future debug/profiling pass.
	_slot_entity_id[last] = -1
	_body_multimesh.set_instance_transform(last, Transform3D())
	_body_multimesh.set_instance_custom_data(last, Color(0, 0, 0, 0))
	_shadow_multimesh.set_instance_transform(last, Transform3D())

	_entity_to_slot.erase(entity_id)
	# Generation is NOT deleted -- kept so a future register() of the same
	# entity_id correctly bumps to a new generation rather than colliding
	# with a stale handle's old one. (entity_id reuse across a mission's
	# monster-pool lifetime is exactly the case this guards.)
	live_count -= 1
	_sync_visible_count()
	return true


## Debug/test-only integrity check (ADR-0038 Validation Criteria: "Assert
## body/shadow counts, dense IDs, and reverse handles agree in debug/test
## builds"). Returns [] when consistent, else one string per violation.
func assert_dense_integrity() -> Array[String]:
	var errors: Array[String] = []
	if _entity_to_slot.size() != live_count:
		errors.append("entity_to_slot has %d entries, expected live_count=%d" % [_entity_to_slot.size(), live_count])
	if _body_multimesh.visible_instance_count != live_count:
		errors.append("body visible_instance_count=%d != live_count=%d" % [_body_multimesh.visible_instance_count, live_count])
	if _shadow_multimesh.visible_instance_count != live_count:
		errors.append("shadow visible_instance_count=%d != live_count=%d" % [_shadow_multimesh.visible_instance_count, live_count])
	for entity_id: Variant in _entity_to_slot:
		var slot: int = _entity_to_slot[entity_id]
		if slot < 0 or slot >= live_count:
			errors.append("entity %s maps to out-of-dense-range slot %d (live_count=%d)" % [entity_id, slot, live_count])
			continue
		if _slot_entity_id[slot] != entity_id:
			errors.append("entity %s's recorded slot %d actually holds entity_id %d" % [entity_id, slot, _slot_entity_id[slot]])
	for slot: int in range(live_count):
		var entity_id: Variant = _slot_entity_id[slot]
		if entity_id == -1:
			errors.append("dense slot %d (< live_count=%d) is unexpectedly empty" % [slot, live_count])
	return errors


func _resolve_valid_slot(handle: MonsterPresentationHandle) -> int:
	if handle == null or handle.batch_key != batch_key:
		return INVALID_SLOT
	if not _entity_to_slot.has(handle.entity_id):
		return INVALID_SLOT  # not live (never registered, or already removed)
	if (_entity_to_generation.get(handle.entity_id, -1) as int) != handle.generation:
		return INVALID_SLOT  # stale -- caller's handle predates a remove+re-register cycle
	return _entity_to_slot[handle.entity_id]


func _sync_visible_count() -> void:
	_body_multimesh.visible_instance_count = live_count
	_shadow_multimesh.visible_instance_count = live_count
