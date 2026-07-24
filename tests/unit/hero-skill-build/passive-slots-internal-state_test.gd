## Unit tests for Story 004 (TR-heroskill-001, ADR-0030): passive slots as
## internal state (AC-13/AC-14).
##
## HeroSkillBuild is instantiated directly (HeroSkillBuild.new(), no
## add_child()) — matching this project's established test convention.
extends GdUnitTestSuite

var _hero_skill_build: HeroSkillBuild
var _spy: EventBusSpy


func before_test() -> void:
	_hero_skill_build = HeroSkillBuild.new()
	_hero_skill_build._is_sanctuary = true
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.active_skill_equipped)
	_spy.watch(GEventBus.ultimate_skill_changed)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _hero_skill_build != null and is_instance_valid(_hero_skill_build):
		_hero_skill_build.free()
	_hero_skill_build = null


# ---------------------------------------------------------------------------
# AC-13: no event for passive-only change; active-slot changes still emit
# ---------------------------------------------------------------------------

func test_passive_slot_change_emits_no_eventbus_event() -> void:
	# phys_bulwark has passive_slot_count = 2.
	var result: bool = _hero_skill_build.set_passive_slot("phys_bulwark", 0, "some_item_id")

	assert_bool(result).is_true()
	assert_bool(_spy.was_emitted("active_skill_equipped")).is_false()
	assert_bool(_spy.was_emitted("ultimate_skill_changed")).is_false()


func test_active_slot_change_still_emits_as_normal() -> void:
	# Same starting state as the passive-only test, but exercising an
	# active-slot change instead — proves the "no event" resolution is
	# scoped strictly to passive-slot changes, not a blanket suppression.
	_hero_skill_build.set_active_slot(0, "phys_cleave")

	assert_bool(_spy.was_emitted("active_skill_equipped")).is_true()
	assert_bool(_spy.was_emitted("ultimate_skill_changed")).is_true()


# ---------------------------------------------------------------------------
# AC-14: synchronous pull, not push
# ---------------------------------------------------------------------------

func test_get_passive_loadout_returns_equipped_item_synchronously() -> void:
	_hero_skill_build.set_passive_slot("phys_bulwark", 0, "item_a")
	_hero_skill_build.set_passive_slot("phys_bulwark", 1, "item_b")

	var loadout: Array[String] = _hero_skill_build.get_passive_loadout("phys_bulwark")

	assert_array(loadout).contains_exactly(["item_a", "item_b"])


func test_get_passive_loadout_empty_for_never_equipped_skill() -> void:
	var loadout: Array[String] = _hero_skill_build.get_passive_loadout("phys_bulwark")
	assert_array(loadout).is_empty()


func test_set_passive_slot_clears_with_empty_string() -> void:
	_hero_skill_build.set_passive_slot("phys_bulwark", 0, "item_a")
	_hero_skill_build.set_passive_slot("phys_bulwark", 0, "")

	var loadout: Array[String] = _hero_skill_build.get_passive_loadout("phys_bulwark")
	assert_str(loadout[0]).is_equal("")


# ---------------------------------------------------------------------------
# Bounds: slot_index constrained by the skill's own passive_slot_count
# ---------------------------------------------------------------------------

func test_set_passive_slot_rejects_index_beyond_passive_slot_count() -> void:
	# phys_cleave has passive_slot_count = 1 — index 1 is out of bounds.
	var result: bool = _hero_skill_build.set_passive_slot("phys_cleave", 1, "item_a")
	assert_bool(result).is_false()


func test_set_passive_slot_rejects_negative_index() -> void:
	var result: bool = _hero_skill_build.set_passive_slot("phys_bulwark", -1, "item_a")
	assert_bool(result).is_false()


func test_set_passive_slot_rejects_unknown_skill_id() -> void:
	var result: bool = _hero_skill_build.set_passive_slot("no_such_skill", 0, "item_a")
	assert_bool(result).is_false()


# ---------------------------------------------------------------------------
# Sanctuary-only write gating (Rule 3, consistent with active-slot writes)
# ---------------------------------------------------------------------------

func test_set_passive_slot_rejected_while_locked() -> void:
	_hero_skill_build._is_sanctuary = false
	var result: bool = _hero_skill_build.set_passive_slot("phys_bulwark", 0, "item_a")
	assert_bool(result).is_false()
	assert_array(_hero_skill_build.get_passive_loadout("phys_bulwark")).is_empty()
