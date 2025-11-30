## PartyFollower - Party member that follows the hero on the map
##
## SF2-style CHAIN FOLLOWING:
## - Follower 1 follows Hero
## - Follower 2 follows Follower 1
## - Follower 3 follows Follower 2
## - Each follower maintains its own tile_history for the next follower to use
## - TIGHT spacing (~0.6 tiles) for cohesive squad feel
## - CASCADE DELAY creates ripple effect (each follower moves slightly after the previous)
class_name PartyFollower
extends CharacterBody2D

## Debug mode - set to true for verbose logging
const DEBUG_MODE: bool = false

@export var tile_size: int = 32
@export var formation_index: int = 1  ## Position in party (1 = directly behind hero)
@export var base_speed: float = 4.5  ## Slightly faster to catch up

## Spacing and timing configuration
## SF2-AUTHENTIC: All followers read from HERO's history at different depths
const TILES_PER_FOLLOWER: int = 1  ## Spacing between followers (1 = tight, 2 = loose)
const CASCADE_DELAY_MS: float = 80.0  ## Milliseconds delay per follower in chain
const MIN_DISTANCE_FROM_HERO: float = 24.0  ## Never get closer than this to hero (pixels)

## Reference to the hero (for all followers to check min distance)
var _hero_ref: Node2D = null

## The entity we're following (hero or previous follower)
var follow_target: Node2D = null

## Cascade delay tracking
var _cascade_timer: float = 0.0
var _movement_unlocked: bool = true  ## False during cascade delay
var _leader_was_moving: bool = false  ## Track leader's movement state for cascade trigger

## Our own tile history - so the NEXT follower can follow US
var tile_history: Array[Vector2i] = []
const TILE_HISTORY_SIZE: int = 32

## Current target tile (from follow_target's tile_history)
var target_tile: Vector2i = Vector2i.ZERO
var target_world_pos: Vector2 = Vector2.ZERO

## Grid position tracking
var grid_position: Vector2i = Vector2i.ZERO
var is_moving: bool = false

## Visual components (optional)
var sprite: AnimatedSprite2D = null
var collision_shape: CollisionShape2D = null

## Current facing direction
var facing_direction: Vector2i = Vector2i.DOWN

## Reference to tilemap for collision checks
var _tile_map: TileMapLayer = null


func _ready() -> void:
	sprite = get_node_or_null("AnimatedSprite2D")
	collision_shape = get_node_or_null("CollisionShape2D")
	_tile_map = get_node_or_null("../TileMapLayer")
	grid_position = _world_to_grid(global_position)

	# Hero reference will be found after follow_target is set

	# Initialize our tile history with current position
	tile_history.clear()
	for i in range(TILE_HISTORY_SIZE):
		tile_history.append(grid_position)

	if DEBUG_MODE:
		print("[Follower %d] Ready at grid %s" % [formation_index, grid_position])


## Find the hero by tracing up the follow_target chain.
func _find_hero() -> Node2D:
	# If we're following someone, trace up the chain to find the hero
	var current: Node2D = follow_target
	var max_depth: int = 10  # Safety limit

	while current and max_depth > 0:
		# If current doesn't have follow_target, it's the hero (end of chain)
		if not ("follow_target" in current) or current.get("follow_target") == null:
			return current
		current = current.get("follow_target")
		max_depth -= 1

	# Fallback: search parent for node named Hero
	var parent: Node = get_parent()
	if parent:
		for child in parent.get_children():
			if child.name == "Hero" or "hero" in child.name.to_lower():
				if child != self:
					return child

	return null


func _physics_process(delta: float) -> void:
	if not follow_target:
		return

	# Check if leader just started moving - trigger cascade delay
	var leader_moving_now: bool = _is_leader_moving()
	if leader_moving_now and not _leader_was_moving:
		# Leader just started moving - start our cascade delay
		start_cascade_delay()
	_leader_was_moving = leader_moving_now

	# Handle cascade delay - creates ripple effect
	if not _movement_unlocked:
		_cascade_timer -= delta * 1000.0  # Convert to ms
		if _cascade_timer <= 0:
			_movement_unlocked = true
		else:
			return  # Still waiting for cascade delay

	# Get target position from leader's tile history
	_update_target_from_leader()

	# Calculate distance to target
	var to_target: Vector2 = target_world_pos - global_position
	var distance_to_target: float = to_target.length()

	# Already at target? Don't move
	if distance_to_target < 2.0:
		is_moving = false
		_check_grid_position_change()
		return

	# HERO DISTANCE CHECK: Never move closer than MIN_DISTANCE_FROM_HERO to the hero
	if _hero_ref:
		var hero_pos: Vector2 = _hero_ref.global_position
		var current_dist_to_hero: float = global_position.distance_to(hero_pos)
		var target_dist_to_hero: float = target_world_pos.distance_to(hero_pos)

		# If target would put us too close to hero, stay put
		if target_dist_to_hero < MIN_DISTANCE_FROM_HERO:
			is_moving = false
			_check_grid_position_change()
			return

		# If we're already close to hero and target is even closer, stay put
		if current_dist_to_hero < MIN_DISTANCE_FROM_HERO * 1.5 and target_dist_to_hero < current_dist_to_hero:
			is_moving = false
			_check_grid_position_change()
			return

	# Move toward target
	is_moving = true
	var move_direction: Vector2 = to_target.normalized()
	var move_amount: float = base_speed * tile_size * delta

	if move_amount >= distance_to_target:
		global_position = target_world_pos
	else:
		global_position += move_direction * move_amount

	# Check if we crossed into a new tile
	_check_grid_position_change()

	# Debug: Log position every time we complete a tile move
	if DEBUG_MODE and grid_position != target_tile:
		var hero_grid: Vector2i = _world_to_grid(_hero_ref.global_position) if _hero_ref else Vector2i(-99, -99)
		var leader_grid: Vector2i = _world_to_grid(follow_target.global_position) if follow_target else Vector2i(-99, -99)
		print("[F%d] pos=%s target=%s leader=%s hero=%s" % [formation_index, grid_position, target_tile, leader_grid, hero_grid])

	# Update facing direction
	_update_facing_direction(move_direction)


