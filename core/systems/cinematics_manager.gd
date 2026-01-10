extends Node

## CinematicsManager - Orchestrates cinematic sequences
## Singleton autoload that executes scripted cutscenes with character movement,
## camera control, dialog, and game state changes.
## Accessed globally as CinematicsManager (autoload name)

# Preload custom types to ensure they're available
const CinematicData = preload("res://core/resources/cinematic_data.gd")
const CinematicActor = preload("res://core/components/cinematic_actor.gd")
const CinematicCommandExecutor = preload("res://core/systems/cinematic_command_executor.gd")
const SpawnableEntityHandler = preload("res://core/systems/cinematic_spawners/spawnable_entity_handler.gd")

## Cinematic execution states
enum State {
	IDLE,                ## No cinematic active
	LOADING,             ## Loading cinematic data
	PLAYING,             ## Executing commands
	WAITING_FOR_COMMAND, ## Waiting for command to complete
	WAITING_FOR_DIALOG,  ## Waiting for dialog to finish
	PAUSED,              ## Cinematic paused
	SKIPPING,            ## Fast-forwarding to end
	TRANSITIONING,       ## Scene transition in progress
	ENDING               ## Cinematic finishing
}

## Signals
signal cinematic_started(cinematic_id: String)
signal cinematic_ended(cinematic_id: String)
signal command_executed(command_type: String, command_index: int)
signal cinematic_resumed()
signal cinematic_skipped()

## Current state
var current_state: State = State.IDLE
var current_cinematic: CinematicData = null
var current_command_index: int = 0  ## Kept for backwards compatibility with signals

## Command queue for execution (supports branching via check_flag)
## Commands are popped from front, branches inject at front
var _command_queue: Array[Dictionary] = []

## Actor registry (actor_id -> CinematicActor)
var _registered_actors: Dictionary = {}

## Actor display data cache (actor_id -> {display_name, portrait, entity_ref})
## Stores display info for all actors including virtual ones
## Virtual actors have no CinematicActor but still have display data
var _actor_display_data: Dictionary = {}

## Cinematic chain tracking (prevents circular references)
var _cinematic_chain_stack: Array[String] = []
const MAX_CINEMATIC_CHAIN_DEPTH: int = 5

## Command executor registry (command_type -> CinematicCommandExecutor)
## Mods can register custom executors via register_command_executor()
var _command_executors: Dictionary = {}

## Spawnable entity handler registry (entity_type -> SpawnableEntityHandler)
## Mods can register custom spawnable types via register_spawnable_type()
var _spawnable_handlers: Dictionary = {}

## Currently executing command executor (for async operations)
var _current_executor: CinematicCommandExecutor = null

## Player input state
var _player_input_disabled: bool = false
var _previous_input_state: bool = false

## Wait timer for wait commands
var _wait_timer: float = 0.0
var _is_waiting: bool = false

## Interaction context - stores metadata about what triggered the current cinematic
## Used by game systems to identify NPC/interactable interactions
var _interaction_context: Dictionary = {}

## Command execution state
var _current_command_waits: bool = false
var _command_completed: bool = false

## Camera control (Phase 3: camera logic now in CameraController)
var _active_camera: Camera2D = null
var _camera_original_position: Vector2 = Vector2.ZERO

## Spawned actor nodes tracking for cleanup
## Stores references to nodes spawned via actors array or spawn_entity command
var _spawned_actor_nodes: Array[Node] = []

## Next destination for scene change after cinematic ends
## Used by change_scene command to defer scene transition until after cinematic_ended signal
var _next_destination: String = ""
var _next_destination_fade: bool = true
var _next_destination_fade_duration: float = 0.5

## Flag indicating a backdrop scene is being loaded
## When true, map_template and other gameplay scenes should skip gameplay initialization
## (party loading, camera setup, hero creation, etc.) and only set up visuals
var _loading_backdrop: bool = false


func _ready() -> void:
	# Disable per-frame processing when idle (optimization)
	set_process(false)

	# Register all built-in command executors
	_register_built_in_commands()

	# Register all built-in spawnable entity types
	_register_built_in_spawnable_types()

	# Connect to DialogManager signals
	# MED-001: Add is_connected() check before connecting signals
	if DialogManager:
		if not DialogManager.dialog_ended.is_connected(_on_dialog_ended):
			DialogManager.dialog_ended.connect(_on_dialog_ended)

	# Connect to SceneManager to clean up on scene transitions
	# This handles cases where scene changes during a cinematic (e.g., door trigger)
	if SceneManager:
		if not SceneManager.scene_transition_completed.is_connected(_on_scene_transition):
			SceneManager.scene_transition_completed.connect(_on_scene_transition)


func _process(delta: float) -> void:
	# Handle wait timer - only when in PLAYING state (not waiting for dialog/shop)
	# This prevents the timer from firing when _is_waiting is set for dialog commands
	if _is_waiting and current_state == State.PLAYING:
		_wait_timer -= delta
		if _wait_timer <= 0.0:
			_is_waiting = false
			_command_completed = true

	# Phase 3: Camera follow and shake now handled by CameraController

	# Continue executing commands if not waiting
	if current_state == State.PLAYING and not _is_waiting and _command_completed:
		_execute_next_command()


## Register an actor for cinematic control
## Actors must be registered before cinematics can reference them
func register_actor(actor: CinematicActor) -> void:
	if actor == null:
		push_error("CinematicsManager: Cannot register null actor")
		return

	if actor.actor_id.is_empty():
		push_error("CinematicsManager: Cannot register actor with empty actor_id")
		return

	if actor.actor_id in _registered_actors:
		push_warning("CinematicsManager: Actor '%s' already registered, overwriting" % actor.actor_id)

	_registered_actors[actor.actor_id] = actor


