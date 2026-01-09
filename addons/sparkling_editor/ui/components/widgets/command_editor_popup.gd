@tool
class_name CommandEditorPopup
extends Window

## Popup window for editing a single command using the widget system
## Used for editing nested commands in command_array widgets
##
## Usage:
##   var popup: CommandEditorPopup = CommandEditorPopup.new()
##   popup.set_context(context.with_incremented_depth())
##   popup.set_command(command_dict)
##   popup.command_changed.connect(_on_command_updated)
##   add_child(popup)
##   popup.popup_centered()

signal command_changed(command: Dictionary)

var _context: EditorWidgetContext
var _command: Dictionary = {}
var _param_widgets: Dictionary = {}  # param_name -> EditorWidgetBase

# UI elements
var _scroll_container: ScrollContainer
var _main_vbox: VBoxContainer
var _type_picker: OptionButton
var _target_row: HBoxContainer
var _target_edit: LineEdit  # For commands with has_target
var _params_container: VBoxContainer
var _done_btn: Button

# Command type metadata cache
var _definitions: Dictionary = {}
var _type_list: Array[String] = []  # Ordered list of command types


func _init() -> void:
	title = "Edit Command"
	size = Vector2i(450, 500)
	transient = true
	exclusive = true
	wrap_controls = true
	
	# Connect close request to emit changes
	close_requested.connect(_on_close_requested)


func _ready() -> void:
	_load_definitions()
	_build_ui()
	_populate_type_picker()
	_refresh_from_command()


## Set the context for this popup (should be incremented depth)
func set_context(context: EditorWidgetContext) -> void:
	_context = context


## Set the command to edit
func set_command(command: Dictionary) -> void:
	_command = command.duplicate(true)
	if is_inside_tree():
		_refresh_from_command()


## Load command definitions from CinematicCommandDefs
func _load_definitions() -> void:
	_definitions = CinematicCommandDefs.get_merged_definitions()
	
	# Build ordered type list from categories
	var categories: Dictionary = CinematicCommandDefs.build_categories(_definitions)
	_type_list.clear()
	for category: String in categories:
		var cmd_types: Array = categories[category]
		for cmd_type: Variant in cmd_types:
			_type_list.append(str(cmd_type))


## Build the popup UI
func _build_ui() -> void:
	_main_vbox = VBoxContainer.new()
	_main_vbox.add_theme_constant_override("separation", 12)
	_main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main_vbox.offset_left = 12
	_main_vbox.offset_top = 12
	_main_vbox.offset_right = -12
	_main_vbox.offset_bottom = -12
	add_child(_main_vbox)
	
	# Type picker row
	_build_type_picker_row()
	
	# Target row (hidden by default, shown for has_target commands)
	_build_target_row()
	
	# Scrollable params area
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_main_vbox.add_child(_scroll_container)
	
	_params_container = VBoxContainer.new()
	_params_container.add_theme_constant_override("separation", 8)
	_params_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.add_child(_params_container)
	
	# Done button at bottom
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	_main_vbox.add_child(btn_row)
	
	_done_btn = Button.new()
	_done_btn.text = "Done"
	_done_btn.custom_minimum_size.x = 80
	_done_btn.pressed.connect(_on_done_pressed)
	btn_row.add_child(_done_btn)


## Build the command type picker row
func _build_type_picker_row() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_main_vbox.add_child(row)
	
	var label: Label = Label.new()
	label.text = "Command Type:"
	label.custom_minimum_size.x = 100
	row.add_child(label)
	
	_type_picker = OptionButton.new()
	_type_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_type_picker.item_selected.connect(_on_type_changed)
	row.add_child(_type_picker)


## Build the target entity row (for has_target commands)
func _build_target_row() -> void:
	_target_row = HBoxContainer.new()
	_target_row.add_theme_constant_override("separation", 8)
	_target_row.visible = false
	_main_vbox.add_child(_target_row)
	
	var label: Label = Label.new()
	label.text = "Target Entity:"
	label.custom_minimum_size.x = 100
	_target_row.add_child(label)
	
	_target_edit = LineEdit.new()
	_target_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_edit.placeholder_text = "Actor ID (e.g., player, npc_1)"
	_target_edit.text_changed.connect(_on_target_changed)
	_target_row.add_child(_target_edit)


