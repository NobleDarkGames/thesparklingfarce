## FacingUtils - Shared direction/facing conversion utilities
##
## Consolidates duplicated direction conversion logic used by:
## - Unit.gd (battle units)
## - HeroController.gd (map exploration)
## - InputManager.gd (player input handling)
## - NPCNode.gd, CinematicActor.gd, CaravanFollower.gd
class_name FacingUtils
extends RefCounted


## Valid facing direction strings
const DIRECTIONS: Array[String] = ["up", "down", "left", "right"]
const DEFAULT_DIRECTION: String = "down"


## Convert Vector2i direction to string name
## Examples: Vector2i.UP -> "up", Vector2i(1, 0) -> "right"
static func direction_to_string(direction: Vector2i) -> String:
	match direction:
		Vector2i.UP:
			return "up"
		Vector2i.DOWN:
			return "down"
		Vector2i.LEFT:
			return "left"
		Vector2i.RIGHT:
			return "right"
		_:
			return DEFAULT_DIRECTION


## Convert string direction to Vector2i
## Examples: "up" -> Vector2i.UP, "LEFT" -> Vector2i.LEFT
static func string_to_direction(dir_name: String) -> Vector2i:
	match dir_name.to_lower():
		"up":
			return Vector2i.UP
		"down":
			return Vector2i.DOWN
		"left":
			return Vector2i.LEFT
		"right":
			return Vector2i.RIGHT
		_:
			return Vector2i.DOWN


## Get dominant direction string from a delta vector
## Used for movement and facing toward targets
## Examples: Vector2i(3, 1) -> "right", Vector2i(-1, -5) -> "up"
static func get_dominant_direction(delta: Vector2i) -> String:
	if delta == Vector2i.ZERO:
		return DEFAULT_DIRECTION

	if abs(delta.x) >= abs(delta.y):
		return "right" if delta.x > 0 else "left"
	else:
		return "down" if delta.y > 0 else "up"


## Get dominant direction as Vector2i from a delta vector
## Examples: Vector2i(3, 1) -> Vector2i.RIGHT, Vector2i(-1, -5) -> Vector2i.UP
static func get_dominant_direction_vector(delta: Vector2i) -> Vector2i:
	if delta == Vector2i.ZERO:
		return Vector2i.DOWN

	if abs(delta.x) >= abs(delta.y):
		return Vector2i.RIGHT if delta.x > 0 else Vector2i.LEFT
	else:
		return Vector2i.DOWN if delta.y > 0 else Vector2i.UP


## Check if a string is a valid direction
static func is_valid_direction(dir_name: String) -> bool:
	return dir_name.to_lower() in DIRECTIONS


## Get dominant direction string from a float delta vector (for world positions)
## Used for facing toward world-space targets
## Examples: Vector2(30.0, 10.5) -> "right", Vector2(-5.0, -50.0) -> "up"
static func get_dominant_direction_float(delta: Vector2) -> String:
	if delta.is_zero_approx():
		return DEFAULT_DIRECTION

	if absf(delta.x) >= absf(delta.y):
		return "right" if delta.x > 0 else "left"
	else:
		return "down" if delta.y > 0 else "up"
