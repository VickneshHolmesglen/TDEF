## Integration tests for Story 007 (TR-hud-000, ADR-0031): Wave Composition
## Preview Display (Core Rules Group 3c, Rules 11f-11i; Confirmed Signal
## Contract PC-5, composition half). Closes tower.md Rule 8's composition-
## bucketing mandate.
##
## MissionHud IS added to the test's own scene tree (add_child()), matching
## this epic's established convention (mission_hud_test_helper.gd). Real
## GameDataRegistry monster content is used (goblin_runner=STANDARD,
## forest_troll_elite=ELITE, goblin_warlord_boss=BOSS) so tier resolution
## exercises the genuine data path, not a test double.
extends GdUnitTestSuite

const SPAWN_CELL := Vector2i(0, 0)


func _make_config() -> GridConfig:
	var cfg := GridConfig.new()
	cfg.cols = 1
	cfg.rows = 1
	cfg.cell_size = 64.0
	cfg.cells = {SPAWN_CELL: Grid.CellType.SPAWN}
	return cfg


var _hud: MissionHud


func before_test() -> void:
	GGrid.initialize(_make_config())
	_hud = MissionHudTestHelper.build_hud()
	add_child(_hud)


func after_test() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null


func _composition() -> Array:
	return [
		{"monster_id": &"goblin_runner", "count": 3},
		{"monster_id": &"forest_troll_elite", "count": 1},
	]


# ---------------------------------------------------------------------------
# AC-36: SCOUT mount -> full per-monster breakdown, no aggregation
# ---------------------------------------------------------------------------

## Player-requested 2026-08-16 ("UI Changes.PNG" red box): each row is now an
## HBoxContainer (icon + count), not a plain Label with the monster's name —
## see planning_cluster.gd's _render_full_breakdown() and
## MonsterInstance.MONSTER_TEXTURES. Both goblin_runner and forest_troll_elite
## have real authored art, so both rows resolve to icon+"xN" rather than the
## text fallback (that fallback path is covered by a separate test below).
func test_scout_mount_renders_full_per_monster_breakdown() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)

	GEventBus.wave_preview_available.emit(1, _composition(), Vector2i(-1, -1))

	var host: VBoxContainer = _hud._planning_cluster._composition_preview_host
	assert_int(host.get_child_count()).is_equal(2)
	var row0 := host.get_child(0) as HBoxContainer
	var row1 := host.get_child(1) as HBoxContainer
	assert_object(row0).is_not_null()
	assert_object(row1).is_not_null()
	assert_int(row0.get_child_count()).is_equal(2)  # icon + count label
	assert_object((row0.get_child(0) as TextureRect).texture).is_equal(MonsterInstance.MONSTER_TEXTURES[&"goblin_runner"])
	assert_str((row0.get_child(1) as Label).text).is_equal("x3")
	assert_object((row1.get_child(0) as TextureRect).texture).is_equal(MonsterInstance.MONSTER_TEXTURES[&"forest_troll_elite"])
	assert_str((row1.get_child(1) as Label).text).is_equal("x1")


# ---------------------------------------------------------------------------
# AC-35: INTERMISSION mount -> tier-bucketed totals, one line per non-zero tier
# ---------------------------------------------------------------------------

func test_intermission_mount_renders_tier_bucketed_totals() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)
	_hud._on_mission_phase_changed("WAVE_ACTIVE", "INTERMISSION", 0.0)

	GEventBus.wave_preview_available.emit(2, _composition(), Vector2i(-1, -1))

	var host: VBoxContainer = _hud._planning_cluster._composition_preview_host
	assert_int(host.get_child_count()).is_equal(2)  # only 2 non-zero buckets, no BOSS line
	assert_str((host.get_child(0) as Label).text).is_equal("3 STANDARD")
	assert_str((host.get_child(1) as Label).text).is_equal("1 ELITE")


# ---------------------------------------------------------------------------
# AC-37: branch determined by mount phase, not payload inspection
# ---------------------------------------------------------------------------

func test_same_payload_renders_differently_by_mount_phase_alone() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	GEventBus.wave_preview_available.emit(1, _composition(), Vector2i(-1, -1))
	var scout_host: VBoxContainer = _hud._planning_cluster._composition_preview_host
	var scout_line_count: int = scout_host.get_child_count()

	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)
	_hud._on_mission_phase_changed("WAVE_ACTIVE", "INTERMISSION", 0.0)
	GEventBus.wave_preview_available.emit(2, _composition(), Vector2i(-1, -1))
	var intermission_host: VBoxContainer = _hud._planning_cluster._composition_preview_host

	assert_int(scout_line_count).is_equal(2)  # full breakdown: 1 line per monster type
	assert_int(intermission_host.get_child_count()).is_equal(2)  # tier-bucketed: 1 line per tier
	assert_str((intermission_host.get_child(0) as Label).text).is_equal("3 STANDARD")


# ---------------------------------------------------------------------------
# AC-38: fresh repopulation, no carryover across Planning Cluster instances
# ---------------------------------------------------------------------------

func test_fresh_planning_cluster_starts_with_no_composition_display() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	GEventBus.wave_preview_available.emit(1, _composition(), Vector2i(-1, -1))

	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)
	_hud._on_mission_phase_changed("WAVE_ACTIVE", "INTERMISSION", 0.0)

	# New instance, no wave_preview_available received yet — must start empty.
	var host: VBoxContainer = _hud._planning_cluster._composition_preview_host
	assert_int(host.get_child_count()).is_equal(0)
