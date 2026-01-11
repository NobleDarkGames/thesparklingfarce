## Camera shake command executor
## Applies screen shake effect
## Phase 3: Delegates to CameraController
class_name CameraShakeExecutor
extends CinematicCommandExecutor

## Reference to camera for interrupt cleanup
var _active_camera: CameraController = null


func execute(command: Dictionary, manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})
	var intensity: float = params.get("intensity", 2.0)
	var duration: float = params.get("duration", 0.5)
	var frequency: float = params.get("frequency", 30.0)
	var should_wait: bool = params.get("wait", true)

	# Get validated CameraController from manager
	var camera: CameraController = manager.get_camera_controller()
	if not camera:
		return true  # Complete immediately - warning already logged

	# Store camera reference for interrupt cleanup
	_active_camera = camera

	# Delegate shake to CameraController
	camera.shake(intensity, duration, frequency)

	# Connect to completion signal if waiting
	if should_wait:
		camera.shake_completed.connect(
			func() -> void: manager._command_completed = true,
			CONNECT_ONE_SHOT
		)
		return false  # Async - wait for signal

	return true  # Sync - continue immediately


func interrupt() -> void:
	# Stop active camera shake
	if _active_camera and is_instance_valid(_active_camera):
		_active_camera._is_shaking = false
		_active_camera._shake_time_remaining = 0.0
		_active_camera.offset = Vector2.ZERO
	_active_camera = null
