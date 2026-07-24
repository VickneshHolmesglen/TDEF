## Unit tests for GameDataRegistry (S4-02, ADR-0009). Covers AC-1 through AC-8.
##
## _ready() is called directly (not via add_child()) for state-assertion tests,
## since GameDataRegistry has no scene-tree dependency in its load logic — this
## mirrors the direct-call convention used by monster_spawn_test.gd. AC-7 is the
## one test that needs actual scene-tree presence, so it uses add_child().
##
## Fixture .tres files live under tests/fixtures/game_data_registry/ — checked-in
## test data, loaded via the real ResourceLoader (expected per the story: "no
## external I/O beyond loading the actual sample .tres files you create").
extends GdUnitTestSuite

const VALID_MONSTERS_DIR: String = "res://tests/fixtures/game_data_registry/monsters_valid/"
const INVALID_MONSTERS_DIR: String = "res://tests/fixtures/game_data_registry/monsters_invalid/"
const DUPLICATE_MONSTERS_DIR: String = "res://tests/fixtures/game_data_registry/monsters_duplicate/"
const MALFORMED_MONSTERS_DIR: String = "res://tests/fixtures/game_data_registry/monsters_malformed/"
const MISSING_MONSTERS_DIR: String = "res://tests/fixtures/game_data_registry/monsters_does_not_exist/"
const VALID_PERK_REGISTRY_PATH: String = "res://tests/fixtures/game_data_registry/towers/perk_registry_valid.tres"
const MISSING_PERK_REGISTRY_PATH: String = "res://tests/fixtures/game_data_registry/towers/does_not_exist.tres"
const EMPTY_TOWER_BLUEPRINTS_DIR: String = "res://tests/fixtures/game_data_registry/tower_blueprints_empty/"
const VALID_TOWER_BLUEPRINTS_DIR: String = "res://tests/fixtures/game_data_registry/tower_blueprints_valid/"
const INVALID_TOWER_BLUEPRINTS_DIR: String = "res://tests/fixtures/game_data_registry/tower_blueprints_invalid/"
const MALFORMED_TOWER_BLUEPRINTS_DIR: String = "res://tests/fixtures/game_data_registry/tower_blueprints_malformed/"
const DUPLICATE_TOWER_BLUEPRINTS_DIR: String = "res://tests/fixtures/game_data_registry/tower_blueprints_duplicate/"
const MISSING_TOWER_BLUEPRINTS_DIR: String = "res://tests/fixtures/game_data_registry/tower_blueprints_does_not_exist/"
const EMPTY_MISSIONS_DIR: String = "res://tests/fixtures/game_data_registry/missions_empty/"
const VALID_MISSIONS_DIR: String = "res://tests/fixtures/game_data_registry/missions_valid/"
const INVALID_MISSIONS_DIR: String = "res://tests/fixtures/game_data_registry/missions_invalid/"
const MALFORMED_MISSIONS_DIR: String = "res://tests/fixtures/game_data_registry/missions_malformed/"
const DUPLICATE_MISSIONS_DIR: String = "res://tests/fixtures/game_data_registry/missions_duplicate/"
const MISSING_MISSIONS_DIR: String = "res://tests/fixtures/game_data_registry/missions_does_not_exist/"
const EMPTY_SKILLS_DIR: String = "res://tests/fixtures/game_data_registry/skills_empty/"
const VALID_SKILLS_DIR: String = "res://tests/fixtures/game_data_registry/skills_valid/"
const INVALID_SKILLS_DIR: String = "res://tests/fixtures/game_data_registry/skills_invalid/"
const MALFORMED_SKILLS_DIR: String = "res://tests/fixtures/game_data_registry/skills_malformed/"
const DUPLICATE_SKILLS_DIR: String = "res://tests/fixtures/game_data_registry/skills_duplicate/"
const MISSING_SKILLS_DIR: String = "res://tests/fixtures/game_data_registry/skills_does_not_exist/"
const VALID_COMBO_TABLE_PATH: String = "res://tests/fixtures/game_data_registry/skills_combo/ultimate_combo_table_valid.tres"
const MALFORMED_COMBO_TABLE_PATH: String = "res://tests/fixtures/game_data_registry/skills_combo/ultimate_combo_table_malformed.tres"
const MISSING_COMBO_TABLE_PATH: String = "res://tests/fixtures/game_data_registry/skills_combo/does_not_exist.tres"

var _registry: GameDataRegistry


func after_test() -> void:
	if _registry != null and is_instance_valid(_registry):
		if _registry.is_inside_tree():
			_registry.get_parent().remove_child(_registry)
		_registry.free()
	_registry = null


# ---------------------------------------------------------------------------
# AC-1: Autoload registration order
# ---------------------------------------------------------------------------

