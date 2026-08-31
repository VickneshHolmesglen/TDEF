## Integration tests for Story 011 (TR-towermast-003, ADR-0029, ADR-0003):
## SaveRestorer round-trip for mastery_time/points_granted_count/
## archetype_by_signature, restore_order=34, and pause-not-reset semantics.
##
## Migrated 2026-09-01 for hero-skill-tree.md/tower-mastery.md's Rule 13
## revision: the old one-shot `unlocked_skills: Dictionary[String, bool]`
## persisted field (and its orphaned-skill_id/_has_skill_catalogue machinery)
## is fully retired — Tower Mastery no longer unlocks a skill directly, so it
## has nothing left to validate against a skill catalogue. It now persists
## `points_granted_count: Dictionary[String, int]` (how many
## skill_tree_point_earned grants have fired per signature) and
## `archetype_by_signature: Dictionary[String, String]` (Formula 4's own
## archetype-derivation cache) instead. The orphaned-catalogue-entry AC-18
## tests this file used to carry no longer apply to this system at all —
## Hero Skill Tree owns all unlock/lock-out state now (see its own
## hero_skill_tree.gd/its future persistence test suite).
##
## TowerMastery is instantiated directly (no add_child()) so _ready() never
## fires — GSavePersistence.register() is never called, avoiding pollution
## of the real Autoload's _registered_systems list. Round-trips call
## get_save_data()/restore_save_data() directly between two local instances,
## matching this project's established persistence-test convention
## (menagerie's own persistence_test.gd).
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


func _place_and_track(tower_id: int, cell: Vector2i) -> void:
	_grid.place(tower_id, cell)
	_tower_mastery._on_tower_placed(TowerPlacedEvent.make(
		tower_id, cell, "physical", Vector2i.ONE, true, "", "found_basic", "weap_frost_bolt", "focus_none", "power_none"
	))
	_tower_mastery._signatures_in_range[_tower_mastery._active_signature_by_tower[tower_id]] = true


# ---------------------------------------------------------------------------
# restore_order=34 (save-persistence.md's authoritative, collision-corrected
# value — not the GDD's original self-proposed 31, which collided with
# Hero Skill Build's already-assigned 31)
# ---------------------------------------------------------------------------

func test_restore_order_is_34() -> void:
	assert_int(TowerMastery.RESTORE_ORDER).is_equal(34)


# ---------------------------------------------------------------------------
# AC-10: persisted mastery_time reads correctly immediately after
# restore_save_data(), with no dependency on a live tower existing yet
# ---------------------------------------------------------------------------

func test_restore_reads_mastery_time_with_no_live_tower_dependency() -> void:
	var data: Dictionary = {"mastery_time": {"S1": 40.0}, "points_granted_count": {}, "archetype_by_signature": {}}

	var restored := TowerMastery.new()
	var ok: bool = restored.restore_save_data(data)

	assert_bool(ok).is_true()
	assert_float(restored.mastery_time["S1"]).is_equal_approx(40.0, 0.0001)
	restored.free()


func test_full_save_load_round_trip_preserves_mastery_time_grant_count_and_archetype() -> void:
	_place_and_track(0, Vector2i(2, 2))
	var signature: String = _tower_mastery._active_signature_by_tower[0]
	_tower_mastery.tick(45.0)  # crosses threshold, grants 1 point

	var data: Dictionary = _tower_mastery.get_save_data()

	var restored := TowerMastery.new()
	var ok: bool = restored.restore_save_data(data)

	assert_bool(ok).is_true()
	assert_float(restored.mastery_time[signature]).is_equal_approx(45.0, 0.0001)
	assert_int(restored.points_granted_count.get(signature, 0)).is_equal(1)
	assert_str(restored._archetype_by_signature.get(signature, "")).is_equal("physical")
	restored.free()


func test_get_save_data_returns_only_primitive_types() -> void:
	_place_and_track(0, Vector2i(2, 2))
	_tower_mastery.tick(10.0)
	var data: Dictionary = _tower_mastery.get_save_data()

	var mastery_data: Dictionary = data["mastery_time"] as Dictionary
	for key: Variant in mastery_data:
		assert_bool(key is String).is_true()
		assert_bool(mastery_data[key] is float).is_true()

	var counts_data: Dictionary = data["points_granted_count"] as Dictionary
	for key: Variant in counts_data:
		assert_bool(key is String).is_true()
		assert_bool(counts_data[key] is int).is_true()

	var archetype_data: Dictionary = data["archetype_by_signature"] as Dictionary
	for key: Variant in archetype_data:
		assert_bool(key is String).is_true()
		assert_bool(archetype_data[key] is String).is_true()


func test_restore_save_data_rejects_malformed_payload() -> void:
	var ok: bool = _tower_mastery.restore_save_data({
		"mastery_time": "not_a_dict", "points_granted_count": {}, "archetype_by_signature": {},
	})
	assert_bool(ok).is_false()


# ---------------------------------------------------------------------------
# AC-13: pause on out-of-range, not reset
# ---------------------------------------------------------------------------

