extends Node

## CinematicsManager - Orchestrates cinematic sequences
## Singleton autoload that executes scripted cutscenes with character movement,
## camera control, dialog, and game state changes.
## Accessed globally as CinematicsManager (autoload name)

# Preload custom types to ensure they're available
const CinematicData: GDScript = preload("res://core/resources/cinematic_data.gd")
const CinematicActor: GDScript = preload("res://core/components/cinematic_actor.gd")
const CinematicCommandExecutor: GDScript = preload("res://core/systems/cinematic_command_executor.gd")

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
var current_command_index: int = 0

## Actor registry (actor_id -> CinematicActor)
var _registered_actors: Dictionary = {}

## Cinematic chain tracking (prevents circular references)
var _cinematic_chain_stack: Array[String] = []
const MAX_CINEMATIC_CHAIN_DEPTH: int = 5

## Command executor registry (command_type -> CinematicCommandExecutor)
## Mods can register custom executors via register_command_executor()
var _command_executors: Dictionary = {}

## Currently executing command executor (for async operations)
var _current_executor: CinematicCommandExecutor = null

## Player input state
var _player_input_disabled: bool = false
var _previous_input_state: bool = false

## Wait timer for wait commands
var _wait_timer: float = 0.0
var _is_waiting: bool = false

## Interaction context - stores metadata about what triggered the current cinematic
## Used by systems like CampaignManager to identify NPC interactions
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


func _ready() -> void:
	# Disable per-frame processing when idle (optimization)
	set_process(false)

	# Register all built-in command executors
	_register_built_in_commands()

	# Connect to DialogManager signals
	if DialogManager:
		DialogManager.dialog_ended.connect(_on_dialog_ended)


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
	const WaitExecutor: GDScript = preload("res://core/systems/cinematic_commands/wait_executor.gd")
	const SetVariableExecutor: GDScript = preload("res://core/systems/cinematic_commands/set_variable_executor.gd")
	const DialogExecutor: GDScript = preload("res://core/systems/cinematic_commands/dialog_executor.gd")
	const MoveEntityExecutor: GDScript = preload("res://core/systems/cinematic_commands/move_entity_executor.gd")
	const SetFacingExecutor: GDScript = preload("res://core/systems/cinematic_commands/set_facing_executor.gd")
	const PlayAnimationExecutor: GDScript = preload("res://core/systems/cinematic_commands/play_animation_executor.gd")
	const CameraMoveExecutor: GDScript = preload("res://core/systems/cinematic_commands/camera_move_executor.gd")
	const CameraFollowExecutor: GDScript = preload("res://core/systems/cinematic_commands/camera_follow_executor.gd")
	const CameraShakeExecutor: GDScript = preload("res://core/systems/cinematic_commands/camera_shake_executor.gd")
	const FadeScreenExecutor: GDScript = preload("res://core/systems/cinematic_commands/fade_screen_executor.gd")
	const PlaySoundExecutor: GDScript = preload("res://core/systems/cinematic_commands/play_sound_executor.gd")
	const PlayMusicExecutor: GDScript = preload("res://core/systems/cinematic_commands/play_music_executor.gd")
	const SpawnEntityExecutor: GDScript = preload("res://core/systems/cinematic_commands/spawn_entity_executor.gd")
	const DespawnEntityExecutor: GDScript = preload("res://core/systems/cinematic_commands/despawn_entity_executor.gd")
	const OpenShopExecutor: GDScript = preload("res://core/systems/cinematic_commands/open_shop_executor.gd")
	const AddPartyMemberExecutor: GDScript = preload("res://core/systems/cinematic_commands/add_party_member_executor.gd")
	const RemovePartyMemberExecutor: GDScript = preload("res://core/systems/cinematic_commands/remove_party_member_executor.gd")
	const RejoinPartyMemberExecutor: GDScript = preload("res://core/systems/cinematic_commands/rejoin_party_member_executor.gd")
	const SetCharacterStatusExecutor: GDScript = preload("res://core/systems/cinematic_commands/set_character_status_executor.gd")
	const GrantItemsExecutor: GDScript = preload("res://core/systems/cinematic_commands/grant_items_executor.gd")

	# Register all built-in commands
	register_command_executor("wait", WaitExecutor.new())
	register_command_executor("set_variable", SetVariableExecutor.new())
	register_command_executor("show_dialog", DialogExecutor.new())
	register_command_executor("dialog_line", DialogExecutor.new())  # Single-line dialog from Cinematic Editor
	register_command_executor("move_entity", MoveEntityExecutor.new())
	register_command_executor("set_facing", SetFacingExecutor.new())
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
## Supports auto-generated cinematics for Quick Setup NPCs (ID starts with "__auto__")
## and interactables (ID starts with "__auto_interactable__")
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

	# Check for auto-generated NPC cinematic (Quick Setup NPC system)
	if cinematic_id.begins_with("__auto__"):
		var auto_cinematic: CinematicData = _generate_auto_cinematic(cinematic_id)
		if auto_cinematic:
			return play_cinematic_from_resource(auto_cinematic)
		push_error("CinematicsManager: Failed to generate auto-cinematic for '%s'" % cinematic_id)
		return false

	# Look up cinematic in ModRegistry
	var cinematic: CinematicData = ModLoader.registry.get_resource("cinematic", cinematic_id) as CinematicData
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

	# Check if we've finished all commands
	if current_command_index >= current_cinematic.get_command_count():
		_end_cinematic()
		return

	# Get next command
	var command: Dictionary = current_cinematic.get_command(current_command_index)
	if command.is_empty():
		push_error("CinematicsManager: Invalid command at index %d" % current_command_index)
		_end_cinematic()
		return

	# Reset completion flag
	_command_completed = false
	_current_command_waits = command.get("params", {}).get("wait", false)

	# Execute command based on type
	var command_type: String = command.get("type", "")
	command_executed.emit(command_type, current_command_index)

	# Check custom executor registry first (allows mods to add/override commands)
	if command_type in _command_executors:
		_current_executor = _command_executors[command_type]
		var completed: bool = _current_executor.execute(command, self)
		if completed:
			_command_completed = true
		# else: executor will set _command_completed = true when async operation finishes
	else:
		# No executor registered for this command type
		push_warning("CinematicsManager: Unknown command type '%s' - no executor registered" % command_type)
		_command_completed = true

	# Move to next command
	current_command_index += 1

	# If command doesn't wait, continue immediately
	if not _current_command_waits and not _is_waiting:
		_command_completed = true



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