## Check if we've moved to a new grid tile and update our history.
## This allows the NEXT follower in the chain to follow us properly.
func _check_grid_position_change() -> void:
	var new_grid: Vector2i = _world_to_grid(global_position)
	if new_grid != grid_position:
		_update_own_tile_history(new_grid)
		grid_position = new_grid


## Update target position from HERO's tile history.
## SF2-AUTHENTIC: ALL followers read from hero's history at different depths.
## formation_index 1 -> history[1], formation_index 2 -> history[2], etc.
func _update_target_from_leader() -> void:
	if not _hero_ref:
		return

	# Calculate history depth based on formation position
	# Each follower is N tiles behind in the hero's path
	var history_depth: int = formation_index * TILES_PER_FOLLOWER

	# ALL followers read from HERO's tile history (centralized approach)
	if _hero_ref.has_method("get_historical_tile"):
		var historical_tile: Vector2i = _hero_ref.get_historical_tile(history_depth)
		target_tile = historical_tile
		target_world_pos = _grid_to_world(historical_tile)
	else:
		# Fallback: position behind hero based on their movement
		var hero_pos: Vector2 = _hero_ref.global_position
		var to_hero: Vector2 = hero_pos - global_position
		if to_hero.length() > tile_size * formation_index:
			target_world_pos = hero_pos - to_hero.normalized() * tile_size * formation_index
		else:
			target_world_pos = global_position
		target_tile = _world_to_grid(target_world_pos)


## Update our own tile history when we complete a tile move.
## This allows the NEXT follower to follow US.
func _update_own_tile_history(new_tile: Vector2i) -> void:
	tile_history.push_front(new_tile)

	if tile_history.size() > TILE_HISTORY_SIZE:
		tile_history.pop_back()

	if DEBUG_MODE:
		print("[Follower %d] Moved to tile %s" % [formation_index, new_tile])


## Start cascade delay - called when leader starts moving.
## Creates the ripple effect where each follower starts moving slightly after the previous.
func start_cascade_delay() -> void:
	_cascade_timer = CASCADE_DELAY_MS
	_movement_unlocked = false


## Check if the HERO is currently moving (centralized approach).
func _is_leader_moving() -> bool:
	if not _hero_ref:
		return false

	# Check for is_moving property on hero
	if "is_moving" in _hero_ref:
		return _hero_ref.is_moving

	# Fallback: check velocity
	if "velocity" in _hero_ref:
		return _hero_ref.velocity.length() > 0.1

	return false


## Get a tile from our history (for the next follower to use).
func get_historical_tile(tiles_back: int) -> Vector2i:
	tiles_back = clampi(tiles_back, 0, tile_history.size() - 1)
	return tile_history[tiles_back]


## Update facing direction based on movement.
func _update_facing_direction(move_dir: Vector2) -> void:
	if move_dir.length() < 0.1:
		return

	if absf(move_dir.x) > absf(move_dir.y):
		facing_direction = Vector2i.RIGHT if move_dir.x > 0 else Vector2i.LEFT
	else:
		facing_direction = Vector2i.DOWN if move_dir.y > 0 else Vector2i.UP


## Set the entity to follow (hero or previous follower).
## SF2-AUTHENTIC: Spawns at staggered position based on formation_index.
func set_follow_target(target: Node2D) -> void:
	follow_target = target

	if follow_target:
		# Find hero reference - ALL followers use hero's history
		_hero_ref = _find_hero()

		if _hero_ref:
			# Calculate spawn position from hero's pre-seeded history
			var history_depth: int = formation_index * TILES_PER_FOLLOWER
			var spawn_tile: Vector2i = _hero_ref.get_historical_tile(history_depth)

			# Set our position to spawn location
			grid_position = spawn_tile
			global_position = _grid_to_world(spawn_tile)

			# Set target to current position (don't move until hero moves)
			target_tile = spawn_tile
			target_world_pos = global_position

			# Fill our history with spawn position
			tile_history.clear()
			for i in range(TILE_HISTORY_SIZE):
				tile_history.append(grid_position)

			if DEBUG_MODE:
				print("[Follower %d] Now following %s, hero ref: %s, spawned at tile %s (hero history[%d])" % [
					formation_index,
					follow_target.name,
					_hero_ref.name if _hero_ref else "none",
					grid_position,
					history_depth
				])
		else:
			# Fallback if no hero found - stay at current position
			if DEBUG_MODE:
				print("[Follower %d] WARNING: No hero ref found, staying at %s" % [formation_index, grid_position])


## Convert world position to grid coordinates.
func _world_to_grid(world_pos: Vector2) -> Vector2i:
	if _tile_map:
		return _tile_map.local_to_map(world_pos)
	return Vector2i(floori(world_pos.x / tile_size), floori(world_pos.y / tile_size))


## Convert grid to world position (tile center).
func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	if _tile_map:
		return _tile_map.map_to_local(grid_pos)
	return Vector2(grid_pos) * tile_size + Vector2(tile_size, tile_size) * 0.5
