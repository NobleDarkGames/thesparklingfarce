@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Dialogue Editor UI
## Allows browsing and editing DialogueData resources

var dialogue_id_edit: LineEdit
var dialogue_title_edit: LineEdit

# Lines section
var lines_container: VBoxContainer
var lines_list: Array[Dictionary] = []  # Track line UI elements

# Choices section
var choices_container: VBoxContainer
var choices_list: Array[Dictionary] = []  # Track choice UI elements

# Flow control
var next_dialogue_option: OptionButton
var auto_advance_check: CheckBox
var advance_delay_spin: SpinBox

# Audio
var bgm_note_label: Label
var text_sound_note_label: Label


func _ready() -> void:
	resource_directory = "res://data/dialogues/"
	resource_type_name = "Dialogue"
	super._ready()


## Override: Create the dialogue-specific detail form
func _create_detail_form() -> void:
	# Basic info section
	_add_basic_info_section()

	# Dialogue lines section
	_add_lines_section()

	# Choices section
	_add_choices_section()

	# Flow control section
	_add_flow_control_section()

	# Audio section
	_add_audio_section()

	# Add the button container at the end
	detail_panel.add_child(button_container)


## Override: Load dialogue data from resource into UI
func _load_resource_data() -> void:
	var dialogue: DialogueData = current_resource as DialogueData
	if not dialogue:
		return

	dialogue_id_edit.text = dialogue.dialogue_id
	dialogue_title_edit.text = dialogue.dialogue_title

	# Clear existing lines UI
	_clear_lines_ui()

	# Load dialogue lines
	for line_dict in dialogue.lines:
		_add_line_ui(line_dict)

	# Clear existing choices UI
	_clear_choices_ui()

	# Load choices
	for choice_dict in dialogue.choices:
		_add_choice_ui(choice_dict)

	# Flow control
	_update_dialogue_dropdown()
	auto_advance_check.button_pressed = dialogue.auto_advance
	advance_delay_spin.value = dialogue.advance_delay

	# Set next dialogue
	if dialogue.next_dialogue:
		for i in range(available_resources.size()):
			if available_resources[i] == dialogue.next_dialogue:
				next_dialogue_option.selected = i + 1
				break
	else:
		next_dialogue_option.selected = 0


## Override: Save UI data to resource
func _save_resource_data() -> void:
	var dialogue: DialogueData = current_resource as DialogueData
	if not dialogue:
		return

	dialogue.dialogue_id = dialogue_id_edit.text
	dialogue.dialogue_title = dialogue_title_edit.text

	# Save dialogue lines
	var new_lines: Array[Dictionary] = []
	for line_ui in lines_list:
		var line_dict: Dictionary = {
			"speaker_name": line_ui.speaker_edit.text,
			"text": line_ui.text_edit.text,
			"emotion": line_ui.emotion_edit.text
		}
		new_lines.append(line_dict)
	dialogue.lines = new_lines

	# Save choices
	var new_choices: Array[Dictionary] = []
	for choice_ui in choices_list:
		var choice_dict: Dictionary = {
			"choice_text": choice_ui.text_edit.text
		}
		# Get next dialogue from dropdown
		var choice_index: int = choice_ui.next_option.selected - 1
		if choice_index >= 0 and choice_index < available_resources.size():
			choice_dict["next_dialogue"] = available_resources[choice_index]
		new_choices.append(choice_dict)
	dialogue.choices = new_choices

	# Flow control
	var next_index: int = next_dialogue_option.selected - 1
	if next_index >= 0 and next_index < available_resources.size():
		dialogue.next_dialogue = available_resources[next_index] as DialogueData
	else:
		dialogue.next_dialogue = null

	dialogue.auto_advance = auto_advance_check.button_pressed
	dialogue.advance_delay = advance_delay_spin.value


