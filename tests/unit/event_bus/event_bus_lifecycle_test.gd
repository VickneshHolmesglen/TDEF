extends GdUnitTestSuite

# Tests the ADR-0001 signal lifecycle: connect in _ready(), disconnect in _exit_tree().
#
# Uses an inner test double (_TestBus) instead of the real EventBus.gd so this
# test runs before the Autoload is implemented. When EventBus.gd exists, these
# same patterns apply directly — swap _TestBus for EventBus in the setup.

# Minimal signal-owning node that mirrors EventBus signal shapes.
class _TestBus extends Node:
	signal wave_started(wave_number: int, total_waves: int, wave_difficulty: float)
	signal monster_died(payload: Resource)  # 5+ field events use a Resource payload

var _bus: _TestBus
var _received: Array  # accumulated callback args

func before_each() -> void:
	_bus = _TestBus.new()
	add_child(_bus)
	_received = []

func after_each() -> void:
	_bus.queue_free()

func _on_wave_started(wave_number: int, _total: int, _difficulty: float) -> void:
	_received.append(wave_number)

# --- Happy path ---

func test_subscriber_receives_emitted_signal() -> void:
	_bus.wave_started.connect(_on_wave_started)

	_bus.wave_started.emit(1, 10, 1.0)

	assert_array(_received).contains_exactly([1])
	_bus.wave_started.disconnect(_on_wave_started)

func test_multiple_emissions_accumulate_in_order() -> void:
	_bus.wave_started.connect(_on_wave_started)

	_bus.wave_started.emit(1, 10, 1.0)
	_bus.wave_started.emit(2, 10, 1.2)
	_bus.wave_started.emit(3, 10, 1.4)

	assert_array(_received).contains_exactly([1, 2, 3])
	_bus.wave_started.disconnect(_on_wave_started)

# --- Disconnect enforcement (ADR-0001 Rule: mandatory _exit_tree() disconnect) ---

func test_disconnect_stops_delivery() -> void:
	_bus.wave_started.connect(_on_wave_started)
	_bus.wave_started.disconnect(_on_wave_started)

	_bus.wave_started.emit(99, 10, 1.0)

	assert_array(_received).is_empty()

func test_double_connect_delivers_twice() -> void:
	# Documents the failure mode: connecting the same callable twice
	# causes the subscriber to fire twice per emission.
	# Code review must prevent this — _ready() should guard with is_connected().
	_bus.wave_started.connect(_on_wave_started)
	_bus.wave_started.connect(_on_wave_started)

	_bus.wave_started.emit(5, 10, 1.0)

	assert_int(_received.size()).is_greater(1)  # documents the hazard, not a desired outcome

	# Clean up both connections
	_bus.wave_started.disconnect(_on_wave_started)
	_bus.wave_started.disconnect(_on_wave_started)

# --- Payload typing (ADR-0001 Rule 3: 1-4 fields typed inline, 5+ fields Resource) ---

func test_typed_parameters_arrive_with_correct_types() -> void:
	var captured_wave: int = -1
	var captured_total: int = -1
	var captured_diff: float = -1.0

	var cb := func(wave_number: int, total_waves: int, difficulty: float) -> void:
		captured_wave = wave_number
		captured_total = total_waves
		captured_diff = difficulty

	_bus.wave_started.connect(cb)
	_bus.wave_started.emit(3, 10, 1.5)

	assert_int(captured_wave).is_equal(3)
	assert_int(captured_total).is_equal(10)
	assert_float(captured_diff).is_equal(1.5)

	_bus.wave_started.disconnect(cb)