## Unregister an actor
func unregister_actor(actor_id: String) -> void:
	_registered_actors.erase(actor_id)


## Get a registered actor by ID
func get_actor(actor_id: String) -> CinematicActor:
	return _registered_actors.get(actor_id, null)


## Get a registered actor by character UID (for auto_follow in dialogs)
## Returns the first actor found with matching character_uid, or null
func get_actor_by_character_uid(character_uid: String) -> CinematicActor:
	if character_uid.is_empty():
		return null
	for actor_id: String in _registered_actors:
		var actor: CinematicActor = _registered_actors[actor_id] as CinematicActor
		if actor and actor.character_uid == character_uid:
			return actor
	return null


## Get display data for an actor (works for both real and virtual actors)
## Returns: {display_name: String, portrait: Texture2D, entity_ref: String, is_virtual: bool}
## Returns empty dict if actor not found
func get_actor_display_data(actor_id: String) -> Dictionary:
	if actor_id.is_empty():
		return {}
	return _actor_display_data.get(actor_id, {})


## Find an entity node on the current map by entity reference
## Supports formats: "npc:entity_id", character_uid, or actor_id
## Returns the entity's Node2D or null if not found
func find_entity_node(entity_ref: String) -> Node2D:
	if entity_ref.is_empty():
		return null

	# First check if it's a registered actor
	var actor: CinematicActor = get_actor(entity_ref)
	if actor and actor.parent_entity:
		return actor.parent_entity

	# Check by character_uid (for spawned actors)
	actor = get_actor_by_character_uid(entity_ref)
	if actor and actor.parent_entity:
		return actor.parent_entity

	# Search for existing NPC on map
	if entity_ref.begins_with("npc:"):
		var npc_id: String = entity_ref.substr(4)
		return _find_npc_on_map(npc_id)

	# Search for character on map (party member or spawned character)
	return _find_character_on_map(entity_ref)


## Find an NPC node on the current map by npc_id
func _find_npc_on_map(npc_id: String) -> Node2D:
	var scene_root: Node = get_tree().current_scene
	if not scene_root:
		return null

	# Search for NPC nodes - they typically have npc_id property or are in "npcs" group
	var npcs: Array[Node] = scene_root.get_tree().get_nodes_in_group("npcs")
	for npc: Node in npcs:
		if npc is Node2D:
			# Check for npc_id property
			if "npc_id" in npc and npc.npc_id == npc_id:
				return npc as Node2D
			# Check node name as fallback
			if npc.name.to_lower() == npc_id.to_lower():
				return npc as Node2D
	return null


## Find a character node on the current map by character_uid
func _find_character_on_map(character_uid: String) -> Node2D:
	var scene_root: Node = get_tree().current_scene
	if not scene_root:
		return null

	# Search for character nodes - typically in "characters" or "party" group
	for group_name: String in ["characters", "party", "units"]:
		var nodes: Array[Node] = scene_root.get_tree().get_nodes_in_group(group_name)
		for node: Node in nodes:
			if node is Node2D:
				# Check for character_uid property
				if "character_uid" in node and node.character_uid == character_uid:
					return node as Node2D
	return null


## Cache display data for an actor
## Called during actor spawning to store name/portrait for dialog lookups
func _cache_actor_display_data(actor_id: String, entity_ref: String, display_name: String = "", portrait: Texture2D = null, is_virtual: bool = false) -> void:
	_actor_display_data[actor_id] = {
		"display_name": display_name,
		"portrait": portrait,
		"entity_ref": entity_ref,
		"is_virtual": is_virtual
	}


## Clear actor display data cache (called at cinematic end)
func _clear_actor_display_cache() -> void:
	_actor_display_data.clear()


## Register a command executor for a specific command type
## Mods can use this to add custom cinematic commands without modifying core code
##
## Example:
## [codeblock]
## CinematicsManager.register_command_executor("custom_effect", MyCustomExecutor.new())
## [/codeblock]
func register_command_executor(command_type: String, executor: CinematicCommandExecutor) -> void:
	if command_type.is_empty():
		push_error("CinematicsManager: Cannot register executor with empty command_type")
		return

	if executor == null:
		push_error("CinematicsManager: Cannot register null executor")
		return

	if command_type in _command_executors:
		push_warning("CinematicsManager: Overwriting executor for command type '%s'" % command_type)

	_command_executors[command_type] = executor


## Unregister a command executor
func unregister_command_executor(command_type: String) -> void:
	_command_executors.erase(command_type)


## Get list of all registered command types
## Used by editor to discover available commands dynamically
func get_registered_command_types() -> Array[String]:
	var types: Array[String] = []
	for key: String in _command_executors.keys():
		types.append(key)
	return types


## Get editor metadata for a specific command type
## Returns executor's metadata if available, empty dict otherwise
## Used by cinematic editor to build dynamic UI
func get_command_editor_metadata(command_type: String) -> Dictionary:
	if command_type not in _command_executors:
		return {}

	var executor: CinematicCommandExecutor = _command_executors[command_type]
	return executor.get_editor_metadata()


## Get all command metadata for editor
## Returns dictionary of command_type -> metadata for all registered commands
## Commands without metadata return empty dict (editor should use hardcoded fallback)
func get_all_command_metadata() -> Dictionary:
	var result: Dictionary = {}
	for command_type: String in _command_executors:
		var executor: CinematicCommandExecutor = _command_executors[command_type]
		var metadata: Dictionary = executor.get_editor_metadata()
		result[command_type] = metadata
	return result


