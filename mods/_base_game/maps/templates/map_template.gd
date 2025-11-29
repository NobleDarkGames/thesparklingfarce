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

	# CRITICAL: Handle return from battle FIRST (restores hero position)
	if GameState.has_return_data():
		await _restore_from_battle()

	# Setup camera to follow hero
	_setup_camera()

	# Create party followers from PartyManager (if available)
	_setup_party_followers()

	# Connect hero signals for custom behavior
	_connect_hero_signals()

	_debug_print("MapTemplate: Ready! Arrow keys to move, Z/Enter to interact")


# =============================================================================
# BATTLE RETURN HANDLING
# =============================================================================

## Restores hero position after returning from a battle.
## Called automatically in _ready() if return data exists.
func _restore_from_battle() -> void:
	_debug_print("MapTemplate: Returning from battle...")

	# Wait one frame for hero to be fully initialized
	await get_tree().process_frame

	# Try the new TransitionContext API first
	var context: RefCounted = GameState.get_transition_context()
	if context:
		var saved_pos: Vector2i = context.hero_grid_position
		if hero and hero.has_method("teleport_to_grid"):
			hero.teleport_to_grid(saved_pos)
			_debug_print("  Hero restored to grid: %s" % saved_pos)

		# Snap camera to avoid jarring interpolation
		if camera:
			camera.snap_to_target()

		# Clear context after using it
		GameState.clear_transition_context()
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

	_debug_print("MapTemplate: Created %d party followers" % num_followers)


## Creates a single follower node.
## SF2-style: each follower is 1 unit behind the previous in formation.
func _create_follower(index: int) -> CharacterBody2D:
	var follower: CharacterBody2D = CharacterBody2D.new()
	follower.set_script(PartyFollowerScript)
	follower.name = "Follower%d" % (index + 1)
	follower.follow_distance = index + 1  # SF2-style: 1, 2, 3 units behind hero
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

	# Set to follow hero
	follower.set_follow_target(hero)

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
