## Integration tests for Story 009 (TR-hud-000, ADR-0031, ADR-0011): Ultimate
## Button (Core Rules Group 7, Rules 19-20). Reuses Story 008's InputModeTracker.
##
## Per user instruction, this story's usual full verification pass (targeted
## test run, live-MCP verification, full regression) was explicitly SKIPPED
## to move quickly to Stories 009/010 — this file is written but NOT executed
## this session. Run it (and the full regression) before trusting this story.
extends GdUnitTestSuite

var _hud: MissionHud


func before_test() -> void:
	_hud = MissionHudTestHelper.build_hud()
	add_child(_hud)


func after_test() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null


# ---------------------------------------------------------------------------
# AC-45: exists in all phases (no phase-gated existence, unlike Ready/Sell)
# ---------------------------------------------------------------------------

func test_ultimate_button_exists_regardless_of_phase() -> void:
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)
	_hud._on_mission_phase_changed("SCOUT", "PRE_WAVE", 0.0)
	_hud._on_mission_phase_changed("PRE_WAVE", "WAVE_ACTIVE", 0.0)

	assert_object(_hud._ultimate_button).is_not_null()
	assert_bool(is_instance_valid(_hud._ultimate_button)).is_true()


# ---------------------------------------------------------------------------
# AC-46/AC-47: cooldown gating, full input block while on cooldown
# ---------------------------------------------------------------------------

func test_on_cooldown_disables_the_button() -> void:
	GEventBus.hero_skill_cooldown_updated.emit(Hero.ULTIMATE_SLOT_INDEX, 3.0, 5.0)

	assert_bool(_hud._ultimate_button.disabled).is_true()


func test_cooldown_zero_enables_the_button() -> void:
	GEventBus.hero_skill_cooldown_updated.emit(Hero.ULTIMATE_SLOT_INDEX, 3.0, 5.0)
	GEventBus.hero_skill_cooldown_updated.emit(Hero.ULTIMATE_SLOT_INDEX, 0.0, 5.0)

	assert_bool(_hud._ultimate_button.disabled).is_false()


# ---------------------------------------------------------------------------
# AC-48: synchronous emission on press
# ---------------------------------------------------------------------------

func test_press_emits_hero_ultimate_activated_synchronously() -> void:
	var received := {"count": 0}
	var handler := func() -> void: received["count"] += 1
	GEventBus.hero_ultimate_activated.connect(handler)

	_hud._ultimate_button.pressed.emit()

	assert_int(received["count"]).is_equal(1)
	GEventBus.hero_ultimate_activated.disconnect(handler)


# ---------------------------------------------------------------------------
# AC-49: no local prediction — pressing does not itself change disabled state
# ---------------------------------------------------------------------------

func test_press_does_not_locally_predict_cooldown_state() -> void:
	GEventBus.hero_skill_cooldown_updated.emit(Hero.ULTIMATE_SLOT_INDEX, 0.0, 5.0)

	_hud._ultimate_button.pressed.emit()

	assert_bool(_hud._ultimate_button.disabled).is_false()  # unchanged by the press itself


# ---------------------------------------------------------------------------
# AC-50: other skill slots are discarded, no effect
# ---------------------------------------------------------------------------

func test_non_ultimate_skill_slot_updates_are_discarded() -> void:
	GEventBus.hero_skill_cooldown_updated.emit(Hero.ULTIMATE_SLOT_INDEX, 0.0, 5.0)

	GEventBus.hero_skill_cooldown_updated.emit(1, 5.0, 5.0)  # unrelated slot, should have no effect

	assert_bool(_hud._ultimate_button.disabled).is_false()
