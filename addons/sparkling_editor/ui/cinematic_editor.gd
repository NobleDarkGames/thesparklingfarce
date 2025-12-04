@tool
extends Control

## CinematicData Editor
## Visual editor for cinematic sequence JSON files
## Supports all command types with per-command parameter editing

# Command types matching CinematicData.CommandType enum
const COMMAND_TYPES: Array[String] = [
	"move_entity",
	"set_facing",
	"play_animation",
	"show_dialog",
	"dialog_line",
	"camera_move",
	"camera_follow",
	"camera_shake",
	"wait",
	"fade_screen",
	"play_sound",
	"play_music",
	"spawn_entity",
	"despawn_entity",
	"trigger_battle",
	"change_scene",
	"set_variable",
	"conditional",
	"parallel"
]

# UI Components - Main layout
var cinematic_list: ItemList
var detail_scroll: ScrollContainer
var detail_panel: VBoxContainer
var save_button: Button
var create_button: Button

# Current state
var current_cinematic_path: String = ""
var current_cinematic_data: Dictionary = {}

# Error panel
var error_panel: PanelContainer
var error_label: RichTextLabel

# Metadata section
var cinematic_id_edit: LineEdit
var cinematic_name_edit: LineEdit
var description_edit: TextEdit
var can_skip_check: CheckBox
var disable_input_check: CheckBox
var fade_in_spin: SpinBox
var fade_out_spin: SpinBox

# Commands section
var commands_list: ItemList
var command_type_option: OptionButton
var add_command_button: Button
var remove_command_button: Button
var move_up_button: Button
var move_down_button: Button
var duplicate_button: Button

# Command inspector
var command_inspector: VBoxContainer
var current_command_index: int = -1


func _ready() -> void:
	_setup_ui()
	_refresh_cinematic_list()


func _setup_ui() -> void:
	var main_split: HSplitContainer = HSplitContainer.new()
	main_split.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_split)

	# Left panel - Cinematic list
	var left_panel: VBoxContainer = VBoxContainer.new()
	left_panel.custom_minimum_size.x = 250
	main_split.add_child(left_panel)

	var list_label: Label = Label.new()
	list_label.text = "Cinematics"
	list_label.add_theme_font_size_override("font_size", 16)
	left_panel.add_child(list_label)

	cinematic_list = ItemList.new()
	cinematic_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cinematic_list.item_selected.connect(_on_cinematic_selected)
	left_panel.add_child(cinematic_list)

	var btn_row: HBoxContainer = HBoxContainer.new()
	left_panel.add_child(btn_row)

	create_button = Button.new()
	create_button.text = "New"
	create_button.pressed.connect(_on_create_new)
	btn_row.add_child(create_button)

	var refresh_btn: Button = Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_refresh_cinematic_list)
	btn_row.add_child(refresh_btn)

	# Right panel - Detail form
	detail_scroll = ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_split.add_child(detail_scroll)

	detail_panel = VBoxContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(detail_panel)

	_setup_error_panel()
	_setup_metadata_section()
	_setup_commands_section()
	_setup_command_inspector()
	_setup_save_button()


