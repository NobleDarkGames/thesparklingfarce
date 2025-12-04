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
		return

	# Auto-register with CinematicsManager (removes boilerplate from cinematic scenes)
	if CinematicsManager:
		CinematicsManager.register_actor(self)


## Called when this node is about to be removed from the scene tree
func _exit_tree() -> void:
	# Auto-unregister from CinematicsManager
	if not actor_id.is_empty() and CinematicsManager:
		CinematicsManager.unregister_actor(actor_id)


## Find AnimatedSprite2D in entity hierarchy
func _find_sprite_node(node: Node) -> AnimatedSprite2D:
	if node is AnimatedSprite2D:
		return node

	for child: Node in node.get_children():
		var result: AnimatedSprite2D = _find_sprite_node(child)
		if result != null:
			return result

	return null


## Move along a complete path (Phase 3: for executors with pre-expanded paths)
## complete_path: Array[Vector2i] of grid cells (already expanded by GridManager)
## speed: Movement speed in tiles per second (used only for fallback movement)
func move_along_path_direct(complete_path: Array[Vector2i], speed: float = -1.0) -> void:
	if complete_path.is_empty():
		push_warning("CinematicActor: Empty path provided for %s" % actor_id)
		movement_completed.emit()
		return

	if parent_entity == null:
		push_error("CinematicActor: No parent entity for %s" % actor_id)
		movement_completed.emit()
		return

	is_moving = true

	# Delegate directly to parent entity's move_along_path
	if parent_entity.has_method("move_along_path"):
		parent_entity.move_along_path(complete_path)

		# Connect to parent's movement signal if available
		if parent_entity.has_signal("moved"):
			if not parent_entity.moved.is_connected(_on_parent_moved):
				parent_entity.moved.connect(_on_parent_moved, CONNECT_ONE_SHOT)
		else:
			# No signal available, estimate completion time
			var path_length: float = complete_path.size() * GridManager.get_tile_size()
			var estimated_duration: float = path_length / (default_speed * GridManager.get_tile_size())
			await get_tree().create_timer(estimated_duration).timeout
			_stop_movement()
	else:
		# Fallback for simple test entities without Unit component
		_use_simple_movement_direct(complete_path, speed if speed > 0 else default_speed)


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
		if pos is Vector2i:
			waypoints.append(pos)
		elif pos is Vector2:
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
## Phase 3: Simplified to use GridManager.expand_waypoint_path()
func _use_parent_movement(waypoints: Array[Vector2i]) -> void:
	is_moving = true

	# Delegate waypoint expansion to GridManager (Phase 3 refactor)
	var current_pos: Vector2i = GridManager.world_to_cell(parent_entity.global_position)
	var complete_path: Array[Vector2i] = GridManager.expand_waypoint_path(waypoints, 0, current_pos)

	if complete_path.is_empty():
		push_error("CinematicActor: Failed to expand waypoints for %s. GridManager may not be initialized." % actor_id)
		movement_completed.emit()
		return

	# Call parent's move_along_path (reusing battle/exploration movement code)
	parent_entity.move_along_path(complete_path)

	# Connect to parent's movement signal if available
	if parent_entity.has_signal("moved"):
		if not parent_entity.moved.is_connected(_on_parent_moved):
			parent_entity.moved.connect(_on_parent_moved, CONNECT_ONE_SHOT)
	else:
		# No signal available, estimate completion time
		var path_length: float = complete_path.size() * GridManager.get_tile_size()
		var estimated_duration: float = path_length / (default_speed * GridManager.get_tile_size())
		await get_tree().create_timer(estimated_duration).timeout
		_stop_movement()


## Simple movement for basic entities without Unit component
## Uses Manhattan pathfinding for consistent 4-directional movement (matches battle feel)
func _use_simple_movement(waypoints: Array[Vector2i], speed: float) -> void:
	is_moving = true
	movement_speed = speed if speed > 0 else default_speed

	# Build complete path using Manhattan pathfinding between waypoints
	# This ensures consistent 4-directional movement even without battle grid
	var complete_path: Array[Vector2i] = []
	var current_cell: Vector2i = GridManager.world_to_cell(parent_entity.global_position)

	for waypoint: Vector2i in waypoints:
		if waypoint == current_cell:
			continue
		var segment: Array[Vector2i] = _find_manhattan_path(current_cell, waypoint)
		# Skip first cell of segment (it's the current position) unless path is empty
		var start_idx: int = 1 if not complete_path.is_empty() else 0
		for i: int in range(start_idx, segment.size()):
			complete_path.append(segment[i])
		current_cell = waypoint

	if complete_path.is_empty():
		_stop_movement()
		return

	# Convert to world positions
	var world_path: Array[Vector2] = []
	for cell: Vector2i in complete_path:
		world_path.append(GridManager.cell_to_world(cell))

	# Tween through each cell for smooth 4-directional movement
	var move_tween: Tween = create_tween()
	move_tween.set_trans(Tween.TRANS_LINEAR)
	move_tween.set_ease(Tween.EASE_IN_OUT)

	for target_pos: Vector2 in world_path:
		var duration: float = 1.0 / movement_speed  # Each cell takes consistent time
		move_tween.tween_property(parent_entity, "global_position", target_pos, duration)

	move_tween.tween_callback(func() -> void: _stop_movement())


## Simple movement with direct complete path (Phase 3: for move_along_path_direct fallback)
func _use_simple_movement_direct(complete_path: Array[Vector2i], speed: float) -> void:
	is_moving = true
	movement_speed = speed

	# Convert complete path to world positions
	var world_path: Array[Vector2] = []
	for cell: Vector2i in complete_path:
		world_path.append(GridManager.cell_to_world(cell))

	# Simple tween movement
	var move_tween: Tween = create_tween()
	move_tween.set_trans(Tween.TRANS_LINEAR)
	move_tween.set_ease(Tween.EASE_IN_OUT)

	var total_duration: float = 0.0
	for i: int in range(world_path.size()):
		var target_pos: Vector2 = world_path[i]
		var start_pos: Vector2 = world_path[i - 1] if i > 0 else parent_entity.global_position
		var distance: float = start_pos.distance_to(target_pos)
		var duration: float = distance / (movement_speed * GridManager.get_tile_size())
		total_duration += duration
		move_tween.tween_property(parent_entity, "global_position", target_pos, duration)

	move_tween.tween_callback(func() -> void: _stop_movement())


## Called when parent entity's movement completes
func _on_parent_moved(_old_pos: Vector2i, _new_pos: Vector2i) -> void:
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
		# Connect to animation_finished signal with ONE_SHOT to avoid accumulation
		sprite_node.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)
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
func get_grid_position() -> Vector2i:
	if parent_entity != null:
		return GridManager.world_to_cell(parent_entity.global_position)
	return Vector2i.ZERO


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
