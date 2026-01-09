@tool
class_name ChoiceRowWidget
extends EditorWidgetBase

## Single choice row with label, action, value, and optional battle settings
##
## Emits value_changed with the full choice Dictionary when any field changes
## Emits delete_requested when the delete button is pressed
##
## Usage:
##   var row: ChoiceRowWidget = ChoiceRowWidget.new()
##   row.set_context(context)
##   row.set_value({"label": "Fight!", "action": "battle", "value": "boss_battle"})
##   row.value_changed.connect(_on_choice_changed)
##   add_child(row)

signal delete_requested()

## The choice actions available
const CHOICE_ACTIONS: Array[String] = ["none", "battle", "set_flag", "cinematic", "set_variable", "shop"]

var _choice_data: Dictionary = {}
var _label_edit: LineEdit
var _action_picker: OptionButton
var _value_container: VBoxContainer  # Holds value widget, changes based on action
var _value_widget: Control
var _delete_btn: Button
var _battle_options_container: VBoxContainer  # For battle-specific options

# Battle option widgets
var _on_victory_cinematic_widget: ResourcePickerWidget
var _on_defeat_cinematic_widget: ResourcePickerWidget
var _on_victory_flags_widget: StringEditorWidget
var _on_defeat_flags_widget: StringEditorWidget


func _ready() -> void:
	_build_ui()
	_update_from_data()


func _build_ui() -> void:
	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 4)
	add_child(main_vbox)
	
	# Main row: [Label] [Action] [Delete]
	var main_row: HBoxContainer = HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 8)
	main_vbox.add_child(main_row)
	
	# Label input
	var label_label: Label = Label.new()
	label_label.text = "Label:"
	label_label.custom_minimum_size.x = 50
	main_row.add_child(label_label)
	
	_label_edit = LineEdit.new()
	_label_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label_edit.placeholder_text = "Choice text..."
	_label_edit.text_changed.connect(_on_label_changed)
	main_row.add_child(_label_edit)
	
	# Action picker
	var action_label: Label = Label.new()
	action_label.text = "Action:"
	action_label.custom_minimum_size.x = 50
	main_row.add_child(action_label)
	
	_action_picker = OptionButton.new()
	_action_picker.custom_minimum_size.x = 100
	for action: String in CHOICE_ACTIONS:
		_action_picker.add_item(action)
	_action_picker.item_selected.connect(_on_action_changed)
	main_row.add_child(_action_picker)
	
	# Delete button
	_delete_btn = Button.new()
	_delete_btn.text = "✕"
	_delete_btn.custom_minimum_size.x = 28
	_delete_btn.tooltip_text = "Delete choice"
	_delete_btn.pressed.connect(_on_delete_pressed)
	main_row.add_child(_delete_btn)
	
	# Value container (changes based on action type)
	_value_container = VBoxContainer.new()
	_value_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_value_container.add_theme_constant_override("separation", 4)
	main_vbox.add_child(_value_container)
	
	# Battle options container (shown only for battle action)
	_battle_options_container = VBoxContainer.new()
	_battle_options_container.add_theme_constant_override("separation", 4)
	_battle_options_container.visible = false
	main_vbox.add_child(_battle_options_container)
	
	_build_battle_options()