func _setup_error_panel() -> void:
	error_panel = PanelContainer.new()
	error_panel.visible = false

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.1, 0.1, 0.9)
	style.border_color = Color(0.8, 0.2, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	error_panel.add_theme_stylebox_override("panel", style)

	error_label = RichTextLabel.new()
	error_label.bbcode_enabled = true
	error_label.fit_content = true
	error_label.scroll_active = false
	error_panel.add_child(error_label)

	detail_panel.add_child(error_panel)


func _setup_metadata_section() -> void:
	var section: VBoxContainer = _create_section("Cinematic Info")

	var id_row: HBoxContainer = _create_field_row("ID:", 120)
	cinematic_id_edit = LineEdit.new()
	cinematic_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cinematic_id_edit.placeholder_text = "unique_cinematic_id"
	id_row.add_child(cinematic_id_edit)
	section.add_child(id_row)

	var name_row: HBoxContainer = _create_field_row("Name:", 120)
	cinematic_name_edit = LineEdit.new()
	cinematic_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(cinematic_name_edit)
	section.add_child(name_row)

	var desc_label: Label = Label.new()
	desc_label.text = "Description:"
	section.add_child(desc_label)

	description_edit = TextEdit.new()
	description_edit.custom_minimum_size.y = 60
	description_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(description_edit)

	var checks_row: HBoxContainer = HBoxContainer.new()
	checks_row.add_theme_constant_override("separation", 20)

	can_skip_check = CheckBox.new()
	can_skip_check.text = "Can Skip"
	can_skip_check.button_pressed = true
	checks_row.add_child(can_skip_check)

	disable_input_check = CheckBox.new()
	disable_input_check.text = "Disable Player Input"
	disable_input_check.button_pressed = true
	checks_row.add_child(disable_input_check)

	section.add_child(checks_row)

	var fade_row: HBoxContainer = HBoxContainer.new()
	fade_row.add_theme_constant_override("separation", 15)

	var fade_in_label: Label = Label.new()
	fade_in_label.text = "Fade In:"
	fade_row.add_child(fade_in_label)

	fade_in_spin = SpinBox.new()
	fade_in_spin.min_value = 0.0
	fade_in_spin.max_value = 5.0
	fade_in_spin.step = 0.1
	fade_in_spin.value = 0.5
	fade_row.add_child(fade_in_spin)

	var fade_out_label: Label = Label.new()
	fade_out_label.text = "Fade Out:"
	fade_row.add_child(fade_out_label)

	fade_out_spin = SpinBox.new()
	fade_out_spin.min_value = 0.0
	fade_out_spin.max_value = 5.0
	fade_out_spin.step = 0.1
	fade_out_spin.value = 0.5
	fade_row.add_child(fade_out_spin)

	section.add_child(fade_row)

	detail_panel.add_child(section)


func _setup_commands_section() -> void:
	var section: VBoxContainer = _create_section("Commands")

	# Command list
	commands_list = ItemList.new()
	commands_list.custom_minimum_size.y = 150
	commands_list.item_selected.connect(_on_command_selected)
	section.add_child(commands_list)

	# Command buttons row 1
	var btn_row1: HBoxContainer = HBoxContainer.new()

	command_type_option = OptionButton.new()
	for cmd_type: String in COMMAND_TYPES:
		command_type_option.add_item(cmd_type)
	command_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row1.add_child(command_type_option)

	add_command_button = Button.new()
	add_command_button.text = "Add"
	add_command_button.pressed.connect(_on_add_command)
	btn_row1.add_child(add_command_button)

	section.add_child(btn_row1)

	# Command buttons row 2
	var btn_row2: HBoxContainer = HBoxContainer.new()

	move_up_button = Button.new()
	move_up_button.text = "Up"
	move_up_button.pressed.connect(_on_move_command_up)
	btn_row2.add_child(move_up_button)

	move_down_button = Button.new()
	move_down_button.text = "Down"
	move_down_button.pressed.connect(_on_move_command_down)
	btn_row2.add_child(move_down_button)

	duplicate_button = Button.new()
	duplicate_button.text = "Duplicate"
	duplicate_button.pressed.connect(_on_duplicate_command)
	btn_row2.add_child(duplicate_button)

	remove_command_button = Button.new()
	remove_command_button.text = "Remove"
	remove_command_button.pressed.connect(_on_remove_command)
	btn_row2.add_child(remove_command_button)

	section.add_child(btn_row2)

	detail_panel.add_child(section)


func _setup_command_inspector() -> void:
	var section: VBoxContainer = _create_section("Command Inspector")

	command_inspector = VBoxContainer.new()
	command_inspector.add_theme_constant_override("separation", 8)
	section.add_child(command_inspector)

	var placeholder: Label = Label.new()
	placeholder.text = "(Select a command to edit its parameters)"
	placeholder.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	command_inspector.add_child(placeholder)

	detail_panel.add_child(section)


func _setup_save_button() -> void:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size.y = 20
	detail_panel.add_child(spacer)

	save_button = Button.new()
	save_button.text = "Save Cinematic"
	save_button.pressed.connect(_on_save)
	detail_panel.add_child(save_button)


func _create_section(title: String) -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)

	var header: Label = Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 14)
	section.add_child(header)

	var sep: HSeparator = HSeparator.new()
	section.add_child(sep)

	return section


