## Integration tests for Story 012 (TR-hud-000, ADR-0031, ADR-0028, ADR-0011):
## DEFEAT Retry Button (Core Rules Group 10, Rules 25-27).
##
## MissionHud IS added to the test's own scene tree (add_child()), matching
## this epic's established convention. GMissionSelect IS the real Autoload
## (not a stub) — armed directly via its own fields, matching
## retry-current-mission-api_test.gd's established convention for this exact
## class, rather than driving the full select/confirm UI flow.
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
# AC-68: DEFEAT-only existence
# ---------------------------------------------------------------------------

func test_retry_hidden_during_scout() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)

	assert_bool(_hud._retry_button.visible).is_false()


func test_retry_hidden_during_mission_complete() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)

	_hud._on_mission_phase_changed("WAVE_ACTIVE", "MISSION_COMPLETE", 0.0)

	assert_bool(_hud._retry_button.visible).is_false()


func test_retry_visible_during_defeat() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)

	_hud._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 0.0)

	assert_bool(_hud._retry_button.visible).is_true()
	assert_bool(_hud.visible).is_true()  # AC-68: HUD itself must stay visible for Retry to be seeable


func test_retry_hidden_again_after_a_fresh_scout_mount() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)
	_hud._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 0.0)

	# Real retry sequencing: WaveManager never resets its own _phase to IDLE,
	# so a retry's mission_phase_changed arrives as (DEFEAT -> SCOUT), not
	# (IDLE -> SCOUT) — this is exactly the AC-70 mount-condition fix.
	_hud._on_mission_phase_changed("DEFEAT", "SCOUT", 0.0)

	assert_bool(_hud._retry_button.visible).is_false()
	assert_bool(_hud._combat_cluster.visible).is_true()
	assert_object(_hud._planning_cluster).is_not_null()  # AC-70: reacted exactly like an initial launch


# ---------------------------------------------------------------------------
# AC-69: direct Autoload call, not EventBus
# ---------------------------------------------------------------------------

func test_retry_press_calls_mission_select_directly() -> void:
	GMissionSelect._restore_completed = true
	GMissionSelect.select_mission("the_gap")
	GMissionSelect.set_difficulty_tier(1)
	GMissionSelect.confirm_launch()
	var spy := EventBusSpy.new()
	spy.watch(GEventBus.mission_launched)
	spy.clear()

	_hud._retry_button.pressed.emit()

	assert_int(spy.count("mission_launched")).is_equal(1)
	spy.disconnect_all()


# ---------------------------------------------------------------------------
# AC-70: retry's mission_launched is handled identically to an initial launch
# ---------------------------------------------------------------------------

func test_retry_triggered_mission_launched_reaches_the_same_scout_mount_path() -> void:
	GMissionSelect._restore_completed = true
	GMissionSelect.select_mission("the_gap")
	GMissionSelect.set_difficulty_tier(1)
	GMissionSelect.confirm_launch()
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)
	_hud._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 0.0)
	_hud._breach_count = 3  # dirty some Rule-4 state to prove the reset actually runs

	# Real retry: WaveManager itself reacts to mission_launched and calls
	# _transition_to(Phase.SCOUT), which is what actually drives MissionHud —
	# simulated directly here since this test's scope is MissionHud's own
	# reaction, not WaveManager's (covered separately in wave_manager tests).
	_hud._on_mission_phase_changed("DEFEAT", "SCOUT", 0.0)

	assert_int(_hud._breach_count).is_equal(0)  # Rule-4 reset ran, same as an initial launch


# ---------------------------------------------------------------------------
# Mission outcome screen: interim Retry suppressed when the outcome screen owns DEFEAT
# ---------------------------------------------------------------------------

func test_retry_hidden_during_defeat_when_outcome_screen_is_in_the_tree() -> void:
	var screen: MissionOutcomeScreen = auto_free((load("res://src/presentation/mission_outcome/MissionOutcomeScreen.tscn") as PackedScene).instantiate())
	add_child(screen)
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)

	_hud._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 0.0)

	assert_bool(_hud._retry_button.visible).is_false()
	remove_child(screen)