## Register all built-in command executors (Phase 2)
## Called during _ready() to set up the command registry
func _register_built_in_commands() -> void:
	# Load all executor scripts
	const WaitExecutor = preload("res://core/systems/cinematic_commands/wait_executor.gd")
	const SetVariableExecutor = preload("res://core/systems/cinematic_commands/set_variable_executor.gd")
	const DialogExecutor = preload("res://core/systems/cinematic_commands/dialog_executor.gd")
	const MoveEntityExecutor = preload("res://core/systems/cinematic_commands/move_entity_executor.gd")
	const SetFacingExecutor = preload("res://core/systems/cinematic_commands/set_facing_executor.gd")
	const SetPositionExecutor = preload("res://core/systems/cinematic_commands/set_position_executor.gd")
	const PlayAnimationExecutor = preload("res://core/systems/cinematic_commands/play_animation_executor.gd")
	const CameraMoveExecutor = preload("res://core/systems/cinematic_commands/camera_move_executor.gd")
	const CameraFollowExecutor = preload("res://core/systems/cinematic_commands/camera_follow_executor.gd")
	const CameraShakeExecutor = preload("res://core/systems/cinematic_commands/camera_shake_executor.gd")
	const FadeScreenExecutor = preload("res://core/systems/cinematic_commands/fade_screen_executor.gd")
	const PlaySoundExecutor = preload("res://core/systems/cinematic_commands/play_sound_executor.gd")
	const PlayMusicExecutor = preload("res://core/systems/cinematic_commands/play_music_executor.gd")
	const SpawnEntityExecutor = preload("res://core/systems/cinematic_commands/spawn_entity_executor.gd")
	const DespawnEntityExecutor = preload("res://core/systems/cinematic_commands/despawn_entity_executor.gd")
	const OpenShopExecutor = preload("res://core/systems/cinematic_commands/open_shop_executor.gd")
	const AddPartyMemberExecutor = preload("res://core/systems/cinematic_commands/add_party_member_executor.gd")
	const RemovePartyMemberExecutor = preload("res://core/systems/cinematic_commands/remove_party_member_executor.gd")
	const RejoinPartyMemberExecutor = preload("res://core/systems/cinematic_commands/rejoin_party_member_executor.gd")
	const SetCharacterStatusExecutor = preload("res://core/systems/cinematic_commands/set_character_status_executor.gd")
	const GrantItemsExecutor = preload("res://core/systems/cinematic_commands/grant_items_executor.gd")
	const ChangeSceneExecutor = preload("res://core/systems/cinematic_commands/change_scene_executor.gd")
	const SetBackdropExecutor = preload("res://core/systems/cinematic_commands/set_backdrop_executor.gd")
	const ShowChoiceExecutor = preload("res://core/systems/cinematic_commands/show_choice_executor.gd")
	const TriggerBattleExecutor = preload("res://core/systems/cinematic_commands/trigger_battle_executor.gd")
	const CheckFlagExecutor = preload("res://core/systems/cinematic_commands/check_flag_executor.gd")
	const CheckFlagsExecutor = preload("res://core/systems/cinematic_commands/check_flags_executor.gd")

	# Register all built-in commands
	register_command_executor("wait", WaitExecutor.new())
	register_command_executor("set_variable", SetVariableExecutor.new())
	register_command_executor("show_dialog", DialogExecutor.new())
	register_command_executor("dialog", DialogExecutor.new())  # Alias for inline cinematics
	register_command_executor("dialog_line", DialogExecutor.new())  # Single-line dialog from Cinematic Editor
	register_command_executor("move_entity", MoveEntityExecutor.new())
	register_command_executor("set_facing", SetFacingExecutor.new())
	register_command_executor("set_position", SetPositionExecutor.new())
	register_command_executor("play_animation", PlayAnimationExecutor.new())
	register_command_executor("camera_move", CameraMoveExecutor.new())
	register_command_executor("camera_follow", CameraFollowExecutor.new())
	register_command_executor("camera_shake", CameraShakeExecutor.new())
	register_command_executor("fade_screen", FadeScreenExecutor.new())
	register_command_executor("play_sound", PlaySoundExecutor.new())
	register_command_executor("play_music", PlayMusicExecutor.new())
	register_command_executor("spawn_entity", SpawnEntityExecutor.new())
	register_command_executor("despawn_entity", DespawnEntityExecutor.new())
	register_command_executor("open_shop", OpenShopExecutor.new())
	register_command_executor("add_party_member", AddPartyMemberExecutor.new())
	register_command_executor("remove_party_member", RemovePartyMemberExecutor.new())
	register_command_executor("rejoin_party_member", RejoinPartyMemberExecutor.new())
	register_command_executor("set_character_status", SetCharacterStatusExecutor.new())
	register_command_executor("grant_items", GrantItemsExecutor.new())
	register_command_executor("change_scene", ChangeSceneExecutor.new())
	register_command_executor("set_backdrop", SetBackdropExecutor.new())
	register_command_executor("show_choice", ShowChoiceExecutor.new())
	register_command_executor("trigger_battle", TriggerBattleExecutor.new())
	register_command_executor("check_flag", CheckFlagExecutor.new())
	register_command_executor("check_flags", CheckFlagsExecutor.new())


