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
const TransitionContext: GDScript = preload("res://core/resources/transition_context.gd")

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
	# Clear old connections
	_disconnect_all_triggers()

	# Wait one frame for scene to fully initialize
	await get_tree().process_frame

	# Find and connect to all triggers in the new scene
	_connect_to_scene_triggers()


## Find all MapTriggers in the current scene and connect to them
func _connect_to_scene_triggers() -> void:
	var root: Window = get_tree().root
	var current_scene: Node = root.get_child(root.get_child_count() - 1)

	# Recursively find all MapTrigger nodes
	var triggers: Array[Node] = _find_all_triggers(current_scene)

	for trigger in triggers:
		_connect_trigger(trigger)


## Recursively find all MapTrigger nodes in a scene tree
func _find_all_triggers(node: Node) -> Array[Node]:
	var triggers: Array[Node] = []

	# Check if this node is a MapTrigger (duck typing - check for trigger_type property)
	if node.get("trigger_type") != null and node.has_signal("triggered"):
		triggers.append(node)

	# Recursively check children
	for child in node.get_children():
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
	for trigger in connected_triggers:
		if is_instance_valid(trigger) and trigger.triggered.is_connected(_on_trigger_activated):
			trigger.triggered.disconnect(_on_trigger_activated)

	connected_triggers.clear()


## Called when any trigger is activated
func _on_trigger_activated(trigger: Node, player: Node2D) -> void:
	# CRIT-006: Validate trigger is still valid (may have been freed)
	if not is_instance_valid(trigger):
		push_warning("TriggerManager: Trigger was freed before handling")
		return

	var trigger_type: int = trigger.get("trigger_type")
	var trigger_id: String = trigger.get("trigger_id")
	print("[FLOW] Trigger: %s (%s)" % [trigger_id, _get_trigger_type_name(trigger_type)])

	# Route to appropriate handler based on type
	match trigger_type:
		0:  # MapTrigger.TriggerType.BATTLE
			_handle_battle_trigger(trigger, player)
		1:  # MapTrigger.TriggerType.DIALOG
			_handle_dialog_trigger(trigger, player)
		2:  # MapTrigger.TriggerType.CHEST
			_handle_chest_trigger(trigger, player)
		3:  # MapTrigger.TriggerType.DOOR
			_handle_door_trigger(trigger, player)
		4:  # MapTrigger.TriggerType.CUTSCENE
			_handle_cutscene_trigger(trigger, player)
		5:  # MapTrigger.TriggerType.TRANSITION
			_handle_transition_trigger(trigger, player)
		6:  # MapTrigger.TriggerType.CUSTOM
			_handle_custom_trigger(trigger, player)
		_:
			push_warning("TriggerManager: Unknown trigger type: %d" % trigger_type)


## Handle BATTLE trigger - transition to battle scene
func _handle_battle_trigger(trigger: Node, player: Node2D) -> void:
	var trigger_data: Dictionary = trigger.get("trigger_data")
	var battle_id: String = trigger_data.get("battle_id", "")

	if battle_id.is_empty():
		push_error("TriggerManager: Battle trigger missing battle_id")
		return

	print("[FLOW] Loading battle: %s" % battle_id)

	# Look up BattleData resource from ModLoader
	var battle_data: Resource = ModLoader.registry.get_resource("battle", battle_id)

	if not battle_data:
		push_error("TriggerManager: Failed to find BattleData for ID: %s" % battle_id)
		push_error("  Make sure the battle exists in mods/*/data/battles/")
		return

	# Store return data in GameState
	var current_scene_path: String = get_tree().current_scene.scene_file_path
	var hero_position: Vector2 = player.global_position
	var hero_grid_position: Vector2i = player.get("grid_position") if player.get("grid_position") != null else Vector2i.ZERO

	GameState.set_return_data(current_scene_path, hero_position, hero_grid_position)

	# Transition to battle scene (will load the battle_loader scene)
	# We need to pass the battle_data to the battle scene somehow
	# For now, store it in GameState temporarily
	_current_battle_data = battle_data

	# Use the engine's battle_loader scene
	SceneManager.change_scene("res://scenes/battle_loader.tscn")


## Temporary storage for battle data (will be picked up by battle scene)
var _current_battle_data: Resource = null


## Get the current battle data (called by battle scenes)
func get_current_battle_data() -> Resource:
	return _current_battle_data


## Clear current battle data
func clear_current_battle_data() -> void:
	_current_battle_data = null


## Start a battle programmatically (from menus, save loading, etc.)
## @param battle_id: The registry ID of the battle to start
func start_battle(battle_id: String) -> void:
	var battle_data: Resource = ModLoader.registry.get_resource("battle", battle_id)
	if not battle_data:
		push_error("TriggerManager: Battle '%s' not found in registry" % battle_id)
		var available: Array[String] = ModLoader.registry.get_resource_ids("battle")
		push_error("  Available battles: %s" % available)
		return

	print("[FLOW] Starting battle: '%s'" % battle_data.get("battle_name"))
	_current_battle_data = battle_data
	SceneManager.change_scene("res://scenes/battle_loader.tscn")


## Start a battle with direct BattleData reference
## @param battle_data: The BattleData resource to use
func start_battle_with_data(battle_data: Resource) -> void:
	if not battle_data:
		push_error("TriggerManager: Cannot start battle with null data")
		return

	print("[FLOW] Starting battle: '%s'" % battle_data.get("battle_name"))
	_current_battle_data = battle_data
	SceneManager.change_scene("res://scenes/battle_loader.tscn")


