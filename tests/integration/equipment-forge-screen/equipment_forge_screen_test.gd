## Integration tests for EquipmentForgeScreen (src/gameplay/ui/
## equipment_forge_screen), Sanctuary UI Story 005's Room Hosting scope.
## Exercises the screen against equipment-forge.md's UI Requirements:
## persistent Craft/Imbue tab toggle, equipment-recipe crafting (single-
## confirm), and rune-imbuing (2-way select-then-confirm + two-step
## confirmation modal) — see the screen's own doc comment for the honestly-
## scoped deviations from the GDD's literal 3-way selection / reused-panel
## wording.
##
## EquipmentForge is deliberately scene-instanced (ADR-0025), not an
## Autoload — this screen discovers its one real instance via the
## "equipment_forge" group at _ready(), which is empty in an isolated
## scene_runner() tree. Matches crafting-resolution-material-cost_test.gd's
## own established pattern: `EquipmentForge.new()` (no add_child(), so
## _ready()/EventBus subscriptions never fire — irrelevant here since tests
## call resolve_*()/is_*() directly), injected onto the screen post-_ready()
## via `.set()`, followed by an explicit rebuild call.
extends GdUnitTestSuite

const RECIPE_IRON_SWORD: StringName = &"recipe_iron_sword"  # ungated, weapon, needs 4 Material, rune_slot_count=2

var _forge: EquipmentForge
var _runner: GdUnitSceneRunner
var _screen: Control


func before_test() -> void:
	_forge = EquipmentForge.new()
	GInventory.reset_to_defaults()
	_runner = scene_runner("res://src/gameplay/ui/equipment_forge_screen/EquipmentForgeScreen.tscn")
	_screen = _runner.scene() as Control
	_screen.set("equipment_forge", _forge)
	_rebuild_all()


func after_test() -> void:
	if _forge != null and is_instance_valid(_forge):
		_forge.free()
	_forge = null
	GInventory.reset_to_defaults()


func _rebuild_all() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("_rebuild_recipe_list")
	@warning_ignore("unsafe_method_access")
	_screen.call("_rebuild_item_list")
	@warning_ignore("unsafe_method_access")
	_screen.call("_rebuild_rune_list")


func _discover(recipe_id: StringName) -> void:
	@warning_ignore("unsafe_property_access")
	(_forge.get("_equipment_discovery_ledger") as Dictionary)[recipe_id] = true


func _seed_material(quantity: int) -> void:
	var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"common_scrap")
	GInventory.add_stackable(def, quantity)


# ---------------------------------------------------------------------------
# Craft / Imbue tab toggle
# ---------------------------------------------------------------------------

func test_defaults_to_craft_view() -> void:
	assert_bool(_screen.call("is_showing_craft")).is_true()
	var craft_view: Control = _screen.get_node("MainLayout/CraftView") as Control
	var imbue_view: Control = _screen.get_node("MainLayout/ImbueView") as Control
	assert_bool(craft_view.visible).is_true()
	assert_bool(imbue_view.visible).is_false()


func test_tab_toggle_switches_views() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_tab_toggle_pressed")
	assert_bool(_screen.call("is_showing_craft")).is_false()


# ---------------------------------------------------------------------------
# Craft tab
# ---------------------------------------------------------------------------

func test_undiscovered_recipe_is_not_listed() -> void:
	_rebuild_all()
	assert_object(_screen.call("get_recipe_button", RECIPE_IRON_SWORD)).is_null()


func test_discovered_recipe_is_listed_with_craftable_state() -> void:
	_discover(RECIPE_IRON_SWORD)
	_seed_material(4)
	_rebuild_all()

	var button: Button = _screen.call("get_recipe_button", RECIPE_IRON_SWORD)
	assert_object(button).is_not_null()
	assert_str(button.text).contains("CRAFTABLE")


func test_discovered_recipe_without_materials_shows_missing_materials() -> void:
	_discover(RECIPE_IRON_SWORD)
	_rebuild_all()

	var button: Button = _screen.call("get_recipe_button", RECIPE_IRON_SWORD)
	assert_str(button.text).contains("MISSING_MATERIALS")


func test_pressing_a_craftable_recipe_crafts_it() -> void:
	_discover(RECIPE_IRON_SWORD)
	_seed_material(4)
	_rebuild_all()

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_recipe_pressed", RECIPE_IRON_SWORD)

	assert_bool(GInventory.has_items({&"Material": 4})).is_false()  # consumed


