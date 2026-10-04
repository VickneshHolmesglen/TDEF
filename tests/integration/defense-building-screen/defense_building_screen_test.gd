## Integration tests for DefenseBuildingScreen (src/gameplay/ui/
## defense_building_screen), Sanctuary UI Story 005's Room Hosting scope.
## Exercises the screen against defense-building.md's UI Requirements: two
## linked views (tech tree, structure build), single-confirm unlock/build,
## cost/prerequisite display, view switch.
##
## Uses the real GDefenseBuilding Autoload and the real GGameDataRegistry-
## loaded tech/structure data (assets/data/defense_building/) — matches
## this project's established Menagerie-screen-test precedent of testing
## against real Autoload state rather than a fully isolated instance.
extends GdUnitTestSuite

var _runner: GdUnitSceneRunner
var _screen: Control


func before_test() -> void:
	GDefenseBuilding.reset_to_defaults()
	GDefenseBuilding._is_sanctuary = true  # Sanctuary-only gate (matches existing unit test precedent)
	GInventory.reset_to_defaults()
	# resolve_tech_unlock()/resolve_structure_build() dual-gate on material
	# affordability via has_items_by_rarity() -- seed real registered items
	# (matches currency_dual_gate_test.gd's own established pattern; a
	# fabricated item_id silently resolves to null rarity and never counts).
	GInventory.add_stackable(GGameDataRegistry.get_item_definition(&"common_scrap"), 100)
	GInventory.add_stackable(GGameDataRegistry.get_item_definition(&"iron_ore"), 100)
	_runner = scene_runner("res://src/gameplay/ui/defense_building_screen/DefenseBuildingScreen.tscn")
	_screen = _runner.scene() as Control


func after_test() -> void:
	GDefenseBuilding.reset_to_defaults()
	GInventory.reset_to_defaults()


# ---------------------------------------------------------------------------
# Tech tree view
# ---------------------------------------------------------------------------

func test_tech_list_contains_all_6_authored_nodes() -> void:
	# 2026-08-03: tech_structural_3 added alongside habitat_expansion_tier_4 --
	# supersedes the original "all 5" count.
	@warning_ignore("unsafe_property_access")
	var tech_buttons: Dictionary = _screen.get("_tech_buttons")
	assert_int(tech_buttons.size()).is_equal(6)
	assert_bool(tech_buttons.has(&"tech_production_2")).is_true()
	assert_bool(tech_buttons.has(&"tech_structural_1")).is_true()
	assert_bool(tech_buttons.has(&"tech_structural_3")).is_true()


func test_locked_prereq_node_shows_locked_state_in_its_button_text() -> void:
	var button: Button = _screen.call("get_tech_button", &"tech_production_3")
	assert_str(button.text).contains(tr("DEFENSE_TECH_STATE_LOCKED"))


func test_pressing_an_available_tech_node_unlocks_it() -> void:
	var button: Button = _screen.call("get_tech_button", &"tech_production_2")
	assert_str(button.text).contains(tr("DEFENSE_TECH_STATE_AVAILABLE"))

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_tech_pressed", &"tech_production_2")

	assert_bool(GDefenseBuilding.is_tech_unlocked(&"tech_production_2")).is_true()


func test_pressing_a_locked_prereq_node_does_not_unlock_it_and_flags_rejection() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_tech_pressed", &"tech_production_3")

	assert_bool(GDefenseBuilding.is_tech_unlocked(&"tech_production_3")).is_false()
	assert_that(_screen.call("get_last_rejection_id")).is_equal(&"tech_production_3")


func test_ledger_change_event_triggers_a_live_rebuild() -> void:
	GDefenseBuilding.resolve_tech_unlock(&"tech_production_2")
	var button: Button = _screen.call("get_tech_button", &"tech_production_2")
	assert_str(button.text).contains(tr("DEFENSE_TECH_STATE_UNLOCKED"))


# ---------------------------------------------------------------------------
# Structure build view
# ---------------------------------------------------------------------------

func test_structure_list_contains_all_5_authored_structures() -> void:
	# 2026-08-03: habitat_expansion_tier_4 added -- supersedes the original
	# "all 4" count.
	@warning_ignore("unsafe_property_access")
	var structure_buttons: Dictionary = _screen.get("_structure_buttons")
	assert_int(structure_buttons.size()).is_equal(5)
	assert_bool(structure_buttons.has(&"watchtower_tier_1")).is_true()
	assert_bool(structure_buttons.has(&"habitat_expansion_tier_4")).is_true()


func test_unbuilt_structure_shows_unbuilt_status() -> void:
	var button: Button = _screen.call("get_structure_button", &"watchtower_tier_1")
	assert_str(button.text).contains(tr("DEFENSE_STRUCTURE_UNBUILT"))


func test_pressing_an_eligible_structure_builds_it() -> void:
	# watchtower_tier_1 is tech-gated on tech_structural_1 -- unlock it first
	# (also re-confirms the tech-gate cross-link, ADR-0024's own Rule 7).
	GDefenseBuilding.resolve_tech_unlock(&"tech_structural_1")

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_structure_pressed", &"watchtower_tier_1")

	assert_bool(GDefenseBuilding.is_structure_built(&"watchtower_tier_1")).is_true()


func test_gated_structure_shows_its_tech_gate_reference() -> void:
	var button: Button = _screen.call("get_structure_button", &"habitat_expansion_tier_2")
	assert_str(button.text).contains("Requires")


# ---------------------------------------------------------------------------
# View switch (GDD: shoulder-button convention, implemented as an explicit
# button — see class doc comment)
# ---------------------------------------------------------------------------

func test_defaults_to_tech_tree_view() -> void:
	assert_bool(_screen.call("is_showing_tech_tree")).is_true()
	var tech_view: Control = _screen.get_node("MainLayout/TechTreeView") as Control
	var structure_view: Control = _screen.get_node("MainLayout/StructureBuildView") as Control
	assert_bool(tech_view.visible).is_true()
	assert_bool(structure_view.visible).is_false()


func test_view_switch_toggles_between_the_2_views() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_view_switch_pressed")

	assert_bool(_screen.call("is_showing_tech_tree")).is_false()
	var tech_view: Control = _screen.get_node("MainLayout/TechTreeView") as Control
	var structure_view: Control = _screen.get_node("MainLayout/StructureBuildView") as Control
	assert_bool(tech_view.visible).is_false()
	assert_bool(structure_view.visible).is_true()


# ---------------------------------------------------------------------------
# Room-hosting contract (ADR-0032)
# ---------------------------------------------------------------------------

func test_disconnect_own_subscriptions_is_safe_to_call() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("disconnect_own_subscriptions")
	assert_bool(true).is_true()
