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
const DialogBoxScene: PackedScene = preload("res://scenes/ui/dialog_box.tscn")

## Default sprite assets from core
const DEFAULT_SPRITESHEET_PATH: String = "res://core/assets/defaults/sprites/default_character_spritesheet.png"
const DEFAULT_FRAME_SIZE: Vector2i = Vector2i(32, 32)


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

## UI layer for dialog box (dynamically created)
var ui_layer: CanvasLayer = null

## Dialog box for NPC conversations
var dialog_box: Control = null

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

	# Setup dialog box for NPC conversations
	_setup_dialog_box()

	# Connect hero signals for custom behavior
	_connect_hero_signals()

	_debug_print("MapTemplate: Ready! Arrow keys to move, Space/Enter to interact")


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

	# Add visual representation using character's sprite_frames
	var visual_container: Node2D = Node2D.new()
	visual_container.name = "Visual"
	hero.add_child(visual_container)

	# Create animated sprite - use character's sprite_frames or default fallback
	var animated_sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	animated_sprite.name = "AnimatedSprite2D"  # HeroController looks for this name

	if hero_data.sprite_frames:
		animated_sprite.sprite_frames = hero_data.sprite_frames
		_debug_print("  Using character sprite for %s" % hero_data.character_name)
	else:
		# Use core default spritesheet as fallback
		animated_sprite.sprite_frames = _create_default_sprite_frames()
		animated_sprite.modulate = Color(0.2, 0.8, 0.2)  # Green tint for hero
		_debug_print("  Using default fallback sprite for %s" % hero_data.character_name)

	visual_container.add_child(animated_sprite)

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
# DIALOG BOX SETUP
# =============================================================================

## Creates UI layer and dialog box for NPC conversations.
## Registers the dialog box with DialogManager so cinematics can show dialog.
func _setup_dialog_box() -> void:
	# Create UI layer (renders above game world)
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UILayer"
	ui_layer.layer = 10  # Above game elements
	add_child(ui_layer)

	# Instantiate dialog box
	dialog_box = DialogBoxScene.instantiate()
	dialog_box.hide()  # Start hidden
	ui_layer.add_child(dialog_box)

	# Register with DialogManager
	if DialogManager:
		DialogManager.dialog_box = dialog_box
		_debug_print("MapTemplate: Dialog box registered with DialogManager")
	else:
		push_warning("MapTemplate: DialogManager not available - dialog won't display")


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

	# Add visual representation using character's sprite_frames
	var visual_container: Node2D = Node2D.new()
	visual_container.name = "Visual"
	follower.add_child(visual_container)

	# Create animated sprite - use character's sprite_frames or default fallback
	var animated_sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	animated_sprite.name = "AnimatedSprite2D"

	if char_data.sprite_frames:
		animated_sprite.sprite_frames = char_data.sprite_frames
	else:
		# Use core default spritesheet with unique color per follower
		animated_sprite.sprite_frames = _create_default_sprite_frames()
		var hue: float = float(index) / float(maxi(party_characters.size(), 1))
		animated_sprite.modulate = Color.from_hsv(hue, 0.6, 0.9)

	# Start with idle_down animation if available
	if animated_sprite.sprite_frames.has_animation("idle_down"):
		animated_sprite.animation = "idle_down"
		animated_sprite.play()

	visual_container.add_child(animated_sprite)

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
## Handles NPC interactions automatically; override to add custom behavior.
## SF2-authentic: Opens field menu if no interaction target found.
func _on_hero_interaction(interaction_pos: Vector2i) -> void:
	_debug_print("MapTemplate: Interaction at tile %s" % interaction_pos)

	# Check for NPCs at interaction position
	var npc: Node = _find_npc_at_position(interaction_pos)
	if npc:
		_debug_print("MapTemplate: Found NPC at interaction position: %s" % npc.name)
		if npc.has_method("interact"):
			npc.interact(hero)
			return

	# Check for other interactables (signs, chests, etc.)
	var interactable: Node = _find_interactable_at_position(interaction_pos)
	if interactable:
		_debug_print("MapTemplate: Found interactable at position: %s" % interactable.name)
		if interactable.has_method("interact"):
			interactable.interact(hero)
			return

	# Check if caravan is handling this interaction
	# CaravanController handles its own interaction via the same signal,
	# so we just need to avoid opening field menu if caravan is the target
	if _is_caravan_interaction(interaction_pos):
		_debug_print("MapTemplate: Caravan handling interaction")
		return

	# No interaction target found - open field menu
	# This is SF2-authentic behavior: confirm in empty space = field menu
	_open_field_menu()


## Find an NPC at the given grid position.
## Returns the first NPC found at that position, or null if none.
func _find_npc_at_position(grid_pos: Vector2i) -> Node:
	# Get all nodes in the "npcs" group
	var npcs: Array[Node] = get_tree().get_nodes_in_group("npcs")

	for npc: Node in npcs:
		# Check if NPC has grid_position property or method
		if npc.has_method("is_at_grid_position"):
			if npc.is_at_grid_position(grid_pos):
				return npc
		elif "grid_position" in npc:
			if npc.grid_position == grid_pos:
				return npc
		else:
			# Fallback: convert world position to grid
			if "global_position" in npc:
				var npc_grid: Vector2i = GridManager.world_to_cell(npc.global_position)
				if npc_grid == grid_pos:
					return npc

	return null


