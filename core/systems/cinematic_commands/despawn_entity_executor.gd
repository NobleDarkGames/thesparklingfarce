## Despawn entity command executor
## Removes an entity from the scene
## TODO: Implement entity despawning when ready
class_name DespawnEntityExecutor
extends CinematicCommandExecutor


func execute(command: Dictionary, manager: Node) -> bool:
	var target: String = command.get("target", "")

	var actor: CinematicActor = manager.get_actor(target)
	if actor == null:
		push_error("DespawnEntityExecutor: Actor '%s' not found" % target)
		return true  # Complete immediately on error

	# TODO: Implement entity despawning
	push_warning("DespawnEntityExecutor: despawn_entity not yet implemented")

	return true  # Complete immediately (stub)
