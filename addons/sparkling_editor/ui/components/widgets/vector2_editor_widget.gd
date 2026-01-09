@tool
class_name Vector2EditorWidget
extends EditorWidgetBase

## X/Y coordinate input widget
## Value is stored/returned as Array [x, y] for JSON compatibility
##
## Usage:
##   var widget: Vector2EditorWidget = Vector2EditorWidget.new(-1000.0, 1000.0)
##   widget.set_value([100.0, 200.0])  # or Vector2(100, 200)
##   widget.value_changed.connect(_on_position_changed)
##   add_child(widget)

var min_value: float = -10000.0
var max_value: float = 10000.0
var _x_spin: SpinBox
var _y_spin: SpinBox
var _current_value: Array = [0.0, 0.0]


func _init(p_min: float = -10000.0, p_max: float = 10000.0) -> void:
	min_value = p_min
	max_value = p_max


func _ready() -> void:
	var container: HBoxContainer = HBoxContainer.new()
	add_child(container)
	
	# X label and spinbox
	var x_label: Label = Label.new()
	x_label.text = "X:"
	container.add_child(x_label)
	
	_x_spin = SpinBox.new()
	_x_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_x_spin.min_value = min_value
	_x_spin.max_value = max_value
	_x_spin.step = 1.0
	_x_spin.value = _current_value[0]
	_x_spin.value_changed.connect(_on_value_changed)
	container.add_child(_x_spin)
	
	# Y label and spinbox
	var y_label: Label = Label.new()
	y_label.text = "Y:"
	container.add_child(y_label)
	
	_y_spin = SpinBox.new()
	_y_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_y_spin.min_value = min_value
	_y_spin.max_value = max_value
	_y_spin.step = 1.0
	_y_spin.value = _current_value[1]
	_y_spin.value_changed.connect(_on_value_changed)
	container.add_child(_y_spin)


## Override: Set the current value without emitting signal
## Handles Array, Vector2, or Vector2i input
func set_value(value: Variant) -> void:
	if value is Array:
		var arr: Array = value
		_current_value = [
			float(arr[0]) if arr.size() > 0 else 0.0,
			float(arr[1]) if arr.size() > 1 else 0.0
		]
	elif value is Vector2:
		var vec: Vector2 = value
		_current_value = [vec.x, vec.y]
	elif value is Vector2i:
		var vec: Vector2i = value
		_current_value = [float(vec.x), float(vec.y)]
	else:
		_current_value = [0.0, 0.0]
	
	_update_spinboxes()


## Override: Get the current value as Array [x, y]
func get_value() -> Variant:
	return _current_value


## Update spinboxes without emitting signals
func _update_spinboxes() -> void:
	if not _x_spin or not _y_spin:
		return
	
	# Temporarily disconnect to prevent signal emission
	_x_spin.value_changed.disconnect(_on_value_changed)
	_y_spin.value_changed.disconnect(_on_value_changed)
	
	_x_spin.value = _current_value[0]
	_y_spin.value = _current_value[1]
	
	_x_spin.value_changed.connect(_on_value_changed)
	_y_spin.value_changed.connect(_on_value_changed)


func _on_value_changed(_new_value: float) -> void:
	if _x_spin and _y_spin:
		_current_value = [_x_spin.value, _y_spin.value]
		value_changed.emit(_current_value)
