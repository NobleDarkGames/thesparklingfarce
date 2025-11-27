## HeroController - Player character controller for map exploration
##
## Handles grid-based movement on the overworld map with smooth interpolation.
## Maintains position history for party followers to use.
class_name HeroController
extends CharacterBody2D

## Emitted when hero completes movement to a new tile
signal moved_to_tile(tile_position: Vector2i)

## Emitted when hero interacts with something (A button)
signal interaction_requested(interaction_position: Vector2i)

@export var tile_size: int = 32  ## SF-authentic: unified 32px tiles for all modes
@export var movement_speed: float = 4.0  ## tiles per second
@export var position_history_size: int = 20  ## Number of positions to track for followers

## Current facing direction (for sprites and interactions)
var facing_direction: Vector2i = Vector2i.DOWN

## Grid position tracking
var grid_position: Vector2i = Vector2i.ZERO
var target_position: Vector2 = Vector2.ZERO
var is_moving: bool = false

## Position history for followers (world positions, not grid)
var position_history: Array[Vector2] = []

## References (optional - may not exist in all setups)
var sprite: AnimatedSprite2D = null
var collision_shape: CollisionShape2D = null
var interaction_ray: RayCast2D = null
var tile_map: TileMapLayer = null


func _ready() -> void:
	# Add to "hero" group for trigger detection
	add_to_group("hero")

	# Get optional node references
	sprite = get_node_or_null("AnimatedSprite2D")
	collision_shape = get_node_or_null("CollisionShape2D")
	interaction_ray = get_node_or_null("InteractionRay")

	# Get TileMapLayer reference (sibling node in map scenes)
	tile_map = get_node_or_null("../TileMapLayer")
	if not tile_map:
		push_warning("HeroController: No TileMapLayer found - collision detection disabled")

	# Initialize position
	grid_position = world_to_grid(global_position)
	target_position = grid_to_world(grid_position)  # Snap to grid center
	global_position = target_position  # Actually snap the position

	print("[HeroController] Init - tile_size: %d" % tile_size)
	print("[HeroController] Init - global_position: %s" % global_position)
	print("[HeroController] Init - grid_position: %s" % grid_position)
	print("[HeroController] Init - target_position: %s" % target_position)

	# Initialize position history with current position
	position_history.clear()
	for i in range(position_history_size):
		position_history.append(global_position)

	# Setup interaction raycast
	if interaction_ray:
		interaction_ray.enabled = true
		interaction_ray.target_position = Vector2(tile_size, 0)  # Default to right


func _physics_process(delta: float) -> void:
	# Handle movement
	if is_moving:
		_process_movement(delta)
	else:
		_process_input()

	# Update position history
	_update_position_history()


## Smoothly interpolate to target position.
func _process_movement(delta: float) -> void:
	var distance_to_target: float = global_position.distance_to(target_position)

	if distance_to_target < 1.0:
		# Snap to target
		global_position = target_position
		grid_position = world_to_grid(global_position)
		is_moving = false

		# Emit signal
		moved_to_tile.emit(grid_position)

		# Check for triggers at new position
		_check_tile_triggers()
	else:
		# Move toward target
		var direction_vec: Vector2 = (target_position - global_position).normalized()
		var move_distance: float = movement_speed * tile_size * delta
		global_position += direction_vec * move_distance


## Handle directional input for movement.
func _process_input() -> void:
	# TODO: Don't process input if dialog is open or other systems are active
	# if DialogManager and DialogManager.is_dialog_active():
	# 	return

	var input_dir: Vector2i = Vector2i.ZERO

	# Get input direction (4-directional only)
	if Input.is_action_pressed("ui_up"):
		input_dir = Vector2i.UP
	elif Input.is_action_pressed("ui_down"):
		input_dir = Vector2i.DOWN
	elif Input.is_action_pressed("ui_left"):
		input_dir = Vector2i.LEFT
	elif Input.is_action_pressed("ui_right"):
		input_dir = Vector2i.RIGHT

	# Try to move in that direction
	if input_dir != Vector2i.ZERO:
		attempt_move(input_dir)


