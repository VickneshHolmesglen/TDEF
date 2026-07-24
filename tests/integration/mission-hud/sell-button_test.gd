## Integration tests for Story 010 (TR-hud-000, ADR-0031, ADR-0011): Sell
## Button (Core Rules Group 8, Rules 21-22). Reuses Story 008's InputModeTracker.
##
## Per user instruction, this story's usual full verification pass (targeted
## test run, live-MCP verification, full regression) was explicitly SKIPPED
## to move quickly through Stories 009/010 — this file is written but NOT
## executed this session. Run it (and the full regression) before trusting
## this story.
extends GdUnitTestSuite

const SPAWN_CELL := Vector2i(0, 0)


func _make_config() -> GridConfig:
	var cfg := GridConfig.new()
	cfg.cols = 1
	cfg.rows = 1
	cfg.cell_size = 64.0
	cfg.cells = {SPAWN_CELL: Grid.CellType.SPAWN}
	return cfg


var _hud: MissionHud


func before_test() -> void:
	GGrid.initialize(_make_config())
	_hud = MissionHudTestHelper.build_hud()
	add_child(_hud)


func after_test() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null


# ---------------------------------------------------------------------------
# AC-52: existence gate — phase AND selection
# ---------------------------------------------------------------------------

func test_hidden_during_scout_with_no_tower_inspected() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)

	assert_bool(_hud._planning_cluster._sell_button.visible).is_false()


func test_visible_during_scout_with_a_tower_inspected() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)

	_hud._planning_cluster.set_inspected_tower(7)

	assert_bool(_hud._planning_cluster._sell_button.visible).is_true()


func test_hidden_during_pre_wave_even_with_a_tower_inspected() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	_hud._planning_cluster.set_inspected_tower(7)

	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)

	assert_bool(_hud._planning_cluster._sell_button.visible).is_false()


func test_visible_during_intermission_with_a_tower_inspected() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)
	_hud._on_mission_phase_changed("WAVE_ACTIVE", "INTERMISSION", 0.0)

	_hud._planning_cluster.set_inspected_tower(9)

	assert_bool(_hud._planning_cluster._sell_button.visible).is_true()


# ---------------------------------------------------------------------------
# AC-53/AC-54: press behavior
# ---------------------------------------------------------------------------

func test_press_emits_tower_sell_requested_with_inspected_id() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	_hud._planning_cluster.set_inspected_tower(7)
	var received := {"tower_id": -99}
	var handler := func(tower_id: int) -> void: received["tower_id"] = tower_id
	GEventBus.tower_sell_requested.connect(handler)

	_hud._planning_cluster._sell_button.pressed.emit()

	assert_int(received["tower_id"]).is_equal(7)
	GEventBus.tower_sell_requested.disconnect(handler)


func test_press_clears_selection_and_hides_button() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	_hud._planning_cluster.set_inspected_tower(7)

	_hud._planning_cluster._sell_button.pressed.emit()

	assert_int(_hud._planning_cluster._inspected_tower_id).is_equal(-1)
	assert_bool(_hud._planning_cluster._sell_button.visible).is_false()


# ---------------------------------------------------------------------------
# AC-55: concurrent sells across different tower_ids, no HUD-side guard
# ---------------------------------------------------------------------------

func test_second_different_tower_sell_after_first_is_not_blocked() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	var received: Array[int] = []
	var handler := func(tower_id: int) -> void: received.append(tower_id)
	GEventBus.tower_sell_requested.connect(handler)

	_hud._planning_cluster.set_inspected_tower(1)
	_hud._planning_cluster._sell_button.pressed.emit()
	_hud._planning_cluster.set_inspected_tower(2)
	_hud._planning_cluster._sell_button.pressed.emit()

	assert_array(received).is_equal([1, 2])
	GEventBus.tower_sell_requested.disconnect(handler)
