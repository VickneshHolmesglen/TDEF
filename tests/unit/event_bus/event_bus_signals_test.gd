extends GdUnitTestSuite

## Tests that every EventBus signal is declared and has the correct typed signature.
##
## ADR-0001 Validation Criteria:
##   "All 70 signals declared in EventBus.gd compile without type errors."
##   "signal.connect(callable) typed-connection syntax works for all signal shapes
##    (0-param, N typed-param, Resource-param)."
##
## These tests use an inner _LocalBus that mirrors all 76 signal declarations
## so the suite runs independently of the Autoload being registered. The shapes
## tested here must exactly match event_bus.gd — any drift is a contract violation.
##
## Test naming convention: test_[signal_name]_[scenario]_[expected]

# ---------------------------------------------------------------------------
# Inner node that mirrors all 70 signal declarations exactly.
# Keeps tests independent of Autoload registration order.
# ---------------------------------------------------------------------------
class _LocalBus extends Node:
	# Wave Manager
	signal mission_phase_changed(previous_phase: String, new_phase: String, timestamp: float)
	signal wave_started(wave_number: int, total_waves: int, wave_difficulty: float)
	signal wave_completed(wave_number: int, enemies_remaining: int, was_boss_breached: bool)
	signal wave_countdown_warning(seconds_remaining: int)
	signal phase_timer_tick(phase: String, seconds_remaining: float)
	signal monster_spawn_requested(payload: MonsterSpawnRequest)
	signal wave_preview_available(next_wave_number: int, composition: Array, boss_spawn_cell: Vector2i)
	signal wave_stalled(wave_number: int, enemies_remaining: int)
	signal player_ready()
	# Scene Manager
	signal scene_transition_started(target_context: String, mission_id: String)
	signal scene_transition_completed(target_context: String, mission_id: String)
	# Hero System
	signal hero_auto_attacked(payload: HeroAutoAttackEvent)
	signal hero_health_changed(current_health: float, max_health: float)
	signal hero_died()
	signal hero_position_changed(grid_position: Vector2i)
	signal hero_equipment_changed(slot: String, item_id: String)
	signal hero_skill_activated(skill_id: String, target_position: Vector2)
	signal hero_skill_cooldown_updated(skill_slot: int, cooldown_remaining: float, cooldown_max: float)
	signal hero_ultimate_activated()
	signal hero_class_unlocked(archetype: StringName, is_deep: bool)
	# Tower System
	signal tower_placed(payload: TowerPlacedEvent)
	signal tower_removed(tower_id: int, grid_position: Vector2i, archetype: String, constellation_eligibility_tag: String)
	signal tower_destroyed(tower_id: int, grid_position: Vector2i, archetype: String, footprint: Array, constellation_eligibility_tag: String)
	signal tower_damaged(tower_id: int, damage_dealt: float, current_hp: float, max_hp: float)
	signal tower_sell_requested(tower_id: int)
	signal tower_component_equipped(payload: TowerComponentEquippedEvent)
	signal tower_attacked(tower_id: int, target_monster_id: int, damage_amount: float, is_siege: bool, is_armored: bool)
	signal tower_aura_pulse(payload: TowerAuraPulseEvent)
	signal pre_placement_perk_activated(tower_id: int, perk_type: String)
	signal tower_wave_summary(payload: TowerWaveSummary)
	# Monster System
	signal monster_spawned(payload: MonsterSpawnedEvent)
	signal monster_died(payload: MonsterDiedEvent)
	signal monsters_died_batch(payloads: Array[MonsterDiedEvent])
	signal monster_breached(entity_id: int, monster_id: StringName, tier: int)
	signal boss_died(entity_id: int, monster_id: StringName, wave_index: int, cause: String)
	signal boss_hp_changed(entity_id: int, current_hp: float, max_hp: float)
	signal boss_tower_attack_attempted(boss_entity_id: int, target_tower_id: int, base_damage: float, wave_id: int)
	signal monster_cell_entered(entity_id: int, grid_cell: Vector2i, path_step_index: int)
	# Pathfinding System
	signal path_invalidated(affected_cells: Array)
	signal templates_ready(spawn_count: int, build_duration_ms: float)
	signal tower_placement_blocked(blocked_cells: Array, primary_blocking_cell: Vector2i)
	# Damage & Status System
	signal monster_damage_taken(payload: MonsterDamageTaken)
	signal hero_healed(amount: int)
	signal monster_hp_absorbed(entity_id: int, absorbed: int)
	signal hero_damage_taken(amount: int, source_type: int)
	signal hero_incoming_damage()
	# Constellation System
	signal constellation_activated(pattern_id: String, grid_origin: Vector2i, bonus_type: String, bonus_value: float)
	signal constellation_deactivated(pattern_id: String, reason: String)
	signal constellation_rune_discovered(rune_id: String, pattern_id: String)
	# Tarot System
	signal mission_modifier_applied(modifier_type: String, modifier_value: float, source_card_id: String)
	signal tarot_rune_discovered(rune_id: String, card_id: String)
	signal tarot_deck_changed(active_card_count: int)
	# Crafting System
	signal component_crafted(component_id: String, component_type: String, quality_tier: int)
	signal recipe_discovered(recipe_id: String, recipe_category: String)
	# Menagerie System
	signal creature_happiness_changed(creature_id: String, new_happiness: float, quality_bonus: float)
	signal creature_bred(offspring_id: String, species: String)
	signal creature_sacrificed(creature_id: String, target_item_id: String)
	signal creature_moved_to_breeding_pen(creature_id: String)
	signal creature_returned_from_breeding_pen(creature_id: String)
	# Defense Building System
	signal tech_unlocked(tech_id: String, tech_category: String)
	signal sanctuary_structure_built(structure_id: String, structure_type: String)
	# Inventory System
	signal item_added(item_id: String, item_type: String, quantity: int)
	signal item_removed(item_id: String, item_type: String, quantity: int)
	signal equipment_slot_changed(slot: String, new_item_id: String, previous_item_id: String)
	# Resource Economy System
	signal materials_earned(material_type: String, quantity: int, source: String)
	signal materials_spent(material_type: String, quantity: int, destination: String)
	# Tower Mastery System
	signal mastery_progress_updated(tower_id: int, skill_id: String, progress_percent: float)
	signal skill_unlocked(skill_id: String, source_tower_id: int)
	# Equipment Forge System
	signal hero_equipment_crafted(item_id: String, item_type: String, quality_tier: int)
	signal item_rune_imbued(item_id: String, rune_id: String, rune_source: String)
	# Hero Skill Build System
	signal active_skill_equipped(slot_index: int, skill_id: String)
	signal ultimate_skill_changed(ultimate_id: String)
	# Save & Persistence System
	signal game_saved(save_slot: int, timestamp: float)
	signal sanctuary_state_restored(save_slot: int)
	# Mission Select System
	signal mission_selected(mission_id: String)
	signal run_modifier_selected(modifier_id: String, modifier_value: float)
	signal mission_launched(mission_id: String, modifiers: PackedStringArray, difficulty_tier: int)
	# Encyclopedia System
	signal encyclopedia_entry_added(category: String, entry_id: String)

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

