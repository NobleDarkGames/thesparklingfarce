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

## The player character - dynamically created from PartyManager
var hero: CharacterBody2D = null

## Camera that follows the hero
@onready var camera: Camera2D = $MapCamera

## TileMapLayer for terrain (optional - hero works without it)
@onready var tilemap: TileMapLayer = $TileMapLayer

## Container for dynamically created party followers
@onready var followers_container: Node2D = $Followers

## Party data loaded from PartyManager
var party_characters: Array[CharacterData] = []


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

	# Load party from PartyManager
	_load_party()

	# Dynamically create hero from first party member
	_create_hero()

	# Create party followers from remaining party members
	# SF2-authentic: followers spawn at hero position, fan out as hero moves
	_setup_party_followers()

	# CRITICAL: Handle transitions (restores hero position after battle/door)
	var context: RefCounted = GameState.get_transition_context()
	if context:
		await _handle_transition_context(context)
	else:
		# No transition context - use default spawn point if available
		_spawn_at_default()

	# Setup camera to follow hero
	_setup_camera()

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

	# Reposition all followers relative to hero's new position
	for follower in party_followers:
		if follower and follower.has_method("reposition_to_hero"):
			follower.reposition_to_hero()
	_debug_print("  Followers repositioned around hero")

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

			# SF2-AUTHENTIC: Reposition followers at hero's new location
			for follower in party_followers:
				if follower and follower.has_method("reposition_to_hero"):
					follower.reposition_to_hero()
			_debug_print("MapTemplate: Followers repositioned to hero")

			# Snap camera to new position
			if camera:
				camera.snap_to_target()
	# If no default spawn point, hero stays at scene-defined position


## Legacy function - redirects to new system.
## @deprecated Subclasses should use _handle_transition_context() directly.
## This function is kept for backwards compatibility with existing map subclasses.
func _restore_from_battle() -> void:
	var context: RefCounted = GameState.get_transition_context()
	if context:
		await _handle_transition_context(context)
	else:
		# Fallback: No context available, try legacy property (will warn)
		# Note: return_hero_grid_position property still works but is deprecated
		var return_pos: Vector2i = GameState.return_hero_grid_position
		if hero and hero.has_method("teleport_to_grid"):
			hero.teleport_to_grid(return_pos)
		GameState.clear_transition_context()


# =============================================================================
# DYNAMIC PARTY CREATION
# =============================================================================

## Load party members from PartyManager
func _load_party() -> void:
	_debug_print("MapTemplate: Loading party...")

	if PartyManager and PartyManager.party_members.size() > 0:
		party_characters = PartyManager.party_members.duplicate()
		_debug_print("  Loaded %d characters from PartyManager" % party_characters.size())
		for character: CharacterData in party_characters:
			if character:
				var class_name_str: String = character.character_class.display_name if character.character_class else "Unknown"
				_debug_print("    - %s (%s)" % [character.character_name, class_name_str])
	else:
		push_warning("MapTemplate: PartyManager is empty! Loading fallback test party...")
		# Fallback: try to load a character from ModRegistry
		var hero_char: CharacterData = ModLoader.registry.get_resource("character", "character_1763762722")
		if hero_char:
			party_characters.append(hero_char)
			_debug_print("  Loaded fallback hero: %s" % hero_char.character_name)

	if party_characters.is_empty():
		push_error("MapTemplate: No party members available! Cannot create hero.")


