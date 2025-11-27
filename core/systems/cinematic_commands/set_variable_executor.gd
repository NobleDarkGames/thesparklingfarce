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

	# Set in GameState - use value if provided, otherwise set as boolean flag
	if value != null:
		GameState.set_campaign_data(variable_name, value)
	else:
		GameState.set_flag(variable_name)

	return true  # Synchronous, completes immediately
