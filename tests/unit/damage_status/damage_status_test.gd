extends GdUnitTestSuite

## S3-04 unit tests — Damage & Status system.
## Covers AC-1 through AC-14 (D1/D2/D3 formulas + architectural invariants).

var _ds: DamageStatus
var _spy: EventBusSpy


func before_test() -> void:
	_ds = DamageStatus.new()
	add_child(_ds)  # Required: async handlers call get_tree()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.monster_damage_taken)
	_spy.watch(GEventBus.hero_healed)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if is_instance_valid(_ds):
		_ds.queue_free()
		await get_tree().process_frame
	_ds = null


# ---------------------------------------------------------------------------
# AC-1: D1 no armor — floor(47.3) = 47
# ---------------------------------------------------------------------------
func test_d1_no_armor_floors_raw_damage() -> void:
	_ds._on_tower_attacked(0, 1, 47.3, false, false, "", 0.0, 0.0)
	await get_tree().process_frame

	var emissions: Array = _spy.emissions.get("monster_damage_taken", []) as Array
	assert_int(emissions.size()).is_equal(1)
	var payload: MonsterDamageTaken = emissions[0][0] as MonsterDamageTaken
	assert_int(payload.amount).is_equal(47)
	assert_int(payload.entity_id).is_equal(1)
	assert_int(payload.source_type).is_equal(0)
	assert_bool(payload.is_crit).is_false()
	assert_int(payload.hero_bonus_tier).is_equal(0)


# ---------------------------------------------------------------------------
# AC-2: D1 armored — floor(80.7 × 0.50) = floor(40.35) = 40
# ---------------------------------------------------------------------------
func test_d1_armored_applies_50_percent_mitigation() -> void:
	_ds._on_tower_attacked(0, 1, 80.7, false, true, "", 0.0, 0.0)
	await get_tree().process_frame

	var emissions: Array = _spy.emissions.get("monster_damage_taken", []) as Array
	assert_int(emissions.size()).is_equal(1)
	var payload: MonsterDamageTaken = emissions[0][0] as MonsterDamageTaken
	assert_int(payload.amount).is_equal(40)


# AC-2 edge case: floor(2.5)=2 — distinguishes floori from roundi
func test_d1_armored_floor_not_round_on_half_value() -> void:
	_ds._on_tower_attacked(0, 1, 5.0, false, true, "", 0.0, 0.0)
	await get_tree().process_frame

	var emissions: Array = _spy.emissions.get("monster_damage_taken", []) as Array
	var payload: MonsterDamageTaken = emissions[0][0] as MonsterDamageTaken
	assert_int(payload.amount).is_equal(2)  # floor(2.5)=2, not round(2.5)=3


# ---------------------------------------------------------------------------
# AC-3: D1 ELITE target — hero_bonus_tier irrelevant to tower pipeline
# Proof is structural: _on_tower_attacked has no tier parameter, so monster
# tier cannot influence tower damage. The hardcoded hero_bonus_tier=0 and
# is_crit=false on the payload ARE the invariant being validated here.
# ---------------------------------------------------------------------------
func test_d1_elite_target_does_not_affect_tower_pipeline() -> void:
	_ds._on_tower_attacked(0, 1, 80.7, false, false, "", 0.0, 0.0)
	await get_tree().process_frame

	var emissions: Array = _spy.emissions.get("monster_damage_taken", []) as Array
	var payload: MonsterDamageTaken = emissions[0][0] as MonsterDamageTaken
	assert_int(payload.amount).is_equal(80)
	assert_int(payload.hero_bonus_tier).is_equal(0)
	assert_bool(payload.is_crit).is_false()


# ---------------------------------------------------------------------------
# AC-4: Zero-damage guard — floor(0.9) = 0 → NOT emitted
# ---------------------------------------------------------------------------
func test_d1_zero_final_damage_suppresses_emission() -> void:
	_ds._on_tower_attacked(0, 1, 0.9, false, false, "", 0.0, 0.0)
	await get_tree().process_frame

	assert_bool(_spy.was_emitted("monster_damage_taken")).is_false()


# ---------------------------------------------------------------------------
# AC-5: D2 STANDARD no crit — floor(100 × 1.0 × 1.0) = 100
# ---------------------------------------------------------------------------
func test_d2_standard_no_crit_returns_base_damage() -> void:
	var ev := HeroAutoAttackEvent.new()
	ev.base_damage = 100.0
	ev.is_crit = false
	ev.target_id = 5
	ev.crit_multiplier_effective = 1.0
	ev.hero_lifesteal_fraction = 0.0
	ev.hero_bonus_tier = 0

	_ds._on_hero_auto_attacked(ev)
	await get_tree().process_frame

	var emissions: Array = _spy.emissions.get("monster_damage_taken", []) as Array
	assert_int(emissions.size()).is_equal(1)
	var payload: MonsterDamageTaken = emissions[0][0] as MonsterDamageTaken
	assert_int(payload.amount).is_equal(100)
	assert_int(payload.source_type).is_equal(1)
	assert_bool(payload.is_crit).is_false()
	assert_int(payload.hero_bonus_tier).is_equal(0)