var _bus: _LocalBus

func before_test() -> void:
	_bus = _LocalBus.new()
	add_child(_bus)

func after_test() -> void:
	_bus.queue_free()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_monster_died_payload() -> MonsterDiedEvent:
	var p := MonsterDiedEvent.new()
	p.entity_id = 1
	p.monster_id = &"goblin_runner"
	p.tier = 0
	p.drop_table_id = &"standard"
	p.menagerie_attraction_drop_chance = 0.05
	p.world_position = Vector2(128.0, 64.0)
	p.kill_source = "tower"
	p.wave_reward_scalar = 1.2
	return p

# ---------------------------------------------------------------------------
# Signal count — AC-08 proxy (all 70 signals present)
# ---------------------------------------------------------------------------

func test_bus_has_all_70_signals_declared() -> void:
	# Arrange: count declared signals on the inner bus node.
	# Act: retrieve signal list via get_signal_list().
	var signal_list: Array = _bus.get_signal_list()
	# Subtract Node's built-in signals (robust to Godot version changes).
	var node_signal_count: int = Node.new().get_signal_list().size()
	var game_signal_count: int = signal_list.size() - node_signal_count
	# Assert: live catalogue has 78 signals (70 original + 6 added during sprint 1
	# UX/system design + 2 added by S4-01: scene_transition_started/completed).
	assert_int(game_signal_count).is_equal(78)

# ---------------------------------------------------------------------------
# Zero-parameter signal (player_ready, hero_died)
# ---------------------------------------------------------------------------

func test_player_ready_signal_fires_with_no_params() -> void:
	# Arrange
	var state := {"fired": false}
	var cb := func() -> void: state.fired = true
	_bus.player_ready.connect(cb)

	# Act
	_bus.player_ready.emit()

	# Assert
	assert_bool(state.fired).is_true()
	_bus.player_ready.disconnect(cb)

