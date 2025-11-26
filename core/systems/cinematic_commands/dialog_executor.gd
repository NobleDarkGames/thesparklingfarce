## Dialog command executor
## Shows dialog by delegating to DialogManager
class_name DialogExecutor
extends CinematicCommandExecutor


func execute(command: Dictionary, manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})
	var dialogue_id: String = params.get("dialogue_id", "")

	if dialogue_id.is_empty():
		push_error("DialogExecutor: Missing dialogue_id")
		return true  # Complete immediately on error

	# Start dialog via DialogManager (proper delegation pattern)
	if DialogManager.start_dialog(dialogue_id):
		manager.current_state = manager.State.WAITING_FOR_DIALOG
		return false  # Async - dialog_ended signal will set _command_completed
	else:
		push_error("DialogExecutor: Failed to start dialog '%s'" % dialogue_id)
		return true  # Complete immediately on error