# ---------------------------------------------------------------------------
# AC-6: D2 ELITE no crit — floor(100 × 1.5) = 150
# ---------------------------------------------------------------------------
func test_d2_elite_bonus_applies_1_5_multiplier() -> void:
	var ev := HeroAutoAttackEvent.new()
	ev.base_damage = 100.0
	ev.is_crit = false
	ev.target_id = 5
	ev.crit_multiplier_effective = 1.0
	ev.hero_lifesteal_fraction = 0.0
	ev.hero_bonus_tier = 1

	_ds._on_hero_auto_attacked(ev)
	await get_tree().process_frame

	var emissions: Array = _spy.emissions.get("monster_damage_taken", []) as Array
	var payload: MonsterDamageTaken = emissions[0][0] as MonsterDamageTaken
	assert_int(payload.amount).is_equal(150)
	assert_int(payload.hero_bonus_tier).is_equal(1)


# ---------------------------------------------------------------------------
# AC-7: D2 ELITE + crit — floor(100 × 1.5 × 1.75) = floor(262.5) = 262
# ---------------------------------------------------------------------------
func test_d2_elite_crit_returns_262() -> void:
	var ev := HeroAutoAttackEvent.new()
	ev.base_damage = 100.0
	ev.is_crit = true
	ev.target_id = 5
	ev.crit_multiplier_effective = 1.75
	ev.hero_lifesteal_fraction = 0.0
	ev.hero_bonus_tier = 1

	_ds._on_hero_auto_attacked(ev)
	await get_tree().process_frame

	var emissions: Array = _spy.emissions.get("monster_damage_taken", []) as Array
	var payload: MonsterDamageTaken = emissions[0][0] as MonsterDamageTaken
	assert_int(payload.amount).is_equal(262)
	assert_bool(payload.is_crit).is_true()


# ---------------------------------------------------------------------------
# AC-8: D2 STANDARD + crit — floor(100 × 1.0 × 1.75) = 175
# ---------------------------------------------------------------------------
func test_d2_standard_crit_returns_175() -> void:
	var ev := HeroAutoAttackEvent.new()
	ev.base_damage = 100.0
	ev.is_crit = true
	ev.target_id = 5
	ev.crit_multiplier_effective = 1.75
	ev.hero_lifesteal_fraction = 0.0
	ev.hero_bonus_tier = 0

	_ds._on_hero_auto_attacked(ev)
	await get_tree().process_frame

	var emissions: Array = _spy.emissions.get("monster_damage_taken", []) as Array
	var payload: MonsterDamageTaken = emissions[0][0] as MonsterDamageTaken
	assert_int(payload.amount).is_equal(175)


# AC-7 edge case (story-specified): base=100, ELITE, crit_mult=3.25 → floor(487.5) = 487
func test_d2_elite_max_crit_returns_487() -> void:
	var ev := HeroAutoAttackEvent.new()
	ev.base_damage = 100.0
	ev.is_crit = true
	ev.target_id = 5
	ev.crit_multiplier_effective = 3.25
	ev.hero_lifesteal_fraction = 0.0
	ev.hero_bonus_tier = 1

	_ds._on_hero_auto_attacked(ev)
	await get_tree().process_frame

	var emissions: Array = _spy.emissions.get("monster_damage_taken", []) as Array
	var payload: MonsterDamageTaken = emissions[0][0] as MonsterDamageTaken
	assert_int(payload.amount).is_equal(487)  # floor(100 × 1.50 × 3.25) = floor(487.5) = 487


# D2 zero-damage guard — hero pipeline counterpart to AC-4
func test_d2_zero_base_damage_suppresses_emission() -> void:
	var ev := HeroAutoAttackEvent.new()
	ev.base_damage = 0.5
	ev.is_crit = false
	ev.target_id = 5
	ev.crit_multiplier_effective = 1.0
	ev.hero_lifesteal_fraction = 0.0
	ev.hero_bonus_tier = 0

	_ds._on_hero_auto_attacked(ev)
	await get_tree().process_frame

	assert_bool(_spy.was_emitted("monster_damage_taken")).is_false()


# ---------------------------------------------------------------------------
# AC-9: D3 lifesteal — fraction=0.20, absorbed=150 → hero_healed(30)
# ---------------------------------------------------------------------------
func test_lifesteal_emits_hero_healed_with_correct_amount() -> void:
	_ds._lifesteal_pending[42] = 0.20
	_ds._on_monster_hp_absorbed(42, 150)  # synchronous

	assert_bool(_spy.was_emitted("hero_healed")).is_true()
	var emissions: Array = _spy.emissions.get("hero_healed", []) as Array
	assert_int(int(emissions[0][0])).is_equal(30)
	assert_bool(_ds._lifesteal_pending.has(42)).is_false()


