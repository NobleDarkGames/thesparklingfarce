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

# Character and NPC cache
var _characters: Array[Resource] = []
var _npcs: Array[Resource] = []


func _ready() -> void:
	title = "Quick Add Dialog Line"
	size = Vector2i(500, 400)
	exclusive = true
	transient = true

	_refresh_characters()
	_setup_ui()

	close_requested.connect(_on_cancel)


func _exit_tree() -> void:
	# Clean up signal connections
	if close_requested.is_connected(_on_cancel):
		close_requested.disconnect(_on_cancel)

	# Clean up internal control signals
	if character_picker and character_picker.item_selected.is_connected(_on_character_selected):
		character_picker.item_selected.disconnect(_on_character_selected)
	if emotion_picker and emotion_picker.item_selected.is_connected(_on_input_changed):
		emotion_picker.item_selected.disconnect(_on_input_changed)
	if text_edit and text_edit.text_changed.is_connected(_on_input_changed):
		text_edit.text_changed.disconnect(_on_input_changed)
	if copy_button and copy_button.pressed.is_connected(_on_copy):
		copy_button.pressed.disconnect(_on_copy)
	if cancel_button and cancel_button.pressed.is_connected(_on_cancel):
		cancel_button.pressed.disconnect(_on_cancel)

	# Clear resource caches
	_characters.clear()
	_npcs.clear()


func _refresh_characters() -> void:
	_characters.clear()
	_npcs.clear()
	if ModLoader and ModLoader.registry:
		_characters = ModLoader.registry.get_all_resources("character")
		_npcs = ModLoader.registry.get_all_resources("npc")


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
	character_picker.set_item_metadata(0, null)  # No character for custom speaker
	for i: int in range(_characters.size()):
		var char_data: CharacterData = _characters[i] as CharacterData
		if char_data:
			var display_name: String = SparklingEditorUtils.get_character_display_name(char_data)
			var item_idx: int = character_picker.item_count
			character_picker.add_item(display_name, i + 1)
			character_picker.set_item_metadata(item_idx, {"type": "character", "resource": char_data})
	# Add NPCs with [NPC] prefix
	for i: int in range(_npcs.size()):
		var npc_data: Resource = _npcs[i]
		if npc_data:
			var npc_name: String = str(npc_data.get("npc_name")) if "npc_name" in npc_data else "Unknown NPC"
			var display_name: String = "[NPC] " + npc_name
			var item_idx: int = character_picker.item_count
			character_picker.add_item(display_name)
			character_picker.set_item_metadata(item_idx, {"type": "npc", "resource": npc_data})
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
	result_preview.add_theme_color_override("font_color", SparklingEditorUtils.get_success_color())
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
	var metadata: Variant = character_picker.get_item_metadata(index)
	portrait_preview.texture = null

	if metadata is Dictionary:
		var resource: Resource = metadata.get("resource")
		var entity_type: String = metadata.get("type", "")
		if resource:
			if entity_type == "character":
				var char_data: CharacterData = resource as CharacterData
				if char_data and char_data.portrait:
					portrait_preview.texture = char_data.portrait
			elif entity_type == "npc":
				# NPCs may have a portrait property
				if "portrait" in resource:
					var portrait: Texture2D = resource.get("portrait") as Texture2D
					if portrait:
						portrait_preview.texture = portrait

	_update_preview()


func _on_input_changed() -> void:
	_update_preview()


func _update_preview() -> void:
	var json_dict: Dictionary = _build_command_dict()
	var json_text: String = JSON.stringify(json_dict, "  ")
	result_preview.text = json_text


func _build_command_dict() -> Dictionary:
	var params: Dictionary = {}

	# Character/NPC - use metadata instead of index arithmetic
	var selected_idx: int = character_picker.selected
	var metadata: Variant = character_picker.get_item_metadata(selected_idx)

	if metadata is Dictionary:
		var resource: Resource = metadata.get("resource")
		var entity_type: String = metadata.get("type", "")
		if resource:
			if entity_type == "character":
				# Use get() for safe property access in editor context
				var char_uid: String = ""
				if "character_uid" in resource:
					char_uid = str(resource.get("character_uid"))
				params["speaker"] = char_uid
			elif entity_type == "npc":
				# NPCs use "npc:" prefix
				var npc_uid: String = ""
				if "npc_uid" in resource:
					npc_uid = str(resource.get("npc_uid"))
				params["speaker"] = "npc:" + npc_uid
		else:
			# Custom speaker - user needs to fill in manually
			params["speaker"] = "REPLACE_WITH_SPEAKER_ID"
	else:
		# Custom speaker - user needs to fill in manually
		params["speaker"] = "REPLACE_WITH_SPEAKER_ID"

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


## Show the popup, optionally pre-selecting a character or NPC
func show_popup(preselect_speaker: String = "") -> void:
	_refresh_characters()

	# Rebuild character list with metadata
	character_picker.clear()
	character_picker.add_item("(Custom Speaker)", 0)
	character_picker.set_item_metadata(0, null)  # No character/NPC for custom speaker
	for i: int in range(_characters.size()):
		var char_res: Resource = _characters[i]
		if char_res:
			# Use get() for safe property access in editor context
			var display_name: String = SparklingEditorUtils.get_resource_display_name_with_mod(char_res, "character_name")
			var item_idx: int = character_picker.item_count
			character_picker.add_item(display_name, i + 1)
			character_picker.set_item_metadata(item_idx, {"type": "character", "resource": char_res})

	# Add NPCs with [NPC] prefix
	for i: int in range(_npcs.size()):
		var npc_res: Resource = _npcs[i]
		if npc_res:
			var npc_name: String = str(npc_res.get("npc_name")) if "npc_name" in npc_res else "Unknown NPC"
			var display_name: String = "[NPC] " + npc_name
			var item_idx: int = character_picker.item_count
			character_picker.add_item(display_name)
			character_picker.set_item_metadata(item_idx, {"type": "npc", "resource": npc_res})

	# Preselect if provided - search by metadata instead of index
	if not preselect_speaker.is_empty():
		var is_npc: bool = preselect_speaker.begins_with("npc:")
		var search_uid: String = preselect_speaker.trim_prefix("npc:") if is_npc else preselect_speaker

		for item_idx: int in range(character_picker.item_count):
			var metadata: Variant = character_picker.get_item_metadata(item_idx)
			if metadata is Dictionary:
				var resource: Resource = metadata.get("resource")
				var entity_type: String = metadata.get("type", "")
				if resource:
					var uid: String = ""
					if entity_type == "character" and not is_npc:
						if "character_uid" in resource:
							uid = str(resource.get("character_uid"))
					elif entity_type == "npc" and is_npc:
						if "npc_uid" in resource:
							uid = str(resource.get("npc_uid"))
					if uid == search_uid:
						character_picker.selected = item_idx
						_on_character_selected(item_idx)
						break
	else:
		character_picker.selected = 0
		portrait_preview.texture = null

	# Reset other fields
	emotion_picker.selected = 0
	text_edit.text = ""
	_update_preview()

	popup_centered()
