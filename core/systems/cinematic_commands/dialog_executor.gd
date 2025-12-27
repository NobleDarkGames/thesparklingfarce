## Dialog command executor
## Shows dialog by delegating to DialogManager
## Supports both:
##   - dialogue_id: lookup existing DialogueData from ModRegistry
##   - lines: inline dialog lines (creates temporary DialogueData)
class_name DialogExecutor
extends CinematicCommandExecutor


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
