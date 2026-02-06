class_name CinematicActor
extends Node

## Component that makes an entity controllable during cinematics.
## Attach this to any CharacterBody2D, Unit, or NPC to allow scripted control.
##
## Usage:
## 1. Attach CinematicActor as child of character node
## 2. Set unique actor_id
## 3. Reference actor_id in CinematicData commands

const FacingUtils = preload("res://core/utils/facing_utils.gd")
const DEFAULT_MOVEMENT_SPEED: float = 3.0

@export var actor_id: String = ""
@export var default_speed: float = DEFAULT_MOVEMENT_SPEED
@export var sprite_node: Node2D
@export var collision_shape: CollisionShape2D

var character_uid: String = ""
var parent_entity: Node2D
var is_moving: bool = false
var movement_speed: float = DEFAULT_MOVEMENT_SPEED

signal movement_completed()
signal animation_completed()
signal facing_completed()


func _ready() -> void:
	var parent: Node = get_parent()
	parent_entity = parent as Node2D

	if parent_entity == null:
		push_error("CinematicActor: Must be child of a Node2D entity")
		return

	if sprite_node == null:
		sprite_node = _find_sprite_node(parent_entity)
		if sprite_node == null:
			push_warning("CinematicActor: No AnimatedSprite2D found for %s" % actor_id)

	if actor_id.is_empty():
		push_warning("CinematicActor: actor_id not set for %s" % parent_entity.name)
		return

	if CinematicsManager:
		CinematicsManager.register_actor(self)


func _exit_tree() -> void:
	if not actor_id.is_empty() and CinematicsManager:
		CinematicsManager.unregister_actor(actor_id)


func _find_sprite_node(node: Node) -> AnimatedSprite2D:
	if node is AnimatedSprite2D:
		return node
	for child: Node in node.get_children():
		var result: AnimatedSprite2D = _find_sprite_node(child)
		if result != null:
			return result
	return null


## Move along a pre-expanded path (for executors with GridManager-expanded paths)
func move_along_path_direct(complete_path: Array[Vector2i], speed: float = -1.0, auto_face: bool = true) -> void:
	if not _validate_movement_preconditions(complete_path):
		return

	is_moving = true
	if parent_entity.has_method("move_along_path"):
		parent_entity.call("move_along_path", complete_path)
		_await_parent_movement(complete_path)
	else:
		_use_simple_movement_direct(complete_path, speed if speed > 0 else default_speed, auto_face)


## Move along waypoints - delegates to parent entity if possible
func move_along_path(path: Array, speed: float = -1.0, _is_grid: bool = true, auto_face: bool = true) -> void:
	var waypoints: Array[Vector2i] = _convert_to_waypoints(path)
	if not _validate_movement_preconditions(waypoints):
		return

	if parent_entity.has_method("move_along_path"):
		_use_parent_movement(waypoints)
	else:
		_use_simple_movement(waypoints, speed, auto_face)


func _validate_movement_preconditions(path: Array[Vector2i]) -> bool:
	if path.is_empty():
		push_warning("CinematicActor: Empty path provided for %s" % actor_id)
		movement_completed.emit()
		return false
	if parent_entity == null:
		push_error("CinematicActor: No parent entity for %s" % actor_id)
		movement_completed.emit()
		return false
	return true


func _convert_to_waypoints(path: Array) -> Array[Vector2i]:
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
	return waypoints


func _use_parent_movement(waypoints: Array[Vector2i]) -> void:
	is_moving = true

	if not is_instance_valid(parent_entity):
		push_error("CinematicActor: Parent entity was freed for %s" % actor_id)
		movement_completed.emit()
		return

	var current_pos: Vector2i = GridManager.world_to_cell(parent_entity.global_position)
	var complete_path: Array[Vector2i] = GridManager.expand_waypoint_path(waypoints, 0, current_pos, true)

	if complete_path.is_empty():
		push_error("CinematicActor: Failed to expand waypoints for %s. GridManager may not be initialized." % actor_id)
		movement_completed.emit()
		return

	parent_entity.call("move_along_path", complete_path)
	_await_parent_movement(complete_path)


func _use_simple_movement(waypoints: Array[Vector2i], speed: float, auto_face: bool = true) -> void:
	is_moving = true
	movement_speed = speed if speed > 0 else default_speed

	var complete_path: Array[Vector2i] = _build_manhattan_path(waypoints)
	if complete_path.is_empty():
		_stop_movement()
		return

	var world_path: Array[Vector2] = _grid_to_world_path(complete_path)
	_tween_through_world_path(world_path, movement_speed, auto_face)


func _use_simple_movement_direct(complete_path: Array[Vector2i], speed: float, auto_face: bool = true) -> void:
	is_moving = true
	movement_speed = speed
	_tween_through_world_path(_grid_to_world_path(complete_path), speed, auto_face)


func _build_manhattan_path(waypoints: Array[Vector2i]) -> Array[Vector2i]:
	var complete_path: Array[Vector2i] = []
	var current_cell: Vector2i = GridManager.world_to_cell(parent_entity.global_position)

	for waypoint: Vector2i in waypoints:
		if waypoint == current_cell:
			continue
		var segment: Array[Vector2i] = _find_manhattan_path(current_cell, waypoint)
		var start_idx: int = 1 if not complete_path.is_empty() else 0
		for i: int in range(start_idx, segment.size()):
			complete_path.append(segment[i])
		current_cell = waypoint

	return complete_path


