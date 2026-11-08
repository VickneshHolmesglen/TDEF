## Integration tests for the Tower Build Panel (design/gdd/tower.md's Visual/
## Audio Requirements, design/ux/mission-hud.md Zone E) — the one Planning
## Cluster element the GDD named but no prior story had implemented (see
## planning_cluster.tscn's own now-replaced BuildListPlaceholder/
## CellOverlayPlaceholder scaffold nodes). Added 2026-08-10.
##
## Real GGameDataRegistry.get_all_tower_blueprints() content is used
## throughout (4 authored blueprints as of this writing: archer,
## frostbolt_turret, longshot_sniper, rally_banner — costs 10/10/12/12) —
## matches this epic's established precedent of testing against real data
## rather than injected fixtures for this class of read-only list.
extends GdUnitTestSuite

var _hud: MissionHud


func before_test() -> void:
	# TD-test-004: direct call, not a grid_initialized broadcast (its real
	# reset trigger since 2026-08-11 — see mission_economy.gd; rationale
	# otherwise identical to tests/unit/tower/tower_placement_test.gd) —
	# resets GMissionEconomy's real balance to a known 0 baseline.
	GMissionEconomy._on_grid_initialized(0, 0, 0.0)
	var config := GridConfig.new()
	config.cols = 1
	config.rows = 1
	config.cell_size = 64.0
	config.cells = {Vector2i(0, 0): Grid.CellType.SPAWN}
	GGrid.initialize(config)
	_hud = MissionHudTestHelper.build_hud()
	add_child(_hud)
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)


func after_test() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null
	GMissionEconomy._on_grid_initialized(0, 0, 0.0)


func _cluster() -> PlanningCluster:
	return _hud._planning_cluster


# ---------------------------------------------------------------------------
# List population
# ---------------------------------------------------------------------------

func test_build_list_has_one_entry_per_real_blueprint() -> void:
	var blueprints: Dictionary = GGameDataRegistry.get_all_tower_blueprints()
	@warning_ignore("unsafe_property_access")
	var build_buttons: Dictionary = _cluster().get("_build_buttons")
	assert_int(build_buttons.size()).is_equal(blueprints.size())
	assert_bool(build_buttons.has(&"archer")).is_true()
	assert_bool(build_buttons.has(&"frostbolt_turret")).is_true()


## Tiles are icon-only (2026-08-11 redesign) — details live in tooltip_text,
## shown on hover, not in the button's own always-visible text.
func test_entry_tooltip_contains_display_name_and_cost() -> void:
	@warning_ignore("unsafe_property_access")
	var build_buttons: Dictionary = _cluster().get("_build_buttons")
	var button: Button = build_buttons[&"archer"]
	assert_str(button.text).is_equal("")
	assert_str(button.tooltip_text).contains("Archer Tower")
	assert_str(button.tooltip_text).contains("10g")


func test_aura_weapon_shows_buff_not_a_misleading_dps_number() -> void:
	# rally_banner is a Support/AURA tower — "8 DPS" would misdescribe a
	# damage-buff aura that deals no damage itself.
	@warning_ignore("unsafe_property_access")
	var build_buttons: Dictionary = _cluster().get("_build_buttons")
	var button: Button = build_buttons[&"rally_banner"]
	assert_str(button.tooltip_text).contains("Aura:")
	assert_str(button.tooltip_text).not_contains("DPS")


func test_tile_is_square_and_icon_only() -> void:
	@warning_ignore("unsafe_property_access")
	var build_buttons: Dictionary = _cluster().get("_build_buttons")
	var button: Button = build_buttons[&"archer"]
	assert_that(button.custom_minimum_size).is_equal(PlanningCluster.TILE_SIZE)


# ---------------------------------------------------------------------------
# Icons — each tile is a render of the 3D model the blueprint places
# (ADR-0043). Player-reported 2026-11-08: tiles still showed the old 2D
# per-archetype art, which matched neither the 3D towers nor each other.
# ---------------------------------------------------------------------------

