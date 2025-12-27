## CaravanFollower - Caravan wagon that follows the party on overworld maps
##
## SF2-AUTHENTIC BREADCRUMB TRAIL FOLLOWING:
## - Caravan walks the EXACT path the followed entity walked
## - Uses tile history from the follow target (last party member or hero)
## - Creates the classic trailing effect like party followers
##
## Unlike PartyFollower, the caravan:
## - Follows the LAST party member (or hero if no party)
## - Has an interaction area for player proximity detection
## - Uses caravan configuration resource for sprite, speed, distance
class_name CaravanFollower
extends CharacterBody2D

const FacingUtils: GDScript = preload("res://core/utils/facing_utils.gd")
const DEBUG_MODE: bool = false

# =============================================================================
# CONFIGURATION
# =============================================================================

@export var tile_size: int = 32

## How many tiles behind the follow target
@export var follow_distance: int = 3

## Pixels per second for smooth animation
@export var move_speed: float = 96.0

# =============================================================================
# RUNTIME STATE
# =============================================================================

## The entity we're following (last party follower or hero)
var _follow_target: Node2D = null

## The caravan configuration
## CaravanData configuration resource
var _config: Resource = null

## Grid position tracking
var grid_position: Vector2i = Vector2i.ZERO

## Movement state
var _target_grid: Vector2i = Vector2i.ZERO
var _target_world: Vector2 = Vector2.ZERO
var _is_moving: bool = false

## Reference to tilemap for grid conversion
var _tile_map: TileMapLayer = null

## The sprite displaying the wagon
var _sprite: Sprite2D = null

## Directional sprites (loaded if available)
var _direction_sprites: Dictionary = {}  # "down", "up", "left", "right" -> Texture2D

## Current facing direction
var _current_direction: String = "down"

## Interaction area for player proximity
var _interaction_area: Area2D = null

## Whether to track our own tile history (for future features)
var _tile_history: Array[Vector2i] = []
var _max_history_size: int = 20

func _ready() -> void:
	set_physics_process(false)  # Disabled until initialize() is called
	_tile_map = get_node_or_null("../TileMapLayer")
	_setup_sprite()
	_setup_interaction_area()


func _physics_process(delta: float) -> void:
	if not _is_moving:
		return

	# Smoothly animate toward target position
	var distance: float = global_position.distance_to(_target_world)

	if distance < 2.0:
		# Arrived at target
		global_position = _target_world
		_on_arrived_at_target()
		return

	# Move toward target
	var direction: Vector2 = (_target_world - global_position).normalized()
	var move_amount: float = move_speed * delta

	if move_amount >= distance:
		global_position = _target_world
		_on_arrived_at_target()
	else:
		global_position += direction * move_amount
		_update_sprite_direction(direction)


func _on_arrived_at_target() -> void:
	grid_position = _target_grid
	_is_moving = false
	_record_tile_in_history(_target_grid)


# =============================================================================
# INITIALIZATION
# =============================================================================

## Initialize the caravan follower with target and configuration
## @param target: Node2D to follow (last party follower or hero)
## @param distance: Number of tiles to trail behind
## @param config: CaravanData resource for appearance and behavior
func initialize(target: Node2D, distance: int, config: Resource = null) -> void:
	_follow_target = target
	follow_distance = distance
	_config = config

	if not _follow_target:
		push_error("CaravanFollower: Cannot initialize without follow target")
		return

	# Apply config settings if provided
	if _config:
		follow_distance = _config.follow_distance_tiles
		move_speed = _config.follow_speed
		_max_history_size = _config.max_history_size
		_apply_sprite_config()

	# Start at follow target's position (will spread out as they move)
	_target_grid = _world_to_grid(_follow_target.global_position)
	_target_world = _follow_target.global_position
	global_position = _target_world
	grid_position = _target_grid
	_is_moving = false

	# Connect to follow target's movement signal
	_connect_to_target()

	set_physics_process(true)

	if DEBUG_MODE:
		print("[Caravan] Initialized at target position %s (will trail by %d tiles)" % [
			grid_position, follow_distance
		])


