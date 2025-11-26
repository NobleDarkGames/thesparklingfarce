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

## Camera control
var _active_camera: Camera2D = null
var _camera_tween: Tween = null
var _camera_original_position: Vector2 = Vector2.ZERO
var _camera_shake_timer: float = 0.0
var _camera_shake_intensity: float = 0.0
var _camera_follow_target: Node = null  ## Actor to continuously follow
var _camera_follow_speed: float = 8.0   ## Camera follow smoothness

## Fade overlay
var _fade_overlay: ColorRect = null


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

	# Handle continuous camera follow
	if _camera_follow_target and _active_camera:
		var target_pos: Vector2 = _camera_follow_target.get_world_position() if _camera_follow_target.has_method("get_world_position") else _camera_follow_target.global_position
		_active_camera.global_position = _active_camera.global_position.lerp(target_pos, _camera_follow_speed * delta)

	# Handle camera shake
	if _camera_shake_timer > 0.0 and _active_camera:
		_camera_shake_timer -= delta

		# Apply random shake offset
		var shake_offset: Vector2 = Vector2(
			randf_range(-_camera_shake_intensity, _camera_shake_intensity),
			randf_range(-_camera_shake_intensity, _camera_shake_intensity)
		)
		_active_camera.offset = shake_offset

		# Check if shake completed
		if _camera_shake_timer <= 0.0:
			_active_camera.offset = Vector2.ZERO
			_camera_shake_timer = 0.0
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


## Register a camera for cinematic control
## The active scene's camera will be auto-detected, but can be set explicitly
func register_camera(camera: Camera2D) -> void:
	_active_camera = camera
	if camera:
		_camera_original_position = camera.global_position


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

	# Check custom executor registry first (allows mods to add/override commands)
	if command_type in _command_executors:
		_current_executor = _command_executors[command_type]
		var completed: bool = _current_executor.execute(command, self)
		if completed:
			_command_completed = true
		# else: executor will set _command_completed = true when async operation finishes
	else:
		# Fallback to built-in commands (will be migrated to executors in Phase 2)
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
	var should_wait: bool = params.get("wait", true)

	if not _active_camera:
		push_warning("CinematicsManager: No camera available for camera_move")
		_command_completed = true
		return

	# Convert grid position to world position if needed
	var world_pos: Vector2 = target_pos
	if params.get("is_grid", false):
		world_pos = GridManager.cell_to_world(Vector2i(target_pos))

	# Kill any existing camera tween
	if _camera_tween and _camera_tween.is_valid():
		_camera_tween.kill()
		_camera_tween = null

	# Calculate duration based on speed (speed is tiles per second)
	var distance: float = _active_camera.global_position.distance_to(world_pos)
	var duration: float = distance / (speed * GridManager.get_tile_size())
	duration = max(duration, 0.1)  # Minimum duration

	# Create tween for smooth camera movement
	_camera_tween = create_tween()
	_camera_tween.set_trans(Tween.TRANS_CUBIC)
	_camera_tween.set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(_active_camera, "global_position", world_pos, duration)

	if should_wait:
		_camera_tween.tween_callback(func() -> void: _command_completed = true)
	else:
		_command_completed = true


