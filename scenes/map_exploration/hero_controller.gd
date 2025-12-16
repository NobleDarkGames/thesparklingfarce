## HeroController - Player character controller for map exploration
##
## Handles grid-based movement on the overworld map with smooth interpolation.
## Maintains position history for party followers to use.
class_name HeroController
extends CharacterBody2D

const FacingUtils: GDScript = preload("res://core/utils/facing_utils.gd")

## Debug mode - set to true for verbose logging
const DEBUG_MODE: bool = false

## Preload CinematicActor for hero control during cinematics
const CinematicActorScript: GDScript = preload("res://core/components/cinematic_actor.gd")

## Emitted when hero completes movement to a new tile
signal moved_to_tile(tile_position: Vector2i)

## Emitted when hero interacts with something (A button)
signal interaction_requested(interaction_position: Vector2i)

@export var tile_size: int = 32  ## SF-authentic: unified 32px tiles for all modes
@export var movement_speed: float = 4.0  ## tiles per second
@export var position_history_size: int = 20  ## Number of positions to track for followers

## Reference to ExplorationUIController for input blocking
## Set by exploration scene after instantiation
var ui_controller: Node = null

## Current facing direction (for sprites and interactions)
## Uses string format ("up", "down", "left", "right") for consistency with Unit.gd
var facing_direction: String = "down"

## Grid position tracking
var grid_position: Vector2i = Vector2i.ZERO
var target_position: Vector2 = Vector2.ZERO
var is_moving: bool = false

## Position history for followers (world positions, not grid) - LEGACY, updated every frame
var position_history: Array[Vector2] = []

## Tile history for followers - ONLY updated on tile completion (SF2-style)
## This is the array followers should use for path memory
var tile_history: Array[Vector2i] = []
const TILE_HISTORY_SIZE: int = 32

## References (optional - may not exist in all setups)
var sprite: AnimatedSprite2D = null
var collision_shape: CollisionShape2D = null
var interaction_ray: RayCast2D = null
var tile_map: TileMapLayer = null

## CinematicActor child for cutscene control
## Allows cinematics to move and animate the hero during cutscenes
var cinematic_actor: Node = null

## Dedicated audio player for looping walk sound
var _walk_audio_player: AudioStreamPlayer = null

## Diagnostic: log once if falling back to modal checks (helps debug intermittent movement bugs)
var _logged_fallback_warning: bool = false


func _ready() -> void:
	# Add to "hero" group for trigger detection
	add_to_group("hero")

	# Get optional node references
	# AnimatedSprite2D may be direct child or inside Visual container
	sprite = get_node_or_null("AnimatedSprite2D")
	if not sprite:
		sprite = get_node_or_null("Visual/AnimatedSprite2D")
	collision_shape = get_node_or_null("CollisionShape2D")
	interaction_ray = get_node_or_null("InteractionRay")

	# Create CinematicActor child for cutscene control
	# This allows cinematics to control the hero's movement and animation
	_create_cinematic_actor()

	# Get TileMapLayer reference (sibling node in map scenes)
	tile_map = get_node_or_null("../TileMapLayer")
	if not tile_map:
		push_warning("HeroController: No TileMapLayer found - collision detection disabled")

	# Initialize position - use 'position' not 'global_position' as transforms
	# may not be fully computed yet during _ready()
	var initial_pos: Vector2 = position if position != Vector2.ZERO else global_position
	grid_position = world_to_grid(initial_pos)
	target_position = grid_to_world(grid_position)  # Snap to grid center
	position = target_position  # Snap to grid center using local position

	if DEBUG_MODE:
		print("[HeroController] Init - tile_size: %d" % tile_size)
		print("[HeroController] Init - initial position (from .tscn): %s" % initial_pos)
		print("[HeroController] Init - grid_position: %s" % grid_position)
		print("[HeroController] Init - target_position: %s" % target_position)

	# Initialize position history with current position
	position_history.clear()
	for i: int in range(position_history_size):
		position_history.append(target_position)

	# Initialize tile history with current grid position (SF2-style)
	tile_history.clear()
	for i: int in range(TILE_HISTORY_SIZE):
		tile_history.append(grid_position)
	if DEBUG_MODE:
		print("[HeroController] Tile history initialized with %d entries at %s" % [TILE_HISTORY_SIZE, grid_position])

	# Setup interaction raycast
	if interaction_ray:
		interaction_ray.enabled = true
		interaction_ray.target_position = Vector2(tile_size, 0)  # Default to right

	# Create dedicated walk audio player (loops seamlessly while moving)
	_walk_audio_player = AudioStreamPlayer.new()
	_walk_audio_player.bus = "SFX"
	add_child(_walk_audio_player)
	_load_walk_sound()

	# Start with idle animation facing current direction
	_play_idle_animation()


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

		# Update tile history (SF2-style - only on tile completion!)
		_update_tile_history(grid_position)

		# Emit signal
		moved_to_tile.emit(grid_position)

		# Check for triggers at new position
		_check_tile_triggers()

		# Stop walk sound and play idle if no direction input held (seamless if continuing to move)
		if not _is_direction_input_held():
			_stop_walk_sound()
			_play_idle_animation()
	else:
		# Move toward target
		var direction_vec: Vector2 = (target_position - global_position).normalized()
		var move_distance: float = movement_speed * tile_size * delta
		global_position += direction_vec * move_distance


