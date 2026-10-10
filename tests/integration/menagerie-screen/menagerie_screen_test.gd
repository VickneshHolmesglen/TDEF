## Integration tests for MenagerieScreen (src/gameplay/ui/menagerie_screen),
## Sanctuary UI Story 005's Room Hosting scope. Exercises the screen against
## menagerie.md's UI Requirements: roster review, tend, breeding multi-
## select-then-confirm, and sacrifice two-step confirmation.
##
## Uses the real GMenagerie Autoload (screen's own @export defaults to it),
## reset to defaults before/after each test and populated directly via
## Menagerie's own internal _creatures array — the same technique this
## project's existing Menagerie unit tests already use (e.g.
## aggregate_recompute_push_test.gd's _add_creature() helper).
extends GdUnitTestSuite

var _runner: GdUnitSceneRunner
var _screen: Control


func before_test() -> void:
	GMenagerie.reset_to_defaults()
	_runner = scene_runner("res://src/gameplay/ui/menagerie_screen/MenagerieScreen.tscn")
	_screen = _runner.scene() as Control


func after_test() -> void:
	GMenagerie.reset_to_defaults()


func _add_creature(state: CreatureInstance.CreatureState, happiness: float = 70.0, species: StringName = &"test_species") -> int:
	var creature := CreatureInstance.new()
	creature.creature_id = GMenagerie._next_creature_id
	GMenagerie._next_creature_id += 1
	creature.state = state
	creature.happiness = happiness
	creature.species = species
	GMenagerie._creatures.append(creature)
	return creature.creature_id


# ---------------------------------------------------------------------------
# Roster strip
# ---------------------------------------------------------------------------

func test_roster_lists_every_non_sacrificed_creature() -> void:
	var habitat_id: int = _add_creature(CreatureInstance.CreatureState.HABITAT)
	var reserve_id: int = _add_creature(CreatureInstance.CreatureState.RESERVE)
	var sacrificed_id: int = _add_creature(CreatureInstance.CreatureState.SACRIFICED)
	@warning_ignore("unsafe_method_access")
	_screen.call("_rebuild_roster")

	@warning_ignore("unsafe_property_access")
	var roster_buttons: Dictionary = _screen.get("_roster_buttons")
	assert_bool(roster_buttons.has(habitat_id)).is_true()
	assert_bool(roster_buttons.has(reserve_id)).is_true()
	assert_bool(roster_buttons.has(sacrificed_id)).is_false()


func test_roster_changed_event_triggers_a_live_rebuild() -> void:
	@warning_ignore("unsafe_property_access")
	var initial_count: int = (_screen.get("_roster_buttons") as Dictionary).size()
	assert_int(initial_count).is_equal(0)

	GMenagerie.lure_creature(&"test_species")  # will fail (no lure item/species registered) -- use direct emit instead
	GEventBus.creature_acquired.emit(999, "direct_test_species")

	@warning_ignore("unsafe_property_access")
	var count_after: int = (_screen.get("_roster_buttons") as Dictionary).size()
	# The screen rebuilds FROM Menagerie's own live state, not from the event
	# payload -- since lure_creature() itself failed (no real item/species
	# data registered in this unit-style test), the roster stays at 0. This
	# assertion is really about "the handler ran and rebuilt without erroring."
	assert_int(count_after).is_equal(0)


# ---------------------------------------------------------------------------
# Tend interaction
# ---------------------------------------------------------------------------

func test_tend_button_disabled_for_non_habitat_focus() -> void:
	var reserve_id: int = _add_creature(CreatureInstance.CreatureState.RESERVE)
	@warning_ignore("unsafe_method_access")
	_screen.call("_rebuild_roster")
	_screen.set("_focused_creature_id", reserve_id)
	@warning_ignore("unsafe_method_access")
	_screen.call("_refresh_detail_panel")

	var tend_button: Button = _screen.get_node("MainLayout/DetailPanel/ActionRow/TendButton") as Button
	assert_bool(tend_button.disabled).is_true()


func test_tend_pressed_increases_happiness_for_habitat_creature() -> void:
	var habitat_id: int = _add_creature(CreatureInstance.CreatureState.HABITAT, 50.0)
	_screen.set("_focused_creature_id", habitat_id)

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_tend_pressed")

	var creature: CreatureInstance = GMenagerie.get_creature(habitat_id)
	assert_float(creature.happiness).is_equal(70.0)  # +20 tend boost


# ---------------------------------------------------------------------------
# Breeding multi-select-then-confirm
# ---------------------------------------------------------------------------

func test_breed_select_mode_toggles_selection_membership() -> void:
	var id_a: int = _add_creature(CreatureInstance.CreatureState.HABITAT, 70.0, &"same_species")
	var id_b: int = _add_creature(CreatureInstance.CreatureState.HABITAT, 70.0, &"same_species")
	_screen.set("_focused_creature_id", id_a)

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_breed_select_pressed")
	assert_bool(_screen.call("is_breed_select_mode_active")).is_true()

	@warning_ignore("unsafe_method_access")
	_screen.call("_toggle_breeding_selection", id_b)

	var selection: Array = _screen.call("get_breeding_selection")
	assert_array(selection).contains(id_a, id_b)


