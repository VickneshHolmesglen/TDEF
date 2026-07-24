## Unit tests for Story 003 (TR-const-001, ADR-0022): deactivation lifecycle
## and the reverse-index-driven overlap-stacking deactivation (Core Rule 5).
##
## Same fixture conventions as the other Constellation test files
## (Constellation.new(), no add_child(), GridSpyDouble on _grid, handler
## methods called directly).
extends GdUnitTestSuite

var _constellation: Constellation
var _grid: GridSpyDouble
var _spy: EventBusSpy


func before_test() -> void:
	_constellation = Constellation.new()
	_grid = GridSpyDouble.new()
	_constellation._grid = _grid
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.constellation_activated)
	_spy.watch(GEventBus.constellation_deactivated)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _constellation != null and is_instance_valid(_constellation):
		_constellation.free()
	_constellation = null
	_grid = null


func _place(tower_id: int, cell: Vector2i, tag: String) -> void:
	_grid.place(tower_id, cell)
	_constellation._on_tower_placed(TowerPlacedEvent.make(tower_id, cell, "BASIC", Vector2i.ONE, true, tag))


func _make_active_triad_line() -> void:
	_place(1, Vector2i(2, 4), "solar")
	_place(2, Vector2i(3, 4), "solar")
	_place(3, Vector2i(4, 4), "solar")
	assert_int(_spy.count("constellation_activated")).is_equal(1)


# ---------------------------------------------------------------------------
# AC-10: tower_removed deactivates with reason "tower_removed"
# ---------------------------------------------------------------------------

func test_tower_removed_deactivates_active_instance_with_correct_reason() -> void:
	_make_active_triad_line()

	_grid.remove(Vector2i(3, 4))
	_constellation._on_tower_removed(2, Vector2i(3, 4), "BASIC", "solar")

	assert_int(_spy.count("constellation_deactivated")).is_equal(1)
	var args: Array = (_spy.emissions["constellation_deactivated"] as Array)[0] as Array
	assert_str(args[0] as String).is_equal("triad_line@(2,4)")
	assert_str(args[1] as String).is_equal("tower_removed")
	assert_bool(_constellation.is_active("triad_line@(2,4)")).is_false()


# ---------------------------------------------------------------------------
# AC-11: tower_destroyed deactivates with reason "tower_destroyed"
# ---------------------------------------------------------------------------

func test_tower_destroyed_deactivates_active_instance_with_correct_reason() -> void:
	_make_active_triad_line()

	_grid.remove(Vector2i(4, 4))
	_constellation._on_tower_destroyed(3, Vector2i(4, 4), "BASIC", [Vector2i(4, 4)], "solar")

	assert_int(_spy.count("constellation_deactivated")).is_equal(1)
	var args: Array = (_spy.emissions["constellation_deactivated"] as Array)[0] as Array
	assert_str(args[0] as String).is_equal("triad_line@(2,4)")
	assert_str(args[1] as String).is_equal("tower_destroyed")


# ---------------------------------------------------------------------------
# AC-13: destroying a tower shared by two active instances fires one
# deactivation per instance (reverse-index-driven, not a combined event)
# ---------------------------------------------------------------------------

func test_destroying_shared_member_tower_fires_one_deactivation_per_instance() -> void:
	# Build l_corner@(20,20) and a separate diagonal triad_line@(20,21)
	# sharing member cell (20,21) — matching detection-trigger-activation-
	# lifecycle_test.gd's overlap setup exactly (see that file's comments
	# for the full geometry rationale). The l_corner's own run also
	# produces an intrinsic triad_line@(20,20), which does NOT share the
	# (20,21) tower and must remain active after this test's destruction.
	_place(1, Vector2i(21, 20), "solar")
	_place(2, Vector2i(22, 20), "solar")
	_place(3, Vector2i(21, 22), "solar")
	_place(4, Vector2i(22, 23), "solar")
	_place(5, Vector2i(20, 20), "solar")  # completes triad_line@(20,20)
	_place(6, Vector2i(20, 21), "solar")  # shared cell: completes l_corner@(20,20) + triad_line@(20,21)
	assert_int(_spy.count("constellation_activated")).is_equal(3)

	_grid.remove(Vector2i(20, 21))
	_constellation._on_tower_destroyed(6, Vector2i(20, 21), "BASIC", [Vector2i(20, 21)], "solar")

	assert_int(_spy.count("constellation_deactivated")).is_equal(2)
	var pattern_ids: Array[String] = []
	var reasons: Array[String] = []
	for emission: Array in (_spy.emissions["constellation_deactivated"] as Array):
		pattern_ids.append(emission[0] as String)
		reasons.append(emission[1] as String)
	assert_bool(pattern_ids.has("l_corner@(20,20)")).is_true()
	assert_bool(pattern_ids.has("triad_line@(20,21)")).is_true()
	for reason: String in reasons:
		assert_str(reason).is_equal("tower_destroyed")

	assert_bool(_constellation.is_active("l_corner@(20,20)")).is_false()
	assert_bool(_constellation.is_active("triad_line@(20,21)")).is_false()
	# The l_corner's own intrinsic triad_line does NOT share the destroyed
	# tower — must remain active, proving the reverse index scoped the
	# deactivation correctly rather than tearing down every instance.
	assert_bool(_constellation.is_active("triad_line@(20,20)")).is_true()
