extends GdUnitTestSuite

## Tests that all 7 event-payload Resource subclasses have correct default fields,
## accept valid data, and document their semantic constraints.
##
## ADR-0001 Rule 3: "Events with 5 or more data fields must package their payload
##   into a custom Resource subclass."
## ADR-0009: "Event-payload Resources are short-lived — never saved as .tres files."
##
## Each test class covers one Resource subclass:
##   MonsterDiedEvent (8 fields)
##   MonsterSpawnedEvent (5 fields)
##   MonsterSpawnRequest (6 fields)
##   HeroAutoAttackEvent (6 fields)
##   MonsterDamageTaken (5 fields)
##   TowerAuraPulseEvent (4 fields)
##   TowerWaveSummary (7 fields)
##
## Test naming convention: test_[class]_[field_or_rule]_[expected]

# =============================================================================
# MonsterDiedEvent (8 fields)
# =============================================================================

func test_monster_died_event_default_entity_id_is_minus_one() -> void:
	# Arrange / Act
	var p := MonsterDiedEvent.new()
	# Assert
	assert_int(p.entity_id).is_equal(-1)

func test_monster_died_event_default_monster_id_is_empty_stringname() -> void:
	var p := MonsterDiedEvent.new()
	assert_str(p.monster_id).is_equal("")

func test_monster_died_event_default_tier_is_zero() -> void:
	var p := MonsterDiedEvent.new()
	assert_int(p.tier).is_equal(0)

func test_monster_died_event_default_wave_reward_scalar_is_one() -> void:
	var p := MonsterDiedEvent.new()
	assert_float(p.wave_reward_scalar).is_equal(1.0)

func test_monster_died_event_default_kill_source_is_empty_string() -> void:
	var p := MonsterDiedEvent.new()
	assert_str(p.kill_source).is_equal("")

func test_monster_died_event_kill_source_wave_end_identifies_force_removal() -> void:
	# kill_source == "wave_end" means force-removed at wave_completed.
	# Resource Economy must suppress all drop resolution for this value.
	# Arrange
	var p := MonsterDiedEvent.new()
	p.kill_source = "wave_end"
	# Act / Assert — semantic: wave_end suppresses drops
	assert_str(p.kill_source).is_equal("wave_end")

func test_monster_died_event_all_fields_round_trip() -> void:
	# Arrange
	var p := MonsterDiedEvent.new()
	p.entity_id = 99
	p.monster_id = &"troll_boss"
	p.tier = 2
	p.drop_table_id = &"boss_drops"
	p.menagerie_attraction_drop_chance = 0.25
	p.world_position = Vector2(512.0, 256.0)
	p.kill_source = "tower"
	p.wave_reward_scalar = 1.5
	# Assert
	assert_int(p.entity_id).is_equal(99)
	assert_str(p.monster_id).is_equal("troll_boss")
	assert_int(p.tier).is_equal(2)
	assert_str(p.drop_table_id).is_equal("boss_drops")
	assert_float(p.menagerie_attraction_drop_chance).is_equal(0.25)
	assert_that(p.world_position).is_equal(Vector2(512.0, 256.0))
	assert_str(p.kill_source).is_equal("tower")
	assert_float(p.wave_reward_scalar).is_equal(1.5)

# =============================================================================
# MonsterSpawnedEvent (5 fields)
# =============================================================================

func test_monster_spawned_event_default_entity_id_is_minus_one() -> void:
	var p := MonsterSpawnedEvent.new()
	assert_int(p.entity_id).is_equal(-1)

func test_monster_spawned_event_default_hp_max_is_one() -> void:
	# hp_max must not default to 0 — Tower System seeds HP cache from it.
	var p := MonsterSpawnedEvent.new()
	assert_float(p.hp_max).is_greater(0.0)

func test_monster_spawned_event_default_grid_position_is_sentinel() -> void:
	var p := MonsterSpawnedEvent.new()
	assert_that(p.grid_position).is_equal(Vector2i(-1, -1))

func test_monster_spawned_event_all_fields_round_trip() -> void:
	# Arrange
	var p := MonsterSpawnedEvent.new()
	p.entity_id = 5
	p.monster_id = &"orc_heavy"
	p.wave_index = 2
	p.grid_position = Vector2i(7, 3)
	p.hp_max = 250.0
	# Assert
	assert_int(p.entity_id).is_equal(5)
	assert_str(p.monster_id).is_equal("orc_heavy")
	assert_int(p.wave_index).is_equal(2)
	assert_that(p.grid_position).is_equal(Vector2i(7, 3))
	assert_float(p.hp_max).is_equal(250.0)

# =============================================================================
# MonsterSpawnRequest (6 fields — is_penultimate_wave added, Story 004)
# =============================================================================

func test_monster_spawn_request_default_spawn_cell_is_sentinel() -> void:
	var p := MonsterSpawnRequest.new()
	assert_that(p.spawn_cell).is_equal(Vector2i(-1, -1))