func _build_battle_options() -> void:
	# On Victory Cinematic
	var victory_cin_row: HBoxContainer = HBoxContainer.new()
	victory_cin_row.add_theme_constant_override("separation", 8)
	_battle_options_container.add_child(victory_cin_row)
	
	var victory_cin_label: Label = Label.new()
	victory_cin_label.text = "On Victory:"
	victory_cin_label.custom_minimum_size.x = 100
	victory_cin_row.add_child(victory_cin_label)
	
	_on_victory_cinematic_widget = ResourcePickerWidget.new(ResourcePickerWidget.ResourceType.CINEMATIC)
	_on_victory_cinematic_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_on_victory_cinematic_widget.value_changed.connect(_on_battle_option_changed.bind("on_victory_cinematic"))
	victory_cin_row.add_child(_on_victory_cinematic_widget)
	
	# On Defeat Cinematic
	var defeat_cin_row: HBoxContainer = HBoxContainer.new()
	defeat_cin_row.add_theme_constant_override("separation", 8)
	_battle_options_container.add_child(defeat_cin_row)
	
	var defeat_cin_label: Label = Label.new()
	defeat_cin_label.text = "On Defeat:"
	defeat_cin_label.custom_minimum_size.x = 100
	defeat_cin_row.add_child(defeat_cin_label)
	
	_on_defeat_cinematic_widget = ResourcePickerWidget.new(ResourcePickerWidget.ResourceType.CINEMATIC)
	_on_defeat_cinematic_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_on_defeat_cinematic_widget.value_changed.connect(_on_battle_option_changed.bind("on_defeat_cinematic"))
	defeat_cin_row.add_child(_on_defeat_cinematic_widget)
	
	# Victory Flags
	var victory_flags_row: HBoxContainer = HBoxContainer.new()
	victory_flags_row.add_theme_constant_override("separation", 8)
	_battle_options_container.add_child(victory_flags_row)
	
	var victory_flags_label: Label = Label.new()
	victory_flags_label.text = "Victory Flags:"
	victory_flags_label.custom_minimum_size.x = 100
	victory_flags_row.add_child(victory_flags_label)
	
	_on_victory_flags_widget = StringEditorWidget.new("flag1, flag2...")
	_on_victory_flags_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_on_victory_flags_widget.value_changed.connect(_on_battle_option_changed.bind("on_victory_flags"))
	victory_flags_row.add_child(_on_victory_flags_widget)
	
	# Defeat Flags
	var defeat_flags_row: HBoxContainer = HBoxContainer.new()
	defeat_flags_row.add_theme_constant_override("separation", 8)
	_battle_options_container.add_child(defeat_flags_row)
	
	var defeat_flags_label: Label = Label.new()
	defeat_flags_label.text = "Defeat Flags:"
	defeat_flags_label.custom_minimum_size.x = 100
	defeat_flags_row.add_child(defeat_flags_label)
	
	_on_defeat_flags_widget = StringEditorWidget.new("flag1, flag2...")
	_on_defeat_flags_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_on_defeat_flags_widget.value_changed.connect(_on_battle_option_changed.bind("on_defeat_flags"))
	defeat_flags_row.add_child(_on_defeat_flags_widget)


## Override: Set context and pass to child widgets
func set_context(context: EditorWidgetContext) -> void:
	super.set_context(context)
	
	if _on_victory_cinematic_widget:
		_on_victory_cinematic_widget.set_context(context)
	if _on_defeat_cinematic_widget:
		_on_defeat_cinematic_widget.set_context(context)
	
	# Rebuild value widget with new context
	if is_inside_tree():
		_rebuild_value_widget()


## Override: Set the choice data
func set_value(value: Variant) -> void:
	if value is Dictionary:
		_choice_data = value.duplicate(true)
	else:
		_choice_data = _create_default_choice()
	_update_from_data()


## Override: Get the choice data
func get_value() -> Variant:
	return _choice_data


## Create a default empty choice
func _create_default_choice() -> Dictionary:
	return {
		"label": "",
		"action": "none",
		"value": ""
	}


## Update UI from current data
func _update_from_data() -> void:
	if not _label_edit:
		return
	
	_label_edit.text = _choice_data.get("label", "")
	
	var action: String = _choice_data.get("action", "none")
	var action_idx: int = CHOICE_ACTIONS.find(action)
	if action_idx >= 0:
		_action_picker.select(action_idx)
	else:
		_action_picker.select(0)  # Default to "none"
	
	_rebuild_value_widget()
	_update_battle_options_visibility()
	_update_battle_options_values()


