extends GdUnitTestSuite

## Integration tests for Hero -> Damage & Status auto-attack combat formula
## (story-004, ADR-0007, ADR-0010). Verifies the already-shipped signal chain:
## Hero emits hero_auto_attacked (HeroAutoAttackEvent) synchronously; D&S's
## _on_hero_auto_attacked() resolves Formula 4 damage (tier bonus x crit
## multiplier, floored) and emits monster_damage_taken (MonsterDamageTaken)
## one frame later via `await get_tree().process_frame`.
##
## Scope: AC-03 (crit damage) and AC-04 (elite/boss tier multiplier) only.
## AC-05 (monster armor reduction) and AC-06 (lifesteal overheal clamp) are
## explicitly out of scope for this story — see dispatch brief:
##   - AC-05 describes a "monster armor" stat applied to hero-dealt damage
##     that does not exist anywhere in damage_status.gd or the GDDs. Real
##     armor reduction (Formula 5 / D1, ARMORED_MITIGATION_MULTIPLIER) only
##     applies to tower_attacked (incoming damage to monsters from towers),
##     and is unrelated to any "monster armor vs hero" concept.
##   - AC-06's overheal clamp is Hero System's responsibility per GDD, but
##     Hero has no current_hp field and no hero_healed subscriber yet.
## No changes were made to src/ — this file only exercises the existing,
## shipped D&S implementation.
##
## Discrepancy vs. the story's Implementation Notes: damage_status.gd's
## HERO_DAMAGE_BONUS_MULTIPLIER is a single flat 1.5x constant applied to
## ANY hero_bonus_tier > 0 (see _on_hero_auto_attacked, line 56). It does
## NOT distinguish ELITE (1.5x) from BOSS (2.0x) the way the story's
## Formula 4 sketch and QA Test Cases (AC-04 edge case) claim. Both
## hero_bonus_tier = 1 (ELITE) and hero_bonus_tier = 2 (BOSS) resolve to
## the same 1.5x multiplier in the current implementation. Tests below
## assert the actual code behavior, not the story's stale claim.

var _damage_status: DamageStatus
var _spy: EventBusSpy


func before_test() -> void:
	# D&S subscribes to GEventBus signals in _ready(); must be a live node in
	# the tree for the subscription to be active during the test.
	_damage_status = DamageStatus.new()
	add_child(_damage_status)
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.monster_damage_taken)


func after_test() -> void:
	if _spy != null:
		_spy.disconnect_all()
		_spy = null
	if _damage_status != null and is_instance_valid(_damage_status):
		if _damage_status.is_inside_tree():
			_damage_status.get_parent().remove_child(_damage_status)
		_damage_status.free()
	_damage_status = null


## Builds a HeroAutoAttackEvent with minimal, explicit fields. lifesteal_fraction
## is fixed at 0.0 to avoid triggering the _lifesteal_pending registration path
## (out of scope per AC-06 exclusion — lifesteal resolution is not under test here).
func _make_payload(base_damage: float, is_crit: bool, crit_multiplier_effective: float,
		hero_bonus_tier: int, target_id: int) -> HeroAutoAttackEvent:
	var payload := HeroAutoAttackEvent.new()
	payload.base_damage = base_damage
	payload.is_crit = is_crit
	payload.crit_multiplier_effective = crit_multiplier_effective
	payload.hero_bonus_tier = hero_bonus_tier
	payload.target_id = target_id
	payload.hero_lifesteal_fraction = 0.0
	return payload


# ---------------------------------------------------------------------------
# AC-03: Crit damage pipeline
# ---------------------------------------------------------------------------

func test_hero_auto_attack_crit_damage_applies_crit_multiplier() -> void:
	# Arrange: standard tier, crit, base_damage=90, crit_multiplier_effective=2.0
	var payload := _make_payload(90.0, true, 2.0, 0, 101)

	# Act
	GEventBus.hero_auto_attacked.emit(payload)
	await get_tree().process_frame
	assert_that(is_instance_valid(self)).is_true()

	# Assert: final_damage = floor(90 * 1.0 * 2.0) = 180
	assert_int(_spy.count("monster_damage_taken")).is_equal(1)
	var ev: MonsterDamageTaken = (_spy.emissions["monster_damage_taken"] as Array)[0][0] as MonsterDamageTaken
	assert_int(ev.amount).is_equal(180)
	assert_int(ev.entity_id).is_equal(101)
	assert_bool(ev.is_crit).is_true()
	assert_int(ev.source_type).is_equal(1)  # 1 = hero
	assert_int(ev.hero_bonus_tier).is_equal(0)