func _tower_views() -> Dictionary:
	@warning_ignore("unsafe_property_access")
	return _cluster().get("_tower_views")


func test_build_panel_icon_is_render_of_placed_3d_model() -> void:
	# Arrange
	var blueprints: Dictionary = GGameDataRegistry.get_all_tower_blueprints()
	@warning_ignore("unsafe_property_access")
	var build_buttons: Dictionary = _cluster().get("_build_buttons")
	for blueprint_id: StringName in blueprints:
		var data: TowerBlueprintData = blueprints[blueprint_id]
		var keys: Array[StringName] = TowerInstance.model_keys(data.foundation.archetype,
				data.foundation.component_id, data.weapon.component_id if data.weapon != null else "")
		if keys.is_empty():
			continue
		# Act
		var view: TowerViewport3D = _tower_views().get(blueprint_id) as TowerViewport3D
		# Assert: the tile shows this view, whose model is the placed tower's
		assert_object(view).override_failure_message("no 3D icon for %s" % blueprint_id).is_not_null()
		assert_object((build_buttons[blueprint_id] as Button).icon).is_equal(view.get_texture())
		var crown: Node3D = view.model.get_child(2) as Node3D
		assert_str(crown.scene_file_path).contains(String(keys[1]))
		assert_str((view.model.get_child(0) as Node3D).scene_file_path).contains("base_" + String(keys[0]))


func test_build_panel_icons_differ_between_blueprints_with_same_archetype() -> void:
	# Arrange: archer and longshot_sniper share the physical archetype art
	@warning_ignore("unsafe_property_access")
	var build_buttons: Dictionary = _cluster().get("_build_buttons")
	# Act
	var archer: Texture2D = (build_buttons[&"archer"] as Button).icon
	var longshot: Texture2D = (build_buttons[&"longshot_sniper"] as Button).icon
	# Assert
	assert_object(archer).is_not_null()
	assert_object(archer).is_not_same(longshot)


# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------

func test_pressing_an_entry_emits_tower_blueprint_selected() -> void:
	var spy := EventBusSpy.new()
	spy.watch(GEventBus.tower_blueprint_selected)

	@warning_ignore("unsafe_property_access")
	var build_buttons: Dictionary = _cluster().get("_build_buttons")
	var button: Button = build_buttons[&"longshot_sniper"]
	button.pressed.emit()

	assert_bool(spy.was_emitted("tower_blueprint_selected")).is_true()
	var args: Array = (spy.emissions["tower_blueprint_selected"] as Array)[0] as Array
	assert_str(String(args[0])).is_equal("longshot_sniper")
	spy.disconnect_all()


# ---------------------------------------------------------------------------
# Affordability (GMissionEconomy.can_afford(), direct read — see
# _on_resources_changed()'s own doc comment for why this doesn't derive
# affordability from resources_changed's own delta payload)
# ---------------------------------------------------------------------------

func test_unaffordable_entry_is_disabled_at_zero_gold() -> void:
	@warning_ignore("unsafe_property_access")
	var build_buttons: Dictionary = _cluster().get("_build_buttons")
	var button: Button = build_buttons[&"archer"]  # costs 10, balance is 0
	assert_bool(button.disabled).is_true()


func test_entry_becomes_enabled_once_gold_covers_its_cost() -> void:
	GEventBus.resources_changed.emit(10, &"test_setup")

	@warning_ignore("unsafe_property_access")
	var build_buttons: Dictionary = _cluster().get("_build_buttons")
	var button: Button = build_buttons[&"archer"]
	assert_bool(button.disabled).is_false()


func test_entry_becomes_disabled_again_after_spending_below_its_cost() -> void:
	GEventBus.resources_changed.emit(10, &"test_setup")
	GEventBus.resources_changed.emit(-10, &"test_spend")

	@warning_ignore("unsafe_property_access")
	var build_buttons: Dictionary = _cluster().get("_build_buttons")
	var button: Button = build_buttons[&"archer"]
	assert_bool(button.disabled).is_true()