## Execute camera_follow command
func _execute_camera_follow(command: Dictionary) -> void:
	var target: String = command.get("target", "")
	var params: Dictionary = command.get("params", {})
	var should_wait: bool = params.get("wait", false)
	var duration: float = params.get("duration", 0.5)
	var continuous: bool = params.get("continuous", true)  ## Keep following until explicitly stopped

	if not _active_camera:
		push_warning("CinematicsManager: No camera available for camera_follow")
		_command_completed = true
		return

	var actor: CinematicActor = get_actor(target)
	if actor == null:
		push_error("CinematicsManager: Actor '%s' not found for camera_follow" % target)
		_command_completed = true
		return

	# Get actor's world position
	var actor_pos: Vector2 = actor.get_world_position()

	# Kill any existing camera tween
	if _camera_tween and _camera_tween.is_valid():
		_camera_tween.kill()
		_camera_tween = null

	if continuous:
		# Enable continuous follow (handled in _process)
		_camera_follow_target = actor
		_camera_follow_speed = params.get("speed", 8.0)

		# Do initial move to actor position
		_camera_tween = create_tween()
		_camera_tween.set_trans(Tween.TRANS_CUBIC)
		_camera_tween.set_ease(Tween.EASE_IN_OUT)
		_camera_tween.tween_property(_active_camera, "global_position", actor_pos, duration)

		if should_wait:
			_camera_tween.tween_callback(func() -> void: _command_completed = true)
		else:
			_command_completed = true
	else:
		# One-time move to actor
		_camera_follow_target = null
		_camera_tween = create_tween()
		_camera_tween.set_trans(Tween.TRANS_CUBIC)
		_camera_tween.set_ease(Tween.EASE_IN_OUT)
		_camera_tween.tween_property(_active_camera, "global_position", actor_pos, duration)

		if should_wait:
			_camera_tween.tween_callback(func() -> void: _command_completed = true)
		else:
			_command_completed = true


## Execute camera_shake command
func _execute_camera_shake(command: Dictionary) -> void:
	var params: Dictionary = command.get("params", {})
	var intensity: float = params.get("intensity", 2.0)
	var duration: float = params.get("duration", 0.5)
	var should_wait: bool = params.get("wait", false)

	if not _active_camera:
		push_warning("CinematicsManager: No camera available for camera_shake")
		_command_completed = true
		return

	# Set shake parameters
	_camera_shake_intensity = intensity
	_camera_shake_timer = duration

	if not should_wait:
		_command_completed = true
	# else: _process will set _command_completed when shake finishes


## Execute wait command
func _execute_wait(command: Dictionary) -> void:
	var params: Dictionary = command.get("params", {})
	var duration: float = params.get("duration", 1.0)

	_wait_timer = duration
	_is_waiting = true


## Execute fade_screen command
func _execute_fade_screen(command: Dictionary) -> void:
	var params: Dictionary = command.get("params", {})
	var fade_type: String = params.get("fade_type", "out")  # "in" or "out"
	var duration: float = params.get("duration", 1.0)
	var color: Color = params.get("color", Color.BLACK)

	# Ensure fade overlay exists
	_ensure_fade_overlay()

	if not _fade_overlay:
		push_warning("CinematicsManager: Failed to create fade overlay")
		_command_completed = true
		return

	# Set initial color based on fade type
	if fade_type == "in":
		# Fade in: start opaque, end transparent
		_fade_overlay.color = Color(color.r, color.g, color.b, 1.0)
		_fade_overlay.show()
	else:
		# Fade out: start transparent, end opaque
		_fade_overlay.color = Color(color.r, color.g, color.b, 0.0)
		_fade_overlay.show()

	# Create tween for fade
	var fade_tween: Tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_LINEAR)

	if fade_type == "in":
		# Fade to transparent
		fade_tween.tween_property(_fade_overlay, "color:a", 0.0, duration)
		fade_tween.tween_callback(func() -> void:
			_fade_overlay.hide()
			_command_completed = true
		)
	else:
		# Fade to opaque
		fade_tween.tween_property(_fade_overlay, "color:a", 1.0, duration)
		fade_tween.tween_callback(func() -> void: _command_completed = true)


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

	# Stop camera follow
	_camera_follow_target = null

	# Reset camera shake
	if _active_camera:
		_active_camera.offset = Vector2.ZERO
	_camera_shake_timer = 0.0

	# Clear current data
	current_cinematic = null
	current_command_index = 0
	_command_completed = false
	_is_waiting = false
	_current_executor = null  # Clear executor reference

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


## Ensure fade overlay exists in the scene tree
func _ensure_fade_overlay() -> void:
	if _fade_overlay:
		return

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