## Create the hero from the first party member
func _create_hero() -> void:
	_debug_print("MapTemplate: Creating hero...")

	if party_characters.is_empty():
		push_error("MapTemplate: Cannot create hero - no party members!")
		return

	var hero_data: CharacterData = party_characters[0]

	hero = CharacterBody2D.new()
	hero.set_script(HeroControllerScript)
	hero.name = "Hero"
	hero.z_index = 100  # Hero on top of all party members
	hero.add_to_group("hero")  # Required for MapTrigger detection
	hero.collision_mask = 2  # Match expected collision settings

	# Add visual representation using character's battle_sprite
	var visual_container: Node2D = Node2D.new()
	visual_container.name = "Visual"
	hero.add_child(visual_container)

	if hero_data.battle_sprite:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = hero_data.battle_sprite
		sprite.name = "Sprite"
		visual_container.add_child(sprite)
		_debug_print("  Using battle_sprite: %s" % hero_data.battle_sprite.resource_path)
	else:
		# Fallback: colored square if no battle_sprite
		var sprite_rect: ColorRect = ColorRect.new()
		sprite_rect.custom_minimum_size = Vector2(24, 24)
		sprite_rect.position = Vector2(-12, -12)
		sprite_rect.color = Color(0.2, 0.8, 0.2)  # Green for hero
		sprite_rect.name = "SpriteRect"
		visual_container.add_child(sprite_rect)
		_debug_print("  Using fallback green square (no battle_sprite)")

	# Collision shape
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 4.0
	collision.shape = shape
	collision.name = "CollisionShape2D"
	hero.add_child(collision)

	# Interaction ray
	var interaction_ray: RayCast2D = RayCast2D.new()
	interaction_ray.enabled = true
	interaction_ray.target_position = Vector2(32, 0)
	interaction_ray.name = "InteractionRay"
	hero.add_child(interaction_ray)

	# Add hero to scene (position will be set by spawn point handling)
	add_child(hero)

	_debug_print("  Hero created: %s" % hero_data.character_name)


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
## SF2-AUTHENTIC: Followers only appear in towns (caravan_visible = false).
## On overworld maps, only hero + caravan are visible.
## Uses actual party data from PartyManager for sprites.
func _setup_party_followers() -> void:
	_debug_print("MapTemplate: Setting up party followers...")

	if not hero:
		push_warning("MapTemplate: Cannot create followers - hero not created")
		return

	# SF2-AUTHENTIC: Check if we should show party followers
	# Followers appear in towns (caravan_visible = false)
	# On overworld (caravan_visible = true), only hero + caravan are shown
	var map_meta: MapMetadata = _get_current_map_metadata()
	if map_meta and map_meta.caravan_visible:
		_debug_print("MapTemplate: Overworld map - party followers hidden (caravan mode)")
		return

	# Skip first member (that's the hero) - create followers from remaining party
	var num_followers: int = mini(party_characters.size() - 1, MAX_VISIBLE_FOLLOWERS)

	for i: int in range(num_followers):
		var char_index: int = i + 1  # Skip hero at index 0
		var char_data: CharacterData = party_characters[char_index]

		var follower: CharacterBody2D = _create_follower(i, char_data)
		followers_container.add_child(follower)
		party_followers.append(follower)

		# SF2-style: Initialize with hero reference and formation index
		# Follower spawns at correct position relative to hero automatically
		var formation_index: int = i + 1
		follower.initialize(hero, formation_index)

		# Now make visible - follower is at correct position
		follower.visible = true

		_debug_print("  Follower %d: %s" % [formation_index, char_data.character_name])

	_debug_print("MapTemplate: Created %d party followers" % num_followers)


## Creates a single follower node from CharacterData.
## Note: formation_index is set by initialize() call in _setup_party_followers()
func _create_follower(index: int, char_data: CharacterData) -> CharacterBody2D:
	var follower: CharacterBody2D = CharacterBody2D.new()
	follower.set_script(PartyFollowerScript)
	follower.name = "Follower_%s" % char_data.character_name
	follower.z_index = 90 - index  # Followers below hero, in reverse order
	follower.visible = false  # Hide until positioned by initialize()

	# Add visual representation using character's battle_sprite
	var visual_container: Node2D = Node2D.new()
	visual_container.name = "Visual"
	follower.add_child(visual_container)

	if char_data.battle_sprite:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = char_data.battle_sprite
		sprite.name = "Sprite"
		visual_container.add_child(sprite)
	else:
		# Fallback: colored square if no battle_sprite
		var hue: float = float(index) / float(maxi(party_characters.size(), 1))
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
	shape.radius = 4.0
	collision.shape = shape
	follower.add_child(collision)

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
# MAP METADATA
# =============================================================================

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
