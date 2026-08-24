## Unit tests for CreatureAnimationClip, CreatureAtlasMappingResource, and
## GameDataRegistry's boot-time loading/validation of CreatureAtlasMappingResource
## (ADR-0038, hybrid-swarm-rendering-implementation-blueprint.md Story 5 —
## "Data registry integration").
##
## Registry-boot tests follow visual_mesh_mapping_resource_test.gd's
## direct-injection convention: a fresh GameDataRegistry.new() + _inject() +
## reach-in override of _creature_atlases_dir, fixtures under
## tests/fixtures/game_data_registry/creature_atlases_*/.
##
## This story is explicitly data-layer-only (ADR-0038 Migration Plan step 3:
## "without changing live monsters") — no live MonsterManager/MonsterInstance
## behavior is touched or asserted here.
extends GdUnitTestSuite

const VALID_ATLASES_DIR: String = "res://tests/fixtures/game_data_registry/creature_atlases_valid/"
const INVALID_ATLASES_DIR: String = "res://tests/fixtures/game_data_registry/creature_atlases_invalid/"
const MALFORMED_ATLASES_DIR: String = "res://tests/fixtures/game_data_registry/creature_atlases_malformed/"
const DUPLICATE_ATLASES_DIR: String = "res://tests/fixtures/game_data_registry/creature_atlases_duplicate/"
const MISSING_ATLASES_DIR: String = "res://tests/fixtures/game_data_registry/creature_atlases_does_not_exist/"

# Existing valid fixtures for the other GameDataRegistry loaders — needed
# because _inject() takes positional args for every loader, matching
# visual_mesh_mapping_resource_test.gd's own const-reuse convention.
const VALID_MONSTERS_DIR: String = "res://tests/fixtures/game_data_registry/monsters_valid/"
const VALID_PERK_REGISTRY_PATH: String = "res://tests/fixtures/game_data_registry/towers/perk_registry_valid.tres"
const EMPTY_TOWER_BLUEPRINTS_DIR: String = "res://tests/fixtures/game_data_registry/tower_blueprints_empty/"
const EMPTY_MISSIONS_DIR: String = "res://tests/fixtures/game_data_registry/missions_empty/"
const EMPTY_SKILLS_DIR: String = "res://tests/fixtures/game_data_registry/skills_empty/"
const VALID_COMBO_TABLE_PATH: String = "res://tests/fixtures/game_data_registry/skills_combo/ultimate_combo_table_valid.tres"
const EMPTY_DROP_TABLES_DIR: String = "res://tests/fixtures/game_data_registry/drop_tables_empty/"

var _registry: GameDataRegistry


func _inject_registry(creature_atlases_dir: String) -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR, EMPTY_SKILLS_DIR, VALID_COMBO_TABLE_PATH, EMPTY_DROP_TABLES_DIR)
	_registry._creature_atlases_dir = creature_atlases_dir


func after_test() -> void:
	if _registry != null and is_instance_valid(_registry):
		if _registry.is_inside_tree():
			_registry.get_parent().remove_child(_registry)
		_registry.free()
	_registry = null


# ---------------------------------------------------------------------------
# CreatureAnimationClip.validate()
# ---------------------------------------------------------------------------

func test_clip_validate_fails_when_all_fields_invalid() -> void:
	var clip := CreatureAnimationClip.new()
	clip.clip_name = &""
	clip.start_frame = -1
	clip.frame_count = 0
	clip.fps = 0.0
	var errors: Array[String] = clip.validate()
	assert_array(errors).contains([
		"clip_name must not be empty",
		"start_frame must not be negative (got -1)",
		"frame_count must be positive (got 0)",
		"fps must be positive (got 0.000000)",
	])


func test_clip_validate_passes_for_valid_clip() -> void:
	var clip := CreatureAnimationClip.new()
	clip.clip_name = &"walk"
	clip.start_frame = 0
	clip.frame_count = 4
	clip.fps = 12.0
	clip.loop = true
	assert_array(clip.validate()).is_empty()


# ---------------------------------------------------------------------------
# CreatureAtlasMappingResource.validate() — field-level failures
# ---------------------------------------------------------------------------

func _make_minimal_valid_mapping() -> CreatureAtlasMappingResource:
	var mapping := CreatureAtlasMappingResource.new()
	mapping.creature_id = &"test_creature"
	mapping.family_atlas_id = &"test_family"
	mapping.atlas_texture = PlaceholderTexture2D.new()
	mapping.atlas_columns = 2
	mapping.atlas_rows = 1
	mapping.frame_count = 2
	mapping.world_width = 1.0
	mapping.world_height = 1.0
	mapping.mesh_layout_id = &"quad_billboard"
	mapping.shader_variant_id = &"creature_swarm_body"
	mapping.render_mode_id = CreatureAtlasMappingResource.RENDER_MODE_ALPHA_SCISSOR
	mapping.presentation_class = CreatureAtlasMappingResource.PRESENTATION_CLASS_STANDARD
	mapping.batch_capacity_requirement = 200
	mapping.status_mask_schema_version = 1
	return mapping