## Return to map after battle ends
func return_to_map() -> void:
	if not GameState.has_return_data():
		push_warning("TriggerManager: No return data available")
		return

	var return_scene: String = GameState.return_scene_path

	# Validate return scene exists
	if return_scene.is_empty():
		push_error("TriggerManager: Return scene path is empty!")
		GameState.clear_transition_context()
		return

	if not ResourceLoader.exists(return_scene):
		push_error("TriggerManager: Return scene not found: %s" % return_scene)
		GameState.clear_transition_context()
		return

	print("[FLOW] Returning to map: %s" % return_scene.get_file())

	# Clear battle data (but NOT transition context - map scene needs it for position restoration)
	clear_current_battle_data()

	# Transition back to map
	SceneManager.change_scene(return_scene)

	# Wait for scene transition to complete before emitting signal
	# Map scene will handle restoration in its _ready() using GameState.has_return_data()
	if SceneManager.has_method("is_transitioning") and SceneManager.is_transitioning:
		await SceneManager.scene_transition_completed
	elif SceneManager.has_signal("scene_transition_completed"):
		await SceneManager.scene_transition_completed

	# Signal that we've returned (map scene can connect to this if needed)
	returned_from_battle.emit()


## Handle DIALOG trigger - show dialogue
func _handle_dialog_trigger(trigger: Node, player: Node2D) -> void:
	var trigger_data: Dictionary = trigger.get("trigger_data")
	var dialog_id: String = trigger_data.get("dialog_id", "")

	if dialog_id.is_empty():
		push_warning("TriggerManager: Dialog trigger missing dialog_id")
		return


	# Look up DialogueData resource
	var dialogue_data: Resource = ModLoader.registry.get_resource("dialogue", dialog_id)

	if not dialogue_data:
		push_error("TriggerManager: Failed to find DialogueData for ID: %s" % dialog_id)
		return

	# Start dialogue
	DialogManager.start_dialogue(dialogue_data)


## Handle CHEST trigger - grant rewards
func _handle_chest_trigger(trigger: Node, _player: Node2D) -> void:
	var _trigger_data: Dictionary = trigger.get("trigger_data")
	# TODO: Phase 4 - implement item/gold rewards
	pass


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
	var trigger_id: String = trigger.get("trigger_id") if trigger.get("trigger_id") else ""

	# Determine destination scene path
	var destination_scene: String = ""
	var target_map_id: String = trigger_data.get("target_map_id", "")

	if not target_map_id.is_empty():
		# New style: Look up MapMetadata from registry
		var map_metadata: Resource = ModLoader.registry.get_resource("map", target_map_id)
		if map_metadata:
			destination_scene = map_metadata.scene_path
		else:
			push_error("TriggerManager: MapMetadata not found for ID: %s" % target_map_id)
			return
	else:
		# Legacy style: Direct scene path
		destination_scene = trigger_data.get("destination_scene", "")

	if destination_scene.is_empty():
		push_warning("TriggerManager: Door trigger missing destination_scene or target_map_id")
		return

	# Get spawn point ID (support both old and new field names)
	var spawn_point_id: String = trigger_data.get("target_spawn_id", "")
	if spawn_point_id.is_empty():
		spawn_point_id = trigger_data.get("spawn_point", "")

	# Check for locked door (requires key item)
	var requires_key: String = trigger_data.get("requires_key", "")
	if not requires_key.is_empty():
		# TODO: Check if player has key item in inventory
		pass

	print("[FLOW] Door -> %s (spawn: %s)" % [destination_scene.get_file(), spawn_point_id])

	# Create transition context with spawn point info
	var context: RefCounted = TransitionContext.from_current_scene(player)
	context.spawn_point_id = spawn_point_id

	# Store any extra transition data
	var transition_type: String = trigger_data.get("transition_type", "fade")
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
		"scroll":
			# TODO: Implement scroll transition for overworld edges
			SceneManager.change_scene(destination_scene)
		_:  # Default: fade
			SceneManager.change_scene(destination_scene)


## Handle CUTSCENE trigger
func _handle_cutscene_trigger(trigger: Node, _player: Node2D) -> void:
	var _trigger_data: Dictionary = trigger.get("trigger_data")
	# TODO: Phase 5 - implement cutscene system
	pass


## Handle TRANSITION trigger - teleport within same scene
func _handle_transition_trigger(trigger: Node, player: Node2D) -> void:
	var trigger_data: Dictionary = trigger.get("trigger_data")
	var target_position: Vector2i = trigger_data.get("target_position", Vector2i.ZERO)

	if target_position == Vector2i.ZERO:
		push_warning("TriggerManager: Transition trigger missing target_position")
		return


	# Teleport player
	if player.has_method("teleport_to_grid"):
		player.teleport_to_grid(target_position)
	else:
		push_warning("TriggerManager: Player doesn't have teleport_to_grid method")


## Handle CUSTOM trigger
func _handle_custom_trigger(trigger: Node, _player: Node2D) -> void:
	var _trigger_data: Dictionary = trigger.get("trigger_data")
	# TODO: Phase 5 - custom trigger system
	pass


## Get human-readable trigger type name
func _get_trigger_type_name(type: int) -> String:
	match type:
		0: return "BATTLE"
		1: return "DIALOG"
		2: return "CHEST"
		3: return "DOOR"
		4: return "CUTSCENE"
		5: return "TRANSITION"
		6: return "CUSTOM"
		_: return "UNKNOWN"
