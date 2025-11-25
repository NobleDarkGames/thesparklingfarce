## MapTest - Test scene for map exploration system
##
## Demonstrates hero movement, party followers, and camera control.
extends Node2D

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
	print("MapTest: Initializing map exploration test scene")

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

	print("MapTest: Scene initialized. Use arrow keys to move, Enter/Z to interact")


func _setup_party_followers() -> void:
	"""Create party followers for testing."""
	# For now, create 3 test followers
	var num_followers: int = 3
	var follow_spacing: int = 5  # Tiles apart in position history

	var previous_target: Node2D = hero

	for i in range(num_followers):
		var follower: CharacterBody2D = CharacterBody2D.new()
		follower.set_script(PartyFollowerScript)
		follower.name = "Follower%d" % (i + 1)
		follower.follow_distance = follow_spacing * (i + 1)
		follower.tile_size = hero.tile_size

		# Add visual components (placeholder colored squares)
		var sprite_placeholder: ColorRect = ColorRect.new()
		sprite_placeholder.custom_minimum_size = Vector2(24, 24)
		sprite_placeholder.position = Vector2(-12, -12)
		sprite_placeholder.color = Color(0.3 + i * 0.2, 0.5, 0.8 - i * 0.2)  # Different colors
		sprite_placeholder.name = "SpriteVisual"
		follower.add_child(sprite_placeholder)

		# Add collision shape (placeholder)
		var collision: CollisionShape2D = CollisionShape2D.new()
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = 8.0
		collision.shape = shape
		collision.name = "CollisionShape2D"
		follower.add_child(collision)

		# Set follow target (each follower follows the hero)
		follower.set_follow_target(hero)

		# Add to scene
		followers_container.add_child(follower)
		party_followers.append(follower)

	print("MapTest: Created %d party followers" % num_followers)


func _on_hero_moved(tile_pos: Vector2i) -> void:
	"""Called when hero completes movement to a new tile."""
	print("MapTest: Hero moved to grid position: ", tile_pos)

	# TODO: Check for encounters, triggers, etc.


func _on_hero_interaction(interaction_pos: Vector2i) -> void:
	"""Called when hero attempts to interact."""
	print("MapTest: Hero interacting with tile: ", interaction_pos)

	# TODO: Check for NPCs, doors, chests, etc.


func _input(event: InputEvent) -> void:
	"""Handle debug inputs."""
	# Debug: Press ESC to return to main menu (when implemented)
	if event.is_action_pressed("ui_cancel"):
		print("MapTest: ESC pressed - would return to main menu")

	# Debug: Press 'T' to teleport hero to center
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		if hero:
			print("MapTest: Teleporting hero to center")
			hero.teleport_to_grid(Vector2i(5, 5))
