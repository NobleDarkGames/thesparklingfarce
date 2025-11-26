## Camera shake command executor
## Applies screen shake effect
## Phase 3: Delegates to CameraController
class_name CameraShakeExecutor
extends CinematicCommandExecutor


func execute(command: Dictionary, manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})
	var intensity: float = params.get("intensity", 2.0)
	var duration: float = params.get("duration", 0.5)
	var frequency: float = params.get("frequency", 30.0)
	var should_wait: bool = params.get("wait", false)

	if not manager._active_camera:
		push_warning("CameraShakeExecutor: No camera available")
		return true  # Complete immediately

	# Check if camera is CameraController (Phase 3 upgrade)
	if not manager._active_camera is CameraController:
		push_warning("CameraShakeExecutor: Camera is Camera2D, not CameraController. Shake skipped. Upgrade to CameraController for Phase 3 features.")
		return true  # Skip shake, continue cinematic

	var camera: CameraController = manager._active_camera as CameraController

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
