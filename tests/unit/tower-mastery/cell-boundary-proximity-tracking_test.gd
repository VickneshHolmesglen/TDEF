## Unit tests for Story 009 (TR-towermast-001, ADR-0029/ADR-0005/ADR-0020):
## _signatures_in_range recompute wiring — cell-boundary crossing via
## hero_position_changed, immediate recompute on the 4 tower lifecycle
## events, the out-of-bounds guard, and the SCOUT accrual halt.
##
## TowerMastery is instantiated directly (TowerMastery.new(), no add_child())
## so _ready() never fires — handler methods are called directly with a
## GridSpyDouble injected on _grid, matching Story 007/008's own established
## convention for this system's tests.
extends GdUnitTestSuite

var _tower_mastery: TowerMastery
var _grid: GridSpyDouble


func before_test() -> void:
	_tower_mastery = TowerMastery.new()
	_grid = GridSpyDouble.new()
	_tower_mastery._grid = _grid


func after_test() -> void:
	if _tower_mastery != null and is_instance_valid(_tower_mastery):
		_tower_mastery.free()
	_tower_mastery = null
	_grid = null


func _place_with_loadout(tower_id: int, cell: Vector2i, foundation_id: String = "found_basic",
		weapon_id: String = "weap_basic", focus_id: String = "focus_none", power_id: String = "power_none") -> void:
	_grid.place(tower_id, cell)
	_tower_mastery._on_tower_placed(TowerPlacedEvent.make(
		tower_id, cell, "BASIC", Vector2i.ONE, true, "", foundation_id, weapon_id, focus_id, power_id
	))


# ---------------------------------------------------------------------------
# AC-24: SCOUT phase halts accrual same-frame; hero_position_changed during
# SCOUT never changes mastery_time
# ---------------------------------------------------------------------------

func test_scout_phase_halts_accrual_same_frame() -> void:
	_place_with_loadout(1, Vector2i(2, 2))
	var signature: String = _tower_mastery._active_signature_by_tower[1]

	_tower_mastery._on_mission_phase_changed("", "WAVE_ACTIVE", 0.0)
	_tower_mastery._on_hero_position_changed(Vector2i(2, 2))
	_tower_mastery.tick(5.0)
	assert_float(_tower_mastery.mastery_time.get(signature, 0.0)).is_equal_approx(5.0, 0.0001)

	_tower_mastery._on_mission_phase_changed("WAVE_ACTIVE", "SCOUT", 0.0)
	_tower_mastery.tick(5.0)
	assert_float(_tower_mastery.mastery_time.get(signature, 0.0)).is_equal_approx(5.0, 0.0001)


func test_hero_position_changed_during_scout_never_changes_mastery_time() -> void:
	_place_with_loadout(1, Vector2i(2, 2))
	var signature: String = _tower_mastery._active_signature_by_tower[1]

	_tower_mastery._on_mission_phase_changed("", "SCOUT", 0.0)
	_tower_mastery._on_hero_position_changed(Vector2i(2, 2))
	_tower_mastery.tick(10.0)

	assert_float(_tower_mastery.mastery_time.get(signature, 0.0)).is_equal_approx(0.0, 0.0001)


# ---------------------------------------------------------------------------
# AC-25: out-of-bounds hero cell skips the recompute entirely, retains the
# previous cache, no crash, and never calls Grid with the invalid cell
# ---------------------------------------------------------------------------

func test_out_of_bounds_cell_skips_recompute_and_retains_previous_cache() -> void:
	_place_with_loadout(1, Vector2i(2, 2))
	_tower_mastery._on_hero_position_changed(Vector2i(2, 2))
	var cached_before: Dictionary = _tower_mastery._signatures_in_range.duplicate()

	# GridSpyDouble.is_in_bounds() is permissive for 0<=x<16, 0<=y<12.
	_tower_mastery._on_hero_position_changed(Vector2i(-1, 5))

	assert_dict(_tower_mastery._signatures_in_range).is_equal(cached_before)


