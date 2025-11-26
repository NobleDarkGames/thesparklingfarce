## Wait command executor
## Pauses cinematic execution for a specified duration
class_name WaitExecutor
extends CinematicCommandExecutor


func execute(command: Dictionary, manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})
	var duration: float = params.get("duration", 1.0)

	# Set manager's wait timer (handled in _process)
	manager._wait_timer = duration
	manager._is_waiting = true

	return false  # Async - _process will set _command_completed when timer expires
