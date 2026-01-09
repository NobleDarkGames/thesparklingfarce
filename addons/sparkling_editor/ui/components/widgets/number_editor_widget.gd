@tool
class_name NumberEditorWidget
extends EditorWidgetBase

## Numeric input widget with SpinBox
##
## Usage:
##   var widget: NumberEditorWidget = NumberEditorWidget.new(0.0, 100.0, 1.0)
##   widget.set_value(50)
##   widget.value_changed.connect(_on_value_changed)
##   add_child(widget)

var min_value: float = 0.0
var max_value: float = 100.0
var step: float = 0.1
var _spin_box: SpinBox
var _current_value: float = 0.0


func _init(p_min: float = 0.0, p_max: float = 100.0, p_step: float = 0.1) -> void:
	min_value = p_min
	max_value = p_max
	step = p_step


func _ready() -> void:
	_spin_box = SpinBox.new()
	_spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spin_box.min_value = min_value
	_spin_box.max_value = max_value
	_spin_box.step = step
	_spin_box.value = _current_value
	_spin_box.value_changed.connect(_on_value_changed)
	add_child(_spin_box)


## Override: Set the current value without emitting signal
## Handles both int and float input
func set_value(value: Variant) -> void:
	if value is int:
		_current_value = float(value)
	elif value is float:
		_current_value = value
	else:
		_current_value = 0.0
	
	if _spin_box:
		# Temporarily disconnect to prevent signal emission
		_spin_box.value_changed.disconnect(_on_value_changed)
		_spin_box.value = _current_value
		_spin_box.value_changed.connect(_on_value_changed)


## Override: Get the current value
func get_value() -> Variant:
	return _current_value


func _on_value_changed(new_value: float) -> void:
	_current_value = new_value
	value_changed.emit(new_value)
