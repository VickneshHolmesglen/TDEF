## Integration tests for Story 008 (TR-hud-000, ADR-0031, ADR-0011): Ready
## Button + InputModeTracker wiring (Core Rules Group 6, Rules 16-18; Group 9,
## Rules 23-24).
##
## MissionHud IS added to the test's own scene tree (add_child()), matching
## this epic's established convention (mission_hud_test_helper.gd).
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
# AC-39/AC-40: existence + interactability across phases
# ---------------------------------------------------------------------------

func test_ready_exists_and_interactable_during_scout() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)

	assert_object(_hud._planning_cluster).is_not_null()
	assert_bool(_hud._planning_cluster._ready_button.disabled).is_false()


func test_ready_remains_interactable_during_pre_wave() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)

	assert_object(_hud._planning_cluster).is_not_null()
	assert_bool(_hud._planning_cluster._ready_button.disabled).is_false()


func test_ready_absent_during_wave_active() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)

	assert_object(_hud._planning_cluster).is_null()  # torn down, Story 002


func test_ready_exists_during_intermission() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)
	_hud._on_mission_phase_changed("WAVE_ACTIVE", "INTERMISSION", 0.0)

	assert_object(_hud._planning_cluster).is_not_null()
	assert_bool(_hud._planning_cluster._ready_button.disabled).is_false()


func test_ready_absent_during_mission_complete() -> void:
	# MISSION_COMPLETE always follows WAVE_ACTIVE in real play (Story 001's own
	# convention, hud-scaffold-local-state_test.gd) — Planning Cluster is
	# already torn down by that transition, same as the WAVE_ACTIVE case above.
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)
	_hud._on_mission_phase_changed("WAVE_ACTIVE", "MISSION_COMPLETE", 0.0)

	assert_object(_hud._planning_cluster).is_null()


func test_ready_absent_during_defeat() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)
	_hud._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 0.0)

	assert_object(_hud._planning_cluster).is_null()


# ---------------------------------------------------------------------------
# AC-41: synchronous emission, no HUD-side guard
# ---------------------------------------------------------------------------

func test_ready_press_emits_player_ready_synchronously() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	var received := {"count": 0}
	var handler := func() -> void: received["count"] += 1
	GEventBus.player_ready.connect(handler)

	_hud._planning_cluster._ready_button.pressed.emit()

	assert_int(received["count"]).is_equal(1)
	GEventBus.player_ready.disconnect(handler)


# ---------------------------------------------------------------------------
# AC-42: PRE_WAVE relabels the same button, same event
# ---------------------------------------------------------------------------

func test_pre_wave_relabels_ready_button() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	var scout_text: String = _hud._planning_cluster._ready_button.text

	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	var pre_wave_text: String = _hud._planning_cluster._ready_button.text

	assert_str(scout_text).is_not_equal(pre_wave_text)


# ---------------------------------------------------------------------------
# AC-43: InputModeTracker singleton, focus-ring gating
# ---------------------------------------------------------------------------

func test_input_mode_tracker_is_a_single_hud_root_child() -> void:
	var trackers: Array[Node] = []
	for child: Node in _hud.get_children():
		if child is InputModeTracker:
			trackers.append(child)

	assert_int(trackers.size()).is_equal(1)
	assert_object(_hud._input_mode_tracker).is_same(trackers[0])


func test_fresh_planning_cluster_receives_the_shared_tracker() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)

	assert_object(_hud._planning_cluster._input_mode_tracker).is_same(_hud._input_mode_tracker)


func test_focus_ring_hidden_without_focus() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)

	assert_bool(_hud._planning_cluster._ready_focus_ring.visible).is_false()


## Cross-button isolation (QA testability review finding): all 4 focusable
## buttons (Ready, Sell — PlanningCluster; Ultimate, Retry — MissionHud) share
## one InputModeTracker instance. Each ring's visibility handler independently
## checks its OWN button's has_focus() — a mis-wired handler pointing at the
## wrong button's has_focus() would show multiple rings simultaneously for a
## single focus event. Confirms that does not happen.
func test_focusing_ready_does_not_show_sibling_buttons_rings() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	var cluster: PlanningCluster = _hud._planning_cluster
	cluster.set_inspected_tower(1)  # make Sell visible too, so its ring is a fair comparison
	_hud._input_mode_tracker._current_mode = InputModeTracker.InputMode.KEYBOARD_GAMEPAD
	_hud._input_mode_tracker.input_mode_changed.emit(InputModeTracker.InputMode.KEYBOARD_GAMEPAD)

	cluster._ready_button.grab_focus()

	assert_bool(cluster._ready_focus_ring.visible).is_true()
	assert_bool(cluster._sell_focus_ring.visible).is_false()
	assert_bool(_hud._ultimate_focus_ring.visible).is_false()
	assert_bool(_hud._retry_focus_ring.visible).is_false()