func test_autoload_registered_immediately_after_pathfinding_and_before_wavemanager() -> void:
	var text: String = FileAccess.get_file_as_string("res://project.godot")
	var pathfinding_idx: int = text.find("GPathfindingSystem=")
	var registry_idx: int = text.find("GGameDataRegistry=")
	var wave_manager_idx: int = text.find("GWaveManager=")
	assert_int(pathfinding_idx).is_greater(-1)
	assert_int(registry_idx).is_greater(-1)
	assert_int(wave_manager_idx).is_greater(-1)
	assert_bool(pathfinding_idx < registry_idx).is_true()
	assert_bool(registry_idx < wave_manager_idx).is_true()


func test_autoload_script_path_matches_adr_0009() -> void:
	var text: String = FileAccess.get_file_as_string("res://project.godot")
	assert_bool(text.contains("GGameDataRegistry=\"*res://src/core/game_data_registry.gd\"")).is_true()


# ---------------------------------------------------------------------------
# AC-2 / AC-5: Monster resource loading and lookup
# ---------------------------------------------------------------------------

func test_ready_loads_monster_resource_keyed_by_monster_id() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR)
	_registry._ready()
	var result: MonsterResource = _registry.get_monster_resource(&"goblin_runner")
	assert_object(result).is_not_null()
	assert_str(String(result.monster_id)).is_equal("goblin_runner")


func test_get_monster_resource_unknown_id_returns_null() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR)
	_registry._ready()
	var result: MonsterResource = _registry.get_monster_resource(&"nonexistent")
	assert_object(result).is_null()


# ---------------------------------------------------------------------------
# AC-3: Validation logging without abort
# ---------------------------------------------------------------------------

func test_ready_logs_push_error_for_invalid_monster_resource() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(INVALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] broken_goblin.tres: base_hp must be > 0 (got -5.00)")


func test_ready_completes_despite_invalid_monster_resource() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(INVALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR)
	_registry._ready()
	# Boot did not abort — the invalid resource is still cached (ADR-0009 Risks).
	var result: MonsterResource = _registry.get_monster_resource(&"broken_goblin")
	assert_object(result).is_not_null()


func test_ready_logs_push_error_for_monster_tres_that_fails_to_load() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(MALFORMED_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] wrong_type.tres: failed to load as MonsterResource.")
	# _ready() still completes — no entry added, no crash.
	assert_object(_registry.get_monster_resource(&"anything")).is_null()


func test_ready_duplicate_monster_id_logs_push_error_last_file_wins() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(DUPLICATE_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR)
	_registry._ready()
	# Both goblin_a.tres and goblin_b.tres author monster_id = &"duplicate_id".
	# Exactly one wins (last file scanned) — assert a result exists and is
	# one of the two authored values, not that a specific file wins (file
	# iteration order via DirAccess.get_files_at() is not documented/guaranteed).
	var result: MonsterResource = _registry.get_monster_resource(&"duplicate_id")
	assert_object(result).is_not_null()
	assert_bool(result.display_name == "Goblin A" or result.display_name == "Goblin B").is_true()


func test_ready_missing_monsters_directory_logs_push_error_no_crash() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(MISSING_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] Monsters directory does not exist: %s" % MISSING_MONSTERS_DIR)
	assert_object(_registry.get_monster_resource(&"anything")).is_null()


# ---------------------------------------------------------------------------
# AC-4 / AC-6: Perk registry preload
# ---------------------------------------------------------------------------

func test_get_perk_registry_non_null_after_ready() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR)
	_registry._ready()
	assert_object(_registry.get_perk_registry()).is_not_null()


func test_get_perk_registry_missing_file_returns_null_without_crash() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, MISSING_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] %s: failed to load as TowerPerkRegistry." % MISSING_PERK_REGISTRY_PATH)
	# Documented exception (story AC-4/AC-6 edge case): get_perk_registry() may be null here.
	assert_object(_registry.get_perk_registry()).is_null()


# ---------------------------------------------------------------------------
# S5-01: Tower blueprint loading and lookup (closes TD-data-001)
# ---------------------------------------------------------------------------

func test_ready_loads_tower_blueprint_keyed_by_tower_id() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, VALID_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR)
	_registry._ready()
	var result: TowerBlueprintData = _registry.get_tower_blueprint(&"archer")
	assert_object(result).is_not_null()
	assert_str(String(result.tower_id)).is_equal("archer")


func test_get_tower_blueprint_unknown_id_returns_null() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, VALID_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR)
	_registry._ready()
	var result: TowerBlueprintData = _registry.get_tower_blueprint(&"nonexistent")
	assert_object(result).is_null()


func test_get_all_tower_blueprints_returns_full_cache() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, VALID_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR)
	_registry._ready()
	var all_blueprints: Dictionary = _registry.get_all_tower_blueprints()
	assert_int(all_blueprints.size()).is_equal(1)
	assert_bool(all_blueprints.has(&"archer")).is_true()


