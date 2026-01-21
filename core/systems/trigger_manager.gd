extends Node
## TriggerManager - Autoload singleton for handling map triggers
##
## Responsibilities:
## - Automatically connect to all MapTriggers in the current scene
## - Handle BATTLE triggers (transition to battle, store return data)
## - Handle other trigger types (DIALOG, CHEST, DOOR, etc.) in future phases
## - Coordinate scene transitions with SceneManager
##
## Integration points:
## - MapTrigger: Listens to triggered signals
## - GameState: Stores return scene/position data
## - ModLoader: Looks up BattleData by ID
## - SceneManager: Handles scene transitions
## - BattleManager: Starts battles with BattleData

## Emitted when returning from battle (for map scenes to handle restoration)
signal returned_from_battle()

## Emitted when a door transition begins (for UI effects, audio, etc.)
signal door_transition_started(from_map: String, to_map: String)

## Emitted when a door transition completes and spawn point is resolved
signal door_transition_completed(spawn_point_id: String)

## Preload TransitionContext for door transitions
const TransitionContext = preload("res://core/resources/transition_context.gd")

## LOW-001: Constants for trigger type strings
const TRIGGER_TYPE_BATTLE: String = "battle"
const TRIGGER_TYPE_DIALOG: String = "dialog"
const TRIGGER_TYPE_DOOR: String = "door"
const TRIGGER_TYPE_CUTSCENE: String = "cutscene"
const TRIGGER_TYPE_TRANSITION: String = "transition"
const TRIGGER_TYPE_CUSTOM: String = "custom"

## Track connected triggers to avoid duplicate connections
var connected_triggers: Array[Node] = []


func _ready() -> void:
	# Defer connecting to SceneManager to ensure it's fully initialized
	call_deferred("_connect_to_scene_manager")


## Connect to SceneManager after initialization
func _connect_to_scene_manager() -> void:
	if SceneManager:
		SceneManager.scene_transition_completed.connect(_on_scene_changed)
	else:
		push_error("TriggerManager: SceneManager not found!")


## Called when a scene transition completes
func _on_scene_changed(_scene_path: String) -> void:
	# CRIT-002: Store scene path before await to verify it hasn't changed
	# Resolve UID to path for consistent comparison (UIDs don't match scene_file_path)
	var expected_scene: String = _scene_path
	if expected_scene.begins_with("uid://"):
		var resolved: String = ResourceUID.get_id_path(ResourceUID.text_to_id(expected_scene))
		if not resolved.is_empty():
			expected_scene = resolved

	# Clear old connections
	_disconnect_all_triggers()

	# Wait one frame for scene to fully initialize
	await get_tree().process_frame

	# CRIT-002: Verify scene hasn't changed during await
	var current_scene: Node = get_tree().current_scene
	var current_path: String = current_scene.scene_file_path if current_scene else ""
	
	if current_scene and current_path != expected_scene:
		return  # Scene changed during await, abort

	# Find and connect to all triggers in the new scene
	_connect_to_scene_triggers()


## Find all MapTriggers in the current scene and connect to them
func _connect_to_scene_triggers() -> void:
	var root: Window = get_tree().root
	var current_scene: Node = root.get_child(root.get_child_count() - 1)

	# Recursively find all MapTrigger nodes
	var triggers: Array[Node] = _find_all_triggers(current_scene)

	for trigger: Node in triggers:
		_connect_trigger(trigger)


## Recursively find all MapTrigger nodes in a scene tree
func _find_all_triggers(node: Node) -> Array[Node]:
	var triggers: Array[Node] = []

	# Check if this node is a MapTrigger (duck typing - check for trigger_type property)
	if node.get("trigger_type") != null and node.has_signal("triggered"):
		triggers.append(node)

	# Recursively check children
	for child: Node in node.get_children():
		triggers.append_array(_find_all_triggers(child))

	return triggers


## Connect to a single trigger
func _connect_trigger(trigger: Node) -> void:
	if trigger in connected_triggers:
		return  # Already connected

	# Connect to triggered signal
	if not trigger.triggered.is_connected(_on_trigger_activated):
		trigger.triggered.connect(_on_trigger_activated)
		connected_triggers.append(trigger)


## Disconnect from all triggers
func _disconnect_all_triggers() -> void:
	for trigger: Node in connected_triggers:
		if is_instance_valid(trigger) and trigger.triggered.is_connected(_on_trigger_activated):
			trigger.triggered.disconnect(_on_trigger_activated)

	connected_triggers.clear()


