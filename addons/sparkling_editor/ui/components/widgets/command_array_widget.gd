@tool
class_name CommandArrayWidget
extends EditorWidgetBase

## Collapsible editor for an array of commands
## Supports recursive embedding with depth limiting
##
## When depth limit is reached, falls back to JSON editing.
##
## Usage:
##   var widget: CommandArrayWidget = CommandArrayWidget.new()
##   widget.set_param_name("if_true")  # For accent color
##   widget.set_context(context)
##   widget.set_value([{"type": "dialog_line", "params": {...}}])
##   widget.command_edit_requested.connect(_on_edit_nested_command)
##   add_child(widget)

signal command_edit_requested(index: int, command: Dictionary)

const MAX_DEPTH: int = 3

## Accent colors based on param name
const ACCENT_COLORS: Dictionary = {
	"if_true": Color(0.29, 0.49, 0.29),   # Green
	"if_false": Color(0.49, 0.29, 0.29),  # Red
}
const DEFAULT_ACCENT: Color = Color(0.35, 0.35, 0.45)

var _commands: Array = []
var _param_name: String = ""  # For accent color selection
var _command_rows: Array[CommandRowWidget] = []
var _header_btn: Button
var _content_panel: PanelContainer
var _rows_container: VBoxContainer
var _add_menu_btn: MenuButton
var _is_expanded: bool = true

# JSON fallback widgets (used when at depth limit)
var _json_edit: TextEdit
var _is_json_mode: bool = false


func _ready() -> void:
	_build_ui()
	refresh()


## Set the parameter name for accent color selection
func set_param_name(name: String) -> void:
	_param_name = name
	_update_accent_color()


func _build_ui() -> void:
	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	add_child(main_vbox)
	
	_build_header(main_vbox)
	_build_content_panel(main_vbox)


func _build_header(parent: VBoxContainer) -> void:
	_header_btn = Button.new()
	_header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header_btn.pressed.connect(_on_header_toggled)
	parent.add_child(_header_btn)
	
	_update_header_text()


func _build_content_panel(parent: VBoxContainer) -> void:
	_content_panel = PanelContainer.new()
	parent.add_child(_content_panel)
	
	var content_vbox: VBoxContainer = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 4)
	_content_panel.add_child(content_vbox)
	
	# Rows container
	_rows_container = VBoxContainer.new()
	_rows_container.add_theme_constant_override("separation", 2)
	content_vbox.add_child(_rows_container)
	
	# Add menu button
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	content_vbox.add_child(btn_row)
	
	_add_menu_btn = MenuButton.new()
	_add_menu_btn.text = "+ Add Command"
	_setup_add_menu()
	btn_row.add_child(_add_menu_btn)
	
	_update_accent_color()


func _update_accent_color() -> void:
	if not _content_panel:
		return
	
	var accent: Color = DEFAULT_ACCENT
	if _param_name in ACCENT_COLORS:
		accent = ACCENT_COLORS[_param_name]
	
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.3, accent.g * 0.3, accent.b * 0.3, 0.8)
	style.border_color = accent
	style.set_border_width_all(2)
	style.border_width_left = 4  # Thicker left border for visual distinction
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	_content_panel.add_theme_stylebox_override("panel", style)


## Override: Set context and check depth limit
func set_context(context: EditorWidgetContext) -> void:
	super.set_context(context)
	
	# Check if we need to switch to JSON mode
	var should_use_json: bool = _should_use_json_fallback()
	if should_use_json != _is_json_mode:
		_is_json_mode = should_use_json
		refresh()


## Override: Set the commands array
func set_value(value: Variant) -> void:
	if value is Array:
		_commands = []
		for item: Variant in value:
			if item is Dictionary:
				_commands.append(item.duplicate(true))
	else:
		_commands = []
	
	# Auto-collapse if many commands
	if _commands.size() > 2:
		_is_expanded = false
	else:
		_is_expanded = true
	
	refresh()


