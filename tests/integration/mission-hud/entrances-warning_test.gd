## Multi-entrance warning (2026-11-04, design/quick-specs/procedural-paths-2026-11-03.md
## amendment): on a map with more than one SPAWN the HUD shows a banner at
## mission start saying how many entrances there are. Single-spawn maps show
## nothing. GGrid is the real Autoload, seeded per test (boss-lane-telegraph
## convention).
extends GdUnitTestSuite

var _hud: MissionHud


func _make_config(spawns: Array[Vector2i]) -> GridConfig:
	var cfg := GridConfig.new()
	cfg.cols = 4
	cfg.rows = 3
	cfg.cell_size = 64.0
	var cells: Dictionary[Vector2i, int] = {}
	for x: int in range(4):
		for y: int in range(3):
			cells[Vector2i(x, y)] = Grid.CellType.PATH
	for s: Vector2i in spawns:
		cells[s] = Grid.CellType.SPAWN
	cells[Vector2i(3, 1)] = Grid.CellType.GOAL
	cfg.cells = cells
	return cfg


func before_test() -> void:
	_hud = MissionHudTestHelper.build_hud()
	add_child(_hud)


func after_test() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null


func test_hud_two_spawn_map_shows_entrances_banner_at_scout() -> void:
	# Arrange
	GGrid.initialize(_make_config([Vector2i(0, 0), Vector2i(0, 2)]))
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	# Act
	_hud._on_templates_ready(2, 0.1)
	# Assert
	assert_bool(_hud._banner.visible).is_true()
	assert_str(_hud._banner_label.text).is_equal(tr("HUD_ENTRANCES_WARNING") % 2)
	assert_float(_hud._banner_timer.time_left).is_greater(MissionHud.BANNER_DURATION_SECONDS)


func test_hud_single_spawn_map_shows_no_banner() -> void:
	GGrid.initialize(_make_config([Vector2i(0, 1)]))
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	_hud._on_templates_ready(1, 0.1)
	assert_bool(_hud._banner.visible).is_false()


func test_hud_templates_ready_outside_scout_shows_no_banner() -> void:
	# An intermission rebuild must not repeat the mission-start warning.
	GGrid.initialize(_make_config([Vector2i(0, 0), Vector2i(0, 2)]))
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	_hud._dismiss_banner()
	_hud._on_mission_phase_changed("SCOUT", "INTERMISSION", 0.0)
	_hud._on_templates_ready(2, 0.1)
	assert_bool(_hud._banner.visible).is_false()