## Called when any trigger is activated
func _on_trigger_activated(trigger: Node, player: Node2D) -> void:
	# CRIT-006: Validate trigger is still valid (may have been freed)
	if not is_instance_valid(trigger):
		push_warning("TriggerManager: Trigger was freed before handling")
		return

	# Get trigger type as string (supports both enum and string-based types)
	var type_name: String = _get_trigger_type_string(trigger)

	# Route to appropriate handler based on type string
	# LOW-001: Use constants for trigger type strings
	match type_name:
		TRIGGER_TYPE_BATTLE:
			_handle_battle_trigger(trigger, player)
		TRIGGER_TYPE_DIALOG:
			_handle_dialog_trigger(trigger, player)
		TRIGGER_TYPE_DOOR:
			_handle_door_trigger(trigger, player)
		TRIGGER_TYPE_CUTSCENE:
			_handle_cutscene_trigger(trigger, player)
		TRIGGER_TYPE_TRANSITION:
			_handle_transition_trigger(trigger, player)
		TRIGGER_TYPE_CUSTOM:
			push_warning("TriggerManager: TriggerType.CUSTOM is deprecated. Use trigger_type_string with a registered handler script, or use CUTSCENE triggers with custom cinematic commands.")
			_handle_modded_trigger(trigger, player, type_name)
		_:
			# Check for registered custom trigger handler
			_handle_modded_trigger(trigger, player, type_name)


## Get the trigger type as a string (works with both enum and string-based triggers)
func _get_trigger_type_string(trigger: Node) -> String:
	# Check for string-based type first (Phase 2.5.1+)
	if trigger.has_method("get_trigger_type_name"):
		return trigger.get_trigger_type_name()

	# Fall back to checking trigger_type_string property
	var type_string: Variant = trigger.get("trigger_type_string")
	if type_string is String and not type_string.is_empty():
		return type_string.to_lower()

	# Legacy: Convert enum to string
	var trigger_type: Variant = trigger.get("trigger_type")
	if trigger_type is int:
		match trigger_type:
			0: return "battle"
			1: return "dialog"
			2: return "chest"
			3: return "door"
			4: return "cutscene"
			5: return "transition"
			6: return "custom"

	return "custom"


## Handle a modded trigger type (not built-in)
## Custom trigger handlers must define a static function:
##   static func handle_trigger(trigger: Node, player: Node2D, manager: Node) -> void
func _handle_modded_trigger(trigger: Node, player: Node2D, type_name: String) -> void:
	# Check if there's a registered handler script for this type
	var script_path: String = ModLoader.trigger_type_registry.get_trigger_script_path(type_name)

	if not script_path.is_empty():
		# Load the custom trigger script
		var script: GDScript = load(script_path) as GDScript
		if script:
			# Verify the static handle_trigger method exists by checking script method list
			# Note: has_method() checks instance methods, not static methods
			# For static methods, we check the script's method_list directly
			var has_static_handler: bool = false
			for method_info: Dictionary in script.get_script_method_list():
				if method_info.get("name", "") == "handle_trigger":
					has_static_handler = true
					break
			
			if has_static_handler:
				script.handle_trigger(trigger, player, self)
				return
			else:
				push_error("TriggerManager: Script '%s' is missing static handle_trigger() method" % script_path)
				return
		else:
			push_error("TriggerManager: Failed to load trigger script: %s" % script_path)

	# Check if trigger type is at least registered (even without a handler)
	if ModLoader.trigger_type_registry.is_valid_trigger_type(type_name):
		push_warning("TriggerManager: Trigger type '%s' is registered but has no handler script" % type_name)
	else:
		push_warning("TriggerManager: Unknown trigger type: '%s'" % type_name)


## Handle BATTLE trigger - transition to battle scene
func _handle_battle_trigger(trigger: Node, player: Node2D) -> void:
	var trigger_data: Dictionary = trigger.get("trigger_data")
	# LOW-002: Use .get() with default instead of ternary pattern
	var battle_id: String = trigger_data.get("battle_id", "")

	if battle_id.is_empty():
		push_error("TriggerManager: Battle trigger missing battle_id")
		return

	# Look up BattleData resource from ModLoader
	var battle_data: BattleData = ModLoader.registry.get_battle(battle_id)

	if not battle_data:
		push_error("TriggerManager: Failed to find BattleData for ID: %s" % battle_id)
		push_error("  Make sure the battle exists in mods/*/data/battles/")
		return

	# Store return data in GameState using TransitionContext
	var context: TransitionContext = TransitionContext.new()
	var current_scene: Node = get_tree().current_scene
	if current_scene:
		context.return_scene_path = current_scene.scene_file_path
	else:
		push_error("TriggerManager: No current scene when creating battle transition context")
		context.return_scene_path = ""
	context.hero_world_position = player.global_position
	context.hero_grid_position = player.get("grid_position") if player.get("grid_position") != null else Vector2i.ZERO
	if player.get("facing_direction"):
		context.hero_facing = player.facing_direction

	GameState.set_transition_context(context)

	# Transition to battle scene (will load the battle_loader scene)
	# We need to pass the battle_data to the battle scene somehow
	# For now, store it in GameState temporarily
	_current_battle_data = battle_data

	# Use the engine's battle_loader scene
	SceneManager.change_scene("res://scenes/battle_loader.tscn")


