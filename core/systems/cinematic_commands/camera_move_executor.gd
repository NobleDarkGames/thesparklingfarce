## Camera move command executor
## Moves camera to a target position
## Phase 3: Delegates to CameraController
class_name CameraMoveExecutor
extends CinematicCommandExecutor

## Reference to camera for interrupt cleanup
var _active_camera: CameraController = null


func execute(command: Dictionary, manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})
	var target_pos: Vector2 = params.get("target_pos", Vector2.ZERO)
	var speed: float = params.get("speed", 2.0)
	var should_wait: bool = params.get("wait", true)

	# Get validated CameraController from manager
	var camera: CameraController = manager.get_camera_controller()
	if not camera:
		return true  # Complete immediately - warning already logged

	# Store camera reference for interrupt cleanup
	_active_camera = camera

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


func interrupt() -> void:
	# Kill active camera movement tween
	if _active_camera and is_instance_valid(_active_camera):
		if _active_camera._movement_tween and _active_camera._movement_tween.is_valid():
			_active_camera._movement_tween.kill()
			_active_camera._movement_tween = null
	_active_camera = null
