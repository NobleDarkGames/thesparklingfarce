## Camera move command executor
## Moves camera to a target position
## Phase 3: Delegates to CameraController
class_name CameraMoveExecutor
extends CinematicCommandExecutor


func execute(command: Dictionary, manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})
	var target_pos: Vector2 = params.get("target_pos", Vector2.ZERO)
	var speed: float = params.get("speed", 2.0)
	var should_wait: bool = params.get("wait", true)

	if not manager._active_camera:
		push_warning("CameraMoveExecutor: No camera available")
		return true  # Complete immediately

	# Check if camera is CameraController (Phase 3 upgrade)
	if not manager._active_camera is CameraController:
		push_warning("CameraMoveExecutor: Camera is Camera2D, not CameraController. Movement skipped. Upgrade to CameraController for Phase 3 features.")
		return true  # Skip move, continue cinematic

	var camera: CameraController = manager._active_camera as CameraController

	# Convert grid position to world position if needed
	var world_pos: Vector2 = target_pos
	if params.get("is_grid", false):
		world_pos = GridManager.cell_to_world(Vector2i(target_pos))

	# Calculate duration based on speed (speed is tiles per second)
	var distance: float = camera.global_position.distance_to(world_pos)
	var duration: float = distance / (speed * GridManager.get_tile_size())
	duration = max(duration, 0.1)  # Minimum duration

	# Delegate to CameraController
	camera.move_to_position(world_pos, duration, should_wait)

	# Connect to completion signal if waiting
	if should_wait:
		camera.movement_completed.connect(
			func() -> void: manager._command_completed = true,
			CONNECT_ONE_SHOT
		)
		return false  # Async - wait for signal

	return true  # Sync - continue immediately