func test_out_of_bounds_cell_does_not_update_last_known_hero_cell() -> void:
	_place_with_loadout(1, Vector2i(2, 2))
	_tower_mastery._on_hero_position_changed(Vector2i(2, 2))

	_tower_mastery._on_hero_position_changed(Vector2i(999, 999))  # out of bounds

	# A subsequent tower lifecycle event must still recompute from the last
	# VALID cell (2,2), not the rejected out-of-bounds one.
	_place_with_loadout(2, Vector2i(2, 3))
	var sig_2: String = _tower_mastery._active_signature_by_tower[2]
	assert_bool(_tower_mastery._signatures_in_range.get(sig_2, false)).is_true()


# ---------------------------------------------------------------------------
# Immediate recompute on tower lifecycle events (Implementation Notes) —
# a tower appearing/vanishing/swapping under a stationary hero must be
# reflected the same frame, no grace period until the next hero movement.
# ---------------------------------------------------------------------------

func test_tower_placed_under_stationary_hero_is_reflected_immediately() -> void:
	_tower_mastery._on_hero_position_changed(Vector2i(4, 4))
	assert_int(_tower_mastery._signatures_in_range.size()).is_equal(0)

	_place_with_loadout(1, Vector2i(4, 4))
	var signature: String = _tower_mastery._active_signature_by_tower[1]

	assert_bool(_tower_mastery._signatures_in_range.get(signature, false)).is_true()


func test_tower_removed_under_stationary_hero_is_reflected_immediately() -> void:
	_place_with_loadout(1, Vector2i(4, 4))
	var signature: String = _tower_mastery._active_signature_by_tower[1]
	_tower_mastery._on_hero_position_changed(Vector2i(4, 4))
	assert_bool(_tower_mastery._signatures_in_range.get(signature, false)).is_true()

	_grid.remove(Vector2i(4, 4))
	_tower_mastery._on_tower_removed(1, Vector2i(4, 4), "BASIC", "")

	assert_bool(_tower_mastery._active_signature_by_tower.has(1)).is_false()
	assert_bool(_tower_mastery._signatures_in_range.get(signature, false)).is_false()


func test_tower_destroyed_under_stationary_hero_is_reflected_immediately() -> void:
	_place_with_loadout(1, Vector2i(4, 4))
	var signature: String = _tower_mastery._active_signature_by_tower[1]
	_tower_mastery._on_hero_position_changed(Vector2i(4, 4))
	assert_bool(_tower_mastery._signatures_in_range.get(signature, false)).is_true()

	_grid.remove(Vector2i(4, 4))
	_tower_mastery._on_tower_destroyed(1, Vector2i(4, 4), "BASIC", [Vector2i(4, 4)], "")

	assert_bool(_tower_mastery._active_signature_by_tower.has(1)).is_false()
	assert_bool(_tower_mastery._signatures_in_range.get(signature, false)).is_false()


func test_tower_component_equipped_under_stationary_hero_is_reflected_immediately() -> void:
	_place_with_loadout(1, Vector2i(4, 4), "found_basic", "weap_frost_bolt", "focus_none", "power_none")
	var old_signature: String = _tower_mastery._active_signature_by_tower[1]
	_tower_mastery._on_hero_position_changed(Vector2i(4, 4))
	assert_bool(_tower_mastery._signatures_in_range.get(old_signature, false)).is_true()

	var payload := TowerComponentEquippedEvent.new()
	payload.tower_id = 1
	payload.slot = "weapon"
	payload.component_id = "weap_flame_burst"
	payload.foundation_component_id = "found_basic"
	payload.weapon_component_id = "weap_flame_burst"
	payload.focus_component_id = "focus_none"
	payload.power_component_id = "power_none"
	_tower_mastery._on_tower_component_equipped(payload)

	var new_signature: String = TowerMastery.compute_build_signature(
		"found_basic", "weap_flame_burst", "focus_none", "power_none"
	)
	assert_bool(_tower_mastery._signatures_in_range.get(old_signature, false)).is_false()
	assert_bool(_tower_mastery._signatures_in_range.get(new_signature, false)).is_true()


