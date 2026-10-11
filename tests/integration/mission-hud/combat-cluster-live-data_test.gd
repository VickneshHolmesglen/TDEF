## Integration tests for Story 011 (TR-hud-000, ADR-0031): Combat Cluster Live
## Data Widgets (Core Rules Rule 4 visual half, PC-4, Interactions table).
##
## MissionHud IS added to the test's own scene tree (add_child()), matching
## this epic's established convention (mission_hud_test_helper.gd).
extends GdUnitTestSuite

const SPAWN_CELL := Vector2i(0, 0)


func _make_config() -> GridConfig:
	var cfg := GridConfig.new()
	cfg.cols = 1
	cfg.rows = 1
	cfg.cell_size = 64.0
	cfg.cells = {SPAWN_CELL: Grid.CellType.SPAWN}
	return cfg


var _hud: MissionHud


func before_test() -> void:
	GGrid.initialize(_make_config())
	# TD-test-004: GMissionEconomy is a real, persistent Autoload -- reset to
	# a known 0 baseline the same way mission_economy_test.gd does, since
	# _on_resources_changed() now reads its real get_gold_balance() directly
	# (2026-08-10 fix) instead of echoing the signal's own raw payload.
	GMissionEconomy._on_grid_initialized(0, 0, 0.0)
	_hud = MissionHudTestHelper.build_hud()
	add_child(_hud)


func after_test() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null
	GMissionEconomy._on_grid_initialized(0, 0, 0.0)


func _boss_spawn(entity_id: int, hp_max: float = 500.0) -> MonsterSpawnedEvent:
	var payload := MonsterSpawnedEvent.new()
	payload.entity_id = entity_id
	payload.monster_id = &"goblin_warlord_boss"
	payload.hp_max = hp_max
	return payload


# ---------------------------------------------------------------------------
# AC-57: Hero HP bar
# ---------------------------------------------------------------------------

func test_hero_health_changed_updates_label() -> void:
	GEventBus.hero_health_changed.emit(42.0, 100.0)

	assert_str(_hud._hero_hp_label.text).is_equal("Hero HP: 42/100")


# ---------------------------------------------------------------------------
# AC-58: skill cooldown fills, slots 0-3, discard slot 4
# ---------------------------------------------------------------------------

## Player-reported 2026-08-16: the text-Label cooldown readout ("Skill N:
## Ready"/"Skill N: 3.2s") was replaced with Pattern 12's icon-tile states
## (design/ux/interaction-patterns.md) -- dim opacity + a top-to-bottom dark
## fill (anchor_bottom == cooldown_remaining / cooldown_max) + a numeric
## countdown Label while on cooldown, full opacity/no fill/no countdown when
## ready. These 3 tests were updated to assert the new state surface instead
## of Label.text.
func test_skill_slot_cooldown_updates_its_own_fill_and_countdown() -> void:
	GEventBus.hero_skill_cooldown_updated.emit(1, 2.5, 5.0)

	assert_bool(_hud._skill_slot_fills[1].visible).is_true()
	assert_float(_hud._skill_slot_fills[1].anchor_bottom).is_equal_approx(0.5, 0.001)
	assert_str(_hud._skill_slot_countdowns[1].text).is_equal("3s")
	assert_float(_hud._skill_slot_icons[1].modulate.a).is_equal_approx(0.5, 0.001)


func test_skill_slot_ready_at_zero_cooldown() -> void:
	GEventBus.hero_skill_cooldown_updated.emit(1, 0.0, 5.0)

	assert_bool(_hud._skill_slot_fills[1].visible).is_false()
	assert_str(_hud._skill_slot_countdowns[1].text).is_equal("")
	assert_float(_hud._skill_slot_icons[1].modulate.a).is_equal_approx(1.0, 0.001)


func test_ultimate_slot_does_not_touch_skill_cooldown_slots() -> void:
	var original_text: String = _hud._skill_slot_countdowns[3].text
	var original_fill_visible: bool = _hud._skill_slot_fills[3].visible

	GEventBus.hero_skill_cooldown_updated.emit(Hero.ULTIMATE_SLOT_INDEX, 3.0, 5.0)

	assert_str(_hud._skill_slot_countdowns[3].text).is_equal(original_text)
	assert_bool(_hud._skill_slot_fills[3].visible).is_equal(original_fill_visible)


# ---------------------------------------------------------------------------
# AC-59: breach counter
# ---------------------------------------------------------------------------

func test_breach_updates_counter_label() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)

	_hud._on_monster_breached(1, &"goblin_runner", 0)

	assert_str(_hud._breach_counter_label.text).is_equal("Breaches: 1")