## End the current cinematic
func _end_cinematic() -> void:
	if current_state == State.IDLE:
		return

	current_state = State.ENDING

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

	# Clean up spawned actors
	_cleanup_spawned_actors()

	# Clear current data
	current_cinematic = null
	current_command_index = 0
	_command_completed = false
	_is_waiting = false
	_current_executor = null  # Clear executor reference

	cinematic_ended.emit(finished_cinematic.cinematic_id if finished_cinematic else "")

	current_state = State.IDLE

	# Disable per-frame processing while idle (optimization)
	# Note: Will be re-enabled if chaining to next cinematic
	set_process(false)

	# Chain to next cinematic if exists
	if finished_cinematic and finished_cinematic.has_next():
		play_cinematic_from_resource(finished_cinematic.next_cinematic)


## Skip the current cinematic
func skip_cinematic() -> void:
	if current_state == State.IDLE:
		return

	if current_cinematic and not current_cinematic.can_skip:
		push_warning("CinematicsManager: Current cinematic cannot be skipped")
		return

	# Interrupt any active async executor to allow cleanup
	if _current_executor:
		_current_executor.interrupt()
		_current_executor = null

	cinematic_skipped.emit()
	_end_cinematic()


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


# =============================================================================
# AUTO-CINEMATIC GENERATION (Quick Setup NPC System)
# =============================================================================

## Default greetings per NPC role
const AUTO_GREETINGS: Dictionary = {
	"SHOPKEEPER": "Welcome to my shop!",
	"PRIEST": "Welcome, weary traveler. How may I serve you?",
	"INNKEEPER": "Welcome, traveler. Looking for a place to rest?",
	"CARAVAN_DEPOT": "The caravan is ready for your storage needs.",
	"CRAFTER": "Welcome! What can I craft for you today?"
}

## Default farewells per NPC role
const AUTO_FAREWELLS: Dictionary = {
	"SHOPKEEPER": "Come again!",
	"PRIEST": "May light guide your path...",
	"INNKEEPER": "Rest well!",
	"CARAVAN_DEPOT": "Safe travels!",
	"CRAFTER": "May your new gear serve you well!"
}


