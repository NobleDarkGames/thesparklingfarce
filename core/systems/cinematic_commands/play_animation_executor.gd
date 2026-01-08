## Play animation command executor
## Plays an animation on a CinematicActor
class_name PlayAnimationExecutor
extends CinematicCommandExecutor

## Reference to active actor for interrupt cleanup
var _active_actor: CinematicActor = null
## Reference to manager for signal disconnection
var _active_manager: Node = null


func execute(command: Dictionary, manager: Node) -> bool:
	var target: String = command.get("target", "")
	var params: Dictionary = command.get("params", {})

	var actor: CinematicActor = manager.get_actor(target)
	if actor == null:
		push_error("PlayAnimationExecutor: Actor '%s' not found" % target)
		return true  # Complete immediately on error

	# Store references for interrupt cleanup
	_active_actor = actor
	_active_manager = manager

	var animation: String = params.get("animation", "")
	var should_wait: bool = params.get("wait", false)

	if should_wait:
		# Connect to animation_completed signal with ONE_SHOT to prevent signal leak
		if not actor.animation_completed.is_connected(manager._on_animation_completed):
			actor.animation_completed.connect(manager._on_animation_completed, CONNECT_ONE_SHOT)

	actor.play_animation(animation, should_wait)

	return not should_wait  # Return true if non-blocking, false if waiting


func interrupt() -> void:
	# Disconnect signal to prevent stale callbacks
	if _active_actor and is_instance_valid(_active_actor) and _active_manager and is_instance_valid(_active_manager):
		if _active_actor.animation_completed.is_connected(_active_manager._on_animation_completed):
			_active_actor.animation_completed.disconnect(_active_manager._on_animation_completed)
		# Stop the animation
		_active_actor.stop()
	_active_actor = null
	_active_manager = null
