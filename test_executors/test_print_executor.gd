## Test executor that prints a message
## Demonstrates synchronous command execution
extends CinematicCommandExecutor


func execute(command: Dictionary, manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})
	var message: String = params.get("message", "Test message")
	print("TestPrintExecutor: %s" % message)
	return true  # Completes immediately
