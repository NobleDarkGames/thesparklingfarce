## Playable Map Test - Load party and explore
##
## This scene loads your party and lets you explore a test map
extends Node2D

const HeroControllerScript: GDScript = preload("res://scenes/map_exploration/hero_controller.gd")
const MapCameraScript: GDScript = preload("res://scenes/map_exploration/map_camera.gd")
const PartyFollowerScript: GDScript = preload("res://scenes/map_exploration/party_follower.gd")

## Scene references
var hero: CharacterBody2D = null
var camera: Camera2D = null
var followers: Array[CharacterBody2D] = []

## Party data
var party_characters: Array[CharacterData] = []


func _ready() -> void:
	print("===========================================")
	print("MAP EXPLORATION - PLAYABLE TEST")
	print("===========================================")

	# Load party from PartyManager or create test party
	_load_party()

	# Create hero from first party member
	_create_hero()

	# Create followers from remaining party members
	_create_followers()

	# Setup camera
	_setup_camera()

	print("\n===========================================")
	print("CONTROLS:")
	print("  Arrow Keys - Move hero")
	print("  Enter/Z - Interact")
	print("  ESC - Quit test")
	print("===========================================\n")


func _load_party() -> void:
	"""Load party members from PartyManager or create test party."""
	print("\n[Loading Party]")

	# Try to load from PartyManager
	if PartyManager and PartyManager.party_members.size() > 0:
		party_characters = PartyManager.party_members.duplicate()
		print("✅ Loaded %d characters from PartyManager" % party_characters.size())
		for character in party_characters:
			if character:
				print("  - %s (%s)" % [character.character_name, character.character_class.display_name])
	else:
		# Load test characters from mod registry
		print("⚠️  PartyManager empty, loading test party from ModRegistry...")

		var max_char: CharacterData = ModLoader.registry.get_resource("character", "max")
		if max_char:
			party_characters.append(max_char)
			print("  - Loaded Max (Hero)")

		# Try to load some other characters for followers
		var all_characters: Array[Resource] = ModLoader.registry.get_all_resources("character")
		for char_data: CharacterData in all_characters:
			if char_data != max_char and party_characters.size() < 4:
				party_characters.append(char_data)
				print("  - Loaded %s (%s)" % [char_data.character_name, char_data.character_class.display_name])

		if party_characters.size() == 0:
			push_error("No characters found! Cannot create party.")
			return


func _create_hero() -> void:
	"""Create the hero controller from the first party member."""
	print("\n[Creating Hero]")

	if party_characters.size() == 0:
		push_error("No party members available!")
		return

	var hero_data: CharacterData = party_characters[0]

	hero = CharacterBody2D.new()
	hero.set_script(HeroControllerScript)
	hero.name = "Hero"
	hero.position = Vector2(320, 180)  # Center of screen
	hero.z_index = 100  # Hero on top of all party members

	# Add visual representation (colored square with label)
	var visual_container: Node2D = Node2D.new()
	visual_container.name = "Visual"
	hero.add_child(visual_container)

	# Character sprite (colored square for now)
	var sprite_rect: ColorRect = ColorRect.new()
	sprite_rect.custom_minimum_size = Vector2(28, 28)
	sprite_rect.position = Vector2(-14, -14)
	sprite_rect.color = Color(0.2, 0.8, 0.2)  # Green for hero
	sprite_rect.name = "SpriteRect"
	visual_container.add_child(sprite_rect)

	# Character name label (hidden in map mode to avoid overlap)
	# var name_label: Label = Label.new()
	# name_label.text = hero_data.character_name
	# name_label.position = Vector2(-20, -30)
	# name_label.add_theme_font_size_override("font_size", 10)
	# name_label.modulate = Color(1, 1, 1, 0.9)
	# visual_container.add_child(name_label)

	# Collision shape
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 12.0
	collision.shape = shape
	collision.name = "CollisionShape2D"
	hero.add_child(collision)

	# Interaction ray
	var interaction_ray: RayCast2D = RayCast2D.new()
	interaction_ray.enabled = true
	interaction_ray.target_position = Vector2(32, 0)
	interaction_ray.name = "InteractionRay"
	hero.add_child(interaction_ray)

	add_child(hero)

	print("✅ Hero created: %s" % hero_data.character_name)


