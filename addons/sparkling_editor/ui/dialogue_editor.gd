@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Dialogue Editor UI
## Allows browsing and editing DialogueData resources
## Enhanced with character picker for easy speaker selection

var dialogue_id_edit: LineEdit
var dialogue_title_edit: LineEdit

# Lines section
var lines_container: VBoxContainer
var lines_list: Array[Dictionary] = []  # Track line UI elements

# Character cache for picker dropdowns
var _cached_characters: Array[Resource] = []

# Standard emotions (placeholder - will be data-driven later)
const EMOTIONS: Array[String] = ["neutral", "happy", "sad", "angry", "worried", "surprised", "determined", "thinking"]

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
	resource_type_id = "dialogue"
	resource_type_name = "Dialogue"
	# resource_directory is set dynamically via base class using ModLoader.get_active_mod()

	# Declare dependencies BEFORE calling super._ready() so base class sets up tracking
	resource_dependencies = ["character"]

	_refresh_character_cache()
	super._ready()


## Called when a dependent resource type changes (character created/saved/deleted)
func _on_dependencies_changed(_changed_type: String) -> void:
	_refresh_character_cache()
	# Update existing line pickers to reflect new character list
	_update_line_character_pickers()


## Refresh the cached list of characters from ModLoader
func _refresh_character_cache() -> void:
	_cached_characters.clear()
	if ModLoader and ModLoader.registry:
		_cached_characters = ModLoader.registry.get_all_resources("character")


## Update all line character pickers with the refreshed character cache
func _update_line_character_pickers() -> void:
	for line_ui: Dictionary in lines_list:
		var picker: OptionButton = line_ui.character_picker
		if not picker:
			continue

		# Store current selection (by character UID if selected)
		var current_char_uid: String = ""
		var current_index: int = picker.selected
		if current_index > 0:
			var char_idx: int = current_index - 1
			if char_idx >= 0 and char_idx < _cached_characters.size():
				var char_data: CharacterData = _cached_characters[char_idx] as CharacterData
				if char_data:
					current_char_uid = char_data.character_uid

		# Rebuild picker items
		picker.clear()
		picker.add_item("(Custom Speaker)", 0)
		for i: int in range(_cached_characters.size()):
			var char_data: CharacterData = _cached_characters[i] as CharacterData
			if char_data:
				var display_name: String = SparklingEditorUtils.get_character_display_name(char_data)
				picker.add_item(display_name, i + 1)

		# Restore selection by UID
		if not current_char_uid.is_empty():
			var new_index: int = _get_character_index_by_uid(current_char_uid)
			if new_index >= 0:
				picker.selected = new_index + 1
			else:
				picker.selected = 0  # Character was deleted, revert to custom
		elif current_index == 0:
			picker.selected = 0


## Get character by UID from cache
func _get_character_by_uid(uid: String) -> CharacterData:
	for char_data: CharacterData in _cached_characters:
		if not char_data:
			continue
		if char_data.character_uid == uid:
			return char_data
	return null


