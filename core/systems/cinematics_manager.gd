extends Node

## CinematicsManager - Orchestrates cinematic sequences
## Singleton autoload that executes scripted cutscenes with character movement,
## camera control, dialog, and game state changes.
## Accessed globally as CinematicsManager (autoload name)

# Preload custom types to ensure they're available
const CinematicData: GDScript = preload("res://core/resources/cinematic_data.gd")
const CinematicActor: GDScript = preload("res://core/components/cinematic_actor.gd")

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

## Player input state
var _player_input_disabled: bool = false
var _previous_input_state: bool = false

## Wait timer for wait commands
var _wait_timer: float = 0.0
var _is_waiting: bool = false

## Command execution state
var _current_command_waits: bool = false
var _command_completed: bool = false


func _ready() -> void:
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

	# Disable player input if requested
	if cinematic.disable_player_input:
		_disable_player_input()

	emit_signal("cinematic_started", cinematic.cinematic_id)

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

	match command_type:
		"move_entity":
			_execute_move_entity(command)
		"set_facing":
			_execute_set_facing(command)
		"play_animation":
			_execute_play_animation(command)
		"show_dialog":
			_execute_show_dialog(command)
		"camera_move":
			_execute_camera_move(command)
		"camera_follow":
			_execute_camera_follow(command)
		"camera_shake":
			_execute_camera_shake(command)
		"wait":
			_execute_wait(command)
		"fade_screen":
			_execute_fade_screen(command)
		"play_sound":
			_execute_play_sound(command)
		"play_music":
			_execute_play_music(command)
		"spawn_entity":
			_execute_spawn_entity(command)
		"despawn_entity":
			_execute_despawn_entity(command)
		"set_variable":
			_execute_set_variable(command)
		_:
			push_warning("CinematicsManager: Unknown command type '%s'" % command_type)
			_command_completed = true

	# Move to next command
	current_command_index += 1

	# If command doesn't wait, continue immediately
	if not _current_command_waits and not _is_waiting:
		_command_completed = true


## Execute move_entity command
func _execute_move_entity(command: Dictionary) -> void:
	var target: String = command.get("target", "")
	var params: Dictionary = command.get("params", {})

	var actor: CinematicActor = get_actor(target)
	if actor == null:
		push_error("CinematicsManager: Actor '%s' not found for move_entity" % target)
		_command_completed = true
		return

	var path: Array = params.get("path", [])
	var speed: float = params.get("speed", -1.0)
	var should_wait: bool = params.get("wait", true)

	# Convert array elements to Vector2 if needed
	var converted_path: Array = []
	for pos: Variant in path:
		if pos is Array and pos.size() >= 2:
			converted_path.append(Vector2(pos[0], pos[1]))
		elif pos is Vector2:
			converted_path.append(pos)
		else:
			push_error("CinematicsManager: Invalid path position: %s" % str(pos))

	if should_wait:
		# Connect to movement_completed signal
		if not actor.movement_completed.is_connected(_on_movement_completed):
			actor.movement_completed.connect(_on_movement_completed)

	actor.move_along_path(converted_path, speed, true)

	if not should_wait:
		_command_completed = true


## Execute set_facing command
func _execute_set_facing(command: Dictionary) -> void:
	var target: String = command.get("target", "")
	var params: Dictionary = command.get("params", {})

	var actor: CinematicActor = get_actor(target)
	if actor == null:
		push_error("CinematicsManager: Actor '%s' not found for set_facing" % target)
		_command_completed = true
		return

	var direction: String = params.get("direction", "down")
	actor.set_facing(direction)

	_command_completed = true


## Execute play_animation command
func _execute_play_animation(command: Dictionary) -> void:
	var target: String = command.get("target", "")
	var params: Dictionary = command.get("params", {})

	var actor: CinematicActor = get_actor(target)
	if actor == null:
		push_error("CinematicsManager: Actor '%s' not found for play_animation" % target)
		_command_completed = true
		return

	var animation: String = params.get("animation", "")
	var should_wait: bool = params.get("wait", false)

	if should_wait:
		# Connect to animation_completed signal
		if not actor.animation_completed.is_connected(_on_animation_completed):
			actor.animation_completed.connect(_on_animation_completed)

	actor.play_animation(animation, should_wait)

	if not should_wait:
		_command_completed = true