func test_mapping_validate_passes_for_minimal_valid_resource() -> void:
	assert_array(_make_minimal_valid_mapping().validate()).is_empty()


func test_mapping_validate_fails_when_creature_id_empty() -> void:
	var mapping := _make_minimal_valid_mapping()
	mapping.creature_id = &""
	assert_array(mapping.validate()).contains(["creature_id must not be empty"])


func test_mapping_validate_fails_when_family_atlas_id_empty() -> void:
	var mapping := _make_minimal_valid_mapping()
	mapping.family_atlas_id = &""
	assert_array(mapping.validate()).contains(["family_atlas_id must not be empty"])


func test_mapping_validate_fails_when_atlas_texture_null() -> void:
	var mapping := _make_minimal_valid_mapping()
	mapping.atlas_texture = null
	assert_array(mapping.validate()).contains(["atlas_texture must be assigned"])


func test_mapping_validate_fails_when_atlas_columns_non_positive() -> void:
	var mapping := _make_minimal_valid_mapping()
	mapping.atlas_columns = 0
	assert_array(mapping.validate()).contains(["atlas_columns must be positive (got 0)"])


func test_mapping_validate_fails_when_atlas_rows_non_positive() -> void:
	var mapping := _make_minimal_valid_mapping()
	mapping.atlas_rows = -1
	assert_array(mapping.validate()).contains(["atlas_rows must be positive (got -1)"])


func test_mapping_validate_fails_when_frame_count_non_positive() -> void:
	var mapping := _make_minimal_valid_mapping()
	mapping.frame_count = 0
	assert_array(mapping.validate()).contains(["frame_count must be positive (got 0)"])


func test_mapping_validate_fails_when_frame_count_exceeds_grid_capacity() -> void:
	var mapping := _make_minimal_valid_mapping()
	mapping.atlas_columns = 2
	mapping.atlas_rows = 1
	mapping.frame_count = 3
	assert_array(mapping.validate()).contains(["frame_count (3) exceeds atlas grid capacity (2 columns x 1 rows = 2 cells)"])


func test_mapping_validate_fails_when_world_width_non_positive() -> void:
	var mapping := _make_minimal_valid_mapping()
	mapping.world_width = 0.0
	assert_array(mapping.validate()).contains(["world_width must be positive (got 0.000000)"])


func test_mapping_validate_fails_when_world_height_non_positive() -> void:
	var mapping := _make_minimal_valid_mapping()
	mapping.world_height = -2.0
	assert_array(mapping.validate()).contains(["world_height must be positive (got -2.000000)"])


func test_mapping_validate_fails_when_mesh_layout_id_empty() -> void:
	var mapping := _make_minimal_valid_mapping()
	mapping.mesh_layout_id = &""
	assert_array(mapping.validate()).contains(["mesh_layout_id must not be empty"])


func test_mapping_validate_fails_when_shader_variant_id_empty() -> void:
	var mapping := _make_minimal_valid_mapping()
	mapping.shader_variant_id = &""
	assert_array(mapping.validate()).contains(["shader_variant_id must not be empty"])


func test_mapping_validate_fails_when_render_mode_id_unrecognized() -> void:
	var mapping := _make_minimal_valid_mapping()
	mapping.render_mode_id = &"alpha_blend"
	assert_array(mapping.validate()).contains(["render_mode_id must be one of alpha_scissor/alpha_hash (got 'alpha_blend')"])


func test_mapping_validate_passes_for_alpha_hash_render_mode() -> void:
	var mapping := _make_minimal_valid_mapping()
	mapping.render_mode_id = CreatureAtlasMappingResource.RENDER_MODE_ALPHA_HASH
	assert_array(mapping.validate()).is_empty()


func test_mapping_validate_fails_when_presentation_class_unrecognized() -> void:
	var mapping := _make_minimal_valid_mapping()
	mapping.presentation_class = &"unique"
	assert_array(mapping.validate()).contains(["presentation_class must be one of standard/exceptional (got 'unique')"])


func test_mapping_validate_fails_when_exceptional_missing_approved_presenter_class() -> void:
	var mapping := _make_minimal_valid_mapping()
	mapping.presentation_class = CreatureAtlasMappingResource.PRESENTATION_CLASS_EXCEPTIONAL
	mapping.approved_presenter_class = &""
	assert_array(mapping.validate()).contains(["approved_presenter_class must be set for exceptional presentation_class"])


