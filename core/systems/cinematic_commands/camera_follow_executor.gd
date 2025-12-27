## Camera follow command executor
## Makes camera follow a target actor
## Phase 3: Delegates to CameraController
class_name CameraFollowExecutor
extends CinematicCommandExecutor


func execute(command: Dictionary, manager: Node) -> bool:
	var target: String = command.get("target", "")
	var params: Dictionary = command.get("params", {})
	var should_wait: bool = params.get("wait", false)
	var duration: float = params.get("duration", 0.5)
	var continuous: bool = params.get("continuous", true)  ## Keep following until explicitly stopped

	# Get validated CameraController from manager
	var camera: CameraController = manager.get_camera_controller()
	if not camera:
		return true  # Complete immediately - warning already logged

	var actor: CinematicActor = manager.get_actor(target)
	if actor == null:
		push_error("CameraFollowExecutor: Actor '%s' not found" % target)
		return true  # Complete immediately on error

	# Get actor's parent entity (the actual Node2D to follow)
	var parent_node: Node = actor.get_parent()
	var entity: Node2D = actor.parent_entity if actor.parent_entity else (parent_node if parent_node is Node2D else null)
	if not entity:
		push_error("CameraFollowExecutor: Actor '%s' has no valid parent entity to follow" % target)
		return true

	# Instant snap if duration <= 0 (useful for opening cinematics)
	if duration <= 0.0:
		camera.position = entity.global_position
		if continuous:
			var follow_speed: float = params.get("speed", 8.0)
			camera.follow_actor(entity, follow_speed, 0.0)
		return true  # Instant - no waiting needed

	if continuous:
		# Enable continuous follow
		var follow_speed: float = params.get("speed", 8.0)
		camera.follow_actor(entity, follow_speed, duration)

		# Connect to initial movement completion if waiting
		if should_wait:
			camera.movement_completed.connect(
				func() -> void: manager._command_completed = true,
				CONNECT_ONE_SHOT
			)
			return false  # Async - wait for initial movement

		return true  # Sync - continue immediately
	else:
		# One-time move to actor position
		camera.stop_follow()  # Ensure no continuous follow
		camera.move_to_position(entity.global_position, duration, should_wait)

		# Connect to completion signal if waiting
		if should_wait:
			camera.movement_completed.connect(
				func() -> void: manager._command_completed = true,
				CONNECT_ONE_SHOT
			)
			return false  # Async - wait for signal

		return true  # Sync - continue immediately
