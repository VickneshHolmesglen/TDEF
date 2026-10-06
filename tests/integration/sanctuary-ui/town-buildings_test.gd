## Sanctuary town buildings (docs/superpowers/specs/2026-10-07-sanctuary-town-
## buildings-design.md): SanctuaryProgress scoring/tiers, TownBuildingView's
## placeholder growth and tier art, the 7 building data files, and the
## Overview diorama wiring (click opens the tab, Castle inert, info line).
extends GdUnitTestSuite

const BUILDINGS_DIR := "res://assets/data/sanctuary_buildings/"

var _runner: GdUnitSceneRunner
var _shell: SanctuaryUI


func _make_resource(target: StringName = &"ROOM_MENAGERIE") -> SanctuaryBuildingResource:
	var res := SanctuaryBuildingResource.new()
	res.building_id = &"test_building"
	res.name_key = "SANCTUARY_BUILDING_MENAGERIE"
	res.hint_key = "SANCTUARY_BUILDING_MENAGERIE_HINT"
	res.target_state = target
	res.position = Vector2(200, 300)
	res.footprint = Vector2(100, 120)
	return res


func _make_view(res: SanctuaryBuildingResource) -> TownBuildingView:
	var view: TownBuildingView = auto_free(TownBuildingView.new())
	view.setup(res)
	add_child(view)
	return view


func _open_shell() -> void:
	TabStrip.reset_onboarding_flag_for_tests()
	_runner = scene_runner("res://src/presentation/sanctuary_ui/SanctuaryUI.tscn")
	@warning_ignore("unsafe_cast")
	_shell = _runner.scene() as SanctuaryUI


func _town_view(id: StringName) -> TownBuildingView:
	return _shell.get_diorama().call("get_town_building", id) as TownBuildingView


# ---------------------------------------------------------------------------
# SanctuaryProgress (spec §2-3)
# ---------------------------------------------------------------------------

func test_tier_for_thresholds_at_each_20_percent() -> void:
	assert_int(SanctuaryProgress.tier_for(0.0)).is_equal(1)
	assert_int(SanctuaryProgress.tier_for(0.19)).is_equal(1)
	assert_int(SanctuaryProgress.tier_for(0.2)).is_equal(2)
	assert_int(SanctuaryProgress.tier_for(0.4)).is_equal(3)
	assert_int(SanctuaryProgress.tier_for(0.6)).is_equal(4)
	assert_int(SanctuaryProgress.tier_for(0.8)).is_equal(5)
	assert_int(SanctuaryProgress.tier_for(1.0)).is_equal(5)


func test_tier_for_clamps_out_of_range_scores() -> void:
	assert_int(SanctuaryProgress.tier_for(-0.5)).is_equal(1)
	assert_int(SanctuaryProgress.tier_for(3.0)).is_equal(5)


func test_scores_are_0_to_1_and_castle_is_the_mean_of_the_six() -> void:
	var scores: Dictionary[StringName, float] = SanctuaryProgress.scores(get_tree())
	var total: float = 0.0
	for id: StringName in SanctuaryProgress.BUILDING_IDS:
		assert_bool(scores.has(id)).override_failure_message("missing score %s" % id).is_true()
		assert_float(scores[id]).is_between(0.0, 1.0)
		total += scores[id]
	assert_float(scores[&"castle"]).is_equal_approx(total / 6.0, 0.0001)


func test_missing_scene_systems_score_zero_not_error() -> void:
	# No Crafting/EquipmentForge in a null tree: those terms are 0.
	assert_float(SanctuaryProgress.blacksmith(null)).is_equal(0.0)
	assert_float(SanctuaryProgress.armoury(null)).is_between(0.0, 0.5)


# ---------------------------------------------------------------------------
# Building data (spec §4)
# ---------------------------------------------------------------------------

func test_seven_building_files_validate_and_target_real_tabs() -> void:
	var ids: Array[StringName] = []
	for file: String in DirAccess.get_files_at(BUILDINGS_DIR):
		if not file.ends_with(".tres"):
			continue
		var res: SanctuaryBuildingResource = load(BUILDINGS_DIR + file)
		assert_array(res.validate()).override_failure_message("%s: %s" % [file, res.validate()]).is_empty()
		ids.append(res.building_id)
		if res.building_id == &"castle":
			assert_str(String(res.target_state)).is_empty()
		else:
			assert_bool(TabStrip.TAB_TARGETS.has(res.target_state)) \
				.override_failure_message("%s targets unknown tab %s" % [file, res.target_state]).is_true()
	assert_int(ids.size()).is_equal(7)
	for id: StringName in SanctuaryProgress.BUILDING_IDS:
		assert_bool(ids.has(id)).override_failure_message("no data file for %s" % id).is_true()
	assert_bool(ids.has(&"castle")).is_true()