## Handle directional input for movement.
func _process_input() -> void:
	# Block input if UI menus are open
	if ui_controller:
		if ui_controller.is_blocking_input():
			return
	else:
		# Fallback checks ONLY if ui_controller isn't set (defensive programming)
		# Log once if we're in fallback mode - helps diagnose intermittent movement bugs
		if not _logged_fallback_warning:
			_logged_fallback_warning = true
			push_warning("[HeroController] ui_controller is null - using fallback modal checks")
		if _is_modal_ui_active():
			return

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

	# Block input if UI menus are open
	if ui_controller:
		if ui_controller.is_blocking_input():
			return
	else:
		# Fallback checks ONLY if ui_controller isn't set (defensive programming)
		if _is_modal_ui_active():
			return

	# Interaction key (confirm)
	if event.is_action_pressed("sf_confirm"):
		_try_interact()

	# Cancel key opens field menu directly (SF2 authentic)
	# Only when in exploration mode with no UI active
	elif event.is_action_pressed("sf_cancel"):
		_try_open_field_menu()


## Attempt to move in the given direction.
## Returns true if movement was initiated, false if blocked.
func attempt_move(direction: Vector2i) -> bool:
	if is_moving:
		return false

	# Always update facing direction, even if blocked (SF-authentic)
	facing_direction = FacingUtils.direction_to_string(direction)
	_update_interaction_ray()
	_update_sprite_animation()

	# Calculate target grid position
	var target_grid: Vector2i = grid_position + direction

	# Check if target is walkable
	if not _is_tile_walkable(target_grid):
		return false

	# Start movement
	target_position = grid_to_world(target_grid)
	is_moving = true

	# Start looping walk sound (if not already playing)
	_start_walk_sound()

	return true


## Check if a tile is walkable using TileMap collision data and NPC occupancy.
## Tiles with physics collision are considered impassable (walls, water, etc.)
## Tiles without physics collision are walkable (grass, roads, etc.)
## Tiles occupied by NPCs are also impassable (SF-authentic behavior).
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

	if has_collision:
		return false

	# Check if an NPC occupies this tile (SF-authentic: can't walk through NPCs)
	if _is_npc_at_tile(tile_pos):
		return false

	return true


