## Move entity command executor
## Moves a CinematicActor along a path
## Phase 3: Uses GridManager.expand_waypoint_path() for pathfinding
class_name MoveEntityExecutor
extends CinematicCommandExecutor

## Reference to active actor for interrupt cleanup
var _active_actor: CinematicActor = null


func execute(command: Dictionary, manager: Node) -> bool:
	var target: String = command.get("target", "")
	var params: Dictionary = command.get("params", {})

	var actor: CinematicActor = manager.get_actor(target)
	if actor == null:
		push_error("MoveEntityExecutor: Actor '%s' not found" % target)
		return true  # Complete immediately on error

	# Store actor reference for interrupt cleanup
	_active_actor = actor

	var path: Array = params.get("path", [])
	var speed: float = params.get("speed", -1.0)
	var should_wait: bool = params.get("wait", true)

	# Convert path elements to Vector2i waypoints
	var waypoints: Array[Vector2i] = []
	for pos: Variant in path:
		if pos is Array and pos.size() >= 2:
			var x_val: Variant = pos[0]
			var y_val: Variant = pos[1]
			if (x_val is int or x_val is float) and (y_val is int or y_val is float):
				waypoints.append(Vector2i(int(x_val), int(y_val)))
			else:
				push_error("MoveEntityExecutor: Path position elements must be numeric: %s" % str(pos))
				continue
		elif pos is Vector2:
			waypoints.append(Vector2i(pos))
		elif pos is Vector2i:
			waypoints.append(pos)
		else:
			push_error("MoveEntityExecutor: Invalid path position: %s" % str(pos))

	if waypoints.is_empty():
		push_warning("MoveEntityExecutor: No valid waypoints for actor '%s'" % target)
		return true

	# Try to use GridManager for path expansion (Phase 3)
	# Fall back to old behavior if GridManager not initialized (test scenes)
	var complete_path: Array[Vector2i] = []
	if GridManager.grid != null:
		# Delegate waypoint expansion to GridManager
		var current_pos: Vector2i = GridManager.world_to_cell(actor.parent_entity.global_position) if actor.parent_entity else Vector2i.ZERO
		complete_path = GridManager.expand_waypoint_path(waypoints, 0, current_pos)

		if complete_path.is_empty():
			push_error("MoveEntityExecutor: Failed to expand waypoints for actor '%s'" % target)
			return true

		# Connect to movement_completed signal if waiting
		if should_wait:
			actor.movement_completed.connect(
				func() -> void: manager._command_completed = true,
				CONNECT_ONE_SHOT
			)

		# Delegate movement to actor (which delegates to parent entity)
		actor.move_along_path_direct(complete_path, speed)
	else:
		# Fallback for test scenes without GridManager
		# Use old waypoint-based movement (actor will expand internally or use simple movement)
		if should_wait:
			actor.movement_completed.connect(
				func() -> void: manager._command_completed = true,
				CONNECT_ONE_SHOT
			)

		# Convert waypoints to generic Array for old move_along_path signature
		var path_array: Array = []
		for waypoint: Vector2i in waypoints:
			path_array.append(waypoint)

		actor.move_along_path(path_array, speed, true)

	return not should_wait  # Return true if non-blocking, false if waiting


func interrupt() -> void:
	# Stop active actor movement
	if _active_actor and is_instance_valid(_active_actor):
		_active_actor.stop()
	_active_actor = null