func test_get_all_monster_resources_returns_full_cache() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR)
	_registry._ready()
	var all_monsters: Dictionary = _registry.get_all_monster_resources()
	assert_bool(all_monsters.has(&"goblin_runner")).is_true()


func test_ready_logs_push_error_for_invalid_tower_blueprint() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, INVALID_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[WeaponComponent] weapon_damage 200.0 outside [8.0, 120.0]")


func test_ready_completes_despite_invalid_tower_blueprint() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, INVALID_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR)
	_registry._ready()
	# Boot did not abort — the invalid blueprint is still cached (same policy as monsters).
	var result: TowerBlueprintData = _registry.get_tower_blueprint(&"broken_tower")
	assert_object(result).is_not_null()


func test_ready_logs_push_error_for_tower_tres_that_fails_to_load() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, MALFORMED_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] wrong_type.tres: failed to load as TowerBlueprintData.")
	assert_object(_registry.get_tower_blueprint(&"anything")).is_null()


func test_ready_duplicate_tower_id_logs_push_error_last_file_wins() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, DUPLICATE_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR)
	_registry._ready()
	# Both blueprint_a.tres and blueprint_b.tres author tower_id = &"duplicate_tower".
	# Exactly one wins (last file scanned) — assert a result exists and is one of
	# the two authored values, not that a specific file wins (file iteration order
	# via DirAccess.get_files_at() is not documented/guaranteed).
	var result: TowerBlueprintData = _registry.get_tower_blueprint(&"duplicate_tower")
	assert_object(result).is_not_null()
	assert_bool(result.display_name == "Blueprint A" or result.display_name == "Blueprint B").is_true()


func test_ready_missing_tower_blueprints_directory_logs_push_error_no_crash() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, MISSING_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] Tower blueprints directory does not exist: %s" % MISSING_TOWER_BLUEPRINTS_DIR)
	assert_object(_registry.get_tower_blueprint(&"anything")).is_null()


# ---------------------------------------------------------------------------
# S5-02: Mission resource loading and lookup (closes the missing-MissionResource gap)
# ---------------------------------------------------------------------------

func test_ready_loads_mission_resource_keyed_by_mission_id() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, VALID_MISSIONS_DIR)
	_registry._ready()
	var result: MissionResource = _registry.get_mission_resource(&"the_gap")
	assert_object(result).is_not_null()
	assert_str(String(result.mission_id)).is_equal("the_gap")
	assert_str(result.objective_text).is_equal("Defend the sanctuary. Survive 6 waves.")


func test_get_mission_resource_unknown_id_returns_null() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, VALID_MISSIONS_DIR)
	_registry._ready()
	var result: MissionResource = _registry.get_mission_resource(&"nonexistent")
	assert_object(result).is_null()


func test_ready_logs_push_error_for_invalid_mission_resource() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, INVALID_MISSIONS_DIR)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] broken_mission.tres: objective_text must not be empty")


func test_ready_completes_despite_invalid_mission_resource() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, INVALID_MISSIONS_DIR)
	_registry._ready()
	# Boot did not abort — the invalid resource is still cached (same policy as monsters/towers).
	var result: MissionResource = _registry.get_mission_resource(&"broken_mission")
	assert_object(result).is_not_null()


func test_ready_logs_push_error_for_mission_tres_that_fails_to_load() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, MALFORMED_MISSIONS_DIR)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] wrong_type.tres: failed to load as MissionResource.")
	assert_object(_registry.get_mission_resource(&"anything")).is_null()


func test_ready_duplicate_mission_id_logs_push_error_last_file_wins() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, DUPLICATE_MISSIONS_DIR)
	_registry._ready()
	var result: MissionResource = _registry.get_mission_resource(&"duplicate_mission")
	assert_object(result).is_not_null()
	assert_bool(result.objective_text == "Objective A" or result.objective_text == "Objective B").is_true()


func test_ready_missing_missions_directory_logs_push_error_no_crash() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, MISSING_MISSIONS_DIR)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] Missions directory does not exist: %s" % MISSING_MISSIONS_DIR)
	assert_object(_registry.get_mission_resource(&"anything")).is_null()


# ---------------------------------------------------------------------------
# AC-7: Autoload lifetime check — no per-frame processing
# ---------------------------------------------------------------------------

func test_registry_has_no_per_frame_processing_when_in_scene_tree() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR)
	add_child(_registry)
	assert_bool(_registry.is_inside_tree()).is_true()
	assert_bool(_registry.is_processing()).is_false()
	assert_bool(_registry.is_physics_processing()).is_false()


