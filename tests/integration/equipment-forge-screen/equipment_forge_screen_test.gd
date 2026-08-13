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

const UPGRADE_ID: StringName = &"upgrade_watchtower_reinforced"

var _forge: EquipmentForge
var _building_upgrade: BuildingUpgrade
var _tower_assembly: TowerAssembly
var _runner: GdUnitSceneRunner
var _screen: Control


func before_test() -> void:
	_forge = EquipmentForge.new()
	_building_upgrade = BuildingUpgrade.new()
	add_child(_building_upgrade)
	_tower_assembly = TowerAssembly.new()
	add_child(_tower_assembly)
	GInventory.reset_to_defaults()
	GDefenseBuilding.reset_to_defaults()
	GMenagerie.reset_to_defaults()
	GTarot.reset_to_defaults()
	_runner = scene_runner("res://src/gameplay/ui/equipment_forge_screen/EquipmentForgeScreen.tscn")
	_screen = _runner.scene() as Control
	_screen.set("equipment_forge", _forge)
	_screen.set("building_upgrade", _building_upgrade)
	_screen.set("tower_assembly", _tower_assembly)
	_rebuild_all()


func after_test() -> void:
	if _forge != null and is_instance_valid(_forge):
		_forge.free()
	_forge = null
	if _building_upgrade != null and is_instance_valid(_building_upgrade):
		remove_child(_building_upgrade)
		_building_upgrade.free()
	_building_upgrade = null
	if _tower_assembly != null and is_instance_valid(_tower_assembly):
		remove_child(_tower_assembly)
		_tower_assembly.free()
	_tower_assembly = null
	GInventory.reset_to_defaults()
	GDefenseBuilding.reset_to_defaults()
	GMenagerie.reset_to_defaults()
	GTarot.reset_to_defaults()


func _rebuild_all() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("_rebuild_recipe_list")
	@warning_ignore("unsafe_method_access")
	_screen.call("_rebuild_item_list")
	@warning_ignore("unsafe_method_access")
	_screen.call("_rebuild_rune_list")
	@warning_ignore("unsafe_method_access")
	_screen.call("_rebuild_upgrade_list")
	@warning_ignore("unsafe_method_access")
	_screen.call("_rebuild_assemble_lists")


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


func test_tab_button_switches_to_imbue_view() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_tab_button_pressed", 1)  # TAB_IMBUE
	assert_bool(_screen.call("is_showing_craft")).is_false()


func test_assemble_tab_is_reachable() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_tab_button_pressed", 2)  # TAB_ASSEMBLE
	assert_int(_screen.call("get_active_tab")).is_equal(2)
	var assemble_view: Control = _screen.get_node("MainLayout/AssembleView") as Control
	assert_bool(assemble_view.visible).is_true()


func test_upgrade_tab_is_reachable() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_tab_button_pressed", 3)  # TAB_UPGRADE
	assert_int(_screen.call("get_active_tab")).is_equal(3)
	var upgrade_view: Control = _screen.get_node("MainLayout/UpgradeView") as Control
	assert_bool(upgrade_view.visible).is_true()


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
# Upgrade Buildings tab
# ---------------------------------------------------------------------------

func test_upgrade_not_listed_before_its_target_structure_is_built() -> void:
	assert_object(_screen.call("get_upgrade_button", UPGRADE_ID)).is_null()


func test_upgrade_listed_as_visible_locked_once_target_structure_is_built() -> void:
	GDefenseBuilding._structure_ledger[&"watchtower_tier_1"] = true
	_rebuild_all()

	var button: Button = _screen.call("get_upgrade_button", UPGRADE_ID)
	assert_object(button).is_not_null()
	assert_str(button.text).contains("VISIBLE_LOCKED")


func test_pressing_an_ineligible_upgrade_does_not_open_the_confirmation_dialog() -> void:
	GDefenseBuilding._structure_ledger[&"watchtower_tier_1"] = true
	_rebuild_all()

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_upgrade_pressed", UPGRADE_ID)

	var dialog: ConfirmationDialog = _screen.get_node("UpgradeConfirmDialog") as ConfirmationDialog
	assert_bool(dialog.visible).is_false()


## AC-6 (Story 003, Rule 2a): each requirements entry renders as its own
## chip -- upgrade_watchtower_reinforced's real content requires "building",
## "creature", and "tarot" (assets/data/building_upgrades/
## upgrade_watchtower_reinforced.tres) -- 3 chips, one per entry, not one
## collapsed pass/fail state for the whole row.
func test_visible_locked_upgrade_renders_one_chip_per_requirement() -> void:
	GDefenseBuilding._structure_ledger[&"watchtower_tier_1"] = true
	_rebuild_all()

	var chip_row: Control = _screen.call("get_upgrade_chip_row", UPGRADE_ID)
	assert_object(chip_row).is_not_null()
	assert_int(chip_row.get_child_count()).is_equal(3)


