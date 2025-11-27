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

	# Check if returning from battle - restore hero position if so
	var returning_from_battle: bool = GameState.has_return_data()
	var saved_position: Vector2 = Vector2.ZERO
	var battle_outcome: int = 0  # TransitionContext.BattleOutcome.NONE

	if returning_from_battle:
		var context: RefCounted = GameState.get_transition_context()
		if context:
			saved_position = context.hero_world_position
			battle_outcome = context.battle_outcome
			print("Returning from battle at position: %s (outcome: %d)" % [saved_position, battle_outcome])

	# Load party from PartyManager or create test party
	_load_party()

	# Create hero from first party member
	_create_hero()

	# Create followers from remaining party members
	_create_followers()

	# Setup camera
	_setup_camera()

	# Create test battle trigger
	_create_battle_trigger()

	# If returning from battle, restore hero position
	if returning_from_battle and saved_position != Vector2.ZERO:
		_restore_from_battle(saved_position)

	print("\n===========================================")
	print("CONTROLS:")
	print("  Arrow Keys - Move hero")
	print("  Enter/Z - Interact")
	print("  Walk into RED SQUARE to trigger battle")
	print("  ESC - Quit test")
	print("===========================================\n")


## Load party members from PartyManager or create test party.
func _load_party() -> void:
	print("\n[Loading Party]")

	# Try to load from PartyManager
	if PartyManager and PartyManager.party_members.size() > 0:
		party_characters = PartyManager.party_members.duplicate()
		print("✅ Loaded %d characters from PartyManager" % party_characters.size())
		for character in party_characters:
			if character:
				var class_name_str: String = character.character_class.display_name if character.character_class else "Unknown"
				print("  - %s (%s)" % [character.character_name, class_name_str])
	else:
		# Load test characters from mod registry and add to PartyManager
		print("⚠️  PartyManager empty, loading test party from ModRegistry...")

		# Load hero from sandbox mod (Mr Big Hero Face)
		var hero_char: CharacterData = ModLoader.registry.get_resource("character", "character_1763762722")
		if hero_char:
			party_characters.append(hero_char)
			PartyManager.add_member(hero_char)
			print("  - Loaded %s (Hero)" % hero_char.character_name)

		# Try to load some other characters for followers (only those with valid classes)
		var all_characters: Array[Resource] = ModLoader.registry.get_all_resources("character")
		for char_data: CharacterData in all_characters:
			if char_data != hero_char and party_characters.size() < 4:
				# Skip characters without a class assigned
				if not char_data.character_class:
					print("  - Skipping %s (no class assigned)" % char_data.character_name)
					continue
				party_characters.append(char_data)
				PartyManager.add_member(char_data)
				print("  - Loaded %s (%s)" % [char_data.character_name, char_data.character_class.display_name])

		print("✅ Added %d characters to PartyManager for battle" % party_characters.size())

		if party_characters.size() == 0:
			push_error("No characters found! Cannot create party.")
			return


## Create the hero controller from the first party member.
func _create_hero() -> void:
	print("\n[Creating Hero]")

	if party_characters.size() == 0:
		push_error("No party members available!")
		return

	var hero_data: CharacterData = party_characters[0]

	hero = CharacterBody2D.new()
	hero.set_script(HeroControllerScript)
	hero.name = "Hero"
	# Grid-aligned position: cell (10, 5) centered = (10*32+16, 5*32+16) = (336, 176)
	hero.position = Vector2(336, 176)
	hero.z_index = 100  # Hero on top of all party members
	hero.add_to_group("hero")  # Required for MapTrigger detection

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


## Create party followers from remaining party members.
func _create_followers() -> void:
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


## Setup camera to follow the hero.
func _setup_camera() -> void:
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


## Restore hero and party after returning from battle.
func _restore_from_battle(saved_position: Vector2) -> void:
	print("\n[Restoring from Battle]")

	if not hero:
		push_error("Cannot restore - hero not created!")
		return

	# Restore hero's exact world position
	hero.global_position = saved_position
	hero.set("target_position", saved_position)
	hero.set("is_moving", false)

	# Calculate grid position from world position
	var tile_size: int = 32
	var grid_pos: Vector2i = Vector2i(int(saved_position.x / tile_size), int(saved_position.y / tile_size))
	hero.set("grid_position", grid_pos)

	# Rebuild position history for followers
	var position_history_size: int = hero.get("position_history_size") if hero.get("position_history_size") else 30
	var position_history: Array = []
	for i in range(position_history_size):
		position_history.append(saved_position)
	hero.set("position_history", position_history)

	print("✅ Hero restored to position: %s (grid: %s)" % [saved_position, grid_pos])

	# Snap camera to restored position
	if camera:
		camera.position = saved_position
		if camera.has_method("snap_to_target"):
			camera.call("snap_to_target")
		print("✅ Camera snapped to hero")

	# Clear transition context - we've used it
	GameState.clear_transition_context()
	print("✅ Transition context cleared")


## Create a battle trigger for testing the explore-battle-explore loop.
func _create_battle_trigger() -> void:
	print("\n[Creating Battle Trigger]")

	# Create the trigger area
	var trigger: Area2D = Area2D.new()
	trigger.set_script(load("res://core/components/map_trigger.gd"))
	trigger.name = "TestBattleTrigger"
	trigger.position = Vector2(480, 180)  # Right side of screen

	# Configure as battle trigger
	trigger.set("trigger_type", 0)  # MapTrigger.TriggerType.BATTLE
	trigger.set("trigger_id", "test_battle_001")
	trigger.set("one_shot", false)  # Allow re-triggering for testing
	trigger.set("trigger_data", {"battle_id": "battle_1763763677"})

	# Collision shape
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(48, 48)
	collision.shape = shape
	trigger.add_child(collision)

	# Visual indicator (red square)
	var visual: ColorRect = ColorRect.new()
	visual.size = Vector2(48, 48)
	visual.position = Vector2(-24, -24)
	visual.color = Color(0.8, 0.2, 0.2, 0.7)  # Semi-transparent red
	trigger.add_child(visual)

	# Label
	var label: Label = Label.new()
	label.text = "BATTLE"
	label.position = Vector2(-24, -40)
	label.add_theme_font_size_override("font_size", 10)
	trigger.add_child(label)

	add_child(trigger)

	# Connect trigger signal to TriggerManager
	if trigger.has_signal("triggered"):
		trigger.triggered.connect(TriggerManager._on_trigger_activated)

	print("✅ Battle trigger created at (480, 180)")
	print("   Walk into the red square to start battle")


## Handle test scene controls.
func _input(event: InputEvent) -> void:
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


## Draw a simple grid for reference.
func _draw() -> void:
	# Draw grid lines
	var grid_color: Color = Color(0.3, 0.3, 0.3, 0.3)
	var tile_size: int = 32

	# Draw vertical lines
	for x in range(0, 640, tile_size):
		draw_line(Vector2(x, 0), Vector2(x, 360), grid_color, 1.0)

	# Draw horizontal lines
	for y in range(0, 360, tile_size):
		draw_line(Vector2(0, y), Vector2(640, y), grid_color, 1.0)


## Keep redrawing the grid.
func _process(_delta: float) -> void:
	queue_redraw()
