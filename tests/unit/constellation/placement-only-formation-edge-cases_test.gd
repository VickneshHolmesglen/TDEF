## Unit tests for Story 006 (TR-const-001, ADR-0022): removal-only-breaks
## structural guarantee, tower_destroyed's not-phase-gated deactivation, and
## the N-1-then-remove-and-replace-elsewhere edge case.
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


# ---------------------------------------------------------------------------
# AC-18: removal alone can never simultaneously complete a shape — the
# removal handler only ever deactivates, never invokes the formation path.
# ---------------------------------------------------------------------------

func test_removing_a_blocking_tower_does_not_complete_the_shape() -> void:
	_place(1, Vector2i(2, 4), "solar")
	_place(2, Vector2i(3, 4), "solar")
	_place(3, Vector2i(4, 4), "lunar")  # differently-tagged, blocks triad_line
	assert_int(_spy.count("constellation_activated")).is_equal(0)

	_grid.remove(Vector2i(4, 4))
	_constellation._on_tower_removed(3, Vector2i(4, 4), "BASIC", "lunar")

	assert_int(_spy.count("constellation_activated")).is_equal(0)
	assert_bool(_constellation.is_active("triad_line@(2,4)")).is_false()


# ---------------------------------------------------------------------------
# AC-19: tower_destroyed breaks an active instance during WAVE_ACTIVE,
# regardless of phase — Constellation enforces no phase gating of its own.
# ---------------------------------------------------------------------------

func test_tower_destroyed_breaks_active_instance_during_wave_active() -> void:
	_place(1, Vector2i(3, 5), "solar")
	_place(2, Vector2i(4, 5), "solar")
	_place(3, Vector2i(5, 5), "solar")
	_place(4, Vector2i(6, 5), "solar")  # completes quad_line@(3,5)
	var activated_ids: Array[String] = []
	for emission: Array in (_spy.emissions["constellation_activated"] as Array):
		activated_ids.append(emission[0] as String)
	assert_bool(activated_ids.has("quad_line@(3,5)")).is_true()

	# Current mission phase is WAVE_ACTIVE (Constellation itself never reads
	# or gates on mission phase — this is asserted implicitly by simply not
	# calling any phase-related setter before triggering the destroy event).
	# Tower 2 is also a member of the two intrinsic triad_line sub-instances
	# (Core Rule 6/AC-26 precedent — see the other Constellation test files'
	# own comments), so destroying it deactivates all 3 instances sharing
	# it, not just quad_line@(3,5) alone — filter by pattern_id rather than
	# asserting a raw total, matching this project's established convention.
	_grid.remove(Vector2i(4, 5))
	_constellation._on_tower_destroyed(2, Vector2i(4, 5), "BASIC", [Vector2i(4, 5)], "solar")

	var deactivated_by_id: Dictionary[String, String] = {}
	for emission: Array in (_spy.emissions["constellation_deactivated"] as Array):
		deactivated_by_id[emission[0] as String] = emission[1] as String
	assert_str(deactivated_by_id.get("quad_line@(3,5)", "")).is_equal("tower_destroyed")
	assert_bool(_constellation.is_active("quad_line@(3,5)")).is_false()


# ---------------------------------------------------------------------------
# AC-27: N-1-then-remove-and-replace-elsewhere fires no deactivation —
# nothing was ever active, so _tower_membership has no entry to deactivate.
# ---------------------------------------------------------------------------

func test_n_minus_1_remove_and_replace_elsewhere_fires_no_deactivation() -> void:
	_place(1, Vector2i(2, 4), "solar")
	_place(2, Vector2i(3, 4), "solar")  # only 2 of 3 needed — never ACTIVE
	assert_int(_spy.count("constellation_activated")).is_equal(0)

	_grid.remove(Vector2i(3, 4))
	_constellation._on_tower_removed(2, Vector2i(3, 4), "BASIC", "solar")
	assert_int(_spy.count("constellation_deactivated")).is_equal(0)

	# Re-placement at an unrelated cell triggers only its own fresh,
	# independent, localized recheck — no deactivation anywhere in the
	# sequence, and no activation either (still isolated).
	_place(2, Vector2i(10, 10), "solar")

	assert_int(_spy.count("constellation_deactivated")).is_equal(0)
	assert_int(_spy.count("constellation_activated")).is_equal(0)