## Generate a CinematicData at runtime for Quick Setup NPCs
## Auto-cinematic IDs have format: __auto__{npc_id}::{shop_id}
## Uses :: delimiter to avoid conflicts with underscores in IDs
## Returns null if generation fails
func _generate_auto_cinematic(cinematic_id: String) -> CinematicData:
	# Parse the auto-cinematic ID
	# Format: __auto__{npc_id}::{shop_id}
	var content: String = cinematic_id.substr(8)  # Skip "__auto__"
	var delimiter_pos: int = content.find("::")
	if delimiter_pos <= 0:
		push_error("CinematicsManager: Invalid auto-cinematic ID format: %s" % cinematic_id)
		return null

	var npc_id: String = content.substr(0, delimiter_pos)
	var shop_id: String = content.substr(delimiter_pos + 2)  # Skip "::"

	# Look up the NPC data
	var npc_data: NPCData = ModLoader.registry.get_resource("npc", npc_id) as NPCData
	if not npc_data:
		push_error("CinematicsManager: NPC '%s' not found for auto-cinematic" % npc_id)
		return null

	# Build the cinematic based on the NPC's role
	var cinematic: CinematicData = CinematicData.new()
	cinematic.cinematic_id = cinematic_id
	cinematic.cinematic_name = "Auto: %s" % npc_id
	cinematic.disable_player_input = true
	cinematic.can_skip = false  # Can't skip shop interactions

	# Get role name for lookup
	var role_name: String = _get_role_name(npc_data.npc_role)

	# Get greeting text (custom or default)
	var greeting: String = npc_data.greeting_text
	if greeting.is_empty():
		greeting = AUTO_GREETINGS.get(role_name, "Hello!")

	# Get farewell text (custom or default)
	var farewell: String = npc_data.farewell_text
	if farewell.is_empty():
		farewell = AUTO_FAREWELLS.get(role_name, "Goodbye!")

	# Get speaker name
	var speaker_name: String = npc_data.get_display_name()

	# Build cinematic commands based on role
	match npc_data.npc_role:
		NPCData.NPCRole.SHOPKEEPER, NPCData.NPCRole.PRIEST, NPCData.NPCRole.INNKEEPER, NPCData.NPCRole.CRAFTER:
			# Standard flow: greeting -> shop -> farewell
			cinematic.add_dialog_line(speaker_name, greeting)
			cinematic.add_open_shop(shop_id)
			cinematic.add_dialog_line(speaker_name, farewell)

		NPCData.NPCRole.CARAVAN_DEPOT:
			# Caravan flow: greeting -> caravan interface -> farewell
			# Note: We use open_shop with special "caravan" type handling
			# (requires CaravanController integration in open_shop_executor or separate executor)
			cinematic.add_dialog_line(speaker_name, greeting)
			# For now, caravan depot NPCs need a special shop type or custom handling
			# This is a placeholder - the actual caravan opening would need integration
			push_warning("CinematicsManager: CARAVAN_DEPOT auto-cinematic - caravan interface integration pending")
			cinematic.add_dialog_line(speaker_name, farewell)

		_:
			push_error("CinematicsManager: Cannot generate auto-cinematic for role: %s" % role_name)
			return null

	return cinematic


## Convert NPCRole enum to string name for dictionary lookup
func _get_role_name(role: NPCData.NPCRole) -> String:
	match role:
		NPCData.NPCRole.NONE: return "NONE"
		NPCData.NPCRole.SHOPKEEPER: return "SHOPKEEPER"
		NPCData.NPCRole.PRIEST: return "PRIEST"
		NPCData.NPCRole.INNKEEPER: return "INNKEEPER"
		NPCData.NPCRole.CARAVAN_DEPOT: return "CARAVAN_DEPOT"
		NPCData.NPCRole.CRAFTER: return "CRAFTER"
	return "NONE"


## Disable player input
func _disable_player_input() -> void:
	# InputManager is for battles - only try to disable if it has the method
	if InputManager.has_method("set_input_enabled"):
		var current_state: Variant = InputManager.get("input_enabled")
		_previous_input_state = current_state if current_state != null else true
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
	for actor_def: Variant in actors:
		if not actor_def is Dictionary:
			push_warning("CinematicsManager: Invalid actor definition (not a dictionary)")
			continue

		var actor_dict: Dictionary = actor_def as Dictionary
		_spawn_single_actor(actor_dict)


