## Playable Map Test - Load party and explore
##
## This scene loads your party and lets you explore a test map
extends Node2D

## Set to true to enable verbose debug output
const DEBUG_VERBOSE: bool = false


## Helper to print debug messages only when verbose mode is enabled.
func _debug_print(msg: String) -> void:
	if DEBUG_VERBOSE:
		print(msg)


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
	_debug_print("===========================================")
	_debug_print("MAP EXPLORATION - PLAYABLE TEST")
	_debug_print("===========================================")

	# Check if returning from battle - restore hero position if so
	var context: RefCounted = GameState.get_transition_context()
	var returning_from_battle: bool = context != null and context.is_valid()
	var saved_position: Vector2 = Vector2.ZERO
	var battle_outcome: int = 0  # TransitionContext.BattleOutcome.NONE

	if returning_from_battle:
		saved_position = context.hero_world_position
		battle_outcome = context.battle_outcome
		_debug_print("Returning from battle at position: %s (outcome: %d)" % [saved_position, battle_outcome])

	# Load party from PartyManager or create test party
	_load_party()

	# Create hero from first party member
	_create_hero()

	# Create followers from remaining party members
	# SF2-authentic: followers spawn at hero position, fan out as hero moves
	_create_followers()

	# Setup camera
	_setup_camera()

	# Create test battle trigger
	_create_battle_trigger()

	# Note: Exploration UI (inventory menu, depot panel) is automatically
	# provided by ExplorationUIManager autoload - no manual setup needed!

	# If returning from battle, restore hero position
	if returning_from_battle and saved_position != Vector2.ZERO:
		_restore_from_battle(saved_position)

	_debug_print("\n===========================================")
	_debug_print("CONTROLS:")
	_debug_print("  Arrow Keys - Move hero")
	_debug_print("  Enter/Z - Interact")
	_debug_print("  I - Open Inventory/Equipment Menu")
	_debug_print("  Walk into RED SQUARE to trigger battle")
	_debug_print("  ESC - Quit test")
	_debug_print("===========================================\n")


## Load party members from PartyManager or create test party.
func _load_party() -> void:
	_debug_print("\n[Loading Party]")

	# Try to load from PartyManager
	if PartyManager and PartyManager.party_members.size() > 0:
		party_characters = PartyManager.party_members.duplicate()
		_debug_print("✅ Loaded %d characters from PartyManager" % party_characters.size())
		for character in party_characters:
			if character:
				var class_name_str: String = character.character_class.display_name if character.character_class else "Unknown"
				_debug_print("  - %s (%s)" % [character.character_name, class_name_str])
	else:
		# Load test characters from mod registry and add to PartyManager
		_debug_print("⚠️  PartyManager empty, loading test party from ModRegistry...")

		# Load hero from sandbox mod (Mr Big Hero Face)
		var hero_char: CharacterData = ModLoader.registry.get_resource("character", "character_1763762722")
		if hero_char:
			party_characters.append(hero_char)
			PartyManager.add_member(hero_char)
			_debug_print("  - Loaded %s (Hero)" % hero_char.character_name)

		# Try to load some other characters for followers (only those with valid classes)
		var all_characters: Array[Resource] = ModLoader.registry.get_all_resources("character")
		for char_data: CharacterData in all_characters:
			if char_data != hero_char and party_characters.size() < 4:
				# Skip characters without a class assigned
				if not char_data.character_class:
					_debug_print("  - Skipping %s (no class assigned)" % char_data.character_name)
					continue
				party_characters.append(char_data)
				PartyManager.add_member(char_data)
				_debug_print("  - Loaded %s (%s)" % [char_data.character_name, char_data.character_class.display_name])

		_debug_print("✅ Added %d characters to PartyManager for battle" % party_characters.size())

		if party_characters.size() == 0:
			push_error("No characters found! Cannot create party.")
			return


