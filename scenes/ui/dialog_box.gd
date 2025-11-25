extends Control

## DialogBox - Displays dialogue lines with portraits and text reveal
## Communicates with DialogManager via signals

## Text reveal settings
const BASE_TEXT_SPEED: float = 30.0  ## Characters per second
const PUNCTUATION_PAUSE: float = 0.15  ## Pause duration at punctuation

## UI element references
@onready var portrait_texture_rect: TextureRect = $ContentMargin/ContentHBox/PortraitContainer/Portrait
@onready var speaker_label: Label = $ContentMargin/ContentHBox/DialogVBox/SpeakerNameLabel
@onready var text_label: RichTextLabel = $ContentMargin/ContentHBox/DialogVBox/DialogTextLabel
@onready var continue_indicator: Label = $ContentMargin/ContentHBox/DialogVBox/ContinueIndicator
@onready var blink_animation: AnimationPlayer = $BlinkAnimation

## Current state
var is_revealing_text: bool = false
var visible_characters: float = 0.0
var full_text: String = ""
var text_reveal_speed: float = BASE_TEXT_SPEED


func _ready() -> void:
	# Connect to DialogManager signals
	DialogManager.line_changed.connect(_on_line_changed)
	DialogManager.dialog_ended.connect(_on_dialog_ended)

	# Start hidden
	hide()

	# Ensure continue indicator starts hidden
	continue_indicator.hide()

	# Set mouse filter to block clicks to battle map
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	if is_revealing_text:
		_update_text_reveal(delta)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Skip text reveal or advance dialog
	if event.is_action_pressed("sf_confirm"):
		if is_revealing_text:
			# Skip to end of text reveal
			_finish_text_reveal()
		else:
			# Advance to next line
			DialogManager.advance_dialog()
		get_viewport().set_input_as_handled()

	# Cancel dialog
	elif event.is_action_pressed("sf_cancel"):
		DialogManager.cancel_dialog()
		get_viewport().set_input_as_handled()


## Called when DialogManager changes line
func _on_line_changed(line_index: int, line_data: Dictionary) -> void:
	# Show the dialog box
	show()

	# Update portrait
	var portrait: Texture2D = line_data.get("portrait", null)
	if portrait:
		portrait_texture_rect.texture = portrait
		portrait_texture_rect.show()
	else:
		portrait_texture_rect.hide()

	# Update speaker name
	var speaker_name: String = line_data.get("speaker_name", "")
	speaker_label.text = speaker_name
	speaker_label.visible = not speaker_name.is_empty()

	# Start text reveal
	full_text = line_data.get("text", "")
	_start_text_reveal()


## Called when dialog ends
func _on_dialog_ended(dialogue_data: DialogueData) -> void:
	hide()
	continue_indicator.hide()
	blink_animation.stop()


## Start revealing text character by character
func _start_text_reveal() -> void:
	is_revealing_text = true
	visible_characters = 0.0
	text_label.visible_characters = 0
	text_label.text = full_text
	continue_indicator.hide()
	blink_animation.stop()

	# Apply text speed multiplier from DialogManager
	text_reveal_speed = BASE_TEXT_SPEED * DialogManager.text_speed_multiplier

	# If instant speed, finish immediately
	if text_reveal_speed >= 999:
		_finish_text_reveal()


## Update text reveal progress
func _update_text_reveal(delta: float) -> void:
	var chars_to_reveal: float = text_reveal_speed * delta
	var old_visible: int = int(visible_characters)
	visible_characters += chars_to_reveal
	var new_visible: int = int(visible_characters)

	# Check for punctuation pause
	if new_visible > old_visible and new_visible < full_text.length():
		var current_char: String = full_text[new_visible - 1]
		if current_char in [".", "!", "?"]:
			await get_tree().create_timer(PUNCTUATION_PAUSE).timeout

	text_label.visible_characters = new_visible

	# Check if finished
	if new_visible >= full_text.length():
		_finish_text_reveal()


## Finish text reveal instantly
func _finish_text_reveal() -> void:
	is_revealing_text = false
	visible_characters = float(full_text.length())
	text_label.visible_characters = -1  ## Show all text

	# Show continue indicator
	continue_indicator.show()
	blink_animation.play("blink")

	# Notify DialogManager
	DialogManager.on_text_reveal_finished()


## Set dialog box position based on BoxPosition enum
func set_box_position(pos: DialogueData.BoxPosition) -> void:
	match pos:
		DialogueData.BoxPosition.BOTTOM:
			size = Vector2(560, 120)
			position = Vector2(40, 220)
		DialogueData.BoxPosition.TOP:
			size = Vector2(560, 100)
			position = Vector2(40, 20)
		DialogueData.BoxPosition.CENTER:
			size = Vector2(600, 160)
			position = Vector2(20, 100)
		DialogueData.BoxPosition.AUTO:
			# TODO: Implement auto-positioning based on camera/context
			set_box_position(DialogueData.BoxPosition.BOTTOM)
