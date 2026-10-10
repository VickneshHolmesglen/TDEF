## Integration tests for the Crafting panel (InventoryScreen's right-hand
## panel — the previous CraftingPlaceholderLabel), design/gdd/crafting.md.
## Implements that GDD's "core functionality" scope only, per explicit user
## decision: recipe list grouped by category (Ready-first sort), cost display
## with current/required + non-color state cues, select-to-highlight
## consumed left-panel slots, single-confirm Craft button wired to
## resolve_craft(). Deferred: unlock-cascade VFX flash, material-drain pulse
## animation, full gamepad D-pad spatial-adjacency crossing.
##
## Crafting is deliberately scene-instanced (ADR-0023), not an Autoload —
## this screen discovers its one real instance via the "crafting" group at
## _ready(), which is empty in an isolated scene_runner() tree. Matches
## equipment_forge_screen_test.gd's own established pattern: `Crafting.new()`
## (no add_child(), so _ready()/EventBus subscriptions never fire —
## irrelevant here since tests call resolve_craft()/is_*() indirectly through
## the screen, or seed the discovery ledger directly), injected onto the
## screen post-_ready() via `.set()`, followed by an explicit rebuild call.
##
## Real recipe/item data used throughout (no synthetic injection needed):
## recipe_healing_salve (crafted_good, 3x Material -> 3x healing_salve,
## ungated) and recipe_iron_foundation (tower_component/foundation, 5x
## Material -> iron_foundation_component, ungated). common_scrap is a real
## Material-item_type ItemDefinitionResource used to seed Inventory.
extends GdUnitTestSuite

const RECIPE_SALVE: StringName = &"recipe_healing_salve"
const RECIPE_FOUNDATION: StringName = &"recipe_iron_foundation"
const MATERIAL_ITEM_ID: StringName = &"common_scrap"

var _crafting: Crafting
var _runner: GdUnitSceneRunner
var _screen: Control


func before_test() -> void:
	_crafting = Crafting.new()
	GInventory.reset_to_defaults()
	_runner = scene_runner("res://src/gameplay/ui/inventory_screen/InventoryScreen.tscn")
	_screen = _runner.scene() as Control
	_screen.set("crafting", _crafting)
	_refresh()


func after_test() -> void:
	if _crafting != null and is_instance_valid(_crafting):
		_crafting.free()
	_crafting = null
	GInventory.reset_to_defaults()


func _refresh() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("_refresh_crafting_panel")


func _discover(recipe_id: StringName) -> void:
	@warning_ignore("unsafe_property_access")
	(_crafting.get("_discovery_ledger") as Dictionary)[recipe_id] = true


func _seed_material(quantity: int) -> void:
	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(MATERIAL_ITEM_ID)
	GInventory.add_stackable(definition, quantity)


func _recipe_row(recipe_id: StringName) -> Control:
	var host: VBoxContainer = _screen.get_node("MainLayout/RightPanel/RightPanelContent/RecipeScroll/RecipeListHost") as VBoxContainer
	return host.get_node_or_null("Recipe_%s" % String(recipe_id)) as Control


# ---------------------------------------------------------------------------
# Discovery-gated visibility (Rule 4)
# ---------------------------------------------------------------------------

func test_undiscovered_recipe_is_not_shown() -> void:
	_refresh()

	assert_object(_recipe_row(RECIPE_SALVE)).is_null()


func test_discovered_recipe_shows_a_row() -> void:
	_discover(RECIPE_SALVE)
	_refresh()

	assert_object(_recipe_row(RECIPE_SALVE)).is_not_null()


func test_no_crafting_instance_leaves_recipe_list_empty_not_crashed() -> void:
	# Explicitly nulled rather than relying on an isolated scene_runner()
	# tree having no "crafting" group member -- the full test-suite process
	# is shared across many test FILES, some of which mount a real
	# SanctuaryUI.tscn (with a real, EventBus-subscribed Crafting child) and
	# may leave it as a GdUnit4-tracked orphan rather than freeing it
	# synchronously; an orphaned-but-not-freed Node stays in its group. This
	# test's own contract (real gameplay always finds an instance via the
	# "crafting" group; an isolated mount with none must not crash) is
	# fully exercised by forcing the null case directly, independent of
	# whatever else happens to be alive elsewhere in the same test run.
	var bare_runner: GdUnitSceneRunner = scene_runner("res://src/gameplay/ui/inventory_screen/InventoryScreen.tscn")
	var bare_screen: Control = bare_runner.scene() as Control
	bare_screen.set("crafting", null)

	@warning_ignore("unsafe_method_access")
	bare_screen.call("_refresh_crafting_panel")

	var host: VBoxContainer = bare_screen.get_node("MainLayout/RightPanel/RightPanelContent/RecipeScroll/RecipeListHost") as VBoxContainer
	assert_int(host.get_child_count()).is_equal(0)