func test_hero_leaving_range_pauses_accrual_without_resetting_mastery_time() -> void:
	_place_and_track(0, Vector2i(2, 2))
	var signature: String = _tower_mastery._active_signature_by_tower[0]
	_tower_mastery.tick(22.0)
	assert_float(_tower_mastery.mastery_time[signature]).is_equal_approx(22.0, 0.0001)

	# Hero moves out of radius — recompute against a cell far from the tower.
	_tower_mastery._on_hero_position_changed(Vector2i(15, 11))
	assert_bool(_tower_mastery._signatures_in_range.get(signature, false)).is_false()

	_tower_mastery.tick(5.0)  # no qualifying signature in range — no accrual
	assert_float(_tower_mastery.mastery_time[signature]).is_equal_approx(22.0, 0.0001)


# ---------------------------------------------------------------------------
# AC-14: pause on tower destruction, same-frame
# ---------------------------------------------------------------------------

func test_sole_live_tower_destroyed_pauses_mastery_time_same_frame() -> void:
	_place_and_track(0, Vector2i(2, 2))
	var signature: String = _tower_mastery._active_signature_by_tower[0]
	_tower_mastery.tick(22.0)

	_tower_mastery._on_hero_position_changed(Vector2i(2, 2))
	_grid.remove(Vector2i(2, 2))
	_tower_mastery._on_tower_destroyed(0, Vector2i(2, 2), "BASIC", [Vector2i(2, 2)], "")

	assert_bool(_tower_mastery._signatures_in_range.get(signature, false)).is_false()
	assert_float(_tower_mastery.mastery_time[signature]).is_equal_approx(22.0, 0.0001)


# ---------------------------------------------------------------------------
# AC-15: accrual resumes automatically from the paused value when a
# matching-signature tower is later placed in range
# ---------------------------------------------------------------------------

func test_accrual_resumes_from_paused_value_when_matching_signature_tower_placed() -> void:
	_place_and_track(0, Vector2i(2, 2))
	var signature: String = _tower_mastery._active_signature_by_tower[0]
	_tower_mastery.tick(22.0)

	_tower_mastery._on_hero_position_changed(Vector2i(2, 2))
	_grid.remove(Vector2i(2, 2))
	_tower_mastery._on_tower_destroyed(0, Vector2i(2, 2), "BASIC", [Vector2i(2, 2)], "")
	assert_float(_tower_mastery.mastery_time[signature]).is_equal_approx(22.0, 0.0001)

	# A later mission places a new tower_id with the identical loadout,
	# within the hero's current cell — accrual resumes automatically.
	_place_and_track(9, Vector2i(2, 2))
	assert_bool(_tower_mastery._signatures_in_range.get(signature, false)).is_true()

	_tower_mastery.tick(3.0)
	assert_float(_tower_mastery.mastery_time[signature]).is_equal_approx(25.0, 0.0001)


# ---------------------------------------------------------------------------
# AC-16/AC-17: DEFEAT does not reset partial progress or revoke a permanent
# grant — mission outcome has no bearing on persisted state at all; the
# only mechanism that clears these structures is reset_to_defaults().
# ---------------------------------------------------------------------------

func test_defeat_outcome_does_not_reset_partial_progress_across_restore() -> void:
	_place_and_track(0, Vector2i(2, 2))
	var signature: String = _tower_mastery._active_signature_by_tower[0]
	_tower_mastery.tick(30.0)  # below the 45s threshold

	# A mission ending in DEFEAT saves current state as-is (no special
	# DEFEAT-triggered clearing exists anywhere in this file).
	var data: Dictionary = _tower_mastery.get_save_data()

	var next_session := TowerMastery.new()
	var ok: bool = next_session.restore_save_data(data)

	assert_bool(ok).is_true()
	assert_float(next_session.mastery_time[signature]).is_equal_approx(30.0, 0.0001)
	next_session.free()


func test_defeat_outcome_does_not_revoke_permanent_grant_count_across_restore() -> void:
	_place_and_track(0, Vector2i(2, 2))
	var signature: String = _tower_mastery._active_signature_by_tower[0]
	_tower_mastery.tick(45.0)  # grants 1 point
	assert_int(_tower_mastery.points_granted_count.get(signature, 0)).is_equal(1)

	var data: Dictionary = _tower_mastery.get_save_data()

	var next_session := TowerMastery.new()
	var ok: bool = next_session.restore_save_data(data)

	assert_bool(ok).is_true()
	assert_int(next_session.points_granted_count.get(signature, 0)).is_equal(1)
	next_session.free()


func test_reset_to_defaults_clears_all_three_persisted_structures() -> void:
	_place_and_track(0, Vector2i(2, 2))
	_tower_mastery.tick(45.0)

	_tower_mastery.reset_to_defaults()

	assert_int(_tower_mastery.mastery_time.size()).is_equal(0)
	assert_int(_tower_mastery.points_granted_count.size()).is_equal(0)
	assert_int(_tower_mastery._archetype_by_signature.size()).is_equal(0)