func test_tower_lifecycle_event_before_any_hero_position_does_not_crash() -> void:
	# No hero_position_changed has fired yet — _has_hero_cell is false, so
	# the lifecycle handlers' recompute must be a no-op, not a crash.
	_place_with_loadout(1, Vector2i(4, 4))
	assert_int(_tower_mastery._signatures_in_range.size()).is_equal(0)


# ---------------------------------------------------------------------------
# tower_mastery_proximity_changed (2026-08-13, Story 013 Audio Requirement d):
# discrete edge-detection diff, fires only on an actual entered/exited
# transition, never on a recompute that leaves membership unchanged.
# ---------------------------------------------------------------------------

func test_entering_range_emits_proximity_changed_true() -> void:
	var spy := EventBusSpy.new()
	spy.watch(GEventBus.tower_mastery_proximity_changed)

	_place_with_loadout(1, Vector2i(4, 4))
	var signature: String = _tower_mastery._active_signature_by_tower[1]
	_tower_mastery._on_hero_position_changed(Vector2i(4, 4))

	assert_int(spy.count("tower_mastery_proximity_changed")).is_equal(1)
	var args: Array = (spy.emissions["tower_mastery_proximity_changed"] as Array)[0] as Array
	assert_str(args[0] as String).is_equal(signature)
	assert_bool(args[1] as bool).is_true()
	spy.disconnect_all()


func test_exiting_range_emits_proximity_changed_false() -> void:
	_place_with_loadout(1, Vector2i(4, 4))
	var signature: String = _tower_mastery._active_signature_by_tower[1]
	_tower_mastery._on_hero_position_changed(Vector2i(4, 4))

	var spy := EventBusSpy.new()
	spy.watch(GEventBus.tower_mastery_proximity_changed)

	_tower_mastery._on_hero_position_changed(Vector2i(10, 10))  # walks out of radius

	assert_int(spy.count("tower_mastery_proximity_changed")).is_equal(1)
	var args: Array = (spy.emissions["tower_mastery_proximity_changed"] as Array)[0] as Array
	assert_str(args[0] as String).is_equal(signature)
	assert_bool(args[1] as bool).is_false()
	spy.disconnect_all()


func test_recompute_with_unchanged_membership_does_not_reemit() -> void:
	_place_with_loadout(1, Vector2i(4, 4))
	_tower_mastery._on_hero_position_changed(Vector2i(4, 4))

	var spy := EventBusSpy.new()
	spy.watch(GEventBus.tower_mastery_proximity_changed)

	# Same cell again -- membership doesn't change, must stay silent (no
	# per-recompute spam, only real transitions).
	_tower_mastery._on_hero_position_changed(Vector2i(4, 4))

	assert_int(spy.count("tower_mastery_proximity_changed")).is_equal(0)
	spy.disconnect_all()


func test_tower_removed_under_stationary_hero_emits_proximity_changed_false() -> void:
	_place_with_loadout(1, Vector2i(4, 4))
	var signature: String = _tower_mastery._active_signature_by_tower[1]
	_tower_mastery._on_hero_position_changed(Vector2i(4, 4))

	var spy := EventBusSpy.new()
	spy.watch(GEventBus.tower_mastery_proximity_changed)

	_grid.remove(Vector2i(4, 4))
	_tower_mastery._on_tower_removed(1, Vector2i(4, 4), "BASIC", "")

	assert_int(spy.count("tower_mastery_proximity_changed")).is_equal(1)
	var args: Array = (spy.emissions["tower_mastery_proximity_changed"] as Array)[0] as Array
	assert_str(args[0] as String).is_equal(signature)
	assert_bool(args[1] as bool).is_false()
	spy.disconnect_all()
