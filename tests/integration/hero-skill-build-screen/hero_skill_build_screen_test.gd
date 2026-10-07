## Integration tests for HeroSkillBuildScreen (src/gameplay/ui/
## hero_skill_build_screen), Tarot Deck UI Story 001's Room Hosting scope.
## Exercises the screen against hero-skill-build.md's UI Requirements:
## library + 4 active slots + Ultimate readout + simplified passive-cycle
## assignment (see the screen's own doc comment for the honestly-scoped
## deviations from the GDD's literal pick-up-then-place / nested-socket
## wording).
##
## HeroSkillBuild IS a real Autoload (GHeroSkillBuild), unlike Tarot/
## EquipmentForge -- the screen defaults directly to it, matching
## menagerie_screen_test.gd's/defense_building_screen_test.gd's own
## established pattern (reset in before_test()/after_test(), populated
## directly via internal fields the same way this project's own
## hero-skill-build unit tests already do).
extends GdUnitTestSuite

const SKILL_PHYS_CLEAVE: StringName = &"phys_cleave"
const SKILL_PHYS_BULWARK: StringName = &"phys_bulwark"
const SKILL_RNG_PIERCING: StringName = &"rng_piercing_shot"
const SKILL_RNG_VOLLEY: StringName = &"rng_volley"

var _runner: GdUnitSceneRunner
var _screen: Control


func before_test() -> void:
	GHeroSkillBuild.reset_to_defaults()
	GHeroSkillBuild._is_sanctuary = true
	GHeroSkillTree.reset_to_defaults()
	GInventory.reset_to_defaults()
	_runner = scene_runner("res://src/gameplay/ui/hero_skill_build_screen/HeroSkillBuildScreen.tscn")
	_screen = _runner.scene() as Control


func after_test() -> void:
	GHeroSkillBuild.reset_to_defaults()
	GHeroSkillTree.reset_to_defaults()
	GInventory.reset_to_defaults()


func _unlock(skill_id: StringName) -> void:
	GHeroSkillBuild._equippable_skills[String(skill_id)] = true


func _rebuild_all() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("_rebuild_everything")


# ---------------------------------------------------------------------------
# Library panel
# ---------------------------------------------------------------------------

func test_unlocked_skill_is_listed_in_the_library() -> void:
	_unlock(SKILL_PHYS_CLEAVE)
	_rebuild_all()

	assert_object(_screen.call("get_library_button", "phys_cleave")).is_not_null()


## Revised 2026-09-01 for the not-yet-learned-skills roadmap decision
## (player decision via AskUserQuestion, hero-skill-build.md's own
## previously-open question, now resolved): the library always lists the
## FULL catalogue now, not just unlocked skills -- a locked entry is listed
## but disabled, not absent.
func test_locked_skill_is_listed_but_disabled() -> void:
	_rebuild_all()
	var button: Button = _screen.call("get_library_button", "phys_cleave")
	assert_object(button).is_not_null()
	assert_bool(button.disabled).is_true()


func test_unlocked_skill_is_not_disabled() -> void:
	_unlock(SKILL_PHYS_CLEAVE)
	_rebuild_all()
	var button: Button = _screen.call("get_library_button", "phys_cleave")
	assert_bool(button.disabled).is_false()


## Defense-in-depth guard (see _on_library_skill_pressed()'s own doc
## comment): a locked skill_id is rejected even when the handler is called
## directly, not just gated by the UI's own disabled button.
func test_pressing_a_locked_skill_directly_is_a_no_op() -> void:
	_rebuild_all()

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_library_skill_pressed", "phys_cleave")

	assert_str(GHeroSkillBuild.get_active_slots()[0]).is_equal("")


func test_pressing_a_library_skill_assigns_it_to_the_first_empty_active_slot() -> void:
	_unlock(SKILL_PHYS_CLEAVE)
	_rebuild_all()

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_library_skill_pressed", "phys_cleave")

	assert_array(GHeroSkillBuild.get_active_slots()).contains("phys_cleave")


func test_pressing_a_library_skill_when_all_4_slots_full_is_a_no_op() -> void:
	for id: StringName in [SKILL_PHYS_CLEAVE, SKILL_PHYS_BULWARK, SKILL_RNG_PIERCING, SKILL_RNG_VOLLEY]:
		_unlock(id)
	GHeroSkillBuild.set_active_slot(0, "phys_cleave")
	GHeroSkillBuild.set_active_slot(1, "phys_bulwark")
	GHeroSkillBuild.set_active_slot(2, "rng_piercing_shot")
	GHeroSkillBuild.set_active_slot(3, "rng_volley")
	_rebuild_all()

	# a 5th skill press with no room should not error and should leave all 4 unchanged
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_library_skill_pressed", "phys_cleave")

	assert_array(GHeroSkillBuild.get_active_slots()).is_equal(["phys_cleave", "phys_bulwark", "rng_piercing_shot", "rng_volley"])


