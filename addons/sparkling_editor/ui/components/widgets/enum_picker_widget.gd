@tool
class_name EnumPickerWidget
extends EditorWidgetBase

## Dropdown widget for enum/string options
##
## Usage:
##   var widget: EnumPickerWidget = EnumPickerWidget.new(["option1", "option2", "option3"])
##   widget.set_value("option2")
##   widget.value_changed.connect(_on_option_changed)
##   add_child(widget)

var options: Array[String] = []
var _option_button: OptionButton
var _current_value: String = ""


func _init(p_options: Array[String] = []) -> void:
	options = p_options


## Set options and refresh the dropdown
func set_options(p_options: Array[String]) -> void:
	options = p_options
	if is_inside_tree():
		refresh()


func _ready() -> void:
	_option_button = OptionButton.new()
	_option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_option_button.item_selected.connect(_on_item_selected)
	add_child(_option_button)
	refresh()


## Override: Rebuild dropdown from options array
func refresh() -> void:
	if not _option_button:
		return
	
	_option_button.clear()
	
	for i: int in range(options.size()):
		var option: String = options[i]
		_option_button.add_item(option, i)
	
	# Restore selection
	_select_current_value()


## Override: Set the current value without emitting signal
func set_value(value: Variant) -> void:
	_current_value = str(value) if value != null else ""
	_select_current_value()


## Override: Get the current value
func get_value() -> Variant:
	return _current_value


## Select the item matching _current_value
func _select_current_value() -> void:
	if not _option_button:
		return
	
	for i: int in range(_option_button.item_count):
		if _option_button.get_item_text(i) == _current_value:
			_option_button.select(i)
			return
	
	# Value not found - select first item if available
	if _option_button.item_count > 0:
		_option_button.select(0)
		_current_value = _option_button.get_item_text(0)


func _on_item_selected(index: int) -> void:
	_current_value = _option_button.get_item_text(index)
	value_changed.emit(_current_value)
