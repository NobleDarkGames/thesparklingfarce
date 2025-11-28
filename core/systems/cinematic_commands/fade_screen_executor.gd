## Fade screen command executor
## Fades screen in or out using SceneManager's centralized fade system
class_name FadeScreenExecutor
extends CinematicCommandExecutor


func execute(command: Dictionary, manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})
	var fade_type: String = params.get("fade_type", "out")  # "in" or "out"
	var duration: float = params.get("duration", 1.0)
	var color: Color = params.get("color", Color.BLACK)

	# Use SceneManager's centralized fade system
	if not SceneManager:
		push_warning("FadeScreenExecutor: SceneManager not available")
		return true  # Complete immediately on error

	# Start the fade asynchronously
	_do_fade(fade_type, duration, color, manager)

	return false  # Always async


## Perform the fade using SceneManager
func _do_fade(fade_type: String, duration: float, color: Color, manager: Node) -> void:
	if fade_type == "in":
		# Fade in: reveal the scene (from black to visible)
		# First ensure we're at black
		if not SceneManager.is_faded_to_black:
			SceneManager.set_black()
		await SceneManager.fade_from_black(duration)
	else:
		# Fade out: hide the scene (from visible to black)
		await SceneManager.fade_to_black(duration, color)

	# Mark command as completed
	manager._command_completed = true
