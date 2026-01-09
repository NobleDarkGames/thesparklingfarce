## CheckFlagsExecutor - Compound conditional branching based on multiple GameState flags
##
## Evaluates multiple flags at once with AND/OR logic and injects the appropriate
## branch commands into the execution queue. This avoids deeply nested check_flag commands.
##
## Parameters:
##   flags: Array[String] - List of flag names to check (supports namespaced: "mod_id:flag")
##   mode: String - "all" (AND - all flags must be set) or "any" (OR - at least one set)
##                  Default: "all"
##   negate: bool (optional) - If true, inverts the final result (default: false)
##   if_true: Array[Dictionary] - Commands to execute if condition passes
##   if_false: Array[Dictionary] - Commands to execute if condition fails (optional)
##
## Usage in cinematic JSON:
##
## Check if ALL flags are set (AND logic):
##   {
##     "type": "check_flags",
##     "params": {
##       "flags": ["battle1_victory", "battle2_victory"],
##       "mode": "all",
##       "if_true": [
##         {"type": "dialog_line", "params": {"text": "You've proven yourself!"}}
##       ]
##     }
##   }
##
## Check if ANY flag is set (OR logic):
##   {
##     "type": "check_flags",
##     "params": {
##       "flags": ["met_kurt", "met_sarah", "met_bob"],
##       "mode": "any",
##       "if_true": [
##         {"type": "dialog_line", "params": {"text": "I see you've been making friends."}}
##       ]
##     }
##   }
##
## Check if NOT all flags are set (negate + all):
##   {
##     "type": "check_flags",
##     "params": {
##       "flags": ["quest1_done", "quest2_done", "quest3_done"],
##       "mode": "all",
##       "negate": true,
##       "if_true": [
##         {"type": "dialog_line", "params": {"text": "You still have work to do."}}
##       ]
##     }
##   }
class_name CheckFlagsExecutor
extends CinematicCommandExecutor


func execute(command: Dictionary, manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})

	# Get flags array (required)
	var flags_raw: Variant = params.get("flags", [])
	var flags: Array[String] = []

	# Handle both Array and comma-separated string input
	if flags_raw is Array:
		for flag: Variant in flags_raw:
			if flag is String and not flag.is_empty():
				flags.append(flag)
	elif flags_raw is String:
		# Support comma-separated string: "flag1, flag2, flag3"
		var flag_str: String = flags_raw
		for part: String in flag_str.split(","):
			var trimmed: String = part.strip_edges()
			if not trimmed.is_empty():
				flags.append(trimmed)

	if flags.is_empty():
		push_error("CheckFlagsExecutor: Missing or empty 'flags' parameter")
		return true  # Complete immediately on error

	# Get mode: "all" (AND) or "any" (OR)
	var mode: String = params.get("mode", "all")
	if mode != "all" and mode != "any":
		push_warning("CheckFlagsExecutor: Invalid mode '%s', defaulting to 'all'" % mode)
		mode = "all"

	# Check if we should negate the condition
	var negate: bool = params.get("negate", false)

	# Evaluate condition based on mode
	var condition_met: bool = _evaluate_flags(flags, mode)

	# Apply negation if requested
	if negate:
		condition_met = not condition_met

	# Get the appropriate branch
	var branch_key: String = "if_true" if condition_met else "if_false"
	var branch: Variant = params.get(branch_key, [])

	# Validate branch is an array
	if not branch is Array:
		push_warning("CheckFlagsExecutor: '%s' is not an array" % branch_key)
		return true

	var branch_commands: Array = branch
	if branch_commands.is_empty():
		# No commands in this branch - just continue
		return true

	# Inject branch commands into the manager's queue
	if manager.has_method("inject_commands"):
		manager.inject_commands(branch_commands)
	else:
		push_error("CheckFlagsExecutor: Manager doesn't support inject_commands()")

	return true  # Synchronous completion - branch commands are now queued


## Evaluate multiple flags based on mode
## @param flags: Array of flag names to check
## @param mode: "all" for AND logic, "any" for OR logic
## @return: true if condition is met
func _evaluate_flags(flags: Array[String], mode: String) -> bool:
	if mode == "all":
		# AND logic: all flags must be set
		for flag: String in flags:
			if not GameState.has_flag(flag):
				return false
		return true
	else:
		# OR logic: at least one flag must be set
		for flag: String in flags:
			if GameState.has_flag(flag):
				return true
		return false


func get_editor_metadata() -> Dictionary:
	return {
		"description": "Branch based on multiple flag conditions (AND/OR)",
		"category": "Flow Control",
		"icon": "Skeleton2D",  # Same as check_flag for consistency
		"has_target": false,
		"params": {
			"flags": {
				"type": "string_array",
				"default": [],
				"hint": "Flag names to check (e.g., 'battle1_victory, met_kurt')"
			},
			"mode": {
				"type": "enum",
				"default": "all",
				"options": ["all", "any"],
				"hint": "'all' = AND (all flags set), 'any' = OR (at least one set)"
			},
			"negate": {
				"type": "bool",
				"default": false,
				"hint": "If true, inverts the result (e.g., 'none set' or 'not all set')"
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