# ---------------------------------------------------------------------------
# Active slots + Ultimate readout
# ---------------------------------------------------------------------------

func test_pressing_an_occupied_active_slot_clears_it() -> void:
	_unlock(SKILL_PHYS_CLEAVE)
	GHeroSkillBuild.set_active_slot(0, "phys_cleave")
	_rebuild_all()

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_active_slot_pressed", 0)

	assert_str(GHeroSkillBuild.get_active_slots()[0]).is_equal("")


func test_ultimate_readout_reflects_a_full_pure_build() -> void:
	for id: StringName in [SKILL_PHYS_CLEAVE, SKILL_PHYS_BULWARK]:
		_unlock(id)
	GHeroSkillBuild.set_active_slot(0, "phys_cleave")
	GHeroSkillBuild.set_active_slot(1, "phys_bulwark")
	GHeroSkillBuild.set_active_slot(2, "phys_cleave")
	GHeroSkillBuild.set_active_slot(3, "phys_bulwark")
	_rebuild_all()

	assert_str(_screen.call("get_ultimate_label_text")).contains("Physical Ascendant")


# ---------------------------------------------------------------------------
# Passive-cycle (simplified 2-way assignment, see class doc comment)
# ---------------------------------------------------------------------------

func test_passive_cycle_disabled_for_an_empty_active_slot() -> void:
	_rebuild_all()
	var button: Button = _screen.call("get_passive_cycle_button", 0)
	assert_bool(button.disabled).is_true()


## Real bug found and fixed 2026-09-02 (closing hero-skill-build.md's
## flagged skill_modifier item_type gap): _on_passive_cycle_pressed()
## previously cycled through ANY owned Inventory item, including plain
## Materials like common_scrap -- a stub predating Rule 13's 2026-09-01
## typed-slot revision. It now filters to item_type == "skill_modifier"
## candidates, so these tests use real skill-modifier content
## (sup_mod_ruthless/sup_mod_increased_aoe, both compatible with
## phys_cleave's [Melee, Area] tags) added via add_unique_item() --
## skill-modifier items are is_unique_instance == true, not stackable.
func test_passive_cycle_assigns_the_next_owned_item_to_the_next_empty_sub_slot() -> void:
	_unlock(SKILL_PHYS_CLEAVE)
	GHeroSkillBuild.set_active_slot(0, "phys_cleave")  # passive_slot_count = 1
	var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"sup_mod_ruthless")
	GInventory.add_unique_item(def)
	_rebuild_all()

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_passive_cycle_pressed", 0)

	var loadout: Array[String] = GHeroSkillBuild.get_passive_loadout("phys_cleave")
	assert_array(loadout).contains("sup_mod_ruthless")


func test_passive_cycle_is_a_no_op_when_no_free_sub_slot_remains() -> void:
	_unlock(SKILL_PHYS_CLEAVE)
	GHeroSkillBuild.set_active_slot(0, "phys_cleave")  # passive_slot_count = 1
	GHeroSkillBuild.set_passive_slot("phys_cleave", 0, "sup_mod_ruthless")
	var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"sup_mod_increased_aoe")
	GInventory.add_unique_item(def)
	_rebuild_all()

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_passive_cycle_pressed", 0)

	var loadout: Array[String] = GHeroSkillBuild.get_passive_loadout("phys_cleave")
	assert_array(loadout).is_equal(["sup_mod_ruthless"])  # unchanged -- still full


# ---------------------------------------------------------------------------
# Room-hosting contract (ADR-0032)
# ---------------------------------------------------------------------------

func test_disconnect_own_subscriptions_is_safe_to_call() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("disconnect_own_subscriptions")
	assert_bool(true).is_true()


# ---------------------------------------------------------------------------
# Skill detail panel (skill effect UI, 2026-10-07)
# ---------------------------------------------------------------------------

func test_detail_panel_starts_with_a_prompt_and_sits_under_the_active_slots() -> void:
	var panel: Node = _screen.find_child("SkillDetail", true, false)
	assert_object(panel).is_not_null()
	assert_int(panel.get_index()).is_equal(_screen.get_node("MainLayout/AssemblyArea").get_index() + 1)
	assert_str(_screen.get_skill_detail_text()).is_equal("Hover or select a skill to see what it does.")