func _create_field_row(label_text: String, label_width: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = label_width
	row.add_child(label)

	return row


func _refresh_cinematic_list() -> void:
	cinematic_list.clear()

	var mods_dir: DirAccess = DirAccess.open("res://mods/")
	if not mods_dir:
		return

	mods_dir.list_dir_begin()
	var mod_name: String = mods_dir.get_next()

	while mod_name != "":
		if mods_dir.current_is_dir() and not mod_name.begins_with("."):
			var cin_path: String = "res://mods/%s/data/cinematics/" % mod_name
			var cin_dir: DirAccess = DirAccess.open(cin_path)

			if cin_dir:
				cin_dir.list_dir_begin()
				var file_name: String = cin_dir.get_next()

				while file_name != "":
					if file_name.ends_with(".json"):
						var display: String = "[%s] %s" % [mod_name, file_name.get_basename()]
						var full_path: String = cin_path + file_name
						cinematic_list.add_item(display)
						cinematic_list.set_item_metadata(cinematic_list.item_count - 1, full_path)
					file_name = cin_dir.get_next()

				cin_dir.list_dir_end()

		mod_name = mods_dir.get_next()

	mods_dir.list_dir_end()


func _on_cinematic_selected(index: int) -> void:
	var path: String = cinematic_list.get_item_metadata(index)
	_load_cinematic(path)


func _load_cinematic(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		_show_errors(["Failed to open: " + path])
		return

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var err: Error = json.parse(json_text)
	if err != OK:
		_show_errors(["JSON parse error: " + json.get_error_message()])
		return

	current_cinematic_path = path
	current_cinematic_data = json.data
	_populate_form()
	_hide_errors()


func _populate_form() -> void:
	cinematic_id_edit.text = current_cinematic_data.get("cinematic_id", "")
	cinematic_name_edit.text = current_cinematic_data.get("cinematic_name", "")
	description_edit.text = current_cinematic_data.get("description", "")
	can_skip_check.button_pressed = current_cinematic_data.get("can_skip", true)
	disable_input_check.button_pressed = current_cinematic_data.get("disable_player_input", true)
	fade_in_spin.value = current_cinematic_data.get("fade_in_duration", 0.5)
	fade_out_spin.value = current_cinematic_data.get("fade_out_duration", 0.5)

	_populate_commands_list()
	current_command_index = -1
	_clear_command_inspector()


func _populate_commands_list() -> void:
	commands_list.clear()
	var commands: Array = current_cinematic_data.get("commands", [])

	for i in range(commands.size()):
		var cmd: Dictionary = commands[i]
		var cmd_type: String = cmd.get("type", "unknown")
		var target: String = cmd.get("target", "")
		var display: String = "%d. %s" % [i + 1, cmd_type]
		if not target.is_empty():
			display += " [%s]" % target
		commands_list.add_item(display)
		commands_list.set_item_metadata(commands_list.item_count - 1, i)


func _on_command_selected(index: int) -> void:
	current_command_index = commands_list.get_item_metadata(index)
	_populate_command_inspector()


func _clear_command_inspector() -> void:
	for child in command_inspector.get_children():
		child.queue_free()

	var placeholder: Label = Label.new()
	placeholder.text = "(Select a command to edit)"
	placeholder.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	command_inspector.add_child(placeholder)


func _populate_command_inspector() -> void:
	for child in command_inspector.get_children():
		child.queue_free()

	var commands: Array = current_cinematic_data.get("commands", [])
	if current_command_index < 0 or current_command_index >= commands.size():
		_clear_command_inspector()
		return

	var cmd: Dictionary = commands[current_command_index]
	var cmd_type: String = cmd.get("type", "")
	var params: Dictionary = cmd.get("params", {})

	# Type label
	var type_label: Label = Label.new()
	type_label.text = "Type: " + cmd_type
	type_label.add_theme_font_size_override("font_size", 13)
	command_inspector.add_child(type_label)

	# Target (if applicable)
	if "target" in cmd:
		var target_row: HBoxContainer = _create_field_row("Target:", 80)
		var target_edit: LineEdit = LineEdit.new()
		target_edit.text = cmd.get("target", "")
		target_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		target_edit.text_changed.connect(_on_command_target_changed)
		target_row.add_child(target_edit)
		command_inspector.add_child(target_row)

	# Build params UI based on command type
	match cmd_type:
		"move_entity":
			_add_param_field("path", params, "Array of [x,y] points")
			_add_param_spin("speed", params, 0.1, 10.0, 0.1, 3.0)
			_add_param_check("wait", params, true)

		"set_facing":
			_add_param_option("direction", params, ["down", "up", "left", "right"])

		"play_animation":
			_add_param_field("animation", params, "Animation name")
			_add_param_check("wait", params, true)

		"show_dialog":
			_add_param_field("dialogue_id", params, "DialogueData ID")

		"dialog_line":
			_add_param_field("character_id", params, "Character ID")
			_add_param_field("text", params, "Dialog text", true)
			_add_param_option("emotion", params, ["neutral", "happy", "sad", "angry", "worried", "surprised"])

		"camera_move":
			_add_param_vector2("target_pos", params)
			_add_param_spin("speed", params, 0.1, 10.0, 0.1, 2.0)
			_add_param_check("wait", params, true)

		"camera_follow":
			pass  # Only needs target

		"camera_shake":
			_add_param_spin("intensity", params, 1.0, 20.0, 0.5, 6.0)
			_add_param_spin("duration", params, 0.1, 5.0, 0.1, 0.5)
			_add_param_spin("frequency", params, 5.0, 60.0, 1.0, 30.0)
			_add_param_check("wait", params, false)

		"wait":
			_add_param_spin("duration", params, 0.1, 30.0, 0.1, 1.0)

		"fade_screen":
			_add_param_option("fade_type", params, ["in", "out"])
			_add_param_spin("duration", params, 0.1, 5.0, 0.1, 1.0)

		"play_sound":
			_add_param_field("sound_id", params, "Sound effect ID")

		"play_music":
			_add_param_field("music_id", params, "Music track ID")
			_add_param_check("fade", params, true)

		"spawn_entity":
			_add_param_field("actor_id", params, "Entity ID to spawn")
			_add_param_vector2("position", params)
			_add_param_option("facing", params, ["down", "up", "left", "right"])

		"despawn_entity":
			pass  # Only needs target

		"trigger_battle":
			_add_param_field("battle_id", params, "BattleData ID")

		"change_scene":
			_add_param_field("scene_path", params, "Scene path")
			_add_param_field("spawn_id", params, "Spawn point ID")

		"set_variable":
			_add_param_field("variable", params, "Variable name")
			_add_param_field("value", params, "Value")

		"conditional":
			_add_param_field("condition", params, "Condition expression")
			_add_json_param_field("true_branch", params, "Commands if true (JSON array)")
			_add_json_param_field("false_branch", params, "Commands if false (JSON array)")

		"parallel":
			_add_json_param_field("commands", params, "Parallel commands (JSON array)")


func _add_param_field(param_name: String, params: Dictionary, placeholder: String, multiline: bool = false) -> void:
	var row: HBoxContainer = _create_field_row(param_name + ":", 100)

	if multiline:
		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var edit: TextEdit = TextEdit.new()
		edit.text = str(params.get(param_name, ""))
		edit.custom_minimum_size.y = 60
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.placeholder_text = placeholder
		edit.text_changed.connect(_on_param_text_changed.bind(param_name, edit))
		vbox.add_child(edit)

		row.add_child(vbox)
	else:
		var edit: LineEdit = LineEdit.new()
		var value: Variant = params.get(param_name, "")
		edit.text = str(value) if value != null else ""
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.placeholder_text = placeholder
		edit.text_changed.connect(_on_param_changed.bind(param_name))
		row.add_child(edit)

	command_inspector.add_child(row)


func _add_param_spin(param_name: String, params: Dictionary, min_val: float, max_val: float, step: float, default: float) -> void:
	var row: HBoxContainer = _create_field_row(param_name + ":", 100)

	var spin: SpinBox = SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = step
	spin.value = params.get(param_name, default)
	spin.value_changed.connect(_on_param_spin_changed.bind(param_name))
	row.add_child(spin)

	command_inspector.add_child(row)


func _add_param_check(param_name: String, params: Dictionary, default: bool) -> void:
	var check: CheckBox = CheckBox.new()
	check.text = param_name
	check.button_pressed = params.get(param_name, default)
	check.toggled.connect(_on_param_check_changed.bind(param_name))
	command_inspector.add_child(check)


func _add_param_option(param_name: String, params: Dictionary, options: Array) -> void:
	var row: HBoxContainer = _create_field_row(param_name + ":", 100)

	var option: OptionButton = OptionButton.new()
	for opt in options:
		option.add_item(str(opt))

	var current: String = str(params.get(param_name, options[0]))
	for i in range(options.size()):
		if str(options[i]) == current:
			option.select(i)
			break

	option.item_selected.connect(_on_param_option_changed.bind(param_name, options))
	row.add_child(option)

	command_inspector.add_child(row)


func _add_param_vector2(param_name: String, params: Dictionary) -> void:
	var row: HBoxContainer = _create_field_row(param_name + ":", 100)

	var current: Variant = params.get(param_name, [0, 0])
	var x_val: float = 0.0
	var y_val: float = 0.0

	if current is Array and current.size() >= 2:
		x_val = current[0]
		y_val = current[1]
	elif current is Dictionary:
		x_val = current.get("x", 0)
		y_val = current.get("y", 0)

	var x_label: Label = Label.new()
	x_label.text = "X:"
	row.add_child(x_label)

	var x_spin: SpinBox = SpinBox.new()
	x_spin.min_value = -9999
	x_spin.max_value = 9999
	x_spin.value = x_val
	x_spin.value_changed.connect(_on_param_vector_changed.bind(param_name, "x"))
	row.add_child(x_spin)

	var y_label: Label = Label.new()
	y_label.text = "Y:"
	row.add_child(y_label)

	var y_spin: SpinBox = SpinBox.new()
	y_spin.min_value = -9999
	y_spin.max_value = 9999
	y_spin.value = y_val
	y_spin.value_changed.connect(_on_param_vector_changed.bind(param_name, "y"))
	row.add_child(y_spin)

	command_inspector.add_child(row)


## Add a JSON-validated text field for nested command arrays
func _add_json_param_field(param_name: String, params: Dictionary, placeholder: String) -> void:
	var container: VBoxContainer = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	var row: HBoxContainer = _create_field_row(param_name + ":", 100)
	container.add_child(row)

	var edit: TextEdit = TextEdit.new()
	edit.custom_minimum_size.y = 60
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.placeholder_text = placeholder

	# Convert current value to JSON string for display
	var current: Variant = params.get(param_name, [])
	if current is Array or current is Dictionary:
		edit.text = JSON.stringify(current, "\t")
	elif current is String:
		edit.text = current
	else:
		edit.text = "[]"

	row.add_child(edit)

	# Validation label (shows error or success)
	var validation_label: Label = Label.new()
	validation_label.add_theme_font_size_override("font_size", 10)
	validation_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	validation_label.text = ""
	container.add_child(validation_label)

	# Validate on text change
	edit.text_changed.connect(_on_json_param_changed.bind(param_name, edit, validation_label))

	# Initial validation
	_validate_json_field(edit, validation_label)

	command_inspector.add_child(container)


## Called when a JSON param field changes
func _on_json_param_changed(param_name: String, edit: TextEdit, validation_label: Label) -> void:
	var is_valid: bool = _validate_json_field(edit, validation_label)

	if is_valid:
		var json_text: String = edit.text.strip_edges()
		if json_text.is_empty():
			_set_current_param(param_name, [])
		else:
			var json: JSON = JSON.new()
			if json.parse(json_text) == OK:
				_set_current_param(param_name, json.data)


## Validate a JSON field and update the validation label
## Returns true if valid
func _validate_json_field(edit: TextEdit, validation_label: Label) -> bool:
	var json_text: String = edit.text.strip_edges()

	if json_text.is_empty():
		validation_label.text = "(empty = no commands)"
		validation_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		return true

	var json: JSON = JSON.new()
	var err: Error = json.parse(json_text)

	if err != OK:
		validation_label.text = "Invalid JSON: " + json.get_error_message()
		validation_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
		return false

	if not (json.data is Array):
		validation_label.text = "Must be a JSON array []"
		validation_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))
		return false

	var count: int = json.data.size()
	validation_label.text = "Valid JSON (%d command%s)" % [count, "s" if count != 1 else ""]
	validation_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	return true


