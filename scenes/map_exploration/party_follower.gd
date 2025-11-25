## PartyFollower - Party member that follows the hero on the map
##
## Uses the hero's position history to follow behind in a snake-like pattern.
class_name PartyFollower
extends CharacterBody2D

@export var tile_size: int = 32
@export var follow_distance: int = 3  ## Tiles behind leader in position history
@export var movement_smoothing: float = 8.0  ## How quickly to interpolate to target position

## Reference to the character being followed (HeroController or another follower)
var follow_target: Node2D = null

## Visual components (optional)
var sprite: AnimatedSprite2D = null
var collision_shape: CollisionShape2D = null

## Current facing direction
var facing_direction: Vector2i = Vector2i.DOWN


func _ready() -> void:
	# Get optional node references
	sprite = get_node_or_null("AnimatedSprite2D")
	collision_shape = get_node_or_null("CollisionShape2D")

	# Initialize position to match target if set
	if follow_target and follow_target.has_method("get_historical_position"):
		global_position = follow_target.get_historical_position(follow_distance)


func _physics_process(delta: float) -> void:
	if not follow_target:
		return

	# Get target position from history
	var target_pos: Vector2 = Vector2.ZERO

	if follow_target.has_method("get_historical_position"):
		# Following a HeroController or another follower with position history
		target_pos = follow_target.get_historical_position(follow_distance)
	else:
		# Fallback: just follow the target's position directly
		target_pos = follow_target.global_position

	# Smoothly move toward target position
	_move_to_position(target_pos, delta)


func _move_to_position(target_pos: Vector2, delta: float) -> void:
	"""Smoothly interpolate to target position."""
	var distance: float = global_position.distance_to(target_pos)

	# Only move if we're far enough away (avoid jitter)
	if distance > 1.0:
		# Calculate movement direction
		var move_direction: Vector2 = (target_pos - global_position).normalized()

		# Smooth interpolation
		global_position = global_position.lerp(target_pos, movement_smoothing * delta)

		# Update facing direction based on movement
		_update_facing_direction(move_direction)


func _update_facing_direction(move_dir: Vector2) -> void:
	"""Update facing direction based on movement vector."""
	# Only update if moving significantly
	if move_dir.length() < 0.1:
		return

	# Determine primary direction (4-directional)
	if absf(move_dir.x) > absf(move_dir.y):
		# Horizontal movement dominant
		if move_dir.x > 0:
			facing_direction = Vector2i.RIGHT
		else:
			facing_direction = Vector2i.LEFT
	else:
		# Vertical movement dominant
		if move_dir.y > 0:
			facing_direction = Vector2i.DOWN
		else:
			facing_direction = Vector2i.UP

	# Update sprite animation
	_update_sprite_animation()


func _update_sprite_animation() -> void:
	"""Update sprite based on facing direction."""
	if not sprite:
		return

	# TODO: Play appropriate animation based on facing_direction
	# For now, placeholder
	# sprite.play("walk_down")
	pass


func set_follow_target(target: Node2D) -> void:
	"""Set the character to follow."""
	follow_target = target

	# Initialize position if target has history
	if follow_target and follow_target.has_method("get_historical_position"):
		global_position = follow_target.get_historical_position(follow_distance)
