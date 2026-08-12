## Unit tests for Story 002 (TR-buildupgrade-001, ADR-0034): the 2 new
## content-validation checks added to BuildingUpgradeResource beyond its
## pre-existing (2026-08-11) validate() — cross-structure prerequisite
## rejection and same-structure prerequisite chain cycle/length rejection
## (GDD Rule 1a/1b). See:
## - src/core/building_upgrade/building_upgrade_resource.gd (validate_chain())
## - src/core/game_data_registry.gd (_load_building_upgrades()'s second pass)
##
## Deliberately unit-tests validate()/validate_chain() directly against
## hand-built BuildingUpgradeResource instances, not through GameDataRegistry's
## filesystem loader — no external/filesystem state (test-standards.md).
## The one exception is target_structure_id, which validate()'s pre-existing
## (out of this story's scope) cross-reference check resolves against the
## REAL GGameDataRegistry Autoload content — "watchtower_tier_1" and
## "habitat_expansion_tier_1" are both real, already-authored structure_ids
## (same ones building_upgrade_test.gd's own real .tres content already
## exercises), so using them here keeps every assertion focused on this
## story's own 2 new checks rather than on an unrelated missing-structure error.
extends GdUnitTestSuite

const STRUCTURE_A: StringName = &"watchtower_tier_1"
const STRUCTURE_B: StringName = &"habitat_expansion_tier_1"


func _make_upgrade(id: StringName, target_structure_id: StringName, prerequisite_upgrade_id: StringName = &"") -> BuildingUpgradeResource:
	var upgrade := BuildingUpgradeResource.new()
	upgrade.upgrade_id = id
	upgrade.target_structure_id = target_structure_id
	upgrade.prerequisite_upgrade_id = prerequisite_upgrade_id
	upgrade.requirements = {"building": &"some_structure"}
	upgrade.gold_cost = 100
	return upgrade


# ---------------------------------------------------------------------------
# AC-12 — prerequisite chain cycle rejection
# ---------------------------------------------------------------------------

func test_validate_chain_self_referencing_prerequisite_rejected() -> void:
	var a: BuildingUpgradeResource = _make_upgrade(&"upgrade_a", STRUCTURE_A, &"upgrade_a")
	var all: Dictionary[StringName, BuildingUpgradeResource] = {&"upgrade_a": a}

	var errors: Array[String] = a.validate_chain(all)

	assert_bool(errors.any(func(e: String) -> bool: return e.contains("cycle"))).is_true()


func test_validate_chain_two_upgrade_cycle_rejected() -> void:
	var a: BuildingUpgradeResource = _make_upgrade(&"upgrade_a", STRUCTURE_A, &"upgrade_b")
	var b: BuildingUpgradeResource = _make_upgrade(&"upgrade_b", STRUCTURE_A, &"upgrade_a")
	var all: Dictionary[StringName, BuildingUpgradeResource] = {&"upgrade_a": a, &"upgrade_b": b}

	var errors: Array[String] = a.validate_chain(all)

	assert_bool(errors.any(func(e: String) -> bool: return e.contains("cycle"))).is_true()


func test_validate_chain_three_upgrade_cycle_rejected() -> void:
	var a: BuildingUpgradeResource = _make_upgrade(&"upgrade_a", STRUCTURE_A, &"upgrade_c")
	var b: BuildingUpgradeResource = _make_upgrade(&"upgrade_b", STRUCTURE_A, &"upgrade_a")
	var c: BuildingUpgradeResource = _make_upgrade(&"upgrade_c", STRUCTURE_A, &"upgrade_b")
	var all: Dictionary[StringName, BuildingUpgradeResource] = {&"upgrade_a": a, &"upgrade_b": b, &"upgrade_c": c}

	var errors: Array[String] = a.validate_chain(all)

	assert_bool(errors.any(func(e: String) -> bool: return e.contains("cycle"))).is_true()


func test_validate_chain_no_prerequisite_returns_empty_array() -> void:
	var a: BuildingUpgradeResource = _make_upgrade(&"upgrade_a", STRUCTURE_A)
	var all: Dictionary[StringName, BuildingUpgradeResource] = {&"upgrade_a": a}

	assert_array(a.validate_chain(all)).is_empty()


## A cycle longer than the depth cap (3) is rejected via the chain-length
## error, not the cycle error — the depth cap fires before the walk ever
## revisits the starting node. Both are rejected either way (see
## validate_chain()'s own doc comment); this test documents which specific
## message a 4-node cycle actually produces, closing a gap found during
## /code-review (qa-tester).
func test_validate_chain_four_node_cycle_rejected_via_chain_length_not_cycle_message() -> void:
	var a: BuildingUpgradeResource = _make_upgrade(&"upgrade_a", STRUCTURE_A, &"upgrade_d")
	var b: BuildingUpgradeResource = _make_upgrade(&"upgrade_b", STRUCTURE_A, &"upgrade_a")
	var c: BuildingUpgradeResource = _make_upgrade(&"upgrade_c", STRUCTURE_A, &"upgrade_b")
	var d: BuildingUpgradeResource = _make_upgrade(&"upgrade_d", STRUCTURE_A, &"upgrade_c")
	var all: Dictionary[StringName, BuildingUpgradeResource] = {&"upgrade_a": a, &"upgrade_b": b, &"upgrade_c": c, &"upgrade_d": d}

	var errors: Array[String] = a.validate_chain(all)

	assert_bool(errors.any(func(e: String) -> bool: return e.contains("exceeds the maximum of 3"))).is_true()