## Populate the type picker dropdown
func _populate_type_picker() -> void:
	_type_picker.clear()
	
	var categories: Dictionary = CinematicCommandDefs.build_categories(_definitions)
	
	for category: String in categories:
		# Add category separator (disabled item)
		_type_picker.add_separator("-- %s --" % category)
		
		# Add commands in this category
		var cmd_types: Array = categories[category]
		for cmd_type: Variant in cmd_types:
			var cmd_str: String = str(cmd_type)
			_type_picker.add_item(cmd_str)
			# Use actual item count - 1 to get the index of the just-added item
			# This correctly accounts for separators taking up index slots
			var actual_idx: int = _type_picker.item_count - 1
			_type_picker.set_item_metadata(actual_idx, cmd_str)


## Refresh UI from current command data
func _refresh_from_command() -> void:
	if not _type_picker:
		return
	
	var cmd_type: String = _command.get("type", "")
	
	# Select the type in picker
	_select_type_in_picker(cmd_type)
	
	# Update target field
	_update_target_visibility(cmd_type)
	if "target" in _command:
		_target_edit.text = str(_command.get("target", ""))
	else:
		_target_edit.text = ""
	
	# Build params UI
	_build_params_ui()


## Select a command type in the picker by type string
func _select_type_in_picker(cmd_type: String) -> void:
	for i: int in range(_type_picker.item_count):
		if _type_picker.get_item_metadata(i) == cmd_type:
			_type_picker.select(i)
			return
	
	# Type not found - select first valid item
	for i: int in range(_type_picker.item_count):
		if not _type_picker.is_item_separator(i):
			_type_picker.select(i)
			return


## Update target row visibility based on command type
func _update_target_visibility(cmd_type: String) -> void:
	if not _target_row:
		return
	
	var has_target: bool = false
	if cmd_type in _definitions:
		var def: Dictionary = _definitions[cmd_type]
		has_target = def.get("has_target", false)
	
	_target_row.visible = has_target


## Build parameter widgets for current command type
func _build_params_ui() -> void:
	# Clear existing widgets
	for child: Node in _params_container.get_children():
		child.queue_free()
	_param_widgets.clear()
	
	var cmd_type: String = _command.get("type", "")
	if cmd_type.is_empty() or cmd_type not in _definitions:
		var no_params_label: Label = Label.new()
		no_params_label.text = "Select a command type"
		no_params_label.add_theme_color_override("font_color", SparklingEditorUtils.get_disabled_color())
		_params_container.add_child(no_params_label)
		return
	
	var def: Dictionary = _definitions[cmd_type]
	var params_def: Dictionary = def.get("params", {})
	var current_params: Dictionary = _command.get("params", {})
	
	if params_def.is_empty():
		var no_params_label: Label = Label.new()
		no_params_label.text = "This command has no parameters"
		no_params_label.add_theme_color_override("font_color", SparklingEditorUtils.get_disabled_color())
		_params_container.add_child(no_params_label)
		return
	
	# Add description if available
	if "description" in def:
		var desc_label: Label = Label.new()
		desc_label.text = def.get("description", "")
		desc_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_params_container.add_child(desc_label)
		
		var sep: HSeparator = HSeparator.new()
		_params_container.add_child(sep)
	
	# Create widget for each parameter
	for param_name: String in params_def:
		var param_def: Dictionary = params_def[param_name]
		var current_value: Variant = current_params.get(param_name, param_def.get("default", null))
		_create_param_row(param_name, param_def, current_value)


