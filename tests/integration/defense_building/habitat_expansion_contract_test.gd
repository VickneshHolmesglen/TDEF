## Integration tests for Story 020 (TR-defbuild-002, ADR-0024): the Habitat
## Expansion structure contract — structure_id/structure_type content on the
## authored StructureResource .tres files, and DefenseBuilding's
## can_build_structure() combined eligibility check (tier-sequence
## prerequisite AND tech-gate, both evaluated together per the story's
## Implementation Notes).
##
## Exercises the real, authored res://assets/data/defense_building/structures/
## content via the GGameDataRegistry Autoload (no fixture injection) — same
## rationale as Story 018/019's tech-node tests: these ACs are specifically
## about the actual chain this project authors, not a synthetic stand-in.
##
## 2026-08-03: extended from Story 020's original 3-tier chain to 4 tiers
## (habitat_expansion_tier_4 + tech_structural_3, see design/quick-specs/
## habitat-expansion-tier-4-2026-08-03.md) — AC-7/AC-8 now assert all four
## tiers, and the AC-11/AC-12/AC-13/AC-14 tier-sequence/tech-gate rejection
## pattern is mirrored for tier 4 below.
##
## Deliberately NOT covered here (out of scope, Story 022/023): gold/material
## cost-affordability gating, _action_resolving guard, sanctuary_structure_built
## event emission. can_build_structure() is a read-only eligibility check
## only — it never touches Inventory, gold/materials, or emits any signal,
## and these tests never assert anything about them.
extends GdUnitTestSuite

const HABITAT_TIER_1: StringName = &"habitat_expansion_tier_1"
const HABITAT_TIER_2: StringName = &"habitat_expansion_tier_2"
const HABITAT_TIER_3: StringName = &"habitat_expansion_tier_3"
const HABITAT_TIER_4: StringName = &"habitat_expansion_tier_4"
const TECH_STRUCTURAL_1: StringName = &"tech_structural_1"
const TECH_STRUCTURAL_2: StringName = &"tech_structural_2"
const TECH_STRUCTURAL_3: StringName = &"tech_structural_3"

var _defense_building: DefenseBuilding


func before_test() -> void:
	_defense_building = DefenseBuilding.new()


func after_test() -> void:
	if _defense_building != null and is_instance_valid(_defense_building):
		_defense_building.free()
	_defense_building = null


# ---------------------------------------------------------------------------
# AC-7: structure_id values are exactly habitat_expansion_tier_1/_2/_3/_4
# ---------------------------------------------------------------------------

func test_structure_ids_are_exactly_habitat_expansion_tier_1_2_3_4() -> void:
	assert_that(GGameDataRegistry.get_structure(HABITAT_TIER_1).structure_id).is_equal(HABITAT_TIER_1)
	assert_that(GGameDataRegistry.get_structure(HABITAT_TIER_2).structure_id).is_equal(HABITAT_TIER_2)
	assert_that(GGameDataRegistry.get_structure(HABITAT_TIER_3).structure_id).is_equal(HABITAT_TIER_3)
	assert_that(GGameDataRegistry.get_structure(HABITAT_TIER_4).structure_id).is_equal(HABITAT_TIER_4)


# ---------------------------------------------------------------------------
# AC-8: structure_type is the literal string "habitat_expansion" on all 4
# ---------------------------------------------------------------------------

func test_structure_type_is_habitat_expansion_on_all_four_tiers() -> void:
	assert_str(GGameDataRegistry.get_structure(HABITAT_TIER_1).structure_type).is_equal("habitat_expansion")
	assert_str(GGameDataRegistry.get_structure(HABITAT_TIER_2).structure_type).is_equal("habitat_expansion")
	assert_str(GGameDataRegistry.get_structure(HABITAT_TIER_3).structure_type).is_equal("habitat_expansion")
	assert_str(GGameDataRegistry.get_structure(HABITAT_TIER_4).structure_type).is_equal("habitat_expansion")


# ---------------------------------------------------------------------------
# AC-9: DEFERRED — exact 2-field sanctuary_structure_built payload shape
# requires the actual event-emission mechanism, which is Story 022/023
# scope (build-resolution sequence). No emission code exists yet in this
# story to assert against — mirrors Story 018's deferral of its own AC-2 for
# the identical reason. Do not fake a partial/test-only emission shortcut to
# force this to pass.
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# AC-10: no tech node UNLOCKED, tier 1 attempted -> tech-gate passes
# unconditionally (tech_gate == "")
# ---------------------------------------------------------------------------

func test_can_build_structure_tier_1_from_fresh_ledger_returns_true() -> void:
	assert_bool(_defense_building.can_build_structure(HABITAT_TIER_1)).is_true()


# ---------------------------------------------------------------------------
# AC-11: tier 1 BUILT but tech_structural_1 NOT UNLOCKED -> tier 2 rejected
# at the tech-gate check even though the tier-sequence prerequisite is
# independently satisfied.
# ---------------------------------------------------------------------------