func _on_command_target_changed(new_text: String) -> void:
	var commands: Array = current_cinematic_data.get("commands", [])
	if current_command_index >= 0 and current_command_index < commands.size():
		commands[current_command_index]["target"] = new_text
		_populate_commands_list()
		commands_list.select(current_command_index)


func _on_param_changed(new_text: String, param_name: String) -> void:
	_set_current_param(param_name, new_text)


func _on_param_text_changed(param_name: String, edit: TextEdit) -> void:
	_set_current_param(param_name, edit.text)


func _on_param_spin_changed(value: float, param_name: String) -> void:
	_set_current_param(param_name, value)


func _on_param_check_changed(pressed: bool, param_name: String) -> void:
	_set_current_param(param_name, pressed)


func _on_param_option_changed(index: int, param_name: String, options: Array) -> void:
	_set_current_param(param_name, options[index])


func _on_param_vector_changed(value: float, param_name: String, component: String) -> void:
	var commands: Array = current_cinematic_data.get("commands", [])
	if current_command_index < 0 or current_command_index >= commands.size():
		return

	var params: Dictionary = commands[current_command_index].get("params", {})
	var current: Variant = params.get(param_name, [0, 0])

	var vec: Array = [0, 0]
	if current is Array and current.size() >= 2:
		vec = [current[0], current[1]]

	if component == "x":
		vec[0] = value
	else:
		vec[1] = value

	params[param_name] = vec
	commands[current_command_index]["params"] = params


