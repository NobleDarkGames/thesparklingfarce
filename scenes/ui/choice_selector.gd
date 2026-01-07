## ChoiceSelector - Displays dialog choices for player selection
## Matches action_menu ColorRect border style
class_name ChoiceSelector
extends Control

## Animation settings
const SLIDE_IN_DURATION: float = 0.2  ## Choice box slide-in duration

## UI element references
@onready var choices_container: VBoxContainer = $ContentMargin/ChoiceVBox

## Current state
var choice_labels: Array[Label] = []
var selected_index: int = 0
var is_active: bool = false


func _ready() -> void:
	# Connect to DialogManager signals
	DialogManager.choices_ready.connect(_on_choices_ready)
	DialogManager.dialog_ended.connect(_on_dialog_ended)
	DialogManager.dialog_cancelled.connect(_on_dialog_cancelled)

	# Start hidden
	hide()

	# Set mouse filter to block clicks to battle map
	mouse_filter = Control.MOUSE_FILTER_STOP


func _exit_tree() -> void:
	# Disconnect from DialogManager signals to prevent stale references
	if DialogManager.choices_ready.is_connected(_on_choices_ready):
		DialogManager.choices_ready.disconnect(_on_choices_ready)
	if DialogManager.dialog_ended.is_connected(_on_dialog_ended):
		DialogManager.dialog_ended.disconnect(_on_dialog_ended)
	if DialogManager.dialog_cancelled.is_connected(_on_dialog_cancelled):
		DialogManager.dialog_cancelled.disconnect(_on_dialog_cancelled)


func _input(event: InputEvent) -> void:
	if not is_active or not visible:
		return

	# Navigate choices
	if event.is_action_pressed("ui_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()

	# Confirm selection
	elif event.is_action_pressed("sf_confirm"):
		_select_current_choice()
		get_viewport().set_input_as_handled()

	# Cancel not allowed for choices - player must pick one
	# (Can add optional cancel support later if needed)


## Called when DialogManager shows choices
func _on_choices_ready(choices: Array[Dictionary]) -> void:
	if choices.is_empty():
		return

	# Clear existing choice labels
	_clear_choices()

	# Create labels for each choice
	for i: int in range(choices.size()):
		var choice_dict: Dictionary = choices[i]
		var choice_text_val: Variant = choice_dict.get("choice_text", "Choice " + str(i + 1))
		var choice_text: String = str(choice_text_val) if choice_text_val != null else "Choice " + str(i + 1)

		var label: Label = Label.new()
		label.text = choice_text
		label.add_theme_font_size_override("font_size", 16)
		label.mouse_filter = Control.MOUSE_FILTER_STOP

		# Mouse hover detection
		label.mouse_entered.connect(_on_choice_mouse_entered.bind(i))
		label.gui_input.connect(_on_choice_gui_input.bind(i))

		choices_container.add_child(label)
		choice_labels.append(label)

	# Reset selection
	selected_index = 0
	_update_selection_visual()

	# Show with slide-in animation
	_show_with_animation()


## Called when dialog ends
## Only hide if choices are currently active - don't hide on dialog_ended if choices
## haven't been shown yet (e.g., campaign choices come AFTER dialog ends)
func _on_dialog_ended(_dialogue_data: DialogueData) -> void:
	if is_active:
		_hide_with_animation()


## Called when dialog is cancelled (player backed out)
func _on_dialog_cancelled() -> void:
	if is_active:
		_hide_with_animation()


## Show choices with slide-in animation from bottom
func _show_with_animation() -> void:
	is_active = true

	# Position below viewport
	var target_position: Vector2 = Vector2(20, 240)
	position = Vector2(20, 360)  ## Start below screen

	show()

	# Slide up into view
	var slide_tween: Tween = create_tween()
	slide_tween.tween_property(self, "position", target_position, SLIDE_IN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## Hide choices with slide-out animation
func _hide_with_animation() -> void:
	is_active = false

	var slide_tween: Tween = create_tween()
	slide_tween.tween_property(self, "position:y", 360.0, SLIDE_IN_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	await slide_tween.finished

	hide()
	_clear_choices()


## Move selection up or down
func _move_selection(delta: int) -> void:
	selected_index += delta

	# Wrap around
	if selected_index < 0:
		selected_index = choice_labels.size() - 1
	elif selected_index >= choice_labels.size():
		selected_index = 0

	_update_selection_visual()


## Update visual highlighting of selected choice
func _update_selection_visual() -> void:
	for i: int in range(choice_labels.size()):
		if i == selected_index:
			# Highlight selected choice (yellow)
			choice_labels[i].modulate = Color(1.0, 1.0, 0.3, 1.0)
		else:
			# Normal gray
			choice_labels[i].modulate = Color(0.8, 0.8, 0.8, 1.0)


## Select the current choice
func _select_current_choice() -> void:
	if selected_index >= 0 and selected_index < choice_labels.size():
		# Notify DialogManager
		DialogManager.select_choice(selected_index)


## Clear all choice labels
func _clear_choices() -> void:
	for label: Label in choice_labels:
		label.queue_free()
	choice_labels.clear()


## Mouse entered a choice
func _on_choice_mouse_entered(choice_index: int) -> void:
	selected_index = choice_index
	_update_selection_visual()


## Mouse clicked a choice
func _on_choice_gui_input(event: InputEvent, choice_index: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			selected_index = choice_index
			_select_current_choice()
