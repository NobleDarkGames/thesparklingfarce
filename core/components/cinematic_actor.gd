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
var movement_speed: float = 3.0

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
	# Movement is now handled by tweens, not per-frame updates
	pass


## Find AnimatedSprite2D in entity hierarchy
func _find_sprite_node(node: Node) -> AnimatedSprite2D:
	if node is AnimatedSprite2D:
		return node

	for child: Node in node.get_children():
		var result: AnimatedSprite2D = _find_sprite_node(child)
		if result != null:
			return result

	return null


## Start moving along a path - delegates to parent entity if possible
## path: Array of waypoints (grid coordinates)
## speed: Movement speed in tiles per second (ignored if parent handles it)
## is_grid: If true, path positions are grid coordinates (default true)
func move_along_path(path: Array, speed: float = -1.0, is_grid: bool = true) -> void:
	if path.is_empty():
		push_warning("CinematicActor: Empty path provided for %s" % actor_id)
		movement_completed.emit()
		return

	if parent_entity == null:
		push_error("CinematicActor: No parent entity for %s" % actor_id)
		movement_completed.emit()
		return

	# Convert waypoints to Vector2i grid coordinates
	var waypoints: Array[Vector2i] = []
	for pos: Variant in path:
		if pos is Vector2:
			waypoints.append(Vector2i(pos))
		elif pos is Array and pos.size() >= 2:
			waypoints.append(Vector2i(pos[0], pos[1]))
		else:
			push_error("CinematicActor: Invalid position in path: %s" % str(pos))

	if waypoints.is_empty():
		push_warning("CinematicActor: No valid waypoints in path for %s" % actor_id)
		movement_completed.emit()
		return

	# ARCHITECTURE: Reuse existing movement systems instead of reimplementing
	# If parent is a Unit (battle) or has move_along_path, use that
	if parent_entity.has_method("move_along_path"):
		_use_parent_movement(waypoints)
	else:
		# Fallback for simple test entities without Unit component
		_use_simple_movement(waypoints, speed)


## Use parent entity's existing movement system (Unit, HeroController, etc.)
func _use_parent_movement(waypoints: Array[Vector2i]) -> void:
	is_moving = true

	# Build complete path using GridManager pathfinding (same as battles)
	var complete_path: Array[Vector2i] = []
	var current_pos: Vector2i = GridManager.world_to_cell(parent_entity.global_position)

	complete_path.append(current_pos)

	# Expand waypoints to full path
	for waypoint: Vector2i in waypoints:
		if waypoint == current_pos:
			continue

		var segment_path: Array[Vector2i] = GridManager.find_path(current_pos, waypoint, 0)

		if segment_path.is_empty():
			push_error("CinematicActor: GridManager not initialized! Call GridManager.setup_grid() before playing cinematics.")
			movement_completed.emit()
			return

		# Add segment to complete path (skip first to avoid duplicates)
		for i: int in range(1, segment_path.size()):
			complete_path.append(segment_path[i])

		current_pos = waypoint

	# Call parent's move_along_path (reusing battle/exploration movement code)
	parent_entity.move_along_path(complete_path)

	# Connect to parent's movement signal if available
	if parent_entity.has_signal("moved"):
		if not parent_entity.moved.is_connected(_on_parent_moved):
			parent_entity.moved.connect(_on_parent_moved)
	else:
		# No signal available, estimate completion time
		var path_length: float = complete_path.size() * GridManager.get_tile_size()
		var estimated_duration: float = path_length / (default_speed * GridManager.get_tile_size())
		await get_tree().create_timer(estimated_duration).timeout
		_stop_movement()


## Simple movement for basic entities without Unit component
func _use_simple_movement(waypoints: Array[Vector2i], speed: float) -> void:
	# This should only be used in minimal test scenes
	push_warning("CinematicActor: Using fallback movement - parent entity lacks move_along_path() method")

	is_moving = true
	movement_speed = speed if speed > 0 else default_speed

	# Build simple path
	var world_path: Array[Vector2] = []
	for waypoint: Vector2i in waypoints:
		world_path.append(GridManager.cell_to_world(waypoint))

	# Simple tween movement
	var move_tween: Tween = create_tween()
	move_tween.set_trans(Tween.TRANS_LINEAR)
	move_tween.set_ease(Tween.EASE_IN_OUT)

	for target_pos: Vector2 in world_path:
		var distance: float = parent_entity.global_position.distance_to(target_pos) if move_tween.get_total_elapsed_time() == 0 else world_path[world_path.find(target_pos) - 1].distance_to(target_pos)
		var duration: float = distance / (movement_speed * GridManager.get_tile_size())
		move_tween.tween_property(parent_entity, "global_position", target_pos, duration)

	move_tween.tween_callback(func() -> void: _stop_movement())


## Called when parent entity's movement completes
func _on_parent_moved(old_pos: Vector2i, new_pos: Vector2i) -> void:
	# Parent has finished moving
	_stop_movement()


## Stop current movement
func _stop_movement() -> void:
	is_moving = false
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
		return Vector2(GridManager.world_to_cell(parent_entity.global_position))
	return Vector2.ZERO


## Simple Manhattan distance pathfinding fallback (for cinematics without battle grid)
## Moves horizontally first, then vertically (4-directional movement)
func _find_manhattan_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current: Vector2i = from

	path.append(current)

	# Move horizontally first
	while current.x != to.x:
		if current.x < to.x:
			current.x += 1
		else:
			current.x -= 1
		path.append(current)

	# Then move vertically
	while current.y != to.y:
		if current.y < to.y:
			current.y += 1
		else:
			current.y -= 1
		path.append(current)

	return path


## Teleport to position (instant, no movement)
func teleport_to(position: Vector2, is_grid: bool = true) -> void:
	if parent_entity == null:
		return

	if is_grid:
		parent_entity.global_position = GridManager.cell_to_world(Vector2i(position))
	else:
		parent_entity.global_position = position