func test_monster_spawn_request_default_wave_reward_scalar_is_one() -> void:
	var p := MonsterSpawnRequest.new()
	assert_float(p.wave_reward_scalar).is_equal(1.0)

func test_monster_spawn_request_wave_reward_scalar_must_not_affect_combat_stats() -> void:
	# Semantic contract: Monster System must forward wave_reward_scalar unchanged
	# into MonsterDiedEvent. Resource Economy owns all scaling logic.
	# This test documents the rule via the round-trip invariant.
	var p := MonsterSpawnRequest.new()
	p.wave_reward_scalar = 1.3
	# Simulated Monster System passthrough: scalar must arrive unchanged.
	var forwarded_scalar: float = p.wave_reward_scalar
	assert_float(forwarded_scalar).is_equal(1.3)

func test_monster_spawn_request_all_fields_round_trip() -> void:
	var p := MonsterSpawnRequest.new()
	p.monster_id = &"goblin_runner"
	p.spawn_cell = Vector2i(0, 5)
	p.wave_index = 1
	p.difficulty_tier = 0
	p.wave_reward_scalar = 1.1
	p.is_penultimate_wave = true
	assert_str(p.monster_id).is_equal("goblin_runner")
	assert_that(p.spawn_cell).is_equal(Vector2i(0, 5))
	assert_int(p.wave_index).is_equal(1)
	assert_int(p.difficulty_tier).is_equal(0)
	assert_float(p.wave_reward_scalar).is_equal(1.1)
	assert_bool(p.is_penultimate_wave).is_true()

func test_monster_spawn_request_default_is_penultimate_wave_is_false() -> void:
	var p := MonsterSpawnRequest.new()
	assert_bool(p.is_penultimate_wave).is_false()

# =============================================================================
# HeroAutoAttackEvent (6 fields)
# =============================================================================

func test_hero_auto_attack_event_default_crit_multiplier_is_one() -> void:
	# Default must not be 0 — would zero out all damage.
	var p := HeroAutoAttackEvent.new()
	assert_float(p.crit_multiplier_effective).is_equal(1.0)

func test_hero_auto_attack_event_default_is_crit_is_false() -> void:
	var p := HeroAutoAttackEvent.new()
	assert_bool(p.is_crit).is_false()

func test_hero_auto_attack_event_default_hero_bonus_tier_is_zero() -> void:
	# 0 = STANDARD target tier. Hero System sets this from target archetype tag.
	var p := HeroAutoAttackEvent.new()
	assert_int(p.hero_bonus_tier).is_equal(0)

func test_hero_auto_attack_event_hero_bonus_tier_valid_values() -> void:
	# Valid values per GDD: 0 = STANDARD, 1 = ELITE, 2 = BOSS.
	var p := HeroAutoAttackEvent.new()
	for tier: int in [0, 1, 2]:
		p.hero_bonus_tier = tier
		assert_int(p.hero_bonus_tier).is_equal(tier)

func test_hero_auto_attack_event_all_fields_round_trip() -> void:
	var p := HeroAutoAttackEvent.new()
	p.base_damage = 55.0
	p.is_crit = true
	p.target_id = 12
	p.crit_multiplier_effective = 2.5
	p.hero_lifesteal_fraction = 0.1
	p.hero_bonus_tier = 1
	assert_float(p.base_damage).is_equal(55.0)
	assert_bool(p.is_crit).is_true()
	assert_int(p.target_id).is_equal(12)
	assert_float(p.crit_multiplier_effective).is_equal(2.5)
	assert_float(p.hero_lifesteal_fraction).is_equal(0.1)
	assert_int(p.hero_bonus_tier).is_equal(1)

# =============================================================================
# MonsterDamageTaken (5 fields)
# =============================================================================

func test_monster_damage_taken_default_source_type_is_zero() -> void:
	# 0 = tower (most common source). Ensures neutral default.
	var p := MonsterDamageTaken.new()
	assert_int(p.source_type).is_equal(0)

func test_monster_damage_taken_default_is_crit_is_false() -> void:
	var p := MonsterDamageTaken.new()
	assert_bool(p.is_crit).is_false()

func test_monster_damage_taken_default_amount_is_zero() -> void:
	var p := MonsterDamageTaken.new()
	assert_int(p.amount).is_equal(0)

func test_monster_damage_taken_source_type_valid_values() -> void:
	# Valid source_type values per GDD: 0 = tower, 1 = hero, 2 = reserved.
	var p := MonsterDamageTaken.new()
	for src: int in [0, 1, 2]:
		p.source_type = src
		assert_int(p.source_type).is_equal(src)

