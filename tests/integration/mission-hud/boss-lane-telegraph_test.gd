## Integration tests for Story 006 (TR-hud-000, ADR-0031): Boss-Lane
## Telegraph (Core Rules Group 3b, Rules 11a-11e; Confirmed Signal Contract
## PC-5, boss half). Closes tower.md's OQ-11.
##
## MissionHud IS added to the test's own scene tree (add_child()), matching
## this epic's established convention. GGrid is the real Autoload, seeded
## with a minimal real config so cell_to_world()/get_viewport() resolve
## correctly for the marker/pulse rendering.
##
## wave_preview_available is emitted directly with an explicit boss_spawn_cell
## rather than driven through a real WaveManager mission — this story's scope
## is "MissionHud correctly consumes the payload," not "WaveManager correctly
## computes it" (covered separately in wave_manager_config_loading_test.gd).
extends GdUnitTestSuite

const SPAWN_CELL := Vector2i(0, 0)
const BOSS_CELL := Vector2i(2, 0)


func _make_config() -> GridConfig:
	var cfg := GridConfig.new()
	cfg.cols = 3
	cfg.rows = 1
	cfg.cell_size = 64.0
	cfg.cells = {
		SPAWN_CELL: Grid.CellType.SPAWN,
		Vector2i(1, 0): Grid.CellType.PATH,
		BOSS_CELL: Grid.CellType.GOAL,
	}
	return cfg


var _hud: MissionHud


func before_test() -> void:
	GGrid.initialize(_make_config())
	_hud = MissionHudTestHelper.build_hud()
	add_child(_hud)
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)


func after_test() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null


func _boss_spawn(entity_id: int, hp_max: float = 500.0) -> MonsterSpawnedEvent:
	var payload := MonsterSpawnedEvent.new()
	payload.entity_id = entity_id
	payload.monster_id = &"goblin_warlord_boss"  # real BOSS-tier content
	payload.hp_max = hp_max
	return payload


# ---------------------------------------------------------------------------
# AC-28: caches boss_spawn_cell, hands to the live Planning Cluster
# ---------------------------------------------------------------------------

func test_wave_preview_available_caches_and_renders_boss_telegraph() -> void:
	GEventBus.wave_preview_available.emit(1, [], BOSS_CELL)

	assert_vector(_hud._boss_telegraph_cell).is_equal(BOSS_CELL)
	assert_int(_hud._planning_cluster._boss_telegraph_host.get_child_count()).is_equal(1)


# ---------------------------------------------------------------------------
# AC-29: sentinel -> no marker
# ---------------------------------------------------------------------------

func test_non_boss_wave_sentinel_renders_no_marker() -> void:
	GEventBus.wave_preview_available.emit(1, [], Vector2i(-1, -1))

	assert_vector(_hud._boss_telegraph_cell).is_equal(Vector2i(-1, -1))
	assert_int(_hud._planning_cluster._boss_telegraph_host.get_child_count()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-31/AC-33: WAVE_ACTIVE spawn-confirmation pulse, the Rule 11e regression
# ---------------------------------------------------------------------------

func test_boss_spawn_during_wave_active_fires_pulse_and_clears_cell() -> void:
	GEventBus.wave_preview_available.emit(1, [], BOSS_CELL)
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)
	# WAVE_ACTIVE entry must NOT have cleared the cell (Rule 11e's own bug fix).
	assert_vector(_hud._boss_telegraph_cell).is_equal(BOSS_CELL)

	# Baseline taken after mount, not before: Story 011 gave CombatCluster
	# several permanent children (Chrome, DamageNumberHost, ToastHost,
	# UltimateButton) — the pulse assertion below must be a delta against
	# that baseline, not an absolute child count.
	var baseline: int = _hud._combat_cluster.get_child_count()
	_hud._on_monster_spawned(_boss_spawn(1))

	assert_int(_hud._combat_cluster.get_child_count()).is_equal(baseline + 1)  # pulse fired, owned by outer root
	assert_vector(_hud._boss_telegraph_cell).is_equal(Vector2i(-1, -1))  # cleared after firing


func test_no_pulse_if_boss_spawns_with_no_cached_cell() -> void:
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)
	var baseline: int = _hud._combat_cluster.get_child_count()

	_hud._on_monster_spawned(_boss_spawn(1))

	assert_int(_hud._combat_cluster.get_child_count()).is_equal(baseline)  # no pulse — nothing was cached


# ---------------------------------------------------------------------------
# AC-32: unconditional reset on wave_completed, never on WAVE_ACTIVE entry
# ---------------------------------------------------------------------------

func test_wave_active_entry_never_clears_the_cell() -> void:
	GEventBus.wave_preview_available.emit(1, [], BOSS_CELL)

	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)

	assert_vector(_hud._boss_telegraph_cell).is_equal(BOSS_CELL)  # NOT Vector2i(-1,-1)


func test_wave_completed_unconditionally_resets_even_without_a_boss_spawn() -> void:
	GEventBus.wave_preview_available.emit(1, [], BOSS_CELL)

	GEventBus.wave_completed.emit(1, 0, false)

	assert_vector(_hud._boss_telegraph_cell).is_equal(Vector2i(-1, -1))


# ---------------------------------------------------------------------------
# AC-30: destroyed with the rest of the Planning Cluster at WAVE_ACTIVE
# ---------------------------------------------------------------------------

func test_marker_destroyed_with_planning_cluster_at_wave_active() -> void:
	GEventBus.wave_preview_available.emit(1, [], BOSS_CELL)
	var cluster: PlanningCluster = _hud._planning_cluster

	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)

	assert_bool(cluster._exit_tree_fired).is_true()  # cluster (and its marker) torn down


# ---------------------------------------------------------------------------
# AC-34: double emission overwrites cleanly, no stacking
# ---------------------------------------------------------------------------

func test_second_wave_preview_available_overwrites_not_stacks() -> void:
	GEventBus.wave_preview_available.emit(1, [], SPAWN_CELL)
	GEventBus.wave_preview_available.emit(1, [], BOSS_CELL)

	assert_vector(_hud._boss_telegraph_cell).is_equal(BOSS_CELL)
	assert_int(_hud._planning_cluster._boss_telegraph_host.get_child_count()).is_equal(1)


# ---------------------------------------------------------------------------
# AC-8 hand-off: a freshly-spawned Planning Cluster receives the cached cell
# ---------------------------------------------------------------------------

func test_fresh_planning_cluster_receives_cached_telegraph_cell_at_intermission() -> void:
	GEventBus.wave_preview_available.emit(1, [], BOSS_CELL)
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)

	_hud._on_mission_phase_changed("WAVE_ACTIVE", "INTERMISSION", 0.0)

	assert_int(_hud._planning_cluster._boss_telegraph_host.get_child_count()).is_equal(1)
