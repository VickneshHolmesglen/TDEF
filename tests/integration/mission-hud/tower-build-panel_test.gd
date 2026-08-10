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
	# TD-test-004: direct call, not a mission_launched broadcast (see
	# tests/unit/tower/tower_placement_test.gd's identical rationale) —
	# resets GMissionEconomy's real balance to a known 0 baseline.
	GMissionEconomy._on_mission_launched("test_mission", PackedStringArray(), 1)
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
	GMissionEconomy._on_mission_launched("test_mission", PackedStringArray(), 1)


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
# Icons (2026-08-11) — reuses tower_instance.gd's real per-archetype art
# (assets/art/towers/), which already existed but was never wired into this
# list; it originally shipped text-only on the incorrect assumption that no
# tower art existed in the project at all.
# ---------------------------------------------------------------------------

func test_each_entry_shows_its_archetype_icon() -> void:
	@warning_ignore("unsafe_property_access")
	var build_buttons: Dictionary = _cluster().get("_build_buttons")
	var archer: Button = build_buttons[&"archer"]
	var frostbolt: Button = build_buttons[&"frostbolt_turret"]
	assert_object(archer.icon).is_not_null()
	assert_str(archer.icon.resource_path).contains("tower_physical_base")
	assert_object(frostbolt.icon).is_not_null()
	assert_str(frostbolt.icon.resource_path).contains("tower_elem_ice")


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