func _set_current_param(param_name: String, value: Variant) -> void:
	var commands: Array = current_cinematic_data.get("commands", [])
	if current_command_index < 0 or current_command_index >= commands.size():
		return

	if "params" not in commands[current_command_index]:
		commands[current_command_index]["params"] = {}

	commands[current_command_index]["params"][param_name] = value


func _on_add_command() -> void:
	var cmd_type: String = COMMAND_TYPES[command_type_option.selected]

	var new_cmd: Dictionary = {
		"type": cmd_type,
		"params": {}
	}

	# Add target for commands that need it
	if cmd_type in ["move_entity", "set_facing", "play_animation", "camera_follow", "despawn_entity"]:
		new_cmd["target"] = ""

	# Add default params
	match cmd_type:
		"move_entity":
			new_cmd["params"] = {"path": [[0, 0]], "speed": 3.0, "wait": true}
		"set_facing":
			new_cmd["params"] = {"direction": "down"}
		"wait":
			new_cmd["params"] = {"duration": 1.0}
		"fade_screen":
			new_cmd["params"] = {"fade_type": "in", "duration": 1.0}
		"camera_shake":
			new_cmd["params"] = {"intensity": 6.0, "duration": 0.5, "frequency": 30.0}
		"dialog_line":
			new_cmd["params"] = {"character_id": "", "text": "", "emotion": "neutral"}

	if "commands" not in current_cinematic_data:
		current_cinematic_data["commands"] = []

	current_cinematic_data["commands"].append(new_cmd)
	_populate_commands_list()

	# Select the new command
	var new_index: int = current_cinematic_data["commands"].size() - 1
	commands_list.select(new_index)
	_on_command_selected(new_index)