func test_focusing_a_library_skill_shows_its_stats_and_effect() -> void:
	var button: Button = _screen.get_library_button("elem_frostbolt")
	button.focus_entered.emit()
	var text: String = _screen.get_skill_detail_text()
	assert_str(text).contains("Frostbolt")
	assert_str(text).contains("Ice")
	assert_str(text).contains("Cooldown 4s")
	assert_str(text).contains("Effect: Slows the target by 30% for 2s.")


func test_hovering_a_locked_skill_still_shows_its_detail() -> void:
	var button: Button = _screen.get_library_button("elem_absolute_zero")
	assert_bool(button.disabled).is_true()
	button.mouse_entered.emit()
	assert_str(_screen.get_skill_detail_text()).contains("Absolute Zero")


# ---------------------------------------------------------------------------
# Locked-skill unlock conditions (detail panel, 2026-10-07)
# ---------------------------------------------------------------------------

## Buys one Skill Tree node the way the Skill Tree screen does, granting the
## point and clearing the once-per-visit limit first.
func _buy_node(archetype: String, node_index: int, skill_id: String = "") -> void:
	GHeroSkillTree.skill_tree_points[archetype] = 1
	GHeroSkillTree.visit_spend_count = 0
	assert_bool(GHeroSkillTree.purchase_node(archetype, node_index, skill_id)).is_true()


func _hover(skill_id: String) -> String:
	var button: Button = _screen.get_library_button(skill_id)
	button.mouse_entered.emit()
	return _screen.get_skill_detail_text()


func _display_name(skill_id: String) -> String:
	return GGameDataRegistry.get_skill_definition(StringName(skill_id)).display_name


func test_locked_skill_shows_its_skill_tree_node_and_unmet_requirements() -> void:
	var text: String = _hover("elem_absolute_zero")
	assert_str(text).contains("Unlock: Skill Tree, Elemental Choice III")
	assert_str(text).contains("Requires Elemental Minor first")
	assert_str(text).contains("Costs 1 Elemental skill point (you have 0), earned by fighting near Elemental towers")


func test_unlock_conditions_sit_below_the_skill_description() -> void:
	var text: String = _hover("elem_absolute_zero")
	assert_int(text.find("Unlock:")).is_greater(text.find("Effect:"))


func test_unlock_tier_maps_to_its_choice_node() -> void:
	var opener: String = GHeroSkillTree.get_tier_skill_ids("ranged", 1)[0]
	var core: String = GHeroSkillTree.get_tier_skill_ids("ranged", 2)[0]
	assert_str(_hover(opener)).contains("Unlock: Skill Tree, Ranged Choice I
")
	assert_str(_hover(core)).contains("Unlock: Skill Tree, Ranged Choice II
")


func test_requires_line_names_the_first_locked_node_in_the_chain() -> void:
	_buy_node("elemental", 0)
	var text: String = _hover("elem_absolute_zero")
	assert_str(text).contains("Requires Elemental Choice I first")
	assert_str(text).not_contains("Elemental Minor")


func test_requires_line_is_omitted_once_the_chain_reaches_the_node() -> void:
	_buy_node("elemental", 0)
	var opener: String = GHeroSkillTree.get_tier_skill_ids("elemental", 1)[0]
	assert_str(_hover(opener)).not_contains("Requires")


func test_point_count_includes_overflow_points() -> void:
	GHeroSkillTree.skill_tree_points["ranged"] = 2
	GHeroSkillTree.overflow_points = 1
	assert_str(_hover("rng_barrage")).contains("(you have 3)")


func test_sibling_of_a_chosen_skill_shows_locked_out_instead_of_requirements() -> void:
	var openers: Array[String] = GHeroSkillTree.get_tier_skill_ids("elemental", 1)
	_buy_node("elemental", 0)
	_buy_node("elemental", 1, openers[0])
	_rebuild_all()

	var text: String = _hover(openers[1])
	assert_str(text).contains("Locked out: you chose %s at Elemental Choice I" % _display_name(openers[0]))
	assert_str(text).not_contains("Unlock:")
	assert_str(text).not_contains("Costs 1")


func test_learned_skill_shows_no_unlock_conditions() -> void:
	_unlock(&"elem_absolute_zero")
	_rebuild_all()
	var text: String = _hover("elem_absolute_zero")
	assert_str(text).contains("Absolute Zero")
	assert_str(text).not_contains("Unlock:")
	assert_str(text).not_contains("Locked out")
