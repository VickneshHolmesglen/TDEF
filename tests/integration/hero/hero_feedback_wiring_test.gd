extends GdUnitTestSuite

## Wiring guard (wind-up presentation spec §3/§10): both mission scenes host a HeroFeedback child
## that reacts to hero_health_changed and resolves a live monster's position through
## MonsterManager.get_monster_world_position. No test path here emits the real hero_died.

const THE_GAP_PATH: String = "res://src/gameplay/missions/the_gap/the_gap.tscn"
const MISSION_SCENE_PATH: String = "res://src/scenes/MissionScene.tscn"

var _scene: Node
var _fake_entity: MonsterEntity


func before_test() -> void:
	# Real GSceneManager is live: keep any accidental hero_died from arming the 1.5 s hold.
	GSceneManager._death_hold_seconds = 0.0
	GMissionSelect.reset_to_defaults()
	GMissionSelect._restore_completed = true


func after_test() -> void:
	GSceneManager._death_hold_seconds = GSceneManager.HERO_DEATH_HOLD_SECONDS
	if _fake_entity != null and is_instance_valid(_fake_entity):
		_fake_entity.free()
	_fake_entity = null
	if is_instance_valid(_scene):
		if _scene.get_parent() != null:
			_scene.get_parent().remove_child(_scene)
		_scene.free()
	_scene = null
	GGrid.initialize(GridConfig.new())
	GMissionSelect.reset_to_defaults()


func _assert_feedback(feedback: HeroFeedback, manager: MonsterManager) -> void:
	assert_object(feedback).is_not_null()
	assert_str(String(feedback.name)).is_equal("HeroFeedback")
	# Provider resolves a spawned monster's position through the manager getter.
	_fake_entity = MonsterEntity.new()
	_fake_entity.entity_id = 987654
	manager._entity_lookup[987654] = _fake_entity
	add_child(_fake_entity)
	_fake_entity.global_position = Vector2(123.0, 45.0)
	var provider: Callable = feedback._source_position_provider
	assert_bool(provider.is_valid()).is_true()
	assert_vector(provider.call(987654) as Vector2).is_equal(Vector2(123.0, 45.0))
	assert_vector(provider.call(-1) as Vector2).is_equal(Vector2.INF)
	manager._entity_lookup.erase(987654)
	# Low-HP state reacts to the real event bus.
	assert_bool(feedback.is_low_hp_active()).is_false()
	GEventBus.hero_health_changed.emit(10.0, 100.0)
	assert_bool(feedback.is_low_hp_active()).is_true()
	GEventBus.hero_health_changed.emit(100.0, 100.0)


func test_the_gap_hosts_hero_feedback() -> void:
	_scene = (load(THE_GAP_PATH) as PackedScene).instantiate()
	add_child(_scene)
	var feedback: HeroFeedback = _scene.get_node_or_null("HeroFeedback") as HeroFeedback
	_assert_feedback(feedback, _scene.get_node("MonsterManager") as MonsterManager)


func test_mission_scene_hosts_hero_feedback_under_gameplay_root() -> void:
	_scene = (load(MISSION_SCENE_PATH) as PackedScene).instantiate()
	add_child(_scene)
	var feedback: HeroFeedback = _scene.get_node_or_null("GameplayRoot/HeroFeedback") as HeroFeedback
	_assert_feedback(feedback, _scene.get_node("GameplayRoot/MonsterManager") as MonsterManager)