## Temporary storage for battle data (will be picked up by battle scene)
var _current_battle_data: BattleData = null


## Get the current battle data (called by battle scenes)
func get_current_battle_data() -> BattleData:
	return _current_battle_data


## Clear current battle data
func clear_current_battle_data() -> void:
	_current_battle_data = null


## Start a battle programmatically (from menus, save loading, etc.)
## @param battle_id: The registry ID of the battle to start
func start_battle(battle_id: String) -> void:
	var battle_data: BattleData = ModLoader.registry.get_battle(battle_id)
	if not battle_data:
		push_error("TriggerManager: Battle '%s' not found in registry" % battle_id)
		var available: Array[String] = ModLoader.registry.get_resource_ids("battle")
		push_error("  Available battles: %s" % available)
		return

	start_battle_with_data(battle_data)


## Start a battle with direct BattleData reference
## @param battle_data: The BattleData resource to use
func start_battle_with_data(battle_data: BattleData) -> void:
	if not battle_data:
		push_error("TriggerManager: Cannot start battle with null data")
		return

	_capture_transition_context()
	_current_battle_data = battle_data
	SceneManager.change_scene("res://scenes/battle_loader.tscn")


## Create and store transition context for battle return
func _capture_transition_context() -> void:
	var current_scene: Node = get_tree().current_scene
	if not current_scene:
		return

	var context: TransitionContext = TransitionContext.new()
	context.return_scene_path = current_scene.scene_file_path

	var heroes: Array[Node] = get_tree().get_nodes_in_group("hero")
	if heroes.size() > 0:
		var hero: Node2D = heroes[0] as Node2D
		if hero:
			context.hero_world_position = hero.global_position
			context.hero_grid_position = hero.get("grid_position") if hero.get("grid_position") != null else Vector2i.ZERO
			if hero.get("facing_direction"):
				context.hero_facing = hero.facing_direction

	GameState.set_transition_context(context)


## Return to map after battle ends
func return_to_map() -> void:
	var context: TransitionContext = GameState.get_transition_context()
	if not context or not context.is_valid():
		push_warning("TriggerManager: No transition context available")
		return

	var return_scene: String = context.return_scene_path

	# Validate return scene exists
	if return_scene.is_empty():
		push_error("TriggerManager: Return scene path is empty!")
		GameState.clear_transition_context()
		return

	if not ResourceLoader.exists(return_scene):
		push_error("TriggerManager: Return scene not found: %s" % return_scene)
		GameState.clear_transition_context()
		return

	# Clear battle data (but NOT transition context - map scene needs it for position restoration)
	clear_current_battle_data()

	# Transition back to map and wait for completion
	var transition_result: Variant = await SceneManager.change_scene(return_scene)

	# CRIT-003: Verify transition succeeded before emitting signal
	if transition_result == null or (transition_result is bool and not transition_result):
		push_warning("TriggerManager: Scene transition may have failed")

	# Signal that we've returned (map scene can connect to this if needed)
	returned_from_battle.emit()


## Handle DIALOG trigger - show dialogue
func _handle_dialog_trigger(trigger: Node, _player: Node2D) -> void:
	var trigger_data: Dictionary = trigger.get("trigger_data")
	# LOW-002: Use .get() with default instead of ternary pattern
	var dialog_id: String = trigger_data.get("dialog_id", "")

	if dialog_id.is_empty():
		push_warning("TriggerManager: Dialog trigger missing dialog_id")
		return


	# Look up DialogueData resource
	var dialogue_data: DialogueData = ModLoader.registry.get_dialogue(dialog_id)

	if not dialogue_data:
		push_error("TriggerManager: Failed to find DialogueData for ID: %s" % dialog_id)
		return

	# Start dialogue (method is start_dialog_from_resource, not start_dialogue)
	DialogManager.start_dialog_from_resource(dialogue_data)