## Register all built-in spawnable entity types
## Called during _ready() to set up the spawnable registry
func _register_built_in_spawnable_types() -> void:
	const CharacterSpawnHandler = preload("res://core/systems/cinematic_spawners/character_spawn_handler.gd")
	const InteractableSpawnHandler = preload("res://core/systems/cinematic_spawners/interactable_spawn_handler.gd")
	const NPCSpawnHandler = preload("res://core/systems/cinematic_spawners/npc_spawn_handler.gd")
	const VirtualSpawnHandler = preload("res://core/systems/cinematic_spawners/virtual_spawn_handler.gd")

	register_spawnable_type(CharacterSpawnHandler.new())
	register_spawnable_type(InteractableSpawnHandler.new())
	register_spawnable_type(NPCSpawnHandler.new())
	register_spawnable_type(VirtualSpawnHandler.new())


## Register a spawnable entity handler
## Mods can use this to add custom entity types that can be spawned in cinematics
## @param handler: SpawnableEntityHandler instance with get_type_id() defined
func register_spawnable_type(handler: SpawnableEntityHandler) -> void:
	var type_id: String = handler.get_type_id()
	if type_id.is_empty():
		push_error("CinematicsManager: Cannot register spawnable handler with empty type_id")
		return

	if type_id in _spawnable_handlers:
		push_warning("CinematicsManager: Overwriting spawnable handler for type '%s'" % type_id)

	_spawnable_handlers[type_id] = handler


## Get a spawnable entity handler by type ID
## @param type_id: The entity type (e.g., "character", "interactable", "npc")
## @return: SpawnableEntityHandler or null if not found
func get_spawnable_handler(type_id: String) -> SpawnableEntityHandler:
	return _spawnable_handlers.get(type_id) as SpawnableEntityHandler


## Get all registered spawnable type IDs
## Useful for editor dropdowns
func get_spawnable_types() -> Array[String]:
	var types: Array[String] = []
	for key: String in _spawnable_handlers.keys():
		types.append(key)
	return types


## Get all registered spawnable handlers
## Returns array of {type_id: String, handler: SpawnableEntityHandler}
func get_all_spawnable_handlers() -> Array[Dictionary]:
	var handlers: Array[Dictionary] = []
	for type_id: String in _spawnable_handlers.keys():
		var handler: SpawnableEntityHandler = _spawnable_handlers[type_id] as SpawnableEntityHandler
		handlers.append({
			"type_id": type_id,
			"handler": handler
		})
	return handlers


## Register a camera for cinematic control
## The active scene's camera will be auto-detected, but can be set explicitly
func register_camera(camera: Camera2D) -> void:
	_active_camera = camera
	if camera:
		_camera_original_position = camera.global_position


## Get camera as CameraController if available (helper for executors)
## Returns null with warning if no camera or camera is not CameraController
func get_camera_controller() -> CameraController:
	if not _active_camera:
		push_warning("CinematicsManager: No camera available")
		return null
	if not _active_camera is CameraController:
		push_warning("CinematicsManager: Camera is not CameraController. Upgrade to CameraController for Phase 3 features.")
		return null
	return _active_camera as CameraController


## Get the active camera regardless of type (Camera2D, CameraController, MapCamera)
## Returns null if no camera detected
func get_active_camera() -> Camera2D:
	return _active_camera


## Auto-detect camera in the current scene
func _auto_detect_camera() -> void:
	# Try to find a Camera2D in the current scene
	var scene_root: Node = get_tree().current_scene
	if scene_root:
		_active_camera = _find_camera_recursive(scene_root)
		if _active_camera:
			_camera_original_position = _active_camera.global_position


## Recursively search for Camera2D
func _find_camera_recursive(node: Node) -> Camera2D:
	if node is Camera2D:
		return node as Camera2D

	for child: Node in node.get_children():
		var result: Camera2D = _find_camera_recursive(child)
		if result:
			return result

	return null


## Play a cinematic by ID (looks up in ModRegistry)
## Supports auto-generated cinematics for interactables (ID starts with "__auto_interactable__")
func play_cinematic(cinematic_id: String) -> bool:
	if current_state != State.IDLE:
		push_warning("CinematicsManager: Cannot play cinematic '%s' - cinematic already active" % cinematic_id)
		return false

	# Check for auto-generated interactable cinematic
	if cinematic_id.begins_with("__auto_interactable__"):
		var auto_cinematic: CinematicData = _generate_interactable_auto_cinematic(cinematic_id)
		if auto_cinematic:
			return play_cinematic_from_resource(auto_cinematic)
		push_error("CinematicsManager: Failed to generate auto-interactable cinematic for '%s'" % cinematic_id)
		return false

	# Look up cinematic in ModRegistry
	var cinematic: CinematicData = ModLoader.registry.get_cinematic(cinematic_id)
	if not cinematic:
		push_error("CinematicsManager: Cinematic '%s' not found in ModRegistry" % cinematic_id)
		return false

	return play_cinematic_from_resource(cinematic)


