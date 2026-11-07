extends GdUnitTestSuite

## Raised things follow the terrain (spec 2026-11-07-3d-terrain §6.4): the
## hero sprite is lifted by the surface under it, and placement picking maps
## a pointer over a hill's drawn top onto that hilltop.

const CELL := 64.0
const MissionSceneScript := preload("res://src/scenes/mission_scene.gd")

var _scenery: Hd2dScenery


func before_test() -> void:
	_scenery = Hd2dScenery.new()
	add_child(_scenery)
	_scenery.profile = load("res://assets/data/hd2d/the_gap_scenery.tres") as Hd2dSceneryProfile
	var cfg: GridConfig = load("res://tests/unit/visual_presentation/terrain_surface_test.gd")._config()
	GGrid.initialize(cfg)
	_scenery.set_terrain(TerrainSurface.from_config(cfg, TerrainTuning.load_default()))


func after_test() -> void:
	remove_child(_scenery)
	_scenery.free()
	GGrid.initialize(GridConfig.new())


func test_hero_sprite_lifted_on_hill() -> void:
	var hero: Hero = (load("res://src/core/hero/Hero.tscn") as PackedScene).instantiate()
	add_child(hero)
	hero.set_physics_process(false)
	var sprite: Sprite2D = hero.get_node("Sprite2D")
	var base_y: float = sprite.position.y
	hero.global_position = Vector2(5.5, 5.5) * CELL
	hero.set_visual_lift(_scenery.screen_lift(hero.global_position))
	assert_float(sprite.position.y).is_equal_approx(base_y - _scenery.screen_lift(hero.global_position), 0.01)
	assert_float(base_y - sprite.position.y).is_greater(10.0)
	hero.set_visual_lift(0.0)
	assert_float(sprite.position.y).is_equal_approx(base_y, 0.01)
	remove_child(hero)
	hero.free()


func test_placement_center_uses_screen_to_ground() -> void:
	var scene: Node2D = MissionSceneScript.new()
	scene._scenery = _scenery
	scene._selected_blueprint_id = GGameDataRegistry.get_all_tower_blueprints().keys()[0]
	scene.placement_snap_cells = 0.0
	var top := Vector2(5.5, 7.2) * CELL  # near the hill's camera-side edge
	var pointer := Vector2(top.x, top.y - _scenery.screen_lift(top))
	var center: Vector2 = scene._placement_center(pointer)
	assert_int(int(floor(center.y / CELL))).is_equal(7)
	scene.free()
