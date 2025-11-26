class_name CinematicActor
extends Node

## Component that makes an entity controllable during cinematics.
## Attach this to any CharacterBody2D, Unit, or NPC to allow scripted control.
##
## The CinematicActor component provides:
## - Unique identification for cinematics to reference
## - Movement control with pathfinding
## - Animation triggering
## - Facing direction control
## - Signal-based completion tracking
##
## Usage:
## 1. Attach CinematicActor as child of character node
## 2. Set unique actor_id
## 3. Reference actor_id in CinematicData commands

## Unique identifier for this actor (used in cinematic commands)
@export var actor_id: String = ""

## Default movement speed for cinematic movement (tiles per second)
@export var default_speed: float = 3.0

## Sprite node for animation control (auto-detected if not set)
@export var sprite_node: AnimatedSprite2D

## Collision shape node (auto-detected if not set)
@export var collision_shape: CollisionShape2D

## Reference to the parent entity (CharacterBody2D, Unit, etc.)
var parent_entity: Node2D

## Current movement state
var is_moving: bool = false
var current_path: Array = []
var current_path_index: int = 0
var movement_speed: float = 3.0
var target_position: Vector2 = Vector2.ZERO

## Emitted when movement along path is completed
signal movement_completed()

## Emitted when animation finishes playing
signal animation_completed()

## Emitted when facing direction change is completed
signal facing_completed()


func _ready() -> void:
	# Get reference to parent entity
	parent_entity = get_parent()

	if parent_entity == null:
		push_error("CinematicActor: Must be child of a Node2D entity")
		return

	# Auto-detect sprite node if not set
	if sprite_node == null:
		sprite_node = _find_sprite_node(parent_entity)
		if sprite_node == null:
			push_warning("CinematicActor: No AnimatedSprite2D found for %s" % actor_id)

	# Validate actor_id is set
	if actor_id.is_empty():
		push_warning("CinematicActor: actor_id not set for %s" % parent_entity.name)


func _process(delta: float) -> void:
	if is_moving and current_path.size() > 0:
		_process_movement(delta)


## Find AnimatedSprite2D in entity hierarchy
func _find_sprite_node(node: Node) -> AnimatedSprite2D:
	if node is AnimatedSprite2D:
		return node

	for child: Node in node.get_children():
		var result: AnimatedSprite2D = _find_sprite_node(child)
		if result != null:
			return result

	return null


## Start moving along a path
## path: Array of Vector2 positions (world coordinates or grid positions)
## speed: Movement speed in tiles per second
## is_grid: If true, path positions are grid coordinates
func move_along_path(path: Array, speed: float = -1.0, is_grid: bool = true) -> void:
	if path.is_empty():
		push_warning("CinematicActor: Empty path provided for %s" % actor_id)
		movement_completed.emit()
		return

	# Convert grid positions to world positions if needed
	if is_grid:
		current_path = []
		for pos: Variant in path:
			if pos is Vector2:
				# Use GridManager to convert grid to world position
				var world_pos: Vector2 = GridManager.grid_to_world(pos)
				current_path.append(world_pos)
			else:
				push_error("CinematicActor: Invalid position in path: %s" % str(pos))
	else:
		current_path = path.duplicate()

	# Set movement parameters
	movement_speed = speed if speed > 0 else default_speed
	current_path_index = 0
	is_moving = true

	# Set first target
	if current_path.size() > 0:
		target_position = current_path[0]


## Process movement towards current target
func _process_movement(delta: float) -> void:
	if parent_entity == null or current_path.is_empty():
		_stop_movement()
		return

	var distance_to_target: float = parent_entity.global_position.distance_to(target_position)
	var move_distance: float = movement_speed * GridManager.TILE_SIZE * delta

	# Check if we reached the target
	if distance_to_target <= move_distance:
		# Snap to target position
		parent_entity.global_position = target_position

		# Move to next waypoint
		current_path_index += 1

		if current_path_index >= current_path.size():
			# Path completed
			_stop_movement()
		else:
			# Continue to next target
			target_position = current_path[current_path_index]
	else:
		# Move towards target
		var direction: Vector2 = (target_position - parent_entity.global_position).normalized()
		parent_entity.global_position += direction * move_distance

		# Update facing direction if sprite exists
		_update_facing_from_direction(direction)


## Stop current movement
func _stop_movement() -> void:
	is_moving = false
	current_path.clear()
	current_path_index = 0
	movement_completed.emit()


## Update sprite facing based on movement direction
func _update_facing_from_direction(direction: Vector2) -> void:
	if sprite_node == null:
		return

	# Determine primary direction (similar to hero_controller logic)
	var abs_x: float = abs(direction.x)
	var abs_y: float = abs(direction.y)

	if abs_x > abs_y:
		if direction.x > 0:
			_play_animation("walk_right")
		else:
			_play_animation("walk_left")
	else:
		if direction.y > 0:
			_play_animation("walk_down")
		else:
			_play_animation("walk_up")


## Set facing direction explicitly
## direction: "up", "down", "left", "right"
func set_facing(direction: String) -> void:
	if sprite_node == null:
		facing_completed.emit()
		return

	match direction.to_lower():
		"up":
			_play_animation("idle_up")
		"down":
			_play_animation("idle_down")
		"left":
			_play_animation("idle_left")
		"right":
			_play_animation("idle_right")
		_:
			push_warning("CinematicActor: Invalid direction '%s' for %s" % [direction, actor_id])

	facing_completed.emit()


## Play animation by name
func play_animation(animation_name: String, wait_for_finish: bool = false) -> void:
	if sprite_node == null:
		push_warning("CinematicActor: No sprite node for %s" % actor_id)
		animation_completed.emit()
		return

	if not sprite_node.sprite_frames.has_animation(animation_name):
		push_warning("CinematicActor: Animation '%s' not found for %s" % [animation_name, actor_id])
		animation_completed.emit()
		return

	sprite_node.play(animation_name)

	if wait_for_finish:
		# Connect to animation_finished signal
		if not sprite_node.animation_finished.is_connected(_on_animation_finished):
			sprite_node.animation_finished.connect(_on_animation_finished)
	else:
		# Emit immediately if not waiting
		animation_completed.emit()


## Internal helper to play animation
func _play_animation(animation_name: String) -> void:
	if sprite_node == null:
		return

	if sprite_node.sprite_frames.has_animation(animation_name):
		sprite_node.play(animation_name)


## Called when animation finishes
func _on_animation_finished() -> void:
	animation_completed.emit()


## Stop current actions
func stop() -> void:
	_stop_movement()
	if sprite_node != null:
		sprite_node.stop()


## Check if actor is currently performing an action
func is_busy() -> bool:
	return is_moving


## Get current world position
func get_world_position() -> Vector2:
	if parent_entity != null:
		return parent_entity.global_position
	return Vector2.ZERO


## Get current grid position
func get_grid_position() -> Vector2:
	if parent_entity != null:
		return GridManager.world_to_grid(parent_entity.global_position)
	return Vector2.ZERO


## Teleport to position (instant, no movement)
func teleport_to(position: Vector2, is_grid: bool = true) -> void:
	if parent_entity == null:
		return

	if is_grid:
		parent_entity.global_position = GridManager.grid_to_world(position)
	else:
		parent_entity.global_position = position
