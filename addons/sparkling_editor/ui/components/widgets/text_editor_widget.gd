@tool
class_name TextEditorWidget
extends EditorWidgetBase

## Multi-line text input widget for dialog text, descriptions, etc.
##
## Usage:
##   var widget: TextEditorWidget = TextEditorWidget.new("Enter description...", 100.0)
##   widget.set_value("Initial text\nwith multiple lines")
##   widget.value_changed.connect(_on_text_changed)
##   add_child(widget)

var placeholder_text: String = ""
var min_height: float = 60.0
var _text_edit: TextEdit
var _current_value: String = ""


func _init(p_placeholder: String = "", p_min_height: float = 60.0) -> void:
	placeholder_text = p_placeholder
	min_height = p_min_height


func _ready() -> void:
	_text_edit = TextEdit.new()
	_text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_edit.custom_minimum_size.y = min_height
	_text_edit.placeholder_text = placeholder_text
	_text_edit.text = _current_value
	_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text_edit.text_changed.connect(_on_text_changed)
	add_child(_text_edit)


## Override: Set the current value without emitting signal
func set_value(value: Variant) -> void:
	_current_value = str(value) if value != null else ""
	if _text_edit:
		_text_edit.text = _current_value


## Override: Get the current value
func get_value() -> Variant:
	return _current_value


func _on_text_changed() -> void:
	if _text_edit:
		_current_value = _text_edit.text
		value_changed.emit(_current_value)