## Override: Validate resource before saving
func _validate_resource() -> Dictionary:
	var dialogue: DialogueData = current_resource as DialogueData
	if not dialogue:
		return {valid = false, errors = ["Invalid resource type"]}

	var errors: Array[String] = []

	if dialogue.dialogue_id.strip_edges().is_empty():
		errors.append("Dialogue ID cannot be empty")

	if dialogue.lines.is_empty():
		errors.append("Dialogue must have at least one line")

	# Validate each line has text
	for i in range(dialogue.lines.size()):
		var line: Dictionary = dialogue.lines[i]
		if not "text" in line or line["text"].strip_edges().is_empty():
			errors.append("Line " + str(i + 1) + " must have text")

	return {valid = errors.is_empty(), errors = errors}


## Override: Check for references before deletion
func _check_resource_references(resource_to_check: Resource) -> Array[String]:
	var dialogue_to_check: DialogueData = resource_to_check as DialogueData
	if not dialogue_to_check:
		return []

	var references: Array[String] = []

	# Check all dialogues for references in next_dialogue or choices
	var dir: DirAccess = DirAccess.open("res://data/dialogues/")
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var dialogue: DialogueData = load("res://data/dialogues/" + file_name)
				if dialogue:
					# Check next_dialogue
					if dialogue.next_dialogue == dialogue_to_check:
						references.append("res://data/dialogues/" + file_name)
					else:
						# Check choices
						for choice in dialogue.choices:
							if "next_dialogue" in choice and choice["next_dialogue"] == dialogue_to_check:
								references.append("res://data/dialogues/" + file_name)
								break
			file_name = dir.get_next()
		dir.list_dir_end()

	# Check battles for references
	var battle_dir: DirAccess = DirAccess.open("res://data/battles/")
	if battle_dir:
		battle_dir.list_dir_begin()
		var file_name: String = battle_dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var battle: BattleData = load("res://data/battles/" + file_name)
				if battle:
					if battle.pre_battle_dialogue == dialogue_to_check or \
					   battle.victory_dialogue == dialogue_to_check or \
					   battle.defeat_dialogue == dialogue_to_check:
						references.append("res://data/battles/" + file_name)
					else:
						# Check turn dialogues
						for turn in battle.turn_dialogues.keys():
							if battle.turn_dialogues[turn] == dialogue_to_check:
								references.append("res://data/battles/" + file_name)
								break
			file_name = battle_dir.get_next()
		battle_dir.list_dir_end()

	return references


## Override: Create a new dialogue with defaults
func _create_new_resource() -> Resource:
	var new_dialogue: DialogueData = DialogueData.new()
	new_dialogue.dialogue_id = "new_dialogue_" + str(Time.get_unix_time_from_system())
	new_dialogue.dialogue_title = "New Dialogue"
	# Add one default line
	new_dialogue.add_line("Speaker", "Enter dialogue text here.", null, "neutral")

	return new_dialogue


## Override: Get the display name from a dialogue resource
func _get_resource_display_name(resource: Resource) -> String:
	var dialogue: DialogueData = resource as DialogueData
	if dialogue:
		return dialogue.dialogue_title if not dialogue.dialogue_title.is_empty() else dialogue.dialogue_id
	return "Unnamed Dialogue"


func _add_basic_info_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Basic Information"
	section_label.add_theme_font_size_override("font_size", 14)
	section.add_child(section_label)

	# Dialogue ID
	var id_container: HBoxContainer = HBoxContainer.new()
	var id_label: Label = Label.new()
	id_label.text = "Dialogue ID:"
	id_label.custom_minimum_size.x = 120
	id_label.tooltip_text = "Unique identifier for this dialogue"
	id_container.add_child(id_label)

	dialogue_id_edit = LineEdit.new()
	dialogue_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_container.add_child(dialogue_id_edit)
	section.add_child(id_container)

	# Title
	var title_container: HBoxContainer = HBoxContainer.new()
	var title_label: Label = Label.new()
	title_label.text = "Title:"
	title_label.custom_minimum_size.x = 120
	title_container.add_child(title_label)

	dialogue_title_edit = LineEdit.new()
	dialogue_title_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_container.add_child(dialogue_title_edit)
	section.add_child(title_container)

	detail_panel.add_child(section)


