## Integration tests for Story 011 (TR-towermast-003, ADR-0029, ADR-0003):
## SaveRestorer round-trip for mastery_time/unlocked_skills, restore_order=34,
## pause-not-reset semantics, and orphaned-skill_id handling on restore.
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
		tower_id, cell, "BASIC", Vector2i.ONE, true, "", "found_basic", "weap_frost_bolt", "focus_none", "power_none"
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
	var data: Dictionary = {"mastery_time": {"S1": 40.0}, "unlocked_skills": {}}

	var restored := TowerMastery.new()
	var ok: bool = restored.restore_save_data(data)

	assert_bool(ok).is_true()
	assert_float(restored.mastery_time["S1"]).is_equal_approx(40.0, 0.0001)
	restored.free()


func test_full_save_load_round_trip_preserves_mastery_time_and_unlocked_skills() -> void:
	_place_and_track(0, Vector2i(2, 2))
	var signature: String = _tower_mastery._active_signature_by_tower[0]
	_tower_mastery.tick(45.0)  # crosses threshold, unlocks

	var data: Dictionary = _tower_mastery.get_save_data()

	var restored := TowerMastery.new()
	var ok: bool = restored.restore_save_data(data)

	assert_bool(ok).is_true()
	assert_float(restored.mastery_time[signature]).is_equal_approx(45.0, 0.0001)
	assert_bool(restored._unlocked_signatures.get(signature, false)).is_true()
	restored.free()


func test_get_save_data_returns_only_primitive_types() -> void:
	_place_and_track(0, Vector2i(2, 2))
	_tower_mastery.tick(10.0)
	var data: Dictionary = _tower_mastery.get_save_data()

	var mastery_data: Dictionary = data["mastery_time"] as Dictionary
	for key: Variant in mastery_data:
		assert_bool(key is String).is_true()
		assert_bool(mastery_data[key] is float).is_true()


func test_restore_save_data_rejects_malformed_payload() -> void:
	var ok: bool = _tower_mastery.restore_save_data({"mastery_time": "not_a_dict", "unlocked_skills": {}})
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
# unlock — mission outcome has no bearing on persisted state at all; the
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


func test_defeat_outcome_does_not_revoke_permanent_unlock_across_restore() -> void:
	_place_and_track(0, Vector2i(2, 2))
	var signature: String = _tower_mastery._active_signature_by_tower[0]
	_tower_mastery.tick(45.0)  # unlocks
	assert_bool(_tower_mastery._unlocked_signatures.get(signature, false)).is_true()

	var data: Dictionary = _tower_mastery.get_save_data()

	var next_session := TowerMastery.new()
	var ok: bool = next_session.restore_save_data(data)

	assert_bool(ok).is_true()
	assert_bool(next_session._unlocked_signatures.get(signature, false)).is_true()
	next_session.free()


func test_reset_to_defaults_clears_both_persisted_structures() -> void:
	_place_and_track(0, Vector2i(2, 2))
	_tower_mastery.tick(45.0)

	_tower_mastery.reset_to_defaults()

	assert_int(_tower_mastery.mastery_time.size()).is_equal(0)
	assert_int(_tower_mastery._unlocked_signatures.size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-18: orphaned unlocked_skills entry — retained, marked UNKNOWN, excluded
# from UI (via is_skill_unknown()), warning logged, load never blocks.
# ---------------------------------------------------------------------------

func test_orphaned_skill_id_is_retained_and_marked_unknown_when_catalogue_configured() -> void:
	var restored := TowerMastery.new()
	restored._has_skill_catalogue = true
	restored._known_skill_ids = {"frost_bolt_skill_a": true}

	var data: Dictionary = {
		"mastery_time": {},
		"unlocked_skills": {"legacy_skill_id": true, "frost_bolt_skill_a": true},
	}
	var ok: bool = restored.restore_save_data(data)

	assert_bool(ok).is_true()
	# Never discarded — still present and still true.
	assert_bool(restored._unlocked_signatures.get("legacy_skill_id", false)).is_true()
	assert_bool(restored.is_skill_unknown("legacy_skill_id")).is_true()
	# The known entry is not flagged.
	assert_bool(restored.is_skill_unknown("frost_bolt_skill_a")).is_false()
	restored.free()


func test_orphan_check_is_a_noop_when_no_catalogue_is_configured() -> void:
	# Production default: _has_skill_catalogue is false (no real catalogue
	# exists yet) — nothing is ever flagged unknown, matching this file's
	# own documented deferred-content precedent.
	var restored := TowerMastery.new()
	var data: Dictionary = {"mastery_time": {}, "unlocked_skills": {"legacy_skill_id": true}}

	var ok: bool = restored.restore_save_data(data)

	assert_bool(ok).is_true()
	assert_bool(restored._unlocked_signatures.get("legacy_skill_id", false)).is_true()
	assert_bool(restored.is_skill_unknown("legacy_skill_id")).is_false()
	restored.free()