## Find character index in cache by UID (for dropdown selection)
func _get_character_index_by_uid(uid: String) -> int:
	for i: int in range(_cached_characters.size()):
		var char_data: CharacterData = _cached_characters[i] as CharacterData
		if char_data and char_data.character_uid == uid:
			return i
	return -1


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

	# Add the button container at the end (with separator for visual clarity)
	_add_button_container_to_detail_panel()


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
		var line_dict: Dictionary = {}

		# Get character_id or speaker_name based on picker selection
		var picker: OptionButton = line_ui.character_picker
		var picker_idx: int = picker.selected
		if picker_idx > 0:
			# Character selected - store character_id
			var char_idx: int = picker_idx - 1
			if char_idx >= 0 and char_idx < _cached_characters.size():
				var char_res: Resource = _cached_characters[char_idx]
				if char_res:
					# Use get() for safe property access in editor context
					var char_uid: String = ""
					var char_name: String = ""
					if "character_uid" in char_res:
						char_uid = str(char_res.get("character_uid"))
					if "character_name" in char_res:
						char_name = str(char_res.get("character_name"))
					line_dict["character_id"] = char_uid
					# Also store speaker_name as fallback/display hint
					line_dict["speaker_name"] = char_name
		else:
			# Custom speaker - store speaker_name only
			line_dict["speaker_name"] = line_ui.speaker_edit.text

		line_dict["text"] = line_ui.text_edit.text
		# Get emotion from dropdown
		var emotion_idx: int = line_ui.emotion_option.selected
		if emotion_idx >= 0 and emotion_idx < EMOTIONS.size():
			line_dict["emotion"] = EMOTIONS[emotion_idx]
		else:
			line_dict["emotion"] = "neutral"

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
## Reads from UI state (not resource) since validation runs before _save_resource_data()
func _validate_resource() -> Dictionary:
	var dialogue: DialogueData = current_resource as DialogueData
	if not dialogue:
		return {valid = false, errors = ["Invalid resource type"]}

	var errors: Array[String] = []

	# Validate dialogue ID from UI
	var dialogue_id: String = dialogue_id_edit.text.strip_edges() if dialogue_id_edit else ""
	if dialogue_id.is_empty():
		errors.append("Dialogue ID cannot be empty")

	# Validate lines from UI state
	if lines_list.is_empty():
		errors.append("Dialogue must have at least one line")

	# Validate each line has text (from UI)
	for i in range(lines_list.size()):
		var line_ui: Dictionary = lines_list[i]
		var text_edit: TextEdit = line_ui.get("text_edit") as TextEdit
		if text_edit and text_edit.text.strip_edges().is_empty():
			errors.append("Line " + str(i + 1) + " must have text")

	return {valid = errors.is_empty(), errors = errors}


## Override: Check for references before deletion
func _check_resource_references(resource_to_check: Resource) -> Array[String]:
	var dialogue_to_check: DialogueData = resource_to_check as DialogueData
	if not dialogue_to_check:
		return []

	var references: Array[String] = []

	# Check all dialogues across all mods for references in next_dialogue or choices
	var dialogue_files: Array[Dictionary] = _scan_all_mods_for_resource_type("dialogue")
	for file_info: Dictionary in dialogue_files:
		var dialogue: DialogueData = load(file_info.path) as DialogueData
		if dialogue:
			# Check next_dialogue
			if dialogue.next_dialogue == dialogue_to_check:
				references.append(file_info.path)
			else:
				# Check choices
				for choice: Dictionary in dialogue.choices:
					if "next_dialogue" in choice and choice["next_dialogue"] == dialogue_to_check:
						references.append(file_info.path)
						break

	# Check battles across all mods for references
	var battle_files: Array[Dictionary] = _scan_all_mods_for_resource_type("battle")
	for file_info: Dictionary in battle_files:
		var battle: BattleData = load(file_info.path) as BattleData
		if battle:
			if battle.pre_battle_dialogue == dialogue_to_check or \
			   battle.victory_dialogue == dialogue_to_check or \
			   battle.defeat_dialogue == dialogue_to_check:
				references.append(file_info.path)
			else:
				# Check turn dialogues
				for turn: int in battle.turn_dialogues.keys():
					if battle.turn_dialogues[turn] == dialogue_to_check:
						references.append(file_info.path)
						break

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
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.add_section("Basic Information")

	dialogue_id_edit = form.add_text_field("Dialogue ID:", "",
		"Unique ID for referencing this dialogue. Used in triggers and NPC assignments.")
	dialogue_id_edit.text_changed.connect(_on_field_changed)

	dialogue_title_edit = form.add_text_field("Title:", "",
		"Human-readable title for organization. Shown in editor dropdowns.")
	dialogue_title_edit.text_changed.connect(_on_field_changed)


## Called when any form field changes to mark the editor as dirty
func _on_field_changed(_new_value: Variant = null) -> void:
	_mark_dirty()


