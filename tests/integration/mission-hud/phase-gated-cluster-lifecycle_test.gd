## Integration tests for Story 002 (TR-hud-000, ADR-0031): Phase-Gated
## Cluster Lifecycle (Core Rules Group 2, Rules 5-8).
##
## Unlike every other test in this project, MissionHud IS added to the test's
## own scene tree (add_child(), auto-freed) — this story's entire subject is
## real node-lifecycle behavior (_ready()/_exit_tree() firing, add_child()/
## remove_child()/queue_free() ordering), which cannot be exercised by
## calling handler methods directly (the established convention elsewhere in
## this project). This is safe here specifically because MissionHud has no
## SavePersistence registration to pollute (unlike Autoload-style systems),
## matching this project's own stated reason for normally avoiding add_child().
extends GdUnitTestSuite

var _hud: MissionHud


func before_test() -> void:
	_hud = MissionHudTestHelper.build_hud()
	add_child(_hud)


func after_test() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null


# ---------------------------------------------------------------------------
# AC-8: fresh instance on SCOUT mount and every INTERMISSION entry
# ---------------------------------------------------------------------------

func test_scout_mount_spawns_planning_cluster() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)

	assert_object(_hud._planning_cluster).is_not_null()
	assert_bool(_hud._planning_cluster is PlanningCluster).is_true()
	assert_object(_hud._planning_cluster.get_parent()).is_equal(_hud._planning_cluster_host)


func test_intermission_entry_spawns_a_fresh_instance_not_the_prior_one() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	var scout_instance: PlanningCluster = _hud._planning_cluster
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)

	_hud._on_mission_phase_changed("WAVE_ACTIVE", "INTERMISSION", 0.0)

	assert_object(_hud._planning_cluster).is_not_null()
	assert_object(_hud._planning_cluster).is_not_equal(scout_instance)


# ---------------------------------------------------------------------------
# AC-9: synchronous remove_child()-then-queue_free() teardown, no double
# subscription window
# ---------------------------------------------------------------------------

func test_wave_active_entry_tears_down_planning_cluster_synchronously() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	var scout_instance: PlanningCluster = _hud._planning_cluster

	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)

	assert_object(_hud._planning_cluster).is_null()
	# remove_child() ran synchronously — _exit_tree() already fired, not
	# deferred to end-of-frame. This is the exact regression the
	# engine-specialist review caught in ADR-0031's own first draft.
	assert_bool(scout_instance._exit_tree_fired).is_true()
	assert_bool(scout_instance.is_inside_tree()).is_false()


func test_two_full_cycles_never_leave_two_instances_live_simultaneously() -> void:
	var seen_instances: Array = []

	for cycle: int in range(2):
		_hud._on_mission_phase_changed("WAVE_ACTIVE" if cycle > 0 else "IDLE", "SCOUT" if cycle == 0 else "INTERMISSION", 0.0)
		var instance: PlanningCluster = _hud._planning_cluster
		assert_bool(seen_instances.has(instance)).is_false()  # never re-seen
		seen_instances.append(instance)

		_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
		_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)
		assert_object(_hud._planning_cluster).is_null()  # exactly zero live during WAVE_ACTIVE
		assert_bool(instance._exit_tree_fired).is_true()

	assert_int(seen_instances.size()).is_equal(2)  # 2 distinct instances across 2 cycles


# ---------------------------------------------------------------------------
# AC-10: PRE_WAVE partial interactivity
# ---------------------------------------------------------------------------

func test_pre_wave_leaves_only_ready_interactive() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	var cluster: PlanningCluster = _hud._planning_cluster

	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)

	assert_bool(cluster._ready_button.disabled).is_false()
	# Story 010 moved Sell out of NonReadyControls entirely (AC-52 requires it
	# to disappear, not just disable, during PRE_WAVE — see sell-button_test.gd
	# for its own dedicated coverage). CellOverlayPlaceholder (the empty
	# scaffold Control) became the real Placement Cursor (2026-08-10, Tower
	# Build Panel) — still a direct NonReadyControls child, still exercises
	# the same group-level disable this test targets.
	assert_int(cluster._placement_cursor.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_bool(cluster._sell_button.visible).is_false()  # AC-52: gone during PRE_WAVE


func test_planning_cluster_does_not_exist_yet_before_scout_mount() -> void:
	assert_object(_hud._planning_cluster).is_null()


# ---------------------------------------------------------------------------
# AC-11: CombatCluster persistence (no destroy/recreate anywhere in this story)
# ---------------------------------------------------------------------------

func test_combat_cluster_is_never_touched_by_phase_transitions() -> void:
	var combat_cluster: Control = _hud._combat_cluster

	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)
	_hud._on_mission_phase_changed("WAVE_ACTIVE", "INTERMISSION", 0.0)

	assert_object(_hud._combat_cluster).is_equal(combat_cluster)  # same instance throughout
	assert_bool(is_instance_valid(combat_cluster)).is_true()
