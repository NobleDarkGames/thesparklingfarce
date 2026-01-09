@tool
class_name StringEditorWidget
extends EditorWidgetBase

## Single-line text input widget
##
## Usage:
##   var widget: StringEditorWidget = StringEditorWidget.new("Enter name...")
##   widget.set_value("Initial text")
##   widget.value_changed.connect(_on_text_changed)
##   add_child(widget)

var placeholder_text: String = ""
var _line_edit: LineEdit
var _current_value: String = ""


func _init(p_placeholder: String = "") -> void:
	placeholder_text = p_placeholder


func _ready() -> void:
	_line_edit = LineEdit.new()
	_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line_edit.placeholder_text = placeholder_text
	_line_edit.text = _current_value
	_line_edit.text_changed.connect(_on_text_changed)
	add_child(_line_edit)


## Override: Set the current value without emitting signal
func set_value(value: Variant) -> void:
	_current_value = str(value) if value != null else ""
	if _line_edit:
		_line_edit.text = _current_value


## Override: Get the current value
func get_value() -> Variant:
	return _current_value


func _on_text_changed(new_text: String) -> void:
	_current_value = new_text
	value_changed.emit(new_text)
