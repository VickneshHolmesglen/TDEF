## Unit tests for the 2026-11-02 enemy archetypes: flying (straight-line path,
## immune to BALLISTIC), stealth (hero reveal), healer/splitter validation, and
## the four authored monsters' data.
extends GdUnitTestSuite


func _tower_state(projectile_type: String) -> TowerMissionState:
	var state := TowerMissionState.new()
	state.weapon = WeaponComponent.new()
	state.weapon.projectile_type = projectile_type
	return state


# --- Flight path ----------------------------------------------------------------

func test_monster_flight_path_runs_straight_from_spawn_to_nearest_goal() -> void:
	# Arrange
	var goals: Array[Vector2i] = [Vector2i(20, 11), Vector2i(10, 4)]
	# Act
	var path: Array[Vector2i] = MonsterManager.flight_path(Vector2i(0, 4), goals)
	# Assert
	assert_int(path.size()).is_equal(11)
	assert_object(path[0]).is_equal(Vector2i(0, 4))
	assert_object(path[path.size() - 1]).is_equal(Vector2i(10, 4))


func test_monster_flight_path_diagonal_steps_are_adjacent() -> void:
	# Arrange
	var goals: Array[Vector2i] = [Vector2i(7, 3)]
	# Act
	var path: Array[Vector2i] = MonsterManager.flight_path(Vector2i(0, 0), goals)
	# Assert
	for i: int in range(1, path.size()):
		assert_int(MonsterManager.chebyshev(path[i - 1], path[i])).is_equal(1)
	assert_object(path[path.size() - 1]).is_equal(Vector2i(7, 3))


func test_monster_flight_path_without_goal_is_empty() -> void:
	var goals: Array[Vector2i] = []
	assert_array(MonsterManager.flight_path(Vector2i(0, 0), goals)).is_empty()


# --- Stealth reveal -------------------------------------------------------------

func test_monster_stealth_revealed_only_within_hero_radius() -> void:
	# Radius 3 = WorldRange circle of 253 px.
	var monster := Vector2(320.0, 320.0)
	assert_bool(MonsterManager.is_revealed(monster, monster + Vector2(128.0, 128.0), 3)).is_true()  # 181 px
	assert_bool(MonsterManager.is_revealed(monster, monster + Vector2(256.0, 0.0), 3)).is_false()
	assert_bool(MonsterManager.is_revealed(monster, Vector2.INF, 3)).is_false()


# --- Tower targeting counters ---------------------------------------------------

func test_tower_ballistic_cannot_target_flyers_but_homing_can() -> void:
	# Arrange
	var tower_system := TowerSystem.new()
	var flyer: Dictionary = {"cell": Vector2i(3, 3), "is_flying": true}
	# Act / Assert
	assert_bool(tower_system.can_target(_tower_state("BALLISTIC"), flyer)).is_false()
	assert_bool(tower_system.can_target(_tower_state("HOMING"), flyer)).is_true()
	tower_system.free()


func test_tower_stealthed_target_needs_hero_nearby() -> void:
	# Arrange
	var tower_system := TowerSystem.new()
	var shade: Dictionary = {"cell": Vector2i(3, 3), "stealthed": true, "reveal_radius": 3}
	var state: TowerMissionState = _tower_state("HOMING")
	tower_system._grid = GGrid  # cell centres for the cached-cell fallback (no position sources)
	# Act / Assert
	assert_bool(tower_system.can_target(state, shade)).is_false()
	tower_system._on_hero_position_changed(Vector2i(5, 4))
	assert_bool(tower_system.can_target(state, shade)).is_true()
	tower_system._on_hero_died()
	assert_bool(tower_system.can_target(state, shade)).is_false()
	tower_system.free()


func test_tower_plain_ground_monster_stays_targetable() -> void:
	var tower_system := TowerSystem.new()
	assert_bool(tower_system.can_target(_tower_state("BALLISTIC"), {"cell": Vector2i(1, 1)})).is_true()
	tower_system.free()


# --- Validation and content -----------------------------------------------------

func test_monster_resource_rejects_self_split_and_unrevealable_stealth() -> void:
	# Arrange
	var res := MonsterResource.new()
	res.monster_id = &"loop"
	res.split_into_monster_id = &"loop"
	res.split_count = 2
	res.stealthed = true
	# Act
	var errors: Array[String] = res.validate()
	# Assert
	assert_int(errors.size()).is_equal(2)


func test_monster_archetype_content_is_valid_and_flagged() -> void:
	var moth: MonsterResource = load("res://assets/data/monsters/ashwing_moth.tres")
	var mender: MonsterResource = load("res://assets/data/monsters/goblin_mender.tres")
	var sac: MonsterResource = load("res://assets/data/monsters/brood_sac.tres")
	var shade: MonsterResource = load("res://assets/data/monsters/shade_stalker.tres")
	for res: MonsterResource in [moth, mender, sac, shade]:
		assert_array(res.validate()).is_empty()
		assert_bool(MonsterInstance.MONSTER_TEXTURES.has(res.monster_id)).is_true()
	assert_bool(moth.is_flying()).is_true()
	assert_bool(mender.is_healer()).is_true()
	assert_bool(sac.is_splitter()).is_true()
	assert_bool(shade.stealthed).is_true()