func _add_lines_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Dialogue Lines"
	section_label.add_theme_font_size_override("font_size", 14)
	section.add_child(section_label)

	# Container for the list of lines
	lines_container = VBoxContainer.new()
	section.add_child(lines_container)

	# Add line button
	var add_line_button: Button = Button.new()
	add_line_button.text = "Add Line"
	add_line_button.pressed.connect(_on_add_line_pressed)
	section.add_child(add_line_button)

	detail_panel.add_child(section)


func _add_choices_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Choices (Optional Branching)"
	section_label.add_theme_font_size_override("font_size", 14)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Add choices for yes/no branches. If no choices, dialogue flows to 'Next Dialogue'."
	help_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	help_label.add_theme_font_size_override("font_size", 11)
	section.add_child(help_label)

	# Container for the list of choices
	choices_container = VBoxContainer.new()
	section.add_child(choices_container)

	# Add choice button
	var add_choice_button: Button = Button.new()
	add_choice_button.text = "Add Choice"
	add_choice_button.pressed.connect(_on_add_choice_pressed)
	section.add_child(add_choice_button)

	detail_panel.add_child(section)


func _add_flow_control_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Flow Control"
	section_label.add_theme_font_size_override("font_size", 14)
	section.add_child(section_label)

	# Next dialogue
	var next_container: HBoxContainer = HBoxContainer.new()
	var next_label: Label = Label.new()
	next_label.text = "Next Dialogue:"
	next_label.custom_minimum_size.x = 150
	next_label.tooltip_text = "Dialogue to play after this one (if no choices)"
	next_container.add_child(next_label)

	next_dialogue_option = OptionButton.new()
	next_dialogue_option.add_item("(None)", 0)
	next_dialogue_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_container.add_child(next_dialogue_option)
	section.add_child(next_container)

	# Auto advance
	auto_advance_check = CheckBox.new()
	auto_advance_check.text = "Auto-advance dialogue"
	section.add_child(auto_advance_check)

	# Advance delay
	var delay_container: HBoxContainer = HBoxContainer.new()
	var delay_label: Label = Label.new()
	delay_label.text = "Advance Delay (sec):"
	delay_label.custom_minimum_size.x = 150
	delay_container.add_child(delay_label)

	advance_delay_spin = SpinBox.new()
	advance_delay_spin.min_value = 0.1
	advance_delay_spin.max_value = 10.0
	advance_delay_spin.step = 0.1
	advance_delay_spin.value = 2.0
	delay_container.add_child(advance_delay_spin)
	section.add_child(delay_container)

	detail_panel.add_child(section)


func _add_audio_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Audio & Visuals"
	section_label.add_theme_font_size_override("font_size", 14)
	section.add_child(section_label)

	var note_label: Label = Label.new()
	note_label.text = "Note: Background music, text sounds, portraits, and backgrounds\ncan be assigned in the Inspector after saving."
	note_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	note_label.add_theme_font_size_override("font_size", 11)
	section.add_child(note_label)

	detail_panel.add_child(section)


func _on_add_line_pressed() -> void:
	var line_dict: Dictionary = {
		"speaker_name": "Speaker",
		"text": "Enter text here",
		"emotion": "neutral"
	}
	_add_line_ui(line_dict)


