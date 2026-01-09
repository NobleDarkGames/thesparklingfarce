@tool
class_name ChoicesEditorWidget
extends EditorWidgetBase

## Editor for an array of choices
## Used by show_choice command to edit multiple choice options
##
## Usage:
##   var widget: ChoicesEditorWidget = ChoicesEditorWidget.new()
##   widget.set_context(context)
##   widget.set_value([{"label": "Yes", "action": "set_flag", "value": "accepted"}])
##   widget.value_changed.connect(_on_choices_changed)
##   add_child(widget)

var _choices: Array = []
var _choice_rows: Array[ChoiceRowWidget] = []
var _rows_container: VBoxContainer
var _add_btn: Button


func _ready() -> void:
	_build_ui()
	refresh()


func _build_ui() -> void:
	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)
	
	# Header
	var header: Label = Label.new()
	header.text = "Choices"
	header.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(header)
	
	# Rows container
	_rows_container = VBoxContainer.new()
	_rows_container.add_theme_constant_override("separation", 12)
	main_vbox.add_child(_rows_container)
	
	# Add button
	var btn_row: HBoxContainer = HBoxContainer.new()
	main_vbox.add_child(btn_row)
	
	_add_btn = Button.new()
	_add_btn.text = "+ Add Choice"
	_add_btn.pressed.connect(_on_add_choice_pressed)
	btn_row.add_child(_add_btn)


## Override: Set context and pass to child widgets
func set_context(context: EditorWidgetContext) -> void:
	super.set_context(context)
	
	# Update existing rows with new context
	for row: ChoiceRowWidget in _choice_rows:
		row.set_context(context)


## Override: Set the choices array
func set_value(value: Variant) -> void:
	if value is Array:
		_choices = []
		for item: Variant in value:
			if item is Dictionary:
				_choices.append(item.duplicate(true))
			else:
				_choices.append(_create_default_choice())
	else:
		_choices = []
	
	refresh()


## Override: Get the choices array
func get_value() -> Variant:
	return _choices


## Override: Rebuild all rows from current data
func refresh() -> void:
	if not _rows_container:
		return
	
	# Clear existing rows
	for row: ChoiceRowWidget in _choice_rows:
		row.queue_free()
	_choice_rows.clear()
	
	# Create new rows
	for i: int in range(_choices.size()):
		var choice: Dictionary = _choices[i]
		_create_choice_row(i, choice)


## Create a single choice row
func _create_choice_row(index: int, choice_data: Dictionary) -> void:
	# Container with visual separator
	var container: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25, 0.5)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	container.add_theme_stylebox_override("panel", style)
	_rows_container.add_child(container)
	
	var row: ChoiceRowWidget = ChoiceRowWidget.new()
	if _context:
		row.set_context(_context)
	row.set_value(choice_data)
	row.value_changed.connect(_on_choice_changed.bind(index))
	row.delete_requested.connect(_on_choice_delete_requested.bind(index))
	container.add_child(row)
	
	_choice_rows.append(row)


## Create a default empty choice
func _create_default_choice() -> Dictionary:
	return {
		"label": "New Choice",
		"action": "none",
		"value": ""
	}


func _on_choice_changed(new_value: Dictionary, index: int) -> void:
	if index >= 0 and index < _choices.size():
		_choices[index] = new_value
		value_changed.emit(_choices)


func _on_choice_delete_requested(index: int) -> void:
	if index >= 0 and index < _choices.size():
		_choices.remove_at(index)
		refresh()
		value_changed.emit(_choices)


func _on_add_choice_pressed() -> void:
	_choices.append(_create_default_choice())
	refresh()
	value_changed.emit(_choices)
