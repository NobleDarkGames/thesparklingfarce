## Set variable/flag command executor
## Sets a variable or flag in GameState
class_name SetVariableExecutor
extends CinematicCommandExecutor


func execute(command: Dictionary, manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})
	var variable_name: String = params.get("variable", "")
	var value: Variant = params.get("value", null)

	if variable_name.is_empty():
		push_error("SetVariableExecutor: Missing variable name")
		return true  # Complete immediately on error

	# Set in GameState
	GameState.set_flag(variable_name)

	return true  # Synchronous, completes immediately
