## Wait command executor
## Pauses cinematic execution for a specified duration
class_name WaitExecutor
extends CinematicCommandExecutor

## Reference to manager for interrupt cleanup
var _active_manager: Node = null


func execute(command: Dictionary, manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})
	var duration: float = params.get("duration", 1.0)

	# Store manager reference for interrupt cleanup
	_active_manager = manager

	# Set manager's wait timer (handled in _process)
	manager._wait_timer = duration
	manager._is_waiting = true

	return false  # Async - _process will set _command_completed when timer expires


func interrupt() -> void:
	# Reset manager's wait state to stop the timer
	if _active_manager and is_instance_valid(_active_manager):
		_active_manager._wait_timer = 0.0
		_active_manager._is_waiting = false
	_active_manager = null