func test_hero_died_signal_fires_with_no_params() -> void:
	# Arrange
	var state := {"fired": false}
	var cb := func() -> void: state.fired = true
	_bus.hero_died.connect(cb)

	# Act
	_bus.hero_died.emit()

	# Assert
	assert_bool(state.fired).is_true()
	_bus.hero_died.disconnect(cb)

# ---------------------------------------------------------------------------
# Typed inline signals (1–4 fields)
# ---------------------------------------------------------------------------

func test_wave_started_delivers_correct_typed_params() -> void:
	# Arrange
	var state := {"wave": -1, "total": -1, "diff": -1.0}
	var cb := func(wave_number: int, total_waves: int, difficulty: float) -> void:
		state.wave = wave_number
		state.total = total_waves
		state.diff = difficulty
	_bus.wave_started.connect(cb)

	# Act
	_bus.wave_started.emit(3, 8, 1.6)

	# Assert
	assert_int(state.wave).is_equal(3)
	assert_int(state.total).is_equal(8)
	assert_float(state.diff).is_equal(1.6)
	_bus.wave_started.disconnect(cb)

func test_monster_breached_delivers_stringname_and_tier() -> void:
	# Arrange
	var state := {"id": &"", "tier": -1}
	var cb := func(entity_id: int, monster_id: StringName, tier: int) -> void:
		state.id = monster_id
		state.tier = tier
	_bus.monster_breached.connect(cb)

	# Act
	_bus.monster_breached.emit(42, &"goblin_runner", 0)

	# Assert
	assert_str(String(state.id)).is_equal("goblin_runner")
	assert_int(state.tier).is_equal(0)
	_bus.monster_breached.disconnect(cb)

func test_tower_placed_delivers_all_five_typed_params() -> void:
	# Arrange
	var state := {"tower_id": -1, "pos": Vector2i(-1, -1), "arch": "", "foot": Vector2i(-1, -1), "scout": false}
	var cb := func(payload: TowerPlacedEvent) -> void:
		state.tower_id = payload.tower_id
		state.pos = payload.grid_position
		state.arch = payload.archetype
		state.foot = payload.footprint
		state.scout = payload.placed_in_scout
	_bus.tower_placed.connect(cb)

	# Act
	_bus.tower_placed.emit(TowerPlacedEvent.make(10, Vector2i(3, 4), "RANGED", Vector2i(2, 2), true, ""))
	# Assert
	assert_int(state.tower_id).is_equal(10)
	assert_that(state.pos).is_equal(Vector2i(3, 4))
	assert_str(state.arch).is_equal("RANGED")
	assert_that(state.foot).is_equal(Vector2i(2, 2))
	assert_bool(state.scout).is_true()
	_bus.tower_placed.disconnect(cb)

func test_mission_phase_changed_delivers_string_and_float() -> void:
	# Arrange
	var state := {"prev": "", "new_phase": "", "ts": -1.0}
	var cb := func(previous_phase: String, new_phase: String, timestamp: float) -> void:
		state.prev = previous_phase
		state.new_phase = new_phase
		state.ts = timestamp
	_bus.mission_phase_changed.connect(cb)

	# Act
	_bus.mission_phase_changed.emit("SCOUT", "WAVE_ACTIVE", 12.5)

	# Assert
	assert_str(state.prev).is_equal("SCOUT")
	assert_str(state.new_phase).is_equal("WAVE_ACTIVE")
	assert_float(state.ts).is_equal(12.5)
	_bus.mission_phase_changed.disconnect(cb)

# ---------------------------------------------------------------------------
# Resource-subclass payload signals (5+ fields — ADR-0001 Rule 3)
# ---------------------------------------------------------------------------

func test_monster_died_delivers_resource_payload() -> void:
	# Arrange
	var state := {"received": null}
	var cb := func(payload: MonsterDiedEvent) -> void:
		state.received = payload
	_bus.monster_died.connect(cb)
	var payload: MonsterDiedEvent = _make_monster_died_payload()

	# Act
	_bus.monster_died.emit(payload)

	# Assert
	var received: MonsterDiedEvent = state.received
	assert_that(received).is_not_null()
	assert_int(received.entity_id).is_equal(1)
	assert_str(received.monster_id).is_equal("goblin_runner")
	assert_int(received.tier).is_equal(0)
	assert_str(received.kill_source).is_equal("tower")
	assert_float(received.wave_reward_scalar).is_equal(1.2)
	_bus.monster_died.disconnect(cb)

