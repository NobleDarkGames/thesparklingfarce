class_name CinematicLoader
extends RefCounted

## Loads CinematicData from JSON files
##
## This allows modders to define cinematics in pure JSON without writing GDScript.
## JSON cinematics can include all standard commands: dialog, camera, movement, etc.
##
## Example JSON format:
## {
##   "cinematic_id": "my_intro",
##   "cinematic_name": "My Introduction",
##   "can_skip": true,
##   "disable_player_input": true,
##   "commands": [
##     {"type": "fade_screen", "params": {"fade_type": "in", "duration": 2.0}},
##     {"type": "dialog_line", "params": {"character_id": "ab3d7kx2", "text": "Hello!", "emotion": "happy"}},
##     {"type": "camera_shake", "params": {"intensity": 5.0, "duration": 1.0}}
##   ]
## }

const CinematicData: GDScript = preload("res://core/resources/cinematic_data.gd")


## Load a CinematicData resource from a JSON file
## Returns null if loading fails
static func load_from_json(json_path: String) -> CinematicData:
	# Don't use FileAccess.file_exists() - it fails in exports where files are in PCK
	# Just try to open the file directly
	var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("CinematicLoader: File not found or failed to open: %s" % json_path)
		return null

	var json_text: String = file.get_as_text()
	file.close()

	return load_from_json_string(json_text, json_path)


## Load a CinematicData resource from a JSON string
## source_path is optional, used for error messages
static func load_from_json_string(json_text: String, source_path: String = "<string>") -> CinematicData:
	var json: JSON = JSON.new()
	var error: Error = json.parse(json_text)

	if error != OK:
		push_error("CinematicLoader: JSON parse error in %s at line %d: %s" % [
			source_path, json.get_error_line(), json.get_error_message()
		])
		return null

	var data: Variant = json.data
	if not data is Dictionary:
		push_error("CinematicLoader: Root element must be a dictionary in %s" % source_path)
		return null

	return _build_cinematic_from_dict(data, source_path)


## Build CinematicData from a parsed JSON dictionary
static func _build_cinematic_from_dict(data: Dictionary, source_path: String) -> CinematicData:
	var cinematic: CinematicData = CinematicData.new()

	# Required fields
	if "cinematic_id" in data:
		cinematic.cinematic_id = str(data["cinematic_id"])
	else:
		push_error("CinematicLoader: Missing required 'cinematic_id' in %s" % source_path)
		return null

	# Optional metadata
	if "cinematic_name" in data:
		cinematic.cinematic_name = str(data["cinematic_name"])

	if "description" in data:
		cinematic.description = str(data["description"])

	# Settings
	if "can_skip" in data:
		cinematic.can_skip = bool(data["can_skip"])

	if "disable_player_input" in data:
		cinematic.disable_player_input = bool(data["disable_player_input"])

	if "fade_in_duration" in data:
		cinematic.fade_in_duration = float(data["fade_in_duration"])

	if "fade_out_duration" in data:
		cinematic.fade_out_duration = float(data["fade_out_duration"])

	# Actors array (spawned before commands execute)
	if "actors" in data:
		var actors_data: Variant = data["actors"]
		if actors_data is Array:
			var actors_array: Array = actors_data
			for actor_data: Variant in actors_array:
				if actor_data is Dictionary:
					cinematic.actors.append(actor_data)
		else:
			push_warning("CinematicLoader: 'actors' should be an array in %s" % source_path)

	# Commands array
	if "commands" in data:
		var commands_data: Variant = data["commands"]
		if commands_data is Array:
			var commands_array: Array = commands_data
			for cmd_data: Variant in commands_array:
				if cmd_data is Dictionary:
					var command: Dictionary = _parse_command(cmd_data, source_path)
					if not command.is_empty():
						cinematic.commands.append(command)
		else:
			push_warning("CinematicLoader: 'commands' should be an array in %s" % source_path)

	return cinematic


## Parse a single command from JSON
## Handles shorthand formats and converts to standard command dictionary
## Also normalizes dialog_line to show_dialog with inline lines
static func _parse_command(cmd_data: Dictionary, source_path: String) -> Dictionary:
	if "type" not in cmd_data:
		push_warning("CinematicLoader: Command missing 'type' in %s" % source_path)
		return {}

	var cmd_type: String = str(cmd_data["type"])
	var params: Dictionary = {}

	# Get params if present, otherwise extract from root level (shorthand format)
	if "params" in cmd_data:
		var params_data: Variant = cmd_data["params"]
		if params_data is Dictionary:
			var params_dict: Dictionary = params_data
			params = _convert_params(params_dict, cmd_type)
	else:
		# Shorthand: params at root level (excluding 'type' and 'target')
		for key: String in cmd_data.keys():
			if key != "type" and key != "target":
				params[key] = cmd_data[key]
		params = _convert_params(params, cmd_type)

	# Normalize dialog_line to show_dialog with inline lines array
	# This allows simple single-line dialog commands in JSON:
	#   {"type": "dialog_line", "params": {"character_id": "xyz", "text": "Hello!", "emotion": "happy"}}
	# Converted to:
	#   {"type": "show_dialog", "params": {"lines": [{"character_id": "xyz", "text": "Hello!", "emotion": "happy"}]}}
	if cmd_type == "dialog_line":
		cmd_type = "show_dialog"
		var line_data: Dictionary = {}
		if "character_id" in params:
			line_data["character_id"] = params["character_id"]
		if "speaker_name" in params:
			line_data["speaker_name"] = params["speaker_name"]
		if "text" in params:
			line_data["text"] = params["text"]
		if "emotion" in params:
			line_data["emotion"] = params["emotion"]
		else:
			line_data["emotion"] = "neutral"
		params = {"lines": [line_data]}

	var command: Dictionary = {
		"type": cmd_type,
		"params": params
	}

	# Add target if present
	if "target" in cmd_data:
		command["target"] = str(cmd_data["target"])

	return command