func _grid_to_world_path(grid_path: Array[Vector2i]) -> Array[Vector2]:
	var world_path: Array[Vector2] = []
	for cell: Vector2i in grid_path:
		world_path.append(GridManager.cell_to_world(cell))
	return world_path


func _on_parent_moved(_old_pos: Vector2i, _new_pos: Vector2i) -> void:
	_stop_movement()


func _stop_movement() -> void:
	is_moving = false
	_sync_parent_grid_position()
	movement_completed.emit()


func _sync_parent_grid_position() -> void:
	if not parent_entity or not is_instance_valid(parent_entity):
		return
	if "grid_position" in parent_entity:
		parent_entity.grid_position = GridManager.world_to_cell(parent_entity.global_position)


func _await_parent_movement(complete_path: Array[Vector2i]) -> void:
	if parent_entity.has_signal("moved"):
		var moved_signal: Signal = Signal(parent_entity, "moved")
		if not moved_signal.is_connected(_on_parent_moved):
			moved_signal.connect(_on_parent_moved, CONNECT_ONE_SHOT)
	else:
		var path_length: float = complete_path.size() * GridManager.get_tile_size()
		var estimated_duration: float = path_length / (default_speed * GridManager.get_tile_size())
		await get_tree().create_timer(estimated_duration).timeout
		if not is_instance_valid(self):
			return
		_stop_movement()


func _tween_through_world_path(world_path: Array[Vector2], tiles_per_second: float, auto_face: bool = true) -> void:
	var move_tween: Tween = create_tween()
	move_tween.set_trans(Tween.TRANS_LINEAR)
	move_tween.set_ease(Tween.EASE_IN_OUT)

	for i: int in range(world_path.size()):
		var target_pos: Vector2 = world_path[i]
		var start_pos: Vector2 = world_path[i - 1] if i > 0 else parent_entity.global_position
		var direction: Vector2 = target_pos - start_pos
		var distance: float = start_pos.distance_to(target_pos)
		var duration: float = distance / (tiles_per_second * GridManager.get_tile_size())
		if auto_face:
			move_tween.tween_callback(_update_facing_from_direction.bind(direction))
		move_tween.tween_property(parent_entity, "global_position", target_pos, duration)

	move_tween.tween_callback(_stop_movement)


func _update_facing_from_direction(direction: Vector2) -> void:
	var dir_name: String = FacingUtils.get_dominant_direction_float(direction)

	if parent_entity and parent_entity.has_method("set_facing"):
		parent_entity.call("set_facing", dir_name)
		return

	if sprite_node != null:
		_play_animation("walk_" + dir_name)


func set_facing(direction: String) -> void:
	if sprite_node == null:
		facing_completed.emit()
		return

	var dir_lower: String = direction.to_lower()
	if FacingUtils.is_valid_direction(dir_lower):
		_play_animation("walk_" + dir_lower)
	else:
		push_warning("CinematicActor: Invalid direction '%s' for %s" % [direction, actor_id])

	facing_completed.emit()


func play_animation(animation_name: String, wait_for_finish: bool = false) -> void:
	if sprite_node == null or not sprite_node is AnimatedSprite2D:
		if sprite_node == null:
			push_warning("CinematicActor: No sprite node for %s" % actor_id)
		animation_completed.emit()
		return

	var anim_sprite: AnimatedSprite2D = sprite_node as AnimatedSprite2D
	if not anim_sprite.sprite_frames.has_animation(animation_name):
		push_warning("CinematicActor: Animation '%s' not found for %s" % [animation_name, actor_id])
		animation_completed.emit()
		return

	anim_sprite.play(animation_name)

	if wait_for_finish:
		anim_sprite.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)
	else:
		animation_completed.emit()


func _play_animation(animation_name: String) -> void:
	if sprite_node == null or not sprite_node is AnimatedSprite2D:
		return
	var anim_sprite: AnimatedSprite2D = sprite_node as AnimatedSprite2D
	if anim_sprite.sprite_frames.has_animation(animation_name):
		anim_sprite.play(animation_name)


func _on_animation_finished() -> void:
	animation_completed.emit()


func stop() -> void:
	_stop_movement()
	if sprite_node != null and sprite_node is AnimatedSprite2D:
		(sprite_node as AnimatedSprite2D).stop()


func is_busy() -> bool:
	return is_moving


func get_world_position() -> Vector2:
	if parent_entity and is_instance_valid(parent_entity):
		return parent_entity.global_position
	return Vector2.ZERO


func get_grid_position() -> Vector2i:
	if parent_entity and is_instance_valid(parent_entity):
		return GridManager.world_to_cell(parent_entity.global_position)
	return Vector2i.ZERO


func _find_manhattan_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [from]
	var current: Vector2i = from

	# Move horizontally first
	while current.x != to.x:
		current.x += 1 if current.x < to.x else -1
		path.append(current)

	# Then move vertically
	while current.y != to.y:
		current.y += 1 if current.y < to.y else -1
		path.append(current)

	return path


func teleport_to(pos: Vector2, is_grid: bool = true) -> void:
	if parent_entity == null:
		return

	parent_entity.global_position = GridManager.cell_to_world(Vector2i(pos)) if is_grid else pos
	_sync_parent_grid_position()

	if parent_entity is CharacterBody2D:
		var body: CharacterBody2D = parent_entity as CharacterBody2D
		body.velocity = Vector2.ZERO
		body.move_and_slide()
