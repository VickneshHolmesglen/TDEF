## Integration tests for Story 005 (TR-const-001, ADR-0022/ADR-0005/ADR-0020):
## localized Grid query scope and the per-event performance bound.
##
## Constellation is instantiated directly (Constellation.new(), no
## add_child()) so _ready() never fires — GridSpyDouble is injected on
## _grid, matching the other Constellation test files' established
## convention. GridSpyDouble's own `get_all_occupied_cells_call_count`
## tripwire (already built for Stories 001-003, per its own class doc
## comment) is exactly the "GUT test double records every Grid call and
## fails if get_all_occupied_cells() is invoked" seam this story's own
## Implementation Notes call for — no new test double was needed.
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


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _constellation != null and is_instance_valid(_constellation):
		_constellation.free()
	_constellation = null
	_grid = null


func _place(tower_id: int, cell: Vector2i, tag: String = "solar") -> void:
	_grid.place(tower_id, cell)
	_constellation._on_tower_placed(TowerPlacedEvent.make(tower_id, cell, "BASIC", Vector2i.ONE, true, tag))


# ---------------------------------------------------------------------------
# AC-17 (BLOCKING): recheck queries only get_occupied_cells_in_radius, never
# get_all_occupied_cells, across all 3 tower lifecycle events.
# ---------------------------------------------------------------------------

func test_tower_placed_never_calls_get_all_occupied_cells() -> void:
	_place(1, Vector2i(2, 4), "solar")
	_place(2, Vector2i(3, 4), "solar")
	_place(3, Vector2i(4, 4), "solar")  # completes triad_line

	assert_int(_grid.get_all_occupied_cells_call_count).is_equal(0)


func test_tower_removed_never_calls_get_all_occupied_cells() -> void:
	_place(1, Vector2i(2, 4), "solar")
	_place(2, Vector2i(3, 4), "solar")
	_place(3, Vector2i(4, 4), "solar")

	_grid.remove(Vector2i(3, 4))
	_constellation._on_tower_removed(2, Vector2i(3, 4), "BASIC", "solar")

	assert_int(_grid.get_all_occupied_cells_call_count).is_equal(0)


func test_tower_destroyed_never_calls_get_all_occupied_cells() -> void:
	_place(1, Vector2i(2, 4), "solar")
	_place(2, Vector2i(3, 4), "solar")
	_place(3, Vector2i(4, 4), "solar")

	_grid.remove(Vector2i(3, 4))
	_constellation._on_tower_destroyed(2, Vector2i(3, 4), "BASIC", [Vector2i(3, 4)], "solar")

	assert_int(_grid.get_all_occupied_cells_call_count).is_equal(0)


# ---------------------------------------------------------------------------
# AC-25 (ADVISORY): derived radius equals 3 for the current 4-shape
# catalogue, and cells at exactly that distance are boundary-included.
# ---------------------------------------------------------------------------

func test_pattern_search_radius_matches_registry_value_of_3() -> void:
	# design/registry/entities.yaml: constellation_pattern_search_radius = 3
	assert_int(Constellation.PATTERN_SEARCH_RADIUS).is_equal(3)


## quad_line's own max member-to-anchor Chebyshev offset (3) is the
## catalogue's largest — this is the specific case that derived the
## registered radius value. Completing it from its FAR end (so the
## triggering changed_cell sits exactly 3 cells from the anchor) proves the
## radius is boundary-inclusive (dist <= radius, not dist < radius).
func test_boundary_cell_at_exactly_radius_3_completes_quad_line() -> void:
	_place(1, Vector2i(2, 4), "solar")
	_place(2, Vector2i(3, 4), "solar")
	_place(3, Vector2i(4, 4), "solar")
	assert_int(_spy.count("constellation_activated")).is_equal(1)  # intrinsic triad_line

	# Far end, exactly Chebyshev distance 3 from the anchor (2,4).
	_place(4, Vector2i(5, 4), "solar")

	var pattern_ids: Array[String] = []
	for emission: Array in (_spy.emissions["constellation_activated"] as Array):
		pattern_ids.append(emission[0] as String)
	assert_bool(pattern_ids.has("quad_line@(2,4)")).is_true()


# ---------------------------------------------------------------------------
# AC-29 (ADVISORY): geometrically-impossible-to-complete neighborhood
# produces no error and no activation, not an exception.
# ---------------------------------------------------------------------------

func test_isolated_tower_with_no_neighbors_produces_no_error_and_no_activation() -> void:
	_place(1, Vector2i(8, 8), "solar")  # nothing else on the field

	assert_int(_spy.count("constellation_activated")).is_equal(0)
	# Reaching this line without a thrown exception/pushed error already
	# demonstrates the "no error" half of this AC.


# ---------------------------------------------------------------------------
# AC-30 (ADVISORY, informal smoke check — OQ-7 flags the measurement
# methodology itself as unresolved; this is not a scientifically rigorous
# perf harness, just a loose-tolerance regression tripwire against an
# obviously-wrong O(total tower count) implementation creeping in later).
# ---------------------------------------------------------------------------

func _time_single_tower_placed_event(background_tower_count: int) -> int:
	var grid := GridSpyDouble.new()
	var constellation := Constellation.new()
	constellation._grid = grid

	# Background towers placed far outside the search radius (>3 cells from
	# the cell under test) — present on the field, but irrelevant to the
	# recheck's own local neighborhood.
	for i in range(background_tower_count):
		grid.place(100 + i, Vector2i(50 + i, 50))

	var start: int = Time.get_ticks_usec()
	grid.place(1, Vector2i(0, 0))
	constellation._on_tower_placed(TowerPlacedEvent.make(1, Vector2i(0, 0), "BASIC", Vector2i.ONE, true, "solar"))
	var elapsed: int = Time.get_ticks_usec() - start

	constellation.free()
	return elapsed


func test_recheck_cost_does_not_scale_dramatically_with_unrelated_tower_count() -> void:
	var time_with_10: int = _time_single_tower_placed_event(10)
	var time_with_55: int = _time_single_tower_placed_event(55)

	# Generous, explicitly-informal tolerance (not the ±20% band OQ-7
	# proposes ad hoc) — this test exists to catch a genuinely wrong
	# O(total towers) regression, not to enforce a tight perf budget that
	# hasn't been signed off by QA Lead/Technical Director yet.
	assert_int(time_with_55).is_less(maxi(time_with_10 * 10, 5000))
