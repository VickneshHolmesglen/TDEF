## Unit tests for Formula 6's pure quantity term,
## ResourceEconomy._compute_surplus_quantity() (design/gdd/resource-economy.md
## Rule 11, Tower Components, 2026-08-17).
extends GdUnitTestSuite


func test_tier_1_grants_base_quantity() -> void:
	assert_int(ResourceEconomy._compute_surplus_quantity(1)).is_equal(1)


func test_tier_4_scales_linearly_with_tier() -> void:
	assert_int(ResourceEconomy._compute_surplus_quantity(4)).is_equal(4)


func test_tier_0_boundary_grants_zero() -> void:
	assert_int(ResourceEconomy._compute_surplus_quantity(0)).is_equal(0)


## Difficulty reward multiplier (DifficultyRewards, 2026-11-02): material
## quantities scale by the tier multiplier; Normal (1.0) leaves them unchanged.
func test_resource_economy_tier_multiplier_scales_quantity() -> void:
	# Arrange
	var economy := ResourceEconomy.new()
	# Act
	var normal: int = economy._scale_by_tier(10)
	economy.set_tier_reward_multiplier(DifficultyRewards.multiplier_for_tier(3))
	var brutal: int = economy._scale_by_tier(10)
	# Assert
	assert_int(normal).is_equal(10)
	assert_int(brutal).is_equal(17)
	economy.free()
