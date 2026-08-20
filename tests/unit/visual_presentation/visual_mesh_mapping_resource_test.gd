## Unit tests for VisualMeshMappingResource, VisualMath.map_to_3d(), and
## GameDataRegistry's boot-time loading/validation of VisualMeshMappingResource
## (Epic 15 Story 001, ADR-0037). Covers the story's QA Test Cases AC-1
## through AC-5.
##
## Registry-boot tests follow tests/unit/game_data_registry/game_data_registry_test.gd's
## direct-injection convention: a fresh GameDataRegistry.new() + _inject() +
## _ready(), fixtures under tests/fixtures/game_data_registry/visual_mesh_mappings_*/.
##
## AC-5 (end-to-end real mapping) deliberately uses the LIVE GGameDataRegistry
## autoload rather than an injected fixture registry — it is the one test in
## this suite proving the actual shipped assets/data/visual_meshes/tower_round.tres
## resolves through the real boot path, matching this project's existing
## "end-to-end via the live autoload" precedent (e.g.
## drop_table_schema_registry_test.gd's ResourceEconomy half reads live
## GGameDataRegistry state directly).
extends GdUnitTestSuite

const VALID_MAPPINGS_DIR: String = "res://tests/fixtures/game_data_registry/visual_mesh_mappings_valid/"
const INVALID_MAPPINGS_DIR: String = "res://tests/fixtures/game_data_registry/visual_mesh_mappings_invalid/"
const MALFORMED_MAPPINGS_DIR: String = "res://tests/fixtures/game_data_registry/visual_mesh_mappings_malformed/"
const DUPLICATE_MAPPINGS_DIR: String = "res://tests/fixtures/game_data_registry/visual_mesh_mappings_duplicate/"
const MISSING_MAPPINGS_DIR: String = "res://tests/fixtures/game_data_registry/visual_mesh_mappings_does_not_exist/"
const DUMMY_MESH_SCENE_PATH: String = "res://tests/fixtures/game_data_registry/visual_mesh_mappings_valid/dummy_mesh.tscn"

# Existing valid fixtures for the other GameDataRegistry loaders — needed
# because _inject() takes positional args for every loader, matching
# game_data_registry_test.gd's/drop_table_schema_registry_test.gd's own
# const-reuse convention.
const VALID_MONSTERS_DIR: String = "res://tests/fixtures/game_data_registry/monsters_valid/"
const VALID_PERK_REGISTRY_PATH: String = "res://tests/fixtures/game_data_registry/towers/perk_registry_valid.tres"
const EMPTY_TOWER_BLUEPRINTS_DIR: String = "res://tests/fixtures/game_data_registry/tower_blueprints_empty/"
const EMPTY_MISSIONS_DIR: String = "res://tests/fixtures/game_data_registry/missions_empty/"
const EMPTY_SKILLS_DIR: String = "res://tests/fixtures/game_data_registry/skills_empty/"
const VALID_COMBO_TABLE_PATH: String = "res://tests/fixtures/game_data_registry/skills_combo/ultimate_combo_table_valid.tres"
const EMPTY_DROP_TABLES_DIR: String = "res://tests/fixtures/game_data_registry/drop_tables_empty/"

var _registry: GameDataRegistry


## Mirrors drop_table_schema_registry_test.gd's _inject_registry() helper
## exactly: specifies fixture dirs only through drop_tables_dir (this suite's
## own const set), then overrides _visual_mesh_mappings_dir directly on the
## instance afterward — the same "test reaches into underscore-prefixed
## state" convention that file's own header comment documents and cites.
## Everything else (tech_nodes_dir onward, per _inject()'s own defaults)
## loads from the REAL project directories; harmless here since
## GameDataRegistry's does-not-abort load policy means unrelated valid
## production data never interferes with this suite's assertions.
func _inject_registry(visual_mesh_mappings_dir: String) -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR, EMPTY_SKILLS_DIR, VALID_COMBO_TABLE_PATH, EMPTY_DROP_TABLES_DIR)
	_registry._visual_mesh_mappings_dir = visual_mesh_mappings_dir


func after_test() -> void:
	if _registry != null and is_instance_valid(_registry):
		if _registry.is_inside_tree():
			_registry.get_parent().remove_child(_registry)
		_registry.free()
	_registry = null


# ---------------------------------------------------------------------------
# AC-1 & AC-2: VisualMeshMappingResource shape + validate()
# ---------------------------------------------------------------------------

