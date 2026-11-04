extends GdUnitTestSuite

## Wave report (design/quick-specs/wave-report-2026-11-05.md): post-wave
## per-tower breakdown fed by tower_wave_summary. Handlers are called directly
## so no other autoload subscriber reacts.

var _report: WaveReport


func before_test() -> void:
	_report = WaveReport.new()
	add_child(_report)


func after_test() -> void:
	if is_instance_valid(_report):
		remove_child(_report)
		_report.free()


func _summary(tower_id: int, damage: float, shots: int, idle: int, pulses: int = 0) -> TowerWaveSummary:
	var s := TowerWaveSummary.new()
	s.tower_id = tower_id
	s.damage_dealt = damage
	s.shots_fired = shots
	s.idle_ticks = idle
	s.aura_applications_this_wave = pulses
	return s


func _place(tower_id: int, weapon: String, archetype: String) -> void:
	var p := TowerPlacedEvent.new()
	p.tower_id = tower_id
	p.weapon_component_id = weapon
	p.archetype = archetype
	_report._on_tower_placed(p)


func _death(killer: int) -> MonsterDiedEvent:
	var d := MonsterDiedEvent.new()
	d.killer_tower_id = killer
	return d


func test_wave_report_rows_sort_by_damage_with_share_and_idle() -> void:
	# Arrange
	var summaries: Array[TowerWaveSummary] = [_summary(1, 100.0, 10, 10), _summary(2, 300.0, 30, 0)]
	var towers: Dictionary = {1: {&"name": "Arrow", &"archetype": "ranged", &"rank": 0}}
	# Act
	var rows: Array[Dictionary] = WaveReport.build_rows(summaries, towers, {2: 4})
	# Assert
	assert_int(int(rows[0][&"tower_id"])).is_equal(2)
	assert_float(float(rows[0][&"share"])).is_equal_approx(0.75, 0.0001)
	assert_int(int(rows[0][&"kills"])).is_equal(4)
	assert_str(String(rows[0][&"name"])).is_equal("#2")
	assert_float(float(rows[1][&"idle_ratio"])).is_equal_approx(0.5, 0.0001)
	assert_str(String(rows[1][&"name"])).is_equal("Arrow")


func test_wave_report_support_tower_reports_pulses() -> void:
	var summaries: Array[TowerWaveSummary] = [_summary(5, 0.0, 0, 0, 7)]
	var rows: Array[Dictionary] = WaveReport.build_rows(summaries, {}, {})
	assert_bool(bool(rows[0][&"support"])).is_true()
	assert_int(int(rows[0][&"pulses"])).is_equal(7)
	assert_float(float(rows[0][&"share"])).is_equal(0.0)


func test_wave_report_weapon_display_name() -> void:
	assert_str(WaveReport.weapon_display_name("weap_frost_bolt")).is_equal("Frost Bolt")
	assert_str(WaveReport.weapon_display_name("")).is_equal("?")


func test_wave_report_counts_single_and_batched_kills_and_resets_per_wave() -> void:
	# Arrange
	_place(3, "weap_arrow", "ranged")
	_report._on_wave_started(1, 5, 1.0)
	# Act
	_report._on_monster_died(_death(3))
	var batch: Array[MonsterDiedEvent] = [_death(3), _death(-1), _death(3)]
	_report._on_monsters_died_batch(batch)
	# Assert
	assert_int(int(_report._kills.get(3, 0))).is_equal(3)
	_report._on_wave_started(2, 5, 1.0)
	assert_bool(_report._kills.is_empty()).is_true()


func test_wave_report_shows_after_wave_and_hides_on_next_wave_and_outcome() -> void:
	# Arrange
	_place(1, "weap_arrow", "ranged")
	_report._on_wave_started(2, 5, 1.0)
	_report._on_tower_wave_summary(_summary(1, 50.0, 5, 1))
	# Act
	_report._on_wave_completed(2, 0, false)
	await await_idle_frame()
	# Assert
	assert_bool(_report.visible).is_true()
	assert_str(_report._title.text).contains("2")
	_report._on_wave_started(3, 5, 1.0)
	assert_bool(_report.visible).is_false()
	_report.show_report()
	_report._on_mission_phase_changed("INTERMISSION", "MISSION_COMPLETE", 0.0)
	assert_bool(_report.visible).is_false()


func test_wave_report_caps_rows_and_hides_when_empty() -> void:
	# Arrange
	for i: int in 10:
		_report._on_tower_wave_summary(_summary(i, float(i + 1), 1, 0))
	# Act
	_report.show_report()
	await await_idle_frame()
	# Assert: 8 rows + "+2 more".
	assert_int(_report._rows.get_child_count()).is_equal(WaveReport.MAX_ROWS + 1)
	_report._summaries.clear()
	_report.show_report()
	assert_bool(_report.visible).is_false()


func test_wave_report_rank_up_is_recorded() -> void:
	_place(4, "weap_cannon", "physical")
	_report._on_tower_ranked_up(4, 2)
	assert_int(int(_report._towers[4][&"rank"])).is_equal(2)


func test_wave_report_prefers_blueprint_display_name() -> void:
	var p := TowerPlacedEvent.new()
	p.tower_id = 9
	p.weapon_component_id = "weap_arcane_t3"
	p.display_name = "Arcane Lance"
	_report._on_tower_placed(p)
	assert_str(String(_report._towers[9][&"name"])).is_equal("Arcane Lance")
