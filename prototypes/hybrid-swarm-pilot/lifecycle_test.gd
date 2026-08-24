extends RefCounted

## Dense-handle lifecycle test driver for PilotSwarmBatch (ADR-0038 Story 2
## / Blueprint "Test and evidence matrix — Dense lifecycle" row). Runnable
## directly via Godot MCP `run_script` (matches the required
## "extends RefCounted" + "func execute(scene_tree: SceneTree) -> Variant"
## contract) so this is a real, repeatable artifact, not a one-off ad hoc
## check thrown away after use.
##
## Builds its own isolated capacity-10 body+shadow MultiMesh pair (does not
## touch pilot.tscn's own swarm) so failures here are unambiguously about
## PilotSwarmBatch's own bookkeeping, not interference from the main pilot
## scene's animation/flash loop.

const CAPACITY: int = 10


func execute(scene_tree: SceneTree) -> Variant:
	var results: Dictionary = {}
	var root := scene_tree.root

	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)

	var body_mm := MultiMesh.new()
	body_mm.transform_format = MultiMesh.TRANSFORM_3D
	body_mm.use_custom_data = true
	body_mm.mesh = quad
	body_mm.instance_count = CAPACITY

	var shadow_mm := MultiMesh.new()
	shadow_mm.transform_format = MultiMesh.TRANSFORM_3D
	shadow_mm.mesh = quad
	shadow_mm.instance_count = CAPACITY

	var body_mmi := MultiMeshInstance3D.new()
	body_mmi.multimesh = body_mm
	var shadow_mmi := MultiMeshInstance3D.new()
	shadow_mmi.multimesh = shadow_mm
	root.add_child(body_mmi)
	root.add_child(shadow_mmi)

	var SwarmBatchScript: GDScript = load("res://prototypes/hybrid-swarm-pilot/swarm_batch.gd")
	var batch = SwarmBatchScript.new(CAPACITY, body_mm, shadow_mm)

	var errors: Array[String] = []
	var handles: Dictionary = {}  # entity_id -> handle Dictionary

	# --- Test 1: register to capacity ---
	for i in range(CAPACITY):
		var xform := Transform3D(Basis(), Vector3(float(i), 0.0, 0.0))
		var h = batch.register(i, xform, Color(float(i), 0.0, 0.0, 0.0), xform)
		if h == null:
			errors.append("Test1: register(%d) unexpectedly failed" % i)
		else:
			handles[i] = h
	if batch.live_count != CAPACITY:
		errors.append("Test1: live_count=%d after filling to capacity, expected %d" % [batch.live_count, CAPACITY])
	errors.append_array(_prefixed(batch.assert_dense_integrity(), "Test1"))

	# --- Test 2: overflow rejected, does not resize ---
	var overflow_handle = batch.register(999, Transform3D(), Color(), Transform3D())
	if overflow_handle != null:
		errors.append("Test2: register() at full capacity should return null, got a handle")
	if body_mm.instance_count != CAPACITY:
		errors.append("Test2: instance_count changed from %d to %d -- must never resize at runtime" % [CAPACITY, body_mm.instance_count])

	# --- Test 3: duplicate entity_id rejected ---
	var dup_handle = batch.register(3, Transform3D(), Color(), Transform3D())
	if dup_handle != null:
		errors.append("Test3: register() of an already-live entity_id (3) should return null, got a handle")

	# --- Test 4: remove from the middle, verify swap-remove moved the
	# correct (last) entity into the freed slot, dense integrity holds ---
	var removed_ok: bool = batch.remove(handles[3])
	if not removed_ok:
		errors.append("Test4: remove(handles[3]) unexpectedly failed")
	if batch.live_count != CAPACITY - 1:
		errors.append("Test4: live_count=%d after one removal, expected %d" % [batch.live_count, CAPACITY - 1])
	errors.append_array(_prefixed(batch.assert_dense_integrity(), "Test4"))
	# Entity 9 (the original `last`, slot CAPACITY-1) should now occupy
	# slot 3 (freed by entity 3's removal) -- update it and confirm the
	# write lands where the entity actually is, not the entity's old slot.
	var update_after_move_ok: bool = batch.update(handles[9], Transform3D(Basis(), Vector3(42.0, 0.0, 0.0)), Color(9.0, 0, 0, 0), Transform3D())
	if not update_after_move_ok:
		errors.append("Test4: update(handles[9]) after it was moved by entity 3's removal unexpectedly failed")
	else:
		var moved_slot: int = batch._entity_to_slot[9]
		var written_pos: Vector3 = body_mm.get_instance_transform(moved_slot).origin
		if not written_pos.is_equal_approx(Vector3(42.0, 0.0, 0.0)):
			errors.append("Test4: update() after move wrote to the wrong slot -- expected entity 9's new slot to read back (42,0,0), got %s" % written_pos)

	# --- Test 5: stale handle rejected, never mutates the replacement occupant ---
	var stale_handle = handles[3]  # entity 3 was removed in Test 4 -- this handle is now stale
	var stale_update_ok: bool = batch.update(stale_handle, Transform3D(Basis(), Vector3(-999.0, -999.0, -999.0)), Color(), Transform3D())
	if stale_update_ok:
		errors.append("Test5: update() with a stale handle (removed entity 3) should return false, returned true")
	# Confirm slot 3 (now occupied by entity 9 post-move) was NOT corrupted
	# by the stale update attempt above.
	var slot3_pos: Vector3 = body_mm.get_instance_transform(3).origin
	if slot3_pos.is_equal_approx(Vector3(-999.0, -999.0, -999.0)):
		errors.append("Test5: stale handle mutated the replacement occupant's slot -- this is the exact failure ADR-0038 names as unacceptable")
	var stale_remove_ok: bool = batch.remove(stale_handle)
	if stale_remove_ok:
		errors.append("Test5: remove() with a stale handle should return false, returned true")

	# --- Test 6: repeated swap-remove (first, then whatever is now last, repeatedly) ---
	var repeated_remove_errors: Array[String] = []
	while batch.live_count > 3:
		var any_live_entity_id: int = -1
		for entity_id: Variant in handles.keys():
			if batch._entity_to_slot.has(entity_id):
				any_live_entity_id = entity_id
				break
		if any_live_entity_id == -1:
			break
		if not batch.remove(handles[any_live_entity_id]):
			repeated_remove_errors.append("Test6: remove(handles[%d]) failed mid-loop" % any_live_entity_id)
			break
	errors.append_array(repeated_remove_errors)
	errors.append_array(_prefixed(batch.assert_dense_integrity(), "Test6"))

	# --- Test 7: wave clear -- remove everything remaining ---
	for entity_id: Variant in handles.keys():
		if batch._entity_to_slot.has(entity_id):
			batch.remove(handles[entity_id])
	if batch.live_count != 0:
		errors.append("Test7: live_count=%d after removing everything, expected 0" % batch.live_count)
	if body_mm.visible_instance_count != 0 or shadow_mm.visible_instance_count != 0:
		errors.append("Test7: visible_instance_count not 0 after wave clear (body=%d, shadow=%d)" % [body_mm.visible_instance_count, shadow_mm.visible_instance_count])
	errors.append_array(_prefixed(batch.assert_dense_integrity(), "Test7"))

	# --- Test 8: re-register a previously-removed entity_id, confirm a
	# fresh generation (old stale handles for the same ID must stay stale) ---
	var old_handle_for_0 = handles[0]
	var fresh_handle = batch.register(0, Transform3D(), Color(), Transform3D())
	if fresh_handle == null:
		errors.append("Test8: re-registering entity_id 0 after wave clear unexpectedly failed")
	elif fresh_handle["generation"] == old_handle_for_0["generation"]:
		errors.append("Test8: re-registered entity_id 0 got the same generation as its old, now-removed handle -- the old handle would incorrectly validate")
	if fresh_handle != null and batch.update(old_handle_for_0, Transform3D(Basis(), Vector3(-1, -1, -1)), Color(), Transform3D()):
		errors.append("Test8: the OLD (pre-wave-clear) handle for entity_id 0 incorrectly validated against the newly re-registered entity_id 0")

	body_mmi.queue_free()
	shadow_mmi.queue_free()

	results["pass"] = errors.is_empty()
	results["error_count"] = errors.size()
	results["errors"] = errors
	return results


func _prefixed(errs: Array[String], prefix: String) -> Array[String]:
	var out: Array[String] = []
	for e: String in errs:
		out.append("%s: %s" % [prefix, e])
	return out
