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

## Animation settings
const PORTRAIT_SLIDE_DURATION: float = 0.15  ## Portrait slide animation duration
const DIALOG_FADE_DURATION: float = 0.2  ## Dialog box fade in/out duration

## Current state
var is_revealing_text: bool = false
var visible_characters: float = 0.0
var full_text: String = ""
var text_reveal_speed: float = BASE_TEXT_SPEED
var current_portrait: Texture2D = null  ## Track current portrait for change detection
var is_first_line: bool = true  ## Track if this is the first line of dialog
var fade_tween: Tween = null  ## Track active fade animation to prevent conflicts


func _ready() -> void:
	# Connect to DialogManager signals
	DialogManager.line_changed.connect(_on_line_changed)
	DialogManager.dialog_ended.connect(_on_dialog_ended)

	# Start hidden with NO stale content
	hide()
	modulate.a = 0.0

	# Clear any stale text content to prevent flicker on first show
	_clear_all_content()

	# Ensure continue indicator starts hidden
	continue_indicator.hide()

	# Set mouse filter to block clicks to battle map
	mouse_filter = Control.MOUSE_FILTER_STOP


## Clear all text/visual content to prevent stale content flicker
func _clear_all_content() -> void:
	if text_label:
		text_label.text = ""
		text_label.visible_characters = 0
	if speaker_label:
		speaker_label.text = ""
	if portrait_texture_rect:
		portrait_texture_rect.texture = null
		portrait_texture_rect.hide()
	full_text = ""
	visible_characters = 0.0


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
	# Cancel any existing fade animation
	if fade_tween:
		fade_tween.kill()
		fade_tween = null

	# IMMEDIATELY clear old text content to prevent ANY flash of previous content
	# This must happen BEFORE any await operations (portrait animations, fade-in, etc.)
	text_label.text = ""
	text_label.visible_characters = 0
	full_text = ""
	visible_characters = 0.0

	# Fade in dialog box on first line (or if it was hidden)
	if is_first_line or modulate.a < 0.5:
		modulate.a = 0.0
		show()
		fade_tween = create_tween()
		fade_tween.tween_property(self, "modulate:a", 1.0, DIALOG_FADE_DURATION)
		await fade_tween.finished
		fade_tween = null
		is_first_line = false
	else:
		show()
		modulate.a = 1.0  ## Ensure fully visible

	# Update portrait with animation - try emotion variant if not explicitly provided
	var new_portrait: Texture2D = line_data.get("portrait", null)

	# If no portrait provided, try to load based on speaker name and emotion
	if not new_portrait:
		var speaker_name: String = line_data.get("speaker_name", "")
		var emotion: String = line_data.get("emotion", "neutral")
		if not speaker_name.is_empty():
			new_portrait = _try_load_portrait_variant(speaker_name, emotion)

	await _update_portrait(new_portrait)

	# Update speaker name with color modulation
	var speaker_name: String = line_data.get("speaker_name", "")
	speaker_label.text = speaker_name
	speaker_label.visible = not speaker_name.is_empty()

	# Highlight speaker name briefly
	if not speaker_name.is_empty():
		speaker_label.modulate = Color(1.0, 1.0, 0.6, 1.0)  ## Yellow tint
		var speaker_tween: Tween = create_tween()
		speaker_tween.tween_property(speaker_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)

	# Start text reveal
	full_text = line_data.get("text", "")
	_start_text_reveal()


## Try to load portrait variant based on speaker name and emotion
## Searches for portraits in pattern: {speaker}_{emotion}.png
## Example: "max_happy.png", "anri_sad.png"
func _try_load_portrait_variant(speaker_name: String, emotion: String) -> Texture2D:
	# Normalize speaker name (lowercase, remove spaces)
	var normalized_speaker: String = speaker_name.to_lower().replace(" ", "_")
	var normalized_emotion: String = emotion.to_lower()

	# Search pattern: {speaker}_{emotion}.png
	var portrait_filename: String = "%s_%s.png" % [normalized_speaker, normalized_emotion]

	# Common portrait directories to search
	var search_paths: Array[String] = [
		"res://mods/_base_game/assets/portraits/%s" % portrait_filename,
		"res://assets/portraits/%s" % portrait_filename,
	]

	# Try each path
	for path: String in search_paths:
		if ResourceLoader.exists(path):
			var portrait: Texture2D = load(path) as Texture2D
			if portrait:
				return portrait

	# Fallback: try without emotion (just speaker name)
	var fallback_filename: String = "%s.png" % normalized_speaker
	for path: String in search_paths:
		var fallback_path: String = path.replace(portrait_filename, fallback_filename)
		if ResourceLoader.exists(fallback_path):
			var portrait: Texture2D = load(fallback_path) as Texture2D
			if portrait:
				return portrait

	# No portrait found
	return null


## Update portrait with slide animation
func _update_portrait(new_portrait: Texture2D) -> void:
	# Check if portrait changed
	var portrait_changed: bool = (new_portrait != current_portrait)

	if new_portrait:
		if portrait_changed and current_portrait != null:
			# Slide out old portrait
			var slide_out_tween: Tween = create_tween()
			slide_out_tween.tween_property(portrait_texture_rect, "position:x", -80.0, PORTRAIT_SLIDE_DURATION)
			await slide_out_tween.finished

		# Set new portrait
		portrait_texture_rect.texture = new_portrait
		current_portrait = new_portrait
		portrait_texture_rect.show()

		if portrait_changed:
			# Start portrait offscreen
			portrait_texture_rect.position.x = -80.0

			# Slide in new portrait
			var slide_in_tween: Tween = create_tween()
			slide_in_tween.tween_property(portrait_texture_rect, "position:x", 0.0, PORTRAIT_SLIDE_DURATION)
			await slide_in_tween.finished
	else:
		# No portrait - hide it
		if current_portrait != null:
			var slide_out_tween: Tween = create_tween()
			slide_out_tween.tween_property(portrait_texture_rect, "position:x", -80.0, PORTRAIT_SLIDE_DURATION)
			await slide_out_tween.finished

		portrait_texture_rect.hide()
		current_portrait = null


## Called when dialog ends
func _on_dialog_ended(dialogue_data: DialogueData) -> void:
	# Only fade out if we're actually visible (not chaining to another dialog)
	# Check after a brief delay to see if another dialog started
	await get_tree().create_timer(0.05).timeout

	# If dialog is still idle after delay, fade out
	if DialogManager.current_state == DialogManager.State.IDLE:
		# Cancel any existing fade
		if fade_tween:
			fade_tween.kill()
			fade_tween = null

		# Fade out dialog box
		fade_tween = create_tween()
		fade_tween.tween_property(self, "modulate:a", 0.0, DIALOG_FADE_DURATION)
		await fade_tween.finished
		fade_tween = null

		hide()
		modulate.a = 0.0  # Keep at 0 when hidden to prevent flash on next show

		# Clear ALL content after hiding to prevent stale content flash on next dialog
		_clear_all_content()

	# Always clean up UI elements
	continue_indicator.hide()
	blink_animation.stop()

	# Reset state for next dialog
	is_first_line = true
	current_portrait = null


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

	# Subtle text completion feedback - brief glow effect
	var glow_tween: Tween = create_tween()
	glow_tween.tween_property(text_label, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.1)
	glow_tween.tween_property(text_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)

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