func test_mapping_validate_passes_for_exceptional_with_approved_presenter_class() -> void:
	var mapping := _make_minimal_valid_mapping()
	mapping.presentation_class = CreatureAtlasMappingResource.PRESENTATION_CLASS_EXCEPTIONAL
	mapping.approved_presenter_class = &"BossCreaturePresenter3D"
	assert_array(mapping.validate()).is_empty()


func test_mapping_validate_fails_when_standard_batch_capacity_non_positive() -> void:
	var mapping := _make_minimal_valid_mapping()
	mapping.batch_capacity_requirement = 0
	assert_array(mapping.validate()).contains(["batch_capacity_requirement must be positive for standard presentation_class (got 0)"])


func test_mapping_validate_ignores_batch_capacity_for_exceptional() -> void:
	var mapping := _make_minimal_valid_mapping()
	mapping.presentation_class = CreatureAtlasMappingResource.PRESENTATION_CLASS_EXCEPTIONAL
	mapping.approved_presenter_class = &"BossCreaturePresenter3D"
	mapping.batch_capacity_requirement = 0
	assert_array(mapping.validate()).is_empty()


func test_mapping_validate_fails_when_status_mask_schema_version_non_positive() -> void:
	var mapping := _make_minimal_valid_mapping()
	mapping.status_mask_schema_version = 0
	assert_array(mapping.validate()).contains(["status_mask_schema_version must be positive (got 0)"])


# ---------------------------------------------------------------------------
# CreatureAtlasMappingResource.validate() — animation_clips
# ---------------------------------------------------------------------------

func test_mapping_validate_fails_for_null_clip_entry() -> void:
	var mapping := _make_minimal_valid_mapping()
	mapping.animation_clips = [null]
	assert_array(mapping.validate()).contains(["animation_clips contains a null entry"])


func test_mapping_validate_propagates_clip_validation_errors_with_clip_name_prefix() -> void:
	var mapping := _make_minimal_valid_mapping()
	var bad_clip := CreatureAnimationClip.new()
	bad_clip.clip_name = &"broken"
	bad_clip.fps = 0.0
	mapping.animation_clips = [bad_clip]
	assert_array(mapping.validate()).contains(["animation clip 'broken': fps must be positive (got 0.000000)"])


func test_mapping_validate_fails_for_duplicate_clip_names() -> void:
	var mapping := _make_minimal_valid_mapping()
	var clip_1 := CreatureAnimationClip.new()
	clip_1.clip_name = &"idle"
	clip_1.start_frame = 0
	clip_1.frame_count = 1
	var clip_2 := CreatureAnimationClip.new()
	clip_2.clip_name = &"idle"
	clip_2.start_frame = 1
	clip_2.frame_count = 1
	mapping.animation_clips = [clip_1, clip_2]
	assert_array(mapping.validate()).contains(["duplicate animation clip name 'idle'"])


func test_mapping_validate_fails_when_clip_range_exceeds_frame_count() -> void:
	var mapping := _make_minimal_valid_mapping()
	mapping.frame_count = 2
	var clip := CreatureAnimationClip.new()
	clip.clip_name = &"walk"
	clip.start_frame = 1
	clip.frame_count = 2
	mapping.animation_clips = [clip]
	assert_array(mapping.validate()).contains(["animation clip 'walk': start_frame (1) + frame_count (2) exceeds this mapping's frame_count (2)"])


func test_mapping_validate_passes_with_valid_non_overlapping_clips() -> void:
	var mapping := _make_minimal_valid_mapping()
	mapping.atlas_columns = 4
	mapping.atlas_rows = 1
	mapping.frame_count = 4
	var idle := CreatureAnimationClip.new()
	idle.clip_name = &"idle"
	idle.start_frame = 0
	idle.frame_count = 2
	var walk := CreatureAnimationClip.new()
	walk.clip_name = &"walk"
	walk.start_frame = 2
	walk.frame_count = 2
	mapping.animation_clips = [idle, walk]
	assert_array(mapping.validate()).is_empty()


# ---------------------------------------------------------------------------
# get_animation_clip()
# ---------------------------------------------------------------------------

func test_get_animation_clip_returns_matching_clip() -> void:
	var mapping := _make_minimal_valid_mapping()
	var walk := CreatureAnimationClip.new()
	walk.clip_name = &"walk"
	mapping.animation_clips = [walk]
	assert_object(mapping.get_animation_clip(&"walk")).is_same(walk)


func test_get_animation_clip_returns_null_for_unknown_name() -> void:
	var mapping := _make_minimal_valid_mapping()
	assert_object(mapping.get_animation_clip(&"nonexistent")).is_null()