## Check if any NPC occupies the given tile position.
func _is_npc_at_tile(tile_pos: Vector2i) -> bool:
	var npcs: Array[Node] = get_tree().get_nodes_in_group("npcs")
	for npc: Node in npcs:
		if npc.has_method("is_at_grid_position"):
			if npc.is_at_grid_position(tile_pos):
				return true
	return false


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
	var dir_vec: Vector2i = FacingUtils.string_to_direction(facing_direction)
	var interaction_pos: Vector2i = grid_position + dir_vec
	interaction_requested.emit(interaction_pos)


## Try to open the field menu (SF2-authentic: cancel button opens field menu)
func _try_open_field_menu() -> void:
	if not ui_controller:
		if DEBUG_MODE:
			print("[HeroController] Cannot open field menu - no ui_controller")
		return

	if not ui_controller.has_method("open_field_menu"):
		if DEBUG_MODE:
			print("[HeroController] ui_controller does not have open_field_menu method")
		return

	# Get screen position for menu positioning
	var screen_pos: Vector2 = get_global_transform_with_canvas().origin

	# Open field menu at hero's current position
	ui_controller.open_field_menu(grid_position, screen_pos)
	if DEBUG_MODE:
		print("[HeroController] Opened field menu via sf_cancel at %s" % grid_position)


## Update the interaction raycast to face the current direction.
func _update_interaction_ray() -> void:
	if not interaction_ray:
		return

	var dir_vec: Vector2i = FacingUtils.string_to_direction(facing_direction)
	interaction_ray.target_position = Vector2(dir_vec) * tile_size


## Update sprite animation based on current facing direction.
func _update_sprite_animation() -> void:
	if not sprite:
		return

	var anim_name: String = "walk_" + facing_direction

	# Only change animation if it exists and is different
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)


## Play walk animation for current facing direction (SF2-authentic: walk plays even when stationary).
func _play_idle_animation() -> void:
	if not sprite:
		return

	# SF2-authentic: walk animation loops continuously, even when "idle"
	var anim_name: String = "walk_" + facing_direction

	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)


## Add current position to history for followers.
func _update_position_history() -> void:
	# Add current position to front
	position_history.push_front(global_position)

	# Remove oldest position if we exceed the limit
	if position_history.size() > position_history_size:
		position_history.pop_back()


## Update tile history when hero completes a tile move (SF2-style).
## This is called ONLY on tile completion, not every frame.
func _update_tile_history(new_tile: Vector2i) -> void:
	# Add new tile to front of history
	tile_history.push_front(new_tile)

	# Trim to max size
	if tile_history.size() > TILE_HISTORY_SIZE:
		tile_history.pop_back()

	if DEBUG_MODE:
		print("[HeroController] Tile history updated: moved to %s (history size: %d)" % [new_tile, tile_history.size()])


## Initialize tile history with a formation trail extending BEHIND the hero.
## SF2-AUTHENTIC: This gives followers somewhere to spawn that isn't on the hero.
## Call this after the hero is positioned but BEFORE followers are created.
func initialize_formation_history() -> void:
	tile_history.clear()

	# Determine the "behind" direction (opposite of facing)
	var facing_vec: Vector2i = FacingUtils.string_to_direction(facing_direction)
	var behind_direction: Vector2i = -facing_vec

	# Pre-seed history with tiles extending behind the hero
	# history[0] = hero position, history[1] = 1 tile behind, etc.
	for i: int in range(TILE_HISTORY_SIZE):
		var offset_tile: Vector2i = grid_position + (behind_direction * i)
		tile_history.append(offset_tile)

	if DEBUG_MODE:
		print("[HeroController] Formation history initialized: %d tiles behind %s (direction: %s)" % [
			TILE_HISTORY_SIZE, grid_position, behind_direction
		])


## Get a position from the hero's movement history.
## steps_back: How many steps back in history to look (0 = current position)
func get_historical_position(steps_back: int) -> Vector2:
	steps_back = clampi(steps_back, 0, position_history.size() - 1)
	return position_history[steps_back]


