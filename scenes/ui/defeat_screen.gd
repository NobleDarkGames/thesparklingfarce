class_name DefeatScreen
extends CanvasLayer

## Defeat Screen - Displays game over options
##
## Simple MVP version: Shows "DEFEAT!", retry and return buttons.
## Per Commander Claudius: SF returned you to town with gold penalty.

signal retry_requested
signal return_requested
signal result_dismissed  ## Generic dismiss (for compatibility)

## Font reference
const MONOGRAM_FONT: Font = preload("res://assets/fonts/monogram.ttf")

## Animation constants
const FADE_IN_DURATION: float = 0.6

## UI References
@onready var background: ColorRect = $Background
@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var title_label: Label = $CenterContainer/Panel/MarginContainer/VBox/TitleLabel
@onready var message_label: Label = $CenterContainer/Panel/MarginContainer/VBox/MessageLabel
@onready var buttons_container: VBoxContainer = $CenterContainer/Panel/MarginContainer/VBox/ButtonsContainer
@onready var retry_button: Button = $CenterContainer/Panel/MarginContainer/VBox/ButtonsContainer/RetryButton
@onready var return_button: Button = $CenterContainer/Panel/MarginContainer/VBox/ButtonsContainer/ReturnButton

## State
var _can_interact: bool = false


func _ready() -> void:
	# Start hidden
	background.modulate.a = 0.0
	panel.modulate.a = 0.0
	buttons_container.visible = false

	# Set layer above everything else
	layer = 100

	# Connect button signals
	retry_button.pressed.connect(_on_retry_pressed)
	return_button.pressed.connect(_on_return_pressed)


## Show the defeat screen
func show_defeat() -> void:
	_can_interact = false

	# Play somber music
	AudioManager.play_music("defeat_theme", 0.6)

	# Set title
	title_label.text = "DEFEAT..."
	title_label.add_theme_color_override("font_color", Color.DARK_RED)

	# Set message
	message_label.text = "Your forces have fallen."

	# Fade in background (darker for defeat)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(background, "modulate:a", 0.9, FADE_IN_DURATION)
	tween.tween_property(panel, "modulate:a", 1.0, FADE_IN_DURATION)
	await tween.finished

	# Show buttons after a moment
	await get_tree().create_timer(0.5).timeout
	buttons_container.visible = true
	buttons_container.modulate.a = 0.0

	var button_tween: Tween = create_tween()
	button_tween.tween_property(buttons_container, "modulate:a", 1.0, 0.3)
	await button_tween.finished

	# Focus first button and allow interaction
	retry_button.grab_focus()
	_can_interact = true


func _on_retry_pressed() -> void:
	if not _can_interact:
		return

	_can_interact = false
	AudioManager.play_sfx("ui_confirm", AudioManager.SFXCategory.UI)

	await _fade_out()
	retry_requested.emit()
	result_dismissed.emit()


func _on_return_pressed() -> void:
	if not _can_interact:
		return

	_can_interact = false
	AudioManager.play_sfx("ui_confirm", AudioManager.SFXCategory.UI)

	await _fade_out()
	return_requested.emit()
	result_dismissed.emit()


func _fade_out() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(background, "modulate:a", 0.0, 0.3)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	await tween.finished


func _input(event: InputEvent) -> void:
	# Block ALL inputs while this modal popup is visible
	# This prevents clicks/keys from passing through to the battle map
	get_viewport().set_input_as_handled()

	if not _can_interact:
		return

	# Handle keyboard navigation between buttons
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		AudioManager.play_sfx("ui_select", AudioManager.SFXCategory.UI)
