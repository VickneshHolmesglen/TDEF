## Unit tests for Story 001 (TR-const-001/TR-const-003, ADR-0022): pattern
## catalogue shape/orientation matching (Core Rule 1) and uniform-tag
## eligibility (Core Rule 2).
##
## Constellation is instantiated directly (Constellation.new(), no
## add_child()) so _ready() never fires — GSavePersistence.register() is
## never called, matching Crafting/DefenseBuilding's established convention
## for scene-instanced systems under test. Grid is injected as a
## GridSpyDouble (tests/helpers/grid_spy_double.gd) directly onto _grid,
## per constellation.md's own Fixture Convention note ("all ACs assume a GUT
## test double for Grid"). tower_placed/tower_removed/tower_destroyed are
## exercised by calling Constellation's handler methods directly with the
## real 6/4/5-param signature (matching event_bus.gd's actual signal shape,
## not ADR-0022's simplified Resource-payload pseudocode) rather than a live
## EventBus emission — same direct-method-call convention
## recipe_discovery_state_machine_test.gd already established for Crafting.
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


func _place(tower_id: int, cell: Vector2i, tag: String) -> void:
	_grid.place(tower_id, cell)
	_constellation._on_tower_placed(TowerPlacedEvent.make(tower_id, cell, "BASIC", Vector2i.ONE, true, tag))


## Counts constellation_activated emissions for one specific pattern_id.
## Needed because larger shapes (l_corner, cross_plus's near-complete arms)
## intrinsically contain a smaller shape's own valid geometry (e.g. any
## l_corner's 3-cell run is ALSO a valid triad_line) — Core Rule 6/AC-26
## requires both to activate independently, so asserting a raw total
## activation count is generally wrong; tests must filter by pattern_id.
func _count_activations_for(pattern_id: String) -> int:
	var count: int = 0
	for emission: Array in (_spy.emissions.get("constellation_activated", []) as Array):
		if (emission[0] as String) == pattern_id:
			count += 1
	return count


# ---------------------------------------------------------------------------
# AC-1/AC-2: triad_line recognized at 0° and 45°
# ---------------------------------------------------------------------------

func test_triad_line_recognized_at_0_degrees_horizontal() -> void:
	_place(1, Vector2i(2, 4), "solar")
	_place(2, Vector2i(3, 4), "solar")
	_place(3, Vector2i(4, 4), "solar")

	assert_int(_spy.count("constellation_activated")).is_equal(1)
	var args: Array = (_spy.emissions["constellation_activated"] as Array)[0] as Array
	assert_str(args[0] as String).is_equal("triad_line@(2,4)")
	assert_that(args[1] as Vector2i).is_equal(Vector2i(2, 4))
	assert_float(args[3] as float).is_equal_approx(0.100, 0.001)


func test_triad_line_recognized_at_45_degrees_diagonal() -> void:
	_place(1, Vector2i(2, 4), "solar")
	_place(2, Vector2i(3, 5), "solar")
	_place(3, Vector2i(4, 6), "solar")

	assert_int(_spy.count("constellation_activated")).is_equal(1)
	var args: Array = (_spy.emissions["constellation_activated"] as Array)[0] as Array
	assert_str(args[0] as String).is_equal("triad_line@(2,4)")


# ---------------------------------------------------------------------------
# AC-3: l_corner recognized in a mirrored orientation (not just base rotations)
# ---------------------------------------------------------------------------

func test_l_corner_recognized_in_mirrored_orientation() -> void:
	_place(1, Vector2i(5, 5), "solar")
	_place(2, Vector2i(5, 6), "solar")
	# The run (5,5),(5,6),(5,7) is itself a valid triad_line — it activates
	# independently the moment it's complete (Core Rule 6/AC-26), BEFORE the
	# 4th tower below turns the same run into an l_corner too. Both are
	# correct, expected activations; this test asserts l_corner's own
	# activation specifically, not the total count.
	_place(3, Vector2i(5, 7), "solar")
	assert_int(_count_activations_for("triad_line@(5,5)")).is_equal(1)

	_place(4, Vector2i(4, 5), "solar")
	assert_int(_count_activations_for("l_corner@(4,5)")).is_equal(1)


## Confirms all 8 l_corner orientations (4 rotations x 2 mirrors) are
## catalogued, not only the 4 base rotations — exercises a rotation not
## covered by the mirrored case above.
func test_l_corner_all_8_orientations_are_catalogued() -> void:
	var catalogue: Dictionary = Constellation._get_catalogue()
	var variants: Array = catalogue["l_corner"]
	assert_int(variants.size()).is_equal(8)


# ---------------------------------------------------------------------------
# AC-4: cross_plus matches only its single valid orientation; near-miss rejected
# ---------------------------------------------------------------------------