## Convert JSON params to proper GDScript types
## Handles special conversions like arrays to Vector2, etc.
static func _convert_params(params: Dictionary, cmd_type: String) -> Dictionary:
	var converted: Dictionary = {}

	for key: String in params.keys():
		var value: Variant = params[key]
		converted[key] = _convert_value(value, key, cmd_type)

	return converted


## Resolve a character_id to a display name (convenience wrapper)
static func _resolve_character_id(character_id: String) -> String:
	var char_data: Dictionary = CinematicCommandExecutor.resolve_character_data(character_id)
	var name_variant: Variant = char_data.get("name", "")
	return str(name_variant)


## Convert a single value to appropriate GDScript type
static func _convert_value(value: Variant, key: String, cmd_type: String) -> Variant:
	# Handle position/vector arrays -> Vector2
	if key in ["position", "target_pos", "target_position"] and value is Array:
		var arr: Array = value
		var arr_size: int = arr.size()
		if arr_size >= 2:
			var x_val: Variant = arr[0]
			var y_val: Variant = arr[1]
			var x: float = _variant_to_float(x_val)
			var y: float = _variant_to_float(y_val)
			return Vector2(x, y)

	# Handle path arrays -> Array[Vector2] or Array[Vector2i]
	if key == "path" and value is Array:
		var path_arr: Array = value
		var converted_path: Array = []
		for point: Variant in path_arr:
			if point is Array:
				var point_arr: Array = point
				var point_size: int = point_arr.size()
				if point_size >= 2:
					var px_val: Variant = point_arr[0]
					var py_val: Variant = point_arr[1]
					var px: float = _variant_to_float(px_val)
					var py: float = _variant_to_float(py_val)
					# For move_entity, use Vector2i (grid coords)
					if cmd_type == "move_entity":
						converted_path.append(Vector2i(int(px), int(py)))
					else:
						converted_path.append(Vector2(px, py))
			elif point is Dictionary:
				var point_dict: Dictionary = point
				var x_raw: Variant = point_dict.get("x", 0)
				var y_raw: Variant = point_dict.get("y", 0)
				var x: float = _variant_to_float(x_raw)
				var y: float = _variant_to_float(y_raw)
				if cmd_type == "move_entity":
					converted_path.append(Vector2i(int(x), int(y)))
				else:
					converted_path.append(Vector2(x, y))
		return converted_path

	# Handle lines array for dialog
	if key == "lines" and value is Array:
		var lines_arr: Array = value
		var converted_lines: Array = []
		for line: Variant in lines_arr:
			if line is Dictionary:
				var line_dict: Dictionary = line
				var converted_line: Dictionary = {}

				# Support character_id lookup (preferred) or direct speaker name
				if "character_id" in line_dict:
					var char_data: Dictionary = CinematicCommandExecutor.resolve_character_data(str(line_dict["character_id"]))
					var char_name_variant: Variant = char_data.get("name", "")
					var char_name: String = str(char_name_variant)
					var char_portrait: Variant = char_data.get("portrait")
					if not char_name.is_empty():
						converted_line["speaker_name"] = char_name
					if char_portrait != null:
						converted_line["portrait"] = char_portrait
				elif "speaker" in line_dict:
					converted_line["speaker_name"] = str(line_dict["speaker"])
				elif "speaker_name" in line_dict:
					converted_line["speaker_name"] = str(line_dict["speaker_name"])

				if "text" in line_dict:
					converted_line["text"] = str(line_dict["text"])
				if "emotion" in line_dict:
					converted_line["emotion"] = str(line_dict["emotion"])
				else:
					converted_line["emotion"] = "neutral"
				converted_lines.append(converted_line)
		return converted_lines

	# Pass through other values
	return value


## Safely convert a Variant to float with type checking
static func _variant_to_float(value: Variant) -> float:
	if value is float:
		return value
	elif value is int:
		return float(value)
	return 0.0


## Validate a loaded cinematic has required structure
static func validate_cinematic(cinematic: CinematicData) -> bool:
	if cinematic == null:
		return false

	if cinematic.cinematic_id.is_empty():
		push_error("CinematicLoader: Cinematic has empty cinematic_id")
		return false

	if cinematic.commands.is_empty():
		push_warning("CinematicLoader: Cinematic '%s' has no commands" % cinematic.cinematic_id)
		# Allow empty cinematics (might be placeholder)

	return true
