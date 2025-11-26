## Test executor that tracks whether interrupt() was called
## Used to verify cleanup on cinematic skip
extends CinematicCommandExecutor

class_name TestInterruptExecutor

# Static tracking variables (shared across instances for testing)
static var interrupt_called: bool = false
static var execute_called: bool = false
static var cleanup_verified: bool = false

var _timer: Timer = null
var _manager: Node = null


func execute(command: Dictionary, manager: Node) -> bool:
	execute_called = true
	interrupt_called = false
	cleanup_verified = false
	_manager = manager

	var params: Dictionary = command.get("params", {})
	var duration: float = params.get("duration", 2.0)

	print("TestInterruptExecutor: Starting %s second operation..." % duration)

	# Create timer for long-running async operation
	_timer = Timer.new()
	_timer.wait_time = duration
	_timer.one_shot = true
	_timer.timeout.connect(_on_timeout)
	manager.add_child(_timer)
	_timer.start()

	return false  # Async operation


func _on_timeout() -> void:
	print("TestInterruptExecutor: Operation completed naturally")
	if _timer:
		_timer.queue_free()
		_timer = null
	if _manager:
		_manager._command_completed = true


func interrupt() -> void:
	print("TestInterruptExecutor: interrupt() called - cleaning up!")
	interrupt_called = true

	# Clean up timer
	if _timer and is_instance_valid(_timer):
		_timer.stop()
		_timer.queue_free()
		_timer = null
		cleanup_verified = true

	_manager = null


## Reset static tracking variables (call before each test)
static func reset_tracking() -> void:
	interrupt_called = false
	execute_called = false
	cleanup_verified = false