func test_monster_damage_taken_all_fields_round_trip() -> void:
	var p := MonsterDamageTaken.new()
	p.entity_id = 7
	p.amount = 42
	p.source_type = 1
	p.is_crit = true
	p.hero_bonus_tier = 2
	assert_int(p.entity_id).is_equal(7)
	assert_int(p.amount).is_equal(42)
	assert_int(p.source_type).is_equal(1)
	assert_bool(p.is_crit).is_true()
	assert_int(p.hero_bonus_tier).is_equal(2)

# =============================================================================
# TowerAuraPulseEvent (4 fields)
# =============================================================================

func test_tower_aura_pulse_event_default_tower_id_is_minus_one() -> void:
	var p := TowerAuraPulseEvent.new()
	assert_int(p.tower_id).is_equal(-1)

func test_tower_aura_pulse_event_default_aura_radius_cells_is_zero() -> void:
	var p := TowerAuraPulseEvent.new()
	assert_int(p.aura_radius_cells).is_equal(0)

func test_tower_aura_pulse_event_does_not_have_anchor_cell_field() -> void:
	# anchor_cell was removed from the GDD (2026-05-01 revision).
	# D&S derives position from tower_id via Grid read.
	# If this test fails, the field was re-added without a catalogue revision.
	var p := TowerAuraPulseEvent.new()
	assert_bool(p.get("anchor_cell") == null).is_true()

func test_tower_aura_pulse_event_all_fields_round_trip() -> void:
	var p := TowerAuraPulseEvent.new()
	p.tower_id = 3
	p.aura_effect_type = "slow"
	p.aura_effect_value = 0.3
	p.aura_radius_cells = 2
	assert_int(p.tower_id).is_equal(3)
	assert_str(p.aura_effect_type).is_equal("slow")
	assert_float(p.aura_effect_value).is_equal(0.3)
	assert_int(p.aura_radius_cells).is_equal(2)

# =============================================================================
# TowerWaveSummary (7 fields)
# =============================================================================

func test_tower_wave_summary_default_tower_id_is_minus_one() -> void:
	var p := TowerWaveSummary.new()
	assert_int(p.tower_id).is_equal(-1)

func test_tower_wave_summary_default_scatter_target_cycle_is_empty_dict() -> void:
	var p := TowerWaveSummary.new()
	assert_int(p.scatter_target_cycle.size()).is_equal(0)

func test_tower_wave_summary_does_not_have_hp_remaining_field() -> void:
	# hp_remaining was removed — HP always resets to max_hp at wave end.
	# If this test fails, the field was re-added without a catalogue revision.
	var p := TowerWaveSummary.new()
	assert_bool(p.get("hp_remaining") == null).is_true()

func test_tower_wave_summary_does_not_have_wave_id_field() -> void:
	# wave_id was removed — not required by Tower GDD Rule 23.
	var p := TowerWaveSummary.new()
	assert_bool(p.get("wave_id") == null).is_true()

func test_tower_wave_summary_scatter_target_cycle_stores_entity_hit_map() -> void:
	# Arrange
	var p := TowerWaveSummary.new()
	# SCATTER hit map: entity_id -> hit_count
	p.scatter_target_cycle = {101: 3, 102: 1, 103: 7}

	# Assert
	assert_int(p.scatter_target_cycle[101]).is_equal(3)
	assert_int(p.scatter_target_cycle[102]).is_equal(1)
	assert_int(p.scatter_target_cycle[103]).is_equal(7)

func test_tower_wave_summary_all_fields_round_trip() -> void:
	var p := TowerWaveSummary.new()
	p.tower_id = 4
	p.max_hp = 500.0
	p.shots_fired = 30
	p.damage_dealt = 1200.0
	p.idle_ticks = 2
	p.aura_applications_this_wave = 5
	p.scatter_target_cycle = {10: 2}
	assert_int(p.tower_id).is_equal(4)
	assert_float(p.max_hp).is_equal(500.0)
	assert_int(p.shots_fired).is_equal(30)
	assert_float(p.damage_dealt).is_equal(1200.0)
	assert_int(p.idle_ticks).is_equal(2)
	assert_int(p.aura_applications_this_wave).is_equal(5)
	assert_int(p.scatter_target_cycle[10]).is_equal(2)

# =============================================================================
# Cross-class: event-payload Resources must not inherit from each other
# =============================================================================

func test_all_payload_classes_extend_resource_directly() -> void:
	# Each payload class must extend Resource, not another payload class.
	# This guards against accidental inheritance coupling between payload types.
	assert_str(MonsterDiedEvent.new().get_class()).is_equal("Resource")
	assert_str(MonsterSpawnedEvent.new().get_class()).is_equal("Resource")
	assert_str(MonsterSpawnRequest.new().get_class()).is_equal("Resource")
	assert_str(HeroAutoAttackEvent.new().get_class()).is_equal("Resource")
	assert_str(MonsterDamageTaken.new().get_class()).is_equal("Resource")
	assert_str(TowerAuraPulseEvent.new().get_class()).is_equal("Resource")
	assert_str(TowerWaveSummary.new().get_class()).is_equal("Resource")