## Play a cinematic from a CinematicData resource directly
func play_cinematic_from_resource(cinematic: CinematicData) -> bool:
	if not cinematic:
		push_error("CinematicsManager: Cannot play null cinematic")
		return false

	if current_state != State.IDLE:
		push_warning("CinematicsManager: Cannot play cinematic - cinematic already active")
		return false

	# Validate the cinematic
	if not cinematic.validate():
		push_error("CinematicsManager: Cinematic validation failed")
		return false

	# Check for circular references
	if cinematic.cinematic_id in _cinematic_chain_stack:
		push_error("CinematicsManager: Circular cinematic reference detected: %s" % cinematic.cinematic_id)
		return false

	# Check max chain depth
	if _cinematic_chain_stack.size() >= MAX_CINEMATIC_CHAIN_DEPTH:
		push_error("CinematicsManager: Max cinematic chain depth (%d) exceeded" % MAX_CINEMATIC_CHAIN_DEPTH)
		return false

	# Add to chain stack
	if not cinematic.cinematic_id.is_empty():
		_cinematic_chain_stack.append(cinematic.cinematic_id)

	# Start the cinematic
	current_cinematic = cinematic
	current_command_index = 0
	current_state = State.LOADING

	# Populate command queue from cinematic's commands
	_command_queue.clear()
	for i: int in range(cinematic.get_command_count()):
		_command_queue.append(cinematic.get_command(i))

	# Auto-detect camera if not already set
	if not _active_camera:
		_auto_detect_camera()

	# Switch camera to cinematic mode for smooth, dramatic movements
	if _active_camera and _active_camera is CameraController:
		(_active_camera as CameraController).set_cinematic_mode()

	# Disable player input if requested
	if cinematic.disable_player_input:
		_disable_player_input()

	cinematic_started.emit(cinematic.cinematic_id)

	# Enable per-frame processing while cinematic is active
	set_process(true)

	# Spawn actors from actors array before executing commands
	# This allows data-driven cinematics without pre-placed scene actors
	_spawn_actors_from_data(cinematic)

	# Start executing commands
	current_state = State.PLAYING
	_command_completed = true  # Start first command
	_execute_next_command()

	return true


## Execute the next command in the sequence
func _execute_next_command() -> void:
	if current_cinematic == null:
		return

	# Check if we've finished all commands (queue-based)
	if _command_queue.is_empty():
		_end_cinematic()
		return

	# Pop next command from queue
	var command: Dictionary = _command_queue.pop_front()
	if command.is_empty():
		push_error("CinematicsManager: Invalid command at index %d" % current_command_index)
		_end_cinematic()
		return

	# Reset completion flag
	_command_completed = false
	var params_dict: Dictionary = DictUtils.get_dict(command, "params", {})
	_current_command_waits = DictUtils.get_bool(params_dict, "wait", false)

	# Execute command based on type
	var command_type: String = command.get("type", "")
	command_executed.emit(command_type, current_command_index)

	# Check custom executor registry first (allows mods to add/override commands)
	if command_type in _command_executors:
		var executor: CinematicCommandExecutor = _command_executors[command_type] as CinematicCommandExecutor
		_current_executor = executor
		var completed: bool = _current_executor.execute(command, self)
		if completed:
			_command_completed = true
		# else: executor will set _command_completed = true when async operation finishes
	else:
		# No executor registered for this command type
		push_warning("CinematicsManager: Unknown command type '%s' - no executor registered" % command_type)
		_command_completed = true

	# Increment index for signal/debugging compatibility
	current_command_index += 1

	# If command doesn't wait, continue immediately
	if not _current_command_waits and not _is_waiting:
		_command_completed = true


## Inject commands at the front of the execution queue
## Used by check_flag to insert branch commands for immediate execution
## @param commands: Array of command dictionaries to inject
func inject_commands(commands: Array) -> void:
	# Insert at front (reverse order to maintain sequence)
	for i: int in range(commands.size() - 1, -1, -1):
		var cmd: Variant = commands[i]
		if cmd is Dictionary:
			_command_queue.push_front(cmd)


## Called when actor movement completes
func _on_movement_completed() -> void:
	_command_completed = true


## Called when actor animation completes
func _on_animation_completed() -> void:
	_command_completed = true


## Called when dialog ends
func _on_dialog_ended(dialogue_data: DialogueData) -> void:
	if current_state == State.WAITING_FOR_DIALOG:
		current_state = State.PLAYING
		_is_waiting = false  # Clear the waiting flag set by DialogExecutor
		_command_completed = true


## Handle scene transitions - clean up any active cinematic
## This prevents input from staying disabled when a door trigger fires mid-cinematic
func _on_scene_transition(_scene_path: String) -> void:
	# If a cinematic is active, force-end it to clean up state
	if current_state != State.IDLE:
		push_warning("CinematicsManager: Scene transition during active cinematic - forcing cleanup")
		_end_cinematic()
	# Safety net: if input is disabled but no cinematic active, re-enable it
	elif _player_input_disabled:
		push_warning("CinematicsManager: Input disabled with no active cinematic - re-enabling")
		_enable_player_input()


