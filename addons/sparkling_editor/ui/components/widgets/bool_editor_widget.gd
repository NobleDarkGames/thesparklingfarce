@tool
class_name BoolEditorWidget
extends EditorWidgetBase

## Checkbox widget for boolean values
##
## Usage:
##   var widget: BoolEditorWidget = BoolEditorWidget.new()
##   widget.set_value(true)
##   widget.value_changed.connect(_on_toggled)
##   add_child(widget)

var _check_box: CheckBox
var _current_value: bool = false


func _ready() -> void:
	_check_box = CheckBox.new()
	_check_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_check_box.button_pressed = _current_value
	_check_box.toggled.connect(_on_toggled)
	add_child(_check_box)


## Override: Set the current value without emitting signal
## Handles bool conversion from various types
func set_value(value: Variant) -> void:
	if value is bool:
		_current_value = value
	elif value is int:
		_current_value = value != 0
	elif value is String:
		_current_value = value.to_lower() == "true"
	else:
		_current_value = false
	
	if _check_box:
		# Temporarily disconnect to prevent signal emission
		_check_box.toggled.disconnect(_on_toggled)
		_check_box.button_pressed = _current_value
		_check_box.toggled.connect(_on_toggled)


## Override: Get the current value
func get_value() -> Variant:
	return _current_value


func _on_toggled(pressed: bool) -> void:
	_current_value = pressed
	value_changed.emit(pressed)
