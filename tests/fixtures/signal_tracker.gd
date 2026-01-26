## Reusable utility for tracking signal emissions in tests
##
## Dependencies: None (pure RefCounted utility)
##
## This fixture is safe for both unit and integration tests.
##
## IMPORTANT: Call disconnect_all() in after_test() to prevent
## signal connections persisting between tests.
##
## Usage:
##   var tracker: SignalTracker = SignalTracker.new()
##   tracker.track(my_object.some_signal)
##   # ... trigger action ...
##   assert_bool(tracker.was_emitted("some_signal")).is_true()
##   assert_int(tracker.emission_count("some_signal")).is_equal(2)
##   tracker.disconnect_all()  # Cleanup - REQUIRED in after_test()
class_name SignalTracker
extends RefCounted


## Structure to store emission data
class EmissionRecord:
	var signal_name: String
	var arguments: Array
	var timestamp: float

	func _init(p_signal_name: String, p_arguments: Array) -> void:
		signal_name = p_signal_name
		arguments = p_arguments
		timestamp = Time.get_ticks_msec() / 1000.0


## All tracked connections (for cleanup)
var _connections: Array[Dictionary] = []

## All recorded emissions
var _emissions: Array[EmissionRecord] = []


## Track a signal for emissions
func track(sig: Signal) -> void:
	var signal_name: String = sig.get_name()
	var callback: Callable = func(arg1: Variant = null, arg2: Variant = null, arg3: Variant = null, arg4: Variant = null) -> void:
		var args: Array = []
		if arg1 != null:
			args.append(arg1)
		if arg2 != null:
			args.append(arg2)
		if arg3 != null:
			args.append(arg3)
		if arg4 != null:
			args.append(arg4)
		_record_emission(signal_name, args)

	sig.connect(callback)
	_connections.append({
		"signal": sig,
		"callable": callback
	})


## Track a signal with a custom callback (for tests that need to inspect args)
## The callback is connected AND tracked for automatic disconnection
func track_with_callback(sig: Signal, callback: Callable) -> void:
	sig.connect(callback)
	_connections.append({
		"signal": sig,
		"callable": callback
	})


## Record an emission internally
func _record_emission(signal_name: String, arguments: Array) -> void:
	_emissions.append(EmissionRecord.new(signal_name, arguments))


## Check if a signal was emitted at least once
func was_emitted(signal_name: String) -> bool:
	for emission: EmissionRecord in _emissions:
		if emission.signal_name == signal_name:
			return true
	return false


## Get total emission count for a signal
func emission_count(signal_name: String) -> int:
	var count: int = 0
	for emission: EmissionRecord in _emissions:
		if emission.signal_name == signal_name:
			count += 1
	return count


## Get all emissions for a signal (for detailed assertions)
func get_emissions(signal_name: String) -> Array[EmissionRecord]:
	var result: Array[EmissionRecord] = []
	for emission: EmissionRecord in _emissions:
		if emission.signal_name == signal_name:
			result.append(emission)
	return result


## Check if signal was emitted with specific arguments
func was_emitted_with(signal_name: String, expected_args: Array) -> bool:
	for emission: EmissionRecord in _emissions:
		if emission.signal_name == signal_name:
			if _arrays_equal(emission.arguments, expected_args):
				return true
	return false


## Helper for array comparison
func _arrays_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in range(a.size()):
		if a[i] != b[i]:
			return false
	return true


## Clear all recorded emissions (useful between test phases)
func clear_emissions() -> void:
	_emissions.clear()


## Disconnect all tracked signals (MUST call in after_test)
func disconnect_all() -> void:
	for conn: Dictionary in _connections:
		var sig: Signal = conn.signal
		var callable: Callable = conn.callable
		if sig.is_connected(callable):
			sig.disconnect(callable)
	_connections.clear()
	_emissions.clear()
