## Unit tests for Tarot card unlocking via Defense Building's tech tree
## (TarotCardResource.unlock_tech_id, Tarot.is_card_unlocked()).
##
## Closes tarot.md's previously-flagged "how a Tarot card becomes unlocked"
## Open Question — is_card_unlocked() now OR-combines the existing
## `_card_unlocked` seam (a future non-tech unlock source, e.g. Encyclopedia
## purchase, plus the pre-existing test seam) with a live, pull-based
## GDefenseBuilding.is_tech_unlocked() check, matching Crafting's own
## recipe-tier tech-gate pattern (crafting.gd).
##
## GDefenseBuilding is a real, persistent Autoload (TD-test-004 convention,
## see building_upgrade_test.gd) — reset directly in before_test()/
## after_test() rather than instantiated locally, since is_card_unlocked()
## reads the Autoload singleton by name, not an injected instance.
extends GdUnitTestSuite

## Common rarity, unlock_tech_id = "" (assets/data/tarot/card_iron_resolve.tres).
const UNGATED_CARD: StringName = &"iron_resolve"

## Rare rarity, unlock_tech_id = &"tech_production_2" (assets/data/tarot/card_bountiful_harvest.tres).
const GATED_CARD: StringName = &"bountiful_harvest"
const GATED_CARD_TECH: StringName = &"tech_production_2"

## An unrelated, real tech node — used to prove unlocking the WRONG tech
## does not accidentally satisfy GATED_CARD's gate.
const UNRELATED_TECH: StringName = &"tech_structural_1"

var _tarot: Tarot


func before_test() -> void:
	_tarot = Tarot.new()
	GDefenseBuilding.reset_to_defaults()


func after_test() -> void:
	if _tarot != null and is_instance_valid(_tarot):
		_tarot.free()
	_tarot = null
	GDefenseBuilding.reset_to_defaults()


func test_ungated_common_card_is_unlocked_with_no_tech_unlocked() -> void:
	assert_bool(_tarot.is_card_unlocked(UNGATED_CARD)).is_true()


func test_tech_gated_card_is_locked_before_its_tech_is_unlocked() -> void:
	assert_bool(_tarot.is_card_unlocked(GATED_CARD)).is_false()


func test_tech_gated_card_unlocks_once_its_tech_is_unlocked() -> void:
	GDefenseBuilding._tech_ledger[GATED_CARD_TECH] = true
	assert_bool(_tarot.is_card_unlocked(GATED_CARD)).is_true()


func test_tech_gated_card_stays_locked_when_an_unrelated_tech_unlocks() -> void:
	GDefenseBuilding._tech_ledger[UNRELATED_TECH] = true
	assert_bool(_tarot.is_card_unlocked(GATED_CARD)).is_false()


## The pre-existing test seam (a future non-tech unlock source) still works
## independent of Defense Building state — is_card_unlocked() checks
## _card_unlocked first, an OR branch, never the only path.
func test_manual_unlock_seam_still_unlocks_a_tech_gated_card_without_its_tech() -> void:
	_tarot._card_unlocked[GATED_CARD] = true
	assert_bool(_tarot.is_card_unlocked(GATED_CARD)).is_true()


func test_equip_gated_card_succeeds_once_its_tech_is_unlocked() -> void:
	assert_bool(_tarot.equip_card(GATED_CARD)).is_false()

	GDefenseBuilding._tech_ledger[GATED_CARD_TECH] = true

	assert_bool(_tarot.equip_card(GATED_CARD)).is_true()
	assert_int(_tarot.get_active_card_count()).is_equal(1)


func test_unknown_card_id_is_never_unlocked_regardless_of_tech_state() -> void:
	GDefenseBuilding._tech_ledger[GATED_CARD_TECH] = true
	assert_bool(_tarot.is_card_unlocked(&"not_a_real_card")).is_false()