## Create the hero controller from the first party member.
func _create_hero() -> void:
	_debug_print("\n[Creating Hero]")

	if party_characters.size() == 0:
		push_error("No party members available!")
		return

	var hero_data: CharacterData = party_characters[0]

	hero = CharacterBody2D.new()
	hero.set_script(HeroControllerScript)
	hero.name = "Hero"
	# Grid-aligned position using GridManager for consistency
	hero.position = GridManager.cell_to_world(Vector2i(10, 5))
	hero.z_index = 100  # Hero on top of all party members
	hero.add_to_group("hero")  # Required for MapTrigger detection

	# Add visual representation - prefer animated map_sprite_frames, fallback to battle_sprite
	var visual_container: Node2D = Node2D.new()
	visual_container.name = "Visual"
	hero.add_child(visual_container)

	# Priority 1: Animated map sprite (SpriteFrames with walk/idle animations)
	if hero_data.map_sprite_frames:
		var animated_sprite: AnimatedSprite2D = AnimatedSprite2D.new()
		animated_sprite.sprite_frames = hero_data.map_sprite_frames
		animated_sprite.name = "AnimatedSprite2D"  # HeroController looks for this name
		visual_container.add_child(animated_sprite)
		_debug_print("  Using animated map sprite for %s" % hero_data.character_name)
	# Priority 2: Static battle sprite
	elif hero_data.battle_sprite:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = hero_data.battle_sprite
		sprite.name = "Sprite"
		visual_container.add_child(sprite)
		_debug_print("  Using static battle sprite for %s" % hero_data.character_name)
	else:
		# Fallback: colored square if no sprites
		var sprite_rect: ColorRect = ColorRect.new()
		sprite_rect.custom_minimum_size = Vector2(28, 28)
		sprite_rect.position = Vector2(-14, -14)
		sprite_rect.color = Color(0.2, 0.8, 0.2)  # Green for hero
		sprite_rect.name = "SpriteRect"
		visual_container.add_child(sprite_rect)
		_debug_print("  Using fallback color rect for %s" % hero_data.character_name)

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

	_debug_print("✅ Hero created: %s" % hero_data.character_name)


## Create party followers from remaining party members.
## SF2-AUTHENTIC: Followers only appear in towns (caravan_visible = false)
## On overworld maps, only the hero and caravan are visible.
func _create_followers() -> void:
	_debug_print("\n[Creating Followers]")

	if not hero:
		push_error("Cannot create followers - hero not created!")
		return

	# SF2-AUTHENTIC: Check if we should show party followers
	# Followers appear in towns (caravan_visible = false)
	# On overworld (caravan_visible = true), only hero + caravan are shown
	var map_meta: MapMetadata = _get_current_map_metadata()
	if map_meta and map_meta.caravan_visible:
		_debug_print("⚠️  Overworld map - party followers hidden (caravan mode)")
		return

	# Skip first member (that's the hero)
	for i in range(1, party_characters.size()):
		var char_data: CharacterData = party_characters[i]

		var follower: CharacterBody2D = CharacterBody2D.new()
		follower.set_script(PartyFollowerScript)
		follower.name = "Follower_%s" % char_data.character_name
		follower.z_index = 90 - i  # Followers below hero, in reverse order (closer = higher)

		# CRITICAL: Hide follower until properly positioned to prevent flash at (0,0)
		follower.visible = false

		# Add visual representation - prefer animated map_sprite_frames
		var visual_container: Node2D = Node2D.new()
		visual_container.name = "Visual"
		follower.add_child(visual_container)

		# Priority 1: Animated map sprite
		if char_data.map_sprite_frames:
			var animated_sprite: AnimatedSprite2D = AnimatedSprite2D.new()
			animated_sprite.sprite_frames = char_data.map_sprite_frames
			animated_sprite.name = "AnimatedSprite2D"
			# Start with idle_down animation
			if char_data.map_sprite_frames.has_animation("idle_down"):
				animated_sprite.animation = "idle_down"
				animated_sprite.play()
			visual_container.add_child(animated_sprite)
		# Priority 2: Static battle sprite
		elif char_data.battle_sprite:
			var sprite: Sprite2D = Sprite2D.new()
			sprite.texture = char_data.battle_sprite
			sprite.name = "Sprite"
			visual_container.add_child(sprite)
		else:
			# Fallback: colored square if no sprites
			var hue: float = float(i) / float(party_characters.size())
			var follower_color: Color = Color.from_hsv(hue, 0.6, 0.9)

			var sprite_rect: ColorRect = ColorRect.new()
			sprite_rect.custom_minimum_size = Vector2(24, 24)
			sprite_rect.position = Vector2(-12, -12)
			sprite_rect.color = follower_color
			sprite_rect.name = "SpriteRect"
			visual_container.add_child(sprite_rect)

		# Collision shape
		var collision: CollisionShape2D = CollisionShape2D.new()
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = 10.0
		collision.shape = shape
		collision.name = "CollisionShape2D"
		follower.add_child(collision)

		add_child(follower)
		followers.append(follower)

		# SF2-style: Initialize follower with hero reference and formation index
		# Follower spawns at correct position relative to hero automatically
		follower.call("initialize", hero, i)

		# NOW make follower visible - they're at correct position
		follower.visible = true

		_debug_print("✅ Follower created: %s (formation index %d)" % [char_data.character_name, i])

	_debug_print("Total followers: %d" % followers.size())


