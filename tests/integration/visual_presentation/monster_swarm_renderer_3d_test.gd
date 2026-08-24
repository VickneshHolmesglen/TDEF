## Integration tests for MonsterSwarmRenderer3D (ADR-0038, Epic 16 Story 6 —
## "Mission renderer scene integration"). Covers the story's own scope:
## empty-renderer smoke tests, register/update/unregister against the live
## GGameDataRegistry autoload's real creature_atlases fixtures (goblin_runner
## standard, goblin_warlord_boss exceptional — added by Story 5), and both
## real mission scenes (MissionScene.tscn, the_gap.tscn) carrying exactly
## one PresentationRoot3D/MonsterSwarmRenderer3D with Camera3D reparented
## under it.
##
## No MonsterManager/MonsterInstance code is exercised here — this story
## does not touch either file (see EPIC.md's Story Breakdown). These tests
## drive MonsterSwarmRenderer3D directly, matching
## tower_camera_companion_test.gd's own scene-instantiation pattern.
extends GdUnitTestSuite

const MissionScenePath: String = "res://src/scenes/MissionScene.tscn"
const TheGapScenePath: String = "res://src/gameplay/missions/the_gap/the_gap.tscn"
const RendererScenePath: String = "res://src/core/visual_presentation/monster_swarm_renderer_3d.tscn"

var _renderer: MonsterSwarmRenderer3D


func before_test() -> void:
	var packed: PackedScene = load(RendererScenePath)
	_renderer = packed.instantiate() as MonsterSwarmRenderer3D
	add_child(_renderer)


func after_test() -> void:
	if _renderer != null and is_instance_valid(_renderer):
		remove_child(_renderer)
		_renderer.free()
	_renderer = null


func _make_snapshot(entity_id: int, creature_id: StringName, origin: Vector3 = Vector3.ZERO) -> MonsterPresentationSnapshot:
	return MonsterPresentationSnapshot.new(entity_id, creature_id, Transform3D(Basis(), origin), 0.0, 0.0, 0.0, 0.0)


# ---------------------------------------------------------------------------
# Empty-renderer smoke tests
# ---------------------------------------------------------------------------

func test_empty_renderer_has_zero_batches_and_zero_live_count() -> void:
	assert_int(_renderer.get_batch_count()).is_equal(0)
	assert_int(_renderer.get_total_live_count()).is_equal(0)
	assert_array(_renderer.get_batch_keys()).is_empty()


func test_empty_renderer_has_required_child_nodes() -> void:
	assert_object(_renderer.get_node_or_null("StandardBodyBatches")).is_not_null()
	assert_object(_renderer.get_node_or_null("ContactShadowBatches")).is_not_null()
	assert_object(_renderer.get_node_or_null("ExceptionalPresenters")).is_not_null()


# ---------------------------------------------------------------------------
# register_creature() / update_creature() / unregister_creature()
# ---------------------------------------------------------------------------

func test_register_creature_unknown_creature_id_returns_null() -> void:
	var handle: MonsterPresentationHandle = _renderer.register_creature(_make_snapshot(1, &"nonexistent_creature"))
	assert_object(handle).is_null()
	assert_int(_renderer.get_total_live_count()).is_equal(0)


func test_register_creature_exceptional_class_rejected() -> void:
	var handle: MonsterPresentationHandle = _renderer.register_creature(_make_snapshot(1, &"goblin_warlord_boss"))
	assert_object(handle).is_null()
	assert_int(_renderer.get_total_live_count()).is_equal(0)


func test_register_creature_standard_class_creates_batch_and_returns_handle() -> void:
	var handle: MonsterPresentationHandle = _renderer.register_creature(_make_snapshot(1, &"goblin_runner", Vector3(3.0, 0.0, -2.0)))
	assert_object(handle).is_not_null()
	assert_int(handle.entity_id).is_equal(1)
	assert_int(_renderer.get_batch_count()).is_equal(1)
	assert_int(_renderer.get_total_live_count()).is_equal(1)
	assert_int(_renderer.get_live_count_for_batch(handle.batch_key)).is_equal(1)


