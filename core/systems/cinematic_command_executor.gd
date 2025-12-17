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