func test_validate_fails_when_both_fields_unset() -> void:
	var mapping := VisualMeshMappingResource.new()
	var errors: Array[String] = mapping.validate()
	assert_array(errors).contains(["entity_or_component_id must not be empty", "mesh_scene must be assigned"])


func test_validate_fails_when_id_valid_but_mesh_scene_null() -> void:
	var mapping := VisualMeshMappingResource.new()
	mapping.entity_or_component_id = &"tower_round"
	mapping.mesh_scene = null
	var errors: Array[String] = mapping.validate()
	assert_array(errors).is_equal(["mesh_scene must be assigned"])


func test_validate_fails_when_mesh_scene_valid_but_id_empty() -> void:
	var mapping := VisualMeshMappingResource.new()
	mapping.entity_or_component_id = &""
	mapping.mesh_scene = ResourceLoader.load(DUMMY_MESH_SCENE_PATH) as PackedScene
	var errors: Array[String] = mapping.validate()
	assert_array(errors).is_equal(["entity_or_component_id must not be empty"])


func test_validate_passes_when_both_fields_set() -> void:
	var mapping := VisualMeshMappingResource.new()
	mapping.entity_or_component_id = &"tower_round"
	mapping.mesh_scene = ResourceLoader.load(DUMMY_MESH_SCENE_PATH) as PackedScene
	assert_array(mapping.validate()).is_empty()


# ---------------------------------------------------------------------------
# AC-4: VisualMath.map_to_3d() — pure function
# ---------------------------------------------------------------------------

func test_map_to_3d_returns_exact_mapped_vector() -> void:
	var result: Vector3 = VisualMath.map_to_3d(Vector2(3.5, -2.0), 0.21)
	assert_that(result).is_equal(Vector3(3.5, 0.21, -2.0))


func test_map_to_3d_zero_input_returns_zero_xz_with_layer_height_y() -> void:
	var result: Vector3 = VisualMath.map_to_3d(Vector2.ZERO, 1.5)
	assert_that(result).is_equal(Vector3(0.0, 1.5, 0.0))


func test_map_to_3d_negative_layer_height_is_passed_through_unchanged() -> void:
	var result: Vector3 = VisualMath.map_to_3d(Vector2(1.0, 2.0), -0.5)
	assert_that(result).is_equal(Vector3(1.0, -0.5, 2.0))


func test_map_to_3d_repeated_calls_produce_identical_output() -> void:
	var first: Vector3 = VisualMath.map_to_3d(Vector2(10.0, 20.0), 0.0)
	var second: Vector3 = VisualMath.map_to_3d(Vector2(10.0, 20.0), 0.0)
	var third: Vector3 = VisualMath.map_to_3d(Vector2(10.0, 20.0), 0.0)
	assert_that(first).is_equal(second)
	assert_that(second).is_equal(third)


# ---------------------------------------------------------------------------
# AC-3: GameDataRegistry boot integration — load, lookup, validation
# ---------------------------------------------------------------------------

func test_ready_loads_visual_mesh_mapping_keyed_by_entity_or_component_id() -> void:
	_inject_registry(VALID_MAPPINGS_DIR)
	_registry._ready()
	var result: VisualMeshMappingResource = _registry.get_visual_mesh_mapping(&"tower_round")
	assert_object(result).is_not_null()
	assert_str(String(result.entity_or_component_id)).is_equal("tower_round")
	assert_object(result.mesh_scene).is_not_null()


func test_get_visual_mesh_mapping_unknown_id_returns_null() -> void:
	_inject_registry(VALID_MAPPINGS_DIR)
	_registry._ready()
	var result: VisualMeshMappingResource = _registry.get_visual_mesh_mapping(&"nonexistent")
	assert_object(result).is_null()


func test_get_all_visual_mesh_mappings_returns_full_cache() -> void:
	_inject_registry(VALID_MAPPINGS_DIR)
	_registry._ready()
	var all_mappings: Dictionary = _registry.get_all_visual_mesh_mappings()
	assert_int(all_mappings.size()).is_equal(1)
	assert_bool(all_mappings.has(&"tower_round")).is_true()


func test_ready_logs_push_error_for_missing_mesh_scene() -> void:
	_inject_registry(INVALID_MAPPINGS_DIR)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] broken_mapping.tres: mesh_scene must be assigned")