func test_validate_chain_unrecognized_prerequisite_id_rejected() -> void:
	var a: BuildingUpgradeResource = _make_upgrade(&"upgrade_a", STRUCTURE_A, &"upgrade_does_not_exist")
	var all: Dictionary[StringName, BuildingUpgradeResource] = {&"upgrade_a": a}

	var errors: Array[String] = a.validate_chain(all)

	assert_bool(errors.any(func(e: String) -> bool: return e.contains("unknown upgrade_id"))).is_true()


# ---------------------------------------------------------------------------
# AC-13 — prerequisite chain length cap (boundary at 3)
# ---------------------------------------------------------------------------

func test_validate_chain_exactly_three_chained_upgrades_passes() -> void:
	var a: BuildingUpgradeResource = _make_upgrade(&"upgrade_a", STRUCTURE_A)
	var b: BuildingUpgradeResource = _make_upgrade(&"upgrade_b", STRUCTURE_A, &"upgrade_a")
	var c: BuildingUpgradeResource = _make_upgrade(&"upgrade_c", STRUCTURE_A, &"upgrade_b")
	var all: Dictionary[StringName, BuildingUpgradeResource] = {&"upgrade_a": a, &"upgrade_b": b, &"upgrade_c": c}

	assert_array(a.validate_chain(all)).is_empty()
	assert_array(b.validate_chain(all)).is_empty()
	assert_array(c.validate_chain(all)).is_empty()


func test_validate_chain_exactly_four_chained_upgrades_fails() -> void:
	var a: BuildingUpgradeResource = _make_upgrade(&"upgrade_a", STRUCTURE_A)
	var b: BuildingUpgradeResource = _make_upgrade(&"upgrade_b", STRUCTURE_A, &"upgrade_a")
	var c: BuildingUpgradeResource = _make_upgrade(&"upgrade_c", STRUCTURE_A, &"upgrade_b")
	var d: BuildingUpgradeResource = _make_upgrade(&"upgrade_d", STRUCTURE_A, &"upgrade_c")
	var all: Dictionary[StringName, BuildingUpgradeResource] = {&"upgrade_a": a, &"upgrade_b": b, &"upgrade_c": c, &"upgrade_d": d}

	var errors: Array[String] = d.validate_chain(all)

	assert_bool(errors.any(func(e: String) -> bool: return e.contains("exceeds the maximum of 3"))).is_true()


# ---------------------------------------------------------------------------
# Rule 1b — unrecognized requirements key (pre-existing validate() behavior;
# confirmed here per this story's own QA Test Cases, not skipped as "already
# passing")
# ---------------------------------------------------------------------------

func test_validate_requirements_unrecognized_key_rejected() -> void:
	var a: BuildingUpgradeResource = _make_upgrade(&"upgrade_a", STRUCTURE_A)
	a.requirements = {"unknown_category": &"whatever"}

	var errors: Array[String] = a.validate()

	assert_bool(errors.any(func(e: String) -> bool: return e.contains("is not a valid requirement type"))).is_true()


# ---------------------------------------------------------------------------
# Rule 1b — cross-structure prerequisite rejection
# ---------------------------------------------------------------------------

func test_validate_chain_cross_structure_prerequisite_rejected() -> void:
	var a: BuildingUpgradeResource = _make_upgrade(&"upgrade_a", STRUCTURE_A)
	var b: BuildingUpgradeResource = _make_upgrade(&"upgrade_b", STRUCTURE_B, &"upgrade_a")
	var all: Dictionary[StringName, BuildingUpgradeResource] = {&"upgrade_a": a, &"upgrade_b": b}

	var errors: Array[String] = b.validate_chain(all)

	assert_bool(errors.any(func(e: String) -> bool: return e.contains("targets a different structure"))).is_true()


func test_validate_chain_same_structure_prerequisite_accepted() -> void:
	var a: BuildingUpgradeResource = _make_upgrade(&"upgrade_a", STRUCTURE_A)
	var b: BuildingUpgradeResource = _make_upgrade(&"upgrade_b", STRUCTURE_A, &"upgrade_a")
	var all: Dictionary[StringName, BuildingUpgradeResource] = {&"upgrade_a": a, &"upgrade_b": b}

	assert_array(b.validate_chain(all)).is_empty()