## Setup camera to follow the hero.
func _setup_camera() -> void:
	_debug_print("\n[Setting up Camera]")

	camera = Camera2D.new()
	camera.set_script(MapCameraScript)
	camera.name = "MapCamera"
	camera.position = hero.position if hero else Vector2(320, 180)

	add_child(camera)

	if hero:
		camera.call("set_follow_target", hero)
		camera.call("snap_to_target")

	_debug_print("✅ Camera created and following hero")


## Restore hero and party after returning from battle.
func _restore_from_battle(saved_position: Vector2) -> void:
	_debug_print("\n[Restoring from Battle]")

	if not hero:
		push_error("Cannot restore - hero not created!")
		return

	# Restore hero's exact world position
	hero.global_position = saved_position
	hero.set("target_position", saved_position)
	hero.set("is_moving", false)

	# Calculate grid position from world position using GridManager
	var grid_pos: Vector2i = GridManager.world_to_cell(saved_position)
	hero.set("grid_position", grid_pos)

	_debug_print("✅ Hero restored to position: %s (grid: %s)" % [saved_position, grid_pos])

	# Reposition all followers relative to hero's new position
	for follower in followers:
		if follower and follower.has_method("reposition_to_hero"):
			follower.call("reposition_to_hero")
	_debug_print("✅ Followers repositioned around hero")

	# Snap camera to restored position
	if camera:
		camera.position = saved_position
		if camera.has_method("snap_to_target"):
			camera.call("snap_to_target")
		_debug_print("✅ Camera snapped to hero")

	# Clear transition context - we've used it
	GameState.clear_transition_context()
	_debug_print("✅ Transition context cleared")


## Create a battle trigger for testing the explore-battle-explore loop.
func _create_battle_trigger() -> void:
	_debug_print("\n[Creating Battle Trigger]")

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
	label.add_theme_font_size_override("font_size", 16)
	trigger.add_child(label)

	add_child(trigger)

	# Connect trigger signal to TriggerManager
	if trigger.has_signal("triggered"):
		trigger.triggered.connect(TriggerManager._on_trigger_activated)

	_debug_print("✅ Battle trigger created at (480, 180)")
	_debug_print("   Walk into the red square to start battle")


## Get the MapMetadata for the current scene.
## Returns null if no metadata found.
func _get_current_map_metadata() -> MapMetadata:
	if not ModLoader:
		return null

	# Get all map metadata and find one matching this scene
	var all_maps: Array[Resource] = ModLoader.registry.get_all_resources("map")
	for map_resource: Resource in all_maps:
		var map_meta: MapMetadata = map_resource as MapMetadata
		if map_meta and map_meta.scene_path == scene_file_path:
			return map_meta

	return null


## Handle test scene controls.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_debug_print("\n[ESC] Exiting map exploration test...")
			get_tree().quit()
		elif event.keycode == KEY_F1:
			# Debug: Show positions (always print these - explicit debug request)
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


## Draw a simple grid for reference (static - only drawn once).
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