## AC-6: chip text names the specific target, not a raw StringName id --
## upgrade_watchtower_reinforced's own "building" requirement targets
## habitat_expansion_tier_1 (distinct from its own target_structure_id,
## watchtower_tier_1 -- confirmed by reading the real .tres content), so its
## chip must contain a resolved (title-cased) name, never the flat id
## embedded verbatim as the whole label with no humanization.
func test_requirement_chip_shows_resolved_name_not_raw_id() -> void:
	GDefenseBuilding._structure_ledger[&"watchtower_tier_1"] = true
	_rebuild_all()

	var chip_row: Control = _screen.call("get_upgrade_chip_row", UPGRADE_ID)
	var building_chip: Label = chip_row.get_node("Chip_building") as Label
	assert_str(building_chip.text).contains("Habitat Expansion Tier 1")


## AC-6: an unmet requirement's chip shows the unmet glyph; a satisfied
## one shows the satisfied glyph -- independently per entry, confirming
## this isn't one collapsed state for the whole upgrade.
func test_unmet_and_satisfied_requirements_render_distinct_chip_glyphs() -> void:
	GDefenseBuilding._structure_ledger[&"watchtower_tier_1"] = true  # target_structure_id -- visibility only
	GDefenseBuilding._structure_ledger[&"habitat_expansion_tier_1"] = true  # satisfies the "building" requirement itself
	_rebuild_all()

	var chip_row: Control = _screen.call("get_upgrade_chip_row", UPGRADE_ID)
	var building_chip: Label = chip_row.get_node("Chip_building") as Label
	assert_str(building_chip.text).contains("✓")
	var creature_chip: Label = chip_row.get_node("Chip_creature") as Label
	# no creature seeded -- unmet.
	assert_str(creature_chip.text).contains("✗")


## AC-6b: the 4 requirement categories each get a distinct, non-color-only
## tag (this content's 3 present categories, at minimum, must not collide).
func test_requirement_chips_use_distinct_category_tags() -> void:
	GDefenseBuilding._structure_ledger[&"watchtower_tier_1"] = true
	_rebuild_all()

	var chip_row: Control = _screen.call("get_upgrade_chip_row", UPGRADE_ID)
	var building_chip: Label = chip_row.get_node("Chip_building") as Label
	var creature_chip: Label = chip_row.get_node("Chip_creature") as Label
	var tarot_chip: Label = chip_row.get_node("Chip_tarot") as Label
	var seen_tags: Dictionary[String, bool] = {}
	for chip: Label in [building_chip, creature_chip, tarot_chip]:
		for category_tag: String in ["[Bldg]", "[Equip]", "[Tarot]", "[Creature]"]:
			if chip.text.contains(category_tag):
				seen_tags[category_tag] = true
	assert_int(seen_tags.size()).is_equal(3)  # 3 distinct tags for 3 distinct categories -- no collisions


## AC-6: the tarot requirement is also independently unmet (no Tarot node
## in this scene tree, per _requirement_satisfied()'s fail-closed branch --
## see building-upgrade.md's own Open Questions) -- closes a coverage gap
## /code-review found (only building/creature glyphs were previously
## asserted, not tarot).
## ADR-0035 (2026-08-12): Tarot is now a real Autoload (GTarot), reachable
## from Equipment Forge's own Sanctuary UI screen -- this replaces the old
## "unmet with no live Tarot instance" gap test (that premise no longer
## exists). iron_resolve (this upgrade's own "tarot" requirement) is
## Common content, unlocked by default, so the chip now genuinely reads
## satisfied via the real GTarot.is_card_unlocked() call.
func test_tarot_requirement_chip_is_satisfied_via_the_real_gtarot_autoload() -> void:
	GDefenseBuilding._structure_ledger[&"watchtower_tier_1"] = true
	_rebuild_all()

	var chip_row: Control = _screen.call("get_upgrade_chip_row", UPGRADE_ID)
	var tarot_chip: Label = chip_row.get_node("Chip_tarot") as Label
	assert_str(tarot_chip.text).contains("✓")


