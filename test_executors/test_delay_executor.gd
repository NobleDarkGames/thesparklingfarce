## Test executor that creates a delay
## Demonstrates asynchronous command execution
extends CinematicCommandExecutor

var _manager: Node = null
var _timer: Timer = null


func execute(command: Dictionary, manager: Node) -> bool:
	_manager = manager
	var params: Dictionary = command.get("params", {})
	var duration: float = params.get("duration", 1.0)

	print("TestDelayExecutor: Starting %s second delay..." % duration)

	# Create timer for delay
	_timer = Timer.new()
	_timer.wait_time = duration
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	manager.add_child(_timer)
	_timer.start()

	return false  # Async - will call manager._command_completed when done


func _on_timer_timeout() -> void:
	print("TestDelayExecutor: Delay complete!")
	if _timer:
		_timer.queue_free()
		_timer = null
	# Signal completion
	if _manager:
		_manager._command_completed = true


func interrupt() -> void:
	# Clean up if cinematic is skipped
	if _timer:
		_timer.stop()
		_timer.queue_free()
		_timer = null
