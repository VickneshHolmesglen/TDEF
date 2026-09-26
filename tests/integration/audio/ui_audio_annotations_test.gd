## Verifies the per-button `ui_audio` meta annotations (UI audio cues spec
## §3): confirm on primary actions, cancel on back/close, none where the
## action already plays its own event cue. Screens that mount cheaply are
## instantiated; screens needing heavy fixtures (Sanctuary rooms, Inventory,
## Forge, Defense Building, Menagerie, Tarot Deck UI) are checked at source
## level for the exact annotation line next to the button.
extends GdUnitTestSuite

const OUTCOME_SCENE: String = "res://src/presentation/mission_outcome/MissionOutcomeScreen.tscn"
const PAUSE_MENU_SCENE: PackedScene = preload("res://src/gameplay/ui/pause_menu/pause_menu.tscn")
const MISSION_SELECT_SCENE: String = "res://src/gameplay/ui/mission_select_screen/MissionSelectScreen.tscn"


func _meta(button: BaseButton) -> Variant:
	return button.get_meta(UiAudioBinder.META_KEY, null)


func _source_has(path: String, button_var: String, kind_const: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text: String = file.get_as_text()
	return text.contains("%s.set_meta(UiAudioBinder.META_KEY, UiAudioBinder.%s)" % [button_var, kind_const])


func test_cue_for_annotated_kinds() -> void:
	assert_str(String(UiAudioBinder.cue_for(UiAudioBinder.KIND_CONFIRM))).is_equal("ui_confirm")
	assert_str(String(UiAudioBinder.cue_for(UiAudioBinder.KIND_CANCEL))).is_equal("ui_cancel")
	assert_str(String(UiAudioBinder.cue_for(UiAudioBinder.KIND_NONE))).is_equal("")
	assert_str(String(UiAudioBinder.cue_for(null))).is_equal("ui_click")


func test_outcome_screen_retry_confirm_return_default() -> void:
	var screen: Node = load(OUTCOME_SCENE).instantiate()
	add_child(screen)
	var retry: Button = screen.find_child("RetryButton", true, false) as Button
	var sanctuary: Button = screen.find_child("SanctuaryButton", true, false) as Button
	assert_object(retry).is_not_null()
	assert_object(sanctuary).is_not_null()
	assert_str(String(_meta(retry))).is_equal(String(UiAudioBinder.KIND_CONFIRM))
	assert_bool(sanctuary.has_meta(UiAudioBinder.META_KEY)).is_false()
	screen.queue_free()


func test_mission_select_launch_confirm_back_cancel() -> void:
	var runner: GdUnitSceneRunner = scene_runner(MISSION_SELECT_SCENE)
	var screen: Node = runner.scene()
	var launch: Button = screen.call("get_launch_button") as Button
	var back: Button = screen.get("_back_button") as Button
	assert_str(String(_meta(launch))).is_equal(String(UiAudioBinder.KIND_CONFIRM))
	assert_str(String(_meta(back))).is_equal(String(UiAudioBinder.KIND_CANCEL))


func test_pause_menu_back_and_cancel_buttons() -> void:
	var menu: CanvasLayer = PAUSE_MENU_SCENE.instantiate()
	add_child(menu)
	for var_name: String in ["_settings_back_button", "_objective_back_button", "_quit_confirm_cancel_button"]:
		var button: Button = menu.get(var_name) as Button
		assert_object(button).is_not_null()
		assert_str(String(_meta(button))).is_equal(String(UiAudioBinder.KIND_CANCEL))
	assert_bool((menu.get("_resume_button") as Button).has_meta(UiAudioBinder.META_KEY)).is_false()
	menu.queue_free()


func test_hud_ready_button_confirm() -> void:
	var cfg := GridConfig.new()
	cfg.cols = 1
	cfg.rows = 1
	cfg.cell_size = 64.0
	cfg.cells = {Vector2i(0, 0): Grid.CellType.SPAWN}
	GGrid.initialize(cfg)
	var hud: MissionHud = MissionHudTestHelper.build_hud()
	add_child(hud)
	hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	var ready_button: Button = hud._planning_cluster._ready_button
	assert_str(String(_meta(ready_button))).is_equal(String(UiAudioBinder.KIND_CONFIRM))
	hud.queue_free()


func test_source_level_confirm_and_cancel_annotations() -> void:
	assert_bool(_source_has("res://src/presentation/sanctuary_ui/sanctuary_ui.gd", "_launch_mission_button", "KIND_CONFIRM")).is_true()
	assert_bool(_source_has("res://src/presentation/tarot_deck_ui/tarot_deck_ui.gd", "_return_to_sanctuary_button", "KIND_CANCEL")).is_true()
	assert_bool(_source_has("res://src/presentation/mission_hud/mission_hud.gd", "_retry_button", "KIND_CONFIRM")).is_true()
	assert_bool(_source_has("res://src/gameplay/ui/menagerie_screen/menagerie_screen.gd", "_cancel_selection_button", "KIND_CANCEL")).is_true()
	assert_bool(_source_has("res://src/gameplay/ui/equipment_forge_screen/equipment_forge_screen.gd", "_imbue_cancel_button", "KIND_CANCEL")).is_true()


func test_source_level_none_annotations_for_self_cued_actions() -> void:
	assert_bool(_source_has("res://src/gameplay/ui/inventory_screen/inventory_screen.gd", "craft_button", "KIND_NONE")).is_true()
	assert_bool(_source_has("res://src/gameplay/ui/inventory_screen/inventory_screen.gd", "repair_button", "KIND_NONE")).is_true()
	assert_bool(_source_has("res://src/gameplay/ui/defense_building_screen/defense_building_screen.gd", "button", "KIND_NONE")).is_true()
	assert_bool(_source_has("res://src/gameplay/ui/equipment_forge_screen/equipment_forge_screen.gd", "button", "KIND_NONE")).is_true()
