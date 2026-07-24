## Integration tests for Story 003 (epic-10-sanctuary-ui, ADR-0001): Connection
## Badges -- 4 room-tab EventBus-driven badges (Inventory & Crafting, Menagerie,
## Defense Building, Equipment Forge), clearing on entry, and the Loadout
## carve-out (GDD Core Rule 2, AC Group 2 badge items + AC Group 9's badge item).
##
## Signal substitution note: see tab_strip.gd's own class doc for why these
## tests fire the REAL EventBus signals (recipe_discovered,
## creature_returned_from_breeding_pen, sanctuary_structure_built,
## item_rune_imbued) rather than the GDD's own first-pass-guess names
## (recipe_unlocked, creature READY, rune_socket_unlocked) -- 3 of those 4
## names don't exist in the real catalogue (OQ-6, not yet confirmed).
extends GdUnitTestSuite

var _runner: GdUnitSceneRunner
var _shell: SanctuaryUI
var _tab_strip: TabStrip


func before_test() -> void:
	TabStrip.reset_onboarding_flag_for_tests()
	_runner = scene_runner("res://src/presentation/sanctuary_ui/SanctuaryUI.tscn")
	@warning_ignore("unsafe_cast")
	_shell = _runner.scene() as SanctuaryUI
	_tab_strip = _shell.get_node("Chrome/TabStrip") as TabStrip


func after_test() -> void:
	TabStrip.reset_onboarding_flag_for_tests()


# ---------------------------------------------------------------------------
# Badge appears on trigger, clears on entry (index 2 = Menagerie)
# ---------------------------------------------------------------------------

func test_menagerie_badge_appears_on_creature_returned_and_clears_on_entry() -> void:
	assert_bool(_tab_strip.is_badge_visible(2)).is_false()

	GEventBus.creature_returned_from_breeding_pen.emit(42)

	assert_bool(_tab_strip.is_badge_visible(2)).is_true()
	assert_int(_tab_strip.get_badge_count(2)).is_equal(1)

	_tab_strip.get_tab_button(2).pressed.emit()

	assert_bool(_tab_strip.is_badge_visible(2)).is_false()
	assert_int(_tab_strip.get_badge_count(2)).is_equal(0)


# ---------------------------------------------------------------------------
# Each of the other 3 room badges responds to its own real trigger signal
# ---------------------------------------------------------------------------

func test_inventory_crafting_badge_appears_on_recipe_discovered() -> void:
	GEventBus.recipe_discovered.emit("iron_foundation", "component")
	assert_bool(_tab_strip.is_badge_visible(1)).is_true()


func test_defense_building_badge_appears_on_sanctuary_structure_built() -> void:
	GEventBus.sanctuary_structure_built.emit("watchtower", "defensive")
	assert_bool(_tab_strip.is_badge_visible(3)).is_true()


func test_equipment_forge_badge_appears_on_item_rune_imbued() -> void:
	GEventBus.item_rune_imbued.emit("sword_001", "rune_flame", "constellation")
	assert_bool(_tab_strip.is_badge_visible(4)).is_true()


# ---------------------------------------------------------------------------
# Loadout (index 5) never shows a badge, under any trigger event
# ---------------------------------------------------------------------------

func test_loadout_never_shows_a_badge_under_any_trigger_event() -> void:
	GEventBus.recipe_discovered.emit("iron_foundation", "component")
	GEventBus.creature_returned_from_breeding_pen.emit(42)
	GEventBus.sanctuary_structure_built.emit("watchtower", "defensive")
	GEventBus.item_rune_imbued.emit("sword_001", "rune_flame", "constellation")

	assert_bool(_tab_strip.is_badge_visible(5)).is_false()


func test_overview_never_shows_a_badge_under_any_trigger_event() -> void:
	GEventBus.recipe_discovered.emit("iron_foundation", "component")
	GEventBus.creature_returned_from_breeding_pen.emit(42)
	GEventBus.sanctuary_structure_built.emit("watchtower", "defensive")
	GEventBus.item_rune_imbued.emit("sword_001", "rune_flame", "constellation")

	assert_bool(_tab_strip.is_badge_visible(0)).is_false()


# ---------------------------------------------------------------------------
# Badge fires for a room other than the currently active one, without
# touching the active room's own content (Core Rule 9's cross-system item)
# ---------------------------------------------------------------------------

func test_badge_fires_for_inactive_room_without_touching_active_tab_selection() -> void:
	_tab_strip.get_tab_button(2).pressed.emit()  # ROOM_MENAGERIE active
	assert_that(_shell.get_active_state()).is_equal(&"ROOM_MENAGERIE")

	GEventBus.recipe_discovered.emit("iron_foundation", "component")  # Inventory & Crafting (index 1)

	assert_bool(_tab_strip.is_badge_visible(1)).is_true()
	# Active selection is untouched by a badge arriving elsewhere.
	assert_that(_shell.get_active_state()).is_equal(&"ROOM_MENAGERIE")
	assert_int(_tab_strip.get_current_index()).is_equal(2)


# ---------------------------------------------------------------------------
# Multiple triggers before entry accumulate a count, not just a boolean
# ---------------------------------------------------------------------------

func test_multiple_triggers_before_entry_accumulate_count() -> void:
	GEventBus.recipe_discovered.emit("iron_foundation", "component")
	GEventBus.recipe_discovered.emit("silk_focus", "component")
	GEventBus.recipe_discovered.emit("amber_power", "component")

	assert_int(_tab_strip.get_badge_count(1)).is_equal(3)
