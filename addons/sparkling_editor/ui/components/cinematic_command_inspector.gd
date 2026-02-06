@tool
class_name CinematicCommandInspector
extends VBoxContainer

## Command Inspector component for Cinematic Editor
## Displays and edits parameters for a single cinematic command

signal param_changed(param_name: String, value: Variant)
signal target_changed(target: String)

## Label width for inspector fields
const INSPECTOR_LABEL_WIDTH: int = 130

# UI state
var _widget_context: EditorWidgetContext
var _actor_ids: Array[String] = []
var _command: Dictionary = {}
var _updating_ui: bool = false

# Field references
var inspector_fields: Dictionary = {}  # param_name -> Control
var target_field: OptionButton
var target_custom_edit: LineEdit


func _ready() -> void:
	add_theme_constant_override("separation", 8)


## Set the widget context for resource pickers
func set_context(context: EditorWidgetContext) -> void:
	_widget_context = context


## Set the available actor IDs for target dropdown
func set_actor_ids(actor_ids: Array[String]) -> void:
	_actor_ids = actor_ids


## Load and display a command's parameters
func load_command(command: Dictionary, command_color: Color = Color.WHITE) -> void:
	_command = command
	_clear()

	var cmd_type: String = command.get("type", "")
	var params: Dictionary = command.get("params", {})

	# Command type header
	var type_label: Label = Label.new()
	type_label.text = cmd_type.to_upper()
	type_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	type_label.add_theme_color_override("font_color", command_color)
	add_child(type_label)

	# Description (from merged definitions)
	var definitions: Dictionary = CinematicCommandDefs.get_merged_definitions()
	if cmd_type in definitions and "description" in definitions[cmd_type]:
		var cmd_def: Dictionary = definitions[cmd_type]
		var desc_label: Label = Label.new()
		desc_label.text = cmd_def.get("description", "")
		desc_label.add_theme_color_override("font_color", SparklingEditorUtils.get_disabled_color())
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(desc_label)

	var sep: HSeparator = HSeparator.new()
	add_child(sep)

	# Target field (if applicable)
	if "target" in command:
		_build_target_field(command.get("target", ""))

	# Build parameter fields based on definition
	if cmd_type in definitions and "params" in definitions[cmd_type]:
		var def: Dictionary = definitions[cmd_type]
		var def_params: Dictionary = def.get("params", {})
		for param_name: String in def_params.keys():
			var param_def: Dictionary = def_params[param_name]
			var current_value: Variant = params.get(param_name, param_def.get("default", ""))
			_create_param_field(param_name, param_def, current_value)
	else:
		# Unknown command type - show raw JSON
		var raw_label: Label = Label.new()
		raw_label.text = "Raw Parameters (unknown command type):"
		add_child(raw_label)

		var raw_edit: TextEdit = TextEdit.new()
		raw_edit.custom_minimum_size.y = 100
		raw_edit.text = JSON.stringify(params, "  ")
		add_child(raw_edit)


## Clear all inspector fields
func _clear() -> void:
	for child: Node in get_children():
		child.queue_free()
	inspector_fields.clear()
	target_field = null
	target_custom_edit = null


## Show placeholder when no command selected
func show_placeholder() -> void:
	_clear()
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(self)
	var placeholder: Label = form.add_help_text("Select a command to edit its parameters")
	placeholder.name = "Placeholder"


## Build the target field dropdown
func _build_target_field(current_target: String) -> void:
	var target_row: HBoxContainer = HBoxContainer.new()
	add_child(target_row)

	var target_label: Label = Label.new()
	target_label.text = "Target:"
	target_label.custom_minimum_size.x = INSPECTOR_LABEL_WIDTH
	target_row.add_child(target_label)

	target_field = OptionButton.new()
	target_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_field.add_item("(None)", 0)
	target_field.set_item_metadata(0, "")

	# Add "self" as built-in option (for ambient patrols)
	target_field.add_item("self (this NPC)", 1)
	target_field.set_item_metadata(1, "self")

	var selected_idx: int = 0
	var item_idx: int = 2

	# Check if current target is "self"
	if current_target == "self":
		selected_idx = 1

	# Add defined actors from this cinematic
	if not _actor_ids.is_empty():
		for actor_id: String in _actor_ids:
			target_field.add_item(actor_id, item_idx)
			target_field.set_item_metadata(item_idx, actor_id)
			if actor_id == current_target:
				selected_idx = item_idx
			item_idx += 1

	# Add "Custom..." option for scene NPCs
	target_field.add_item("Custom (scene NPC)...", item_idx)
	target_field.set_item_metadata(item_idx, "__custom__")
	var custom_idx: int = item_idx

	# Check if current target is a custom value (not in dropdown)
	var is_custom: bool = not current_target.is_empty() and current_target != "self" and current_target not in _actor_ids
	if is_custom:
		selected_idx = custom_idx

	target_field.select(selected_idx)
	target_field.item_selected.connect(_on_target_selected)
	target_row.add_child(target_field)

	# Custom entry field (for scene NPC ids)
	target_custom_edit = LineEdit.new()
	target_custom_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_custom_edit.placeholder_text = "Enter npc_id..."
	target_custom_edit.tooltip_text = "Enter the npc_id of a scene NPC to target"
	target_custom_edit.visible = is_custom
	if is_custom:
		target_custom_edit.text = current_target
	target_custom_edit.text_changed.connect(_on_target_custom_changed)
	target_row.add_child(target_custom_edit)

	# Help text for target field
	var target_help: Label = Label.new()
	target_help.text = "self = this NPC | Custom = scene NPC by npc_id"
	target_help.add_theme_font_size_override("font_size", 11)
	target_help.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	add_child(target_help)