# ---------------------------------------------------------------------------
# Imbue tab — item selection, rune selection, two-step confirmation
# ---------------------------------------------------------------------------

func test_item_with_no_free_rune_slot_is_not_listed() -> void:
	var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"iron_sword")
	var instance_id: int = GInventory.add_unique_item(def, {}, 0)  # 0 rune slots
	_rebuild_all()

	assert_object(_screen.call("get_item_button", instance_id)).is_null()


func test_item_with_a_free_rune_slot_is_listed() -> void:
	var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"iron_sword")
	var instance_id: int = GInventory.add_unique_item(def, {}, 2)  # 2 free slots
	_rebuild_all()

	var button: Button = _screen.call("get_item_button", instance_id)
	assert_object(button).is_not_null()
	assert_str(button.text).contains("2/2")


func test_selecting_an_item_shows_the_cancel_button() -> void:
	var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"iron_sword")
	var instance_id: int = GInventory.add_unique_item(def, {}, 2)
	_rebuild_all()

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_item_pressed", instance_id)

	assert_int(_screen.call("get_selected_instance_id")).is_equal(instance_id)
	var cancel_button: Button = _screen.get_node("MainLayout/ImbueView/ItemColumn/CancelSelectionButton") as Button
	assert_bool(cancel_button.visible).is_true()


func test_pressing_a_rune_with_no_item_selected_is_a_no_op() -> void:
	@warning_ignore("unsafe_property_access")
	(_forge.get("_available_runes") as Dictionary)[&"rune_test"] = {"rune_source": "tarot", "stat_delta": {"additive_bonus_total": 0.05}, "is_known": true}
	_rebuild_all()

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_rune_pressed", &"rune_test")

	var dialog: ConfirmationDialog = _screen.get_node("ImbueConfirmDialog") as ConfirmationDialog
	assert_bool(dialog.visible).is_false()


func test_pressing_a_rune_with_an_item_selected_opens_the_confirmation_dialog_without_mutating() -> void:
	var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"iron_sword")
	var instance_id: int = GInventory.add_unique_item(def, {}, 2)
	@warning_ignore("unsafe_property_access")
	(_forge.get("_available_runes") as Dictionary)[&"rune_test"] = {"rune_source": "tarot", "stat_delta": {"additive_bonus_total": 0.05}, "is_known": true}
	_rebuild_all()
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_item_pressed", instance_id)

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_rune_pressed", &"rune_test")

	var dialog: ConfirmationDialog = _screen.get_node("ImbueConfirmDialog") as ConfirmationDialog
	assert_bool(dialog.visible).is_true()
	assert_bool(_forge.get_available_rune(&"rune_test").is_empty()).is_false()  # not yet consumed


func test_confirming_imbue_actually_imbues_the_rune() -> void:
	var def: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"iron_sword")
	var instance_id: int = GInventory.add_unique_item(def, {}, 2)
	@warning_ignore("unsafe_property_access")
	(_forge.get("_available_runes") as Dictionary)[&"rune_test"] = {"rune_source": "tarot", "stat_delta": {"additive_bonus_total": 0.05}, "is_known": true}
	_rebuild_all()
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_item_pressed", instance_id)
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_rune_pressed", &"rune_test")

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_imbue_confirmed")

	assert_bool(_forge.get_available_rune(&"rune_test").is_empty()).is_true()  # consumed
	var contents: Dictionary = GInventory.get_slot_contents_by_instance_id(instance_id)
	assert_array(contents["imbued_runes"] as Array).contains("rune_test")


func test_orphaned_rune_is_not_listed() -> void:
	@warning_ignore("unsafe_property_access")
	(_forge.get("_available_runes") as Dictionary)[&"rune_orphaned"] = {"rune_source": "tarot", "stat_delta": {}, "is_known": false}
	_rebuild_all()

	assert_object(_screen.call("get_rune_button", &"rune_orphaned")).is_null()


# ---------------------------------------------------------------------------
# Room-hosting contract (ADR-0032)
# ---------------------------------------------------------------------------

func test_disconnect_own_subscriptions_is_safe_to_call() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("disconnect_own_subscriptions")
	assert_bool(true).is_true()