## End the current cinematic
func _end_cinematic() -> void:
	if current_state == State.IDLE:
		return

	current_state = State.ENDING

	# DEFENSIVE: Clear backdrop loading flag to prevent maps entering backdrop mode
	_loading_backdrop = false

	var finished_cinematic: CinematicData = current_cinematic

	# Remove from chain stack
	if not _cinematic_chain_stack.is_empty() and not finished_cinematic.cinematic_id.is_empty():
		_cinematic_chain_stack.pop_back()

	# Re-enable player input if we disabled it
	if _player_input_disabled:
		_enable_player_input()

	# Phase 3: Stop camera operations via CameraController
	if _active_camera and _active_camera is CameraController:
		var camera: CameraController = _active_camera as CameraController
		camera.stop_follow()
		camera.offset = Vector2.ZERO  # Reset any active shake
		camera.set_tactical_mode()  # Restore fast camera for gameplay
	elif _active_camera and _active_camera is MapCamera:
		# Clear cinematic target to resume hero following
		var map_camera: MapCamera = _active_camera as MapCamera
		map_camera.clear_cinematic_target()

	# Clean up spawned actors and display cache
	_cleanup_spawned_actors()
	_clear_actor_display_cache()

	# DEFENSIVE: Ensure DialogManager is reset to IDLE
	# This catches edge cases where dialog might still be active
	# (e.g., if skip happened during dialog without proper executor cleanup)
	if DialogManager and DialogManager.is_dialog_active():
		DialogManager.end_dialog()

	# Clear current data
	current_cinematic = null
	current_command_index = 0
	_command_queue.clear()
	_command_completed = false
	_is_waiting = false
	_current_executor = null  # Clear executor reference

	cinematic_ended.emit(finished_cinematic.cinematic_id if finished_cinematic else "")

	current_state = State.IDLE

	# Disable per-frame processing while idle (optimization)
	# Note: Will be re-enabled if chaining to next cinematic
	set_process(false)

	# Handle pending scene destination (from change_scene command)
	# This happens AFTER cinematic_ended signal so listeners can handle it
	if not _next_destination.is_empty():
		var dest: String = _next_destination
		var use_fade: bool = _next_destination_fade
		_next_destination = ""  # Clear to prevent re-entry
		SceneManager.change_scene(dest, use_fade)
		return  # Don't chain to next cinematic - we're changing scenes

	# Chain to next cinematic if exists
	if finished_cinematic and finished_cinematic.has_next():
		play_cinematic_from_resource(finished_cinematic.next_cinematic)


## Skip the current cinematic
## Fades to black before cleanup to avoid jarring actor disappearance
func skip_cinematic() -> void:
	if current_state == State.IDLE:
		return

	if current_cinematic and not current_cinematic.can_skip:
		push_warning("CinematicsManager: Current cinematic cannot be skipped")
		return

	# Prevent multiple skip calls during fade
	if current_state == State.SKIPPING:
		return

	current_state = State.SKIPPING

	# Interrupt any active async executor to allow cleanup
	if _current_executor:
		_current_executor.interrupt()
		_current_executor = null

	# Clear any pending destination to prevent orphaned scene transitions
	_next_destination = ""

	cinematic_skipped.emit()

	# Fade to black BEFORE cleanup so actors don't pop out visually
	# Only fade if not already faded (avoids double-fade)
	if SceneManager and not SceneManager.is_faded_to_black:
		await SceneManager.fade_to_black(0.3)
		# Guard against node being freed during await
		if not is_instance_valid(self):
			return

	_end_cinematic()


## Set the next destination for scene change after cinematic ends
## Used by change_scene command to defer transition until cinematic_ended signal fires
## This ensures listeners (like startup.gd) can handle the signal before scene changes
func set_next_destination(scene_path: String, use_fade: bool = true, fade_duration: float = 0.5) -> void:
	_next_destination = scene_path
	_next_destination_fade = use_fade
	_next_destination_fade_duration = fade_duration


## Resume the paused cinematic
func resume_cinematic() -> void:
	if current_state != State.PAUSED:
		return

	current_state = State.PLAYING
	cinematic_resumed.emit()


## Check if a cinematic is currently active
func is_cinematic_active() -> bool:
	return current_state != State.IDLE


## Get the current state
func get_current_state() -> State:
	return current_state


# =============================================================================
# INTERACTION CONTEXT (NPC identification for external systems)
# =============================================================================

## Set context about what triggered the current cinematic
## Called by NPCNode before playing a cinematic
func set_interaction_context(context: Dictionary) -> void:
	_interaction_context = context.duplicate()


## Get the current interaction context
## Returns empty dictionary if no context set
func get_interaction_context() -> Dictionary:
	return _interaction_context


## Clear the interaction context
## Called when cinematic ends or interaction completes
func clear_interaction_context() -> void:
	_interaction_context.clear()


## Disable player input
func _disable_player_input() -> void:
	# InputManager is for battles - only try to disable if it has the method
	if InputManager.has_method("set_input_enabled"):
		var input_state_value: Variant = InputManager.get("input_enabled")
		var input_enabled_state: bool = input_state_value if input_state_value is bool else true
		_previous_input_state = input_enabled_state
		InputManager.set_input_enabled(false)

	_player_input_disabled = true


## Re-enable player input
func _enable_player_input() -> void:
	# InputManager is for battles - only try to re-enable if it has the method
	if InputManager.has_method("set_input_enabled"):
		InputManager.set_input_enabled(_previous_input_state)

	_player_input_disabled = false


# =============================================================================
# SPAWNED ACTOR MANAGEMENT
# =============================================================================

## Find the appropriate node to add spawned actors to
## Returns the cinematic stage if one exists, otherwise current_scene
## This handles the Startup coordinator pattern where OpeningCinematicStage
## is a child of Startup, not the current_scene itself
func _find_actor_parent() -> Node:
	var scene_root: Node = get_tree().current_scene
	if not scene_root:
		return null

	# Check if current scene IS the cinematic stage
	if scene_root.name.contains("CinematicStage"):
		return scene_root

	# Check children for cinematic stage (Startup coordinator pattern)
	for child: Node in scene_root.get_children():
		if child.name.contains("CinematicStage"):
			return child

	# Fallback: use current scene (map-based cinematics like NPC interactions)
	return scene_root