## Handle interaction input.
func _input(event: InputEvent) -> void:
	if is_moving:
		return

	# TODO: Check if dialog is active
	# if DialogManager and DialogManager.is_dialog_active():
	# 	return

	# Interaction key (confirm)
	if event.is_action_pressed("sf_confirm"):
		_try_interact()


## Attempt to move in the given direction.
## Returns true if movement was initiated, false if blocked.
func attempt_move(direction: Vector2i) -> bool:
	if is_moving:
		return false

	# Calculate target grid position
	var target_grid: Vector2i = grid_position + direction

	# Check if target is walkable
	if not _is_tile_walkable(target_grid):
		return false

	# Update facing direction
	facing_direction = direction
	_update_interaction_ray()

	# Start movement
	target_position = grid_to_world(target_grid)
	is_moving = true

	# Update sprite animation
	_update_sprite_animation(direction)

	return true


## Check if a tile is walkable using TileMap collision data.
## Tiles with physics collision are considered impassable (walls, water, etc.)
## Tiles without physics collision are walkable (grass, roads, etc.)
func _is_tile_walkable(tile_pos: Vector2i) -> bool:
	# If no TileMap reference, allow movement (fallback behavior)
	if not tile_map:
		return true

	# Get tile data at the target position
	var tile_data: TileData = tile_map.get_cell_tile_data(tile_pos)

	# No tile = empty space = walkable
	if tile_data == null:
		return true

	# Check if tile has collision polygon on physics layer 0
	# If it has collision, it's impassable (wall, water, etc.)
	# If no collision, it's walkable (grass, road, etc.)
	var has_collision: bool = tile_data.get_collision_polygons_count(0) > 0

	return not has_collision


## Check if the current tile has any triggers (battles, events, etc.)
func _check_tile_triggers() -> void:
	# TODO: Implement trigger system
	# This will check for:
	# - Battle encounters
	# - Cutscene triggers
	# - Area transitions
	# - NPCs
	pass


## Attempt to interact with whatever is in front of the hero.
func _try_interact() -> void:
	var interaction_pos: Vector2i = grid_position + facing_direction
	interaction_requested.emit(interaction_pos)


## Update the interaction raycast to face the current direction.
func _update_interaction_ray() -> void:
	if not interaction_ray:
		return

	interaction_ray.target_position = Vector2(facing_direction) * tile_size


## Update sprite animation based on movement direction.
func _update_sprite_animation(direction: Vector2i) -> void:
	if not sprite:
		return

	# TODO: Play appropriate walk animation based on direction
	# For now, just a placeholder
	# sprite.play("walk_down")  # Will implement when we have sprites
	pass


## Add current position to history for followers.
func _update_position_history() -> void:
	# Add current position to front
	position_history.push_front(global_position)

	# Remove oldest position if we exceed the limit
	if position_history.size() > position_history_size:
		position_history.pop_back()


## Get a position from the hero's movement history.
## steps_back: How many steps back in history to look (0 = current position)
func get_historical_position(steps_back: int) -> Vector2:
	steps_back = clampi(steps_back, 0, position_history.size() - 1)
	return position_history[steps_back]


## Convert world position to grid coordinates.
func world_to_grid(world_pos: Vector2) -> Vector2i:
	# Use TileMapLayer's built-in method if available (recommended)
	if tile_map:
		return tile_map.local_to_map(world_pos)
	else:
		# Fallback for testing without tilemap
		return Vector2i(floori(world_pos.x / tile_size), floori(world_pos.y / tile_size))


## Convert grid coordinates to world position (centered on tile).
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	# Use TileMapLayer's built-in method if available (recommended)
	if tile_map:
		return tile_map.map_to_local(grid_pos)
	else:
		# Fallback for testing without tilemap
		return Vector2(grid_pos) * tile_size + Vector2(tile_size, tile_size) * 0.5


## Instantly move hero to a grid position (for scene transitions, etc.).
func teleport_to_grid(new_grid_pos: Vector2i) -> void:
	grid_position = new_grid_pos
	global_position = grid_to_world(grid_position)
	target_position = global_position
	is_moving = false

	# Clear position history and fill with new position
	position_history.clear()
	for i in range(position_history_size):
		position_history.append(global_position)