# ---------------------------------------------------------------------------
# GameDataRegistry boot integration — load, lookup, validation
# ---------------------------------------------------------------------------

func test_ready_loads_creature_atlas_mapping_keyed_by_creature_id() -> void:
	_inject_registry(VALID_ATLASES_DIR)
	_registry._ready()
	var result: CreatureAtlasMappingResource = _registry.get_creature_atlas_mapping(&"goblin_test")
	assert_object(result).is_not_null()
	assert_str(String(result.creature_id)).is_equal("goblin_test")
	assert_object(result.atlas_texture).is_not_null()
	assert_array(result.validate()).is_empty()


func test_get_creature_atlas_mapping_unknown_id_returns_null() -> void:
	_inject_registry(VALID_ATLASES_DIR)
	_registry._ready()
	assert_object(_registry.get_creature_atlas_mapping(&"nonexistent")).is_null()


func test_get_all_creature_atlas_mappings_returns_full_cache() -> void:
	_inject_registry(VALID_ATLASES_DIR)
	_registry._ready()
	var all_mappings: Dictionary = _registry.get_all_creature_atlas_mappings()
	assert_int(all_mappings.size()).is_equal(1)
	assert_bool(all_mappings.has(&"goblin_test")).is_true()


func test_ready_logs_push_error_for_missing_texture() -> void:
	_inject_registry(INVALID_ATLASES_DIR)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] missing_texture.tres: atlas_texture must be assigned")


func test_ready_logs_push_error_for_empty_creature_id() -> void:
	_inject_registry(INVALID_ATLASES_DIR)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] empty_id.tres: creature_id must not be empty")


func test_ready_completes_despite_invalid_creature_atlas_mapping() -> void:
	_inject_registry(INVALID_ATLASES_DIR)
	_registry._ready()
	# Boot did not abort — both invalid resources are still cached (same
	# does-not-abort policy as every other GameDataRegistry-loaded type).
	assert_object(_registry.get_creature_atlas_mapping(&"missing_texture_creature")).is_not_null()
	assert_object(_registry.get_creature_atlas_mapping(&"")).is_not_null()


func test_ready_logs_push_error_for_creature_atlas_tres_that_fails_to_load() -> void:
	_inject_registry(MALFORMED_ATLASES_DIR)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] wrong_type.tres: failed to load as CreatureAtlasMappingResource.")
	assert_object(_registry.get_creature_atlas_mapping(&"anything")).is_null()


func test_ready_duplicate_creature_id_logs_push_error_and_keeps_one_entry() -> void:
	_inject_registry(DUPLICATE_ATLASES_DIR)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] mapping_b.tres: duplicate creature_id 'duplicate_creature' — overwriting previous entry.")
	# Exactly one entry wins for the shared creature_id — file iteration
	# order is not documented/guaranteed by DirAccess.get_files_at(), so
	# this asserts a result exists rather than which of the two files won,
	# matching visual_mesh_mapping_resource_test.gd's own precedent.
	var result: CreatureAtlasMappingResource = _registry.get_creature_atlas_mapping(&"duplicate_creature")
	assert_object(result).is_not_null()


func test_ready_missing_creature_atlases_directory_logs_push_error_no_crash() -> void:
	_inject_registry(MISSING_ATLASES_DIR)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] Creature atlases directory does not exist: %s" % MISSING_ATLASES_DIR)
	assert_object(_registry.get_creature_atlas_mapping(&"anything")).is_null()


# ---------------------------------------------------------------------------
# End-to-end real fixtures — the live GameDataRegistry autoload resolves the
# two real production .tres files this story adds under
# assets/data/creature_atlases/.
# ---------------------------------------------------------------------------

func test_live_registry_resolves_goblin_runner_mapping() -> void:
	var mapping: CreatureAtlasMappingResource = GGameDataRegistry.get_creature_atlas_mapping(&"goblin_runner")
	assert_object(mapping).is_not_null()
	assert_array(mapping.validate()).is_empty()
	assert_object(mapping.atlas_texture).is_not_null()
	assert_str(String(mapping.presentation_class)).is_equal("standard")


func test_live_registry_resolves_goblin_warlord_boss_as_exceptional() -> void:
	var mapping: CreatureAtlasMappingResource = GGameDataRegistry.get_creature_atlas_mapping(&"goblin_warlord_boss")
	assert_object(mapping).is_not_null()
	assert_array(mapping.validate()).is_empty()
	assert_str(String(mapping.presentation_class)).is_equal("exceptional")
	assert_str(String(mapping.approved_presenter_class)).is_equal("BossCreaturePresenter3D")
