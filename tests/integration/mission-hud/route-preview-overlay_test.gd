## Integration tests for Story 003 (TR-hud-001, ADR-0031): Route-Preview
## Overlay (Core Rules Group 3, Rules 9-11; Confirmed Signal Contract PC-1).
##
## MissionHud IS added to the test's own scene tree (add_child(), matching
## Story 002's established deviation — safe here since MissionHud has no
## SavePersistence registration). GGrid/GEventBus/GPathfindingSystem are the
## REAL global Autoloads, driven through the same real sequence a live
## mission uses (GGrid.initialize() then mission_phase_changed("", "SCOUT")
## to trigger the real GPathfindingSystem's own template build and
## templates_ready emission) — mirrors this project's established
## pathfinding-consumer test convention, not Pathfinding's own isolated
## local-instance fixture (that pattern tests Pathfinding itself; this story
## tests Mission HUD's correct USE of Pathfinding's real API).
extends GdUnitTestSuite

const SPAWN_CELL := Vector2i(0, 0)
const GOAL_CELL := Vector2i(2, 0)

var _hud: MissionHud


func _make_config() -> GridConfig:
	var cfg := GridConfig.new()
	cfg.cols = 3
	cfg.rows = 1
	cfg.cell_size = 64.0
	cfg.cells = {
		SPAWN_CELL: Grid.CellType.SPAWN,
		Vector2i(1, 0): Grid.CellType.PATH,
		GOAL_CELL: Grid.CellType.GOAL,
	}
	return cfg


func before_test() -> void:
	_hud = MissionHudTestHelper.build_hud()
	add_child(_hud)


func after_test() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null


# ---------------------------------------------------------------------------
# AC-13: initial render on templates_ready, once per spawn cell
# ---------------------------------------------------------------------------

func test_templates_ready_populates_last_known_routes_and_renders_into_live_cluster() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)  # spawns Planning Cluster first
	GGrid.initialize(_make_config())

	GEventBus.mission_phase_changed.emit("", "SCOUT", 0.0)  # real GPathfindingSystem builds templates + emits templates_ready

	assert_int(_hud._last_known_routes.size()).is_equal(1)  # one route, one SPAWN cell
	var route: Array = _hud._last_known_routes[0]
	assert_bool(route.is_empty()).is_false()
	assert_int(_hud._planning_cluster._route_overlay_host.get_child_count()).is_equal(1)  # one Line2D rendered


func test_boot_race_fallback_still_renders_when_templates_ready_fires_before_ready() -> void:
	# Simulate the boot race directly: GPathfindingSystem is already ready
	# BEFORE a fresh MissionHud's _ready() connects — its own _ready() fallback
	# poll must still populate _last_known_routes (AC-13's boot-race clause).
	GGrid.initialize(_make_config())
	GEventBus.mission_phase_changed.emit("", "SCOUT", 0.0)
	assert_bool(GPathfindingSystem.is_templates_ready()).is_true()

	var fresh_hud: MissionHud = MissionHudTestHelper.build_hud()
	add_child(fresh_hud)  # triggers _ready() -> fallback poll

	assert_int(fresh_hud._last_known_routes.size()).is_equal(1)
	fresh_hud.queue_free()


# ---------------------------------------------------------------------------
# AC-14: path_invalidated re-derives via find_path(), never renders
# affected_cells directly
# ---------------------------------------------------------------------------

func test_path_invalidated_re_renders_via_find_path_not_affected_cells() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	GGrid.initialize(_make_config())
	GEventBus.mission_phase_changed.emit("", "SCOUT", 0.0)
	var cluster: PlanningCluster = _hud._planning_cluster

	GEventBus.path_invalidated.emit([Vector2i(1, 0)])  # a footprint cell, NOT a route

	# The re-render must come from find_path()'s own real result, not the
	# affected_cells payload — verified by confirming the cache still holds
	# a genuine SPAWN->GOAL route, not the single footprint cell passed in.
	assert_int(_hud._last_known_routes.size()).is_equal(1)
	assert_bool((_hud._last_known_routes[0] as Array) != [Vector2i(1, 0)]).is_true()
	assert_int(cluster._route_overlay_host.get_child_count()).is_equal(1)


# ---------------------------------------------------------------------------
# AC-16: INTERMISSION reappears with last-known route
# ---------------------------------------------------------------------------

func test_intermission_remount_reappears_with_last_known_route() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	GGrid.initialize(_make_config())
	GEventBus.mission_phase_changed.emit("", "SCOUT", 0.0)
	var cached_routes: Array = _hud._last_known_routes.duplicate()

	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)
	_hud._on_mission_phase_changed("WAVE_ACTIVE", "INTERMISSION", 0.0)

	assert_int(_hud._planning_cluster._route_overlay_host.get_child_count()).is_equal(1)
	assert_array(_hud._last_known_routes).is_equal(cached_routes)  # unchanged — no path_invalidated arrived


# ---------------------------------------------------------------------------
# AC-17/AC-18: structural WAVE_ACTIVE exclusion, PRE_WAVE treated like
# INTERMISSION (no special case needed)
# ---------------------------------------------------------------------------

func test_planning_cluster_does_not_exist_during_wave_active_structurally_excludes_path_invalidated() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)

	assert_object(_hud._planning_cluster).is_null()  # no live instance to receive path_invalidated at all


func test_pre_wave_still_re_renders_on_path_invalidated_no_special_guard() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	GGrid.initialize(_make_config())
	GEventBus.mission_phase_changed.emit("", "SCOUT", 0.0)
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	var cluster: PlanningCluster = _hud._planning_cluster

	GEventBus.path_invalidated.emit([Vector2i(1, 0)])

	assert_int(cluster._route_overlay_host.get_child_count()).is_equal(1)  # re-rendered, same as INTERMISSION
