## MapTemplate - Template for map exploration scenes
##
## USAGE: Duplicate this file and the accompanying .tscn to create new map scenes.
##
## This template provides:
## - Battle return handling (hero position restored after combat)
## - Camera setup with smooth following
## - SF2-style party formation with diagonal shortcuts
## - Signal connections for hero movement and interaction
##
## CAMPAIGN INTEGRATION:
## Add a node to your campaign JSON like this:
##   {
##     "node_id": "my_map",
##     "display_name": "My Map Name",
##     "node_type": "scene",
##     "scene_path": "res://mods/my_mod/maps/my_map.tscn",
##     "is_hub": true,  // Optional: makes this an Egress destination
##     "completion_trigger": "exit_trigger",  // or "flag_set", "manual"
##     "on_complete": "next_node_id"
##   }
##
## TRIGGERING BATTLES:
## Add MapTrigger nodes (battle_trigger.tscn) to your scene with:
##   trigger_type: BATTLE
##   trigger_data: { "battle_id": "your_battle_id" }
##
## The TriggerManager autoload handles everything automatically!
extends Node2D

# =============================================================================
# CONFIGURATION
# =============================================================================

## Enable verbose debug output (disable for production)
const DEBUG_VERBOSE: bool = false

## Number of party followers to display (0-3 recommended for performance)
const MAX_VISIBLE_FOLLOWERS: int = 3


# =============================================================================
# PRELOADED SCRIPTS
# =============================================================================

const HeroControllerScript: GDScript = preload("res://scenes/map_exploration/hero_controller.gd")
const MapCameraScript: GDScript = preload("res://scenes/map_exploration/map_camera.gd")
const PartyFollowerScript: GDScript = preload("res://scenes/map_exploration/party_follower.gd")
const SpawnPointScript: GDScript = preload("res://core/components/spawn_point.gd")


# =============================================================================
# NODE REFERENCES
# =============================================================================

## The player character - must be in "hero" group for triggers to work
@onready var hero: CharacterBody2D = $Hero

## Camera that follows the hero
@onready var camera: Camera2D = $MapCamera

## TileMapLayer for terrain (optional - hero works without it)
@onready var tilemap: TileMapLayer = $TileMapLayer

## Container for dynamically created party followers
@onready var followers_container: Node2D = $Followers


# =============================================================================
# STATE
# =============================================================================

## Created follower nodes for cleanup
var party_followers: Array[CharacterBody2D] = []


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_debug_print("MapTemplate: Initializing...")

	# CRITICAL: Handle transitions FIRST (restores hero position)
	# This handles both battle returns AND door transitions with spawn points
	var context: RefCounted = GameState.get_transition_context()
	if context:
		await _handle_transition_context(context)
	else:
		# No transition context - use default spawn point if available
		_spawn_at_default()

	# Setup camera to follow hero
	_setup_camera()

	# Create party followers from PartyManager (if available)
	_setup_party_followers()

	# Connect hero signals for custom behavior
	_connect_hero_signals()

	_debug_print("MapTemplate: Ready! Arrow keys to move, Z/Enter to interact")


# =============================================================================
# TRANSITION HANDLING (Battle Returns & Door Transitions)
# =============================================================================

## Handles all transition types: battle returns and door transitions
## Uses spawn_point_id if provided, otherwise falls back to position restoration
func _handle_transition_context(context: RefCounted) -> void:
	_debug_print("MapTemplate: Handling transition context...")

	# Wait one frame for hero to be fully initialized
	await get_tree().process_frame

	var spawn_point_id: String = context.spawn_point_id if context.get("spawn_point_id") else ""
	var restored: bool = false

	# Priority 1: Use spawn point if specified (door transitions)
	if not spawn_point_id.is_empty():
		restored = _spawn_at_point(spawn_point_id)
		if restored:
			_debug_print("  Hero spawned at point: %s" % spawn_point_id)

	# Priority 2: Use saved position (battle returns)
	if not restored and context.hero_grid_position != Vector2i.ZERO:
		if hero and hero.has_method("teleport_to_grid"):
			hero.teleport_to_grid(context.hero_grid_position)
			# Restore facing direction if available
			if context.get("hero_facing") and hero.has_method("set_facing"):
				hero.set_facing(context.hero_facing)
			restored = true
			_debug_print("  Hero restored to grid: %s" % context.hero_grid_position)

	# Priority 3: Use default spawn point as fallback
	if not restored:
		_spawn_at_default()
		_debug_print("  Hero spawned at default position")

	# Snap camera to avoid jarring interpolation
	if camera:
		camera.snap_to_target()

	# Clear context after using it
	GameState.clear_transition_context()

	# Emit signal for any listeners
	if TriggerManager and TriggerManager.has_signal("door_transition_completed"):
		TriggerManager.door_transition_completed.emit(spawn_point_id)


## Spawns hero at a named spawn point in this scene
## Returns true if spawn point was found and hero was teleported
func _spawn_at_point(spawn_id: String) -> bool:
	# Find spawn point in scene tree
	var spawn_point: Node = SpawnPointScript.find_by_id(self, spawn_id)

	if spawn_point:
		if hero and hero.has_method("teleport_to_grid"):
			hero.teleport_to_grid(spawn_point.grid_position)
			# Set facing direction from spawn point
			if hero.has_method("set_facing"):
				hero.set_facing(spawn_point.facing)
			return true
	else:
		push_warning("MapTemplate: Spawn point '%s' not found in scene" % spawn_id)

	return false