func test_register_creature_two_entities_same_creature_share_one_batch() -> void:
	var handle_a: MonsterPresentationHandle = _renderer.register_creature(_make_snapshot(1, &"goblin_runner"))
	var handle_b: MonsterPresentationHandle = _renderer.register_creature(_make_snapshot(2, &"goblin_runner"))
	assert_object(handle_a).is_not_null()
	assert_object(handle_b).is_not_null()
	assert_str(handle_a.batch_key).is_equal(handle_b.batch_key)
	assert_int(_renderer.get_batch_count()).is_equal(1)
	assert_int(_renderer.get_total_live_count()).is_equal(2)


func test_update_creature_with_valid_handle_returns_true() -> void:
	var handle: MonsterPresentationHandle = _renderer.register_creature(_make_snapshot(1, &"goblin_runner"))
	var moved: bool = _renderer.update_creature(handle, _make_snapshot(1, &"goblin_runner", Vector3(5.0, 0.0, 5.0)))
	assert_bool(moved).is_true()


func test_update_creature_with_foreign_batch_key_returns_false() -> void:
	var handle: MonsterPresentationHandle = _renderer.register_creature(_make_snapshot(1, &"goblin_runner"))
	var foreign_handle := MonsterPresentationHandle.new(handle.entity_id, "not_a_real_batch_key", handle.slot_index, handle.generation)
	var updated: bool = _renderer.update_creature(foreign_handle, _make_snapshot(1, &"goblin_runner"))
	assert_bool(updated).is_false()


func test_unregister_creature_decrements_live_count() -> void:
	var handle: MonsterPresentationHandle = _renderer.register_creature(_make_snapshot(1, &"goblin_runner"))
	var removed: bool = _renderer.unregister_creature(handle)
	assert_bool(removed).is_true()
	assert_int(_renderer.get_total_live_count()).is_equal(0)


func test_unregister_creature_stale_handle_returns_false_and_does_not_corrupt_survivor() -> void:
	var handle_a: MonsterPresentationHandle = _renderer.register_creature(_make_snapshot(1, &"goblin_runner"))
	var handle_b: MonsterPresentationHandle = _renderer.register_creature(_make_snapshot(2, &"goblin_runner"))
	_renderer.unregister_creature(handle_a)
	# handle_a is now stale -- removing it again must fail, not touch handle_b's slot.
	var removed_again: bool = _renderer.unregister_creature(handle_a)
	assert_bool(removed_again).is_false()
	assert_int(_renderer.get_total_live_count()).is_equal(1)
	assert_int(_renderer.get_live_count_for_batch(handle_b.batch_key)).is_equal(1)


# ---------------------------------------------------------------------------
# Real mission scenes carry exactly one PresentationRoot3D/MonsterSwarmRenderer3D
# ---------------------------------------------------------------------------

func test_the_gap_scene_has_presentation_root_with_renderer_and_reparented_camera() -> void:
	var packed: PackedScene = load(TheGapScenePath)
	var scene: Node2D = packed.instantiate() as Node2D
	add_child(scene)

	var presentation_root: Node3D = scene.get_node(NodePath("PresentationRoot3D")) as Node3D
	assert_object(presentation_root).is_not_null()
	assert_object(presentation_root.get_node_or_null("Camera3D")).is_not_null()
	assert_object(presentation_root.get_node_or_null("MonsterSwarmRenderer3D")).is_not_null()

	remove_child(scene)
	scene.free()
	GGrid.initialize(GridConfig.new())


func test_mission_scene_has_presentation_root_with_renderer_and_reparented_camera() -> void:
	GMissionSelect.reset_to_defaults()
	GMissionSelect._restore_completed = true
	var runner: GdUnitSceneRunner = scene_runner(MissionScenePath)
	@warning_ignore("unsafe_cast")
	var scene: Node2D = runner.scene() as Node2D

	var presentation_root: Node3D = scene.get_node(NodePath("PresentationRoot3D")) as Node3D
	assert_object(presentation_root).is_not_null()
	assert_object(presentation_root.get_node_or_null("Camera3D")).is_not_null()
	assert_object(presentation_root.get_node_or_null("MonsterSwarmRenderer3D")).is_not_null()
