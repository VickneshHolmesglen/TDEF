extends GdUnitTestSuite

## End-to-end wiring for set capstones: Hero.tscn owns the controller, and a
## real equip -> rebuild -> proc -> unequip cycle works
## (equipment-set-effects spec §3.4, AC-8/AC-12).

const HERO_SCENE: String = "res://src/core/hero/Hero.tscn"
const GAUNTLETS: String = "res://assets/data/items/lurker_claw_gauntlets.tres"
const BLADE: String = "res://assets/data/items/lurker_fang_blade.tres"

class _StubMonsterManager extends Node:
	var calls: Array[Array] = []

	func apply_dot(target_id: int, effect_type: String, value: float, duration: float) -> void:
		calls.append([target_id, effect_type, value, duration])


var _hero: Hero
var _ctl: SetEffectController
var _stub: _StubMonsterManager


func before_test() -> void:
	GInventory.reset_to_defaults()
	_hero = (load(HERO_SCENE) as PackedScene).instantiate() as Hero
	add_child(_hero)
	_ctl = _hero.get_node_or_null("SetEffectController") as SetEffectController
	_stub = _StubMonsterManager.new()


func after_test() -> void:
	GInventory.reset_to_defaults()
	if _stub != null and is_instance_valid(_stub):
		_stub.free()
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null
	_ctl = null


func test_hero_scene_owns_a_set_effect_controller() -> void:
	assert_object(_ctl).is_not_null()


func test_equipping_a_set_activates_its_capstone_and_unequipping_removes_it() -> void:
	assert_bool(GInventory.equip_item("gloves", load(GAUNTLETS))).is_true()
	assert_bool(_ctl._active.is_empty()).is_true()
	assert_bool(GInventory.equip_item("main_hand", load(BLADE))).is_true()
	assert_bool(_ctl._active.has(&"set_lurker:2")).is_true()
	GInventory.unequip_item("gloves")
	assert_bool(_ctl._active.is_empty()).is_true()
	GInventory.unequip_item("main_hand")


func test_a_crit_procs_the_equipped_capstone() -> void:
	_ctl.monster_manager = _stub
	GInventory.equip_item("gloves", load(GAUNTLETS))
	GInventory.equip_item("main_hand", load(BLADE))
	var payload := HeroAutoAttackEvent.new()
	payload.is_crit = true
	payload.target_id = 3
	_ctl._on_hero_auto_attacked(payload)
	assert_int(_stub.calls.size()).is_equal(1)
	assert_str(_stub.calls[0][1]).is_equal("poison")
	GInventory.unequip_item("gloves")
	GInventory.unequip_item("main_hand")