# ---------------------------------------------------------------------------
# AC-60/AC-66: boss bar mount/update/dismount, stray discard
# ---------------------------------------------------------------------------

func test_boss_spawn_mounts_the_boss_bar() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)

	_hud._on_monster_spawned(_boss_spawn(1, 500.0))

	assert_bool(_hud._boss_bar_label.visible).is_true()
	assert_str(_hud._boss_bar_label.text).is_equal("BOSS Goblin Warlord: 500/500")


func test_boss_hp_changed_updates_the_bar() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	_hud._on_monster_spawned(_boss_spawn(1, 500.0))

	GEventBus.boss_hp_changed.emit(1, 300.0, 500.0)

	assert_str(_hud._boss_bar_label.text).is_equal("BOSS Goblin Warlord: 300/500")


func test_boss_died_dismounts_the_bar() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	_hud._on_monster_spawned(_boss_spawn(1, 500.0))

	_hud._on_boss_died(1, &"goblin_warlord_boss", 1, "hero_attack")

	assert_bool(_hud._boss_bar_label.visible).is_false()


func test_stray_boss_hp_changed_with_empty_state_is_discarded() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)

	GEventBus.boss_hp_changed.emit(99, 10.0, 500.0)  # no boss ever spawned

	assert_bool(_hud._boss_bar_label.visible).is_false()


# ---------------------------------------------------------------------------
# AC-61: tower HP bars, immediate per-tower removal
# ---------------------------------------------------------------------------

func test_tower_damaged_creates_and_updates_a_bar() -> void:
	_hud._on_tower_damaged(5, 10.0, 90.0, 100.0)

	assert_int(_hud._tower_hp_bars_host.get_child_count()).is_equal(1)
	assert_str(_hud._tower_hp_bar_labels[5].text).is_equal("Tower 5: 90/100")


func test_tower_destroyed_removes_its_bar_immediately() -> void:
	_hud._on_tower_damaged(5, 10.0, 90.0, 100.0)

	_hud._on_tower_destroyed(5, Vector2i(1, 1), "cannon", [], "")

	assert_int(_hud._tower_hp_bars_host.get_child_count()).is_equal(0)
	assert_bool(_hud._active_tower_hp_bars.has(5)).is_false()


func test_other_towers_bars_survive_a_different_towers_destruction() -> void:
	_hud._on_tower_damaged(5, 10.0, 90.0, 100.0)
	_hud._on_tower_damaged(6, 10.0, 80.0, 100.0)

	_hud._on_tower_destroyed(5, Vector2i(1, 1), "cannon", [], "")

	assert_int(_hud._tower_hp_bars_host.get_child_count()).is_equal(1)
	assert_bool(_hud._tower_hp_bar_labels.has(6)).is_true()


# ---------------------------------------------------------------------------
# AC-62: floating damage numbers
# ---------------------------------------------------------------------------

func test_monster_damage_taken_spawns_a_floating_number() -> void:
	GEventBus.monster_damage_number_requested.emit(1, Vector2(100.0, 200.0), 42, false)

	assert_int(_hud._damage_number_host.get_child_count()).is_equal(1)
	assert_str((_hud._damage_number_host.get_child(0) as Label).text).is_equal("42")


func test_crit_damage_number_gets_the_crit_marker() -> void:
	GEventBus.monster_damage_number_requested.emit(1, Vector2(100.0, 200.0), 99, true)

	assert_str((_hud._damage_number_host.get_child(0) as Label).text).is_equal("99!")


## Player-reported 2026-08-16: numbers were rendering near the boss bar
## instead of on the hit monster — regression test for the fix
## (monster_damage_number_requested carries a real world_position, converted
## to screen space via the viewport's canvas transform).
func test_damage_number_spawns_at_the_monster_world_position() -> void:
	var world_position := Vector2(320.0, 150.0)
	GEventBus.monster_damage_number_requested.emit(1, world_position, 42, false)

	var expected_screen_pos: Vector2 = _hud.get_viewport().get_canvas_transform() * world_position
	var number := _hud._damage_number_host.get_child(0) as Label
	# x carries randf_range(-8.0, 8.0) jitter (see _on_monster_damage_number_
	# requested()'s own comment) -- assert it lands within that jitter band
	# rather than an exact value.
	assert_float(absf(number.position.x - expected_screen_pos.x)).is_less_equal(8.0)
	assert_float(number.position.y).is_equal_approx(expected_screen_pos.y - 16.0, 0.01)


