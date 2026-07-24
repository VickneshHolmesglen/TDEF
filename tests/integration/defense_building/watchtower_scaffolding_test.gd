## Integration tests for Story 021 (TR-defbuild-001, Watchtower half; ADR-0024):
## the Watchtower single-tier structure's content and tech-gate eligibility.
##
## Scope note: only AC-16 is implementable here — AC-17 (full build resolution
## with gold/material debit and sanctuary_structure_built emission) is
## explicitly DEFERRED (see story-021-watchtower-scaffolding.md's Completion
## Notes / Dependencies) until Story 022 (gold debit), Story 023 (atomic
## resolution sequence), and Story 025 (authored cost values) all land. No
## test function exists here for AC-17 — do not fake it.
##
## AC-16 requires zero new production code: DefenseBuilding.can_build_structure()
## (Story 020) already handles any StructureResource's tech_gate field
## generically — this story is purely the watchtower_tier_1.tres content plus
## these tests, exercised via the real GGameDataRegistry Autoload content (no
## fixture injection), same rationale as every other defense_building test.
extends GdUnitTestSuite

const WATCHTOWER_TIER_1: StringName = &"watchtower_tier_1"
const TECH_STRUCTURAL_1: StringName = &"tech_structural_1"

var _defense_building: DefenseBuilding


func before_test() -> void:
	_defense_building = DefenseBuilding.new()


func after_test() -> void:
	if _defense_building != null and is_instance_valid(_defense_building):
		_defense_building.free()
	_defense_building = null


# ---------------------------------------------------------------------------
# Content check — structure_type is "watchtower", distinct from
# "habitat_expansion" (proves the schema generalizes beyond one structure
# family, per this story's own stated purpose).
# ---------------------------------------------------------------------------

func test_watchtower_tier_1_structure_type_is_watchtower() -> void:
	var structure: StructureResource = GGameDataRegistry.get_structure(WATCHTOWER_TIER_1)
	assert_object(structure).is_not_null()
	assert_str(structure.structure_type).is_equal("watchtower")
	assert_str(structure.structure_type).is_not_equal("habitat_expansion")


func test_watchtower_tier_1_is_untiered_with_no_prerequisite() -> void:
	var structure: StructureResource = GGameDataRegistry.get_structure(WATCHTOWER_TIER_1)
	assert_object(structure).is_not_null()
	assert_that(structure.prerequisite_structure_id).is_equal(&"")
	assert_that(structure.tech_gate).is_equal(TECH_STRUCTURAL_1)


# ---------------------------------------------------------------------------
# AC-16: tech_structural_1 NOT UNLOCKED -> watchtower_tier_1 rejected at the
# tech-gate check — identical mechanical shape to Story 020's AC-11.
# ---------------------------------------------------------------------------

func test_can_build_structure_watchtower_tier_1_rejected_when_tech_gate_not_unlocked() -> void:
	assert_bool(_defense_building.is_tech_unlocked(TECH_STRUCTURAL_1)).is_false()
	assert_bool(_defense_building.can_build_structure(WATCHTOWER_TIER_1)).is_false()


func test_can_build_structure_watchtower_tier_1_eligible_once_tech_gate_unlocked() -> void:
	_defense_building._tech_ledger[TECH_STRUCTURAL_1] = true
	assert_bool(_defense_building.can_build_structure(WATCHTOWER_TIER_1)).is_true()
