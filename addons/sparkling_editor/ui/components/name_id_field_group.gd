@tool
class_name NameIdFieldGroup
extends VBoxContainer

## Reusable component for Name + ID field pairs with auto-generation
##
## Features:
## - Name field that auto-generates ID using SparklingEditorUtils.generate_id_from_name()
## - ID field with optional lock button to prevent/allow auto-generation
## - has_focus() check to detect manual edits vs programmatic changes
## - _updating_ui guard to prevent signal feedback during populate operations
## - Configurable labels, placeholders, and tooltips
## - show_lock_button option (false for wizard contexts where locking is unnecessary)
##
## Usage:
##   var name_id_group: NameIdFieldGroup = NameIdFieldGroup.new()
##   name_id_group.name_label = "Character Name:"
##   name_id_group.id_label = "Character ID:"
##   name_id_group.value_changed.connect(_on_name_id_changed)
##   parent.add_child(name_id_group)
##
##   # Populate from existing data
##   name_id_group.set_values("Max", "max_hero", true)  # true = determine lock state automatically
##
##   # Get current values
##   var name_val: String = name_id_group.get_name_value()
##   var id_val: String = name_id_group.get_id_value()

## Emitted when either the name or ID value changes
## Passes a dictionary with "name" and "id" keys
signal value_changed(values: Dictionary)

## Emitted specifically when the ID value changes (for validation hooks)
signal id_changed(new_id: String)

# Configuration properties (set before adding to tree for best results)
## Label text for the name field
@export var name_label: String = "Name:":
	set(value):
		name_label = value
		if _name_label_node:
			_name_label_node.text = value

## Label text for the ID field
@export var id_label: String = "ID:":
	set(value):
		id_label = value
		if _id_label_node:
			_id_label_node.text = value

## Placeholder text for name field
@export var name_placeholder: String = "Enter name...":
	set(value):
		name_placeholder = value
		if _name_edit:
			_name_edit.placeholder_text = value

## Placeholder text for ID field
@export var id_placeholder: String = "(auto-generated from name)":
	set(value):
		id_placeholder = value
		if _id_edit:
			_id_edit.placeholder_text = value

## Tooltip for name field
@export var name_tooltip: String = "Display name shown to users":
	set(value):
		name_tooltip = value
		if _name_edit:
			_name_edit.tooltip_text = value

## Tooltip for ID field
@export var id_tooltip: String = "Unique identifier. Auto-generates from name unless locked.":
	set(value):
		id_tooltip = value
		if _id_edit:
			_id_edit.tooltip_text = value

## Width for labels (for alignment with other form fields)
@export var label_width: int = 140:
	set(value):
		label_width = value
		if _name_label_node:
			_name_label_node.custom_minimum_size.x = value
		if _id_label_node:
			_id_label_node.custom_minimum_size.x = value

## Whether to show the lock button (false for wizard contexts)
@export var show_lock_button: bool = true:
	set(value):
		show_lock_button = value
		if _lock_btn:
			_lock_btn.visible = value

## Maximum length for name field (0 = no limit)
@export var name_max_length: int = 0:
	set(value):
		name_max_length = value
		if _name_edit:
			_name_edit.max_length = value

# Internal UI nodes
var _name_label_node: Label
var _name_edit: LineEdit
var _id_label_node: Label
var _id_edit: LineEdit
var _lock_btn: Button
var _help_label: Label

# State tracking
var _id_is_locked: bool = false
var _updating_ui: bool = false


func _init() -> void:
	add_theme_constant_override("separation", 4)


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Name row
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	add_child(name_row)

	_name_label_node = Label.new()
	_name_label_node.text = name_label
	_name_label_node.custom_minimum_size.x = label_width
	name_row.add_child(_name_label_node)

	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.placeholder_text = name_placeholder
	_name_edit.tooltip_text = name_tooltip
	if name_max_length > 0:
		_name_edit.max_length = name_max_length
	_name_edit.text_changed.connect(_on_name_text_changed)
	name_row.add_child(_name_edit)

	# ID row
	var id_row: HBoxContainer = HBoxContainer.new()
	id_row.add_theme_constant_override("separation", 8)
	add_child(id_row)

	_id_label_node = Label.new()
	_id_label_node.text = id_label
	_id_label_node.custom_minimum_size.x = label_width
	id_row.add_child(_id_label_node)

	_id_edit = LineEdit.new()
	_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_id_edit.placeholder_text = id_placeholder
	_id_edit.tooltip_text = id_tooltip
	_id_edit.text_changed.connect(_on_id_text_changed)
	id_row.add_child(_id_edit)

	_lock_btn = Button.new()
	_lock_btn.text = "Lock"
	_lock_btn.tooltip_text = "Click to lock ID and prevent auto-generation"
	_lock_btn.custom_minimum_size.x = 60
	_lock_btn.pressed.connect(_on_lock_button_pressed)
	_lock_btn.visible = show_lock_button
	id_row.add_child(_lock_btn)

	# Help label
	_help_label = Label.new()
	_help_label.text = "ID auto-generates from name. Click lock to set custom ID."
	_help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	_help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	_help_label.visible = show_lock_button  # Only show help text when lock button is visible
	add_child(_help_label)


