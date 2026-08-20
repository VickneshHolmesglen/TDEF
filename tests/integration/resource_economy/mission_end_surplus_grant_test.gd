## Integration tests for Formula 6 — Mission-End Building Material Surplus
## Grant (design/gdd/resource-economy.md Rule 11), Tower Components,
## player-requested 2026-08-17.
##
## Follows wave_completion_gold_grant_test.gd's exact established convention:
## ResourceEconomy tests use add_child()-then-real-signal dispatch, observed
## via tests/helpers/event_bus_spy.gd's EventBusSpy. TowerSystem is a real
## instance (not a stub) added to the tree so its GROUP_NAME registration
## fires in _ready() — placed_towers is populated directly with synthetic
## TowerMissionState entries (bypassing the full 4-gate place_tower() flow,
## which this test has no need to exercise).
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


func test_one_tier1_physical_tower_grants_1_of_each_surplus_plus_archetype_bonus() -> void:
	_ts.placed_towers[1] = _make_state(1, "physical")

	GEventBus.mission_phase_changed.emit("WAVE_ACTIVE", "MISSION_COMPLETE", 0.0)

	assert_int(_spy.count("materials_earned")).is_equal(5)  # 4 surplus + 1 archetype bonus
	var emitted: Dictionary[String, int] = {}
	for args: Array in (_spy.emissions["materials_earned"] as Array):
		var material_id: String = args[0] as String
		emitted[material_id] = emitted.get(material_id, 0) + (args[1] as int)
	assert_int(emitted.get("foundation_surplus", 0)).is_equal(1)
	assert_int(emitted.get("weapon_surplus", 0)).is_equal(1)
	assert_int(emitted.get("focus_surplus", 0)).is_equal(1)
	assert_int(emitted.get("power_surplus", 0)).is_equal(1)
	assert_int(emitted.get("iron_plating", 0)).is_equal(2)  # physical -> iron_plating bonus


func test_tier_scales_surplus_quantity() -> void:
	_ts.placed_towers[1] = _make_state(4, "elemental")

	GEventBus.mission_phase_changed.emit("WAVE_ACTIVE", "MISSION_COMPLETE", 0.0)

	var emitted: Dictionary[String, int] = {}
	for args: Array in (_spy.emissions["materials_earned"] as Array):
		emitted[args[0] as String] = emitted.get(args[0] as String, 0) + (args[1] as int)
	assert_int(emitted.get("foundation_surplus", 0)).is_equal(4)
	assert_int(emitted.get("rift_shard", 0)).is_equal(2)  # elemental -> rift_shard bonus


func test_multiple_towers_sum_independently() -> void:
	_ts.placed_towers[1] = _make_state(1, "physical")
	_ts.placed_towers[2] = _make_state(2, "physical")

	GEventBus.mission_phase_changed.emit("WAVE_ACTIVE", "MISSION_COMPLETE", 0.0)

	var emitted: Dictionary[String, int] = {}
	for args: Array in (_spy.emissions["materials_earned"] as Array):
		emitted[args[0] as String] = emitted.get(args[0] as String, 0) + (args[1] as int)
	assert_int(emitted.get("foundation_surplus", 0)).is_equal(3)  # 1 + 2


func test_no_placed_towers_grants_nothing() -> void:
	GEventBus.mission_phase_changed.emit("WAVE_ACTIVE", "MISSION_COMPLETE", 0.0)
	assert_int(_spy.count("materials_earned")).is_equal(0)


func test_defeat_grants_nothing() -> void:
	_ts.placed_towers[1] = _make_state(1, "physical")
	GEventBus.mission_phase_changed.emit("WAVE_ACTIVE", "DEFEAT", 0.0)
	assert_int(_spy.count("materials_earned")).is_equal(0)


func test_other_phase_transitions_grant_nothing() -> void:
	_ts.placed_towers[1] = _make_state(1, "physical")
	for phase: String in ["SCOUT", "PRE_WAVE", "WAVE_ACTIVE", "INTERMISSION"]:
		GEventBus.mission_phase_changed.emit("SCOUT", phase, 0.0)
	assert_int(_spy.count("materials_earned")).is_equal(0)
