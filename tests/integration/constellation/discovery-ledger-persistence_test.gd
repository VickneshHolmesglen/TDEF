## Integration tests for Story 004 (TR-const-002, ADR-0022): Discovery Ledger
## persistence — first-ever-activation discovery firing, no re-fire on a
## different anchor or a break/reform cycle of the identical instance, and
## the SaveRestorer round-trip at restore_order=24.
##
## Constellation is instantiated directly (Constellation.new(), no
## add_child()) so _ready() never fires — GSavePersistence.register() is
## never called, matching this project's persistence-test convention
## (menagerie/persistence_test.gd, tower-mastery's own cross-mission test).
## GridSpyDouble is injected on _grid; tower_placed/tower_removed/
## tower_destroyed are exercised via direct handler calls with
## TowerPlacedEvent.make(), matching the other 3 Constellation test files'
## established convention.
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
	_spy.watch(GEventBus.constellation_rune_discovered)
	_spy.watch(GEventBus.constellation_deactivated)


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
# AC-14: first-ever activation of a shape_id fires both events
# ---------------------------------------------------------------------------

func test_first_ever_activation_fires_both_activated_and_discovered() -> void:
	assert_bool(_constellation.is_discovered("triad_line")).is_false()

	_place(1, Vector2i(2, 4), "solar")
	_place(2, Vector2i(3, 4), "solar")
	_place(3, Vector2i(4, 4), "solar")

	assert_int(_spy.count("constellation_activated")).is_equal(1)
	assert_int(_spy.count("constellation_rune_discovered")).is_equal(1)

	var activated_args: Array = (_spy.emissions["constellation_activated"] as Array)[0] as Array
	assert_str(activated_args[0] as String).is_equal("triad_line@(2,4)")

	var discovered_args: Array = (_spy.emissions["constellation_rune_discovered"] as Array)[0] as Array
	assert_str(discovered_args[0] as String).is_equal("rune_triad_line")
	assert_str(discovered_args[1] as String).is_equal("triad_line@(2,4)")

	assert_bool(_constellation.is_discovered("triad_line")).is_true()


# ---------------------------------------------------------------------------
# AC-15: re-forming the same shape at a different anchor does not re-fire
# discovery — only a distinct instance's own constellation_activated fires.
# ---------------------------------------------------------------------------

func test_different_anchor_activation_does_not_refire_discovery() -> void:
	# Discovery Ledger already has triad_line = DISCOVERED, from a prior
	# activation at a different anchor now broken.
	_constellation._discovery_ledger["triad_line"] = true

	_place(10, Vector2i(9, 9), "solar")
	_place(11, Vector2i(10, 9), "solar")
	_place(12, Vector2i(11, 9), "solar")

	assert_int(_spy.count("constellation_activated")).is_equal(1)
	var activated_args: Array = (_spy.emissions["constellation_activated"] as Array)[0] as Array
	assert_str(activated_args[0] as String).is_equal("triad_line@(9,9)")

	assert_int(_spy.count("constellation_rune_discovered")).is_equal(0)


# ---------------------------------------------------------------------------
# AC-16: breaking and reforming the identical instance re-fires
# constellation_activated (bonus reapplies) but never constellation_rune_discovered.
# ---------------------------------------------------------------------------

func test_break_and_reform_identical_instance_does_not_refire_discovery() -> void:
	_place(1, Vector2i(2, 4), "solar")
	_place(2, Vector2i(3, 4), "solar")
	_place(3, Vector2i(4, 4), "solar")
	assert_int(_spy.count("constellation_activated")).is_equal(1)
	assert_int(_spy.count("constellation_rune_discovered")).is_equal(1)

	# Break: destroy the middle tower.
	_grid.remove(Vector2i(3, 4))
	_constellation._on_tower_destroyed(2, Vector2i(3, 4), "BASIC", [Vector2i(3, 4)], "solar")
	assert_int(_spy.count("constellation_deactivated")).is_equal(1)
	assert_bool(_constellation.is_active("triad_line@(2,4)")).is_false()

	# Reform: re-occupy the same 3 cells (same anchor).
	_place(2, Vector2i(3, 4), "solar")

	assert_int(_spy.count("constellation_activated")).is_equal(2)
	var second_activation: Array = (_spy.emissions["constellation_activated"] as Array)[1] as Array
	assert_str(second_activation[0] as String).is_equal("triad_line@(2,4)")

	# Discovery never re-fires — still exactly the one emission from the
	# original activation.
	assert_int(_spy.count("constellation_rune_discovered")).is_equal(1)


# ---------------------------------------------------------------------------
# SaveRestorer round-trip at restore_order=24
# ---------------------------------------------------------------------------

func test_restore_order_is_24() -> void:
	assert_int(Constellation.RESTORE_ORDER).is_equal(24)


func test_save_load_round_trip_preserves_discovery_ledger() -> void:
	_place(1, Vector2i(2, 4), "solar")
	_place(2, Vector2i(3, 4), "solar")
	_place(3, Vector2i(4, 4), "solar")
	assert_bool(_constellation.is_discovered("triad_line")).is_true()

	var data: Dictionary = _constellation.get_save_data()

	var restored := Constellation.new()
	var ok: bool = restored.restore_save_data(data)

	assert_bool(ok).is_true()
	assert_bool(restored.is_discovered("triad_line")).is_true()
	assert_bool(restored.is_discovered("cross_plus")).is_false()
	restored.free()


func test_get_save_data_returns_only_primitive_types() -> void:
	_place(1, Vector2i(2, 4), "solar")
	_place(2, Vector2i(3, 4), "solar")
	_place(3, Vector2i(4, 4), "solar")
	var data: Dictionary = _constellation.get_save_data()

	var ledger: Dictionary = data["discovery_ledger"] as Dictionary
	for key: Variant in ledger:
		assert_bool(key is String).is_true()
		assert_bool(ledger[key] is bool).is_true()


func test_restore_save_data_rejects_malformed_payload() -> void:
	var ok: bool = _constellation.restore_save_data({"discovery_ledger": "not_a_dict"})
	assert_bool(ok).is_false()


func test_reset_to_defaults_clears_discovery_ledger() -> void:
	_place(1, Vector2i(2, 4), "solar")
	_place(2, Vector2i(3, 4), "solar")
	_place(3, Vector2i(4, 4), "solar")
	assert_bool(_constellation.is_discovered("triad_line")).is_true()

	_constellation.reset_to_defaults()

	assert_bool(_constellation.is_discovered("triad_line")).is_false()


func test_discovery_is_terminal_even_after_shape_fully_breaks() -> void:
	_place(1, Vector2i(2, 4), "solar")
	_place(2, Vector2i(3, 4), "solar")
	_place(3, Vector2i(4, 4), "solar")
	assert_bool(_constellation.is_discovered("triad_line")).is_true()

	_grid.remove(Vector2i(2, 4))
	_grid.remove(Vector2i(3, 4))
	_grid.remove(Vector2i(4, 4))
	_constellation._on_tower_destroyed(1, Vector2i(2, 4), "BASIC", [Vector2i(2, 4)], "solar")

	assert_bool(_constellation.is_discovered("triad_line")).is_true()
