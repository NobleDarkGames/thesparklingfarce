@tool
class_name CommandRowWidget
extends EditorWidgetBase

## Summary row for a nested command
## Shows command type and brief summary, with action buttons for edit/move/delete
##
## Usage:
##   var row: CommandRowWidget = CommandRowWidget.new()
##   row.set_value({"type": "dialog_line", "params": {"text": "Hello!"}})
##   row.set_index(0, 5)  # First of 5 commands
##   row.edit_requested.connect(_on_edit_command)
##   add_child(row)

signal edit_requested()
signal move_requested(direction: int)  # -1 = up, 1 = down
signal delete_requested()

var _command_data: Dictionary = {}
var _index: int = 0
var _total_count: int = 0

var _summary_btn: Button
var _up_btn: Button
var _down_btn: Button
var _delete_btn: Button


func _ready() -> void:
	_build_ui()
	_update_display()


func _build_ui() -> void:
	# Horizontal layout: [Summary Button] [Up] [Down] [Delete]
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	add_child(hbox)
	
	# Summary button - shows command type and brief description
	_summary_btn = Button.new()
	_summary_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_summary_btn.pressed.connect(_on_summary_pressed)
	hbox.add_child(_summary_btn)
	
	# Up button
	_up_btn = Button.new()
	_up_btn.text = "▲"
	_up_btn.custom_minimum_size.x = 28
	_up_btn.tooltip_text = "Move up"
	_up_btn.pressed.connect(_on_up_pressed)
	hbox.add_child(_up_btn)
	
	# Down button
	_down_btn = Button.new()
	_down_btn.text = "▼"
	_down_btn.custom_minimum_size.x = 28
	_down_btn.tooltip_text = "Move down"
	_down_btn.pressed.connect(_on_down_pressed)
	hbox.add_child(_down_btn)
	
	# Delete button
	_delete_btn = Button.new()
	_delete_btn.text = "✕"
	_delete_btn.custom_minimum_size.x = 28
	_delete_btn.tooltip_text = "Delete command"
	_delete_btn.pressed.connect(_on_delete_pressed)
	hbox.add_child(_delete_btn)


## Set the index and total count for enabling/disabling move buttons
func set_index(index: int, total: int) -> void:
	_index = index
	_total_count = total
	_update_move_buttons()


## Override: Set the command data
func set_value(value: Variant) -> void:
	if value is Dictionary:
		_command_data = value
	else:
		_command_data = {}
	_update_display()


## Override: Get the command data
func get_value() -> Variant:
	return _command_data


## Update the summary button text
func _update_display() -> void:
	if not _summary_btn:
		return
	
	var cmd_type: String = _command_data.get("type", "unknown")
	var summary: String = _get_command_summary()
	
	if summary.is_empty():
		_summary_btn.text = cmd_type
	else:
		_summary_btn.text = "%s: %s" % [cmd_type, summary]


## Update move button enabled states based on position
func _update_move_buttons() -> void:
	if not _up_btn or not _down_btn:
		return
	
	_up_btn.disabled = _index <= 0
	_down_btn.disabled = _index >= _total_count - 1


## Get a brief description based on command type
func _get_command_summary() -> String:
	var cmd_type: String = _command_data.get("type", "")
	var params: Dictionary = _command_data.get("params", {})
	
	match cmd_type:
		"dialog_line":
			var text: String = params.get("text", "")
			if text.length() > 30:
				return '"%s..."' % text.substr(0, 30)
			elif not text.is_empty():
				return '"%s"' % text
		"wait":
			var duration: float = float(params.get("duration", 1.0))
			return "%.1fs" % duration
		"set_variable":
			var variable: String = params.get("variable", "")
			if not variable.is_empty():
				return variable
		"check_flag":
			var flag: String = params.get("flag", "")
			if not flag.is_empty():
				return flag
		"move_entity":
			var target: String = _command_data.get("target", "")
			if not target.is_empty():
				return target
		"camera_move":
			var pos: Variant = params.get("target_pos", [0, 0])
			if pos is Array and pos.size() >= 2:
				return "(%d, %d)" % [int(pos[0]), int(pos[1])]
		"spawn_entity":
			var actor_id: String = params.get("actor_id", "")
			if not actor_id.is_empty():
				return actor_id
		"play_sound", "play_music":
			var sound_id: String = params.get("sound_id", params.get("music_id", ""))
			if not sound_id.is_empty():
				return sound_id
		"fade_screen":
			var fade_type: String = params.get("fade_type", "out")
			return fade_type
	
	return ""


func _on_summary_pressed() -> void:
	edit_requested.emit()


func _on_up_pressed() -> void:
	move_requested.emit(-1)


func _on_down_pressed() -> void:
	move_requested.emit(1)


func _on_delete_pressed() -> void:
	delete_requested.emit()