## Spawns hero at the default spawn point (if one exists)
func _spawn_at_default() -> void:
	var default_spawn: Node = SpawnPointScript.find_default(self)

	if default_spawn:
		if hero and hero.has_method("teleport_to_grid"):
			hero.teleport_to_grid(default_spawn.grid_position)
			if hero.has_method("set_facing"):
				hero.set_facing(default_spawn.facing)
			_debug_print("MapTemplate: Hero spawned at default spawn point")
	# If no default spawn point, hero stays at scene-defined position


## Legacy function - redirects to new system
func _restore_from_battle() -> void:
	var context: RefCounted = GameState.get_transition_context()
	if context:
		await _handle_transition_context(context)
	else:
		# Fallback to legacy API
		var return_pos: Vector2i = GameState.return_hero_grid_position
		if hero and hero.has_method("teleport_to_grid"):
			hero.teleport_to_grid(return_pos)
		GameState.clear_return_data()


# =============================================================================
# CAMERA SETUP
# =============================================================================

## Sets up camera to follow the hero.
func _setup_camera() -> void:
	if not camera or not hero:
		push_warning("MapTemplate: Missing camera or hero node")
		return

	camera.set_follow_target(hero)
	camera.snap_to_target()
	_debug_print("MapTemplate: Camera locked onto hero")


# =============================================================================
# PARTY FOLLOWERS
# =============================================================================

## Creates visual follower sprites for party members.
## SF2-style CHAIN FOLLOWING: Each follower follows the one in front of them.
## TODO: Integrate with PartyManager to use actual party data
func _setup_party_followers() -> void:
	# TODO: Get actual party from PartyManager
	# var party: Array = PartyManager.get_party_members()
	# For now, create placeholder followers for testing

	var num_followers: int = mini(MAX_VISIBLE_FOLLOWERS, 3)

	for i in range(num_followers):
		var follower: CharacterBody2D = _create_follower(i)
		followers_container.add_child(follower)
		party_followers.append(follower)

		# CHAIN FOLLOWING: First follower follows hero, rest follow previous follower
		if i == 0:
			follower.set_follow_target(hero)
		else:
			follower.set_follow_target(party_followers[i - 1])

	_debug_print("MapTemplate: Created %d party followers (chain following)" % num_followers)


## Creates a single follower node.
## SF2-style: each follower is positioned behind hero based on formation_index.
func _create_follower(index: int) -> CharacterBody2D:
	var follower: CharacterBody2D = CharacterBody2D.new()
	follower.set_script(PartyFollowerScript)
	follower.name = "Follower%d" % (index + 1)
	follower.formation_index = index + 1  # SF2-style: position in formation behind hero
	follower.tile_size = hero.tile_size if hero else 32

	# Placeholder visual (replace with actual sprites)
	var visual: ColorRect = ColorRect.new()
	visual.custom_minimum_size = Vector2(12, 12)
	visual.position = Vector2(-6, -6)
	visual.color = Color(0.3 + index * 0.15, 0.5, 0.8 - index * 0.15)
	visual.name = "SpriteVisual"
	follower.add_child(visual)

	# Collision shape
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 4.0
	collision.shape = shape
	follower.add_child(collision)

	# NOTE: follow_target is set in _setup_party_followers() for chain following

	return follower


# =============================================================================
# HERO SIGNALS
# =============================================================================

## Connects to hero's movement and interaction signals.
func _connect_hero_signals() -> void:
	if not hero:
		return

	if hero.has_signal("moved_to_tile"):
		hero.moved_to_tile.connect(_on_hero_moved)

	if hero.has_signal("interaction_requested"):
		hero.interaction_requested.connect(_on_hero_interaction)


## Called when hero completes movement to a new tile.
## Override in your map script to add custom behavior (random encounters, etc.)
func _on_hero_moved(tile_pos: Vector2i) -> void:
	_debug_print("MapTemplate: Hero at tile %s" % tile_pos)

	# TODO: Add your custom logic here:
	# - Random encounter checks
	# - Tile-based events
	# - Step counters


## Called when hero presses the interaction button.
## Override to handle NPC conversations, inspecting objects, etc.
func _on_hero_interaction(interaction_pos: Vector2i) -> void:
	_debug_print("MapTemplate: Interaction at tile %s" % interaction_pos)

	# TODO: Add your custom logic here:
	# - Check for NPCs at interaction_pos
	# - Check for readable signs
	# - Check for chests


# =============================================================================
# DEBUG UTILITIES
# =============================================================================

## Prints debug messages when DEBUG_VERBOSE is enabled.
func _debug_print(msg: String) -> void:
	if DEBUG_VERBOSE:
		print(msg)


## Debug input handling (remove or disable in production).
func _input(event: InputEvent) -> void:
	# ESC to return to main menu (when implemented)
	if event.is_action_pressed("ui_cancel"):
		_debug_print("MapTemplate: ESC pressed")
		# SceneManager.change_scene("res://scenes/ui/main_menu.tscn")

	# Debug teleport (T key)
	if DEBUG_VERBOSE and event is InputEventKey:
		if event.pressed and event.keycode == KEY_T and hero:
			hero.teleport_to_grid(Vector2i(5, 5))
			_debug_print("MapTemplate: Debug teleported to (5, 5)")
