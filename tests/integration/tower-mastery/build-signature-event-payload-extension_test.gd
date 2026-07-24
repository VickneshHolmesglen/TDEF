## Integration tests for Story 008 (TR-towermast-002/003, ADR-0029): build_signature
## derivation from the tower_placed/tower_component_equipped Resource payloads.
##
## TowerMastery is instantiated directly (TowerMastery.new(), no add_child()) so
## _ready() never fires — GEventBus subscriptions are never wired live. Handler
## methods (_on_tower_placed, _on_tower_component_equipped) are called directly
## with real payload objects instead, matching Constellation's own established
## direct-method-call convention (pattern-catalogue-eligibility-matching_test.gd)
## rather than a live EventBus emission — this story's scope is Formula 4
## derivation and the two handlers' bookkeeping, not EventBus wiring itself.
extends GdUnitTestSuite

var _tower_mastery: TowerMastery
var _grid: GridSpyDouble


func before_test() -> void:
	_tower_mastery = TowerMastery.new()
	_grid = GridSpyDouble.new()
	_tower_mastery._grid = _grid
	_tower_mastery._current_phase = "WAVE_ACTIVE"


func after_test() -> void:
	if _tower_mastery != null and is_instance_valid(_tower_mastery):
		_tower_mastery.free()
	_tower_mastery = null
	_grid = null


func _place_with_loadout(tower_id: int, cell: Vector2i, foundation_id: String, weapon_id: String,
		focus_id: String, power_id: String) -> void:
	_grid.place(tower_id, cell)
	_tower_mastery._on_tower_placed(TowerPlacedEvent.make(
		tower_id, cell, "BASIC", Vector2i.ONE, true, "", foundation_id, weapon_id, focus_id, power_id
	))


func _equip(tower_id: int, slot: String, component_id: String, foundation_id: String,
		weapon_id: String, focus_id: String, power_id: String) -> void:
	var payload := TowerComponentEquippedEvent.new()
	payload.tower_id = tower_id
	payload.slot = slot
	payload.component_id = component_id
	payload.foundation_component_id = foundation_id
	payload.weapon_component_id = weapon_id
	payload.focus_component_id = focus_id
	payload.power_component_id = power_id
	_tower_mastery._on_tower_component_equipped(payload)


# ---------------------------------------------------------------------------
# AC-11: tower_placed populates _active_signature_by_tower from the payload
# ---------------------------------------------------------------------------

func test_tower_placed_populates_active_signature_by_tower_per_formula_4() -> void:
	_place_with_loadout(1, Vector2i(2, 2), "found_basic", "weap_frost_bolt", "focus_none", "power_none")

	var expected: String = TowerMastery.compute_build_signature(
		"found_basic", "weap_frost_bolt", "focus_none", "power_none"
	)
	assert_str(_tower_mastery._active_signature_by_tower[1]).is_equal(expected)


# ---------------------------------------------------------------------------
# AC-12: component swap recomputes build_signature; old signature's
# mastery_time is left untouched (no retroactive transfer)
# ---------------------------------------------------------------------------

func test_component_swap_recomputes_signature_and_leaves_old_mastery_time_untouched() -> void:
	_place_with_loadout(1, Vector2i(2, 2), "found_basic", "weap_frost_bolt", "focus_none", "power_none")
	var old_signature: String = _tower_mastery._active_signature_by_tower[1]
	_tower_mastery.mastery_time[old_signature] = 22.0

	_equip(1, "weapon", "weap_flame_burst", "found_basic", "weap_flame_burst", "focus_none", "power_none")

	var new_signature: String = TowerMastery.compute_build_signature(
		"found_basic", "weap_flame_burst", "focus_none", "power_none"
	)
	assert_str(_tower_mastery._active_signature_by_tower[1]).is_equal(new_signature)
	assert_str(new_signature).is_not_equal(old_signature)
	assert_float(_tower_mastery.mastery_time.get(old_signature, 0.0)).is_equal_approx(22.0, 0.0001)
	assert_float(_tower_mastery.mastery_time.get(new_signature, 0.0)).is_equal_approx(0.0, 0.0001)


# ---------------------------------------------------------------------------
# AC-26: signature derived from the full 4-slot loadout, not archetype alone —
# a power-slot-only difference must still produce a distinct signature
# ---------------------------------------------------------------------------