## Find an interactable (sign, chest, etc.) at the given grid position.
## Returns the first interactable found at that position, or null if none.
func _find_interactable_at_position(grid_pos: Vector2i) -> Node:
	# Get all nodes in the "interactables" group
	var interactables: Array[Node] = get_tree().get_nodes_in_group("interactables")

	for interactable: Node in interactables:
		# Check if interactable has grid_position property or method
		if interactable.has_method("is_at_grid_position"):
			if interactable.is_at_grid_position(grid_pos):
				return interactable
		elif "grid_position" in interactable:
			if interactable.grid_position == grid_pos:
				return interactable
		else:
			# Fallback: convert world position to grid
			if "global_position" in interactable:
				var interactable_grid: Vector2i = GridManager.world_to_cell(interactable.global_position)
				if interactable_grid == grid_pos:
					return interactable

	return null


## Check if the interaction is targeting the caravan.
## Returns true if caravan is spawned and either:
## - interaction_pos matches caravan position, OR
## - hero is standing on the caravan (overlap from following behavior)
func _is_caravan_interaction(interaction_pos: Vector2i) -> bool:
	if not CaravanController:
		return false

	if not CaravanController.is_spawned():
		return false

	var caravan_pos: Vector2i = CaravanController.get_grid_position()

	# Check if facing the caravan
	if interaction_pos == caravan_pos:
		return true

	# Check if hero is standing on the caravan (overlap case)
	if hero and "grid_position" in hero:
		if hero.grid_position == caravan_pos:
			return true

	return false


## Open the exploration field menu
## Called when hero interacts with empty space (SF2-authentic behavior)
func _open_field_menu() -> void:
	if not hero:
		push_warning("MapTemplate: Cannot open field menu - no hero")
		return

	# Get exploration UI controller reference
	var exploration_ui: Node = _get_exploration_ui_controller()
	if not exploration_ui:
		_debug_print("MapTemplate: No ExplorationUIController found - field menu unavailable")
		return

	if not exploration_ui.has_method("open_field_menu"):
		push_warning("MapTemplate: ExplorationUIController does not have open_field_menu method")
		return

	# Get hero's screen position for menu positioning
	var hero_screen_pos: Vector2 = hero.get_global_transform_with_canvas().origin

	# Open field menu
	exploration_ui.open_field_menu(hero.grid_position, hero_screen_pos)
	_debug_print("MapTemplate: Opened field menu at hero position %s" % hero.grid_position)


## Get the ExplorationUIController for this scene
## Override in subclasses if you have a custom setup
func _get_exploration_ui_controller() -> Node:
	# Try to get from hero's ui_controller reference
	if hero and "ui_controller" in hero and hero.ui_controller:
		return hero.ui_controller

	# Fallback: search for ExplorationUIController in scene tree
	for child: Node in get_children():
		if child is ExplorationUIController:
			return child

	return null


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
# SPRITE UTILITIES
# =============================================================================

## Create SpriteFrames from the core default spritesheet
## Spritesheet format: 64x128 (2 columns x 4 rows of 32x32 frames)
## Rows: down, left, right, up (standard 4-direction layout)
func _create_default_sprite_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()

	# Remove default animation if present
	if frames.has_animation("default"):
		frames.remove_animation("default")

	# Try to load the default spritesheet
	var spritesheet: Texture2D = load(DEFAULT_SPRITESHEET_PATH)
	if not spritesheet:
		push_warning("MapTemplate: Could not load default spritesheet at %s" % DEFAULT_SPRITESHEET_PATH)
		# Return empty frames - will show nothing but won't crash
		frames.add_animation("idle_down")
		return frames

	# Create atlas textures for each frame
	# Row 0: down, Row 1: left, Row 2: right, Row 3: up
	var directions: Array[String] = ["idle_down", "idle_left", "idle_right", "idle_up"]

	for row: int in range(4):
		var anim_name: String = directions[row]
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, true)
		frames.set_animation_speed(anim_name, 4.0)

		for col: int in range(2):
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = spritesheet
			atlas.region = Rect2(
				col * DEFAULT_FRAME_SIZE.x,
				row * DEFAULT_FRAME_SIZE.y,
				DEFAULT_FRAME_SIZE.x,
				DEFAULT_FRAME_SIZE.y
			)
			frames.add_frame(anim_name, atlas)

	return frames


# =============================================================================
# DEBUG UTILITIES
# =============================================================================

## Prints debug messages when DEBUG_VERBOSE is enabled.
func _debug_print(msg: String) -> void:
	if DEBUG_VERBOSE:
		print(msg)


## Debug input handling (remove or disable in production).
func _input(event: InputEvent) -> void:
	# Don't process game input while debug console is open
	if DebugConsole and DebugConsole.is_open:
		return

	# ESC to return to main menu (when implemented)
	if event.is_action_pressed("ui_cancel"):
		_debug_print("MapTemplate: ESC pressed")
		# SceneManager.change_scene("res://scenes/ui/main_menu.tscn")

	# Debug teleport (T key)
	if DEBUG_VERBOSE and event is InputEventKey:
		if event.pressed and event.keycode == KEY_T and hero:
			hero.teleport_to_grid(Vector2i(5, 5))
			_debug_print("MapTemplate: Debug teleported to (5, 5)")