func _add_line_ui(line_dict: Dictionary) -> void:
	var line_container: VBoxContainer = VBoxContainer.new()
	line_container.add_theme_constant_override("separation", 4)

	# Header with line number and remove button
	var header: HBoxContainer = HBoxContainer.new()
	var line_num_label: Label = Label.new()
	line_num_label.text = "Line " + str(lines_list.size() + 1)
	line_num_label.add_theme_font_size_override("font_size", 12)
	header.add_child(line_num_label)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	# Move up button
	var up_button: Button = Button.new()
	up_button.text = "↑"
	up_button.custom_minimum_size.x = 30
	up_button.pressed.connect(_on_move_line_up.bind(line_container))
	header.add_child(up_button)

	# Move down button
	var down_button: Button = Button.new()
	down_button.text = "↓"
	down_button.custom_minimum_size.x = 30
	down_button.pressed.connect(_on_move_line_down.bind(line_container))
	header.add_child(down_button)

	# Remove button
	var remove_button: Button = Button.new()
	remove_button.text = "Remove"
	remove_button.pressed.connect(_on_remove_line.bind(line_container))
	header.add_child(remove_button)

	line_container.add_child(header)

	# Speaker
	var speaker_container: HBoxContainer = HBoxContainer.new()
	var speaker_label: Label = Label.new()
	speaker_label.text = "Speaker:"
	speaker_label.custom_minimum_size.x = 80
	speaker_container.add_child(speaker_label)

	var speaker_edit: LineEdit = LineEdit.new()
	speaker_edit.text = line_dict.get("speaker_name", "Speaker")
	speaker_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speaker_container.add_child(speaker_edit)

	var emotion_label: Label = Label.new()
	emotion_label.text = "Emotion:"
	emotion_label.custom_minimum_size.x = 70
	speaker_container.add_child(emotion_label)

	var emotion_edit: LineEdit = LineEdit.new()
	emotion_edit.text = line_dict.get("emotion", "neutral")
	emotion_edit.placeholder_text = "neutral, happy, sad, angry"
	emotion_edit.custom_minimum_size.x = 150
	speaker_container.add_child(emotion_edit)

	line_container.add_child(speaker_container)

	# Text
	var text_label: Label = Label.new()
	text_label.text = "Text:"
	line_container.add_child(text_label)

	var text_edit: TextEdit = TextEdit.new()
	text_edit.text = line_dict.get("text", "")
	text_edit.custom_minimum_size.y = 60
	line_container.add_child(text_edit)

	# Separator
	var separator: HSeparator = HSeparator.new()
	line_container.add_child(separator)

	# Store references to UI elements
	var line_ui: Dictionary = {
		"container": line_container,
		"speaker_edit": speaker_edit,
		"emotion_edit": emotion_edit,
		"text_edit": text_edit
	}
	lines_list.append(line_ui)

	lines_container.add_child(line_container)


func _on_remove_line(line_container: VBoxContainer) -> void:
	# Find and remove from lines_list
	for i in range(lines_list.size()):
		if lines_list[i].container == line_container:
			lines_list.remove_at(i)
			break

	line_container.queue_free()
	_update_line_numbers()


func _on_move_line_up(line_container: VBoxContainer) -> void:
	var index: int = -1
	for i in range(lines_list.size()):
		if lines_list[i].container == line_container:
			index = i
			break

	if index > 0:
		# Swap in array
		var temp: Dictionary = lines_list[index]
		lines_list[index] = lines_list[index - 1]
		lines_list[index - 1] = temp

		# Move in UI
		lines_container.move_child(line_container, index - 1)
		_update_line_numbers()


func _on_move_line_down(line_container: VBoxContainer) -> void:
	var index: int = -1
	for i in range(lines_list.size()):
		if lines_list[i].container == line_container:
			index = i
			break

	if index >= 0 and index < lines_list.size() - 1:
		# Swap in array
		var temp: Dictionary = lines_list[index]
		lines_list[index] = lines_list[index + 1]
		lines_list[index + 1] = temp

		# Move in UI
		lines_container.move_child(line_container, index + 1)
		_update_line_numbers()


func _update_line_numbers() -> void:
	for i in range(lines_list.size()):
		var header: HBoxContainer = lines_list[i].container.get_child(0) as HBoxContainer
		if header:
			var label: Label = header.get_child(0) as Label
			if label:
				label.text = "Line " + str(i + 1)


