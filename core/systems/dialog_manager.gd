extends Node

## DialogManager - Orchestrates dialog display and flow
## Singleton autoload that manages dialog state and communicates with UI via signals
## Accessed globally as DialogManager (autoload name)

## Dialog states
enum State {
	IDLE,              ## No dialog active
	DIALOG_STARTING,   ## Dialog beginning (fade in, setup)
	SHOWING_LINE,      ## Currently displaying a line
	WAITING_FOR_INPUT, ## Waiting for player to advance
	WAITING_FOR_CHOICE,## Waiting for player choice selection
	DIALOG_ENDING      ## Dialog finishing (fade out, cleanup)
}

## Box positioning options
enum BoxPosition {
	BOTTOM,  ## Bottom of screen (default, story dialogs)
	TOP,     ## Top of screen (battle dialogs)
	CENTER,  ## Center of screen (dramatic moments)
	AUTO     ## Automatically position based on context
}

## Text reveal speed presets
enum TextSpeed {
	SLOW = 15,
	NORMAL = 30,
	FAST = 60,
	INSTANT = 999
}

## Signals
signal dialog_started(dialogue_data: DialogueData)
signal dialog_ended(dialogue_data: DialogueData)
signal line_changed(line_index: int, line_data: Dictionary)
signal text_reveal_started()
signal text_reveal_finished()
signal choices_ready(choices: Array[Dictionary])
signal choice_selected(choice_index: int, next_dialogue: DialogueData)
signal dialog_cancelled()

## Current state
var current_state: State = State.IDLE
var current_dialogue: DialogueData = null
var current_line_index: int = 0

## Dialog chain tracking (prevents circular references)
var _dialog_chain_stack: Array[String] = []
const MAX_DIALOG_CHAIN_DEPTH: int = 10

## Settings
var text_speed_multiplier: float = 1.0  ## User preference (0.5 = slow, 1.0 = normal, 2.0 = fast)

## References (will be set when DialogBox is created)
var dialog_box: Control = null


func _ready() -> void:
	# This is an autoload singleton
	# DialogBox will be instantiated by scenes that need it
	# (e.g., battle scenes, world scenes)
	pass


## Start a dialog by ID (looks up in ModRegistry)
func start_dialog(dialogue_id: String) -> bool:
	if current_state != State.IDLE:
		push_warning("DialogManager: Cannot start dialog '%s' - dialog already active" % dialogue_id)
		return false

	# Look up dialogue in ModRegistry
	var dialogue: DialogueData = ModLoader.registry.get_resource("dialogue", dialogue_id) as DialogueData
	if not dialogue:
		push_error("DialogManager: Dialogue '%s' not found in ModRegistry" % dialogue_id)
		return false

	return start_dialog_from_resource(dialogue)


## Start a dialog from a DialogueData resource directly
func start_dialog_from_resource(dialogue: DialogueData) -> bool:
	if not dialogue:
		push_error("DialogManager: Cannot start null dialogue")
		return false

	if current_state != State.IDLE:
		push_warning("DialogManager: Cannot start dialog - dialog already active")
		return false

	# Validate the dialogue
	if not dialogue.validate():
		push_error("DialogManager: Dialogue validation failed")
		return false

	# Check for circular references
	if dialogue.dialogue_id in _dialog_chain_stack:
		push_error("DialogManager: Circular dialog reference detected: %s" % dialogue.dialogue_id)
		return false

	# Check max chain depth
	if _dialog_chain_stack.size() >= MAX_DIALOG_CHAIN_DEPTH:
		push_error("DialogManager: Max dialog chain depth (%d) exceeded" % MAX_DIALOG_CHAIN_DEPTH)
		return false

	# Add to chain stack
	_dialog_chain_stack.append(dialogue.dialogue_id)

	# Start the dialog
	current_dialogue = dialogue
	current_line_index = 0
	current_state = State.DIALOG_STARTING

	emit_signal("dialog_started", dialogue)

	# Move to first line
	_show_line(0)

	return true