## AC-6: an unresolvable equipment id falls back to a title-cased id rather
## than crashing or showing the flat raw id -- closes a coverage gap
## /code-review found (the "equipment" branch's null-definition fallback
## had no real content exercising it, since upgrade_watchtower_reinforced
## has no "equipment" requirement).
func test_equipment_display_name_falls_back_to_title_case_for_unknown_item_id() -> void:
	@warning_ignore("unsafe_method_access")
	var resolved: String = _screen.call("_resolve_requirement_display_name", "equipment", &"not_a_real_item_id")
	assert_str(resolved).is_equal("Not A Real Item Id")


# ---------------------------------------------------------------------------
# Assemble Towers tab (design/quick-specs/tower-assembly-2026-08-11.md)
# ---------------------------------------------------------------------------

const FOUNDATION_ITEM: StringName = &"iron_foundation_component"
const WEAPON_ITEM: StringName = &"advanced_weapon_component"
const FOCUS_ITEM: StringName = &"basic_focus_component"
const POWER_ITEM: StringName = &"tier4_power_component"


## Places one of each real crafted tower component into Inventory and
## returns their instance_ids keyed by slot -- mirrors tower_assembly_test.gd's
## own _seed_full_component_set() helper.
func _seed_full_component_set() -> Dictionary[String, int]:
	var ids: Dictionary[String, int] = {}
	for entry: Array in [["foundation", FOUNDATION_ITEM], ["weapon", WEAPON_ITEM], ["focus", FOCUS_ITEM], ["power", POWER_ITEM]]:
		var slot: String = entry[0]
		var item_id: StringName = entry[1]
		var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(item_id)
		var slot_index: int = GInventory.add_unique_item(definition)
		ids[slot] = GInventory.get_slot_contents(slot_index)["instance_id"] as int
	return ids


func test_owned_components_are_listed_in_their_correct_slot_columns() -> void:
	var ids: Dictionary[String, int] = _seed_full_component_set()
	_rebuild_all()

	for slot: String in ids:
		@warning_ignore("unsafe_method_access")
		var button: Button = _screen.call("get_assemble_component_button", slot, ids[slot])
		assert_object(button).is_not_null()


func test_pressing_a_component_selects_it_and_pressing_again_deselects() -> void:
	var ids: Dictionary[String, int] = _seed_full_component_set()
	_rebuild_all()

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
	_rebuild_all()
	# Only 3 of 4 slots selected -- foundation is deliberately left unset.
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_assemble_component_pressed", "weapon", ids["weapon"])
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_assemble_component_pressed", "focus", ids["focus"])
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_assemble_component_pressed", "power", ids["power"])
	(_screen.get_node("MainLayout/AssembleView/AssembleFooter/AssembleNameEdit") as LineEdit).text = "My Tower"

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_assemble_button_pressed")

	var dialog: ConfirmationDialog = _screen.get_node("AssembleConfirmDialog") as ConfirmationDialog
	assert_bool(dialog.visible).is_false()


func test_assemble_button_with_empty_name_does_not_open_confirm_dialog() -> void:
	var ids: Dictionary[String, int] = _seed_full_component_set()
	_rebuild_all()
	for slot: String in ids:
		@warning_ignore("unsafe_method_access")
		_screen.call("_on_assemble_component_pressed", slot, ids[slot])

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_assemble_button_pressed")

	var dialog: ConfirmationDialog = _screen.get_node("AssembleConfirmDialog") as ConfirmationDialog
	assert_bool(dialog.visible).is_false()


func test_full_selection_and_confirm_assembles_consumes_and_lists_the_new_tower() -> void:
	var ids: Dictionary[String, int] = _seed_full_component_set()
	_rebuild_all()
	for slot: String in ids:
		@warning_ignore("unsafe_method_access")
		_screen.call("_on_assemble_component_pressed", slot, ids[slot])
	(_screen.get_node("MainLayout/AssembleView/AssembleFooter/AssembleNameEdit") as LineEdit).text = "My Custom Tower"

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
	assert_str((_screen.get_node("MainLayout/AssembleView/AssembleFooter/AssembleNameEdit") as LineEdit).text).is_equal("")
	# New tower shows up in the Assembled Towers column.
	@warning_ignore("unsafe_method_access")
	var assembled_list: VBoxContainer = _screen.call("get_assembled_list")
	var names: Array[String] = []
	for child: Node in assembled_list.get_children():
		names.append((child as Label).text)
	assert_array(names).contains(["My Custom Tower"])


# ---------------------------------------------------------------------------
# Room-hosting contract (ADR-0032)
# ---------------------------------------------------------------------------

func test_disconnect_own_subscriptions_is_safe_to_call() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("disconnect_own_subscriptions")
	assert_bool(true).is_true()
