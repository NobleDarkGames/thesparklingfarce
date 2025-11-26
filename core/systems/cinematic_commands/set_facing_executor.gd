## Set facing command executor
## Sets the facing direction of a CinematicActor
class_name SetFacingExecutor
extends CinematicCommandExecutor


func execute(command: Dictionary, manager: Node) -> bool:
	var target: String = command.get("target", "")
	var params: Dictionary = command.get("params", {})

	var actor: CinematicActor = manager.get_actor(target)
	if actor == null:
		push_error("SetFacingExecutor: Actor '%s' not found" % target)
		return true  # Complete immediately on error

	var direction: String = params.get("direction", "down")
	actor.set_facing(direction)

	return true  # Synchronous, completes immediately
