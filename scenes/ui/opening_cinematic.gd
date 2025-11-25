extends Control

## Opening Cinematic - Placeholder scene for game intro
## Shows a simple splash screen with "Press any key to continue"
## Transitions to main menu on any input

@onready var title_label: Label = %TitleLabel
@onready var press_key_label: Label = %PressKeyLabel

var can_skip: bool = false


func _ready() -> void:
	# Allow skipping after a short delay
	await get_tree().create_timer(0.5).timeout
	can_skip = true

	# Start blinking animation for "Press any key" text
	_start_blink_animation()


func _unhandled_input(event: InputEvent) -> void:
	if not can_skip:
		return

	# Any key press or mouse click skips to main menu
	if event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed():
			_skip_to_main_menu()


func _skip_to_main_menu() -> void:
	can_skip = false  # Prevent double-triggering
	SceneManager.goto_main_menu()


func _start_blink_animation() -> void:
	if not press_key_label:
		return

	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(press_key_label, "modulate:a", 0.3, 0.8)
	tween.tween_property(press_key_label, "modulate:a", 1.0, 0.8)
