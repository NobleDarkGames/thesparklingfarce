## Despawn entity command executor
## Removes an entity from the scene
class_name DespawnEntityExecutor
extends CinematicCommandExecutor

## Track active fade tween for interrupt cleanup
var _active_tween: Tween = null


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
		# Fade out then remove - track tween for interrupt cleanup
		_active_tween = entity.create_tween()
		_active_tween.tween_property(entity, "modulate:a", 0.0, fade_duration)
		_active_tween.tween_callback(entity.queue_free)
		_active_tween.tween_callback(func() -> void: _active_tween = null)
	else:
		# Instant removal
		entity.queue_free()

	return true  # Complete immediately


## Called when cinematic is interrupted - cleanup fade tween if active
func interrupt() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null
