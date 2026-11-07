extends GdUnitTestSuite

## The HUD shows a "Wading" line under the Hero HP while the hero's water slow
## is active (spec 2026-11-07-3d-terrain §4.3).

var _hud: Node


func before_test() -> void:
	_hud = MissionHudTestHelper.build_hud()
	add_child(_hud)
	_hud._on_mission_phase_changed("IDLE", "SCOUT", 0.0)


func after_test() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null


func test_water_debuff_label_follows_signal() -> void:
	var label: Label = _hud._water_debuff_label
	assert_object(label).is_not_null()
	assert_bool(label.visible).is_false()
	GEventBus.hero_water_debuff_changed.emit(true)
	assert_bool(label.visible).is_true()
	GEventBus.hero_water_debuff_changed.emit(false)
	assert_bool(label.visible).is_false()