# ---------------------------------------------------------------------------
# AC-10: D3 suppressed — fraction=0.10, absorbed=2 → floor(0.2)=0 → NOT fired
# ---------------------------------------------------------------------------
func test_lifesteal_suppressed_when_heal_rounds_to_zero() -> void:
	_ds._lifesteal_pending[42] = 0.10
	_ds._on_monster_hp_absorbed(42, 2)

	assert_bool(_spy.was_emitted("hero_healed")).is_false()
	assert_bool(_ds._lifesteal_pending.has(42)).is_false()


# ---------------------------------------------------------------------------
# AC-11: fraction=0.0 fast path — no entry registered, hero_healed never fires
# ---------------------------------------------------------------------------
func test_lifesteal_zero_fraction_skips_pending_registration() -> void:
	var ev := HeroAutoAttackEvent.new()
	ev.base_damage = 100.0
	ev.is_crit = false
	ev.target_id = 7
	ev.crit_multiplier_effective = 1.0
	ev.hero_lifesteal_fraction = 0.0
	ev.hero_bonus_tier = 0

	_ds._on_hero_auto_attacked(ev)
	assert_bool(_ds._lifesteal_pending.has(7)).is_false()

	await get_tree().process_frame
	assert_bool(_ds._lifesteal_pending.has(7)).is_false()
	assert_bool(_spy.was_emitted("hero_healed")).is_false()
	# Fast path skips lifesteal entry only — damage must still be emitted
	assert_bool(_spy.was_emitted("monster_damage_taken")).is_true()
	var dmg_emissions: Array = _spy.emissions.get("monster_damage_taken", []) as Array
	var dmg_payload: MonsterDamageTaken = dmg_emissions[0][0] as MonsterDamageTaken
	assert_int(dmg_payload.amount).is_equal(100)


# ---------------------------------------------------------------------------
# AC-12: is_instance_valid guard — freed node emits nothing after await
# ---------------------------------------------------------------------------
func test_freed_node_emits_no_signal_after_frame_boundary() -> void:
	_ds._on_tower_attacked(0, 1, 50.0, false, false, "", 0.0, 0.0)  # coroutine suspends at await
	_ds.free()  # immediate free while coroutine is suspended
	_ds = null
	await get_tree().process_frame  # coroutine resumes: is_instance_valid(self) = false → returns

	assert_bool(_spy.was_emitted("monster_damage_taken")).is_false()


# ---------------------------------------------------------------------------
# AC-13: hero_healed fires synchronously from _on_monster_hp_absorbed
# Verified by checking spy immediately after the call — no await needed
# ---------------------------------------------------------------------------
func test_hero_healed_is_synchronous_from_monster_hp_absorbed() -> void:
	_ds._lifesteal_pending[10] = 0.50
	_ds._on_monster_hp_absorbed(10, 100)

	# No await — synchronous emission means spy already has it
	assert_bool(_spy.was_emitted("hero_healed")).is_true()
	var emissions: Array = _spy.emissions.get("hero_healed", []) as Array
	assert_int(int(emissions[0][0])).is_equal(50)


# ---------------------------------------------------------------------------
# AC-14: _lifesteal_pending cleared on wave_completed (deferred)
# ---------------------------------------------------------------------------
func test_wave_completed_clears_lifesteal_pending() -> void:
	_ds._lifesteal_pending[99] = 0.30
	_ds._lifesteal_pending[100] = 0.15
	assert_int(_ds._lifesteal_pending.size()).is_equal(2)

	_ds._on_wave_completed(1, 0, false)
	await get_tree().process_frame

	assert_int(_ds._lifesteal_pending.size()).is_equal(0)

# ---------------------------------------------------------------------------
# Regression (Story 002, epic-04-wave-manager code review): the test above
# calls _on_wave_completed() directly, bypassing GEventBus.wave_completed
# entirely — it cannot catch a future arity mismatch between the real signal
# and this handler. This test goes through the REAL signal instead, so a
# future change to wave_completed's signature that this handler doesn't
# follow surfaces here as a runtime "Method expected N argument(s)" error,
# not just via someone manually re-running the full suite.
# ---------------------------------------------------------------------------
func test_wave_completed_real_signal_wiring_survives_current_arity() -> void:
	_ds._lifesteal_pending[42] = 0.25
	assert_int(_ds._lifesteal_pending.size()).is_equal(1)

	GEventBus.wave_completed.emit(1, 0, false)
	await get_tree().process_frame

	assert_int(_ds._lifesteal_pending.size()).is_equal(0)