## Spawn actors from cinematic data's actors array
## Called before commands execute to set up the scene
func _spawn_actors_from_data(cinematic: CinematicData) -> void:
	# Check if cinematic has actors property (for CinematicData resources)
	# Also check commands for embedded actors array (for JSON cinematics)
	var actors: Array = []

	# CinematicData may have actors property (if we add it later)
	if "actors" in cinematic and cinematic.actors is Array:
		actors = cinematic.actors

	if actors.is_empty():
		return

	# Spawn each actor
	for i: int in range(actors.size()):
		var actor_val: Variant = actors[i]
		if not actor_val is Dictionary:
			push_warning("CinematicsManager: Invalid actor definition at index %d (not a dictionary)" % i)
			continue
		var actor_def: Dictionary = actor_val
		_spawn_single_actor(actor_def)


## Spawn a single actor from a definition dictionary
## Format: {actor_id, entity_type, entity_id, position: [x, y], facing}
## Virtual actors: {actor_id, entity_type: "virtual", display_source: "npc:id" or character_uid}
## Legacy format also supported: {actor_id, character_id, ...} maps to entity_type="character"
func _spawn_single_actor(actor_def: Dictionary) -> void:
	var actor_id: String = actor_def.get("actor_id", "")
	if actor_id.is_empty():
		push_warning("CinematicsManager: Actor definition missing actor_id")
		return

	# Check for existing actor with this ID
	if get_actor(actor_id) != null:
		push_warning("CinematicsManager: Actor '%s' already exists from actors array" % actor_id)

	# Determine entity type and ID (with backward compatibility for character_id)
	var entity_type: String = actor_def.get("entity_type", "")
	var entity_id: String = actor_def.get("entity_id", "")

	# Backward compatibility: character_id maps to entity_type="character"
	if entity_type.is_empty() and entity_id.is_empty():
		var character_id: String = actor_def.get("character_id", "")
		if not character_id.is_empty():
			entity_type = "character"
			entity_id = character_id

	# Default to "character" if still empty (unless virtual)
	if entity_type.is_empty():
		entity_type = "character"

	# Handle virtual actors - no sprite, no node, just cache display data
	if entity_type == "virtual":
		_spawn_virtual_actor(actor_id, actor_def)
		return

	# Parse position (grid coordinates)
	var grid_pos: Vector2i = Vector2i.ZERO
	var pos_param: Variant = actor_def.get("position", [0, 0])
	if pos_param is Array and pos_param.size() >= 2:
		grid_pos = Vector2i(int(pos_param[0]), int(pos_param[1]))
	elif pos_param is Vector2:
		grid_pos = Vector2i(pos_param)
	elif pos_param is Vector2i:
		grid_pos = pos_param

	# Get facing direction
	var facing: String = str(actor_def.get("facing", "down")).to_lower()
	if facing not in ["up", "down", "left", "right"]:
		facing = "down"

	# Create the spawned entity structure
	var entity: CharacterBody2D = CharacterBody2D.new()
	entity.name = "SpawnedActor_%s" % actor_id

	# Position at grid coordinates
	entity.global_position = GridManager.cell_to_world(grid_pos)

	# Ensure spawned actors render above backdrop tilemaps
	entity.z_index = 10

	# Create sprite using the registry handler
	var sprite_node: Node2D = null
	var handler: SpawnableEntityHandler = get_spawnable_handler(entity_type)
	if handler and not entity_id.is_empty():
		sprite_node = handler.create_sprite_node(entity_id, facing)

	# Fallback to empty placeholder if no handler or entity_id
	if sprite_node == null:
		var placeholder: AnimatedSprite2D = AnimatedSprite2D.new()
		placeholder.name = "AnimatedSprite2D"
		sprite_node = placeholder
		if not entity_id.is_empty():
			push_warning("CinematicsManager: No handler for entity_type '%s' or entity '%s' not found" % [entity_type, entity_id])

	entity.add_child(sprite_node)

	# Create CinematicActor component
	var cinematic_actor: CinematicActor = CinematicActor.new()
	cinematic_actor.name = "CinematicActor"
	cinematic_actor.actor_id = actor_id
	cinematic_actor.sprite_node = sprite_node

	# Track character UID for auto_follow in dialogs and cache display data
	var entity_ref: String = ""
	var display_name: String = ""
	var portrait: Texture2D = null

	if entity_type == "character" and not entity_id.is_empty():
		var char_data: CharacterData = ModLoader.registry.get_character(entity_id) as CharacterData
		if char_data:
			if "character_uid" in char_data:
				cinematic_actor.character_uid = str(char_data.get("character_uid"))
				entity_ref = cinematic_actor.character_uid
			else:
				cinematic_actor.character_uid = entity_id
				entity_ref = entity_id
			display_name = char_data.character_name if char_data.character_name else entity_id
			portrait = char_data.portrait
		else:
			cinematic_actor.character_uid = entity_id
			entity_ref = entity_id
	elif entity_type == "npc" and not entity_id.is_empty():
		# For NPCs, use the "npc:" prefix format that matches what dialog_line stores
		cinematic_actor.character_uid = "npc:" + entity_id
		entity_ref = cinematic_actor.character_uid
		var npc_data: NPCData = ModLoader.registry.get_npc(entity_id) as NPCData
		if npc_data:
			display_name = npc_data.get_display_name()
			portrait = npc_data.get_portrait()

	entity.add_child(cinematic_actor)

	# Cache display data for dialog lookups
	_cache_actor_display_data(actor_id, entity_ref, display_name, portrait, false)

	# Add to scene tree (use cinematic stage if available, otherwise current scene)
	var actor_parent: Node = _find_actor_parent()
	if actor_parent:
		actor_parent.add_child(entity)
		_track_spawned_actor(entity)
	else:
		push_error("CinematicsManager: No scene to add actor to")
		entity.queue_free()


