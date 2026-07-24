extends GdUnitTestSuite

## Tower component validation tests.
## Covers: AC-25 through AC-28.
##
## Amendment 2026-07-19 (ADR-0008 implementation catch-up): fields these ACs
## originally validated on a single flat TowerData now live on separate
## component classes (WeaponComponent: weapon_damage/attack_speed;
## FoundationComponent: tier_dps_multiplier/tier_boss_dps_multiplier) — tests
## exercise each component's own validate() directly rather than a composed
## blueprint's, since that's what actually enforces these ranges now.
##
## validate() returns false for out-of-range values and calls push_error()
## for editor diagnostics. Tests verify the bool return value — not the
## push_error side effect (which GdUnit4 would treat as a test error).

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _base_weapon() -> WeaponComponent:
	var w := WeaponComponent.new()
	w.weapon_damage = 35.0
	w.attack_speed = 1.0
	return w


func _base_foundation(tier: int = 1) -> FoundationComponent:
	var f := FoundationComponent.new()
	f.tier = tier
	f.hp_base = 100.0
	f.tier_multiplier = 1.0
	f.tier_dps_multiplier = 1.0
	f.tier_boss_dps_multiplier = 1.0 if tier != 4 else 2.0
	return f

# ---------------------------------------------------------------------------
# AC-25: weapon_damage outside [8.0, 120.0] → validate() returns false
# ---------------------------------------------------------------------------

func test_validate_weapon_damage_below_minimum_returns_false() -> void:
	var w: WeaponComponent = _base_weapon()
	w.weapon_damage = 7.9
	assert_bool(w.validate()).is_false()


func test_validate_weapon_damage_above_maximum_returns_false() -> void:
	var w: WeaponComponent = _base_weapon()
	w.weapon_damage = 120.1
	assert_bool(w.validate()).is_false()


func test_validate_weapon_damage_at_minimum_returns_true() -> void:
	var w: WeaponComponent = _base_weapon()
	w.weapon_damage = 8.0
	assert_bool(w.validate()).is_true()


func test_validate_weapon_damage_at_maximum_returns_true() -> void:
	var w: WeaponComponent = _base_weapon()
	w.weapon_damage = 120.0
	assert_bool(w.validate()).is_true()

# ---------------------------------------------------------------------------
# AC-26: attack_speed outside [0.5, 4.0] → validate() returns false
# ---------------------------------------------------------------------------

func test_validate_attack_speed_below_minimum_returns_false() -> void:
	var w: WeaponComponent = _base_weapon()
	w.attack_speed = 0.49
	assert_bool(w.validate()).is_false()


func test_validate_attack_speed_above_maximum_returns_false() -> void:
	var w: WeaponComponent = _base_weapon()
	w.attack_speed = 4.01
	assert_bool(w.validate()).is_false()


func test_validate_attack_speed_at_lower_boundary_returns_true() -> void:
	var w: WeaponComponent = _base_weapon()
	w.attack_speed = 0.5
	assert_bool(w.validate()).is_true()


func test_validate_attack_speed_at_upper_boundary_returns_true() -> void:
	var w: WeaponComponent = _base_weapon()
	w.attack_speed = 4.0
	assert_bool(w.validate()).is_true()

# ---------------------------------------------------------------------------
# AC-27: tier_dps_multiplier not in {1.0, 1.6, 2.4, 4.0} → validate() returns false
# ---------------------------------------------------------------------------

func test_validate_dps_multiplier_invalid_value_returns_false() -> void:
	var f: FoundationComponent = _base_foundation()
	f.tier_dps_multiplier = 2.0  # Not in the valid set
	assert_bool(f.validate()).is_false()


func test_validate_dps_multiplier_1_0_returns_true() -> void:
	var f: FoundationComponent = _base_foundation()
	f.tier_dps_multiplier = 1.0
	assert_bool(f.validate()).is_true()


func test_validate_dps_multiplier_1_6_returns_true() -> void:
	var f: FoundationComponent = _base_foundation()
	f.tier_dps_multiplier = 1.6
	assert_bool(f.validate()).is_true()


func test_validate_dps_multiplier_2_4_returns_true() -> void:
	var f: FoundationComponent = _base_foundation()
	f.tier_dps_multiplier = 2.4
	assert_bool(f.validate()).is_true()


func test_validate_dps_multiplier_4_0_returns_true() -> void:
	var f: FoundationComponent = _base_foundation()
	f.tier_dps_multiplier = 4.0
	assert_bool(f.validate()).is_true()

# ---------------------------------------------------------------------------
# AC-28: T4 boss_dps_multiplier must be 2.0; T1/T2/T3 must be 1.0
# ---------------------------------------------------------------------------

func test_validate_t4_boss_mult_not_2_returns_false() -> void:
	var f: FoundationComponent = _base_foundation(4)
	f.tier_boss_dps_multiplier = 1.0  # Wrong for T4
	assert_bool(f.validate()).is_false()


func test_validate_t4_boss_mult_2_returns_true() -> void:
	var f: FoundationComponent = _base_foundation(4)
	f.tier_boss_dps_multiplier = 2.0
	assert_bool(f.validate()).is_true()


func test_validate_t1_boss_mult_not_1_returns_false() -> void:
	var f: FoundationComponent = _base_foundation(1)
	f.tier_boss_dps_multiplier = 2.0  # Wrong for T1
	assert_bool(f.validate()).is_false()


func test_validate_t2_boss_mult_1_returns_true() -> void:
	var f: FoundationComponent = _base_foundation(2)
	f.tier_boss_dps_multiplier = 1.0
	assert_bool(f.validate()).is_true()


func test_validate_t3_boss_mult_1_returns_true() -> void:
	var f: FoundationComponent = _base_foundation(3)
	f.tier_boss_dps_multiplier = 1.0
	assert_bool(f.validate()).is_true()


func test_validate_all_valid_fields_returns_true() -> void:
	assert_bool(_base_weapon().validate()).is_true()
	assert_bool(_base_foundation().validate()).is_true()
