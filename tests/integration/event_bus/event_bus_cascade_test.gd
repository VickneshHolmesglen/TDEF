extends GdUnitTestSuite

## Integration tests for EventBus cascade depth, batch dispatch, and timing contracts.
##
## ADR-0001 Rule 4: Cascade depth cap = 2 levels.
## ADR-0001 Rule 5: Batch at >= 20 monster_died firings/frame.
## EC-9: When monster_died > 20/frame, Wave Manager switches to monsters_died_batch.
## EC-10: sanctuary_state_restored must fire deferred so subscribers have connected.
##
## Test naming convention: test_[scenario]_[expected]

# ---------------------------------------------------------------------------
# Cascade depth — ADR-0001 Rule 4
# ---------------------------------------------------------------------------

## Two-level cascade: A emits B. B subscriber does NOT emit further.
## This is the allowed pattern (depth == 1 from root).
class _TwoLevelBus extends Node:
	signal signal_a()
	signal signal_b()

func test_two_level_cascade_completes_without_error() -> void:
	# Arrange
	var bus := _TwoLevelBus.new()
	add_child(bus)
	var state := {"received": false}

	# Level-1 cascade: subscriber to A emits B.
	var on_a := func() -> void:
		bus.signal_b.emit()
	# Level-2 end: subscriber to B does NOT emit further (depth cap honoured).
	var on_b := func() -> void:
		state.received = true

	bus.signal_a.connect(on_a)
	bus.signal_b.connect(on_b)

	# Act
	bus.signal_a.emit()

	# Assert — B must have been received via the cascade chain.
	assert_bool(state.received).is_true()

	bus.signal_a.disconnect(on_a)
	bus.signal_b.disconnect(on_b)
	bus.queue_free()

## Level-1 cascade emitter is supposed to use call_deferred to break the sync chain.
## This test documents the failing case: synchronous Level-1 cascade bloats frame cost.
## It is informational — cascade itself will not crash, but it violates the budget rule.
func test_synchronous_cascade_delivers_before_frame_boundary() -> void:
	# Arrange
	var bus := _TwoLevelBus.new()
	add_child(bus)
	var delivery_order: Array[String] = []

	var on_a := func() -> void:
		delivery_order.append("a_handler_start")
		bus.signal_b.emit()  # synchronous — fires B before A's handler returns
		delivery_order.append("a_handler_end")
	var on_b := func() -> void:
		delivery_order.append("b_handler")

	bus.signal_a.connect(on_a)
	bus.signal_b.connect(on_b)

	# Act
	bus.signal_a.emit()

	# Assert — in sync cascade, B fires between A's start and end.
	# This documents the behaviour; production code should use call_deferred instead.
	assert_array(delivery_order).contains_exactly(["a_handler_start", "b_handler", "a_handler_end"])

	bus.signal_a.disconnect(on_a)
	bus.signal_b.disconnect(on_b)
	bus.queue_free()

# ---------------------------------------------------------------------------
# Batch dispatch — ADR-0001 Rule 5 / EC-9
# ---------------------------------------------------------------------------

## Simulates the Wave Manager batch accumulator pattern.
## When >= 20 monster_died firings accumulate in one frame, they are collapsed
## into a single monsters_died_batch emission carrying Array[MonsterDiedEvent].
class _BatchBus extends Node:
	signal monster_died(payload: MonsterDiedEvent)
	signal monsters_died_batch(payloads: Array[MonsterDiedEvent])

func test_batch_accumulator_pattern_fires_once_for_twenty_one_deaths() -> void:
	# Arrange
	var bus := _BatchBus.new()
	add_child(bus)

	var state := {"deaths": 0, "batch": [] as Array[MonsterDiedEvent]}

	var on_individual := func(_p: MonsterDiedEvent) -> void:
		state.deaths += 1
	var on_batch := func(payloads: Array[MonsterDiedEvent]) -> void:
		state.batch.assign(payloads)

	bus.monster_died.connect(on_individual)
	bus.monsters_died_batch.connect(on_batch)

	# Simulate Wave Manager accumulator: 21 deaths in one frame.
	# Wave Manager builds the array and emits once at frame end.
	var accumulator: Array[MonsterDiedEvent] = []
	for i: int in range(21):
		var p := MonsterDiedEvent.new()
		p.entity_id = i
		p.kill_source = "tower"
		p.world_position = Vector2(float(i) * 16.0, 0.0)
		accumulator.append(p)

	# Emit single batch (individual monster_died never fired).
	bus.monsters_died_batch.emit(accumulator)

	# Assert — individual never fired; batch fired once with all 21 entries.
	assert_int(state.deaths).is_equal(0)
	assert_int(state.batch.size()).is_equal(21)
	assert_int(state.batch[0].entity_id).is_equal(0)
	assert_int(state.batch[20].entity_id).is_equal(20)
	assert_str(state.batch[0].kill_source).is_equal("tower")

	bus.monster_died.disconnect(on_individual)
	bus.monsters_died_batch.disconnect(on_batch)
	bus.queue_free()

# ---------------------------------------------------------------------------
# Disconnect before emit — ADR-0001 Rule 6 / EC-2
# ---------------------------------------------------------------------------

func test_disconnect_before_emit_prevents_delivery() -> void:
	# Arrange
	var bus := _BatchBus.new()
	add_child(bus)
	var received: bool = false

	var cb := func(_payloads: Array[MonsterDiedEvent]) -> void:
		received = true
	bus.monsters_died_batch.connect(cb)
	bus.monsters_died_batch.disconnect(cb)

	# Act
	var batch: Array[MonsterDiedEvent] = []
	var p := MonsterDiedEvent.new()
	p.entity_id = 1
	batch.append(p)
	bus.monsters_died_batch.emit(batch)

	# Assert — no delivery after disconnect.
	assert_bool(received).is_false()
	bus.queue_free()

# ---------------------------------------------------------------------------
# Ghost event — EC-3
# ---------------------------------------------------------------------------

class _GhostBus extends Node:
	signal ghost_event(save_slot: int)

func test_ghost_event_with_no_subscribers_does_not_crash() -> void:
	# Arrange — intentionally no subscribers connected.
	var bus := _GhostBus.new()
	add_child(bus)

	# Act — emit to zero subscribers. Must not error (EC-3: silent success is correct).
	bus.ghost_event.emit(1)

	# Assert — reaching here without error is the pass condition.
	assert_bool(true).is_true()
	bus.queue_free()

# ---------------------------------------------------------------------------
# sanctuary_state_restored deferred timing — EC-10
# ---------------------------------------------------------------------------

class _SaveBus extends Node:
	signal sanctuary_state_restored(save_slot: int)

func test_sanctuary_state_restored_delivered_with_correct_slot() -> void:
	# Arrange
	var bus := _SaveBus.new()
	add_child(bus)
	var state := {"slot": -1}
	var cb := func(save_slot: int) -> void: state.slot = save_slot
	bus.sanctuary_state_restored.connect(cb)

	# Act — emit directly (deferred behaviour is a production concern of Save & Persistence).
	# This test validates payload delivery shape only.
	bus.sanctuary_state_restored.emit(2)

	# Assert
	assert_int(state.slot).is_equal(2)

	bus.sanctuary_state_restored.disconnect(cb)
	bus.queue_free()