# ---------------------------------------------------------------------------
# Cost display (UI Requirements: "[key] current/required")
# ---------------------------------------------------------------------------

func test_cost_line_shows_current_over_required() -> void:
	_discover(RECIPE_SALVE)
	_seed_material(2)  # recipe needs 3
	_refresh()

	var row: Control = _recipe_row(RECIPE_SALVE)
	var found: bool = false
	for child: Node in _collect_labels(row):
		if (child as Label).text.contains("2/3"):
			found = true
	assert_bool(found).is_true()


func _collect_labels(node: Node) -> Array[Label]:
	var labels: Array[Label] = []
	for child: Node in node.get_children():
		if child is Label:
			labels.append(child as Label)
		labels.append_array(_collect_labels(child))
	return labels


# ---------------------------------------------------------------------------
# Craft button state (AC-3: insufficient stays visible but disabled)
# ---------------------------------------------------------------------------

func _craft_button(recipe_id: StringName) -> Button:
	var row: Control = _recipe_row(recipe_id)
	for child: Node in _collect_buttons(row):
		return child as Button
	return null


func _collect_buttons(node: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in node.get_children():
		if child is Button:
			buttons.append(child as Button)
		buttons.append_array(_collect_buttons(child))
	return buttons


func test_insufficient_recipe_has_disabled_craft_button() -> void:
	_discover(RECIPE_SALVE)
	_seed_material(2)  # needs 3
	_refresh()

	assert_bool(_craft_button(RECIPE_SALVE).disabled).is_true()


func test_ready_recipe_has_enabled_craft_button() -> void:
	_discover(RECIPE_SALVE)
	_seed_material(3)
	_refresh()

	assert_bool(_craft_button(RECIPE_SALVE).disabled).is_false()


# ---------------------------------------------------------------------------
# Craft-confirm interaction (single confirm, wired to resolve_craft())
# ---------------------------------------------------------------------------

func test_pressing_craft_consumes_materials_and_adds_output() -> void:
	_discover(RECIPE_SALVE)
	_seed_material(3)
	_refresh()

	_craft_button(RECIPE_SALVE).pressed.emit()

	assert_bool(GInventory.has_items({&"Material": 1})).is_false()
	assert_bool(GInventory.has_items({&"CraftedGood": 3})).is_true()


func test_pressing_craft_refreshes_the_panel_to_the_new_state() -> void:
	_discover(RECIPE_SALVE)
	_seed_material(3)
	_refresh()

	_craft_button(RECIPE_SALVE).pressed.emit()

	# Materials fully spent -- the row should now report not-craftable.
	assert_bool(_craft_button(RECIPE_SALVE).disabled).is_true()


func test_pressing_craft_updates_left_panel_slot_quantity() -> void:
	_discover(RECIPE_SALVE)
	_seed_material(3)
	_refresh()
	var slot_before: Dictionary = GInventory.get_slot_contents(0)
	assert_int(slot_before.get("quantity", 0)).is_equal(3)

	_craft_button(RECIPE_SALVE).pressed.emit()

	# All 3 common_scrap consumed; the freshly-crafted healing_salve output
	# lands in the now-freed slot 0 (Inventory's own fill-first-available-
	# slot algorithm) -- whatever ends up there must not be the stale
	# pre-craft "common_scrap x3" text (regression guard for
	# _apply_slot_visual()'s reset branch), and the real holdings must
	# reflect consumption + output.
	var slot_button: Button = _screen.get_node("MainLayout/LeftPanel/BagPanel/BagContent/SlotGrid/Slot0") as Button
	assert_str(slot_button.text).is_not_equal("common_scrap x3")
	assert_bool(GInventory.has_items({&"Material": 1})).is_false()
	assert_bool(GInventory.has_items({&"CraftedGood": 3})).is_true()


func test_tower_component_craft_rejected_without_room_consumes_nothing() -> void:
	_discover(RECIPE_FOUNDATION)
	_seed_material(6)  # cost is 5 -- a leftover keeps the stack's slot occupied
	# Fill every TowerComponent slot so has_room_for("foundation", 1) is false.
	for i: int in range(20):
		GInventory.add_unique_item(GGameDataRegistry.get_item_definition(&"iron_foundation_component"), {}, 0, -1)
	_refresh()

	_craft_button(RECIPE_FOUNDATION).pressed.emit()

	# Gate 3 (AC-4) rejects before consuming -- the 5 seeded Material must
	# still be fully present.
	assert_bool(GInventory.has_items({&"Material": 5})).is_true()


# Regression (2026-10-10): materials ready + full bag rendered a live Craft
# button that silently did nothing -- it must read as blocked, with a reason.
func test_tower_component_row_shows_bag_full_when_no_room() -> void:
	_discover(RECIPE_FOUNDATION)
	_seed_material(6)  # leftover 1 after paying 5 -- no slot is freed
	for i: int in range(20):
		GInventory.add_unique_item(GGameDataRegistry.get_item_definition(&"iron_foundation_component"), {}, 0, -1)
	_refresh()

	var button: Button = _craft_button(RECIPE_FOUNDATION)
	assert_bool(button.disabled).is_true()
	assert_str(button.text).is_equal(tr("CRAFTING_BAG_FULL_BUTTON"))
	assert_str(button.tooltip_text).is_not_empty()


# A full bag whose cost exactly empties a material stack still has room --
# the freed slot takes the output (AC-4 amended 2026-10-10).
func test_tower_component_craft_uses_slot_freed_by_its_own_cost() -> void:
	_discover(RECIPE_FOUNDATION)
	_seed_material(5)
	for i: int in range(20):
		GInventory.add_unique_item(GGameDataRegistry.get_item_definition(&"iron_foundation_component"), {}, 0, -1)
	_refresh()

	var button: Button = _craft_button(RECIPE_FOUNDATION)
	assert_bool(button.disabled).is_false()
	button.pressed.emit()

	assert_bool(GInventory.has_items({&"Material": 1})).is_false()


# ---------------------------------------------------------------------------
# Hover-to-highlight (UI Requirements: "highlights ... the specific
# Inventory slots on the left panel that would be consumed")
# ---------------------------------------------------------------------------

# Regression (2026-10-11): an item_id-keyed input (goblin_hide) was counted as
# an unknown item_type -- the row read "goblin_hide 0/5 !" while the player
# held enough and the Craft button was live.
func test_item_id_keyed_cost_line_counts_that_item_and_shows_its_name() -> void:
	_discover(&"recipe_goblinhide_bandage")
	GInventory.add_stackable(GGameDataRegistry.get_item_definition(&"goblin_hide"), 7)
	_refresh()

	var texts: Array[String] = []
	for label: Label in _collect_labels(_recipe_row(&"recipe_goblinhide_bandage")):
		texts.append(label.text)
	var display_name: String = GGameDataRegistry.get_item_definition(&"goblin_hide").display_name
	assert_array(texts).contains(["%s 7/5" % display_name])
	assert_array(texts).not_contains(["!"])


func _preview_ring(slot_index: int) -> Panel:
	var slot_button: Button = _screen.get_node("MainLayout/LeftPanel/BagPanel/BagContent/SlotGrid/Slot%d" % slot_index) as Button
	return slot_button.get_node("CraftPreviewRing") as Panel


func test_hovering_recipe_row_highlights_the_matching_material_slot() -> void:
	_discover(RECIPE_SALVE)
	_seed_material(3)
	_refresh()

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_recipe_row_hover", RECIPE_SALVE, true)

	assert_bool(_preview_ring(0).visible).is_true()


func test_unhovering_recipe_row_clears_the_highlight() -> void:
	_discover(RECIPE_SALVE)
	_seed_material(3)
	_refresh()
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_recipe_row_hover", RECIPE_SALVE, true)

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_recipe_row_hover", RECIPE_SALVE, false)

	assert_bool(_preview_ring(0).visible).is_false()


# ---------------------------------------------------------------------------
# Live refresh on discovery / inventory change (Rule 4's own "craftability
# flickers on and off with the player's current material stock")
# ---------------------------------------------------------------------------

func test_recipe_discovered_event_adds_the_row_without_a_manual_refresh_call() -> void:
	GEventBus.recipe_discovered.emit(String(RECIPE_SALVE), "crafted_good")
	_discover(RECIPE_SALVE)  # the real trigger paths live on Crafting itself; this test only proves the screen reacts to the broadcast

	GEventBus.recipe_discovered.emit(String(RECIPE_SALVE), "crafted_good")

	assert_object(_recipe_row(RECIPE_SALVE)).is_not_null()


func test_item_added_event_refreshes_craftability_without_a_manual_refresh_call() -> void:
	_discover(RECIPE_SALVE)
	_refresh()
	assert_bool(_craft_button(RECIPE_SALVE).disabled).is_true()

	_seed_material(3)  # Inventory.add_stackable() emits item_added for real

	assert_bool(_craft_button(RECIPE_SALVE).disabled).is_false()