func test_monster_spawned_delivers_resource_payload() -> void:
	# Arrange
	var state := {"received": null}
	var cb := func(payload: MonsterSpawnedEvent) -> void:
		state.received = payload
	_bus.monster_spawned.connect(cb)
	var p := MonsterSpawnedEvent.new()
	p.entity_id = 5
	p.monster_id = &"orc_heavy"
	p.wave_index = 2
	p.grid_position = Vector2i(7, 3)
	p.hp_max = 250.0

	# Act
	_bus.monster_spawned.emit(p)

	# Assert
	var received: MonsterSpawnedEvent = state.received
	assert_that(received).is_not_null()
	assert_int(received.entity_id).is_equal(5)
	assert_str(received.monster_id).is_equal("orc_heavy")
	assert_float(received.hp_max).is_equal(250.0)
	_bus.monster_spawned.disconnect(cb)

func test_hero_auto_attacked_delivers_resource_payload() -> void:
	# Arrange
	var state := {"received": null}
	var cb := func(payload: HeroAutoAttackEvent) -> void:
		state.received = payload
	_bus.hero_auto_attacked.connect(cb)
	var p := HeroAutoAttackEvent.new()
	p.base_damage = 55.0
	p.is_crit = true
	p.target_id = 12
	p.crit_multiplier_effective = 2.5
	p.hero_lifesteal_fraction = 0.1
	p.hero_bonus_tier = 1

	# Act
	_bus.hero_auto_attacked.emit(p)

	# Assert
	var received: HeroAutoAttackEvent = state.received
	assert_that(received).is_not_null()
	assert_float(received.base_damage).is_equal(55.0)
	assert_bool(received.is_crit).is_true()
	assert_int(received.hero_bonus_tier).is_equal(1)
	_bus.hero_auto_attacked.disconnect(cb)

func test_monster_damage_taken_delivers_resource_payload() -> void:
	# Arrange
	var state := {"received": null}
	var cb := func(payload: MonsterDamageTaken) -> void:
		state.received = payload
	_bus.monster_damage_taken.connect(cb)
	var p := MonsterDamageTaken.new()
	p.entity_id = 7
	p.amount = 42
	p.source_type = 0
	p.is_crit = false
	p.hero_bonus_tier = 0

	# Act
	_bus.monster_damage_taken.emit(p)

	# Assert
	var received: MonsterDamageTaken = state.received
	assert_that(received).is_not_null()
	assert_int(received.entity_id).is_equal(7)
	assert_int(received.amount).is_equal(42)
	assert_int(received.source_type).is_equal(0)
	_bus.monster_damage_taken.disconnect(cb)

func test_monster_spawn_requested_delivers_resource_payload() -> void:
	# Arrange
	var state := {"received": null}
	var cb := func(payload: MonsterSpawnRequest) -> void:
		state.received = payload
	_bus.monster_spawn_requested.connect(cb)
	var p := MonsterSpawnRequest.new()
	p.monster_id = &"goblin_runner"
	p.spawn_cell = Vector2i(0, 5)
	p.wave_index = 1
	p.difficulty_tier = 0
	p.wave_reward_scalar = 1.1

	# Act
	_bus.monster_spawn_requested.emit(p)

	# Assert
	var received: MonsterSpawnRequest = state.received
	assert_that(received).is_not_null()
	assert_str(received.monster_id).is_equal("goblin_runner")
	assert_float(received.wave_reward_scalar).is_equal(1.1)
	_bus.monster_spawn_requested.disconnect(cb)

func test_tower_aura_pulse_delivers_resource_payload() -> void:
	# Arrange
	var state := {"received": null}
	var cb := func(payload: TowerAuraPulseEvent) -> void:
		state.received = payload
	_bus.tower_aura_pulse.connect(cb)
	var p := TowerAuraPulseEvent.new()
	p.tower_id = 3
	p.aura_effect_type = "slow"
	p.aura_effect_value = 0.3
	p.aura_radius_cells = 2

	# Act
	_bus.tower_aura_pulse.emit(p)

	# Assert
	var received: TowerAuraPulseEvent = state.received
	assert_that(received).is_not_null()
	assert_int(received.tower_id).is_equal(3)
	assert_str(received.aura_effect_type).is_equal("slow")
	assert_int(received.aura_radius_cells).is_equal(2)
	_bus.tower_aura_pulse.disconnect(cb)