# Edge case: INVALID_MAPPINGS_DIR contains TWO invalid files at once
# (broken_mapping.tres — missing mesh_scene, and empty_id.tres — missing
# entity_or_component_id). This test proves the SECOND file's distinct error
# is also surfaced by the same boot pass, not swallowed after the first.
func test_ready_logs_push_error_for_missing_entity_id_alongside_other_invalid_file() -> void:
	_inject_registry(INVALID_MAPPINGS_DIR)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] empty_id.tres: entity_or_component_id must not be empty")


func test_ready_completes_despite_invalid_visual_mesh_mapping() -> void:
	_inject_registry(INVALID_MAPPINGS_DIR)
	_registry._ready()
	# Boot did not abort — both invalid resources are still cached (same
	# does-not-abort policy as every other GameDataRegistry-loaded type):
	# _load_visual_mesh_mappings() stores every loaded resource under its own
	# entity_or_component_id regardless of validate() result, only push_error-ing
	# for each violation. empty_id.tres's key IS the empty StringName &"" — it
	# is not "unusable," it is simply keyed on an empty string, so it resolves
	# exactly like any other stored entry, not to null.
	assert_object(_registry.get_visual_mesh_mapping(&"broken_mapping")).is_not_null()
	assert_object(_registry.get_visual_mesh_mapping(&"")).is_not_null()


func test_ready_logs_push_error_for_visual_mesh_mapping_tres_that_fails_to_load() -> void:
	_inject_registry(MALFORMED_MAPPINGS_DIR)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] wrong_type.tres: failed to load as VisualMeshMappingResource.")
	assert_object(_registry.get_visual_mesh_mapping(&"anything")).is_null()


func test_ready_duplicate_entity_or_component_id_logs_push_error_last_file_wins() -> void:
	_inject_registry(DUPLICATE_MAPPINGS_DIR)
	_registry._ready()
	# Both mapping_a.tres and mapping_b.tres author entity_or_component_id =
	# &"duplicate_mapping". Exactly one wins (last file scanned) — assert a
	# result exists and its mesh_scene is one of the two authored scenes, not
	# that a specific file wins (file iteration order via
	# DirAccess.get_files_at() is not documented/guaranteed).
	var result: VisualMeshMappingResource = _registry.get_visual_mesh_mapping(&"duplicate_mapping")
	assert_object(result).is_not_null()
	var instance: Node = result.mesh_scene.instantiate()
	var root_name: String = instance.name
	instance.free()
	assert_bool(root_name == "MeshA" or root_name == "MeshB").is_true()

	# The overwrite is also loudly logged (code-review finding: this test's
	# own name previously claimed to verify the push_error but only checked
	# the resolved value). File iteration order is consistent within a
	# process run (though not documented/guaranteed by Godot's own API), so
	# root_name from the first _ready() call above tells us exactly which
	# file will win again on a fresh registry instance against the same
	# fixture dir, letting us assert the exact message that file's scan logs.
	var winning_file: String = "mapping_a.tres" if root_name == "MeshA" else "mapping_b.tres"
	_inject_registry(DUPLICATE_MAPPINGS_DIR)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] %s: duplicate entity_or_component_id 'duplicate_mapping' — overwriting previous entry." % winning_file)


func test_ready_missing_visual_mesh_mappings_directory_logs_push_error_no_crash() -> void:
	_inject_registry(MISSING_MAPPINGS_DIR)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] Visual mesh mappings directory does not exist: %s" % MISSING_MAPPINGS_DIR)
	assert_object(_registry.get_visual_mesh_mapping(&"anything")).is_null()


# ---------------------------------------------------------------------------
# AC-5: end-to-end real mapping — the live GameDataRegistry autoload resolves
# assets/data/visual_meshes/tower_round.tres to a loadable, instantiable
# PackedScene.
# ---------------------------------------------------------------------------

func test_live_registry_resolves_tower_round_mapping_to_instantiable_node3d() -> void:
	var mapping: VisualMeshMappingResource = GGameDataRegistry.get_visual_mesh_mapping(&"tower_round")
	assert_object(mapping).is_not_null()
	assert_array(mapping.validate()).is_empty()
	assert_object(mapping.mesh_scene).is_not_null()

	var instance: Node = mapping.mesh_scene.instantiate()
	assert_object(instance).is_not_null()
	assert_bool(instance is Node3D).is_true()
	instance.free()