func test_cross_plus_near_miss_does_not_activate_until_all_5_cells_present() -> void:
	_place(1, Vector2i(6, 6), "solar")  # center
	_place(2, Vector2i(6, 5), "solar")  # N (min-y neighbor)
	_place(3, Vector2i(7, 6), "solar")  # E
	# N, center, S below form a vertical triad_line the moment all 3 exist —
	# an intrinsic, independently-correct activation (Core Rule 6/AC-26),
	# distinct from cross_plus itself which still needs the W arm.
	_place(4, Vector2i(6, 7), "solar")  # S
	assert_int(_count_activations_for(_expected_cross_plus_pattern_id())).is_equal(0)
	assert_int(_count_activations_for("triad_line@(6,5)")).is_equal(1)

	# 5th tower (W) completes cross_plus.
	_place(5, Vector2i(5, 6), "solar")
	assert_int(_count_activations_for(_expected_cross_plus_pattern_id())).is_equal(1)
	var cross_plus_args: Array = []
	for emission: Array in (_spy.emissions["constellation_activated"] as Array):
		if (emission[0] as String) == _expected_cross_plus_pattern_id():
			cross_plus_args = emission
	assert_float(cross_plus_args[3] as float).is_equal_approx(0.200, 0.001)


## Core Rule 1's canonicalization ("lowest row/y, then lowest column/x")
## applied to this shape's 5 cells {(6,6),(6,5),(7,6),(6,7),(5,6)} yields
## (6,5) as the smallest-y cell — NOT (5,6) as constellation.md's own AC-4
## text states (see this system's class doc comment for the full
## discrepancy note). Computed here rather than hardcoded so this test
## documents the derivation, not just the conclusion.
func _expected_cross_plus_pattern_id() -> String:
	var cells: Array[Vector2i] = [Vector2i(6, 6), Vector2i(6, 5), Vector2i(7, 6), Vector2i(6, 7), Vector2i(5, 6)]
	var anchor: Vector2i = Constellation._lexicographic_min(cells)
	return Constellation._format_pattern_id("cross_plus", anchor)


# ---------------------------------------------------------------------------
# AC-5/AC-6: Eligibility Matching (uniform, non-empty tag)
# ---------------------------------------------------------------------------

func test_mismatched_tags_prevent_activation_despite_complete_geometry() -> void:
	_place(1, Vector2i(2, 4), "solar")
	_place(2, Vector2i(3, 4), "solar")
	_place(3, Vector2i(4, 4), "lunar")

	assert_int(_spy.count("constellation_activated")).is_equal(0)


func test_empty_eligibility_tag_excludes_tower_from_any_pattern() -> void:
	_place(1, Vector2i(2, 4), "solar")
	_place(2, Vector2i(3, 4), "solar")
	_place(3, Vector2i(4, 4), "")

	assert_int(_spy.count("constellation_activated")).is_equal(0)


# ---------------------------------------------------------------------------
# AC-28: Canonicalization prevents duplicate pattern_id regardless of read order
# ---------------------------------------------------------------------------

func test_canonicalization_produces_identical_pattern_id_regardless_of_completing_endpoint() -> void:
	_place(1, Vector2i(4, 4), "solar")
	_place(2, Vector2i(4, 5), "solar")
	_place(3, Vector2i(4, 6), "solar")
	assert_int(_spy.count("constellation_activated")).is_equal(1)
	var first_id: String = (_spy.emissions["constellation_activated"] as Array)[0][0] as String
	assert_str(first_id).is_equal("triad_line@(4,4)")

	# Second, independent run completing the SAME physical line from the
	# other endpoint must derive the identical canonical anchor.
	var constellation2 := Constellation.new()
	var grid2 := GridSpyDouble.new()
	constellation2._grid = grid2
	grid2.place(10, Vector2i(4, 4))
	grid2.place(11, Vector2i(4, 5))
	constellation2._on_tower_placed(TowerPlacedEvent.make(10, Vector2i(4, 4), "BASIC", Vector2i.ONE, true, "solar"))
	constellation2._on_tower_placed(TowerPlacedEvent.make(11, Vector2i(4, 5), "BASIC", Vector2i.ONE, true, "solar"))
	var spy2 := EventBusSpy.new()
	spy2.watch(GEventBus.constellation_activated)
	grid2.place(12, Vector2i(4, 6))
	constellation2._on_tower_placed(TowerPlacedEvent.make(12, Vector2i(4, 6), "BASIC", Vector2i.ONE, true, "solar"))

	assert_int(spy2.count("constellation_activated")).is_equal(1)
	var second_id: String = (spy2.emissions["constellation_activated"] as Array)[0][0] as String
	assert_str(second_id).is_equal("triad_line@(4,4)")
	assert_str(second_id).is_equal(first_id)

	spy2.disconnect_all()
	constellation2.free()
