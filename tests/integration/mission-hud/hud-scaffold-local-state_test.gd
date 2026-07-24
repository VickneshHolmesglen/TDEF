## Integration tests for Story 001 (TR-hud-000, ADR-0031): HUD Scaffold &
## Local State Model (Core Rules Group 1, Rules 1-4).
##
## MissionHud IS added to the test's own scene tree (add_child(), matching
## Story 002/003's established convention) — required since Story 002 added
## @onready-resolved CombatCluster/PlanningClusterHost children that
## _on_mission_phase_changed()'s SCOUT-mount branch now depends on; those
## only resolve once _ready() actually fires, which requires a live tree.
## This test file originally used bare MissionHud.new() (no add_child()) —
## updated after Story 002 shipped and a full regression caught 3 of these
## tests crashing on a null @onready reference (real regression, not test
## flakiness — see Story 001's Completion Notes addendum). Handler methods
## are still called directly rather than emitted through GEventBus, since
## this story's own subscriptions aren't the subject under test here.
##
## GGameDataRegistry is the real Autoload, exercising real content
## (res://assets/data/monsters/) for the BOSS-tier resolution path.
extends GdUnitTestSuite

var _hud: MissionHud


func before_test() -> void:
	_hud = MissionHudTestHelper.build_hud()
	add_child(_hud)


func after_test() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null


func _spawn(entity_id: int, monster_id: StringName, hp_max: float = 100.0) -> MonsterSpawnedEvent:
	var payload := MonsterSpawnedEvent.new()
	payload.entity_id = entity_id
	payload.monster_id = monster_id
	payload.hp_max = hp_max
	return payload


func _find_boss_monster_id() -> StringName:
	for resource: MonsterResource in GGameDataRegistry.get_all_monster_resources().values():
		if resource.tier == 2:
			return resource.monster_id
	return &""


func _find_non_boss_monster_id() -> StringName:
	for resource: MonsterResource in GGameDataRegistry.get_all_monster_resources().values():
		if resource.tier != 2:
			return resource.monster_id
	return &""


# ---------------------------------------------------------------------------
# AC-2/AC-3: mount/unmount
# ---------------------------------------------------------------------------

func test_mount_resets_all_local_state_and_becomes_visible() -> void:
	_hud._breach_count = 3
	_hud._enemies_alive_display = 5
	_hud._active_tower_hp_bars[1] = Vector2(10, 20)
	_hud._boss_state = {"entity_id": 1, "display_name": "x", "current_hp": 1.0, "max_hp": 1.0}
	_hud._boss_telegraph_cell = Vector2i(2, 2)
	_hud.visible = false

	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)

	assert_int(_hud._breach_count).is_equal(0)
	assert_int(_hud._enemies_alive_display).is_equal(0)
	assert_bool(_hud._active_tower_hp_bars.is_empty()).is_true()
	assert_bool(_hud._boss_state.is_empty()).is_true()
	assert_vector(_hud._boss_telegraph_cell).is_equal(Vector2i(-1, -1))
	assert_bool(_hud.visible).is_true()


func test_unmount_hides_hud_without_freeing_node() -> void:
	_hud.visible = true

	_hud._on_mission_phase_changed("WAVE_ACTIVE", "MISSION_COMPLETE", 0.0)

	assert_bool(_hud.visible).is_false()
	assert_bool(is_instance_valid(_hud)).is_true()  # node persists — not freed


## Story 012 (AC-68) changed DEFEAT's own unmount behavior: the whole
## CanvasLayer now deliberately stays visible so the Retry button (housed
## here pragmatically — see mission_hud.gd's own doc comment, no real
## Outcome/Defeat screen exists in this codebase yet) can actually be shown.
## _combat_cluster (the rest of what Mission HUD owns) still hides — see
## defeat-retry-button_test.gd for this story's own dedicated coverage.
func test_defeat_hides_combat_cluster_but_keeps_hud_visible_for_retry() -> void:
	_hud.visible = true

	_hud._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 0.0)

	assert_bool(_hud.visible).is_true()
	assert_bool(_hud._combat_cluster.visible).is_false()


func test_intermission_entry_clears_tower_hp_bars_only() -> void:
	_hud._active_tower_hp_bars[1] = Vector2(10, 20)
	_hud._breach_count = 2  # must survive — Rule 4: never resets mid-mission

	_hud._on_mission_phase_changed("WAVE_ACTIVE", "INTERMISSION", 0.0)

	assert_bool(_hud._active_tower_hp_bars.is_empty()).is_true()
	assert_int(_hud._breach_count).is_equal(2)


# ---------------------------------------------------------------------------
# AC-4: enemy count clamp
# ---------------------------------------------------------------------------

func test_enemies_alive_display_increments_on_spawn_decrements_on_death() -> void:
	var monster_id: StringName = _find_non_boss_monster_id()
	_hud._on_monster_spawned(_spawn(1, monster_id))
	_hud._on_monster_spawned(_spawn(2, monster_id))
	assert_int(_hud._enemies_alive_display).is_equal(2)

	_hud._on_monster_died(MonsterDiedEvent.new())
	assert_int(_hud._enemies_alive_display).is_equal(1)