# =============================================================================
# PUBLIC API
# =============================================================================

## Get the current name field value
func get_name_value() -> String:
	if _name_edit:
		return _name_edit.text.strip_edges()
	return ""


## Get the current ID field value
func get_id_value() -> String:
	if _id_edit:
		return _id_edit.text.strip_edges()
	return ""


## Set both name and ID values
## If auto_detect_lock is true, determines lock state by comparing ID to auto-generated value
func set_values(name_value: String, id_value: String, auto_detect_lock: bool = true) -> void:
	_updating_ui = true

	if _name_edit:
		_name_edit.text = name_value

	if _id_edit:
		_id_edit.text = id_value

	if auto_detect_lock:
		# Determine if ID is custom (different from what would be auto-generated)
		var expected_auto_id: String = SparklingEditorUtils.generate_id_from_name(name_value)
		_id_is_locked = (id_value != expected_auto_id) and not id_value.is_empty()
	else:
		# Keep current lock state
		pass

	_update_lock_button_display()
	_updating_ui = false


## Set the lock state explicitly
func set_locked(locked: bool) -> void:
	_id_is_locked = locked
	_update_lock_button_display()
	# If unlocking, regenerate ID from current name
	if not _id_is_locked and _name_edit and _id_edit:
		_id_edit.text = SparklingEditorUtils.generate_id_from_name(_name_edit.text)
		_emit_value_changed()


## Get the current lock state
func is_locked() -> bool:
	return _id_is_locked


## Clear both fields and reset lock state
func clear() -> void:
	_updating_ui = true
	if _name_edit:
		_name_edit.text = ""
	if _id_edit:
		_id_edit.text = ""
	_id_is_locked = false
	_update_lock_button_display()
	_updating_ui = false


## Give focus to the name field
func focus_name() -> void:
	if _name_edit:
		_name_edit.grab_focus()


## Give focus to the ID field
func focus_id() -> void:
	if _id_edit:
		_id_edit.grab_focus()


## Check if either field has focus
func has_field_focus() -> bool:
	if _name_edit and _name_edit.has_focus():
		return true
	if _id_edit and _id_edit.has_focus():
		return true
	return false


## Set help text visibility (for compact layouts)
func set_help_visible(visible: bool) -> void:
	if _help_label:
		_help_label.visible = visible


## Update help text
func set_help_text(text: String) -> void:
	if _help_label:
		_help_label.text = text


# =============================================================================
# INTERNAL HANDLERS
# =============================================================================

func _on_name_text_changed(new_text: String) -> void:
	if _updating_ui:
		return
	# Auto-generate ID if not locked
	if not _id_is_locked and _id_edit:
		_id_edit.text = SparklingEditorUtils.generate_id_from_name(new_text)
	_emit_value_changed()


func _on_id_text_changed(_new_text: String) -> void:
	if _updating_ui:
		return
	# If user is manually typing in the ID field, lock it
	if not _id_is_locked and _id_edit and _id_edit.has_focus():
		_id_is_locked = true
		_update_lock_button_display()
	_emit_value_changed()
	id_changed.emit(get_id_value())


func _on_lock_button_pressed() -> void:
	_id_is_locked = not _id_is_locked
	_update_lock_button_display()
	# If unlocking, regenerate the ID from current name
	if not _id_is_locked and _name_edit and _id_edit:
		_id_edit.text = SparklingEditorUtils.generate_id_from_name(_name_edit.text)
		_emit_value_changed()


func _update_lock_button_display() -> void:
	if not _lock_btn:
		return
	_lock_btn.text = "Unlock" if _id_is_locked else "Lock"
	if _id_is_locked:
		_lock_btn.tooltip_text = "ID is locked. Click to unlock and auto-generate."
	else:
		_lock_btn.tooltip_text = "Click to lock ID and prevent auto-generation"


func _emit_value_changed() -> void:
	value_changed.emit({
		"name": get_name_value(),
		"id": get_id_value()
	})