func _add_lines_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Dialogue Lines"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
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
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Add choices for yes/no branches. If no choices, dialogue flows to 'Next Dialogue'."
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
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
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.add_section("Flow Control")

	# Next dialogue dropdown
	next_dialogue_option = OptionButton.new()
	next_dialogue_option.add_item("(None)", 0)
	next_dialogue_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_dialogue_option.item_selected.connect(_on_field_changed)
	form.add_labeled_control("Next Dialogue:", next_dialogue_option,
		"Dialogue to play after this one (if no choices)")

	auto_advance_check = form.add_standalone_checkbox("Auto-advance dialogue", false,
		"Automatically progress to next line without player input. Good for cutscenes.")
	auto_advance_check.toggled.connect(_on_field_changed)

	advance_delay_spin = form.add_float_field("Advance Delay (sec):", 0.1, 10.0, 0.1, 2.0,
		"Seconds to wait between auto-advancing lines. 2.0 is typical reading pace.")
	advance_delay_spin.value_changed.connect(_on_field_changed)


func _add_audio_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.add_section("Audio & Visuals")
	form.add_help_text("Note: Background music, text sounds, portraits, and backgrounds\ncan be assigned in the Inspector after saving.")


func _on_add_line_pressed() -> void:
	var line_dict: Dictionary = {
		"speaker_name": "Speaker",
		"text": "Enter text here",
		"emotion": "neutral"
	}
	_add_line_ui(line_dict)
	_mark_dirty()


func _add_line_ui(line_dict: Dictionary) -> void:
	var line_container: VBoxContainer = VBoxContainer.new()
	line_container.add_theme_constant_override("separation", 4)

	# Header with line number and controls
	var header: HBoxContainer = HBoxContainer.new()
	var line_num_label: Label = Label.new()
	line_num_label.text = "Line " + str(lines_list.size() + 1)
	line_num_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
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

	# Speaker row with character picker
	var speaker_container: HBoxContainer = HBoxContainer.new()
	speaker_container.add_theme_constant_override("separation", 8)

	# Portrait preview (32x32 thumbnail)
	var portrait_preview: TextureRect = TextureRect.new()
	portrait_preview.custom_minimum_size = Vector2(32, 32)
	portrait_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_preview.visible = false
	speaker_container.add_child(portrait_preview)

	# Character picker dropdown
	var character_picker: OptionButton = OptionButton.new()
	character_picker.custom_minimum_size.x = 200
	character_picker.tooltip_text = "Select a character to auto-use their portrait and name. Or choose Custom for named NPCs."
	character_picker.add_item("(Custom Speaker)", 0)
	# Populate with characters from registry (with source mod prefix)
	for i in range(_cached_characters.size()):
		var char_data: CharacterData = _cached_characters[i] as CharacterData
		if char_data:
			var display_name: String = SparklingEditorUtils.get_character_display_name(char_data)
			character_picker.add_item(display_name, i + 1)
	speaker_container.add_child(character_picker)

	# Custom speaker name field (shown when "(Custom Speaker)" selected)
	var speaker_edit: LineEdit = LineEdit.new()
	speaker_edit.placeholder_text = "Speaker name"
	speaker_edit.custom_minimum_size.x = 120
	speaker_edit.tooltip_text = "Name displayed above the text box. For NPCs or unnamed characters."
	speaker_edit.text = line_dict.get("speaker_name", "")
	speaker_container.add_child(speaker_edit)

	# Emotion dropdown
	var emotion_label: Label = Label.new()
	emotion_label.text = "Emotion:"
	speaker_container.add_child(emotion_label)

	var emotion_option: OptionButton = OptionButton.new()
	emotion_option.custom_minimum_size.x = 100
	emotion_option.tooltip_text = "Portrait expression for this line. Changes displayed portrait variant if available."
	for emotion: String in EMOTIONS:
		emotion_option.add_item(emotion)
	# Set current emotion
	var current_emotion: String = line_dict.get("emotion", "neutral")
	var emotion_idx: int = EMOTIONS.find(current_emotion)
	if emotion_idx >= 0:
		emotion_option.selected = emotion_idx
	speaker_container.add_child(emotion_option)

	line_container.add_child(speaker_container)

	# Determine initial state: character_id vs custom speaker
	var has_character_id: bool = "character_id" in line_dict and not line_dict["character_id"].is_empty()
	if has_character_id:
		var char_idx: int = _get_character_index_by_uid(line_dict["character_id"])
		if char_idx >= 0:
			character_picker.selected = char_idx + 1  # +1 for "(Custom Speaker)" offset
			speaker_edit.visible = false
			# Show portrait
			var char_data: CharacterData = _cached_characters[char_idx] as CharacterData
			if char_data and char_data.portrait:
				portrait_preview.texture = char_data.portrait
				portrait_preview.visible = true
		else:
			# Character ID not found, fall back to custom
			character_picker.selected = 0
			speaker_edit.visible = true
			speaker_edit.text = line_dict.get("speaker_name", "")
	else:
		# No character_id, use speaker_name
		character_picker.selected = 0
		speaker_edit.visible = true

	# Connect character picker changes
	character_picker.item_selected.connect(_on_character_selected.bind(
		character_picker, speaker_edit, portrait_preview
	))

	# Text field with hint about variables
	var text_container: VBoxContainer = VBoxContainer.new()
	var text_header: HBoxContainer = HBoxContainer.new()
	var text_label: Label = Label.new()
	text_label.text = "Text:"
	text_header.add_child(text_label)
	var text_hint: Label = Label.new()
	text_hint.text = "(Use {variable_name} for dynamic text)"
	text_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	text_hint.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	text_header.add_child(text_hint)
	text_container.add_child(text_header)

	var text_edit: TextEdit = TextEdit.new()
	text_edit.text = line_dict.get("text", "")
	text_edit.custom_minimum_size.y = 60
	text_edit.placeholder_text = "Enter dialogue text here..."
	text_container.add_child(text_edit)
	line_container.add_child(text_container)

	# Separator
	var separator: HSeparator = HSeparator.new()
	line_container.add_child(separator)

	# Connect dirty tracking to line UI elements
	character_picker.item_selected.connect(_on_field_changed)
	speaker_edit.text_changed.connect(_on_field_changed)
	emotion_option.item_selected.connect(_on_field_changed)
	text_edit.text_changed.connect(_on_field_changed)

	# Store references to UI elements (including new ones)
	var line_ui: Dictionary = {
		"container": line_container,
		"character_picker": character_picker,
		"speaker_edit": speaker_edit,
		"emotion_option": emotion_option,
		"portrait_preview": portrait_preview,
		"text_edit": text_edit
	}
	lines_list.append(line_ui)

	lines_container.add_child(line_container)


