## Set position command executor
## Instantly teleports a CinematicActor to a position (no animation)
## Useful for repositioning actors during fade transitions
class_name SetPositionExecutor
extends CinematicCommandExecutor


func execute(command: Dictionary, manager: Node) -> bool:
	var target: String = command.get("target", "")
	var params: Dictionary = command.get("params", {})

	var actor: CinematicActor = manager.get_actor(target)
	if actor == null:
		push_error("SetPositionExecutor: Actor '%s' not found" % target)
		return true  # Complete immediately on error

	# Get position (required) - handles both Vector2 and Array [x, y]
	var position_raw: Variant = params.get("position", null)
	var pos_vec: Vector2

	if position_raw is Vector2:
		pos_vec = position_raw
	elif position_raw is Array and position_raw.size() >= 2:
		var x_val: Variant = position_raw[0]
		var y_val: Variant = position_raw[1]
		if (x_val is int or x_val is float) and (y_val is int or y_val is float):
			pos_vec = Vector2(x_val, y_val)
		else:
			push_error("SetPositionExecutor: Position array elements must be numeric for actor '%s'" % target)
			return true
	else:
		push_error("SetPositionExecutor: Invalid position for actor '%s'" % target)
		return true

	# Teleport to position (grid coordinates by default)
	var is_grid: bool = params.get("is_grid", true)
	actor.teleport_to(pos_vec, is_grid)

	# Optionally set facing direction after teleport
	var facing: String = params.get("facing", "")
	if not facing.is_empty():
		actor.set_facing(facing)

	return true  # Synchronous, completes immediately
