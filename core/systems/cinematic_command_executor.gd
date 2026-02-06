## Base class for cinematic command executors
##
## Mods can extend this class to add custom cinematic commands without modifying core code.
## Each executor handles one command type (e.g., "move_entity", "play_sound").
##
## Example:
## [codeblock]
## class_name CustomEffectExecutor
## extends CinematicCommandExecutor
##
## func execute(command: Dictionary, manager: Node) -> bool:
##     var params: Dictionary = command.get("params", {})
##     # Your custom logic here
##     return true  # true = completed immediately, false = async (call manager._on_command_completed later)
##
## func interrupt() -> void:
##     # Cleanup if needed when cinematic is skipped
##     pass
## [/codeblock]
class_name CinematicCommandExecutor
extends RefCounted

# Note: DialogueData has class_name so it's globally available

## Counter for generating unique inline dialog IDs (shared across all executors)
static var _inline_dialog_counter: int = 0


# =============================================================================
# SHARED UTILITIES
# =============================================================================

## Show a system message dialog and wait for player input
## @param message: The message to display (supports {char:id} interpolation)
## @param manager: Reference to the CinematicsManager
## @return: true if completed immediately, false if async (waiting for dialog)
static func show_system_message(message: String, manager: Node) -> bool:
	if not is_instance_valid(manager):
		push_warning("CinematicCommandExecutor: Manager freed, cannot show system message")
		return true
	var dialogue: DialogueData = DialogueData.new()

	# Generate unique ID
	_inline_dialog_counter += 1
	dialogue.dialogue_id = "_system_msg_%d_%d" % [Time.get_ticks_msec(), _inline_dialog_counter]

	# Add the message line (will be interpolated by DialogBox)
	dialogue.lines.append({
		"text": message,
		"speaker_name": ""  # No speaker for system messages
	})

	# Start dialog via DialogManager
	if DialogManager.start_dialog_from_resource(dialogue):
		manager.current_state = manager.State.WAITING_FOR_DIALOG
		manager._is_waiting = true
		return false  # Async - wait for dialog to complete
	else:
		push_warning("CinematicCommandExecutor: Failed to show system message")
		return true  # Complete anyway


## Resolve character from ID (supports both resource ID and character_uid)
## @param character_id: Either a resource ID like "max" or character_uid like "hk7wm4np"
## @return: CharacterData if found, null otherwise
static func resolve_character(character_id: String) -> CharacterData:
	if not ModLoader or not ModLoader.registry:
		return null
	# First try by character_uid (what the editor stores)
	var character: CharacterData = ModLoader.registry.get_character_by_uid(character_id) as CharacterData
	if character:
		return character

	# Fallback to resource ID lookup
	return ModLoader.registry.get_character(character_id)


## Resolve a character_id to display data (name and portrait)
## Supports both characters (by UID) and NPCs (prefixed with "npc:")
## @param character_id: Character UID or "npc:id" for NPCs
## @return: Dictionary with "name" (String) and "portrait" (Texture2D or null)
static func resolve_character_data(character_id: String) -> Dictionary:
	var result: Dictionary = {"name": "", "portrait": null}

	if character_id.is_empty():
		return result

	# Check if this is an NPC reference (prefixed with "npc:")
	if character_id.begins_with("npc:"):
		var npc_id: String = character_id.substr(4)  # Remove "npc:" prefix
		if ModLoader and ModLoader.registry:
			var npc: NPCData = ModLoader.registry.get_npc_by_id(npc_id) as NPCData
			if npc:
				result["name"] = npc.get_display_name()
				var portrait: Texture2D = npc.get_portrait()
				if portrait:
					result["portrait"] = portrait
				return result
		push_warning("CinematicCommandExecutor: Could not resolve NPC '%s'" % npc_id)
		result["name"] = "[%s]" % npc_id
		return result

	# Try to look up character in ModRegistry
	if ModLoader and ModLoader.registry:
		var character: CharacterData = ModLoader.registry.get_character_by_uid(character_id) as CharacterData
		if character:
			result["name"] = character.character_name
			if character.portrait:
				result["portrait"] = character.portrait
			return result

	push_warning("CinematicCommandExecutor: Could not resolve character '%s'" % character_id)
	result["name"] = "[%s]" % character_id
	return result