## Handle character picker selection changes
func _on_character_selected(index: int, picker: OptionButton, speaker_edit: LineEdit, portrait_preview: TextureRect) -> void:
	if index == 0:
		# Custom speaker selected
		speaker_edit.visible = true
		portrait_preview.visible = false
	else:
		# Character selected
		speaker_edit.visible = false
		var char_idx: int = index - 1  # Offset for "(Custom Speaker)"
		if char_idx >= 0 and char_idx < _cached_characters.size():
			var char_data: CharacterData = _cached_characters[char_idx] as CharacterData
			if char_data and char_data.portrait:
				portrait_preview.texture = char_data.portrait
				portrait_preview.visible = true
			else:
				portrait_preview.visible = false


func _on_remove_line(line_container: VBoxContainer) -> void:
	# Find and remove from lines_list
	for i in range(lines_list.size()):
		if lines_list[i].container == line_container:
			lines_list.remove_at(i)
			break

	line_container.queue_free()
	_update_line_numbers()
	_mark_dirty()


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
		_mark_dirty()


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
		_mark_dirty()


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
	_mark_dirty()


func _add_choice_ui(choice_dict: Dictionary) -> void:
	var choice_container: VBoxContainer = VBoxContainer.new()

	# Header with choice number and remove button
	var header: HBoxContainer = HBoxContainer.new()
	var choice_num_label: Label = Label.new()
	choice_num_label.text = "Choice " + str(choices_list.size() + 1)
	choice_num_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
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

	# Connect dirty tracking to choice UI elements
	text_edit.text_changed.connect(_on_field_changed)
	next_option.item_selected.connect(_on_field_changed)

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
	_mark_dirty()


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