## Override: Get the commands array
func get_value() -> Variant:
	# If in JSON mode, parse from text
	if _is_json_mode and _json_edit:
		var json: JSON = JSON.new()
		var err: Error = json.parse(_json_edit.text)
		if err == OK and json.data is Array:
			return json.data
	
	return _commands


## Override: Rebuild UI from current state
func refresh() -> void:
	if not _rows_container:
		return
	
	_update_header_text()
	_content_panel.visible = _is_expanded
	
	if _is_json_mode:
		_build_json_fallback()
	else:
		_rebuild_command_rows()


## Update header text with command count and preview
func _update_header_text() -> void:
	if not _header_btn:
		return
	
	var arrow: String = "▼" if _is_expanded else "▶"
	var display_name: String = _param_name.capitalize() if not _param_name.is_empty() else "Commands"
	
	if _commands.is_empty():
		_header_btn.text = "%s %s: (empty)" % [arrow, display_name]
	else:
		# Build type preview
		var type_preview: Array[String] = []
		var max_preview: int = 3
		for i: int in range(mini(_commands.size(), max_preview)):
			var cmd: Dictionary = _commands[i]
			type_preview.append(cmd.get("type", "?"))
		
		var preview_text: String = ", ".join(type_preview)
		if _commands.size() > max_preview:
			preview_text += "..."
		
		_header_btn.text = "%s %s: %d commands (%s)" % [arrow, display_name, _commands.size(), preview_text]


## Rebuild command rows from data
func _rebuild_command_rows() -> void:
	# Clear existing rows - rows are direct children of _rows_container
	for row: CommandRowWidget in _command_rows:
		row.queue_free()
	_command_rows.clear()
	
	# Clear any other children (e.g., JSON fallback widgets)
	for child: Node in _rows_container.get_children():
		child.queue_free()
	
	# Create new rows
	for i: int in range(_commands.size()):
		var cmd: Dictionary = _commands[i]
		_create_command_row(i, cmd)


## Create a single command row
func _create_command_row(index: int, command_data: Dictionary) -> void:
	var row: CommandRowWidget = CommandRowWidget.new()
	row.set_value(command_data)
	row.set_index(index, _commands.size())
	row.edit_requested.connect(_on_command_edit_requested.bind(index))
	row.move_requested.connect(_on_command_move_requested.bind(index))
	row.delete_requested.connect(_on_command_delete_requested.bind(index))
	_rows_container.add_child(row)
	
	_command_rows.append(row)


## Check if we should use JSON fallback due to depth limit
func _should_use_json_fallback() -> bool:
	if not _context:
		return false
	return _context.is_at_depth_limit()


## Build JSON fallback editor for when depth limit is reached
func _build_json_fallback() -> void:
	# Clear existing content
	for child: Node in _rows_container.get_children():
		child.queue_free()
	_command_rows.clear()
	
	# Add warning label
	var warning: Label = Label.new()
	warning.text = "Depth limit reached - editing as JSON"
	warning.add_theme_color_override("font_color", SparklingEditorUtils.get_warning_color())
	_rows_container.add_child(warning)
	
	# Add JSON text editor
	_json_edit = TextEdit.new()
	_json_edit.custom_minimum_size.y = 150
	_json_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_json_edit.text = JSON.stringify(_commands, "  ")
	_json_edit.text_changed.connect(_on_json_changed)
	_rows_container.add_child(_json_edit)
	
	# Hide add menu in JSON mode
	if _add_menu_btn:
		_add_menu_btn.visible = false