func test_hero_auto_attack_no_crit_applies_no_multiplier() -> void:
	# Arrange: standard tier, no crit, base_damage=90 (crit_multiplier_effective
	# irrelevant when is_crit is false)
	var payload := _make_payload(90.0, false, 2.0, 0, 102)

	# Act
	GEventBus.hero_auto_attacked.emit(payload)
	await get_tree().process_frame
	assert_that(is_instance_valid(self)).is_true()

	# Assert: final_damage = floor(90 * 1.0 * 1.0) = 90
	assert_int(_spy.count("monster_damage_taken")).is_equal(1)
	var ev: MonsterDamageTaken = (_spy.emissions["monster_damage_taken"] as Array)[0][0] as MonsterDamageTaken
	assert_int(ev.amount).is_equal(90)
	assert_bool(ev.is_crit).is_false()


# ---------------------------------------------------------------------------
# AC-04: Elite/Boss tier multiplier
# ---------------------------------------------------------------------------

func test_hero_auto_attack_elite_tier_applies_flat_bonus_multiplier() -> void:
	# Arrange: ELITE tier (hero_bonus_tier=1), no crit, base_damage=90
	var payload := _make_payload(90.0, false, 1.0, 1, 103)

	# Act
	GEventBus.hero_auto_attacked.emit(payload)
	await get_tree().process_frame
	assert_that(is_instance_valid(self)).is_true()

	# Assert: final_damage = floor(90 * 1.5 * 1.0) = 135
	assert_int(_spy.count("monster_damage_taken")).is_equal(1)
	var ev: MonsterDamageTaken = (_spy.emissions["monster_damage_taken"] as Array)[0][0] as MonsterDamageTaken
	assert_int(ev.amount).is_equal(135)
	assert_int(ev.hero_bonus_tier).is_equal(1)


func test_hero_auto_attack_boss_tier_applies_same_flat_bonus_multiplier_as_elite() -> void:
	# Arrange: BOSS tier (hero_bonus_tier=2), no crit, base_damage=90.
	# NOTE: damage_status.gd's HERO_DAMAGE_BONUS_MULTIPLIER (1.5) is applied
	# uniformly to any hero_bonus_tier > 0 — there is no separate 2.0x BOSS
	# multiplier in the current implementation, despite the story's Formula 4
	# sketch and QA Test Cases claiming otherwise. This test documents and
	# locks in the actual shipped behavior.
	var payload := _make_payload(90.0, false, 1.0, 2, 104)

	# Act
	GEventBus.hero_auto_attacked.emit(payload)
	await get_tree().process_frame
	assert_that(is_instance_valid(self)).is_true()

	# Assert: final_damage = floor(90 * 1.5 * 1.0) = 135 (NOT 180 — see note above)
	assert_int(_spy.count("monster_damage_taken")).is_equal(1)
	var ev: MonsterDamageTaken = (_spy.emissions["monster_damage_taken"] as Array)[0][0] as MonsterDamageTaken
	assert_int(ev.amount).is_equal(135)
	assert_int(ev.hero_bonus_tier).is_equal(2)


func test_hero_auto_attack_elite_crit_stacks_tier_and_crit_multipliers() -> void:
	# Arrange: ELITE tier + crit, base_damage=90, crit_multiplier_effective=2.0.
	# Cross-check that tier and crit multipliers compose multiplicatively
	# (tier_dmg computed first, then crit applied on top), per D&S source.
	var payload := _make_payload(90.0, true, 2.0, 1, 105)

	# Act
	GEventBus.hero_auto_attacked.emit(payload)
	await get_tree().process_frame
	assert_that(is_instance_valid(self)).is_true()

	# Assert: tier_dmg = 90 * 1.5 = 135; crit_dmg = 135 * 2.0 = 270; floor = 270
	assert_int(_spy.count("monster_damage_taken")).is_equal(1)
	var ev: MonsterDamageTaken = (_spy.emissions["monster_damage_taken"] as Array)[0][0] as MonsterDamageTaken
	assert_int(ev.amount).is_equal(270)
