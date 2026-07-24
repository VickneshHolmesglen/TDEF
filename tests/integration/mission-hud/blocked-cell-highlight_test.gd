## Integration tests for Story 004 (TR-hud-002, ADR-0031): Blocked-Cell
## Highlight (Core Rules Group 4, Rule 12; Confirmed Signal Contract PC-2).
##
## MissionHud IS added to the test's own scene tree (add_child()), matching
## Stories 001-003's established convention — required to exercise
## PlanningCluster's own _ready()-connected tower_placement_blocked
## subscription and its get_viewport()-dependent rendering.
extends GdUnitTestSuite

var _hud: MissionHud


func before_test() -> void:
	_hud = MissionHudTestHelper.build_hud()
	add_child(_hud)
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)


func after_test() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null


func _cluster() -> PlanningCluster:
	return _hud._planning_cluster


# ---------------------------------------------------------------------------
# AC-19: highlight blocked_cells
# ---------------------------------------------------------------------------

func test_tower_placement_blocked_highlights_every_blocked_cell() -> void:
	var blocked: Array = [Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 1)]

	GEventBus.tower_placement_blocked.emit(blocked, Vector2i(-1, -1))

	assert_int(_cluster()._blocked_cell_host.get_child_count()).is_equal(3)


# ---------------------------------------------------------------------------
# AC-20: primary_blocking_cell distinct treatment
# ---------------------------------------------------------------------------

func test_primary_blocking_cell_gets_distinct_treatment() -> void:
	var blocked: Array = [Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 1)]

	GEventBus.tower_placement_blocked.emit(blocked, Vector2i(1, 2))

	var primary_count: int = 0
	var uniform_count: int = 0
	for marker: Node in _cluster()._blocked_cell_host.get_children():
		if marker.get_meta("is_primary"):
			primary_count += 1
			assert_that(marker.get_meta("cell")).is_equal(Vector2i(1, 2))
		else:
			uniform_count += 1
	assert_int(primary_count).is_equal(1)
	assert_int(uniform_count).is_equal(2)


# ---------------------------------------------------------------------------
# AC-21: sentinel -> uniform treatment for all
# ---------------------------------------------------------------------------

func test_sentinel_primary_cell_highlights_all_uniformly() -> void:
	var blocked: Array = [Vector2i(1, 1), Vector2i(1, 2)]

	GEventBus.tower_placement_blocked.emit(blocked, Vector2i(-1, -1))

	for marker: Node in _cluster()._blocked_cell_host.get_children():
		assert_bool(marker.get_meta("is_primary")).is_false()


# ---------------------------------------------------------------------------
# Fresh render clears the prior set (same double-connected/stale-child bug
# class already caught and fixed in render_route()).
# ---------------------------------------------------------------------------

func test_second_emission_replaces_not_accumulates() -> void:
	GEventBus.tower_placement_blocked.emit([Vector2i(1, 1)], Vector2i(-1, -1))
	GEventBus.tower_placement_blocked.emit([Vector2i(2, 2), Vector2i(3, 3)], Vector2i(-1, -1))

	assert_int(_cluster()._blocked_cell_host.get_child_count()).is_equal(2)
