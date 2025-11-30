## MapTest - Test scene for map exploration system
##
## Demonstrates hero movement, party followers, and camera control.
extends Node2D

## Set to true to enable verbose debug output
const DEBUG_VERBOSE: bool = false


## Helper to print debug messages only when verbose mode is enabled.
func _debug_print(msg: String) -> void:
	if DEBUG_VERBOSE:
		print(msg)


## Preload scripts
const HeroControllerScript: GDScript = preload("res://scenes/map_exploration/hero_controller.gd")
const MapCameraScript: GDScript = preload("res://scenes/map_exploration/map_camera.gd")
const PartyFollowerScript: GDScript = preload("res://scenes/map_exploration/party_follower.gd")

## References to scene nodes
@onready var hero: Node2D = $Hero
@onready var camera: Camera2D = $MapCamera
@onready var tilemap: TileMapLayer = $TileMapLayer
@onready var followers_container: Node2D = $Followers

## Party follower nodes (will be created dynamically)
var party_followers: Array[Node2D] = []


func _ready() -> void:
	_debug_print("MapTest: Initializing map exploration test scene")

	# Check if returning from battle
	if GameState.has_return_data():
		_debug_print("MapTest: Returning from battle - restoring hero position")
		var return_pos: Vector2i = GameState.return_hero_grid_position

		# Wait one frame for hero to be fully initialized
		await get_tree().process_frame

		if hero and hero.has_method("teleport_to_grid"):
			hero.teleport_to_grid(return_pos)
			_debug_print("  Hero restored to grid position: %s" % return_pos)

		# Clear return data after using it
		GameState.clear_return_data()

	# Setup camera to follow hero
	if camera and hero:
		camera.set_follow_target(hero)
		camera.snap_to_target()

	# Create test party followers
	_setup_party_followers()

	# Connect hero signals
	if hero:
		hero.moved_to_tile.connect(_on_hero_moved)
		hero.interaction_requested.connect(_on_hero_interaction)

	# Note: TriggerManager now handles all trigger connections automatically
	# No need to manually connect to triggers in map scenes anymore!
	# But we'll keep the old code for backward compatibility
	var battle_trigger: Node = get_node_or_null("BattleTrigger")
	if battle_trigger:
		_debug_print("MapTest: Battle trigger found (will be handled by TriggerManager)")

	_debug_print("MapTest: Scene initialized. Use arrow keys to move, Enter/Z to interact")


## Create party followers for testing.
func _setup_party_followers() -> void:
	# For now, create 3 test followers
	var num_followers: int = 3

	for i in range(num_followers):
		var follower: CharacterBody2D = CharacterBody2D.new()
		follower.set_script(PartyFollowerScript)
		follower.name = "Follower%d" % (i + 1)
		follower.formation_index = i + 1  # SF2-style: position in formation behind hero
		follower.tile_size = hero.tile_size

		# Add visual components (placeholder colored squares)
		var sprite_placeholder: ColorRect = ColorRect.new()
		sprite_placeholder.custom_minimum_size = Vector2(12, 12)
		sprite_placeholder.position = Vector2(-6, -6)
		sprite_placeholder.color = Color(0.3 + i * 0.2, 0.5, 0.8 - i * 0.2)  # Different colors
		sprite_placeholder.name = "SpriteVisual"
		follower.add_child(sprite_placeholder)

		# Add collision shape (placeholder)
		var collision: CollisionShape2D = CollisionShape2D.new()
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = 4.0
		collision.shape = shape
		collision.name = "CollisionShape2D"
		follower.add_child(collision)

		# Set follow target - all followers follow hero directly
		follower.set_follow_target(hero)

		# Add to scene
		followers_container.add_child(follower)
		party_followers.append(follower)

	_debug_print("MapTest: Created %d party followers" % num_followers)


## Called when hero completes movement to a new tile.
func _on_hero_moved(tile_pos: Vector2i) -> void:
	_debug_print("MapTest: Hero moved to grid position: %s" % tile_pos)

	# TODO: Check for encounters, triggers, etc.


## Called when hero attempts to interact.
func _on_hero_interaction(interaction_pos: Vector2i) -> void:
	_debug_print("MapTest: Hero interacting with tile: %s" % interaction_pos)

	# TODO: Check for NPCs, doors, chests, etc.


## Called when battle trigger is activated.
func _on_battle_trigger_activated(trigger: Node, player: Node2D) -> void:
	_debug_print("MapTest: *** BATTLE TRIGGER ACTIVATED ***")
	_debug_print("  Trigger ID: %s" % trigger.trigger_id)
	_debug_print("  Battle ID: %s" % trigger.trigger_data.get("battle_id", "NONE"))
	_debug_print("  Player position: %s" % player.global_position)
	_debug_print("  Trigger completed: %s" % GameState.is_trigger_completed(trigger.trigger_id))


## Called when battle trigger activation fails.
func _on_battle_trigger_failed(trigger: Node, reason: String) -> void:
	_debug_print("MapTest: Battle trigger activation FAILED - Reason: %s" % reason)


## Handle debug inputs.
func _input(event: InputEvent) -> void:
	# Debug: Press ESC to return to main menu (when implemented)
	if event.is_action_pressed("ui_cancel"):
		_debug_print("MapTest: ESC pressed - would return to main menu")

	# Debug: Press 'T' to teleport hero to center
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		if hero:
			_debug_print("MapTest: Teleporting hero to center")
			hero.teleport_to_grid(Vector2i(5, 5))
