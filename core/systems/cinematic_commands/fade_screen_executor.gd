## Fade screen command executor
## Fades screen in or out using SceneManager's centralized fade system
class_name FadeScreenExecutor
extends CinematicCommandExecutor

## Track if this executor was interrupted during async fade
var _interrupted: bool = false
## Reference to manager for async completion
var _active_manager: Node = null


func execute(command: Dictionary, manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})
	var fade_type: String = params.get("fade_type", "out")  # "in" or "out"
	var duration: float = params.get("duration", 1.0)
	var color: Color = params.get("color", Color.BLACK)

	# Use SceneManager's centralized fade system
	if not SceneManager:
		push_warning("FadeScreenExecutor: SceneManager not available")
		return true  # Complete immediately on error

	# Reset interrupt state and store manager reference
	_interrupted = false
	_active_manager = manager

	# Start the fade asynchronously
	_do_fade(fade_type, duration, color)

	return false  # Always async


## Called when the cinematic is interrupted (e.g., skipped by player)
## Clean up and prevent stale state writes
func interrupt() -> void:
	_interrupted = true
	_active_manager = null


## Perform the fade using SceneManager
func _do_fade(fade_type: String, duration: float, color: Color) -> void:
	if fade_type == "in":
		# Fade in: reveal the scene (from black to visible)
		# First ensure we're at black
		if not SceneManager.is_faded_to_black:
			SceneManager.set_black()
		await SceneManager.fade_from_black(duration)
	else:
		# Fade out: hide the scene (from visible to black)
		await SceneManager.fade_to_black(duration, color)

	# Check if we were interrupted during the await
	if _interrupted:
		return

	# Mark command as completed if manager is still valid
	if _active_manager and is_instance_valid(_active_manager):
		_active_manager._command_completed = true

	_active_manager = null