## Handle DOOR trigger - scene transition
## Enhanced to support MapMetadata-based transitions with spawn point resolution
##
## Supported trigger_data fields:
##   destination_scene: String - Direct scene path (legacy)
##   target_map_id: String - MapMetadata ID (preferred, looked up in registry)
##   spawn_point / target_spawn_id: String - Spawn point ID in destination
##   transition_type: String - "fade", "instant", "scroll" (default: "fade")
##   requires_key: String - Item ID if door is locked
func _handle_door_trigger(trigger: Node, player: Node2D) -> void:
	var trigger_data: Dictionary = trigger.get("trigger_data")
	# LOW-002: Use .get() with default or str() for cleaner null handling
	var trigger_id_val: Variant = trigger.get("trigger_id")
	var trigger_id: String = str(trigger_id_val) if trigger_id_val else ""

	# Determine destination scene path
	var destination_scene: String = ""
	# LOW-002: Use .get() with default instead of ternary pattern
	var target_map_id: String = trigger_data.get("target_map_id", "")

	if not target_map_id.is_empty():
		# New style: Look up MapMetadata from registry
		var map_metadata: MapMetadata = ModLoader.registry.get_map(target_map_id)
		if map_metadata:
			destination_scene = map_metadata.scene_path
		else:
			push_error("TriggerManager: MapMetadata not found for ID: %s" % target_map_id)
			return
	else:
		# Legacy style: Direct scene path
		destination_scene = trigger_data["destination_scene"] if "destination_scene" in trigger_data else ""

	if destination_scene.is_empty():
		push_warning("TriggerManager: Door trigger missing destination_scene or target_map_id")
		return

	# Get spawn point ID (support both old and new field names)
	var spawn_point_id: String = trigger_data["target_spawn_id"] if "target_spawn_id" in trigger_data else ""
	if spawn_point_id.is_empty():
		spawn_point_id = trigger_data["spawn_point"] if "spawn_point" in trigger_data else ""

	# Check for locked door (requires key item)
	var requires_key: String = trigger_data["requires_key"] if "requires_key" in trigger_data else ""
	if not requires_key.is_empty():
		if not _party_has_item(requires_key):
			# Show locked door message and abort transition
			var item_data: ItemData = ModLoader.registry.get_resource("item", requires_key) as ItemData
			var item_name: String = item_data.item_name if item_data else requires_key
			if DialogManager:
				DialogManager.show_message("The door is locked. You need the %s." % item_name)
			return

	# Create transition context with spawn point info
	var context: TransitionContext = TransitionContext.from_current_scene(player)
	context.spawn_point_id = spawn_point_id

	# Store any extra transition data
	var transition_type: String = trigger_data["transition_type"] if "transition_type" in trigger_data else "fade"
	context.set_extra("transition_type", transition_type)
	context.set_extra("source_trigger_id", trigger_id)

	# Store transition context in GameState
	GameState.set_transition_context(context)

	# Emit signal for any listeners (UI animations, etc.)
	door_transition_started.emit(context.return_scene_path, destination_scene)

	# Transition to new scene
	match transition_type:
		"instant":
			SceneManager.change_scene(destination_scene, false)  # No fade
		_:  # Default: fade
			SceneManager.change_scene(destination_scene)


## Handle CUTSCENE trigger
func _handle_cutscene_trigger(trigger: Node, player: Node2D) -> void:
	var trigger_data: Dictionary = trigger.get("trigger_data")
	var cinematic_id: String = trigger_data["cinematic_id"] if "cinematic_id" in trigger_data else ""

	if cinematic_id.is_empty():
		push_warning("TriggerManager: Cutscene trigger missing cinematic_id")
		return

	# Validate cinematic exists before playing
	var cinematic_data: CinematicData = ModLoader.registry.get_cinematic(cinematic_id)
	if not cinematic_data:
		push_error("TriggerManager: Cinematic '%s' not found in registry" % cinematic_id)
		return

	# Stop hero movement immediately to prevent walking through the trigger
	if player.has_method("stop_movement"):
		player.stop_movement()

	# Play the cinematic (CinematicsManager handles input blocking and async)
	CinematicsManager.play_cinematic(cinematic_id)


## Handle TRANSITION trigger - teleport within same scene
func _handle_transition_trigger(trigger: Node, player: Node2D) -> void:
	var trigger_data: Dictionary = trigger.get("trigger_data")
	var target_position: Vector2i = trigger_data["target_position"] if "target_position" in trigger_data else Vector2i.ZERO

	if target_position == Vector2i.ZERO:
		push_warning("TriggerManager: Transition trigger missing target_position")
		return


	# Teleport player
	if player.has_method("teleport_to_grid"):
		player.teleport_to_grid(target_position)
	else:
		push_warning("TriggerManager: Player doesn't have teleport_to_grid method")


# =============================================================================
# HELPERS
# =============================================================================

## Check if any party member has a specific item in their inventory
## @param item_id: ID of the item to check for
## @return: true if any party member has the item
func _party_has_item(item_id: String) -> bool:
	if not PartyManager:
		return false
	for character: CharacterData in PartyManager.party_members:
		var save_data: CharacterSaveData = PartyManager.get_member_save_data(character.character_uid)
		if save_data and save_data.has_item_in_inventory(item_id):
			return true
	return false