func test_enemies_alive_display_never_goes_negative() -> void:
	_hud._on_monster_died(MonsterDiedEvent.new())
	assert_int(_hud._enemies_alive_display).is_equal(0)

	var batch: Array[MonsterDiedEvent] = [MonsterDiedEvent.new(), MonsterDiedEvent.new()]
	_hud._on_monsters_died_batch(batch)
	assert_int(_hud._enemies_alive_display).is_equal(0)


# ---------------------------------------------------------------------------
# AC-5: breach counter
# ---------------------------------------------------------------------------

func test_breach_increments_count_and_decrements_enemy_display() -> void:
	var monster_id: StringName = _find_non_boss_monster_id()
	_hud._on_monster_spawned(_spawn(1, monster_id))

	_hud._on_monster_breached(1, monster_id, 0)

	assert_int(_hud._breach_count).is_equal(1)
	assert_int(_hud._enemies_alive_display).is_equal(0)


func test_breach_count_survives_intermission_clear() -> void:
	_hud._on_monster_breached(1, &"x", 0)
	_hud._on_mission_phase_changed("WAVE_ACTIVE", "INTERMISSION", 0.0)
	assert_int(_hud._breach_count).is_equal(1)


# ---------------------------------------------------------------------------
# AC-6: tower HP bars
# ---------------------------------------------------------------------------

func test_tower_damaged_sets_hp_bar_from_payload_fields() -> void:
	_hud._on_tower_damaged(7, 5.0, 40.0, 100.0)

	assert_vector(_hud._active_tower_hp_bars[7]).is_equal(Vector2(40.0, 100.0))


# ---------------------------------------------------------------------------
# AC-7: boss-state single-slot guard
# ---------------------------------------------------------------------------

func test_boss_tier_spawn_sets_boss_state() -> void:
	var boss_id: StringName = _find_boss_monster_id()
	assert_bool(boss_id != &"").is_true()  # real BOSS-tier content must exist

	_hud._on_monster_spawned(_spawn(10, boss_id, 500.0))

	assert_bool(_hud._boss_state.is_empty()).is_false()
	assert_int(_hud._boss_state["entity_id"] as int).is_equal(10)
	assert_float(_hud._boss_state["current_hp"] as float).is_equal(500.0)
	assert_float(_hud._boss_state["max_hp"] as float).is_equal(500.0)


func test_second_concurrent_boss_spawn_discarded_not_overwritten() -> void:
	var boss_id: StringName = _find_boss_monster_id()
	_hud._on_monster_spawned(_spawn(10, boss_id, 500.0))

	_hud._on_monster_spawned(_spawn(11, boss_id, 500.0))

	assert_int(_hud._boss_state["entity_id"] as int).is_equal(10)  # unchanged


func test_non_boss_spawn_does_not_set_boss_state() -> void:
	var monster_id: StringName = _find_non_boss_monster_id()
	_hud._on_monster_spawned(_spawn(1, monster_id))
	assert_bool(_hud._boss_state.is_empty()).is_true()


func test_boss_died_clears_matching_entity_id() -> void:
	var boss_id: StringName = _find_boss_monster_id()
	_hud._on_monster_spawned(_spawn(10, boss_id, 500.0))

	_hud._on_boss_died(10, boss_id, 1, "hero")

	assert_bool(_hud._boss_state.is_empty()).is_true()


func test_boss_died_for_non_matching_entity_id_is_stray_discarded() -> void:
	var boss_id: StringName = _find_boss_monster_id()
	_hud._on_monster_spawned(_spawn(10, boss_id, 500.0))

	_hud._on_boss_died(999, boss_id, 1, "hero")

	assert_bool(_hud._boss_state.is_empty()).is_false()  # still tracking entity_id=10


func test_boss_died_while_already_null_is_idempotent_no_op() -> void:
	_hud._on_boss_died(5, &"x", 1, "hero")  # no crash, no state change
	assert_bool(_hud._boss_state.is_empty()).is_true()


# ---------------------------------------------------------------------------
# _terminal latch (Edge Cases)
# ---------------------------------------------------------------------------

func test_terminal_latch_suppresses_further_mutation_handlers() -> void:
	_hud._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 0.0)
	assert_bool(_hud._terminal).is_true()

	var monster_id: StringName = _find_non_boss_monster_id()
	_hud._on_monster_spawned(_spawn(1, monster_id))
	_hud._on_monster_breached(1, monster_id, 0)
	_hud._on_tower_damaged(1, 1.0, 1.0, 10.0)

	assert_int(_hud._enemies_alive_display).is_equal(0)
	assert_int(_hud._breach_count).is_equal(0)
	assert_bool(_hud._active_tower_hp_bars.is_empty()).is_true()