## Rebuild the value widget based on current action
func _rebuild_value_widget() -> void:
	# Clear existing value widget
	if _value_widget:
		_value_widget.queue_free()
		_value_widget = null
	
	# Clear container
	for child: Node in _value_container.get_children():
		child.queue_free()
	
	var action: String = _choice_data.get("action", "none")
	var current_value: Variant = _choice_data.get("value", "")
	
	# Create appropriate widget based on action
	match action:
		"none":
			# No value widget needed
			pass
		
		"battle":
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			_value_container.add_child(row)
			
			var label: Label = Label.new()
			label.text = "Battle:"
			label.custom_minimum_size.x = 100
			row.add_child(label)
			
			var picker: ResourcePickerWidget = ResourcePickerWidget.new(ResourcePickerWidget.ResourceType.BATTLE)
			picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if _context:
				picker.set_context(_context)
			picker.set_value(current_value)
			picker.value_changed.connect(_on_value_changed)
			row.add_child(picker)
			_value_widget = picker
		
		"set_flag":
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			_value_container.add_child(row)
			
			var label: Label = Label.new()
			label.text = "Flag Name:"
			label.custom_minimum_size.x = 100
			row.add_child(label)
			
			var edit: StringEditorWidget = StringEditorWidget.new("flag_name")
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			edit.set_value(current_value)
			edit.value_changed.connect(_on_value_changed)
			row.add_child(edit)
			_value_widget = edit
		
		"cinematic":
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			_value_container.add_child(row)
			
			var label: Label = Label.new()
			label.text = "Cinematic:"
			label.custom_minimum_size.x = 100
			row.add_child(label)
			
			var picker: ResourcePickerWidget = ResourcePickerWidget.new(ResourcePickerWidget.ResourceType.CINEMATIC)
			picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if _context:
				picker.set_context(_context)
			picker.set_value(current_value)
			picker.value_changed.connect(_on_value_changed)
			row.add_child(picker)
			_value_widget = picker
		
		"set_variable":
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			_value_container.add_child(row)
			
			var label: Label = Label.new()
			label.text = "Key:Value:"
			label.custom_minimum_size.x = 100
			row.add_child(label)
			
			var edit: StringEditorWidget = StringEditorWidget.new("key:value")
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			edit.set_value(current_value)
			edit.value_changed.connect(_on_value_changed)
			row.add_child(edit)
			_value_widget = edit
		
		"shop":
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			_value_container.add_child(row)
			
			var label: Label = Label.new()
			label.text = "Shop:"
			label.custom_minimum_size.x = 100
			row.add_child(label)
			
			var picker: ResourcePickerWidget = ResourcePickerWidget.new(ResourcePickerWidget.ResourceType.SHOP)
			picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if _context:
				picker.set_context(_context)
			picker.set_value(current_value)
			picker.value_changed.connect(_on_value_changed)
			row.add_child(picker)
			_value_widget = picker


## Update battle options visibility
func _update_battle_options_visibility() -> void:
	if not _battle_options_container:
		return
	
	var action: String = _choice_data.get("action", "none")
	_battle_options_container.visible = (action == "battle")


## Update battle options widget values from data
func _update_battle_options_values() -> void:
	if not _on_victory_cinematic_widget:
		return
	
	_on_victory_cinematic_widget.set_value(_choice_data.get("on_victory_cinematic", ""))
	_on_defeat_cinematic_widget.set_value(_choice_data.get("on_defeat_cinematic", ""))
	_on_victory_flags_widget.set_value(_choice_data.get("on_victory_flags", ""))
	_on_defeat_flags_widget.set_value(_choice_data.get("on_defeat_flags", ""))


func _on_label_changed(new_text: String) -> void:
	_choice_data["label"] = new_text
	value_changed.emit(_choice_data)


func _on_action_changed(index: int) -> void:
	var new_action: String = CHOICE_ACTIONS[index]
	_choice_data["action"] = new_action
	_choice_data["value"] = ""  # Reset value when action changes
	
	_rebuild_value_widget()
	_update_battle_options_visibility()
	value_changed.emit(_choice_data)


func _on_value_changed(new_value: Variant) -> void:
	_choice_data["value"] = new_value
	value_changed.emit(_choice_data)


func _on_battle_option_changed(new_value: Variant, option_key: String) -> void:
	_choice_data[option_key] = new_value
	value_changed.emit(_choice_data)


func _on_delete_pressed() -> void:
	delete_requested.emit()
