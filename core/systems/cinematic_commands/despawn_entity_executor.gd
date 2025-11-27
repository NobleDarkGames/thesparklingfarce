## Despawn entity command executor
## Removes an entity from the scene
class_name DespawnEntityExecutor
extends CinematicCommandExecutor


func execute(command: Dictionary, manager: Node) -> bool:
	var target: String = command.get("target", "")
	var params: Dictionary = command.get("params", {})

	var actor: CinematicActor = manager.get_actor(target)
	if actor == null:
		push_error("DespawnEntityExecutor: Actor '%s' not found" % target)
		return true  # Complete immediately on error

	# Get the parent entity (the actual scene node)
	var entity: Node = actor.parent_entity
	if entity == null:
		push_error("DespawnEntityExecutor: Actor '%s' has no parent entity" % target)
		return true

	# Unregister the actor from CinematicsManager before removing
	if CinematicsManager:
		CinematicsManager.unregister_actor(target)

	# Check for fade parameter
	var fade_duration: float = params.get("fade", 0.0)

	if fade_duration > 0.0 and entity is CanvasItem:
		# Fade out then remove
		var tween: Tween = entity.create_tween()
		tween.tween_property(entity, "modulate:a", 0.0, fade_duration)
		tween.tween_callback(entity.queue_free)
	else:
		# Instant removal
		entity.queue_free()

	return true  # Complete immediately