func test_can_build_structure_tier_2_rejected_when_tech_gate_not_unlocked_even_with_prerequisite_satisfied() -> void:
	_defense_building._structure_ledger[HABITAT_TIER_1] = true
	assert_bool(_defense_building.is_tech_unlocked(TECH_STRUCTURAL_1)).is_false()
	assert_bool(_defense_building.can_build_structure(HABITAT_TIER_2)).is_false()


# ---------------------------------------------------------------------------
# AC-12: tier 2 BUILT but tech_structural_2 NOT UNLOCKED -> tier 3 rejected
# identically to AC-11.
# ---------------------------------------------------------------------------

func test_can_build_structure_tier_3_rejected_when_tech_gate_not_unlocked_even_with_prerequisite_satisfied() -> void:
	_defense_building._structure_ledger[HABITAT_TIER_1] = true
	_defense_building._structure_ledger[HABITAT_TIER_2] = true
	_defense_building._tech_ledger[TECH_STRUCTURAL_1] = true
	assert_bool(_defense_building.is_tech_unlocked(TECH_STRUCTURAL_2)).is_false()
	assert_bool(_defense_building.can_build_structure(HABITAT_TIER_3)).is_false()


# ---------------------------------------------------------------------------
# 2026-08-03: tier 3 BUILT but tech_structural_3 NOT UNLOCKED -> tier 4
# rejected, identically to AC-11/AC-12.
# ---------------------------------------------------------------------------

func test_can_build_structure_tier_4_rejected_when_tech_gate_not_unlocked_even_with_prerequisite_satisfied() -> void:
	_defense_building._structure_ledger[HABITAT_TIER_1] = true
	_defense_building._structure_ledger[HABITAT_TIER_2] = true
	_defense_building._structure_ledger[HABITAT_TIER_3] = true
	_defense_building._tech_ledger[TECH_STRUCTURAL_1] = true
	_defense_building._tech_ledger[TECH_STRUCTURAL_2] = true
	assert_bool(_defense_building.is_tech_unlocked(TECH_STRUCTURAL_3)).is_false()
	assert_bool(_defense_building.can_build_structure(HABITAT_TIER_4)).is_false()


# ---------------------------------------------------------------------------
# AC-13: tier 1 NOT yet BUILT -> tier 2 rejected at the prerequisite-structure
# check — a later tier can never be purchased before its predecessor.
# ---------------------------------------------------------------------------

func test_can_build_structure_tier_2_rejected_when_tier_1_not_built() -> void:
	assert_bool(_defense_building.can_build_structure(HABITAT_TIER_2)).is_false()


# ---------------------------------------------------------------------------
# AC-14: tier 1 BUILT but tier 2 NOT -> tier 3 rejected identically to AC-13.
# ---------------------------------------------------------------------------

func test_can_build_structure_tier_3_rejected_when_tier_2_not_built() -> void:
	_defense_building._structure_ledger[HABITAT_TIER_1] = true
	assert_bool(_defense_building.can_build_structure(HABITAT_TIER_3)).is_false()


# ---------------------------------------------------------------------------
# 2026-08-03: tier 3 NOT yet BUILT -> tier 4 rejected, identically to
# AC-13/AC-14.
# ---------------------------------------------------------------------------

func test_can_build_structure_tier_4_rejected_when_tier_3_not_built() -> void:
	_defense_building._structure_ledger[HABITAT_TIER_1] = true
	_defense_building._structure_ledger[HABITAT_TIER_2] = true
	assert_bool(_defense_building.can_build_structure(HABITAT_TIER_4)).is_false()


# ---------------------------------------------------------------------------
# AC-15: DEFERRED — the full end-to-end happy-path sequence (Tier 1 built ->
# tech_structural_1 unlocked -> Tier 2 built -> tech_structural_2 unlocked ->
# Tier 3 built, in that exact order, each with a correct
# sanctuary_structure_built payload) requires the actual build-resolution/
# emission mechanism, which does not exist yet (Story 022/023 scope). No
# "build" mutation exists in this story beyond directly writing
# _structure_ledger in a test — asserting an end-to-end sequence would
# require fabricating the very resolution logic this story explicitly
# excludes. Mirrors Story 018's AC-2 deferral for the same reason.
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# AC-27: tier 1 already BUILT -> re-attempting a build on it returns false,
# no side effects (idempotency, same code path as an ineligible node).
# ---------------------------------------------------------------------------

func test_can_build_structure_already_built_tier_1_returns_false() -> void:
	_defense_building._structure_ledger[HABITAT_TIER_1] = true
	assert_bool(_defense_building.can_build_structure(HABITAT_TIER_1)).is_false()


func test_can_build_structure_already_built_reattempt_has_no_side_effects() -> void:
	_defense_building._structure_ledger[HABITAT_TIER_1] = true
	_defense_building.can_build_structure(HABITAT_TIER_1)
	assert_int(_defense_building._structure_ledger.size()).is_equal(1)
	assert_bool(_defense_building._structure_ledger[HABITAT_TIER_1]).is_true()


# ---------------------------------------------------------------------------
# Unknown structure_id — must not crash
# ---------------------------------------------------------------------------

func test_can_build_structure_unknown_structure_id_returns_false_not_crash() -> void:
	assert_bool(_defense_building.can_build_structure(&"structure_does_not_exist")).is_false()
