@tool
class_name DialogLinePopup
extends Window

## Popup for quickly creating dialog_line JSON commands
## Shows character picker, emotion dropdown, and text field
## Copies formatted JSON to clipboard for pasting into cinematic files

signal dialog_created(json_text: String)

# Standard emotions
const EMOTIONS: Array[String] = ["neutral", "happy", "sad", "angry", "worried", "surprised", "determined", "thinking"]

# UI elements
var character_picker: OptionButton
var portrait_preview: TextureRect
var emotion_picker: OptionButton
var text_edit: TextEdit
var copy_button: Button
var cancel_button: Button
var result_preview: TextEdit

# Character cache
var _characters: Array[Resource] = []


func _ready() -> void:
	title = "Quick Add Dialog Line"
	size = Vector2i(500, 400)
	exclusive = true
	transient = true

	_refresh_characters()
	_setup_ui()

	close_requested.connect(_on_cancel)


func _refresh_characters() -> void:
	_characters.clear()
	if ModLoader and ModLoader.registry:
		_characters = ModLoader.registry.get_all_resources("character")


func _setup_ui() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(main_vbox)

	# Character row
	var char_row: HBoxContainer = HBoxContainer.new()
	char_row.add_theme_constant_override("separation", 8)
	main_vbox.add_child(char_row)

	# Portrait preview
	portrait_preview = TextureRect.new()
	portrait_preview.custom_minimum_size = Vector2(48, 48)
	portrait_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	char_row.add_child(portrait_preview)

	# Character picker
	var char_vbox: VBoxContainer = VBoxContainer.new()
	char_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_row.add_child(char_vbox)

	var char_label: Label = Label.new()
	char_label.text = "Character:"
	char_vbox.add_child(char_label)

	character_picker = OptionButton.new()
	character_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_picker.add_item("(Custom Speaker)", 0)
	for i: int in range(_characters.size()):
		var char_data: CharacterData = _characters[i] as CharacterData
		if char_data:
			var display_name: String = _get_character_display_name_with_mod(char_data)
			character_picker.add_item(display_name, i + 1)
	character_picker.item_selected.connect(_on_character_selected)
	char_vbox.add_child(character_picker)

	# Emotion picker
	var emotion_vbox: VBoxContainer = VBoxContainer.new()
	char_row.add_child(emotion_vbox)

	var emotion_label: Label = Label.new()
	emotion_label.text = "Emotion:"
	emotion_vbox.add_child(emotion_label)

	emotion_picker = OptionButton.new()
	emotion_picker.custom_minimum_size.x = 120
	for emotion: String in EMOTIONS:
		emotion_picker.add_item(emotion)
	emotion_picker.item_selected.connect(_on_input_changed)
	emotion_vbox.add_child(emotion_picker)

	# Text input
	var text_label: Label = Label.new()
	text_label.text = "Dialog Text: (Use {variable_name} for dynamic text)"
	main_vbox.add_child(text_label)

	text_edit = TextEdit.new()
	text_edit.custom_minimum_size.y = 80
	text_edit.placeholder_text = "Enter what the character says..."
	text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_edit.text_changed.connect(_on_input_changed)
	main_vbox.add_child(text_edit)

	# JSON Preview
	var preview_label: Label = Label.new()
	preview_label.text = "JSON Preview:"
	main_vbox.add_child(preview_label)

	result_preview = TextEdit.new()
	result_preview.custom_minimum_size.y = 80
	result_preview.editable = false
	result_preview.add_theme_color_override("font_color", EditorThemeUtils.get_success_color())
	main_vbox.add_child(result_preview)

	# Buttons
	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	button_row.alignment = BoxContainer.ALIGNMENT_END
	main_vbox.add_child(button_row)

	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(_on_cancel)
	button_row.add_child(cancel_button)

	copy_button = Button.new()
	copy_button.text = "Copy to Clipboard"
	copy_button.pressed.connect(_on_copy)
	button_row.add_child(copy_button)

	# Initial preview
	_update_preview()


func _on_character_selected(index: int) -> void:
	if index > 0:
		var char_idx: int = index - 1
		if char_idx >= 0 and char_idx < _characters.size():
			var char_data: CharacterData = _characters[char_idx] as CharacterData
			if char_data and char_data.portrait:
				portrait_preview.texture = char_data.portrait
			else:
				portrait_preview.texture = null
	else:
		portrait_preview.texture = null

	_update_preview()


func _on_input_changed() -> void:
	_update_preview()


func _update_preview() -> void:
	var json_dict: Dictionary = _build_command_dict()
	var json_text: String = JSON.stringify(json_dict, "  ")
	result_preview.text = json_text


func _build_command_dict() -> Dictionary:
	var params: Dictionary = {}

	# Character
	var char_idx: int = character_picker.selected
	if char_idx > 0:
		var data_idx: int = char_idx - 1
		if data_idx >= 0 and data_idx < _characters.size():
			var char_data: CharacterData = _characters[data_idx] as CharacterData
			if char_data:
				params["character_id"] = char_data.character_uid
	else:
		# Custom speaker - user needs to fill in manually
		params["character_id"] = "REPLACE_WITH_CHARACTER_UID"

	# Text
	var dialog_text: String = text_edit.text.strip_edges()
	if dialog_text.is_empty():
		dialog_text = "Enter dialog text here"
	params["text"] = dialog_text

	# Emotion
	var emotion_idx: int = emotion_picker.selected
	if emotion_idx >= 0 and emotion_idx < EMOTIONS.size():
		params["emotion"] = EMOTIONS[emotion_idx]
	else:
		params["emotion"] = "neutral"

	return {
		"type": "dialog_line",
		"params": params
	}


func _on_copy() -> void:
	var json_dict: Dictionary = _build_command_dict()
	var json_text: String = JSON.stringify(json_dict, "  ")
	DisplayServer.clipboard_set(json_text)

	# Emit signal and close
	dialog_created.emit(json_text)
	hide()


func _on_cancel() -> void:
	hide()


## Get character display name with source mod prefix: "[mod_id] Name"
func _get_character_display_name_with_mod(char_data: CharacterData) -> String:
	if not char_data:
		return "(Unknown)"

	var mod_id: String = ""
	if ModLoader and ModLoader.registry:
		var resource_id: String = char_data.resource_path.get_file().get_basename()
		mod_id = ModLoader.registry.get_resource_source(resource_id)

	if mod_id.is_empty():
		return char_data.character_name
	return "[%s] %s" % [mod_id, char_data.character_name]


## Show the popup, optionally pre-selecting a character
func show_popup(preselect_character_uid: String = "") -> void:
	_refresh_characters()

	# Rebuild character list
	character_picker.clear()
	character_picker.add_item("(Custom Speaker)", 0)
	for i: int in range(_characters.size()):
		var char_data: CharacterData = _characters[i] as CharacterData
		if char_data:
			var display_name: String = _get_character_display_name_with_mod(char_data)
			character_picker.add_item(display_name, i + 1)

	# Preselect if provided
	if not preselect_character_uid.is_empty():
		for i: int in range(_characters.size()):
			var char_data: CharacterData = _characters[i] as CharacterData
			if char_data and char_data.character_uid == preselect_character_uid:
				character_picker.selected = i + 1
				_on_character_selected(i + 1)
				break
	else:
		character_picker.selected = 0
		portrait_preview.texture = null

	# Reset other fields
	emotion_picker.selected = 0
	text_edit.text = ""
	_update_preview()

	popup_centered()