# ---------------------------------------------------------------------------
# PRE_WAVE interactivity (Rule 6) — build buttons are nested one level under
# NonReadyControls (inside BuildList), so the pre-existing direct-children
# loop in set_pre_wave_interactivity() cannot reach them without the
# dedicated pass this story added.
# ---------------------------------------------------------------------------

func test_pre_wave_disables_every_build_button() -> void:
	GEventBus.resources_changed.emit(100, &"test_setup")  # affordable, to isolate the PRE_WAVE effect
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)

	@warning_ignore("unsafe_property_access")
	var build_buttons: Dictionary = _cluster().get("_build_buttons")
	for button: Button in build_buttons.values():
		assert_bool(button.disabled).is_true()


func test_intermission_restores_affordable_buttons() -> void:
	GEventBus.resources_changed.emit(100, &"test_setup")
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)
	_hud._on_mission_phase_changed("WAVE_ACTIVE", "INTERMISSION", 0.0)

	@warning_ignore("unsafe_property_access")
	var build_buttons: Dictionary = _cluster().get("_build_buttons")
	for button: Button in build_buttons.values():
		assert_bool(button.disabled).is_false()


# ---------------------------------------------------------------------------
# Grid Placement Cursor (design/ux/interaction-patterns.md)
# ---------------------------------------------------------------------------

func test_preview_update_shows_valid_colored_cursor() -> void:
	_cluster()._on_tower_placement_preview_updated(Vector2i(0, 0), Vector2i(1, 1), true)

	@warning_ignore("unsafe_property_access")
	var cursor: ColorRect = _cluster().get("_placement_cursor")
	assert_bool(cursor.visible).is_true()
	assert_that(cursor.color).is_equal(PlanningCluster.PLACEMENT_VALID_COLOR)


func test_preview_update_shows_invalid_colored_cursor() -> void:
	_cluster()._on_tower_placement_preview_updated(Vector2i(0, 0), Vector2i(1, 1), false)

	@warning_ignore("unsafe_property_access")
	var cursor: ColorRect = _cluster().get("_placement_cursor")
	assert_bool(cursor.visible).is_true()
	assert_that(cursor.color).is_equal(PlanningCluster.PLACEMENT_INVALID_COLOR)


func test_sentinel_cell_hides_the_cursor() -> void:
	_cluster()._on_tower_placement_preview_updated(Vector2i(0, 0), Vector2i(1, 1), true)
	_cluster()._on_tower_placement_preview_updated(Vector2i(-1, -1), Vector2i.ZERO, false)

	@warning_ignore("unsafe_property_access")
	var cursor: ColorRect = _cluster().get("_placement_cursor")
	assert_bool(cursor.visible).is_false()


func test_cursor_size_scales_with_footprint() -> void:
	_cluster()._on_tower_placement_preview_updated(Vector2i(0, 0), Vector2i(2, 2), true)

	@warning_ignore("unsafe_property_access")
	var cursor: ColorRect = _cluster().get("_placement_cursor")
	assert_that(cursor.size).is_equal(Vector2(128.0, 128.0))  # 2x2 footprint * 64px cells


# ---------------------------------------------------------------------------
# Translucent placement drag-preview (2026-08-10, player-requested addition):
# "a translucent image of it should follow my mouse to the point i place it".
# ---------------------------------------------------------------------------

func test_selecting_a_tile_shows_its_translucent_3d_icon_at_preview() -> void:
	var blueprints: Dictionary = GGameDataRegistry.get_all_tower_blueprints()
	var archer: TowerBlueprintData = blueprints[&"archer"]
	_cluster()._on_tower_button_pressed(&"archer")

	_cluster()._on_tower_placement_preview_updated(Vector2i(0, 0), archer.foundation.footprint, true)

	@warning_ignore("unsafe_property_access")
	var icon: TextureRect = _cluster().get("_placement_preview_icon")
	assert_bool(icon.visible).is_true()
	assert_object(icon.texture).is_equal((_tower_views()[&"archer"] as TowerViewport3D).get_texture())


