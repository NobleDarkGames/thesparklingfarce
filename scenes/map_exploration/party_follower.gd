## PartyFollower - Party member that follows the hero on the map
##
## SF2-AUTHENTIC BREADCRUMB TRAIL FOLLOWING:
## - Each follower walks the EXACT path the hero walked
## - Follower N goes to where hero was N tiles ago (tile_history[N])
## - Movement is smooth animation, decisions are tile-discrete
## - Creates the classic "snake game" / "caterpillar" effect
class_name PartyFollower
extends CharacterBody2D

const DEBUG_MODE: bool = false

@export var tile_size: int = 32
@export var formation_index: int = 1  ## Position in trail (1 = 1 tile behind hero, 2 = 2 tiles behind, etc.)
@export var move_speed: float = 128.0  ## Pixels per second for smooth animation

## The hero we're following
var _hero: Node2D = null

## Grid position tracking
var grid_position: Vector2i = Vector2i.ZERO

## Movement state
var _target_grid: Vector2i = Vector2i.ZERO
var _target_world: Vector2 = Vector2.ZERO
var _is_moving: bool = false

## Reference to tilemap for grid conversion
var _tile_map: TileMapLayer = null


func _ready() -> void:
	set_physics_process(false)  # Disabled until initialize() is called
	_tile_map = get_node_or_null("../TileMapLayer")


func _physics_process(delta: float) -> void:
	if not _is_moving:
		return

	# Smoothly animate toward target position
	var distance: float = global_position.distance_to(_target_world)

	if distance < 2.0:
		# Arrived at target
		global_position = _target_world
		grid_position = _target_grid
		_is_moving = false
		return

	# Move toward target
	var direction: Vector2 = (_target_world - global_position).normalized()
	var move_amount: float = move_speed * delta

	if move_amount >= distance:
		global_position = _target_world
		grid_position = _target_grid
		_is_moving = false
	else:
		global_position += direction * move_amount


## Initialize this follower with hero reference.
## SF2-AUTHENTIC: Spawn at hero's position (stacked), fan out as hero moves.
func initialize(hero: Node2D, index: int) -> void:
	_hero = hero
	formation_index = index

	if not _hero:
		push_error("PartyFollower: Cannot initialize without hero reference")
		return

	# SF2-AUTHENTIC: Spawn at hero's exact position (stacked below via z-index)
	# The breadcrumb trail will naturally spread followers as hero moves
	_target_grid = _world_to_grid(_hero.global_position)
	_target_world = _hero.global_position
	global_position = _target_world
	grid_position = _target_grid
	_is_moving = false

	# Connect to hero's movement signal for trail following
	if _hero.has_signal("moved_to_tile"):
		if not _hero.moved_to_tile.is_connected(_on_hero_moved):
			_hero.moved_to_tile.connect(_on_hero_moved)

	set_physics_process(true)

	if DEBUG_MODE:
		print("[Follower %d] Initialized at hero position %s (will fan out on move)" % [formation_index, grid_position])


## Called when hero completes a tile move - update our target from trail history.
func _on_hero_moved(_hero_tile: Vector2i) -> void:
	if not _hero or not _hero.has_method("get_historical_tile"):
		return

	# SF2-AUTHENTIC: Go to where hero was [formation_index] tiles ago
	var new_target: Vector2i = _hero.get_historical_tile(formation_index)

	# Only move if target changed
	if new_target != _target_grid:
		_target_grid = new_target
		_target_world = _grid_to_world(_target_grid)
		_is_moving = true

		if DEBUG_MODE:
			print("[Follower %d] Moving to tile %s (hero history[%d])" % [
				formation_index, _target_grid, formation_index
			])


## Reposition follower after teleport/battle return.
## SF2-AUTHENTIC: Regroup at hero position, fan out as hero moves.
func reposition_to_hero() -> void:
	if not _hero:
		return

	# SF2-AUTHENTIC: Regroup at hero's position (like initial spawn)
	_target_grid = _world_to_grid(_hero.global_position)
	_target_world = _hero.global_position
	global_position = _target_world
	grid_position = _target_grid
	_is_moving = false

	if DEBUG_MODE:
		print("[Follower %d] Repositioned to hero position %s" % [formation_index, grid_position])


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
