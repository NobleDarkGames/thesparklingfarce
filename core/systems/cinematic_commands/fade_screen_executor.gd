## Fade screen command executor
## Fades screen in or out
class_name FadeScreenExecutor
extends CinematicCommandExecutor


func execute(command: Dictionary, manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})
	var fade_type: String = params.get("fade_type", "out")  # "in" or "out"
	var duration: float = params.get("duration", 1.0)
	var color: Color = params.get("color", Color.BLACK)

	# Ensure fade overlay exists
	manager._ensure_fade_overlay()

	if not manager._fade_overlay:
		push_warning("FadeScreenExecutor: Failed to create fade overlay")
		return true  # Complete immediately on error

	# Set initial color based on fade type
	if fade_type == "in":
		# Fade in: start opaque, end transparent
		manager._fade_overlay.color = Color(color.r, color.g, color.b, 1.0)
		manager._fade_overlay.show()
	else:
		# Fade out: start transparent, end opaque
		manager._fade_overlay.color = Color(color.r, color.g, color.b, 0.0)
		manager._fade_overlay.show()

	# Create tween for fade
	var fade_tween: Tween = manager.create_tween()
	fade_tween.set_trans(Tween.TRANS_LINEAR)

	if fade_type == "in":
		# Fade to transparent
		fade_tween.tween_property(manager._fade_overlay, "color:a", 0.0, duration)
		fade_tween.tween_callback(func() -> void:
			manager._fade_overlay.hide()
			manager._command_completed = true
		)
	else:
		# Fade to opaque
		fade_tween.tween_property(manager._fade_overlay, "color:a", 1.0, duration)
		fade_tween.tween_callback(func() -> void: manager._command_completed = true)

	return false  # Always async