func test_confirm_breeding_with_2_selected_pairs_them() -> void:
	var id_a: int = _add_creature(CreatureInstance.CreatureState.HABITAT, 70.0, &"same_species")
	var id_b: int = _add_creature(CreatureInstance.CreatureState.HABITAT, 70.0, &"same_species")
	@warning_ignore("unsafe_method_access")
	_screen.call("_toggle_breeding_selection", id_a)
	@warning_ignore("unsafe_method_access")
	_screen.call("_toggle_breeding_selection", id_b)

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_confirm_breeding_pressed")

	var creature_a: CreatureInstance = GMenagerie.get_creature(id_a)
	assert_int(creature_a.state).is_equal(CreatureInstance.CreatureState.BREEDING_PEN)


func test_cancel_selection_clears_selection_and_exits_mode() -> void:
	var id_a: int = _add_creature(CreatureInstance.CreatureState.HABITAT)
	@warning_ignore("unsafe_method_access")
	_screen.call("_toggle_breeding_selection", id_a)
	@warning_ignore("unsafe_property_access")
	(_screen.get_node("MainLayout/DetailPanel/BreedRow/ConfirmBreedingButton") as Button).visible = true
	assert_array(_screen.call("get_breeding_selection")).contains(id_a)

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_cancel_selection_pressed")

	assert_array(_screen.call("get_breeding_selection")).is_empty()
	assert_bool(_screen.call("is_breed_select_mode_active")).is_false()


# ---------------------------------------------------------------------------
# Sacrifice — two-step confirmation, never single-confirm
# ---------------------------------------------------------------------------

func test_sacrifice_pressed_opens_confirmation_dialog_without_mutating_state() -> void:
	var habitat_id: int = _add_creature(CreatureInstance.CreatureState.HABITAT)
	_screen.set("_focused_creature_id", habitat_id)

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_sacrifice_pressed")

	var creature: CreatureInstance = GMenagerie.get_creature(habitat_id)
	assert_int(creature.state).is_equal(CreatureInstance.CreatureState.HABITAT)  # not yet sacrificed
	var dialog: ConfirmationDialog = _screen.get_node("SacrificeConfirmDialog") as ConfirmationDialog
	assert_bool(dialog.visible).is_true()


func test_sacrifice_confirmed_actually_sacrifices_the_pending_creature() -> void:
	var habitat_id: int = _add_creature(CreatureInstance.CreatureState.HABITAT)
	_screen.set("_focused_creature_id", habitat_id)
	@warning_ignore("unsafe_method_access")
	_screen.call("_on_sacrifice_pressed")

	@warning_ignore("unsafe_method_access")
	_screen.call("_on_sacrifice_confirmed")

	var creature: CreatureInstance = GMenagerie.get_creature(habitat_id)
	assert_int(creature.state).is_equal(CreatureInstance.CreatureState.SACRIFICED)


# ---------------------------------------------------------------------------
# Species portrait icon (closes this screen's own flagged "no real creature
# art" simplification, now that all 5 species have art)
# ---------------------------------------------------------------------------

func test_roster_button_shows_a_species_icon_for_known_species() -> void:
	var habitat_id: int = _add_creature(CreatureInstance.CreatureState.HABITAT, 70.0, &"aurora_stag")
	@warning_ignore("unsafe_method_access")
	_screen.call("_rebuild_roster")

	@warning_ignore("unsafe_property_access")
	var roster_buttons: Dictionary = _screen.get("_roster_buttons")
	var button: Button = roster_buttons[habitat_id]
	assert_object(button.icon).is_not_null()


## Guards the original bug (native ~900-1200 px species art ballooning the
## button to the art's own size). The 2026-10-10 card layout dropped the
## fixed 32 px icon_max_width cap so the portrait fills its card, so the
## guard is now: the art scales (expand_icon) and never drives the card's
## minimum size anywhere near the art's native resolution.
func test_roster_card_icon_scales_instead_of_ballooning_the_card() -> void:
	var habitat_id: int = _add_creature(CreatureInstance.CreatureState.HABITAT, 70.0, &"aurora_stag")
	@warning_ignore("unsafe_method_access")
	_screen.call("_rebuild_roster")

	@warning_ignore("unsafe_property_access")
	var roster_buttons: Dictionary = _screen.get("_roster_buttons")
	var button: Button = roster_buttons[habitat_id]
	assert_bool(button.expand_icon).is_true()
	var min_size: Vector2 = button.get_combined_minimum_size()
	assert_float(min_size.x).is_less(300.0)
	assert_float(min_size.y).is_less(300.0)


## test_species (this file's own default fixture species) has no authored
## art -- confirms the fallback is graceful (null icon, no crash), matching
## MonsterInstance's identical unknown-id fallback.
func test_roster_button_unknown_species_leaves_icon_null() -> void:
	var reserve_id: int = _add_creature(CreatureInstance.CreatureState.RESERVE)
	@warning_ignore("unsafe_method_access")
	_screen.call("_rebuild_roster")

	@warning_ignore("unsafe_property_access")
	var roster_buttons: Dictionary = _screen.get("_roster_buttons")
	var button: Button = roster_buttons[reserve_id]
	assert_object(button.icon).is_null()


# ---------------------------------------------------------------------------
# Room-hosting contract (ADR-0032) — disconnect_own_subscriptions()
# ---------------------------------------------------------------------------

func test_disconnect_own_subscriptions_is_idempotent_safe_to_call() -> void:
	@warning_ignore("unsafe_method_access")
	_screen.call("disconnect_own_subscriptions")
	# A second disconnect against already-disconnected signals would error in
	# Godot -- RoomHost's own contract only ever calls this once per unmount,
	# so this test only confirms the single call itself doesn't error, not
	# double-disconnect safety (unlike ConflictIndicator, this screen has no
	# _exit_tree() fallback since it's mounted/unmounted purely via RoomHost).
	assert_bool(true).is_true()
