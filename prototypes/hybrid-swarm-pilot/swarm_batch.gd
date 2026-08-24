extends RefCounted
class_name PilotSwarmBatch

## Dense-handle register/update/remove lifecycle pilot (ADR-0038 Story 2 /
## Blueprint "Dense batch algorithm"). Prototype-quality: hardcoded, no DI,
## no production integration -- exercises the ALGORITHM against 2 real
## MultiMesh batches (body+shadow), not a bare in-memory simulation, so a
## visual/data desync would actually be observable if the bookkeeping were
## wrong.
##
## **Design decision, not fully unambiguous in ADR-0038/the blueprint --
## documented here for Codex/whoever finalizes Story 7 to confirm or
## correct**: the blueprint's PresentationHandle carries entity_id,
## batch_id, slot_index, and generation, and says "every mutating API
## validates all four" -- read literally, a caller-cached slot_index could
## go stale the instant an unrelated removal elsewhere in the batch
## triggers a swap-move of the entity the caller is NOT trying to touch
## (any live entity that happens to occupy the current `last` slot gets
## relocated by any other entity's removal). The blueprint also says
## "update the moved entity's reverse handle to the new slot" -- this pilot
## reads "reverse handle" as the BATCH's own internal entity_id -> slot_index
## map, and resolves slot_index fresh from entity_id on every mutating call
## rather than trusting a caller-held slot_index directly. This is strictly
## more robust regardless of which reading Codex intended (it is correct
## either way a caller could hold a handle), at the cost of one extra
## dictionary lookup per call -- negligible next to a MultiMesh write.
## Generation is tracked per-entity (not per-slot): it changes only when
## that specific entity_id is removed, so a handle a caller holds for a
## still-live entity never spuriously goes stale from unrelated churn.

const INVALID_SLOT: int = -1

var capacity: int = 0
var live_count: int = 0

var _body_multimesh: MultiMesh
var _shadow_multimesh: MultiMesh

var _slot_entity_id: Array[int] = []          # size=capacity; slot -> entity_id (only [0, live_count) meaningful)
var _entity_to_slot: Dictionary = {}          # entity_id(int) -> slot_index(int), live entities only
var _entity_to_generation: Dictionary = {}    # entity_id(int) -> generation(int), live entities only


func _init(p_capacity: int, body_mm: MultiMesh, shadow_mm: MultiMesh) -> void:
	capacity = p_capacity
	_body_multimesh = body_mm
	_shadow_multimesh = shadow_mm
	_slot_entity_id.resize(capacity)
	_slot_entity_id.fill(-1)


## Register a new live entity. Returns a PresentationHandle Dictionary
## {entity_id, generation} on success, or null on failure (duplicate
## entity_id already live, or capacity exhausted -- never resizes, per
## ADR-0038's "no runtime instance_count resizing" rule).
func register(entity_id: int, body_xform: Transform3D, body_custom: Color, shadow_xform: Transform3D) -> Variant:
	if _entity_to_slot.has(entity_id):
		push_warning("PilotSwarmBatch.register: entity_id %d already live -- duplicate rejected" % entity_id)
		return null
	if live_count >= capacity:
		push_warning("PilotSwarmBatch.register: capacity %d exhausted -- registration dropped, not resized" % capacity)
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

	return {"entity_id": entity_id, "generation": generation}


## Update a live entity's transform/custom data. Returns false (no mutation
## performed) if the handle is stale -- entity_id no longer live, or the
## generation doesn't match the entity's current one (e.g. it was removed
## and never re-registered, or removed and re-registered as a NEW logical
## entity_id reuse with a bumped generation).
func update(handle: Dictionary, body_xform: Transform3D, body_custom: Color, shadow_xform: Transform3D) -> bool:
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
func remove(handle: Dictionary) -> bool:
	var slot: int = _resolve_valid_slot(handle)
	if slot == INVALID_SLOT:
		return false

	var entity_id: int = handle["entity_id"]
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


func _resolve_valid_slot(handle: Dictionary) -> int:
	if not handle.has("entity_id") or not handle.has("generation"):
		return INVALID_SLOT
	var entity_id: int = handle["entity_id"]
	var generation: int = handle["generation"]
	if not _entity_to_slot.has(entity_id):
		return INVALID_SLOT  # not live (never registered, or already removed)
	if (_entity_to_generation.get(entity_id, -1) as int) != generation:
		return INVALID_SLOT  # stale -- caller's handle predates a remove+re-register cycle
	return _entity_to_slot[entity_id]


func _sync_visible_count() -> void:
	_body_multimesh.visible_instance_count = live_count
	_shadow_multimesh.visible_instance_count = live_count
