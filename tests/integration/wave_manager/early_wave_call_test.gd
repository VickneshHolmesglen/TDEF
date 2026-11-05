## Early wave call (design/quick-specs/early-wave-call-2026-11-04.md):
## Ready in INTERMISSION with time left emits wave_called_early, and
## ResourceEconomy pays round(seconds x 0.2 x wave_reward_scalar) gold.
extends GdUnitTestSuite

var _wm: WaveManager
var _re: ResourceEconomy
var _spy: EventBusSpy
var _saved_rebuild_queued: bool


func before_test() -> void:
	_wm = WaveManager.new()
	add_child(_wm)
	_wm._spawn_cells = [Vector2i(0, 0)]
	_re = ResourceEconomy.new()
	add_child(_re)
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.wave_called_early)
	_spy.watch(GEventBus.resources_changed)
	_saved_rebuild_queued = GPathfindingSystem._rebuild_queued
	GPathfindingSystem._rebuild_queued = false


func after_test() -> void:
	GPathfindingSystem._rebuild_queued = _saved_rebuild_queued
	_spy.disconnect_all()
	_spy = null
	for node: Node in [_wm, _re]:
		if node != null and is_instance_valid(node):
			remove_child(node)
			node.free()
	_wm = null
	_re = null


func _enter_intermission_with(seconds_left: float, scalar: float) -> void:
	_wm._phase = WaveManager.Phase.INTERMISSION
	_wm._wave_index = 2
	_wm._wave_reward_scalar = scalar
	_wm._intermission_timer.start(seconds_left)


func _early_call_gold_grants() -> Array:
	var grants: Array = []
	for args: Array in (_spy.emissions.get("resources_changed", []) as Array):
		if args[1] == ResourceEconomy.EARLY_CALL_GRANT_SOURCE:
			grants.append(args[0])
	return grants


func test_early_call_gold_formula() -> void:
	assert_int(ResourceEconomy.early_call_gold(30.0, 1.0)).is_equal(6)
	assert_int(ResourceEconomy.early_call_gold(10.0, 2.0)).is_equal(4)
	assert_int(ResourceEconomy.early_call_gold(0.0, 3.0)).is_equal(0)
	assert_int(ResourceEconomy.early_call_gold(-5.0, 1.0)).is_equal(0)


func test_ready_in_intermission_with_time_left_calls_wave_early_and_pays_gold() -> void:
	# Arrange
	_enter_intermission_with(20.0, 1.5)
	# Act
	GEventBus.player_ready.emit()
	# Assert: wave 3 called with ~20 s skipped, gold = round(20 x 0.2 x 1.5) = 6.
	assert_int(_spy.count("wave_called_early")).is_equal(1)
	var args: Array = (_spy.emissions["wave_called_early"] as Array)[0]
	assert_int(args[0]).is_equal(3)
	assert_float(args[1]).is_equal_approx(20.0, 0.1)
	assert_float(args[2]).is_equal_approx(1.5, 0.0001)
	assert_array(_early_call_gold_grants()).contains_exactly([6])
	assert_int(_wm._phase).is_equal(WaveManager.Phase.PRE_WAVE)


func test_ready_with_under_a_second_left_pays_nothing() -> void:
	_enter_intermission_with(0.5, 1.0)
	GEventBus.player_ready.emit()
	assert_int(_spy.count("wave_called_early")).is_equal(0)
	assert_array(_early_call_gold_grants()).is_empty()
	assert_int(_wm._phase).is_equal(WaveManager.Phase.PRE_WAVE)


func test_ready_in_scout_or_pre_wave_is_not_an_early_call() -> void:
	_wm._phase = WaveManager.Phase.SCOUT
	_wm._scout_timer.start(25.0)
	GEventBus.player_ready.emit()  # SCOUT -> PRE_WAVE
	GEventBus.player_ready.emit()  # PRE_WAVE -> WAVE_ACTIVE (skip countdown)
	assert_int(_spy.count("wave_called_early")).is_equal(0)
	assert_array(_early_call_gold_grants()).is_empty()
