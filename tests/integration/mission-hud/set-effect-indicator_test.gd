## Integration tests for the Mission HUD set-effect indicator (2026-10-06): a
## list under the Hero HP line that mirrors SetEffectController.get_hud_entries().
extends GdUnitTestSuite

var _hud: MissionHud
var _hero: Hero
var _ctl: SetEffectController


func before_test() -> void:
	GInventory.reset_to_defaults()
	_hud = MissionHudTestHelper.build_hud()
	add_child(_hud)
	_hero = Hero.new()
	add_child(_hero)
	_hero._base_stats[&"max_hp"] = 600.0
	_hero._max_hp = 600.0
	_hero._current_hp = 600.0
	_hero._phase = Hero.HeroPhase.COMBAT
	_ctl = SetEffectController.new()
	_hero.add_child(_ctl)


func after_test() -> void:
	GInventory.reset_to_defaults()
	if _hero != null and is_instance_valid(_hero):
		_hero.free()
	if _hud != null and is_instance_valid(_hud):
		_hud.free()
	_hero = null
	_hud = null
	_ctl = null


func _list() -> VBoxContainer:
	return _hud.find_child("SetEffectList", true, false) as VBoxContainer


func test_effect_list_sits_directly_under_the_hero_hp_line() -> void:
	var list: VBoxContainer = _list()
	var hp: Label = _hud._hero_hp_label

	assert_object(list).is_not_null()
	assert_object(list.get_parent()).is_same(hp.get_parent())
	# 2026-10-11 layout pass: the Hero HP bar sits between the line and the list.
	assert_object(hp.get_parent().get_child(hp.get_index() + 1)).is_same(_hud._hero_hp_bar)
	assert_int(list.get_index()).is_equal(hp.get_index() + 2)
	assert_bool(list.visible).is_false()


func test_effect_list_shows_an_active_shield_and_hides_when_it_is_gone() -> void:
	var shield: Dictionary = {&"key": &"set_brute:4", &"set_id": &"set_brute", &"threshold": 4,
		&"name": "Iron Hide", &"type": &"on_hurt_shield",
		&"params": {&"shield_fraction": 0.08, &"duration": 4.0, &"cooldown": 8.0}}
	var effects: Array[Dictionary] = [shield]
	_ctl.apply_effects(effects)
	_ctl._on_hero_damage_taken(40, 0)
	await await_idle_frame()

	_hud._refresh_effect_list()
	assert_bool(_list().visible).is_true()
	assert_int(_list().get_child_count()).is_equal(1)
	assert_str((_list().get_child(0) as Label).text).is_equal("Iron Hide: shield 48 (4s)")

	_hero.clear_all_shields()
	_hud._refresh_effect_list()
	assert_bool(_list().visible).is_false()
