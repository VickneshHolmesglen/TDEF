## Unit tests for Story 019 (TR-defbuild-001, chain-enforcement half; ADR-0024):
## DefenseBuilding's is_tech_unlocked() and can_unlock_tech() prerequisite-
## chain eligibility checks.
##
## Exercises the real, authored res://assets/data/defense_building/tech_nodes/
## content via the GGameDataRegistry Autoload (no fixture injection) — same
## rationale as tech_structure_data_schema_test.gd: these ACs are specifically
## about the actual five-node chain this project authors (tech_production_2 ->
## _3 -> _4, tech_structural_1 -> _2), not a synthetic stand-in.
##
## Deliberately NOT covered here (out of scope, Story 022/023): gold/material
## cost-affordability gating, _action_resolving guard, tech_unlocked event
## emission. can_unlock_tech() is a read-only eligibility check only — it
## never touches Inventory, gold/materials, or emits any signal, and these
## tests never assert anything about them.
extends GdUnitTestSuite

const TECH_PRODUCTION_2: StringName = &"tech_production_2"
const TECH_PRODUCTION_3: StringName = &"tech_production_3"
const TECH_PRODUCTION_4: StringName = &"tech_production_4"
const TECH_STRUCTURAL_1: StringName = &"tech_structural_1"
const TECH_STRUCTURAL_2: StringName = &"tech_structural_2"

var _defense_building: DefenseBuilding


func before_test() -> void:
	_defense_building = DefenseBuilding.new()


func after_test() -> void:
	if _defense_building != null and is_instance_valid(_defense_building):
		_defense_building.free()
	_defense_building = null


# ---------------------------------------------------------------------------
# is_tech_unlocked()
# ---------------------------------------------------------------------------

func test_is_tech_unlocked_never_seen_tech_id_returns_false() -> void:
	assert_bool(_defense_building.is_tech_unlocked(TECH_PRODUCTION_2)).is_false()


func test_is_tech_unlocked_ledger_true_returns_true() -> void:
	_defense_building._tech_ledger[TECH_PRODUCTION_2] = true
	assert_bool(_defense_building.is_tech_unlocked(TECH_PRODUCTION_2)).is_true()


# ---------------------------------------------------------------------------
# can_unlock_tech(): AC-4 — prerequisite not met, rejected before any cost
# check (no cost check exists yet in this story's scope, so these tests only
# assert the eligibility result itself and that no ledger mutation occurs).
# ---------------------------------------------------------------------------

func test_can_unlock_tech_production_3_before_production_2_returns_false() -> void:
	assert_bool(_defense_building.can_unlock_tech(TECH_PRODUCTION_3)).is_false()


func test_can_unlock_tech_production_4_before_production_3_returns_false() -> void:
	# tech_production_2 unlocked but _3 is still not — _4's own immediate
	# prerequisite (_3) is what's checked, not the whole chain transitively.
	_defense_building._tech_ledger[TECH_PRODUCTION_2] = true
	assert_bool(_defense_building.can_unlock_tech(TECH_PRODUCTION_4)).is_false()


func test_can_unlock_tech_structural_2_before_structural_1_returns_false() -> void:
	assert_bool(_defense_building.can_unlock_tech(TECH_STRUCTURAL_2)).is_false()


func test_can_unlock_tech_rejection_has_no_side_effects_on_ledger() -> void:
	_defense_building.can_unlock_tech(TECH_PRODUCTION_3)
	assert_int(_defense_building._tech_ledger.size()).is_equal(0)
	assert_bool(_defense_building.is_tech_unlocked(TECH_PRODUCTION_3)).is_false()


# ---------------------------------------------------------------------------
# can_unlock_tech(): AC-5 — prerequisite satisfied, proceeds to eligible
# (prerequisite satisfaction alone does not bypass the later, out-of-scope
# cost gate — it only proves this method returns true so that flow CAN
# proceed to that gate; this method itself never touches cost).
# ---------------------------------------------------------------------------

func test_can_unlock_tech_production_3_after_production_2_unlocked_returns_true() -> void:
	_defense_building._tech_ledger[TECH_PRODUCTION_2] = true
	assert_bool(_defense_building.can_unlock_tech(TECH_PRODUCTION_3)).is_true()


func test_can_unlock_tech_root_node_with_empty_ledger_returns_true() -> void:
	# tech_production_2's own prerequisite_tech_id is "" (root node) — eligible
	# from a completely empty ledger, no prior unlocks required.
	assert_bool(_defense_building.can_unlock_tech(TECH_PRODUCTION_2)).is_true()


# ---------------------------------------------------------------------------
# can_unlock_tech(): AC-6 — independent chains
# ---------------------------------------------------------------------------

func test_can_unlock_tech_independent_chains_structural_unlock_does_not_affect_production_eligibility() -> void:
	_defense_building._tech_ledger[TECH_STRUCTURAL_1] = true
	assert_bool(_defense_building.can_unlock_tech(TECH_STRUCTURAL_2)).is_true()
	assert_bool(_defense_building.can_unlock_tech(TECH_PRODUCTION_3)).is_false()


func test_can_unlock_tech_independent_chains_production_unlock_does_not_affect_structural_eligibility() -> void:
	_defense_building._tech_ledger[TECH_PRODUCTION_2] = true
	assert_bool(_defense_building.can_unlock_tech(TECH_PRODUCTION_3)).is_true()
	assert_bool(_defense_building.can_unlock_tech(TECH_STRUCTURAL_2)).is_false()


# ---------------------------------------------------------------------------
# can_unlock_tech(): AC-26 — already-unlocked idempotency (same code path
# as an unmet prerequisite — rejected before any cost check, no duplicate
# tech_unlocked, which this method never emits in the first place).
# ---------------------------------------------------------------------------

func test_can_unlock_tech_already_unlocked_node_returns_false() -> void:
	_defense_building._tech_ledger[TECH_PRODUCTION_2] = true
	assert_bool(_defense_building.can_unlock_tech(TECH_PRODUCTION_2)).is_false()


func test_can_unlock_tech_already_unlocked_reattempt_has_no_side_effects() -> void:
	_defense_building._tech_ledger[TECH_PRODUCTION_2] = true
	_defense_building.can_unlock_tech(TECH_PRODUCTION_2)
	assert_int(_defense_building._tech_ledger.size()).is_equal(1)
	assert_bool(_defense_building._tech_ledger[TECH_PRODUCTION_2]).is_true()


# ---------------------------------------------------------------------------
# can_unlock_tech(): unknown tech_id — must not crash
# ---------------------------------------------------------------------------

func test_can_unlock_tech_unknown_tech_id_returns_false_not_crash() -> void:
	assert_bool(_defense_building.can_unlock_tech(&"tech_does_not_exist")).is_false()
