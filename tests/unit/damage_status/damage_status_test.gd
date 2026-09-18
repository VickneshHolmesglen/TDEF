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
	_ds._on_tower_attacked(0, 1, 47.3, false, false, "", 0.0, 0.0, 0.0, false)
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
	_ds._on_tower_attacked(0, 1, 80.7, false, true, "", 0.0, 0.0, 0.0, false)
	await get_tree().process_frame

	var emissions: Array = _spy.emissions.get("monster_damage_taken", []) as Array
	assert_int(emissions.size()).is_equal(1)
	var payload: MonsterDamageTaken = emissions[0][0] as MonsterDamageTaken
	assert_int(payload.amount).is_equal(40)


# AC-2 edge case: floor(2.5)=2 — distinguishes floori from roundi
func test_d1_armored_floor_not_round_on_half_value() -> void:
	_ds._on_tower_attacked(0, 1, 5.0, false, true, "", 0.0, 0.0, 0.0, false)
	await get_tree().process_frame

	var emissions: Array = _spy.emissions.get("monster_damage_taken", []) as Array
	var payload: MonsterDamageTaken = emissions[0][0] as MonsterDamageTaken
	assert_int(payload.amount).is_equal(2)  # floor(2.5)=2, not round(2.5)=3


# ---------------------------------------------------------------------------
# AC-3: D1 ELITE target — hero_bonus_tier irrelevant to tower pipeline
# Proof is structural: _on_tower_attacked has no tier parameter, so monster
# tier cannot influence tower damage. hero_bonus_tier=0 on the payload IS the
# invariant being validated here — hero_bonus_tier has no tower-pipeline
# equivalent at all. is_crit is asserted separately below as a simple
# passthrough check (Tower Stats System Phase 1, 2026-08-16: is_crit is now a
# real forwarded parameter, not a hardcoded value — this call passes false in,
# so false out is the correct passthrough, not a structural invariant).
# ---------------------------------------------------------------------------
func test_d1_elite_target_does_not_affect_tower_pipeline() -> void:
	_ds._on_tower_attacked(0, 1, 80.7, false, false, "", 0.0, 0.0, 0.0, false)
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
	_ds._on_tower_attacked(0, 1, 0.9, false, false, "", 0.0, 0.0, 0.0, false)
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
	# ±5% combat variance (Hero Combat & Stats Redesign, 2026-09-18): floor(100*0.95)=95, floor(100*1.05)=105
	assert_int(payload.amount).is_between(95, 105)
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
	# ±5% combat variance: floor(150*0.95)=142, floor(150*1.05)=157
	assert_int(payload.amount).is_between(142, 157)
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
	# ±5% combat variance: floor(262*0.95)=248, floor(262*1.05)=275
	assert_int(payload.amount).is_between(248, 275)
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
	# ±5% combat variance: floor(175*0.95)=166, floor(175*1.05)=183
	assert_int(payload.amount).is_between(166, 183)


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
	# floor(100 × 1.50 × 3.25) = floor(487.5) = 487; ±5% combat variance:
	# floor(487*0.95)=462, floor(487*1.05)=511
	assert_int(payload.amount).is_between(462, 511)


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
	# ±5% combat variance (Hero Combat & Stats Redesign, 2026-09-18): floor(100*0.95)=95, floor(100*1.05)=105
	assert_int(dmg_payload.amount).is_between(95, 105)


# ---------------------------------------------------------------------------
# AC-12: is_instance_valid guard — freed node emits nothing after await
# ---------------------------------------------------------------------------
func test_freed_node_emits_no_signal_after_frame_boundary() -> void:
	_ds._on_tower_attacked(0, 1, 50.0, false, false, "", 0.0, 0.0, 0.0, false)  # coroutine suspends at await
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


# ---------------------------------------------------------------------------
# Hero Combat & Stats Redesign (2026-09-18): evasion / mitigation / variance
# static helpers, tested in isolation (pure functions, no node/tree needed).
# ---------------------------------------------------------------------------

func test_roll_evasion_zero_percent_never_evades() -> void:
	for i: int in range(100):
		assert_bool(DamageStatus._roll_evasion(0.0)).is_false()


func test_roll_evasion_one_hundred_percent_always_evades() -> void:
	for i: int in range(100):
		assert_bool(DamageStatus._roll_evasion(100.0)).is_true()