## Execute show_dialog command
func _execute_show_dialog(command: Dictionary) -> void:
	var params: Dictionary = command.get("params", {})
	var dialogue_id: String = params.get("dialogue_id", "")

	if dialogue_id.is_empty():
		push_error("CinematicsManager: show_dialog command missing dialogue_id")
		_command_completed = true
		return

	# Start dialog via DialogManager
	if DialogManager.start_dialog(dialogue_id):
		current_state = State.WAITING_FOR_DIALOG
	else:
		push_error("CinematicsManager: Failed to start dialog '%s'" % dialogue_id)
		_command_completed = true


## Execute camera_move command
func _execute_camera_move(command: Dictionary) -> void:
	var params: Dictionary = command.get("params", {})
	var target_pos: Vector2 = params.get("target_pos", Vector2.ZERO)
	var speed: float = params.get("speed", 2.0)

	# TODO: Implement camera movement
	# For now, just complete immediately
	push_warning("CinematicsManager: camera_move not yet implemented")
	_command_completed = true


## Execute camera_follow command
func _execute_camera_follow(command: Dictionary) -> void:
	var target: String = command.get("target", "")

	var actor: CinematicActor = get_actor(target)
	if actor == null:
		push_error("CinematicsManager: Actor '%s' not found for camera_follow" % target)
		_command_completed = true
		return

	# TODO: Implement camera follow
	push_warning("CinematicsManager: camera_follow not yet implemented")
	_command_completed = true


## Execute camera_shake command
func _execute_camera_shake(command: Dictionary) -> void:
	var params: Dictionary = command.get("params", {})

	# TODO: Implement camera shake
	push_warning("CinematicsManager: camera_shake not yet implemented")
	_command_completed = true


## Execute wait command
func _execute_wait(command: Dictionary) -> void:
	var params: Dictionary = command.get("params", {})
	var duration: float = params.get("duration", 1.0)

	_wait_timer = duration
	_is_waiting = true


## Execute fade_screen command
func _execute_fade_screen(command: Dictionary) -> void:
	var params: Dictionary = command.get("params", {})

	# TODO: Implement screen fade
	push_warning("CinematicsManager: fade_screen not yet implemented")
	_command_completed = true


## Execute play_sound command
func _execute_play_sound(command: Dictionary) -> void:
	var params: Dictionary = command.get("params", {})
	var sound_id: String = params.get("sound_id", "")

	# TODO: Integrate with AudioManager
	push_warning("CinematicsManager: play_sound not yet implemented")
	_command_completed = true


## Execute play_music command
func _execute_play_music(command: Dictionary) -> void:
	var params: Dictionary = command.get("params", {})

	# TODO: Integrate with AudioManager
	push_warning("CinematicsManager: play_music not yet implemented")
	_command_completed = true


## Execute spawn_entity command
func _execute_spawn_entity(command: Dictionary) -> void:
	var params: Dictionary = command.get("params", {})

	# TODO: Implement entity spawning
	push_warning("CinematicsManager: spawn_entity not yet implemented")
	_command_completed = true


## Execute despawn_entity command
func _execute_despawn_entity(command: Dictionary) -> void:
	var target: String = command.get("target", "")

	var actor: CinematicActor = get_actor(target)
	if actor == null:
		push_error("CinematicsManager: Actor '%s' not found for despawn_entity" % target)
		_command_completed = true
		return

	# TODO: Implement entity despawning
	push_warning("CinematicsManager: despawn_entity not yet implemented")
	_command_completed = true


## Execute set_variable command
func _execute_set_variable(command: Dictionary) -> void:
	var params: Dictionary = command.get("params", {})
	var variable_name: String = params.get("variable", "")
	var value: Variant = params.get("value", null)

	if variable_name.is_empty():
		push_error("CinematicsManager: set_variable command missing variable name")
		_command_completed = true
		return

	# Set in GameState
	GameState.set_flag(variable_name)
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

	# Clear current data
	current_cinematic = null
	current_command_index = 0
	_command_completed = false
	_is_waiting = false

	emit_signal("cinematic_ended", finished_cinematic.cinematic_id if finished_cinematic else "")

	current_state = State.IDLE

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
	_previous_input_state = InputManager.input_enabled
	InputManager.set_input_enabled(false)
	_player_input_disabled = true


## Re-enable player input
func _enable_player_input() -> void:
	InputManager.set_input_enabled(_previous_input_state)
	_player_input_disabled = false
