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
signal cinematic_paused()
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

## Command execution state
var _current_command_waits: bool = false
var _command_completed: bool = false

## Camera control (Phase 3: camera logic now in CameraController)
var _active_camera: Camera2D = null
var _camera_original_position: Vector2 = Vector2.ZERO

## Fade overlay (DEPRECATED - use SceneManager.fade_to_black/fade_from_black instead)
## Kept for backwards compatibility with custom mods that may reference it
var _fade_overlay: ColorRect = null


func _ready() -> void:
	# Disable per-frame processing when idle (optimization)
	set_process(false)

	# Register all built-in command executors
	_register_built_in_commands()

	# Connect to DialogManager signals
	if DialogManager:
		DialogManager.dialog_ended.connect(_on_dialog_ended)


func _process(delta: float) -> void:
	# Handle wait timer
	if _is_waiting:
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
	print("CinematicsManager: Registered executor for command type '%s'" % command_type)


## Unregister a command executor
func unregister_command_executor(command_type: String) -> void:
	if _command_executors.erase(command_type):
		print("CinematicsManager: Unregistered executor for command type '%s'" % command_type)


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

	# Register all built-in commands
	register_command_executor("wait", WaitExecutor.new())
	register_command_executor("set_variable", SetVariableExecutor.new())
	register_command_executor("show_dialog", DialogExecutor.new())
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

	print("CinematicsManager: Registered 14 built-in command executors")


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
func play_cinematic(cinematic_id: String) -> bool:
	if current_state != State.IDLE:
		push_warning("CinematicsManager: Cannot play cinematic '%s' - cinematic already active" % cinematic_id)
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

	emit_signal("cinematic_started", cinematic.cinematic_id)

	# Enable per-frame processing while cinematic is active
	set_process(true)

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
	emit_signal("command_executed", command_type, current_command_index)

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

	# Clear current data
	current_cinematic = null
	current_command_index = 0
	_command_completed = false
	_is_waiting = false
	_current_executor = null  # Clear executor reference

	emit_signal("cinematic_ended", finished_cinematic.cinematic_id if finished_cinematic else "")

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

	emit_signal("cinematic_skipped")
	_end_cinematic()


## Pause the current cinematic
func pause_cinematic() -> void:
	if current_state != State.PLAYING:
		return

	current_state = State.PAUSED
	emit_signal("cinematic_paused")


## Resume the paused cinematic
func resume_cinematic() -> void:
	if current_state != State.PAUSED:
		return

	current_state = State.PLAYING
	emit_signal("cinematic_resumed")


## Check if a cinematic is currently active
func is_cinematic_active() -> bool:
	return current_state != State.IDLE


## Get the current state
func get_current_state() -> State:
	return current_state


## Disable player input
func _disable_player_input() -> void:
	# InputManager is for battles - only try to disable if it has the method
	if InputManager.has_method("set_input_enabled"):
		_previous_input_state = InputManager.get("input_enabled") if "input_enabled" in InputManager else true
		InputManager.set_input_enabled(false)

	_player_input_disabled = true


## Re-enable player input
func _enable_player_input() -> void:
	# InputManager is for battles - only try to re-enable if it has the method
	if InputManager.has_method("set_input_enabled"):
		InputManager.set_input_enabled(_previous_input_state)

	_player_input_disabled = false


## DEPRECATED: Ensure fade overlay exists in the scene tree
## Now handled by SceneManager. Kept for backwards compatibility with custom mods.
func _ensure_fade_overlay() -> void:
	# Check if existing overlay is still valid (may have been freed on scene change)
	if _fade_overlay and is_instance_valid(_fade_overlay):
		return

	# Clear stale reference if overlay was freed
	_fade_overlay = null

	# Get the scene root
	var scene_root: Node = get_tree().current_scene
	if not scene_root:
		push_error("CinematicsManager: No current scene for fade overlay")
		return

	# Find or create CanvasLayer for fade overlay
	var canvas_layer: CanvasLayer = null
	for child: Node in scene_root.get_children():
		if child is CanvasLayer and child.name == "CinematicOverlay":
			canvas_layer = child as CanvasLayer
			break

	if not canvas_layer:
		canvas_layer = CanvasLayer.new()
		canvas_layer.name = "CinematicOverlay"
		canvas_layer.layer = 100  # High layer to be on top
		scene_root.add_child(canvas_layer)

	# Create fade overlay ColorRect
	_fade_overlay = ColorRect.new()
	_fade_overlay.name = "FadeOverlay"
	_fade_overlay.color = Color(0, 0, 0, 0)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.hide()

	# Make it cover the entire viewport
	_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	canvas_layer.add_child(_fade_overlay)
