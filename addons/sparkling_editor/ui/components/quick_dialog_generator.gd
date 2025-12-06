@tool
class_name QuickDialogGenerator
extends RefCounted

## Generates simple cinematic files from plain text dialog
## Used by the NPC Editor to create dialog cinematics without the full Cinematic Editor

signal cinematic_created(cinematic_id: String, file_path: String)
signal creation_failed(error_message: String)


## Create a cinematic JSON file from dialog text
## Returns the cinematic_id on success, empty string on failure
func create_dialog_cinematic(
	npc_id: String,
	speaker_name: String,
	dialog_text: String,
	cinematics_dir: String
) -> String:
	# Validate inputs
	if npc_id.is_empty():
		creation_failed.emit("NPC ID is required")
		return ""

	if dialog_text.strip_edges().is_empty():
		creation_failed.emit("Dialog text is required")
		return ""

	if cinematics_dir.is_empty():
		creation_failed.emit("Cinematics directory path is required")
		return ""

	# Generate cinematic ID from NPC ID
	var cinematic_id: String = npc_id + "_dialog"

	# Use NPC ID as speaker name if none provided
	var final_speaker: String = speaker_name
	if final_speaker.is_empty():
		final_speaker = npc_id.capitalize().replace("_", " ")

	# Build the cinematic data structure
	var cinematic_data: Dictionary = _build_cinematic_data(cinematic_id, final_speaker, dialog_text)

	# Ensure directory exists
	if not SparklingEditorUtils.ensure_directory_exists(cinematics_dir):
		creation_failed.emit("Failed to create cinematics directory")
		return ""

	# Save the JSON file
	var file_path: String = cinematics_dir.path_join(cinematic_id + ".json")
	var success: bool = _save_json_file(file_path, cinematic_data)

	if not success:
		creation_failed.emit("Failed to write cinematic file")
		return ""

	cinematic_created.emit(cinematic_id, file_path)
	print("QuickDialogGenerator: Created cinematic '%s' at %s" % [cinematic_id, file_path])

	return cinematic_id


## Build a cinematic dictionary from dialog text
func _build_cinematic_data(cinematic_id: String, speaker_name: String, dialog_text: String) -> Dictionary:
	var commands: Array = []

	# Split dialog into lines for multi-line support
	var lines: PackedStringArray = dialog_text.split("\n")

	for line: String in lines:
		var trimmed: String = line.strip_edges()
		if trimmed.is_empty():
			continue

		commands.append({
			"type": "dialog_line",
			"params": {
				"speaker_name": speaker_name,
				"text": trimmed,
				"emotion": "neutral"
			}
		})

	return {
		"cinematic_id": cinematic_id,
		"cinematic_name": "%s Dialog" % speaker_name,
		"description": "Auto-generated dialog for %s" % speaker_name,
		"can_skip": true,
		"disable_player_input": true,
		"commands": commands
	}


## Save cinematic data as JSON file
func _save_json_file(file_path: String, data: Dictionary) -> bool:
	# Convert to JSON with pretty formatting
	var json_string: String = JSON.stringify(data, "  ")

	# Write file
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("QuickDialogGenerator: Failed to open file for writing: " + file_path)
		return false

	file.store_string(json_string)
	file.close()

	return true


## Load existing Quick Dialog text from a cinematic file
## Returns the extracted dialog text, or empty string if not found/not a quick dialog
static func load_dialog_text_from_cinematic(cinematics_dir: String, cinematic_id: String, npc_id: String) -> String:
	# Only load if it's a Quick Dialog cinematic (matches expected pattern)
	if cinematic_id.is_empty():
		return ""

	var expected_quick_id: String = npc_id + "_dialog"
	if cinematic_id != expected_quick_id:
		# Not a Quick Dialog cinematic, don't try to load
		return ""

	var file_path: String = cinematics_dir.path_join(cinematic_id + ".json")
	if not FileAccess.file_exists(file_path):
		return ""

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return ""

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)
	if parse_result != OK:
		return ""

	var data: Dictionary = json.data as Dictionary
	if not data:
		return ""

	# Extract dialog text from commands
	var dialog_lines: PackedStringArray = []
	var commands: Array = data.get("commands", [])

	for command: Variant in commands:
		if command is Dictionary:
			var cmd: Dictionary = command as Dictionary
			if cmd.get("type") == "dialog_line":
				var params: Dictionary = cmd.get("params", {})
				var text: String = params.get("text", "")
				if not text.is_empty():
					dialog_lines.append(text)

	return "\n".join(dialog_lines)


## Check if a cinematic exists either on disk or in the registry
static func cinematic_exists(cinematics_dir: String, cinematic_id: String) -> bool:
	if cinematic_id.is_empty():
		return false

	# First check: file exists on disk
	if not cinematics_dir.is_empty():
		var file_path: String = cinematics_dir.path_join(cinematic_id + ".json")
		if FileAccess.file_exists(file_path):
			return true

	# Second check: try ModLoader registry
	var mod_loader_node: Node = null
	if Engine.get_main_loop():
		mod_loader_node = Engine.get_main_loop().root.get_node_or_null("/root/ModLoader")

	if mod_loader_node:
		var registry: Variant = mod_loader_node.get("registry")
		if registry and registry.has_method("has_resource"):
			if registry.has_resource("cinematic", cinematic_id):
				return true

	return false


## Get the expected cinematic ID for an NPC's quick dialog
static func get_quick_dialog_id(npc_id: String) -> String:
	return npc_id + "_dialog"