func _clear_lines_ui() -> void:
	for line_ui in lines_list:
		line_ui.container.queue_free()
	lines_list.clear()


func _on_add_choice_pressed() -> void:
	var choice_dict: Dictionary = {
		"choice_text": "New Choice"
	}
	_add_choice_ui(choice_dict)


func _add_choice_ui(choice_dict: Dictionary) -> void:
	var choice_container: VBoxContainer = VBoxContainer.new()

	# Header with choice number and remove button
	var header: HBoxContainer = HBoxContainer.new()
	var choice_num_label: Label = Label.new()
	choice_num_label.text = "Choice " + str(choices_list.size() + 1)
	choice_num_label.add_theme_font_size_override("font_size", 12)
	header.add_child(choice_num_label)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var remove_button: Button = Button.new()
	remove_button.text = "Remove"
	remove_button.pressed.connect(_on_remove_choice.bind(choice_container))
	header.add_child(remove_button)

	choice_container.add_child(header)

	# Choice text
	var text_container: HBoxContainer = HBoxContainer.new()
	var text_label: Label = Label.new()
	text_label.text = "Text:"
	text_label.custom_minimum_size.x = 80
	text_container.add_child(text_label)

	var text_edit: LineEdit = LineEdit.new()
	text_edit.text = choice_dict.get("choice_text", "")
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_container.add_child(text_edit)
	choice_container.add_child(text_container)

	# Next dialogue
	var next_container: HBoxContainer = HBoxContainer.new()
	var next_label: Label = Label.new()
	next_label.text = "Next Dialogue:"
	next_label.custom_minimum_size.x = 120
	next_container.add_child(next_label)

	var next_option: OptionButton = OptionButton.new()
	next_option.add_item("(None)", 0)
	next_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_populate_dialogue_dropdown(next_option)

	# Set selected dialogue if exists
	if "next_dialogue" in choice_dict and choice_dict["next_dialogue"]:
		for i in range(available_resources.size()):
			if available_resources[i] == choice_dict["next_dialogue"]:
				next_option.selected = i + 1
				break

	next_container.add_child(next_option)
	choice_container.add_child(next_container)

	# Separator
	var separator: HSeparator = HSeparator.new()
	choice_container.add_child(separator)

	# Store references
	var choice_ui: Dictionary = {
		"container": choice_container,
		"text_edit": text_edit,
		"next_option": next_option
	}
	choices_list.append(choice_ui)

	choices_container.add_child(choice_container)


func _on_remove_choice(choice_container: VBoxContainer) -> void:
	# Find and remove from choices_list
	for i in range(choices_list.size()):
		if choices_list[i].container == choice_container:
			choices_list.remove_at(i)
			break

	choice_container.queue_free()
	_update_choice_numbers()


func _update_choice_numbers() -> void:
	for i in range(choices_list.size()):
		var header: HBoxContainer = choices_list[i].container.get_child(0) as HBoxContainer
		if header:
			var label: Label = header.get_child(0) as Label
			if label:
				label.text = "Choice " + str(i + 1)


func _clear_choices_ui() -> void:
	for choice_ui in choices_list:
		choice_ui.container.queue_free()
	choices_list.clear()


func _update_dialogue_dropdown() -> void:
	_populate_dialogue_dropdown(next_dialogue_option)


func _populate_dialogue_dropdown(dropdown: OptionButton) -> void:
	# Keep (None) option
	var item_count: int = dropdown.item_count
	while item_count > 1:
		dropdown.remove_item(item_count - 1)
		item_count -= 1

	for i in range(available_resources.size()):
		var dialogue: DialogueData = available_resources[i] as DialogueData
		if dialogue:
			var display: String = dialogue.dialogue_title if not dialogue.dialogue_title.is_empty() else dialogue.dialogue_id
			dropdown.add_item(display, i + 1)