## Regression guard: TextureRect's default expand_mode (EXPAND_KEEP_SIZE)
## makes its minimum size equal the texture's native resolution, and
## Control.set_size() clamps up to minimum size -- found live via Godot MCP
## as a 36x64 target preview silently rendering at the tower art's full
## ~858x1003 native resolution, covering most of the grid. The 3D ghost is
## sized from its camera frame (the tower at map scale), not the render size.
func test_preview_icon_is_sized_to_map_scale_not_render_resolution() -> void:
	var blueprints: Dictionary = GGameDataRegistry.get_all_tower_blueprints()
	var archer: TowerBlueprintData = blueprints[&"archer"]
	_cluster()._on_tower_button_pressed(&"archer")

	_cluster()._on_tower_placement_preview_updated(Vector2i(0, 0), archer.foundation.footprint, true)

	@warning_ignore("unsafe_property_access")
	var icon: TextureRect = _cluster().get("_placement_preview_icon")
	var view: TowerViewport3D = _tower_views()[&"archer"]
	var map_scale: float = _cluster()._screen_cell_size().y / PlanningCluster.CELL_SIZE_PX
	assert_float(icon.size.y).is_equal_approx(view.frame_height_px() * map_scale, 0.01)
	assert_float(icon.size.y).is_less(float(PlanningCluster.TOWER_ICON_RENDER_PX))


func test_sentinel_cell_hides_the_preview_icon_too() -> void:
	_cluster()._on_tower_button_pressed(&"archer")
	_cluster()._on_tower_placement_preview_updated(Vector2i(0, 0), Vector2i(1, 1), true)

	_cluster()._on_tower_placement_preview_updated(Vector2i(-1, -1), Vector2i.ZERO, false)

	@warning_ignore("unsafe_property_access")
	var icon: TextureRect = _cluster().get("_placement_preview_icon")
	assert_bool(icon.visible).is_false()


# ---------------------------------------------------------------------------
# Terrain (ADR-0044): the cursor rides the hill, the panel shows the hill price
# ---------------------------------------------------------------------------

func test_preview_cursor_lifted_by_screen_lift() -> void:
	var c := Vector2(160.0, 160.0)
	_cluster()._on_tower_placement_preview_updated(Vector2i(2, 2), Vector2i(1, 1), true, c, [], 0.0)
	@warning_ignore("unsafe_property_access")
	var cursor: ColorRect = _cluster().get("_placement_cursor")
	var flat_y: float = cursor.position.y
	_cluster()._on_tower_placement_preview_updated(Vector2i(2, 2), Vector2i(1, 1), true, c, [], 20.0)
	assert_float(cursor.position.y).is_less(flat_y)


func test_preview_shows_hill_price_in_stats() -> void:
	var blueprints: Dictionary = GGameDataRegistry.get_all_tower_blueprints()
	var archer: TowerBlueprintData = blueprints[&"archer"]
	_cluster()._on_tower_button_pressed(&"archer")
	var hill_cost: int = TowerSystem.terrain_cost(archer.placement_cost, 1)
	_cluster()._on_tower_placement_preview_updated(Vector2i(2, 2), Vector2i(1, 1), true, Vector2(160, 160), [], 20.0, hill_cost)
	@warning_ignore("unsafe_property_access")
	var label: Label = _cluster().get("_tower_stats_label")
	assert_str(label.text).contains("Cost: %dg (hill" % hill_cost)
	_cluster()._on_tower_placement_preview_updated(Vector2i(0, 0), Vector2i(1, 1), true, Vector2(32, 32), [], 0.0, archer.placement_cost)
	assert_str(label.text).contains("Cost: %dg   " % archer.placement_cost)