# ---------------------------------------------------------------------------
# AC-8: TowerComponent isolation (static/structural check)
# ---------------------------------------------------------------------------

func test_source_does_not_reference_tower_component_classes() -> void:
	var text: String = FileAccess.get_file_as_string("res://src/core/game_data_registry.gd")
	assert_bool(text.contains("FoundationComponent")).is_false()
	assert_bool(text.contains("WeaponComponent")).is_false()
	assert_bool(text.contains("FocusComponent")).is_false()
	assert_bool(text.contains("PowerComponent")).is_false()


# ---------------------------------------------------------------------------
# TD-hero-002: Skill resource loading and lookup, Ultimate combo table
# ---------------------------------------------------------------------------

func test_ready_loads_skill_resource_keyed_by_skill_id() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR, VALID_SKILLS_DIR, VALID_COMBO_TABLE_PATH)
	_registry._ready()
	var result: SkillResource = _registry.get_skill_resource(&"test_skill_a")
	assert_object(result).is_not_null()
	assert_float(result.base_cooldown).is_equal_approx(2.0, 0.0001)


func test_get_skill_resource_unknown_id_returns_null() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR, VALID_SKILLS_DIR, VALID_COMBO_TABLE_PATH)
	_registry._ready()
	var result: SkillResource = _registry.get_skill_resource(&"nonexistent")
	assert_object(result).is_null()


func test_get_all_skill_resources_returns_full_cache() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR, VALID_SKILLS_DIR, VALID_COMBO_TABLE_PATH)
	_registry._ready()
	var all_skills: Dictionary = _registry.get_all_skill_resources()
	assert_int(all_skills.size()).is_equal(1)
	assert_bool(all_skills.has(&"test_skill_a")).is_true()


func test_ready_logs_push_error_for_invalid_skill_resource() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR, INVALID_SKILLS_DIR, VALID_COMBO_TABLE_PATH)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] broken_skill.tres: base_cooldown must be > 0.0")


func test_ready_completes_despite_invalid_skill_resource() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR, INVALID_SKILLS_DIR, VALID_COMBO_TABLE_PATH)
	_registry._ready()
	# Boot did not abort — the invalid resource is still cached (same policy as monsters/towers/missions).
	var result: SkillResource = _registry.get_skill_resource(&"broken_skill")
	assert_object(result).is_not_null()


func test_ready_logs_push_error_for_skill_tres_that_fails_to_load() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR, MALFORMED_SKILLS_DIR, VALID_COMBO_TABLE_PATH)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] wrong_type.tres: failed to load as SkillResource.")
	assert_object(_registry.get_skill_resource(&"anything")).is_null()


func test_ready_duplicate_skill_id_logs_push_error_last_file_wins() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR, DUPLICATE_SKILLS_DIR, VALID_COMBO_TABLE_PATH)
	_registry._ready()
	var result: SkillResource = _registry.get_skill_resource(&"duplicate_skill")
	assert_object(result).is_not_null()
	assert_bool(result.base_cooldown == 2.0 or result.base_cooldown == 5.0).is_true()


func test_ready_missing_skills_directory_logs_push_error_no_crash() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR, MISSING_SKILLS_DIR, MISSING_COMBO_TABLE_PATH)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] Skills directory does not exist: %s" % MISSING_SKILLS_DIR)
	assert_object(_registry.get_skill_resource(&"anything")).is_null()


func test_ready_loads_ultimate_combo_table() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR, EMPTY_SKILLS_DIR, VALID_COMBO_TABLE_PATH)
	_registry._ready()
	var table: UltimateComboTable = _registry.get_ultimate_combo_table()
	assert_object(table).is_not_null()
	assert_that(table.get_ultimate_for_combo("a,b,c,d")).is_equal(&"test_ultimate")


func test_get_ultimate_for_combo_unknown_key_returns_empty_stringname() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR, EMPTY_SKILLS_DIR, VALID_COMBO_TABLE_PATH)
	_registry._ready()
	var table: UltimateComboTable = _registry.get_ultimate_combo_table()
	assert_that(table.get_ultimate_for_combo("nonexistent,combo,key,here")).is_equal(&"")


func test_ready_logs_push_error_for_combo_table_that_fails_to_load() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR, EMPTY_SKILLS_DIR, MALFORMED_COMBO_TABLE_PATH)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] %s: failed to load as UltimateComboTable." % MALFORMED_COMBO_TABLE_PATH)
	assert_object(_registry.get_ultimate_combo_table()).is_null()


func test_ready_missing_combo_table_logs_push_error_no_crash() -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR, EMPTY_SKILLS_DIR, MISSING_COMBO_TABLE_PATH)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] %s: failed to load as UltimateComboTable." % MISSING_COMBO_TABLE_PATH)
	assert_object(_registry.get_ultimate_combo_table()).is_null()