func _connect_to_target() -> void:
	if not _follow_target:
		return

	# Try to connect to the target's movement signal
	# PartyFollower and HeroController both use "moved_to_tile"
	if _follow_target.has_signal("moved_to_tile"):
		var signal_obj: Signal = Signal(_follow_target, "moved_to_tile")
		if not signal_obj.is_connected(_on_target_moved):
			signal_obj.connect(_on_target_moved)

	# If following a PartyFollower, we need to track when IT moves
	# PartyFollower doesn't emit its own signal, so we check if it has a hero
	if _follow_target is PartyFollower:
		# The PartyFollower gets its movement from the hero, so we connect to hero
		var hero: Node2D = _find_hero()
		if hero and hero.has_signal("moved_to_tile"):
			var hero_signal: Signal = Signal(hero, "moved_to_tile")
			if not hero_signal.is_connected(_on_hero_moved_for_follower):
				hero_signal.connect(_on_hero_moved_for_follower)


func _find_hero() -> Node2D:
	var heroes: Array[Node] = get_tree().get_nodes_in_group("hero")
	if heroes.is_empty():
		return null
	var first_hero: Node = heroes[0]
	return first_hero if first_hero is Node2D else null


# =============================================================================
# MOVEMENT HANDLING
# =============================================================================

## Called when following the hero directly
func _on_target_moved(_target_tile: Vector2i) -> void:
	_update_movement_from_target()


## Called when following a PartyFollower (hero moved, so follower will move)
func _on_hero_moved_for_follower(_hero_tile: Vector2i) -> void:
	# Wait a frame for the PartyFollower to update its position
	await get_tree().process_frame
	_update_movement_from_target()


func _update_movement_from_target() -> void:
	if not _follow_target:
		return

	# Get historical position from target if it supports it
	var new_target: Vector2i = _get_target_historical_position()

	# Only move if target changed
	if new_target != _target_grid:
		_target_grid = new_target
		_target_world = _grid_to_world(_target_grid)
		_is_moving = true

		if DEBUG_MODE:
			print("[Caravan] Moving to tile %s" % _target_grid)


func _get_target_historical_position() -> Vector2i:
	# If target has historical tile method, use it
	if _follow_target.has_method("get_historical_tile"):
		return _follow_target.call("get_historical_tile", follow_distance) as Vector2i

	# If target is a PartyFollower with its own grid_position
	if "grid_position" in _follow_target:
		# For PartyFollower, we want to be [follow_distance] behind IT
		# But PartyFollower doesn't keep its own history, so we approximate
		# by using our own history or just staying behind current position
		return _follow_target.get("grid_position") as Vector2i

	# Fallback: use target's current world position
	return _world_to_grid(_follow_target.global_position)


func _record_tile_in_history(tile: Vector2i) -> void:
	# Don't record duplicate consecutive tiles
	if not _tile_history.is_empty() and _tile_history[0] == tile:
		return

	_tile_history.insert(0, tile)
	if _tile_history.size() > _max_history_size:
		_tile_history.resize(_max_history_size)


# =============================================================================
# SPRITE SETUP
# =============================================================================

func _setup_sprite() -> void:
	# Create sprite child if it doesn't exist
	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if not _sprite:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite2D"
		add_child(_sprite)

	# Apply placeholder texture initially (will be replaced by config)
	_apply_placeholder_sprite()


func _apply_placeholder_sprite() -> void:
	if not _sprite:
		return

	# Create a simple colored rectangle as placeholder
	var img: Image = Image.create(32, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.6, 0.4, 0.2))  # Brown for wagon

	# Add some detail - lighter roof
	for x: int in range(4, 28):
		for y: int in range(2, 8):
			img.set_pixel(x, y, Color(0.8, 0.6, 0.4))

	# Add wheels
	for x: int in range(6, 10):
		for y: int in range(18, 22):
			img.set_pixel(x, y, Color(0.3, 0.2, 0.1))
	for x: int in range(22, 26):
		for y: int in range(18, 22):
			img.set_pixel(x, y, Color(0.3, 0.2, 0.1))

	var texture: ImageTexture = ImageTexture.create_from_image(img)
	_sprite.texture = texture
	_sprite.centered = true


func _apply_sprite_config() -> void:
	if not _sprite or not _config:
		return

	# Try to load directional sprites
	_load_directional_sprites()

	# Apply main sprite if no directional sprites or as fallback
	if _config.wagon_sprite and _direction_sprites.is_empty():
		_sprite.texture = _config.wagon_sprite
	elif not _direction_sprites.is_empty():
		# Start with down-facing sprite
		_set_sprite_direction("down")

	_sprite.scale = _config.wagon_scale
	z_index = _config.z_index_offset


