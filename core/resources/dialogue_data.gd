class_name DialogueData
extends Resource

## Represents a dialogue sequence with multiple speakers and lines.
## Can include branching choices for player decisions.

## Box positioning options (matches DialogManager.BoxPosition)
enum BoxPosition {
	BOTTOM,  ## Bottom of screen (default, story dialogs)
	TOP,     ## Top of screen (battle dialogs)
	CENTER,  ## Center of screen (dramatic moments)
	AUTO     ## Automatically position based on context
}

## Common emotion presets for portrait variants
enum Emotion {
	NEUTRAL,
	HAPPY,
	SAD,
	ANGRY,
	WORRIED,
	SURPRISED,
	DETERMINED,
	THINKING
}

## A single line of dialogue
class DialogueLine:
	var speaker_name: String = ""
	var portrait: Texture2D = null
	var text: String = ""
	var emotion: String = "neutral"  ## For portrait variants
	var voice_clip: AudioStream = null

	func _init(p_speaker: String = "", p_text: String = "", p_portrait: Texture2D = null) -> void:
		speaker_name = p_speaker
		text = p_text
		portrait = p_portrait

## A choice option for branching dialogue
class DialogueChoice:
	var choice_text: String = ""
	var next_dialogue: DialogueData = null
	var condition_script: GDScript = null  ## Optional condition to show this choice

	func _init(p_text: String = "", p_next: DialogueData = null) -> void:
		choice_text = p_text
		next_dialogue = p_next


@export var dialogue_id: String = ""
@export var dialogue_title: String = ""

@export_group("Content")
## Array of dialogue lines (stored as dictionaries for serialization)
@export var lines: Array[Dictionary] = []
## Array of choice options (stored as dictionaries for serialization)
@export var choices: Array[Dictionary] = []

@export_group("Flow Control")
## Next dialogue to play after this one (if no choices)
@export var next_dialogue: DialogueData
## Should this dialogue auto-advance?
@export var auto_advance: bool = false
## Auto-advance delay in seconds
@export var advance_delay: float = 2.0

@export_group("Audio")
## Background music for this dialogue
@export var background_music: AudioStream
## Sound effect when dialogue appears
@export var text_sound: AudioStream

@export_group("Visuals")
## Background image/scene for dialogue
@export var background: Texture2D
## Fade in/out duration
@export var fade_duration: float = 0.5
## Dialog box position on screen
@export var box_position: BoxPosition = BoxPosition.BOTTOM


## Add a line of dialogue
func add_line(speaker: String, text: String, portrait: Texture2D = null, emotion: String = "neutral") -> void:
	var line: Dictionary = {
		"speaker_name": speaker,
		"text": text,
		"emotion": emotion
	}
	if portrait != null:
		line["portrait"] = portrait
	lines.append(line)


## Add a choice option
func add_choice(choice_text: String, next_dialogue_data: DialogueData = null) -> void:
	var choice: Dictionary = {
		"choice_text": choice_text
	}
	if next_dialogue_data != null:
		choice["next_dialogue"] = next_dialogue_data
	choices.append(choice)


## Get a specific line by index
func get_line(index: int) -> Dictionary:
	if index >= 0 and index < lines.size():
		return lines[index]
	return {}


## Get total number of lines
func get_line_count() -> int:
	return lines.size()


## Get a specific choice by index
func get_choice(index: int) -> Dictionary:
	if index >= 0 and index < choices.size():
		return choices[index]
	return {}


## Get total number of choices
func get_choice_count() -> int:
	return choices.size()


## Check if this dialogue has branching choices
func has_choices() -> bool:
	return choices.size() > 0


## Check if this dialogue has a next dialogue
func has_next() -> bool:
	return next_dialogue != null


## Validate that required fields are set
func validate() -> bool:
	if dialogue_id.is_empty():
		push_error("DialogueData: dialogue_id is required")
		return false
	if lines.is_empty():
		push_error("DialogueData: dialogue must have at least one line")
		return false

	# Validate each line has required fields
	for i: int in range(lines.size()):
		var line: Dictionary = lines[i]
		if "text" not in line or line["text"] == "":
			push_error("DialogueData: line " + str(i) + " has no text")
			return false

	return true
