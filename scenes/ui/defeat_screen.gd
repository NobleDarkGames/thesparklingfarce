class_name DefeatScreen
extends CanvasLayer

## SF2-Authentic Defeat Screen
##
## When the hero falls, this screen displays automatically with no menu choices.
## The force retreats to the last church/safe location with full party revival.
##
## SF2-AUTHENTIC BEHAVIOR:
## - Automatic fade to black with flavor text
## - "[Hero] has fallen! The force retreats..."
## - No retry option - you just wake up in town
## - Full party restoration: HP, MP, status cleared, dead revived
## - Press any key to continue

signal continue_requested  ## Player pressed any key to continue with retreat
signal result_dismissed    ## Generic dismiss (for compatibility)

## Animation constants
const FADE_IN_DURATION: float = 1.0
const TEXT_DELAY: float = 0.8
const HINT_DELAY: float = 2.0

## UI References - simplified for automatic flow
@onready var background: ColorRect = $Background
@onready var message_container: VBoxContainer = $CenterContainer/MessageContainer
@onready var defeat_label: Label = $CenterContainer/MessageContainer/DefeatLabel
@onready var retreat_label: Label = $CenterContainer/MessageContainer/RetreatLabel
@onready var hint_label: Label = $HintLabel

## State
var _can_interact: bool = false
var _hero_name: String = "The hero"


func _ready() -> void:
	# Start hidden
	background.modulate.a = 0.0
	message_container.modulate.a = 0.0
	hint_label.modulate.a = 0.0

	# Set layer above everything else
	layer = 100

	# Disable input processing initially
	set_process_input(false)


## Show the defeat screen with hero name
## @param hero_name: Name of the fallen hero for flavor text (pass from BattleManager)
func show_defeat(hero_name: String = "The hero") -> void:
	_can_interact = false

	# Store hero name for display
	_hero_name = hero_name if not hero_name.is_empty() else "The hero"

	# Set up defeat message (SF2-authentic)
	defeat_label.text = "%s has fallen!" % _hero_name
	retreat_label.text = "The force retreats..."

	# Play somber music
	AudioManager.play_music("defeat_theme", 0.6)

	# Phase 1: Fade to black
	var tween: Tween = create_tween()
	tween.tween_property(background, "modulate:a", 1.0, FADE_IN_DURATION)
	await tween.finished
	if not is_instance_valid(self):
		return

	# Phase 2: Show defeat message
	await get_tree().create_timer(TEXT_DELAY).timeout
	if not is_instance_valid(self):
		return
	var text_tween: Tween = create_tween()
	text_tween.tween_property(message_container, "modulate:a", 1.0, 0.5)
	await text_tween.finished
	if not is_instance_valid(self):
		return

	# Phase 3: Show hint after delay
	await get_tree().create_timer(HINT_DELAY).timeout
	if not is_instance_valid(self):
		return
	hint_label.text = "Press any key..."
	var hint_tween: Tween = create_tween()
	hint_tween.tween_property(hint_label, "modulate:a", 0.6, 0.3)
	await hint_tween.finished
	if not is_instance_valid(self):
		return

	# Now allow interaction
	_can_interact = true
	set_process_input(true)


func _input(event: InputEvent) -> void:
	# Block ALL inputs from passing through
	get_viewport().set_input_as_handled()

	if not _can_interact:
		return

	# Only respond to key/button presses, not releases or motion
	if not event.is_pressed():
		return

	# Ignore mouse motion
	if event is InputEventMouseMotion:
		return

	# Any key/button continues with retreat (SF2-authentic: no quit option)
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		_can_interact = false
		set_process_input(false)
		AudioManager.play_sfx("ui_confirm", AudioManager.SFXCategory.UI)
		await _fade_out()
		if not is_instance_valid(self):
			return
		continue_requested.emit()
		result_dismissed.emit()


func _fade_out() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(message_container, "modulate:a", 0.0, 0.3)
	tween.tween_property(hint_label, "modulate:a", 0.0, 0.3)
	# Keep background black for scene transition
	await tween.finished
	if not is_instance_valid(self):
		return