# ---------------------------------------------------------------------------
# TownBuildingView (spec §4)
# ---------------------------------------------------------------------------

func test_view_is_placed_bottom_centre_on_its_data_position() -> void:
	var view := _make_view(_make_resource())
	assert_vector(view.position + Vector2(view.size.x * 0.5, view.size.y)).is_equal(Vector2(200, 300))
	assert_int(view.focus_mode).is_equal(Control.FOCUS_ALL)


func test_placeholder_grows_with_tier_and_fills_the_footprint_at_tier_5() -> void:
	var view := _make_view(_make_resource())
	view.set_progress(0.0)
	var tier_1_height: float = view.placeholder_height()
	view.set_progress(0.45)
	var tier_3_height: float = view.placeholder_height()
	view.set_progress(1.0)
	assert_float(tier_3_height).is_greater(tier_1_height)
	assert_float(view.placeholder_height()).is_greater(tier_3_height)
	assert_float(view.placeholder_height()).is_equal_approx(view.size.y, 0.001)


func test_set_progress_reports_only_tier_rises() -> void:
	var view := _make_view(_make_resource())
	assert_bool(view.set_progress(0.1)).is_false()  # still tier 1
	assert_bool(view.set_progress(0.45)).is_true()  # 1 -> 3
	assert_int(view.tier).is_equal(3)
	assert_bool(view.set_progress(0.3)).is_false()  # drop to 2 is not a rise
	assert_int(view.tier).is_equal(2)


func test_tier_texture_replaces_the_placeholder_without_code_change() -> void:
	var res := _make_resource()
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	res.tier_textures[2] = ImageTexture.create_from_image(image)
	var view := _make_view(res)
	var art: TextureRect = view.get_node("Art")
	view.set_progress(0.1)
	assert_bool(view.has_tier_art()).is_false()
	assert_bool(art.visible).is_false()
	view.set_progress(0.45)
	assert_bool(view.has_tier_art()).is_true()
	assert_bool(art.visible).is_true()
	assert_object(art.texture).is_same(res.tier_textures[2])


# ---------------------------------------------------------------------------
# Overview diorama wiring (spec §4, acceptance 1/3/4)
# ---------------------------------------------------------------------------

func test_overview_shows_all_seven_buildings_and_no_old_castle_card() -> void:
	_open_shell()
	var ids: Array[StringName] = SanctuaryProgress.BUILDING_IDS.duplicate()
	ids.append(&"castle")
	for id: StringName in ids:
		assert_object(_town_view(id)).override_failure_message("no view for %s" % id).is_not_null()
	var town: Node = _shell.get_diorama().find_child("Town", true, false)
	assert_int(town.get_child_count()).is_equal(7)


func test_clicking_a_building_opens_its_tab() -> void:
	_open_shell()
	_town_view(&"menagerie").pressed.emit()
	assert_that(_shell.get_active_state()).is_equal(&"ROOM_MENAGERIE")
	_town_view(&"keep").pressed.emit()
	assert_that(_shell.get_active_state()).is_equal(&"ROOM_DEFENSE_BUILDING")


func test_seers_tower_routes_to_loadout_and_castle_emits_nothing() -> void:
	_open_shell()
	var emitted: Array[StringName] = []
	_shell.get_diorama().connect(&"building_selected", func(t: StringName) -> void: emitted.append(t))
	_town_view(&"castle").pressed.emit()
	assert_array(emitted).is_empty()
	# Inspect the emitted target rather than letting it start the real
	# Loadout scene transition inside a test.
	_shell.get_diorama().disconnect(&"building_selected", _shell.get_tab_strip_for_test().select_target)
	_town_view(&"seers_tower").pressed.emit()
	assert_array(emitted).contains_exactly([&"DEPARTING_TO_LOADOUT"])


func test_tab_strip_select_target_ignores_unknown_targets() -> void:
	_open_shell()
	_shell.get_tab_strip_for_test().select_target(&"NOT_A_TAB")
	assert_that(_shell.get_active_state()).is_equal(&"OVERVIEW")


func test_info_line_follows_hover_then_returns_to_prompt() -> void:
	_open_shell()
	var info: Label = _shell.get_diorama().find_child("TownInfo", true, false)
	var prompt: String = info.text
	_town_view(&"blacksmith").mouse_entered.emit()
	assert_str(info.text).is_not_equal(prompt)
	assert_str(info.text).contains(tr("SANCTUARY_BUILDING_BLACKSMITH"))
	_town_view(&"blacksmith").mouse_exited.emit()
	assert_str(info.text).is_equal(prompt)
