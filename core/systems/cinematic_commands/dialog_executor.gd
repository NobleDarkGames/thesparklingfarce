## Dialog command executor
## Shows dialog by delegating to DialogManager
## Supports both:
##   - dialogue_id: lookup existing DialogueData from ModRegistry
##   - lines: inline dialog lines (creates temporary DialogueData)
class_name DialogExecutor
extends CinematicCommandExecutor

## Counter for generating unique inline dialog IDs
static var _inline_dialog_counter: int = 0


func execute(command: Dictionary, manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})

	# Check for inline lines first
	if "lines" in params:
		return _execute_inline_dialog(params, manager)

	# Fall back to dialogue_id lookup
	var dialogue_id: String = params.get("dialogue_id", "")
	if dialogue_id.is_empty():
		push_error("DialogExecutor: Missing dialogue_id or lines")
		return true  # Complete immediately on error

	# Start dialog via DialogManager (proper delegation pattern)
	if DialogManager.start_dialog(dialogue_id):
		manager.current_state = manager.State.WAITING_FOR_DIALOG
		return false  # Async - dialog_ended signal will set _command_completed
	else:
		push_error("DialogExecutor: Failed to start dialog '%s'" % dialogue_id)
		return true  # Complete immediately on error


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
			var line_dict: Dictionary = (line_data as Dictionary).duplicate()

			# Resolve character_id to speaker_name and portrait if present
			if "character_id" in line_dict and not "speaker_name" in line_dict:
				var character_id: String = str(line_dict["character_id"])
				var char_data: Dictionary = _resolve_character_data(character_id)
				line_dict["speaker_name"] = char_data["name"]
				if char_data["portrait"] != null:
					line_dict["portrait"] = char_data["portrait"]
				line_dict.erase("character_id")

			dialogue.lines.append(line_dict)

	# Start dialog from the temporary resource
	if DialogManager.start_dialog_from_resource(dialogue):
		manager.current_state = manager.State.WAITING_FOR_DIALOG
		return false  # Async
	else:
		push_error("DialogExecutor: Failed to start inline dialog")
		return true


## Resolve a character_id to character data (name and portrait)
## Returns Dictionary with "name" and optionally "portrait"
func _resolve_character_data(character_id: String) -> Dictionary:
	var result: Dictionary = {"name": "", "portrait": null}

	if character_id.is_empty():
		return result

	# Try to look up character in ModRegistry
	if ModLoader and ModLoader.registry:
		var character: CharacterData = ModLoader.registry.get_character_by_uid(character_id)
		if character:
			result["name"] = character.character_name
			if character.portrait:
				result["portrait"] = character.portrait
			return result

	# Fallback: return the ID in brackets with a warning
	push_warning("DialogExecutor: Could not resolve character_id '%s' - character not found" % character_id)
	result["name"] = "[%s]" % character_id
	return result