func _on_remove_command() -> void:
	var commands: Array = current_cinematic_data.get("commands", [])
	if current_command_index >= 0 and current_command_index < commands.size():
		commands.remove_at(current_command_index)
		current_cinematic_data["commands"] = commands
		_populate_commands_list()
		current_command_index = -1
		_clear_command_inspector()


func _on_move_command_up() -> void:
	var commands: Array = current_cinematic_data.get("commands", [])
	if current_command_index > 0 and current_command_index < commands.size():
		var temp: Dictionary = commands[current_command_index]
		commands[current_command_index] = commands[current_command_index - 1]
		commands[current_command_index - 1] = temp
		current_cinematic_data["commands"] = commands
		current_command_index -= 1
		_populate_commands_list()
		commands_list.select(current_command_index)


func _on_move_command_down() -> void:
	var commands: Array = current_cinematic_data.get("commands", [])
	if current_command_index >= 0 and current_command_index < commands.size() - 1:
		var temp: Dictionary = commands[current_command_index]
		commands[current_command_index] = commands[current_command_index + 1]
		commands[current_command_index + 1] = temp
		current_cinematic_data["commands"] = commands
		current_command_index += 1
		_populate_commands_list()
		commands_list.select(current_command_index)


func _on_duplicate_command() -> void:
	var commands: Array = current_cinematic_data.get("commands", [])
	if current_command_index >= 0 and current_command_index < commands.size():
		var copy: Dictionary = commands[current_command_index].duplicate(true)
		commands.insert(current_command_index + 1, copy)
		current_cinematic_data["commands"] = commands
		_populate_commands_list()
		commands_list.select(current_command_index + 1)
		_on_command_selected(current_command_index + 1)


