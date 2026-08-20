## Regression test for the "still standing at MISSION_COMPLETE" assumption
## behind Formula 6 (Tower Components mission-end surplus grant, 2026-08-17):
## a tower placed then removed/destroyed before mission end must contribute
## ZERO surplus — it already cost its placement gold and its 4 source
## components; granting surplus for it too would double-reward.
extends GdUnitTestSuite

var _re: ResourceEconomy
var _ts: TowerSystem
var _spy: EventBusSpy


func before_test() -> void:
	_re = ResourceEconomy.new()
	_ts = TowerSystem.new()
	add_child(_re)
	add_child(_ts)
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.materials_earned)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _re != null and is_instance_valid(_re):
		remove_child(_re)
		_re.free()
	_re = null
	if _ts != null and is_instance_valid(_ts):
		remove_child(_ts)
		_ts.free()
	_ts = null


func _make_state(tier: int, archetype: String) -> TowerMissionState:
	var state := TowerMissionState.new()
	state.foundation = FoundationComponent.new()
	state.foundation.tier = tier
	state.foundation.archetype = archetype
	state.weapon = WeaponComponent.new()
	state.focus = FocusComponent.new()
	state.power = PowerComponent.new()
	return state


func test_removed_tower_contributes_zero_surplus() -> void:
	_ts.placed_towers[1] = _make_state(1, "physical")
	_ts.placed_towers[2] = _make_state(1, "physical")
	_ts.placed_towers.erase(1)  # simulates a sold/destroyed tower before mission end

	GEventBus.mission_phase_changed.emit("WAVE_ACTIVE", "MISSION_COMPLETE", 0.0)

	var emitted: Dictionary[String, int] = {}
	for args: Array in (_spy.emissions["materials_earned"] as Array):
		emitted[args[0] as String] = emitted.get(args[0] as String, 0) + (args[1] as int)
	# Only the ONE surviving tower's contribution — not both.
	assert_int(emitted.get("foundation_surplus", 0)).is_equal(1)


func test_all_towers_destroyed_grants_nothing() -> void:
	_ts.placed_towers[1] = _make_state(1, "physical")
	_ts.placed_towers.erase(1)

	GEventBus.mission_phase_changed.emit("WAVE_ACTIVE", "MISSION_COMPLETE", 0.0)

	assert_int(_spy.count("materials_earned")).is_equal(0)