# ---------------------------------------------------------------------------
# AC-63: PC-4 chrome
# ---------------------------------------------------------------------------

func test_mission_phase_changed_updates_phase_label() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)

	assert_str(_hud._phase_label.text).is_equal(tr("HUD_PHASE") % tr("HUD_PHASE_NAME_SCOUT"))


func test_wave_started_updates_wave_label() -> void:
	GEventBus.wave_started.emit(3, 10, 1.5)

	assert_str(_hud._wave_label.text).is_equal("Wave: 3/10")


func test_phase_timer_tick_updates_timer_label() -> void:
	GEventBus.phase_timer_tick.emit("PRE_WAVE", 4.2)

	assert_str(_hud._phase_timer_label.text).is_equal(tr("HUD_PHASE_TIMER") % 4.2)


# ---------------------------------------------------------------------------
# AC-64: gold + materials
# ---------------------------------------------------------------------------

## 2026-08-06: text is now just the number (design/quick-specs/gold-
## currency-icon-2026-08-06.md) -- the GoldIcon sibling carries the "this is
## gold" meaning "Gold: " used to.
##
## Regression guard (2026-08-10, player-reported: "the calculation for
## currency seems wrong" after buying a tower): resources_changed's payload
## is a signed DELTA (every real emitter sends one -- see tower_system.gd's
## placement cost/sell refund, resource_economy.gd's Scout grant,
## defense_building.gd's tech/structure costs), never an absolute balance.
## The label previously displayed that raw delta directly, so a second gold
## event after the first (e.g. a tower purchase after the mission-start
## grant) showed the wrong number outright -- a single emit from a 0
## baseline couldn't catch this, since the delta and the new total were
## coincidentally identical. This test now emits two deltas and asserts the
## label reflects the true running balance GMissionEconomy accumulates, not
## either raw payload.
func test_resources_changed_shows_the_real_accumulated_balance_not_the_raw_delta() -> void:
	GEventBus.resources_changed.emit(50, &"mission_start_grant")
	assert_str(_hud._gold_label.text).is_equal("50")

	GEventBus.resources_changed.emit(-10, &"tower_placed")

	assert_str(_hud._gold_label.text).is_equal("40")


## Player-reported 2026-08-16: the "wood: 8" text tally was replaced with
## "[icon] xN" chips (icon-with-text-fallback, see _materials_row's own doc
## comment) -- "wood" has no ItemDefinitionResource.icon authored yet, so
## it still falls back to plain text, just per-chip instead of one joined
## string.
func test_materials_earned_accumulates_a_running_tally() -> void:
	GEventBus.materials_earned.emit("wood", 5, "monster_drop")
	GEventBus.materials_earned.emit("wood", 3, "monster_drop")

	assert_int(_hud._materials_row.get_child_count()).is_equal(1)
	var chip: HBoxContainer = _hud._materials_row.get_child(0)
	var quantity_label: Label = chip.get_child(chip.get_child_count() - 1)
	assert_str(quantity_label.text).is_equal("wood x8")


## Regression (2026-10-04 smoke check): a pickup the inventory rejected as full
## must not stay counted as earned in the mission tally.
func test_mission_hud_rejected_pickup_is_removed_from_materials_tally() -> void:
	GEventBus.materials_earned.emit("wood", 5, "monster_drop")
	GEventBus.item_pickup_rejected.emit("wood", "material", 2, "inventory_full")

	assert_int(_hud._materials_tally["wood"]).is_equal(3)


