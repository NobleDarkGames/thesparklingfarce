extends Control

## Core Fallback Main Menu
## Used when no mod provides a main_menu scene.
## Simpler than _base_game version - minimal animations, robust fallbacks.

# Game Juice: Hover brightness boost
const HOVER_BRIGHTNESS: float = 1.1
const HOVER_TWEEN_DURATION: float = 0.1

@onready var new_game_button: Button = %NewGameButton
@onready var load_game_button: Button = %LoadGameButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Connect hover/focus signals for brightness boost
	for btn: Button in [new_game_button, load_game_button, quit_button]:
		btn.focus_entered.connect(_on_button_hover.bind(btn))
		btn.focus_exited.connect(_on_button_unhover.bind(btn))
		btn.mouse_entered.connect(_on_button_hover.bind(btn))
		btn.mouse_exited.connect(_on_button_unhover.bind(btn))

	# Simple fade-in
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)

	await tween.finished
	if not is_instance_valid(self):
		return
	new_game_button.grab_focus()


func _on_new_game_pressed() -> void:
	SceneManager.goto_save_slot_selector("new_game")


func _on_load_game_pressed() -> void:
	SceneManager.goto_save_slot_selector("load_game")


func _on_quit_pressed() -> void:
	get_tree().quit()


## Tween button brightness up on hover/focus
func _on_button_hover(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	var duration: float = GameJuice.get_adjusted_duration(HOVER_TWEEN_DURATION)
	var tween: Tween = btn.create_tween()
	tween.tween_property(btn, "modulate", Color(HOVER_BRIGHTNESS, HOVER_BRIGHTNESS, HOVER_BRIGHTNESS), duration)


## Tween button brightness back to normal on unhover/unfocus
func _on_button_unhover(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	var duration: float = GameJuice.get_adjusted_duration(HOVER_TWEEN_DURATION)
	var tween: Tween = btn.create_tween()
	tween.tween_property(btn, "modulate", Color.WHITE, duration)
