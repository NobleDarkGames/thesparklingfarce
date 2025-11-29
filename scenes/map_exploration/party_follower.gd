## PartyFollower - Party member that follows the hero on the map
##
## Uses SF2-style formation following with diagonal shortcuts.
## Followers seek their target position directly rather than tracing the hero's exact path.
class_name PartyFollower
extends CharacterBody2D

@export var tile_size: int = 32
@export var follow_distance: int = 1  ## Number of "units" behind leader (spacing in chain)
@export var movement_speed: float = 4.5  ## Slightly faster than hero to catch up
@export var min_distance_threshold: float = 8.0  ## Don't move if closer than this

## Reference to the character being followed (HeroController or another follower)
var follow_target: Node2D = null

## Visual components (optional)
var sprite: AnimatedSprite2D = null
var collision_shape: CollisionShape2D = null

## Current facing direction
var facing_direction: Vector2i = Vector2i.DOWN

## Raycast for diagonal shortcut validation
var _shortcut_ray: RayCast2D = null

## Reference to tilemap for collision checks
var _tile_map: TileMapLayer = null

## Cached grid position
var _grid_position: Vector2i = Vector2i.ZERO

## Position we're currently moving toward
var _current_target: Vector2 = Vector2.ZERO

## Whether we're actively moving
var _is_moving: bool = false


func _ready() -> void:
	# Get optional node references
	sprite = get_node_or_null("AnimatedSprite2D")
	collision_shape = get_node_or_null("CollisionShape2D")

	# Get TileMapLayer reference (sibling in map scenes)
	_tile_map = get_node_or_null("../TileMapLayer")

	# Create raycast for shortcut validation
	_shortcut_ray = RayCast2D.new()
	_shortcut_ray.enabled = false  # We'll use force_raycast_update() manually
	_shortcut_ray.collision_mask = 1  # Collide with physics layer 0
	_shortcut_ray.hit_from_inside = false
	add_child(_shortcut_ray)

	# Initialize grid position
	_grid_position = _world_to_grid(global_position)
	_current_target = global_position

	# Initialize position to match target if set
	if follow_target:
		_snap_to_formation_position()


func _physics_process(delta: float) -> void:
	if not follow_target:
		return

	# Get where we SHOULD be (target position in formation)
	var ideal_position: Vector2 = _calculate_ideal_position()
	var to_ideal: Vector2 = ideal_position - global_position
	var distance_to_ideal: float = to_ideal.length()

	# Only move if we're far enough from our ideal position
	if distance_to_ideal < min_distance_threshold:
		_is_moving = false
		return

	_is_moving = true

	# Determine how to move toward ideal position
	var move_direction: Vector2 = _calculate_best_move_direction(to_ideal)

	# Move toward target
	var move_amount: float = movement_speed * tile_size * delta

	# Don't overshoot
	if move_amount > distance_to_ideal:
		global_position = ideal_position
	else:
		global_position += move_direction * move_amount

	# Update facing direction
	_update_facing_direction(move_direction)

	# Update grid position
	_grid_position = _world_to_grid(global_position)


## Calculate where this follower should ideally be positioned.
## Uses the leader's position history but samples at tile boundaries.
func _calculate_ideal_position() -> Vector2:
	# Strategy: Get position from leader's history, but at a sparse interval
	# This gives us "where the leader was N tiles ago" rather than "N frames ago"

	if follow_target.has_method("get_historical_position"):
		# Sample at intervals based on follow_distance
		# Each follow_distance unit = ~6 frames of history at normal speed
		var history_index: int = follow_distance * 6
		return follow_target.get_historical_position(history_index)
	else:
		# Fallback: position directly behind leader based on their facing
		var leader_pos: Vector2 = follow_target.global_position
		var offset: Vector2 = Vector2(0, tile_size * follow_distance)  # Default behind

		if follow_target.has_method("get") and follow_target.get("facing_direction"):
			var leader_facing: Vector2i = follow_target.facing_direction
			offset = -Vector2(leader_facing) * tile_size * follow_distance

		return leader_pos + offset


## Determine the best movement direction, using diagonal shortcuts when valid.
func _calculate_best_move_direction(to_target: Vector2) -> Vector2:
	var normalized: Vector2 = to_target.normalized()

	# Check if diagonal movement makes sense and is valid
	if _should_use_diagonal(to_target) and _is_diagonal_path_clear(to_target):
		# Use diagonal - move directly toward target
		return normalized

	# Fall back to cardinal direction (strongest axis)
	return _get_cardinal_direction(to_target)


