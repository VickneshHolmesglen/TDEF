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
	# has_meta first: get_meta() with a null default still logs an engine error for a missing key.
	return button.get_meta(UiAudioBinder.META_KEY) if button.has_meta(UiAudioBinder.META_KEY) else null


## Returns the body text of `func_name` in the script at `path` ("" if absent).
func _func_body(path: String, func_name: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var lines: PackedStringArray = file.get_as_text().split("\n")
	var body: PackedStringArray = []
	var inside: bool = false
	for line: String in lines:
		if line.begins_with("func %s(" % func_name):
			inside = true
			continue
		if inside and (line.begins_with("func ") or line.begins_with("static func ")):
			break
		if inside:
			body.append(line)
	return "\n".join(body)


func _annotated_in(path: String, func_name: String, expr: String, kind_const: String) -> bool:
	return _func_body(path, func_name).contains("%s.set_meta(UiAudioBinder.META_KEY, UiAudioBinder.%s)" % [expr, kind_const])


func _unannotated_in(path: String, func_name: String, expr: String) -> bool:
	var body: String = _func_body(path, func_name)
	return not body.is_empty() and not body.contains("%s.set_meta(UiAudioBinder.META_KEY" % expr)


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


const SANCTUARY_UI: String = "res://src/presentation/sanctuary_ui/sanctuary_ui.gd"
const TAROT_DECK_UI: String = "res://src/presentation/tarot_deck_ui/tarot_deck_ui.gd"
const MISSION_HUD: String = "res://src/presentation/mission_hud/mission_hud.gd"
const MENAGERIE: String = "res://src/gameplay/ui/menagerie_screen/menagerie_screen.gd"
const FORGE: String = "res://src/gameplay/ui/equipment_forge_screen/equipment_forge_screen.gd"
const INVENTORY: String = "res://src/gameplay/ui/inventory_screen/inventory_screen.gd"
const DEFENSE: String = "res://src/gameplay/ui/defense_building_screen/defense_building_screen.gd"
const MAIN_MENU: String = "res://src/scenes/main_menu.gd"


func test_source_level_confirm_and_cancel_annotations() -> void:
	assert_bool(_annotated_in(SANCTUARY_UI, "_ready", "_launch_mission_button", "KIND_CONFIRM")).is_true()
	assert_bool(_annotated_in(TAROT_DECK_UI, "_configure_return_to_sanctuary_button", "_return_to_sanctuary_button", "KIND_CANCEL")).is_true()
	assert_bool(_annotated_in(MISSION_HUD, "_ready", "_retry_button", "KIND_CONFIRM")).is_true()
	assert_bool(_annotated_in(MENAGERIE, "_ready", "_cancel_selection_button", "KIND_CANCEL")).is_true()
	assert_bool(_annotated_in(FORGE, "_ready", "_imbue_cancel_button", "KIND_CANCEL")).is_true()


func test_inventory_craft_repair_none_and_forge_defense_buttons_default() -> void:
	# Inventory craft/repair are disabled when non-viable, so a rejected press gets the denial cue.
	assert_bool(_annotated_in(INVENTORY, "_create_recipe_row", "craft_button", "KIND_NONE")).is_true()
	assert_bool(_annotated_in(INVENTORY, "_create_repair_row", "repair_button", "KIND_NONE")).is_true()
	# These two are never disabled: a rejected press must not be silent, so they stay default click.
	assert_bool(_unannotated_in(DEFENSE, "_create_structure_button", "button")).is_true()
	assert_bool(_unannotated_in(FORGE, "_create_recipe_button", "button")).is_true()


func test_confirmation_dialog_buttons_annotated() -> void:
	assert_bool(_annotated_in(FORGE, "_ready", "_imbue_confirm_dialog.get_cancel_button()", "KIND_CANCEL")).is_true()
	assert_bool(_annotated_in(FORGE, "_ready", "_imbue_confirm_dialog.get_ok_button()", "KIND_CONFIRM")).is_true()
	assert_bool(_annotated_in(FORGE, "_ready", "_upgrade_confirm_dialog.get_cancel_button()", "KIND_CANCEL")).is_true()
	assert_bool(_annotated_in(FORGE, "_ready", "_upgrade_confirm_dialog.get_ok_button()", "KIND_NONE")).is_true()
	assert_bool(_annotated_in(INVENTORY, "_ready", "_assemble_confirm_dialog.get_cancel_button()", "KIND_CANCEL")).is_true()
	assert_bool(_annotated_in(INVENTORY, "_ready", "_assemble_confirm_dialog.get_ok_button()", "KIND_CONFIRM")).is_true()
	assert_bool(_annotated_in(MENAGERIE, "_ready", "_sacrifice_confirm_dialog.get_cancel_button()", "KIND_CANCEL")).is_true()
	assert_bool(_annotated_in(MENAGERIE, "_ready", "_sacrifice_confirm_dialog.get_ok_button()", "KIND_CONFIRM")).is_true()


func test_main_menu_back_and_cancel_buttons_annotated() -> void:
	assert_bool(_annotated_in(MAIN_MENU, "_ready", "_settings_back_button", "KIND_CANCEL")).is_true()
	assert_bool(_annotated_in(MAIN_MENU, "_ready", "_load_game_back_button", "KIND_CANCEL")).is_true()
	assert_bool(_annotated_in(MAIN_MENU, "_ready", "_overwrite_cancel_button", "KIND_CANCEL")).is_true()