func _create_followers() -> void:
	"""Create party followers from remaining party members."""
	print("\n[Creating Followers]")

	# Skip first member (that's the hero)
	for i in range(1, party_characters.size()):
		var char_data: CharacterData = party_characters[i]

		var follower: CharacterBody2D = CharacterBody2D.new()
		follower.set_script(PartyFollowerScript)
		follower.name = "Follower_%s" % char_data.character_name
		follower.z_index = 90 - i  # Followers below hero, in reverse order (closer = higher)

		# Set follow parameters
		follower.set("follow_distance", 6 * i)  # Spread them out more
		follower.set("tile_size", 32)
		follower.set("follow_target", hero)

		# Add visual representation
		var visual_container: Node2D = Node2D.new()
		visual_container.name = "Visual"
		follower.add_child(visual_container)

		# Different color for each follower
		var hue: float = float(i) / float(party_characters.size())
		var follower_color: Color = Color.from_hsv(hue, 0.6, 0.9)

		var sprite_rect: ColorRect = ColorRect.new()
		sprite_rect.custom_minimum_size = Vector2(24, 24)
		sprite_rect.position = Vector2(-12, -12)
		sprite_rect.color = follower_color
		sprite_rect.name = "SpriteRect"
		visual_container.add_child(sprite_rect)

		# Character name label (hidden in map mode to avoid overlap)
		# var name_label: Label = Label.new()
		# name_label.text = char_data.character_name
		# name_label.position = Vector2(-20, -28)
		# name_label.add_theme_font_size_override("font_size", 9)
		# name_label.modulate = Color(1, 1, 1, 0.8)
		# visual_container.add_child(name_label)

		# Collision shape
		var collision: CollisionShape2D = CollisionShape2D.new()
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = 10.0
		collision.shape = shape
		collision.name = "CollisionShape2D"
		follower.add_child(collision)

		add_child(follower)
		followers.append(follower)

		print("✅ Follower created: %s" % char_data.character_name)

	print("Total followers: %d" % followers.size())


func _setup_camera() -> void:
	"""Setup camera to follow the hero."""
	print("\n[Setting up Camera]")

	camera = Camera2D.new()
	camera.set_script(MapCameraScript)
	camera.name = "MapCamera"
	camera.position = hero.position if hero else Vector2(320, 180)

	add_child(camera)

	if hero:
		camera.call("set_follow_target", hero)
		camera.call("snap_to_target")

	print("✅ Camera created and following hero")


func _input(event: InputEvent) -> void:
	"""Handle test scene controls."""
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			print("\n[ESC] Exiting map exploration test...")
			get_tree().quit()
		elif event.keycode == KEY_F1:
			# Debug: Show positions
			print("\n--- Debug Info ---")
			if hero:
				print("Hero position: %s" % hero.position)
				print("Hero grid position: %s" % hero.get("grid_position"))
			for i in range(followers.size()):
				if i < followers.size():
					print("Follower %d position: %s" % [i + 1, followers[i].position])
			print("------------------\n")
		elif event.keycode == KEY_F2:
			# Debug: Teleport hero
			if hero and hero.has_method("teleport_to_grid"):
				hero.call("teleport_to_grid", Vector2i(15, 10))
				print("[F2] Hero teleported to (15, 10)")


func _draw() -> void:
	"""Draw a simple grid for reference."""
	# Draw grid lines
	var grid_color: Color = Color(0.3, 0.3, 0.3, 0.3)
	var tile_size: int = 32

	# Draw vertical lines
	for x in range(0, 640, tile_size):
		draw_line(Vector2(x, 0), Vector2(x, 360), grid_color, 1.0)

	# Draw horizontal lines
	for y in range(0, 360, tile_size):
		draw_line(Vector2(0, y), Vector2(640, y), grid_color, 1.0)


func _process(_delta: float) -> void:
	"""Keep redrawing the grid."""
	queue_redraw()