func _load_directional_sprites() -> void:
	_direction_sprites.clear()

	if not _config:
		return

	# Try to find directional sprites based on wagon_sprite path
	# If wagon_sprite is "sprites/caravan_wagon.png", look for:
	#   "sprites/caravan/wagon_down.png", etc.
	var base_path: String = ""

	if _config.wagon_sprite:
		base_path = _config.wagon_sprite.resource_path.get_base_dir()
	else:
		# Default path for base game
		base_path = "res://mods/_base_game/assets/sprites"

	# Look for directional sprites in caravan subdirectory
	var caravan_dir: String = base_path.path_join("caravan")
	var directions: Array[String] = ["down", "up", "left", "right"]

	for dir: String in directions:
		var sprite_path: String = caravan_dir.path_join("wagon_%s.png" % dir)
		if ResourceLoader.exists(sprite_path):
			var loaded: Resource = load(sprite_path)
			var texture: Texture2D = loaded if loaded is Texture2D else null
			if texture:
				_direction_sprites[dir] = texture
				if DEBUG_MODE:
					print("[Caravan] Loaded directional sprite: %s" % sprite_path)

	if DEBUG_MODE and not _direction_sprites.is_empty():
		print("[Caravan] Loaded %d directional wagon sprites" % _direction_sprites.size())


func _set_sprite_direction(direction: String) -> void:
	if not _sprite:
		return

	if direction in _direction_sprites:
		_sprite.texture = _direction_sprites[direction]
		_sprite.flip_h = false  # Reset flip since we have proper directional sprites
		_current_direction = direction
	elif _config and _config.wagon_sprite:
		# Fallback to main sprite with flip for horizontal
		_sprite.texture = _config.wagon_sprite
		_sprite.flip_h = (direction == "left")


func _update_sprite_direction(direction: Vector2) -> void:
	if not _sprite:
		return

	# Skip if movement is negligible (threshold to prevent flicker)
	if direction.is_zero_approx():
		return

	# Determine primary direction from movement vector
	var new_direction: String = FacingUtils.get_dominant_direction_float(direction)

	# Only update if direction changed
	if new_direction != _current_direction:
		if not _direction_sprites.is_empty():
			_set_sprite_direction(new_direction)
		else:
			# Fallback: simple horizontal flip
			_current_direction = new_direction
			if new_direction in ["left", "right"]:
				_sprite.flip_h = (new_direction == "left")


# =============================================================================
# INTERACTION AREA
# =============================================================================

func _setup_interaction_area() -> void:
	# Create interaction area for player proximity detection
	_interaction_area = get_node_or_null("InteractionArea") as Area2D
	if not _interaction_area:
		_interaction_area = Area2D.new()
		_interaction_area.name = "InteractionArea"
		_interaction_area.collision_layer = 0
		_interaction_area.collision_mask = 1  # Detect player (layer 1)
		add_child(_interaction_area)

		# Create collision shape (1.5 tile radius)
		var shape: CollisionShape2D = CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = tile_size * 1.5
		shape.shape = circle
		_interaction_area.add_child(shape)

	# Signals are connected by CaravanController


# =============================================================================
# PUBLIC API
# =============================================================================

## Get current grid position
func get_grid_position() -> Vector2i:
	return grid_position


## Set grid position (for restoring from save)
func set_grid_position(pos: Vector2i) -> void:
	grid_position = pos
	_target_grid = pos
	_target_world = _grid_to_world(pos)
	global_position = _target_world
	_is_moving = false


## Reposition to follow target (after teleport, battle return, etc.)
func reposition_to_target() -> void:
	if not _follow_target:
		return

	_target_grid = _world_to_grid(_follow_target.global_position)
	_target_world = _follow_target.global_position
	global_position = _target_world
	grid_position = _target_grid
	_is_moving = false

	if DEBUG_MODE:
		print("[Caravan] Repositioned to target position %s" % grid_position)


## Get historical tile position (for other entities to follow caravan)
func get_historical_tile(index: int) -> Vector2i:
	if index <= 0 or _tile_history.is_empty():
		return grid_position
	if index >= _tile_history.size():
		return _tile_history[_tile_history.size() - 1]
	return _tile_history[index - 1]


## Check if caravan is currently moving
func is_moving() -> bool:
	return _is_moving


# =============================================================================
# COORDINATE CONVERSION
# =============================================================================

func _world_to_grid(world_pos: Vector2) -> Vector2i:
	if _tile_map:
		return _tile_map.local_to_map(world_pos)
	return Vector2i(floori(world_pos.x / tile_size), floori(world_pos.y / tile_size))


func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	if _tile_map:
		return _tile_map.map_to_local(grid_pos)
	return Vector2(grid_pos) * tile_size + Vector2(tile_size, tile_size) * 0.5