## Get a tile from the hero's tile history (SF2-style).
## tiles_back: How many tiles back in history (0 = current tile, 1 = previous tile, etc.)
func get_historical_tile(tiles_back: int) -> Vector2i:
	tiles_back = clampi(tiles_back, 0, tile_history.size() - 1)
	return tile_history[tiles_back]


## Convert world position to grid coordinates.
func world_to_grid(world_pos: Vector2) -> Vector2i:
	# Use TileMapLayer's built-in method if available AND it has a tile_set
	if tile_map and tile_map.tile_set:
		return tile_map.local_to_map(world_pos)
	else:
		# Fallback for testing without tilemap
		return Vector2i(floori(world_pos.x / tile_size), floori(world_pos.y / tile_size))


## Convert grid coordinates to world position (centered on tile).
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	# Use TileMapLayer's built-in method if available AND it has a tile_set
	if tile_map and tile_map.tile_set:
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
	for i: int in range(position_history_size):
		position_history.append(global_position)

	# Clear tile history and fill with new tile (SF2-style)
	tile_history.clear()
	for i: int in range(TILE_HISTORY_SIZE):
		tile_history.append(grid_position)
	if DEBUG_MODE:
		print("[HeroController] Teleported to %s - tile history reset" % grid_position)


## Create a CinematicActor child for cutscene control.
## This allows the CinematicsManager to control the hero during cinematics.
## The hero is registered with actor_id "hero" for use in cinematic scripts.
func _create_cinematic_actor() -> void:
	# Check if already created (in case _ready is called multiple times)
	if cinematic_actor:
		return

	cinematic_actor = Node.new()
	cinematic_actor.set_script(CinematicActorScript)
	cinematic_actor.name = "CinematicActor"
	cinematic_actor.set("actor_id", "hero")

	# CinematicActor auto-registers with CinematicsManager in its _ready()
	add_child(cinematic_actor)

	if DEBUG_MODE:
		print("[HeroController] CinematicActor created with actor_id 'hero'")


## Load walk sound from active mod's audio/sfx/ folder
func _load_walk_sound() -> void:
	if not _walk_audio_player:
		return

	# Try common audio formats (same logic as AudioManager)
	var extensions: Array[String] = ["ogg", "wav", "mp3"]
	var mod_path: String = AudioManager.current_mod_path

	for ext in extensions:
		var audio_path: String = "%s/audio/sfx/walk.%s" % [mod_path, ext]
		if ResourceLoader.exists(audio_path):
			var stream: AudioStream = load(audio_path)
			if stream:
				# Enable looping on the stream if it's an OggVorbis
				if stream is AudioStreamOggVorbis:
					(stream as AudioStreamOggVorbis).loop = true
				elif stream is AudioStreamWAV:
					(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
				_walk_audio_player.stream = stream
				_walk_audio_player.volume_db = linear_to_db(AudioManager.sfx_volume)
				return


## Start the looping walk sound (if not already playing)
func _start_walk_sound() -> void:
	if _walk_audio_player and _walk_audio_player.stream and not _walk_audio_player.playing:
		_walk_audio_player.play()


## Stop the walk sound
func _stop_walk_sound() -> void:
	if _walk_audio_player and _walk_audio_player.playing:
		_walk_audio_player.stop()


## Check if any direction input is currently held
func _is_direction_input_held() -> bool:
	return (Input.is_action_pressed("ui_up") or
			Input.is_action_pressed("ui_down") or
			Input.is_action_pressed("ui_left") or
			Input.is_action_pressed("ui_right"))


## Check if any modal UI is active (fallback when ui_controller isn't available)
## This provides defense-in-depth for input blocking
func _is_modal_ui_active() -> bool:
	# Check debug console
	if DebugConsole and DebugConsole.is_open:
		return true
	# Check shop
	if ShopManager and ShopManager.is_shop_open():
		return true
	# Check dialog
	if DialogManager and DialogManager.is_dialog_active():
		return true
	# Check cinematics
	if CinematicsManager and CinematicsManager.is_cinematic_active():
		return true
	return false