## Create a row for a single parameter
func _create_param_row(param_name: String, param_def: Dictionary, current_value: Variant) -> void:
	var param_type: String = param_def.get("type", "string")
	
	# Try to create widget from factory
	var widget: EditorWidgetBase = ParamWidgetFactory.create_widget(param_type, param_def, _context)
	
	if widget:
		# Special handling for command_array - set param name for accent color
		if widget is CommandArrayWidget:
			var cmd_array_widget: CommandArrayWidget = widget as CommandArrayWidget
			cmd_array_widget.set_param_name(param_name)
		
		# Create labeled row
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_params_container.add_child(row)
		
		var label: Label = Label.new()
		label.text = "%s:" % param_name.capitalize()
		label.custom_minimum_size.x = 100
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		if "hint" in param_def:
			label.tooltip_text = str(param_def.get("hint"))
		row.add_child(label)
		
		# Widget container (allows widget to expand)
		var widget_container: VBoxContainer = VBoxContainer.new()
		widget_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(widget_container)
		
		widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		widget.set_value(current_value)
		widget.value_changed.connect(_on_param_changed.bind(param_name))
		widget_container.add_child(widget)
		
		_param_widgets[param_name] = widget
	else:
		# Fallback to JSON TextEdit for unsupported types
		_create_json_fallback_row(param_name, param_def, current_value)


## Create a JSON fallback row for unsupported param types
func _create_json_fallback_row(param_name: String, param_def: Dictionary, current_value: Variant) -> void:
	var param_type: String = param_def.get("type", "unknown")
	
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_params_container.add_child(row)
	
	# Label with type info
	var label_row: HBoxContainer = HBoxContainer.new()
	row.add_child(label_row)
	
	var label: Label = Label.new()
	label.text = "%s (%s):" % [param_name.capitalize(), param_type]
	if "hint" in param_def:
		label.tooltip_text = str(param_def.get("hint"))
	label_row.add_child(label)
	
	var type_hint: Label = Label.new()
	type_hint.text = " (JSON)"
	type_hint.add_theme_color_override("font_color", SparklingEditorUtils.get_warning_color())
	label_row.add_child(type_hint)
	
	# JSON TextEdit
	var json_edit: TextEdit = TextEdit.new()
	json_edit.custom_minimum_size.y = 60
	json_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	json_edit.text = JSON.stringify(current_value, "  ")
	json_edit.text_changed.connect(_on_json_param_changed.bind(param_name, json_edit))
	row.add_child(json_edit)
	
	# Store reference for value retrieval
	_param_widgets[param_name] = json_edit


## Handle type picker change (matches main editor logic)
func _on_type_changed(index: int) -> void:
	var new_type: String = _type_picker.get_item_metadata(index)
	if new_type.is_empty():
		return
	
	var old_type: String = _command.get("type", "")
	if new_type == old_type:
		return
	
	# Update command type and reset params to defaults
	_command["type"] = new_type
	_command["params"] = {}
	
	# Populate default params and handle target field
	if new_type in _definitions:
		var def: Dictionary = _definitions[new_type]
		# Add or remove target field based on has_target
		if def.get("has_target", false):
			if "target" not in _command:
				_command["target"] = ""
		else:
			_command.erase("target")
		# Add default param values
		var params_def: Dictionary = def.get("params", {})
		for param_name: String in params_def:
			var param_def: Dictionary = params_def[param_name]
			_command["params"][param_name] = param_def.get("default", "")
	else:
		_command.erase("target")
	
	# Update target row visibility and text
	_update_target_visibility(new_type)
	_target_edit.text = _command.get("target", "")
	
	# Rebuild params UI
	_build_params_ui()


## Handle target field change
func _on_target_changed(new_text: String) -> void:
	if new_text.strip_edges().is_empty():
		_command.erase("target")
	else:
		_command["target"] = new_text.strip_edges()


## Handle parameter value change from widget
func _on_param_changed(new_value: Variant, param_name: String) -> void:
	if "params" not in _command:
		_command["params"] = {}
	_command["params"][param_name] = new_value


## Handle JSON parameter change
func _on_json_param_changed(param_name: String, json_edit: TextEdit) -> void:
	var json: JSON = JSON.new()
	var err: Error = json.parse(json_edit.text)
	if err == OK:
		if "params" not in _command:
			_command["params"] = {}
		_command["params"][param_name] = json.data


## Handle done button press
func _on_done_pressed() -> void:
	_emit_and_close()


## Handle window close request (X button)
func _on_close_requested() -> void:
	_emit_and_close()


## Emit command_changed and close the popup
func _emit_and_close() -> void:
	command_changed.emit(_command)
	queue_free()
