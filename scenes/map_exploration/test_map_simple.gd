## Simple test for map exploration - creates everything programmatically
extends Node2D

const HeroControllerScript: GDScript = preload("res://scenes/map_exploration/hero_controller.gd")
const MapCameraScript: GDScript = preload("res://scenes/map_exploration/map_camera.gd")
const PartyFollowerScript: GDScript = preload("res://scenes/map_exploration/party_follower.gd")


func _ready() -> void:
	print("=== Map Exploration Test ===")
	print("Creating hero...")

	# Create hero
	var hero: CharacterBody2D = CharacterBody2D.new()
	hero.set_script(HeroControllerScript)
	hero.name = "Hero"
	hero.position = Vector2(160, 160)

	# Add visual for hero
	var hero_visual: ColorRect = ColorRect.new()
	hero_visual.custom_minimum_size = Vector2(24, 24)
	hero_visual.position = Vector2(-12, -12)
	hero_visual.color = Color(0.2, 0.8, 0.2)
	hero_visual.name = "SpriteVisual"
	hero.add_child(hero_visual)

	# Add collision for hero
	var hero_collision: CollisionShape2D = CollisionShape2D.new()
	var hero_shape: CircleShape2D = CircleShape2D.new()
	hero_shape.radius = 8.0
	hero_collision.shape = hero_shape
	hero_collision.name = "CollisionShape2D"
	hero.add_child(hero_collision)

	# Add interaction ray
	var interaction_ray: RayCast2D = RayCast2D.new()
	interaction_ray.enabled = true
	interaction_ray.target_position = Vector2(32, 0)
	interaction_ray.name = "InteractionRay"
	hero.add_child(interaction_ray)

	add_child(hero)

	print("Creating camera...")

	# Create camera
	var camera: Camera2D = Camera2D.new()
	camera.set_script(MapCameraScript)
	camera.name = "MapCamera"
	camera.position = Vector2(160, 160)
	add_child(camera)

	# Set camera to follow hero
	camera.set_follow_target(hero)

	print("Creating party followers...")

	# Create 3 followers
	for i in range(3):
		var follower: CharacterBody2D = CharacterBody2D.new()
		follower.set_script(PartyFollowerScript)
		follower.name = "Follower%d" % (i + 1)

		# Set follower properties
		follower.set("follow_distance", 5 * (i + 1))
		follower.set("tile_size", 32)
		follower.set("follow_target", hero)

		# Add visual
		var follower_visual: ColorRect = ColorRect.new()
		follower_visual.custom_minimum_size = Vector2(24, 24)
		follower_visual.position = Vector2(-12, -12)
		follower_visual.color = Color(0.3 + i * 0.2, 0.5, 0.8 - i * 0.2)
		follower_visual.name = "SpriteVisual"
		follower.add_child(follower_visual)

		# Add collision
		var follower_collision: CollisionShape2D = CollisionShape2D.new()
		var follower_shape: CircleShape2D = CircleShape2D.new()
		follower_shape.radius = 8.0
		follower_collision.shape = follower_shape
		follower_collision.name = "CollisionShape2D"
		follower.add_child(follower_collision)

		add_child(follower)
		print("Created follower %d" % (i + 1))

	print("=== Map Exploration Test Ready ===")
	print("Use arrow keys to move the hero")
	print("Party members will follow behind")
	print("")


func _input(event: InputEvent) -> void:
	"""Debug input handlers."""
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			print("ESC pressed - exiting")
			get_tree().quit()
		elif event.keycode == KEY_T:
			print("T pressed - teleport test")
			var hero: Node = get_node_or_null("Hero")
			if hero and hero.has_method("teleport_to_grid"):
				hero.teleport_to_grid(Vector2i(10, 10))
				print("Hero teleported to (10, 10)")
