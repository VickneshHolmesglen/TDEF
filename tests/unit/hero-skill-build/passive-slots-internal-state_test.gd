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
	# phys_bulwark has passive_slot_count = 2. sup_mod_faster_casting's
	# requires_tag is "any" (2026-09-02, Rule 13's typed-slot check) — it is
	# compatible with every skill, so it's used wherever a test only needs
	# ANY valid equip to succeed, not a specific tag match.
	var result: bool = _hero_skill_build.set_passive_slot("phys_bulwark", 0, "sup_mod_faster_casting")

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
	# phys_shatter_slam has passive_slot_count = 2 and tags = [Melee, Area] —
	# sup_mod_ruthless (requires_tag Melee) and sup_mod_increased_aoe
	# (requires_tag Area) are both real, tag-compatible skill-modifier items.
	_hero_skill_build.set_passive_slot("phys_shatter_slam", 0, "sup_mod_ruthless")
	_hero_skill_build.set_passive_slot("phys_shatter_slam", 1, "sup_mod_increased_aoe")

	var loadout: Array[String] = _hero_skill_build.get_passive_loadout("phys_shatter_slam")

	assert_array(loadout).contains_exactly(["sup_mod_ruthless", "sup_mod_increased_aoe"])


func test_get_passive_loadout_empty_for_never_equipped_skill() -> void:
	var loadout: Array[String] = _hero_skill_build.get_passive_loadout("phys_bulwark")
	assert_array(loadout).is_empty()


func test_set_passive_slot_clears_with_empty_string() -> void:
	_hero_skill_build.set_passive_slot("phys_bulwark", 0, "sup_mod_faster_casting")
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


# ---------------------------------------------------------------------------
# Rule 13 (revised 2026-09-01): typed passive slots — requires_tag must
# match the socketed skill's own effect_data.tags, or be "any".
# ---------------------------------------------------------------------------

func test_set_passive_slot_accepts_a_tag_compatible_skill_modifier() -> void:
	# phys_shatter_slam tags = [Melee, Area]; sup_mod_ruthless requires Melee.
	var result: bool = _hero_skill_build.set_passive_slot("phys_shatter_slam", 0, "sup_mod_ruthless")
	assert_bool(result).is_true()


func test_set_passive_slot_rejects_a_tag_incompatible_skill_modifier() -> void:
	# phys_shatter_slam tags = [Melee, Area]; sup_mod_totem_life requires Totem.
	var result: bool = _hero_skill_build.set_passive_slot("phys_shatter_slam", 0, "sup_mod_totem_life")
	assert_bool(result).is_false()
	assert_array(_hero_skill_build.get_passive_loadout("phys_shatter_slam")).is_empty()


func test_set_passive_slot_accepts_an_any_tag_skill_modifier_on_any_skill() -> void:
	# sup_mod_faster_casting's requires_tag is "any" -- compatible regardless
	# of the socketed skill's own tags.
	var result: bool = _hero_skill_build.set_passive_slot("phys_bulwark", 0, "sup_mod_faster_casting")
	assert_bool(result).is_true()


func test_set_passive_slot_rejects_a_non_skill_modifier_item() -> void:
	# common_scrap is a real, registered item but item_type == "Material",
	# not "skill_modifier" -- must be rejected regardless of tags.
	var result: bool = _hero_skill_build.set_passive_slot("phys_shatter_slam", 0, "common_scrap")
	assert_bool(result).is_false()


func test_set_passive_slot_rejects_an_unresolvable_item_id() -> void:
	var result: bool = _hero_skill_build.set_passive_slot("phys_shatter_slam", 0, "no_such_item")
	assert_bool(result).is_false()


func test_set_passive_slot_clearing_with_empty_string_bypasses_the_type_check() -> void:
	_hero_skill_build.set_passive_slot("phys_shatter_slam", 0, "sup_mod_ruthless")
	var result: bool = _hero_skill_build.set_passive_slot("phys_shatter_slam", 0, "")
	assert_bool(result).is_true()


# ---------------------------------------------------------------------------
# TD-hero-skill-002 resolution: requires_damage_type/requires_secondary_effect
# gating axes (sibling to requires_tag).
# ---------------------------------------------------------------------------

func test_set_passive_slot_accepts_a_damage_type_compatible_skill_modifier() -> void:
	# elem_frostbolt's damage_type is "frost"; sup_mod_elemental_focus
	# requires_damage_type includes "frost".
	var result: bool = _hero_skill_build.set_passive_slot("elem_frostbolt", 0, "sup_mod_elemental_focus")
	assert_bool(result).is_true()


func test_set_passive_slot_rejects_a_damage_type_incompatible_skill_modifier() -> void:
	# sup_mod_immolate requires_damage_type is ["fire"] only; frost doesn't match.
	var result: bool = _hero_skill_build.set_passive_slot("elem_frostbolt", 0, "sup_mod_immolate")
	assert_bool(result).is_false()


func test_set_passive_slot_accepts_a_secondary_effect_compatible_skill_modifier() -> void:
	# elem_poison_nova's secondary_effect is "dot_poison"; sup_mod_vile_toxins
	# requires_secondary_effect includes "dot_poison".
	var result: bool = _hero_skill_build.set_passive_slot("elem_poison_nova", 0, "sup_mod_vile_toxins")
	assert_bool(result).is_true()
