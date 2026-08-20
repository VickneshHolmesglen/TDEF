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