## Advance to the next line or finish dialog
func advance_dialog() -> void:
	if current_state == State.WAITING_FOR_INPUT:
		# Move to next line
		current_line_index += 1

		if current_line_index < current_dialogue.get_line_count():
			_show_line(current_line_index)
		else:
			# No more lines - check for choices or next dialogue
			if current_dialogue.has_choices():
				_show_choices()
			elif current_dialogue.has_next():
				_end_dialog_and_chain_to_next()
			else:
				_end_dialog()


## Show a specific line
func _show_line(line_index: int) -> void:
	if not current_dialogue:
		return

	var line_data: Dictionary = current_dialogue.get_line(line_index)
	if line_data.is_empty():
		push_error("DialogManager: Invalid line index %d" % line_index)
		_end_dialog()
		return

	current_state = State.SHOWING_LINE
	current_line_index = line_index

	emit_signal("line_changed", line_index, line_data)

	# After text reveal completes, move to waiting for input
	# (This will be handled by DialogBox emitting text_reveal_finished)


## Called when text reveal finishes (from DialogBox)
func on_text_reveal_finished() -> void:
	if current_state == State.SHOWING_LINE:
		current_state = State.WAITING_FOR_INPUT


## Show choices to the player
func _show_choices() -> void:
	if not current_dialogue:
		return

	var choices: Array[Dictionary] = []
	for i in range(current_dialogue.get_choice_count()):
		choices.append(current_dialogue.get_choice(i))

	current_state = State.WAITING_FOR_CHOICE
	emit_signal("choices_ready", choices)


## Player selected a choice
func select_choice(choice_index: int) -> void:
	if current_state != State.WAITING_FOR_CHOICE:
		push_warning("DialogManager: Cannot select choice - not waiting for choice")
		return

	var choice: Dictionary = current_dialogue.get_choice(choice_index)
	if choice.is_empty():
		push_error("DialogManager: Invalid choice index %d" % choice_index)
		return

	var next_dialogue: DialogueData = choice.get("next_dialogue", null)
	emit_signal("choice_selected", choice_index, next_dialogue)

	# End current dialog
	_end_dialog()

	# Chain to next dialogue if exists
	if next_dialogue:
		start_dialog_from_resource(next_dialogue)


## End the current dialog
func _end_dialog() -> void:
	if current_state == State.IDLE:
		return

	current_state = State.DIALOG_ENDING

	var finished_dialogue: DialogueData = current_dialogue

	# Remove from chain stack
	if not _dialog_chain_stack.is_empty():
		_dialog_chain_stack.pop_back()

	# Clear current data
	current_dialogue = null
	current_line_index = 0

	emit_signal("dialog_ended", finished_dialogue)

	current_state = State.IDLE


## End dialog and chain to next
func _end_dialog_and_chain_to_next() -> void:
	if not current_dialogue:
		return

	var next: DialogueData = current_dialogue.next_dialogue
	_end_dialog()

	if next:
		start_dialog_from_resource(next)


## Cancel the current dialog (player pressed cancel/escape)
func cancel_dialog() -> void:
	if current_state == State.IDLE:
		return

	emit_signal("dialog_cancelled")
	_end_dialog()


## Check if a dialog is currently active
func is_dialog_active() -> bool:
	return current_state != State.IDLE


## Get the current state
func get_current_state() -> State:
	return current_state


## Set text speed multiplier (from settings)
func set_text_speed(speed: TextSpeed) -> void:
	match speed:
		TextSpeed.SLOW:
			text_speed_multiplier = 0.5
		TextSpeed.NORMAL:
			text_speed_multiplier = 1.0
		TextSpeed.FAST:
			text_speed_multiplier = 2.0
		TextSpeed.INSTANT:
			text_speed_multiplier = 999.0