func test_tower_wave_summary_delivers_resource_payload() -> void:
	# Arrange
	var state := {"received": null}
	var cb := func(payload: TowerWaveSummary) -> void:
		state.received = payload
	_bus.tower_wave_summary.connect(cb)
	var p := TowerWaveSummary.new()
	p.tower_id = 4
	p.max_hp = 500.0
	p.shots_fired = 30
	p.damage_dealt = 1200.0
	p.idle_ticks = 2
	p.aura_applications_this_wave = 0
	p.scatter_target_cycle = {}

	# Act
	_bus.tower_wave_summary.emit(p)

	# Assert
	var received: TowerWaveSummary = state.received
	assert_that(received).is_not_null()
	assert_int(received.tower_id).is_equal(4)
	assert_int(received.shots_fired).is_equal(30)
	assert_float(received.damage_dealt).is_equal(1200.0)
	_bus.tower_wave_summary.disconnect(cb)

# ---------------------------------------------------------------------------
# No-payload signals compile and emit correctly
# ---------------------------------------------------------------------------

func test_hero_incoming_damage_fires_with_no_params() -> void:
	# Arrange
	var state := {"fired": false}
	var cb := func() -> void: state.fired = true
	_bus.hero_incoming_damage.connect(cb)

	# Act
	_bus.hero_incoming_damage.emit()

	# Assert
	assert_bool(state.fired).is_true()
	_bus.hero_incoming_damage.disconnect(cb)

# ---------------------------------------------------------------------------
# Disconnect enforcement — ADR-0001 Rule 6
# ---------------------------------------------------------------------------

func test_disconnect_stops_delivery_for_resource_payload_signal() -> void:
	# Arrange
	var call_count: int = 0
	var cb := func(_payload: MonsterDiedEvent) -> void: call_count += 1
	_bus.monster_died.connect(cb)
	_bus.monster_died.disconnect(cb)

	# Act
	_bus.monster_died.emit(_make_monster_died_payload())

	# Assert — subscriber must not receive after disconnect
	assert_int(call_count).is_equal(0)

func test_disconnect_stops_delivery_for_typed_param_signal() -> void:
	# Arrange
	var call_count: int = 0
	var cb := func(_w: int, _t: int, _d: float) -> void: call_count += 1
	_bus.wave_started.connect(cb)
	_bus.wave_started.disconnect(cb)

	# Act
	_bus.wave_started.emit(1, 5, 1.0)

	# Assert
	assert_int(call_count).is_equal(0)

# ---------------------------------------------------------------------------
# Multiple subscribers receive independent deliveries
# ---------------------------------------------------------------------------

func test_two_subscribers_both_receive_same_emission() -> void:
	# Arrange
	var state := {"a": 0, "b": 0}
	var cb_a := func(_w: int, _t: int, _d: float) -> void: state.a += 1
	var cb_b := func(_w: int, _t: int, _d: float) -> void: state.b += 1
	_bus.wave_started.connect(cb_a)
	_bus.wave_started.connect(cb_b)

	# Act
	_bus.wave_started.emit(1, 5, 1.0)

	# Assert
	assert_int(state.a).is_equal(1)
	assert_int(state.b).is_equal(1)
	_bus.wave_started.disconnect(cb_a)
	_bus.wave_started.disconnect(cb_b)

# ---------------------------------------------------------------------------
# Batch signal — monsters_died_batch (EC-9)
# ---------------------------------------------------------------------------

func test_monsters_died_batch_delivers_array_of_payloads() -> void:
	# Arrange
	var state := {"batch": [] as Array[MonsterDiedEvent]}
	var cb := func(payloads: Array[MonsterDiedEvent]) -> void:
		state.batch.assign(payloads)
	_bus.monsters_died_batch.connect(cb)
	var batch: Array[MonsterDiedEvent] = []
	for i: int in range(21):
		var p := MonsterDiedEvent.new()
		p.entity_id = i
		p.kill_source = "tower"
		batch.append(p)

	# Act
	_bus.monsters_died_batch.emit(batch)

	# Assert — batch must deliver all 21 items intact
	assert_int(state.batch.size()).is_equal(21)
	assert_int(state.batch[0].entity_id).is_equal(0)
	assert_int(state.batch[20].entity_id).is_equal(20)
	_bus.monsters_died_batch.disconnect(cb)

# ---------------------------------------------------------------------------
# Sanctuary state restored — EC-10 call_deferred timing contract
# ---------------------------------------------------------------------------

func test_sanctuary_state_restored_delivers_save_slot() -> void:
	# Arrange
	var state := {"slot": -1}
	var cb := func(save_slot: int) -> void: state.slot = save_slot
	_bus.sanctuary_state_restored.connect(cb)

	# Act — in production, Save & Persistence uses call_deferred; direct emit here
	# tests payload delivery shape only.
	_bus.sanctuary_state_restored.emit(2)

	# Assert
	assert_int(state.slot).is_equal(2)
	_bus.sanctuary_state_restored.disconnect(cb)