# =============================================================================
# VIRTUAL METHODS
# =============================================================================

## Execute a cinematic command
##
## This method is called by CinematicsManager when a command of this executor's type is encountered.
##
## @param command: The command dictionary containing "type", "target", and "params"
## @param manager: Reference to the CinematicsManager (use to access actors, state, etc.)
## @return: true if command completed immediately, false if async (executor must call manager._on_command_completed() when done)
func execute(command: Dictionary, manager: Node) -> bool:
	push_error("CinematicCommandExecutor: execute() must be implemented by subclass")
	return true


## Called when the cinematic is interrupted (e.g., skipped by player)
##
## Override this to clean up any ongoing operations (stop tweens, disconnect signals, etc.)
func interrupt() -> void:
	# Default: no cleanup needed
	# Override in subclass if your command has state to clean up
	pass


## Returns editor metadata for this command type
##
## Override this to provide metadata for the cinematic editor UI.
## This enables dynamic command discovery - mods can register custom commands
## that automatically appear in the editor dropdown.
##
## Return format:
## {
##     "description": "Human-readable description",
##     "category": "Category name for dropdown grouping",
##     "icon": "Godot editor icon name (e.g., 'Timer', 'Camera2D')",
##     "has_target": bool,  # Whether command needs a target actor_id
##     "params": {
##         "param_name": {
##             "type": "string|float|int|bool|enum|text|character|vector2|path",
##             "default": default_value,
##             "hint": "Tooltip text",
##             # For float/int:
##             "min": min_value,
##             "max": max_value,
##             # For enum:
##             "options": ["option1", "option2"]
##         }
##     }
## }
##
## Return empty dictionary to use hardcoded fallback (for backwards compatibility).
func get_editor_metadata() -> Dictionary:
	# Default: return empty to signal "use hardcoded definitions"
	# Override in subclass to provide dynamic metadata
	return {}


# =============================================================================
# ASYNC COMPLETION HELPERS
# =============================================================================

## Signal async command completion to the manager
## @param manager: The CinematicsManager reference
## @param restore_playing_state: If true, also sets current_state = PLAYING
##        (needed when executor set state to WAITING_FOR_COMMAND)
static func complete_async_command(manager: Node, restore_playing_state: bool = false) -> void:
	if manager and is_instance_valid(manager):
		if restore_playing_state:
			manager.current_state = manager.State.PLAYING
		manager._command_completed = true


## Resolve scene path from params (priority: scene_path > scene_id > map_id)
## @param params: Dictionary containing scene_path, scene_id, or map_id
## @return: Resolved scene path string, or empty string if none found
static func resolve_scene_path(params: Dictionary) -> String:
	# Direct scene path takes priority
	var scene_path: String = params.get("scene_path", "")
	if not scene_path.is_empty():
		return scene_path

	# Try scene_id (registered scene)
	var scene_id: String = params.get("scene_id", "")
	if not scene_id.is_empty() and ModLoader and ModLoader.registry:
		scene_path = ModLoader.registry.get_scene_path(scene_id)
		if not scene_path.is_empty():
			return scene_path

	# Try map_id (get scene from map metadata)
	var map_id: String = params.get("map_id", "")
	if not map_id.is_empty() and ModLoader and ModLoader.registry:
		var map_data: MapMetadata = ModLoader.registry.get_map(map_id)
		if map_data and "scene_path" in map_data:
			return map_data.scene_path

	return ""


## Parse flag array from params (accepts string or array)
## @param value: The parameter value - can be String, Array, or other
## @return: Array of non-empty strings
static func parse_flag_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is String and not value.is_empty():
		result.append(value)
	elif value is Array:
		for flag: Variant in value:
			if flag is String and not flag.is_empty():
				result.append(flag)
	return result
