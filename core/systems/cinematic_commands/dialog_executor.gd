## Dialog command executor
## Shows dialog by delegating to DialogManager
## Supports both:
##   - dialogue_id: lookup existing DialogueData from ModRegistry
##   - lines: inline dialog lines (creates temporary DialogueData)
class_name DialogExecutor
extends CinematicCommandExecutor

const CinematicActor = preload("res://core/components/cinematic_actor.gd")


func execute(command: Dictionary, manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})

	# Check for inline lines first (show_dialog with lines array)
	if "lines" in params:
		return _execute_inline_dialog(params, manager)

	# Check for single dialog_line format (character_id + text directly in params)
	# This is the format created by the Cinematic Editor's dialog_line command
	if "text" in params:
		return _execute_single_line(params, manager)

	# Fall back to dialogue_id lookup
	var dialogue_id: String = params.get("dialogue_id", "")
	if dialogue_id.is_empty():
		push_error("DialogExecutor: Missing dialogue_id, lines, or text")
		return true  # Complete immediately on error

	# Start dialog via DialogManager (proper delegation pattern)
	if DialogManager.start_dialog(dialogue_id):
		manager.current_state = CinematicsManager.State.WAITING_FOR_DIALOG
		# CRITICAL: Set _is_waiting to prevent the "continue immediately" logic
		# in _execute_next_command() from overriding our async state
		manager._is_waiting = true
		return false  # Async - dialog_ended signal will set _command_completed
	else:
		push_error("DialogExecutor: Failed to start dialog '%s'" % dialogue_id)
		return true  # Complete immediately on error


## Execute a single dialog_line command (character_id, text, emotion in params directly)
func _execute_single_line(params: Dictionary, manager: Node) -> bool:
	var text: String = params.get("text", "")
	if text.is_empty():
		push_error("DialogExecutor: dialog_line has empty text")
		return true

	# Build the line dictionary
	var line_dict: Dictionary = {
		"text": text,
		"emotion": params.get("emotion", "neutral")
	}

	# Resolve character_id to speaker_name and portrait if present
	var character_id: String = params.get("character_id", "")
	if not character_id.is_empty():
		var char_data: Dictionary = CinematicCommandExecutor.resolve_character_data(character_id)
		line_dict["speaker_name"] = char_data["name"]
		if char_data["portrait"] != null:
			line_dict["portrait"] = char_data["portrait"]

		# Auto-follow: move camera to speaker if enabled (default true)
		var auto_follow: bool = params.get("auto_follow", true)
		if auto_follow:
			_auto_follow_character(character_id, manager)
	else:
		line_dict["speaker_name"] = ""

	# Create temporary DialogueData with single line
	var dialogue: DialogueData = DialogueData.new()
	_inline_dialog_counter += 1
	dialogue.dialogue_id = "_dialog_line_%s_%d" % [
		str(Time.get_ticks_msec()),
		_inline_dialog_counter
	]
	dialogue.lines.append(line_dict)

	# Start dialog from the temporary resource
	if DialogManager.start_dialog_from_resource(dialogue):
		manager.current_state = CinematicsManager.State.WAITING_FOR_DIALOG
		manager._is_waiting = true
		return false  # Async
	else:
		push_error("DialogExecutor: Failed to start dialog_line")
		return true


func _execute_inline_dialog(params: Dictionary, manager: Node) -> bool:
	var lines: Array = params.get("lines", [])
	if lines.is_empty():
		push_error("DialogExecutor: Inline dialog has no lines")
		return true

	# Auto-follow: check first line's character for camera follow
	var auto_follow: bool = params.get("auto_follow", true)
	if auto_follow and lines.size() > 0:
		var first_line: Variant = lines[0]
		if first_line is Dictionary:
			var first_char_id: String = str(first_line.get("character_id", ""))
			if not first_char_id.is_empty():
				_auto_follow_character(first_char_id, manager)

	# Create temporary DialogueData
	var dialogue: DialogueData = DialogueData.new()

	# Generate unique ID to satisfy validation and prevent false circular detection
	_inline_dialog_counter += 1
	dialogue.dialogue_id = "_inline_%s_%d" % [
		str(Time.get_ticks_msec()),
		_inline_dialog_counter
	]

	# Copy lines into the DialogueData, resolving character_id if present
	for line_data: Variant in lines:
		if line_data is Dictionary:
			var line_dict: Dictionary = line_data.duplicate()

			# Resolve character_id to speaker_name and portrait if present
			if "character_id" in line_dict and not "speaker_name" in line_dict:
				var char_id: String = str(line_dict["character_id"])
				var char_data: Dictionary = CinematicCommandExecutor.resolve_character_data(char_id)
				line_dict["speaker_name"] = char_data["name"]
				if char_data["portrait"] != null:
					line_dict["portrait"] = char_data["portrait"]
				line_dict.erase("character_id")

			dialogue.lines.append(line_dict)

	# Start dialog from the temporary resource
	if DialogManager.start_dialog_from_resource(dialogue):
		manager.current_state = CinematicsManager.State.WAITING_FOR_DIALOG
		# CRITICAL: Set _is_waiting to prevent the "continue immediately" logic
		# in _execute_next_command() from overriding our async state
		manager._is_waiting = true
		return false  # Async
	else:
		push_error("DialogExecutor: Failed to start inline dialog")
		return true


## Called when the cinematic is interrupted (e.g., skipped by player)
## CRITICAL: This must end any active dialog to prevent stale state.
## Without this, DialogManager.is_dialog_active() would return true after
## skipping a cinematic during dialog, blocking hero input on subsequent scenes.
func interrupt() -> void:
	if DialogManager and DialogManager.is_dialog_active():
		DialogManager.end_dialog()


## Auto-follow: move camera to the speaking character before dialog
## Does NOT wait for completion - camera catches up while dialog shows
func _auto_follow_character(character_id: String, manager: Node) -> void:
	# Find actor by character UID
	var actor: CinematicActor = manager.get_actor_by_character_uid(character_id)
	if actor == null:
		return

	# Get actor's parent entity position
	var entity: Node2D = actor.parent_entity
	if not is_instance_valid(entity):
		return

	# Try CameraController first (battle/cinematic stages)
	var camera: CameraController = manager.get_camera_controller()
	if camera:
		# Stop any existing follow, move to speaker, set them as new follow target
		camera.stop_follow()
		camera.move_to_position(entity.global_position, 0.3, false)
		camera._follow_target = entity
		return

	# Fallback: Try MapCamera (exploration mode)
	var active_camera: Camera2D = manager.get_active_camera()
	if active_camera is MapCamera:
		var map_camera: MapCamera = active_camera as MapCamera
		map_camera.set_cinematic_target(entity)