## Check if diagonal movement would be beneficial.
## Diagonal is good when both x and y components are significant.
func _should_use_diagonal(to_target: Vector2) -> bool:
	var abs_x: float = absf(to_target.x)
	var abs_y: float = absf(to_target.y)

	# Need both components to be meaningful
	if abs_x < tile_size * 0.3 or abs_y < tile_size * 0.3:
		return false

	# Both components should be somewhat balanced (not extremely skewed)
	var ratio: float = minf(abs_x, abs_y) / maxf(abs_x, abs_y)
	return ratio > 0.25  # At least 25% of the dominant direction


## Check if the diagonal path to target is clear of obstacles.
func _is_diagonal_path_clear(to_target: Vector2) -> bool:
	# First check: tilemap collision at intermediate positions
	if _tile_map:
		var target_grid: Vector2i = _world_to_grid(global_position + to_target)

		# Check the diagonal tile itself
		if not _is_tile_walkable(target_grid):
			return false

		# Check the two cardinal tiles that border the diagonal
		# (prevents cutting through wall corners)
		var current_grid: Vector2i = _grid_position
		var dx: int = signi(target_grid.x - current_grid.x)
		var dy: int = signi(target_grid.y - current_grid.y)

		if dx != 0 and dy != 0:
			# Moving diagonally - check both adjacent tiles
			var horiz_tile: Vector2i = Vector2i(current_grid.x + dx, current_grid.y)
			var vert_tile: Vector2i = Vector2i(current_grid.x, current_grid.y + dy)

			if not _is_tile_walkable(horiz_tile) or not _is_tile_walkable(vert_tile):
				return false

	# Second check: raycast for dynamic obstacles
	_shortcut_ray.global_position = global_position
	_shortcut_ray.target_position = to_target
	_shortcut_ray.force_raycast_update()

	return not _shortcut_ray.is_colliding()


## Get the cardinal direction (4-directional) that best matches the vector.
func _get_cardinal_direction(direction: Vector2) -> Vector2:
	if absf(direction.x) > absf(direction.y):
		return Vector2(signf(direction.x), 0)
	else:
		return Vector2(0, signf(direction.y))


## Check if a tile is walkable.
func _is_tile_walkable(tile_pos: Vector2i) -> bool:
	if not _tile_map:
		return true

	var tile_data: TileData = _tile_map.get_cell_tile_data(tile_pos)

	if tile_data == null:
		return true

	var has_collision: bool = tile_data.get_collision_polygons_count(0) > 0
	return not has_collision


## Update facing direction based on movement vector.
func _update_facing_direction(move_dir: Vector2) -> void:
	if move_dir.length() < 0.1:
		return

	# Determine primary direction (4-directional for sprites)
	if absf(move_dir.x) > absf(move_dir.y):
		if move_dir.x > 0:
			facing_direction = Vector2i.RIGHT
		else:
			facing_direction = Vector2i.LEFT
	else:
		if move_dir.y > 0:
			facing_direction = Vector2i.DOWN
		else:
			facing_direction = Vector2i.UP

	_update_sprite_animation()


## Update sprite based on facing direction.
func _update_sprite_animation() -> void:
	if not sprite:
		return
	# TODO: Play appropriate animation based on facing_direction
	pass


## Set the character to follow.
func set_follow_target(target: Node2D) -> void:
	follow_target = target

	if follow_target:
		_snap_to_formation_position()


## Snap immediately to formation position (for initialization/teleport).
func _snap_to_formation_position() -> void:
	if follow_target and follow_target.has_method("get_historical_position"):
		var history_index: int = follow_distance * 6
		global_position = follow_target.get_historical_position(history_index)
		_grid_position = _world_to_grid(global_position)
		_current_target = global_position


## Convert world position to grid coordinates.
func _world_to_grid(world_pos: Vector2) -> Vector2i:
	if _tile_map:
		return _tile_map.local_to_map(world_pos)
	else:
		return Vector2i(floori(world_pos.x / tile_size), floori(world_pos.y / tile_size))


## Convert grid coordinates to world position.
func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	if _tile_map:
		return _tile_map.map_to_local(grid_pos)
	else:
		return Vector2(grid_pos) * tile_size + Vector2(tile_size, tile_size) * 0.5


## Provide historical position for chained followers.
## This allows followers to follow other followers.
func get_historical_position(steps_back: int) -> Vector2:
	# For chained following, we use our current position
	# (followers behind us will use this)
	# The steps_back creates natural spacing in the chain
	if follow_target and follow_target.has_method("get_historical_position"):
		# Pass through to leader with additional offset
		return follow_target.get_historical_position(steps_back + follow_distance * 6)
	return global_position