func _on_create_new() -> void:
	if not ModLoader:
		_show_errors(["ModLoader not available"])
		return

	var active_mod: ModManifest = ModLoader.get_active_mod()
	if not active_mod:
		_show_errors(["No active mod selected"])
		return

	current_cinematic_data = {
		"cinematic_id": "new_cinematic",
		"cinematic_name": "New Cinematic",
		"description": "",
		"can_skip": true,
		"disable_player_input": true,
		"commands": []
	}

	var cin_dir: String = "res://mods/%s/data/cinematics/" % active_mod.mod_id
	var dir: DirAccess = DirAccess.open("res://mods/%s/data/" % active_mod.mod_id)
	if dir and not dir.dir_exists("cinematics"):
		dir.make_dir("cinematics")

	current_cinematic_path = cin_dir + "new_cinematic.json"
	_populate_form()
	_hide_errors()


func _on_save() -> void:
	if current_cinematic_path.is_empty():
		_show_errors(["No cinematic loaded"])
		return

	_collect_data_from_ui()

	var errors: Array[String] = _validate()
	if errors.size() > 0:
		_show_errors(errors)
		return

	var json_text: String = JSON.stringify(current_cinematic_data, "\t")
	var file: FileAccess = FileAccess.open(current_cinematic_path, FileAccess.WRITE)
	if not file:
		_show_errors(["Failed to write: " + current_cinematic_path])
		return

	file.store_string(json_text)
	file.close()

	_hide_errors()
	_refresh_cinematic_list()

	# Notify that a cinematic was saved (not mods_reloaded - that's for mod manifest changes)
	var event_bus: Node = get_node_or_null("/root/EditorEventBus")
	if event_bus:
		var cinematic_id: String = current_cinematic_data.get("cinematic_id", "")
		event_bus.resource_saved.emit("cinematic", cinematic_id, null)


func _collect_data_from_ui() -> void:
	current_cinematic_data["cinematic_id"] = cinematic_id_edit.text.strip_edges()
	current_cinematic_data["cinematic_name"] = cinematic_name_edit.text.strip_edges()
	current_cinematic_data["description"] = description_edit.text
	current_cinematic_data["can_skip"] = can_skip_check.button_pressed
	current_cinematic_data["disable_player_input"] = disable_input_check.button_pressed
	current_cinematic_data["fade_in_duration"] = fade_in_spin.value
	current_cinematic_data["fade_out_duration"] = fade_out_spin.value


func _validate() -> Array[String]:
	var errors: Array[String] = []

	if current_cinematic_data.get("cinematic_id", "").is_empty():
		errors.append("Cinematic ID is required")

	return errors


func _show_errors(errors: Array[String]) -> void:
	error_label.text = "[color=white]" + "\n".join(errors) + "[/color]"
	error_panel.visible = true


func _hide_errors() -> void:
	error_panel.visible = false