## Create a parameter field based on its definition
func _create_param_field(param_name: String, param_def: Dictionary, current_value: Variant) -> void:
	var param_type: String = param_def.get("type", "string")

	# Try widget factory first
	var widget: EditorWidgetBase = ParamWidgetFactory.create_widget(param_type, param_def, _widget_context)

	if widget:
		# Special handling for command_array - set param name for accent color
		if widget is CommandArrayWidget:
			var cmd_widget: CommandArrayWidget = widget as CommandArrayWidget
			cmd_widget.set_param_name(param_name)

		# Command array gets full width, no label row
		if param_type == "command_array":
			widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			widget.set_value(current_value)
			widget.value_changed.connect(_on_widget_value_changed.bind(param_name))
			add_child(widget)
			inspector_fields[param_name] = widget
			return

		# Create row with label for other widget types
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		add_child(row)

		var label: Label = Label.new()
		label.text = param_name.replace("_", " ").capitalize() + ":"
		label.custom_minimum_size.x = INSPECTOR_LABEL_WIDTH
		label.tooltip_text = param_def.get("hint", "")
		row.add_child(label)

		# Set value and connect signal
		widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		widget.set_value(current_value)
		widget.value_changed.connect(_on_widget_value_changed.bind(param_name))
		row.add_child(widget)

		inspector_fields[param_name] = widget
		return

	# Fallback for unsupported types (path, variant, color, or unknown)
	_create_fallback_param_field(param_name, param_def, current_value)


## Fallback for param types not yet supported by the widget system
func _create_fallback_param_field(param_name: String, param_def: Dictionary, current_value: Variant) -> void:
	var param_type: String = param_def.get("type", "string")

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)

	var label: Label = Label.new()
	label.text = param_name.replace("_", " ").capitalize() + ":"
	label.custom_minimum_size.x = INSPECTOR_LABEL_WIDTH
	label.tooltip_text = param_def.get("hint", "")
	row.add_child(label)

	var control: Control

	match param_type:
		"color":
			var color_btn: ColorPickerButton = ColorPickerButton.new()
			color_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if current_value is Array and current_value.size() >= 3:
				color_btn.color = Color(current_value[0], current_value[1], current_value[2], current_value[3] if current_value.size() > 3 else 1.0)
			elif current_value is Color:
				color_btn.color = current_value
			else:
				color_btn.color = Color.BLACK
			color_btn.color_changed.connect(_on_color_changed.bind(param_name))
			control = color_btn

		"path":
			# Path is array of positions - show as editable text for now
			var path_edit: TextEdit = TextEdit.new()
			path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			path_edit.custom_minimum_size.y = 60
			if current_value is Array:
				path_edit.text = JSON.stringify(current_value)
			else:
				path_edit.text = "[]"
			path_edit.placeholder_text = "[[x1, y1], [x2, y2], ...]"
			path_edit.text_changed.connect(_on_path_changed.bind(param_name, path_edit))
			control = path_edit

		"variant":
			# Generic value - allow string/bool/number
			var var_edit: LineEdit = LineEdit.new()
			var_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var_edit.text = str(current_value) if current_value != null else ""
			var_edit.placeholder_text = "value (string, number, or true/false)"
			var_edit.text_changed.connect(_on_variant_changed.bind(param_name))
			control = var_edit

		_:  # Unknown types - JSON fallback
			var json_edit: TextEdit = TextEdit.new()
			json_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			json_edit.custom_minimum_size.y = 60
			json_edit.text = JSON.stringify(current_value, "  ") if current_value != null else ""
			json_edit.text_changed.connect(func() -> void:
				var parsed: Variant = JSON.parse_string(json_edit.text)
				if parsed != null:
					param_changed.emit(param_name, parsed)
			)
			control = json_edit

	row.add_child(control)
	inspector_fields[param_name] = control


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_widget_value_changed(new_value: Variant, param_name: String) -> void:
	if _updating_ui:
		return
	param_changed.emit(param_name, new_value)


func _on_target_selected(item_index: int) -> void:
	if _updating_ui:
		return

	var metadata: String = target_field.get_item_metadata(item_index)

	# Handle custom option - show LineEdit, don't update target yet
	if metadata == "__custom__":
		if target_custom_edit:
			target_custom_edit.visible = true
			target_custom_edit.grab_focus()
		return

	# Hide custom edit for non-custom selections
	if target_custom_edit:
		target_custom_edit.visible = false

	target_changed.emit(metadata)


func _on_target_custom_changed(new_text: String) -> void:
	if _updating_ui:
		return
	target_changed.emit(new_text.strip_edges())


func _on_color_changed(color: Color, param_name: String) -> void:
	param_changed.emit(param_name, [color.r, color.g, color.b, color.a])


func _on_path_changed(param_name: String, path_edit: TextEdit) -> void:
	var parsed: Variant = JSON.parse_string(path_edit.text)
	if parsed != null and parsed is Array:
		param_changed.emit(param_name, parsed)


func _on_variant_changed(new_text: String, param_name: String) -> void:
	# Try to parse as bool/number first
	var value: Variant = new_text
	if new_text.to_lower() == "true":
		value = true
	elif new_text.to_lower() == "false":
		value = false
	elif new_text.is_valid_float():
		value = new_text.to_float()
	elif new_text.is_valid_int():
		value = new_text.to_int()
	param_changed.emit(param_name, value)
