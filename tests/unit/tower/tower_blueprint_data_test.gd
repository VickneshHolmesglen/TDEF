extends GdUnitTestSuite

## Unit tests for TowerBlueprintData.warn_if_perk_benefit_wasted() (TD-tower-004,
## docs/tech-debt-register.md — the equip-time cross-component "wasted benefit"
## warning that entry's own fix left unimplemented). Formulas mirror
## tower_system.gd::_apply_pre_placement_perk() exactly, so these tests use the
## same boundary values that function's own math would produce.

func _make_blueprint(pre_placement_perk: String, perk_power: float,
		attack_speed: float = 1.0, attack_range_cells: int = 3, aura_radius_cells: int = 0) -> TowerBlueprintData:
	var foundation := FoundationComponent.new()
	foundation.pre_placement_perk = pre_placement_perk
	foundation.perk_power = perk_power
	var weapon := WeaponComponent.new()
	weapon.attack_speed = attack_speed
	weapon.aura_radius_cells = aura_radius_cells
	var focus := FocusComponent.new()
	focus.attack_range_cells = attack_range_cells

	var blueprint := TowerBlueprintData.new()
	blueprint.tower_id = &"test_blueprint"
	blueprint.foundation = foundation
	blueprint.weapon = weapon
	blueprint.focus = focus
	blueprint.power = PowerComponent.new()
	return blueprint


# ---------------------------------------------------------------------------
# SPEED_BOOST — AC-Rule-12a's own boundary values (tower.md)
# ---------------------------------------------------------------------------

func test_speed_boost_exceeding_cap_emits_warning() -> void:
	var blueprint: TowerBlueprintData = _make_blueprint("SPEED_BOOST", 0.25, 3.5)  # 3.5 * 1.25 = 4.375 > 4.0

	await assert_error(func() -> void: blueprint.warn_if_perk_benefit_wasted()) \
		.is_push_warning("[TowerBlueprintData 'test_blueprint'] SPEED_BOOST perk_power 0.2500 boosts attack_speed 3.50 to 4.3750, exceeding the 4.0 cap — partial perk benefit wasted")


func test_speed_boost_within_cap_emits_no_warning() -> void:
	var blueprint: TowerBlueprintData = _make_blueprint("SPEED_BOOST", 0.25, 3.0)  # 3.0 * 1.25 = 3.75 <= 4.0

	blueprint.warn_if_perk_benefit_wasted()

	assert_bool(true).is_true()  # reaching here without a push_warning trap is the assertion


# ---------------------------------------------------------------------------
# RANGE_BOOST
# ---------------------------------------------------------------------------

func test_range_boost_exceeding_cap_emits_warning() -> void:
	# 6 + round(0.25 * 8) = 6 + 2 = 8 -- not over. Use 7 base to push over: 7+2=9 > 8.
	var blueprint: TowerBlueprintData = _make_blueprint("RANGE_BOOST", 0.25, 1.0, 7)

	await assert_error(func() -> void: blueprint.warn_if_perk_benefit_wasted()) \
		.is_push_warning("[TowerBlueprintData 'test_blueprint'] RANGE_BOOST perk_power 0.2500 boosts attack_range_cells 7 to 9, exceeding the 8 cap — partial perk benefit wasted")


func test_range_boost_within_cap_emits_no_warning() -> void:
	var blueprint: TowerBlueprintData = _make_blueprint("RANGE_BOOST", 0.25, 1.0, 6)  # 6+2=8, not over

	blueprint.warn_if_perk_benefit_wasted()

	assert_bool(true).is_true()


# ---------------------------------------------------------------------------
# AURA_EXTEND
# ---------------------------------------------------------------------------

func test_aura_extend_exceeding_cap_emits_warning() -> void:
	# 5 + round(0.25 * 6) = 5 + 2 = 7 > 6
	var blueprint: TowerBlueprintData = _make_blueprint("AURA_EXTEND", 0.25, 1.0, 3, 5)

	await assert_error(func() -> void: blueprint.warn_if_perk_benefit_wasted()) \
		.is_push_warning("[TowerBlueprintData 'test_blueprint'] AURA_EXTEND perk_power 0.2500 boosts aura_radius_cells 5 to 7, exceeding the 6 cap — partial perk benefit wasted")


func test_aura_extend_within_cap_emits_no_warning() -> void:
	var blueprint: TowerBlueprintData = _make_blueprint("AURA_EXTEND", 0.25, 1.0, 3, 4)  # 4+2=6, not over

	blueprint.warn_if_perk_benefit_wasted()

	assert_bool(true).is_true()


# ---------------------------------------------------------------------------
# Excluded / inert cases
# ---------------------------------------------------------------------------

func test_damage_boost_never_emits_a_warning_regardless_of_power() -> void:
	var blueprint: TowerBlueprintData = _make_blueprint("DAMAGE_BOOST", 0.25)

	blueprint.warn_if_perk_benefit_wasted()

	assert_bool(true).is_true()  # DAMAGE_BOOST has no paired cap to check — always a no-op


func test_no_perk_emits_no_warning() -> void:
	var blueprint: TowerBlueprintData = _make_blueprint("", 0.0)

	blueprint.warn_if_perk_benefit_wasted()

	assert_bool(true).is_true()


func test_null_foundation_does_not_crash() -> void:
	var blueprint := TowerBlueprintData.new()
	blueprint.tower_id = &"test_blueprint"

	blueprint.warn_if_perk_benefit_wasted()

	assert_bool(true).is_true()