func test_mission_hud_fully_rejected_material_drops_its_chip() -> void:
	GEventBus.materials_earned.emit("wood", 4, "monster_drop")
	GEventBus.item_pickup_rejected.emit("wood", "material", 4, "inventory_full")

	assert_bool(_hud._materials_tally.has("wood")).is_false()
	assert_int(_hud._materials_row.get_child_count()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-65: Inventory toasts
# ---------------------------------------------------------------------------

func test_item_added_shows_a_toast() -> void:
	GEventBus.item_added.emit("wood", "material", 5)

	assert_int(_hud._toast_host.get_child_count()).is_equal(1)
	assert_str((_hud._toast_host.get_child(0) as Label).text).is_equal("+5 Wood")


func test_item_pickup_rejected_shows_a_toast_with_reason() -> void:
	GEventBus.item_pickup_rejected.emit("wood", "material", 5, "inventory_full")

	assert_str((_hud._toast_host.get_child(0) as Label).text).is_equal("Could not pick up 5x Wood (inventory full)")


func test_item_removed_shows_a_toast() -> void:
	GEventBus.item_removed.emit("wood", "material", 3)

	assert_str((_hud._toast_host.get_child(0) as Label).text).is_equal("-3 Wood")


# ---------------------------------------------------------------------------
# Player-reported 2026-08-16: ToastHost is anchored with anchor_top ==
# anchor_bottom, so Godot grows/repositions it to fit however many toasts are
# alive -- a busy wave with several drops made the whole log visibly climb up
# the screen. Fix: MissionHud.MAX_VISIBLE_TOASTS caps live toasts, evicting
# the oldest immediately so the box never needs to grow past the fixed rect
# MissionScene.tscn/the_gap.tscn now declare for ToastHost.
# ---------------------------------------------------------------------------

func test_toast_count_never_exceeds_max_visible() -> void:
	for i in range(MissionHud.MAX_VISIBLE_TOASTS + 3):
		GEventBus.item_added.emit("wood", "material", i + 1)

	assert_int(_hud._toast_host.get_child_count()).is_equal(MissionHud.MAX_VISIBLE_TOASTS)


func test_toast_overflow_evicts_oldest_first() -> void:
	for i in range(MissionHud.MAX_VISIBLE_TOASTS + 2):
		GEventBus.item_added.emit("wood", "material", i + 1)

	# The 2 oldest (+1 wood, +2 wood) were evicted -- the surviving toasts are
	# the most recent MAX_VISIBLE_TOASTS, oldest-to-newest top-to-bottom.
	var first_surviving: int = 3
	for i in range(MissionHud.MAX_VISIBLE_TOASTS):
		var expected_text: String = "+%d Wood" % (first_surviving + i)
		assert_str((_hud._toast_host.get_child(i) as Label).text).is_equal(expected_text)


# ---------------------------------------------------------------------------
# Epic 06 Story 013 (tower-mastery.md): skill_unlocked HUD corner callout —
# the half of that story blocked until Mission HUD existed in code.
# ---------------------------------------------------------------------------

## RESOLVED 2026-08-13: SkillDefinitionResource gained display_name (real
## content: phys_cleave -> "Cleave") — the toast now shows the real name,
## closing the gap this test's own comment history previously documented.
func test_skill_unlocked_shows_a_toast() -> void:
	GEventBus.skill_unlocked.emit("phys_cleave", 7)

	assert_str((_hud._toast_host.get_child(0) as Label).text).is_equal("Skill Learned: Cleave")


func test_skill_unlocked_falls_back_to_raw_id_for_unrecognized_skill() -> void:
	GEventBus.skill_unlocked.emit("not_a_real_skill", 7)

	assert_str((_hud._toast_host.get_child(0) as Label).text).is_equal("Skill Learned: not_a_real_skill")


func test_skill_unlocked_suppressed_after_terminal() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)
	_hud._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 0.0)

	GEventBus.skill_unlocked.emit("phys_cleave", 7)

	assert_int(_hud._toast_host.get_child_count()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-63 (PC-4, countdown-warning half)
# ---------------------------------------------------------------------------

func test_wave_countdown_warning_updates_timer_label() -> void:
	GEventBus.wave_countdown_warning.emit(5)

	assert_str(_hud._phase_timer_label.text).is_equal("Wave incoming: 5s")


# ---------------------------------------------------------------------------
# Code review fix: _on_hero_health_changed/_on_boss_hp_changed/
# _on_materials_earned/_on_resources_changed were originally missing the
# _terminal guard every other Rule-4 mutation handler has.
# ---------------------------------------------------------------------------

func test_terminal_latch_suppresses_hero_boss_materials_gold_handlers() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	_hud._on_monster_spawned(_boss_spawn(1, 500.0))
	var hero_hp_before: String = _hud._hero_hp_label.text
	var boss_bar_before: String = _hud._boss_bar_label.text
	var gold_before: String = _hud._gold_label.text
	var materials_before: int = _hud._materials_row.get_child_count()

	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)
	_hud._on_mission_phase_changed("WAVE_ACTIVE", "DEFEAT", 0.0)

	GEventBus.hero_health_changed.emit(1.0, 100.0)
	GEventBus.boss_hp_changed.emit(1, 1.0, 500.0)
	GEventBus.resources_changed.emit(9999, &"monster_drop")
	GEventBus.materials_earned.emit("wood", 50, "monster_drop")

	assert_str(_hud._hero_hp_label.text).is_equal(hero_hp_before)
	assert_str(_hud._boss_bar_label.text).is_equal(boss_bar_before)
	assert_str(_hud._gold_label.text).is_equal(gold_before)
	assert_int(_hud._materials_row.get_child_count()).is_equal(materials_before)