## Spawn a virtual actor (off-screen speaker)
## Virtual actors have no node in the scene tree - only display data for dialogs
func _spawn_virtual_actor(actor_id: String, actor_def: Dictionary) -> void:
	# Virtual actors use display_source to reference an existing entity for portrait/name
	var display_source: String = actor_def.get("display_source", "")
	var display_name: String = ""
	var portrait: Texture2D = null

	if not display_source.is_empty():
		# Resolve display data from the source entity
		if display_source.begins_with("npc:"):
			var npc_id: String = display_source.substr(4)
			var npc_data: NPCData = ModLoader.registry.get_npc(npc_id) as NPCData
			if npc_data:
				display_name = npc_data.get_display_name()
				portrait = npc_data.get_portrait()
			else:
				push_warning("CinematicsManager: Virtual actor '%s' references unknown NPC '%s'" % [actor_id, npc_id])
				display_name = npc_id
		else:
			# Assume it's a character UID
			var char_data: CharacterData = ModLoader.registry.get_character_by_uid(display_source) as CharacterData
			if char_data:
				display_name = char_data.character_name
				portrait = char_data.portrait
			else:
				push_warning("CinematicsManager: Virtual actor '%s' references unknown character '%s'" % [actor_id, display_source])
				display_name = display_source

	# Cache display data - virtual actors have no entity_ref (can't be followed)
	_cache_actor_display_data(actor_id, "", display_name, portrait, true)


## Track a spawned actor node for cleanup
## Called by SpawnEntityExecutor and _spawn_single_actor
func _track_spawned_actor(node: Node) -> void:
	if node and node not in _spawned_actor_nodes:
		_spawned_actor_nodes.append(node)


## Clean up all spawned actors
## Called when cinematic ends or is skipped
func _cleanup_spawned_actors() -> void:
	for node: Node in _spawned_actor_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_spawned_actor_nodes.clear()


# =============================================================================
# INLINE CINEMATICS
# =============================================================================

## Play an inline cinematic from an array of command dictionaries
## Useful for simple sequences that don't need a full CinematicData resource
## @param commands: Array of command dictionaries [{type: String, params: Dictionary}]
## @param cinematic_id: Optional ID for tracking (auto-generated if empty)
## @return: true if started successfully
func play_inline_cinematic(commands: Array, cinematic_id: String = "") -> bool:
	if current_state != State.IDLE:
		push_warning("CinematicsManager: Cannot play inline cinematic - cinematic already active")
		return false

	if commands.is_empty():
		push_warning("CinematicsManager: Cannot play empty inline cinematic")
		return false

	# Create temporary CinematicData
	var cinematic: CinematicData = CinematicData.new()
	cinematic.cinematic_id = cinematic_id if not cinematic_id.is_empty() else "_inline_%d" % Time.get_ticks_msec()
	cinematic.cinematic_name = "Inline Cinematic"
	cinematic.disable_player_input = true
	cinematic.can_skip = true

	# Add commands
	for i: int in range(commands.size()):
		var cmd_val: Variant = commands[i]
		if cmd_val is Dictionary:
			cinematic.commands.append(cmd_val)

	return play_cinematic_from_resource(cinematic)


# =============================================================================
# INTERACTABLE AUTO-CINEMATICS
# =============================================================================

## Preload InteractableData for type access
const InteractableDataScript = preload("res://core/resources/interactable_data.gd")

## Generate auto-cinematic for interactable objects (chests, bookshelves, etc.)
## Format: __auto_interactable__{interactable_id}
func _generate_interactable_auto_cinematic(cinematic_id: String) -> CinematicData:
	# Parse the interactable ID (format: __auto_interactable__{id})
	var interactable_id: String = cinematic_id.substr(21)  # Skip "__auto_interactable__"

	if interactable_id.is_empty():
		push_error("CinematicsManager: Invalid auto-interactable cinematic ID: %s" % cinematic_id)
		return null

	# Look up the interactable data
	var interactable_resource: InteractableData = ModLoader.registry.get_interactable(interactable_id)
	if not interactable_resource:
		push_error("CinematicsManager: Interactable '%s' not found for auto-cinematic" % interactable_id)
		return null

	# Cast to InteractableData (can't use class_name in type hint due to load order)
	if not interactable_resource.has_method("has_rewards"):
		push_error("CinematicsManager: Invalid interactable resource for '%s'" % interactable_id)
		return null

	# Use typed intermediate for property access
	var interactable: InteractableDataScript = interactable_resource as InteractableDataScript

	# Build the cinematic
	var cinematic: CinematicData = CinematicData.new()
	cinematic.cinematic_id = cinematic_id
	cinematic.cinematic_name = "Auto: %s" % interactable_id
	cinematic.disable_player_input = true
	cinematic.can_skip = true

	# Grant items/gold if present (shows "Found X!" messages)
	# Auto-cinematics are rewards-only. For text (signs, bookshelves), use explicit cinematics.
	if interactable.has_rewards():
		cinematic.commands.append({
			"type": "grant_items",
			"params": {
				"items": interactable.item_rewards,
				"gold": interactable.gold_reward,
				"show_message": true
			}
		})

	# If no commands at all, add type-specific default message
	if cinematic.commands.is_empty():
		var default_msg: String = InteractableDataScript.FALLBACK_EMPTY_MESSAGE
		var interactable_type: InteractableDataScript.InteractableType = interactable.interactable_type
		default_msg = InteractableDataScript.get_default_empty_message(interactable_type)
		cinematic.commands.append({
			"type": "dialog",
			"params": {
				"text": default_msg
			}
		})

	return cinematic
