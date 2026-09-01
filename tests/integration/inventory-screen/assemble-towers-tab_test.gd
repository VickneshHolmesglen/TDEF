## Integration tests for the Assemble Towers sub-tab within InventoryScreen's
## Crafting right-hand panel (design/quick-specs/tower-assembly-2026-08-11.md).
## Relocated here 2026-08-21 (player-requested) from equipment_forge_screen.gd
## — TowerAssembly.assemble_tower() consumes items Crafting itself produces
## (Foundation/Weapon/Focus/Power Tower Components), not anything Forge-
## specific — see inventory_screen.gd's own "Assemble Towers tab, RELOCATED
## HERE" note for the full rationale. Test bodies are otherwise unchanged
## from their prior Forge-screen implementation (git history has the
## original), just re-targeted at InventoryScreen.tscn and this directory's
## own setup/teardown conventions (crafting-panel_test.gd's own pattern).
##
## TowerAssembly is scene-instanced (not an Autoload) — discovered via the
## "tower_assembly" group at _ready(), which is empty in an isolated
## scene_runner() tree, so a real instance is injected post-_ready() via
## `.set()`, matching crafting-panel_test.gd's identical Crafting pattern.
extends GdUnitTestSuite

const FOUNDATION_ITEM: StringName = &"iron_foundation_component"
const WEAPON_ITEM: StringName = &"advanced_weapon_component"
const FOCUS_ITEM: StringName = &"basic_focus_component"
const POWER_ITEM: StringName = &"tier4_power_component"
## New 2026-09-01 (tower.md Rules 4a-4c) — iron_foundation_component is
## Tier 1, so Shaft is now a required slot alongside Foundation/Weapon.
const SHAFT_ITEM: StringName = &"basic_shaft_component"

var _tower_assembly: TowerAssembly
var _runner: GdUnitSceneRunner
var _screen: Control


func before_test() -> void:
	_tower_assembly = TowerAssembly.new()
	add_child(_tower_assembly)
	GInventory.reset_to_defaults()
	_runner = scene_runner("res://src/gameplay/ui/inventory_screen/InventoryScreen.tscn")
	_screen = _runner.scene() as Control
	_screen.set("tower_assembly", _tower_assembly)
	_rebuild()


func after_test() -> void:
	if _tower_assembly != null and is_instance_valid(_tower_assembly):
		remove_child(_tower_assembly)
		_tower_assembly.free()
	_tower_assembly = null
	GInventory.reset_to_defaults()


func _rebuild() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("_rebuild_assemble_lists")


## Places one of each real crafted tower component into Inventory and
## returns their instance_ids keyed by slot.
func _seed_full_component_set() -> Dictionary[String, int]:
	var ids: Dictionary[String, int] = {}
	for entry: Array in [["foundation", FOUNDATION_ITEM], ["weapon", WEAPON_ITEM], ["focus", FOCUS_ITEM], ["power", POWER_ITEM], ["shaft", SHAFT_ITEM]]:
		var slot: String = entry[0]
		var item_id: StringName = entry[1]
		var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(item_id)
		var slot_index: int = GInventory.add_unique_item(definition)
		ids[slot] = GInventory.get_slot_contents(slot_index)["instance_id"] as int
	return ids


# ---------------------------------------------------------------------------
# Sub-tab toggle
# ---------------------------------------------------------------------------

func test_defaults_to_recipes_subtab() -> void:
	assert_bool(_screen.call("is_showing_assemble")).is_false()
	var recipe_scroll: Control = _screen.get_node("MainLayout/RightPanel/RightPanelContent/RecipeScroll") as Control
	var assemble_view: Control = _screen.get_node("MainLayout/RightPanel/RightPanelContent/AssembleView") as Control
	assert_bool(recipe_scroll.visible).is_true()
	assert_bool(assemble_view.visible).is_false()


func test_assemble_tab_button_switches_to_assemble_view() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_crafting_tab_pressed", true)
	assert_bool(_screen.call("is_showing_assemble")).is_true()
	var recipe_scroll: Control = _screen.get_node("MainLayout/RightPanel/RightPanelContent/RecipeScroll") as Control
	var assemble_view: Control = _screen.get_node("MainLayout/RightPanel/RightPanelContent/AssembleView") as Control
	assert_bool(recipe_scroll.visible).is_false()
	assert_bool(assemble_view.visible).is_true()


