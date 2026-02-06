extends Control

## Core Fallback Main Menu
## Used when no mod provides a main_menu scene.
## Simpler than _base_game version - minimal animations, robust fallbacks.

@onready var new_game_button: Button = %NewGameButton
@onready var load_game_button: Button = %LoadGameButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

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
