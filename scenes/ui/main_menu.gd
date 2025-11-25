extends Control

## Main Menu - Primary game menu
## Allows player to start new game or load existing save

@onready var new_game_button: Button = %NewGameButton
@onready var load_game_button: Button = %LoadGameButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	# Connect button signals
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Focus the first button
	new_game_button.grab_focus()


func _on_new_game_pressed() -> void:
	# Go to save slot selector in "new game" mode
	# The selector will create a new save in the chosen slot
	SceneManager.goto_save_slot_selector()


func _on_load_game_pressed() -> void:
	# Go to save slot selector in "load game" mode
	# The selector will load an existing save from the chosen slot
	SceneManager.goto_save_slot_selector()


func _on_quit_pressed() -> void:
	get_tree().quit()