func test_roll_evasion_statistical_rate_within_tolerance() -> void:
	const SAMPLE_SIZE: int = 10000
	const EVASION_PERCENT: float = 30.0
	var evade_count: int = 0
	for i: int in range(SAMPLE_SIZE):
		if DamageStatus._roll_evasion(EVASION_PERCENT):
			evade_count += 1
	var observed_rate: float = float(evade_count) / float(SAMPLE_SIZE)
	assert_float(observed_rate).is_between(0.28, 0.32)


func test_resolve_target_mitigation_true_damage_type_bypasses_everything() -> void:
	var multiplier: float = DamageStatus._resolve_target_mitigation("true", 500.0, 0.9)
	assert_float(multiplier).is_equal_approx(1.0, 0.0001)


func test_resolve_target_mitigation_physical_zero_armor_applies_no_mitigation() -> void:
	var multiplier: float = DamageStatus._resolve_target_mitigation("physical", 0.0, 0.0)
	assert_float(multiplier).is_equal_approx(1.0, 0.0001)


func test_resolve_target_mitigation_physical_with_armor_worked_example() -> void:
	# Armor=50, hero_level=1 (hardcoded): mitigation% = 50/(50+50*1) = 0.5 -> multiplier = 0.5
	var multiplier: float = DamageStatus._resolve_target_mitigation("physical", 50.0, 0.0)
	assert_float(multiplier).is_equal_approx(0.5, 0.0001)


func test_resolve_target_mitigation_magic_uses_elemental_resist_directly() -> void:
	var multiplier: float = DamageStatus._resolve_target_mitigation("fire", 500.0, 0.4)
	# damage_type != "physical"/"true" -> ignores target_armor entirely, uses
	# 1.0 - target_elemental_resist = 0.6
	assert_float(multiplier).is_equal_approx(0.6, 0.0001)


func test_apply_combat_variance_stays_within_five_percent_band() -> void:
	for i: int in range(1000):
		var result: float = DamageStatus._apply_combat_variance(100.0)
		assert_float(result).is_between(94.9, 105.1)


func test_d2_evasion_roll_suppresses_damage_entirely() -> void:
	var ev := HeroAutoAttackEvent.new()
	ev.base_damage = 100.0
	ev.is_crit = false
	ev.target_id = 5
	ev.crit_multiplier_effective = 1.0
	ev.hero_lifesteal_fraction = 0.0
	ev.hero_bonus_tier = 0
	ev.target_evasion = 100.0  # guaranteed miss

	_ds._on_hero_auto_attacked(ev)
	await get_tree().process_frame

	assert_bool(_spy.was_emitted("monster_damage_taken")).is_false()


func test_d2_physical_armor_reduces_damage() -> void:
	var ev := HeroAutoAttackEvent.new()
	ev.base_damage = 100.0
	ev.is_crit = false
	ev.target_id = 5
	ev.crit_multiplier_effective = 1.0
	ev.hero_lifesteal_fraction = 0.0
	ev.hero_bonus_tier = 0
	ev.damage_type = "physical"
	ev.target_armor = 50.0  # mitigation multiplier = 0.5 per the worked example above

	_ds._on_hero_auto_attacked(ev)
	await get_tree().process_frame

	var emissions: Array = _spy.emissions.get("monster_damage_taken", []) as Array
	var payload: MonsterDamageTaken = emissions[0][0] as MonsterDamageTaken
	# floor(100 * 0.5 * variance[0.95,1.05]) -> in [47, 52]
	assert_int(payload.amount).is_between(47, 52)


func test_d2_magic_damage_type_uses_elemental_resist_not_armor() -> void:
	var ev := HeroAutoAttackEvent.new()
	ev.base_damage = 100.0
	ev.is_crit = false
	ev.target_id = 5
	ev.crit_multiplier_effective = 1.0
	ev.hero_lifesteal_fraction = 0.0
	ev.hero_bonus_tier = 0
	ev.damage_type = "fire"
	ev.target_armor = 500.0  # must be ignored entirely for a non-physical damage_type
	ev.target_elemental_resist = 0.5

	_ds._on_hero_auto_attacked(ev)
	await get_tree().process_frame

	var emissions: Array = _spy.emissions.get("monster_damage_taken", []) as Array
	var payload: MonsterDamageTaken = emissions[0][0] as MonsterDamageTaken
	# floor(100 * 0.5 * variance[0.95,1.05]) -> in [47, 52] -- if target_armor
	# were wrongly consulted instead, this would be far lower.
	assert_int(payload.amount).is_between(47, 52)
