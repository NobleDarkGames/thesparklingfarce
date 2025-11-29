class_name VictoryScreen
extends CanvasLayer

## Victory Screen - Displays battle victory results
##
## Simple MVP version: Shows "VICTORY!", gold earned, and continue button.
## Per Commander Claudius: SF didn't show per-unit XP breakdown (XP was shown during battle).

signal result_dismissed

## Font reference
const MONOGRAM_FONT: Font = preload("res://assets/fonts/monogram.ttf")

## Animation constants
const FADE_IN_DURATION: float = 0.5
const TITLE_SCALE_BOUNCE: float = 1.3
const GOLD_REVEAL_DELAY: float = 0.5

## UI References
@onready var background: ColorRect = $Background
@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var title_label: Label = $CenterContainer/Panel/MarginContainer/VBox/TitleLabel
@onready var gold_label: Label = $CenterContainer/Panel/MarginContainer/VBox/GoldLabel
@onready var continue_label: Label = $CenterContainer/Panel/MarginContainer/VBox/ContinueLabel

## State
var _can_dismiss: bool = false
var _blink_tween: Tween = null


func _ready() -> void:
	# Start hidden
	background.modulate.a = 0.0
	panel.modulate.a = 0.0
	gold_label.visible = false
	continue_label.visible = false

	# Set layer above everything else
	layer = 100


## Show the victory screen
func show_victory(gold_earned: int = 0) -> void:
	_can_dismiss = false

	# Play victory fanfare
	AudioManager.play_music("victory_fanfare", 0.8)

	# Set title
	title_label.text = "VICTORY!"
	title_label.add_theme_color_override("font_color", Color.GOLD)
	title_label.pivot_offset = title_label.size / 2

	# Set gold (hidden initially)
	if gold_earned > 0:
		gold_label.text = "Gold Earned: %d G" % gold_earned
	else:
		gold_label.text = "Battle Complete!"

	# Fade in background
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(background, "modulate:a", 0.8, FADE_IN_DURATION)
	tween.tween_property(panel, "modulate:a", 1.0, FADE_IN_DURATION)
	await tween.finished

	# Animate title bounce
	await _animate_title_bounce()

	# Reveal gold
	await get_tree().create_timer(GOLD_REVEAL_DELAY).timeout
	gold_label.visible = true
	gold_label.modulate.a = 0.0
	var gold_tween: Tween = create_tween()
	gold_tween.tween_property(gold_label, "modulate:a", 1.0, 0.3)
	AudioManager.play_sfx("ui_confirm", AudioManager.SFXCategory.UI)
	await gold_tween.finished

	# Show continue prompt
	await get_tree().create_timer(0.3).timeout
	continue_label.visible = true
	_animate_continue_blink()
	_can_dismiss = true


func _animate_title_bounce() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(title_label, "scale", Vector2(TITLE_SCALE_BOUNCE, TITLE_SCALE_BOUNCE), 0.15)
	tween.tween_property(title_label, "scale", Vector2.ONE, 0.2)
	await tween.finished


func _animate_continue_blink() -> void:
	# Kill any existing blink tween
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()

	_blink_tween = create_tween()
	_blink_tween.set_loops()
	_blink_tween.tween_property(continue_label, "modulate:a", 0.3, 0.5)
	_blink_tween.tween_property(continue_label, "modulate:a", 1.0, 0.5)


func _input(event: InputEvent) -> void:
	# Block ALL inputs while this modal popup is visible
	# This prevents clicks/keys from passing through to the battle map
	get_viewport().set_input_as_handled()

	if not _can_dismiss:
		return

	if event.is_action_pressed("sf_confirm") or event.is_action_pressed("sf_cancel"):
		AudioManager.play_sfx("ui_confirm", AudioManager.SFXCategory.UI)
		_dismiss()


func _dismiss() -> void:
	_can_dismiss = false

	# Kill the blink tween to free resources
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
		_blink_tween = null

	# Fade out
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(background, "modulate:a", 0.0, 0.3)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	await tween.finished

	result_dismissed.emit()