## Setup the add command menu with category submenus (matches main editor)
func _setup_add_menu() -> void:
	var popup: PopupMenu = _add_menu_btn.get_popup()
	popup.clear()
	
	# Clean up old submenus
	for child: Node in popup.get_children():
		child.queue_free()
	
	var definitions: Dictionary = CinematicCommandDefs.get_merged_definitions()
	var categories: Dictionary = CinematicCommandDefs.build_categories(definitions)
	
	# Create submenus for each category
	for category: String in categories.keys():
		var submenu: PopupMenu = PopupMenu.new()
		submenu.name = category + "_submenu"
		
		var idx: int = 0
		for cmd_type: String in categories[category]:
			if cmd_type in definitions:
				var def: Dictionary = definitions[cmd_type]
				var desc: String = def.get("description", cmd_type)
				submenu.add_item(cmd_type + " - " + desc.substr(0, 35), idx)
				submenu.set_item_metadata(idx, cmd_type)
				idx += 1
		
		submenu.id_pressed.connect(_on_submenu_command_selected.bind(submenu))
		popup.add_child(submenu)
		popup.add_submenu_item(category, submenu.name)


func _on_submenu_command_selected(id: int, submenu: PopupMenu) -> void:
	var cmd_type: String = submenu.get_item_metadata(id)
	if not cmd_type.is_empty():
		_on_add_command_selected(cmd_type)


func _on_add_command_selected(command_type: String) -> void:
	var new_cmd: Dictionary = _create_default_command(command_type)
	_commands.append(new_cmd)
	refresh()
	value_changed.emit(_commands)


## Create a default command of the given type (matches main editor logic)
func _create_default_command(command_type: String) -> Dictionary:
	var cmd: Dictionary = {
		"type": command_type,
		"params": {}
	}
	
	# Get default params from definitions
	var definitions: Dictionary = CinematicCommandDefs.get_merged_definitions()
	if command_type in definitions:
		var def: Dictionary = definitions[command_type]
		# Add target field if command has_target
		if def.get("has_target", false):
			cmd["target"] = ""
		# Add default param values
		var params_def: Dictionary = def.get("params", {})
		for param_name: String in params_def:
			var param_def: Dictionary = params_def[param_name]
			cmd["params"][param_name] = param_def.get("default", "")
	
	return cmd


func _on_header_toggled() -> void:
	_is_expanded = not _is_expanded
	refresh()


func _on_command_edit_requested(index: int) -> void:
	if index >= 0 and index < _commands.size():
		# Show the command editor popup directly
		_show_command_editor(index)


## Show the command editor popup for a nested command
## Called when user clicks on a command row
func _show_command_editor(index: int) -> void:
	if index < 0 or index >= _commands.size():
		return
	
	var popup: CommandEditorPopup = CommandEditorPopup.new()
	
	# Increment depth for nested editing
	if _context:
		popup.set_context(_context.with_incremented_depth())
	else:
		# Create a minimal context if none exists
		var minimal_context: EditorWidgetContext = EditorWidgetContext.new()
		popup.set_context(minimal_context)
	
	popup.set_command(_commands[index])
	popup.command_changed.connect(func(new_cmd: Dictionary) -> void:
		_commands[index] = new_cmd
		value_changed.emit(_commands)
		_rebuild_command_rows()
	)
	add_child(popup)
	popup.popup_centered()


func _on_command_move_requested(direction: int, index: int) -> void:
	var new_index: int = index + direction
	if new_index < 0 or new_index >= _commands.size():
		return
	
	# Swap commands
	var temp: Dictionary = _commands[index]
	_commands[index] = _commands[new_index]
	_commands[new_index] = temp
	
	refresh()
	value_changed.emit(_commands)


func _on_command_delete_requested(index: int) -> void:
	if index >= 0 and index < _commands.size():
		_commands.remove_at(index)
		refresh()
		value_changed.emit(_commands)


func _on_json_changed() -> void:
	# Try to parse and update commands
	if not _json_edit:
		return
	
	var json: JSON = JSON.new()
	var err: Error = json.parse(_json_edit.text)
	if err == OK and json.data is Array:
		_commands = json.data
		value_changed.emit(_commands)
