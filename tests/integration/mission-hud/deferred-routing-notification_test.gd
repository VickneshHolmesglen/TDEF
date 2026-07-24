## Integration tests for Story 005 (TR-hud-003, ADR-0031): Deferred Routing
## Notification Banner (Core Rules Group 5, Rules 13-15; Confirmed Signal
## Contract PC-3), plus hero_class_unlocked reusing the same mechanism.
##
## MissionHud IS added to the test's own scene tree (add_child()), matching
## this epic's established convention — required for the Timer node's
## start()/stop()/timeout wiring to function.
extends GdUnitTestSuite

var _hud: MissionHud


func before_test() -> void:
	_hud = MissionHudTestHelper.build_hud()
	add_child(_hud)
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)


func after_test() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null


# ---------------------------------------------------------------------------
# AC-23: banner display during WAVE_ACTIVE
# ---------------------------------------------------------------------------

func test_tower_destroyed_during_wave_active_shows_banner() -> void:
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)

	_hud._on_tower_destroyed(1, Vector2i(0, 0), "weapon", [], "")

	assert_bool(_hud._banner.visible).is_true()
	assert_str(_hud._banner_label.text).is_equal("Path update queued for next intermission.")
	assert_bool(_hud._banner_timer.is_stopped()).is_false()


func test_tower_destroyed_outside_wave_active_does_not_show_banner() -> void:
	_hud._on_tower_destroyed(1, Vector2i(0, 0), "weapon", [], "")  # still SCOUT

	assert_bool(_hud._banner.visible).is_false()


# ---------------------------------------------------------------------------
# AC-24: no stacking, second trigger resets the timer
# ---------------------------------------------------------------------------

func test_second_tower_destroyed_while_showing_resets_not_stacks() -> void:
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)
	_hud._on_tower_destroyed(1, Vector2i(0, 0), "weapon", [], "")
	var first_time_left: float = _hud._banner_timer.time_left

	_hud._on_tower_destroyed(2, Vector2i(1, 1), "armor", [], "")

	assert_bool(_hud._banner.visible).is_true()  # still just one banner
	assert_float(_hud._banner_timer.time_left).is_greater_equal(first_time_left)  # timer reset to full


# ---------------------------------------------------------------------------
# AC-25: force-dismissed on INTERMISSION entry
# ---------------------------------------------------------------------------

func test_intermission_entry_force_dismisses_visible_banner() -> void:
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)
	_hud._on_tower_destroyed(1, Vector2i(0, 0), "weapon", [], "")
	assert_bool(_hud._banner.visible).is_true()

	_hud._on_mission_phase_changed("WAVE_ACTIVE", "INTERMISSION", 0.0)

	assert_bool(_hud._banner.visible).is_false()
	assert_bool(_hud._banner_timer.is_stopped()).is_true()


# ---------------------------------------------------------------------------
# AC-26: hero_class_unlocked reuses the same mechanism
# ---------------------------------------------------------------------------

func test_hero_class_unlocked_shows_banner_via_same_mechanism() -> void:
	_hud._on_hero_class_unlocked(&"berserker", false)

	assert_bool(_hud._banner.visible).is_true()
	assert_str(_hud._banner_label.text).is_equal("Hero class unlocked: berserker")


func test_hero_class_unlocked_also_resets_not_stacks() -> void:
	_hud._on_hero_class_unlocked(&"berserker", false)
	_hud._on_hero_class_unlocked(&"ranger", true)

	assert_str(_hud._banner_label.text).is_equal("Hero class unlocked: ranger")  # latest wins, single banner


# ---------------------------------------------------------------------------
# AC-27: accepted non-issue — phase already flipped before tower_destroyed
# is processed
# ---------------------------------------------------------------------------

func test_tower_destroyed_processed_after_intermission_flip_shows_no_banner() -> void:
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)
	_hud._on_mission_phase_changed("WAVE_ACTIVE", "INTERMISSION", 0.0)  # phase flip already processed

	_hud._on_tower_destroyed(1, Vector2i(0, 0), "weapon", [], "")

	assert_bool(_hud._banner.visible).is_false()  # accepted deliberate non-issue, not a bug