func test_power_slot_only_difference_produces_distinct_signatures() -> void:
	_place_with_loadout(1, Vector2i(2, 2), "found_basic", "weap_frost_bolt", "focus_none", "power_none")
	_place_with_loadout(2, Vector2i(5, 5), "found_basic", "weap_frost_bolt", "focus_none", "power_amp")

	var sig_1: String = _tower_mastery._active_signature_by_tower[1]
	var sig_2: String = _tower_mastery._active_signature_by_tower[2]
	assert_str(sig_1).is_not_equal(sig_2)

	_tower_mastery.mastery_time[sig_1] = 5.0
	_tower_mastery.mastery_time[sig_2] = 9.0
	assert_float(_tower_mastery.mastery_time[sig_1]).is_equal_approx(5.0, 0.0001)
	assert_float(_tower_mastery.mastery_time[sig_2]).is_equal_approx(9.0, 0.0001)


# ---------------------------------------------------------------------------
# AC-07: cross-mission build_signature persistence via a recycled tower_id —
# mastery_time is keyed by signature, so a later tower_placed for the same
# tower_id/signature (simulating a new mission recycling the id) does not
# reset previously-accrued progress.
# ---------------------------------------------------------------------------

func test_recycled_tower_id_with_matching_signature_preserves_accrued_mastery_time() -> void:
	_place_with_loadout(0, Vector2i(2, 2), "found_basic", "weap_frost_bolt", "focus_none", "power_none")
	var signature: String = _tower_mastery._active_signature_by_tower[0]
	_tower_mastery.mastery_time[signature] = 18.0

	# Mission 2: tower_id 0 recycled, same loadout/signature re-placed.
	_place_with_loadout(0, Vector2i(3, 3), "found_basic", "weap_frost_bolt", "focus_none", "power_none")

	assert_str(_tower_mastery._active_signature_by_tower[0]).is_equal(signature)
	assert_float(_tower_mastery.mastery_time[signature]).is_equal_approx(18.0, 0.0001)

	_tower_mastery._signatures_in_range[signature] = true
	_tower_mastery.tick(2.0)
	assert_float(_tower_mastery.mastery_time[signature]).is_equal_approx(20.0, 0.0001)


# ---------------------------------------------------------------------------
# AC-08: destroyed-and-replaced identical build resumes progress, does not
# restart — a physically new tower_id sharing the destroyed tower's
# signature must resume from where the destroyed tower left off.
# ---------------------------------------------------------------------------

func test_new_tower_id_with_identical_signature_resumes_instead_of_restarting() -> void:
	_place_with_loadout(3, Vector2i(2, 2), "found_basic", "weap_frost_bolt", "focus_none", "power_none")
	var signature: String = _tower_mastery._active_signature_by_tower[3]
	_tower_mastery.mastery_time[signature] = 22.0
	_tower_mastery._active_signature_by_tower.erase(3)  # tower 3 destroyed

	# A later, physically different tower_id with the identical loadout.
	_place_with_loadout(9, Vector2i(6, 6), "found_basic", "weap_frost_bolt", "focus_none", "power_none")

	assert_str(_tower_mastery._active_signature_by_tower[9]).is_equal(signature)
	assert_float(_tower_mastery.mastery_time[signature]).is_equal_approx(22.0, 0.0001)


# ---------------------------------------------------------------------------
# AC-09: two same-mission towers sharing a build_signature accrue once per
# tick, not doubled — _signatures_in_range is keyed by signature, so being in
# range of both simultaneously still yields exactly one dictionary entry.
# ---------------------------------------------------------------------------

func test_two_towers_sharing_signature_accrue_exactly_once_per_tick() -> void:
	_place_with_loadout(3, Vector2i(4, 4), "found_basic", "weap_frost_bolt", "focus_none", "power_none")
	_place_with_loadout(7, Vector2i(5, 5), "found_basic", "weap_frost_bolt", "focus_none", "power_none")

	var signature: String = _tower_mastery._active_signature_by_tower[3]
	assert_str(_tower_mastery._active_signature_by_tower[7]).is_equal(signature)

	# Hero at (4,5): Chebyshev distance to both (4,4) and (5,5) is 1 — in
	# range of both simultaneously.
	_tower_mastery._recompute_signatures_in_range(Vector2i(4, 5))
	assert_int(_tower_mastery._signatures_in_range.size()).is_equal(1)

	_tower_mastery.tick(5.0)
	assert_float(_tower_mastery.mastery_time[signature]).is_equal_approx(5.0, 0.0001)

	# Only one of the two towers now in range — still accrues correctly.
	_tower_mastery._recompute_signatures_in_range(Vector2i(4, 4))
	_tower_mastery.tick(3.0)
	assert_float(_tower_mastery.mastery_time[signature]).is_equal_approx(8.0, 0.0001)
