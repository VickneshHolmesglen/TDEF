class_name EventBusSpy
extends RefCounted

## Lightweight test helper that records EventBus signal emissions.
##
## Usage:
##   var spy := EventBusSpy.new()
##   spy.watch(GEventBus.tower_placed)
##   place_tower(...)
##   assert_true(spy.was_emitted("tower_placed"))
##   assert_eq(spy.count("tower_placed"), 1)
##   spy.disconnect_all()  # required in after_test() to release GEventBus connections

var emissions: Dictionary = {}  # signal_name: String → Array[Array] (each entry = args list)
var _watched: Array = []        # Array of [Signal, Callable] pairs for cleanup


## Connect to a signal. All subsequent emissions are recorded by name.
## Call disconnect_all() in after_test() — GEventBus holds the connection
## indefinitely and prevents this object from being freed otherwise.
func watch(sig: Signal) -> void:
	var cb := func(...args: Array) -> void: _record(sig.get_name(), args)
	sig.connect(cb)
	_watched.append([sig, cb])


## Disconnect all watched signals. Must be called before nulling the spy.
func disconnect_all() -> void:
	for pair: Array in _watched:
		var s: Signal = pair[0] as Signal
		var c: Callable = pair[1] as Callable
		if s.is_connected(c):
			s.disconnect(c)
	_watched.clear()


## Record one emission of signal_name with the given argument list.
func _record(signal_name: String, args: Array) -> void:
	if not emissions.has(signal_name):
		emissions[signal_name] = []
	(emissions[signal_name] as Array).append(args)


## Number of times signal_name was emitted.
func count(signal_name: String) -> int:
	return (emissions.get(signal_name, []) as Array).size()


## True if signal_name was emitted at least once.
func was_emitted(signal_name: String) -> bool:
	return count(signal_name) > 0


## Reset all recorded emissions. Does not disconnect from signals.
func clear() -> void:
	emissions.clear()
