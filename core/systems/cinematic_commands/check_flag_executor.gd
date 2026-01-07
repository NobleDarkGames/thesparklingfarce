## CheckFlagExecutor - Conditional branching based on GameState flags
##
## Evaluates a flag condition and injects the appropriate branch commands
## into the execution queue.
##
## Parameters:
##   flag: String - The flag name to check (supports namespaced: "mod_id:flag")
##   negate: bool (optional) - If true, inverts the condition (default: false)
##   if_true: Array[Dictionary] - Commands to execute if condition passes
##   if_false: Array[Dictionary] - Commands to execute if condition fails (optional)
##
## Usage in cinematic JSON:
##   {
##     "type": "check_flag",
##     "params": {
##       "flag": "met_kurt",
##       "if_true": [
##         {"type": "dialog_line", "params": {"speaker_name": "Kurt", "text": "Good to see you again!"}}
##       ],
##       "if_false": [
##         {"type": "dialog_line", "params": {"speaker_name": "Kurt", "text": "I'm Kurt, nice to meet you!"}},
##         {"type": "set_variable", "params": {"variable": "met_kurt"}}
##       ]
##     }
##   }
##
## Checking if flag is NOT set:
##   {
##     "type": "check_flag",
##     "params": {
##       "flag": "boss_defeated",
##       "negate": true,
##       "if_true": [
##         {"type": "dialog_line", "params": {"text": "The boss still lives!"}}
##       ]
##     }
##   }
class_name CheckFlagExecutor
extends CinematicCommandExecutor


func execute(command: Dictionary, manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})

	# Get flag name (required)
	var flag_name: String = params.get("flag", "")
	if flag_name.is_empty():
		push_error("CheckFlagExecutor: Missing 'flag' parameter")
		return true  # Complete immediately on error

	# Check if we should negate the condition
	var negate: bool = params.get("negate", false)

	# Evaluate condition
	var flag_value: bool = GameState.has_flag(flag_name)
	var condition_met: bool = flag_value if not negate else not flag_value

	# Get the appropriate branch
	var branch_key: String = "if_true" if condition_met else "if_false"
	var branch: Variant = params.get(branch_key, [])

	# Validate branch is an array
	if not branch is Array:
		push_warning("CheckFlagExecutor: '%s' is not an array" % branch_key)
		return true

	var branch_commands: Array = branch
	if branch_commands.is_empty():
		# No commands in this branch - just continue
		return true

	# Inject branch commands into the manager's queue
	if manager.has_method("inject_commands"):
		manager.inject_commands(branch_commands)
	else:
		push_error("CheckFlagExecutor: Manager doesn't support inject_commands()")

	return true  # Synchronous completion - branch commands are now queued


func get_editor_metadata() -> Dictionary:
	return {
		"description": "Branch based on flag condition",
		"category": "Flow Control",
		"icon": "Skeleton2D",  # Using a built-in icon that suggests branching
		"has_target": false,
		"params": {
			"flag": {
				"type": "string",
				"default": "",
				"hint": "Flag name to check (e.g., 'met_kurt' or 'mod_id:flag_name')"
			},
			"negate": {
				"type": "bool",
				"default": false,
				"hint": "If true, branch executes when flag is NOT set"
			},
			"if_true": {
				"type": "command_array",
				"default": [],
				"hint": "Commands to run if condition is true"
			},
			"if_false": {
				"type": "command_array",
				"default": [],
				"hint": "Commands to run if condition is false (optional)"
			}
		}
	}
