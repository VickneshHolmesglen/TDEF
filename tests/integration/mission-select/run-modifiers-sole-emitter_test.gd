## Integration tests for Story 010 (TR-missel-001, ADR-0028): run-modifier
## toggle emission and the sole-emitter correction (Rule 9, AC-9/AC-10/AC-13/AC-14).
##
## MissionSelect is instantiated directly (MissionSelect.new(), no
## add_child()) — real GEventBus connections are exercised (Integration
## story), matching Tarot's established convention for EventBus round-trips.
extends GdUnitTestSuite

var _mission_select: MissionSelect
var _spy: EventBusSpy


func before_test() -> void:
	_mission_select = MissionSelect.new()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.run_modifier_selected)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _mission_select != null and is_instance_valid(_mission_select):
		_mission_select.free()
	_mission_select = null


# ---------------------------------------------------------------------------
# AC-10: live, immediate emission — not batched
# ---------------------------------------------------------------------------

func test_set_run_modifier_emits_immediately() -> void:
	_mission_select.set_run_modifier(&"extend_waves", 2.0)
	assert_int(_spy.count("run_modifier_selected")).is_equal(1)
	var emission: Array = (_spy.emissions["run_modifier_selected"] as Array)[0]
	assert_that(emission[0]).is_equal(&"extend_waves")
	assert_float(emission[1] as float).is_equal_approx(2.0, 0.0001)


func test_set_run_modifier_emits_once_per_toggle_not_batched() -> void:
	_mission_select.set_run_modifier(&"extend_waves", 1.0)
	_mission_select.set_run_modifier(&"extend_waves", 2.0)
	_mission_select.set_run_modifier(&"difficulty_growth_boost", 0.03)
	assert_int(_spy.count("run_modifier_selected")).is_equal(3)


# ---------------------------------------------------------------------------
# AC-14: non-duplication — raw value emitted bit-identical, no clamping
# ---------------------------------------------------------------------------

func test_set_run_modifier_emits_raw_value_unclamped() -> void:
	# extend_waves=2.0 against base_wave_count=6 (the_gap) would request 8,
	# already within Wave Manager's 5-8 safe range — use difficulty_growth_boost
	# at its max (0.05) against base_r=0.20 to prove the emitted value is the
	# raw stepper selection, not a value derived from/clamped to any mission's
	# authored base_r or Wave Manager's own 0.10-0.25 safe range.
	_mission_select.set_run_modifier(&"difficulty_growth_boost", 0.05)
	var emission: Array = (_spy.emissions["run_modifier_selected"] as Array)[0]
	assert_float(emission[1] as float).is_equal_approx(0.05, 0.0001)


# ---------------------------------------------------------------------------
# AC-11/AC-12: Formula 1/2 worked examples — conceptual only, never transmitted
# ---------------------------------------------------------------------------

func test_formula_1_worked_example_requested_wave_count() -> void:
	var base_wave_count: int = 6
	var extend_waves_value: float = 2.0
	var requested_wave_count: int = base_wave_count + int(extend_waves_value)
	assert_int(requested_wave_count).is_equal(8)

	_mission_select.set_run_modifier(&"extend_waves", extend_waves_value)
	var emission: Array = (_spy.emissions["run_modifier_selected"] as Array)[0]
	# Only the raw modifier_value is transmitted — requested_wave_count is
	# never its own field in the payload.
	assert_int(emission.size()).is_equal(2)
	assert_float(emission[1] as float).is_equal_approx(2.0, 0.0001)


func test_formula_2_worked_example_requested_r() -> void:
	var base_r: float = 0.20
	var difficulty_growth_boost_value: float = 0.05
	var requested_r: float = base_r + difficulty_growth_boost_value
	assert_float(requested_r).is_equal_approx(0.25, 0.0001)

	_mission_select.set_run_modifier(&"difficulty_growth_boost", difficulty_growth_boost_value)
	var emission: Array = (_spy.emissions["run_modifier_selected"] as Array)[0]
	assert_int(emission.size()).is_equal(2)
	assert_float(emission[1] as float).is_equal_approx(0.05, 0.0001)


# ---------------------------------------------------------------------------
# AC-13: no composition-altering modifier exists in the catalogue
# ---------------------------------------------------------------------------

func test_run_modifier_catalogue_has_no_composition_altering_entry() -> void:
	assert_int(MissionSelect.RUN_MODIFIER_IDS.size()).is_equal(2)
	assert_array(MissionSelect.RUN_MODIFIER_IDS).contains([&"extend_waves", &"difficulty_growth_boost"])
	for modifier_id: StringName in MissionSelect.RUN_MODIFIER_IDS:
		assert_bool(modifier_id == &"elite_density" or modifier_id == &"monster_mix").is_false()


# ---------------------------------------------------------------------------
# AC-9: sole-emitter correction — no other production code emits this signal
# ---------------------------------------------------------------------------

func test_mission_select_is_the_only_run_modifier_selected_emitter_in_src() -> void:
	# Static confirmation mirroring tarot.md AC-18's "subscriber, never
	# sender" check from the other side: grep src/ for any emit() call on
	# this signal outside mission_select.gd.
	var offending_files: Array[String] = []
	var dir: DirAccess = DirAccess.open("res://src")
	_scan_for_emitters(dir, "res://src", offending_files)
	assert_array(offending_files).is_empty()


func _scan_for_emitters(dir: DirAccess, path: String, offending_files: Array[String]) -> void:
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry in [".", ".."]:
			entry = dir.get_next()
			continue
		var full_path: String = path + "/" + entry
		if dir.current_is_dir():
			_scan_for_emitters(DirAccess.open(full_path), full_path, offending_files)
		elif entry.ends_with(".gd") and entry != "mission_select.gd":
			var content: String = FileAccess.get_file_as_string(full_path)
			if content.find("run_modifier_selected.emit") != -1:
				offending_files.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
