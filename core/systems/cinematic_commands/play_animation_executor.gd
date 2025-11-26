## Play animation command executor
## Plays an animation on a CinematicActor
class_name PlayAnimationExecutor
extends CinematicCommandExecutor


func execute(command: Dictionary, manager: Node) -> bool:
	var target: String = command.get("target", "")
	var params: Dictionary = command.get("params", {})

	var actor: CinematicActor = manager.get_actor(target)
	if actor == null:
		push_error("PlayAnimationExecutor: Actor '%s' not found" % target)
		return true  # Complete immediately on error

	var animation: String = params.get("animation", "")
	var should_wait: bool = params.get("wait", false)

	if should_wait:
		# Connect to animation_completed signal
		if not actor.animation_completed.is_connected(manager._on_animation_completed):
			actor.animation_completed.connect(manager._on_animation_completed)

	actor.play_animation(animation, should_wait)

	return not should_wait  # Return true if non-blocking, false if waiting