# ---------------------------------------------------------------------------
# Component slot columns and selection
# ---------------------------------------------------------------------------

func test_owned_components_are_listed_in_their_correct_slot_columns() -> void:
	var ids: Dictionary[String, int] = _seed_full_component_set()
	_rebuild()

	for slot: String in ids:
		@warning_ignore("unsafe_method_access")
		var button: Button = _screen.call("get_assemble_component_button", slot, ids[slot])
		assert_object(button).is_not_null()


func test_pressing_a_component_selects_it_and_pressing_again_deselects() -> void:
	var ids: Dictionary[String, int] = _seed_full_component_set()
	_rebuild()

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_assemble_component_pressed", "foundation", ids["foundation"])
	@warning_ignore("unsafe_method_access")
	assert_int(_screen.call("get_assemble_selection", "foundation")).is_equal(ids["foundation"])

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_assemble_component_pressed", "foundation", ids["foundation"])
	@warning_ignore("unsafe_method_access")
	assert_int(_screen.call("get_assemble_selection", "foundation")).is_equal(-1)


func test_assemble_button_with_incomplete_selection_does_not_open_confirm_dialog() -> void:
	var ids: Dictionary[String, int] = _seed_full_component_set()
	_rebuild()
	# Only 3 of 5 seeded slots selected -- foundation and shaft (both
	# required at this fixture's Tier 1) are deliberately left unset.
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_assemble_component_pressed", "weapon", ids["weapon"])
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_assemble_component_pressed", "focus", ids["focus"])
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_assemble_component_pressed", "power", ids["power"])
	(_screen.get_node("MainLayout/RightPanel/RightPanelContent/AssembleView/AssembleFooter/AssembleNameEdit") as LineEdit).text = "My Tower"

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_assemble_button_pressed")

	var dialog: ConfirmationDialog = _screen.get_node("AssembleConfirmDialog") as ConfirmationDialog
	assert_bool(dialog.visible).is_false()


func test_assemble_button_with_empty_name_does_not_open_confirm_dialog() -> void:
	var ids: Dictionary[String, int] = _seed_full_component_set()
	_rebuild()
	for slot: String in ids:
		@warning_ignore("unsafe_method_access")
		_screen.call("_on_assemble_component_pressed", slot, ids[slot])

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_assemble_button_pressed")

	var dialog: ConfirmationDialog = _screen.get_node("AssembleConfirmDialog") as ConfirmationDialog
	assert_bool(dialog.visible).is_false()


func test_full_selection_and_confirm_assembles_consumes_and_lists_the_new_tower() -> void:
	var ids: Dictionary[String, int] = _seed_full_component_set()
	_rebuild()
	for slot: String in ids:
		@warning_ignore("unsafe_method_access")
		_screen.call("_on_assemble_component_pressed", slot, ids[slot])
	(_screen.get_node("MainLayout/RightPanel/RightPanelContent/AssembleView/AssembleFooter/AssembleNameEdit") as LineEdit).text = "My Custom Tower"

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_assemble_button_pressed")
	var dialog: ConfirmationDialog = _screen.get_node("AssembleConfirmDialog") as ConfirmationDialog
	assert_bool(dialog.visible).is_true()

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_assemble_confirmed")

	# Source items consumed.
	for slot: String in ids:
		assert_bool(GInventory.get_slot_contents_by_instance_id(ids[slot]).is_empty()).is_true()
	# Selections and name reset.
	for slot: String in ids:
		@warning_ignore("unsafe_method_access")
		assert_int(_screen.call("get_assemble_selection", slot)).is_equal(-1)
	assert_str((_screen.get_node("MainLayout/RightPanel/RightPanelContent/AssembleView/AssembleFooter/AssembleNameEdit") as LineEdit).text).is_equal("")
	# New tower shows up in the Assembled Towers column.
	@warning_ignore("unsafe_method_access")
	var assembled_list: VBoxContainer = _screen.call("get_assembled_list")
	var names: Array[String] = []
	for child: Node in assembled_list.get_children():
		names.append((child as Label).text)
	assert_array(names).contains(["My Custom Tower"])