## Spawn a single actor from a definition dictionary
## Format: {actor_id, character_id, position: [x, y], facing}
func _spawn_single_actor(actor_def: Dictionary) -> void:
	var actor_id: String = actor_def.get("actor_id", "")
	if actor_id.is_empty():
		push_warning("CinematicsManager: Actor definition missing actor_id")
		return

	# Check for existing actor with this ID
	if get_actor(actor_id) != null:
		push_warning("CinematicsManager: Actor '%s' already exists from actors array" % actor_id)

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

	# Get optional character_id for sprite
	var character_id: String = actor_def.get("character_id", "")

	# Create the spawned entity structure
	var entity: CharacterBody2D = CharacterBody2D.new()
	entity.name = "SpawnedActor_%s" % actor_id

	# Position at grid coordinates
	entity.global_position = GridManager.cell_to_world(grid_pos)

	# Create AnimatedSprite2D
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"

	if not character_id.is_empty():
		var char_data: CharacterData = ModLoader.registry.get_resource("character", character_id) as CharacterData
		if char_data != null and char_data.sprite_frames != null:
			sprite.sprite_frames = char_data.sprite_frames
			var initial_anim: String = "walk_" + facing
			if sprite.sprite_frames.has_animation(initial_anim):
				sprite.play(initial_anim)

	entity.add_child(sprite)

	# Create CinematicActor component
	var cinematic_actor: CinematicActor = CinematicActor.new()
	cinematic_actor.name = "CinematicActor"
	cinematic_actor.actor_id = actor_id
	cinematic_actor.sprite_node = sprite
	entity.add_child(cinematic_actor)

	# Add to scene tree
	var scene_root: Node = get_tree().current_scene
	if scene_root:
		scene_root.add_child(entity)
		_track_spawned_actor(entity)
	else:
		push_error("CinematicsManager: No current scene to add actor to")
		entity.queue_free()


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
	for cmd: Variant in commands:
		if cmd is Dictionary:
			cinematic.commands.append(cmd)

	return play_cinematic_from_resource(cinematic)


# =============================================================================
# INTERACTABLE AUTO-CINEMATICS
# =============================================================================

## Preload InteractableData for type access
const InteractableDataScript: GDScript = preload("res://core/resources/interactable_data.gd")

## Generate auto-cinematic for interactable objects (chests, bookshelves, etc.)
## Format: __auto_interactable__{interactable_id}
func _generate_interactable_auto_cinematic(cinematic_id: String) -> CinematicData:
	# Parse the interactable ID (format: __auto_interactable__{id})
	var interactable_id: String = cinematic_id.substr(21)  # Skip "__auto_interactable__"

	if interactable_id.is_empty():
		push_error("CinematicsManager: Invalid auto-interactable cinematic ID: %s" % cinematic_id)
		return null

	# Look up the interactable data
	var interactable: Resource = ModLoader.registry.get_resource("interactable", interactable_id)
	if not interactable:
		push_error("CinematicsManager: Interactable '%s' not found for auto-cinematic" % interactable_id)
		return null

	# Cast to InteractableData (can't use class_name in type hint due to load order)
	if not interactable.has_method("has_rewards"):
		push_error("CinematicsManager: Invalid interactable resource for '%s'" % interactable_id)
		return null

	# Build the cinematic
	var cinematic: CinematicData = CinematicData.new()
	cinematic.cinematic_id = cinematic_id
	cinematic.cinematic_name = "Auto: %s" % interactable_id
	cinematic.disable_player_input = true
	cinematic.can_skip = true

	# Grant items/gold if present
	if interactable.has_rewards():
		cinematic.commands.append({
			"type": "grant_items",
			"params": {
				"items": interactable.item_rewards,
				"gold": interactable.gold_reward,
				"show_message": true
			}
		})

	# Show dialog text if present
	var dialog_text: String = interactable.dialog_text if "dialog_text" in interactable else ""
	if not dialog_text.is_empty():
		cinematic.commands.append({
			"type": "dialog",
			"params": {
				"text": dialog_text
			}
		})

	# If no commands at all, add type-specific default message
	if cinematic.commands.is_empty():
		var default_msg: String = InteractableDataScript.FALLBACK_EMPTY_MESSAGE
		if "interactable_type" in interactable:
			default_msg = InteractableDataScript.get_default_empty_message(interactable.interactable_type)
		cinematic.commands.append({
			"type": "dialog",
			"params": {
				"text": default_msg
			}
		})

	return cinematic
