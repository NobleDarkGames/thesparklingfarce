@tool
class_name ListEditor
extends VBoxContainer

## Reusable component for master-detail list patterns
##
## This component provides a standard UI pattern consisting of:
## - An ItemList showing all items (the "master" list)
## - A detail panel below for editing the selected item
## - Add/Remove/Update buttons
##
## Unlike DynamicRowList (which embeds fields IN each row), ListEditor
## shows a single editable detail view for the currently selected item.
## This is better for items with many fields that won't fit in a row.
##
## Usage:
##   var list_editor: ListEditor = ListEditor.new()
##   list_editor.add_button_text = "Add Slot"
##   list_editor.detail_builder = _build_slot_fields
##   list_editor.display_formatter = _format_slot_display
##   list_editor.data_factory = func() -> Dictionary: return {"id": "", "name": ""}
##   parent.add_child(list_editor)
##
##   # Load existing data
##   list_editor.load_data([{id = "weapon", name = "Weapon"}, ...])
##
##   # Get current data for saving
##   var data: Array[Dictionary] = list_editor.get_all_data()
##
## Detail Builder Function Signature:
##   func _build_detail(form: FormBuilder, data: Dictionary) -> Dictionary:
##     # Add fields to form and return a mapping of field_name -> Control
##     var fields: Dictionary = {}
##     fields["id"] = form.add_text_field("ID:", "placeholder")
##     fields["id"].text = data.get("id", "")
##     return fields
##
## Display Formatter Function Signature:
##   func _format_display(data: Dictionary, index: int) -> String:
##     return "%d. %s" % [index + 1, data.get("name", "Unnamed")]
##
## Data Extractor Function Signature (optional, auto-extracts if not set):
##   func _extract_data(fields: Dictionary) -> Dictionary:
##     return {id = fields.id.text, name = fields.name.text}
##
## Data Factory Function Signature:
##   func _create_new() -> Dictionary:
##     return {"id": "", "name": "", "types": []}

## Emitted when an item is selected (passes item index)
signal item_selected(index: int)

## Emitted when an item is deselected
signal item_deselected()

## Emitted when data changes (item added, removed, updated)
signal data_changed()

## Emitted when item count changes
signal item_count_changed(count: int)

# =============================================================================
# CONFIGURATION (set before adding to tree)
# =============================================================================

## Function that builds the detail form fields.
## Signature: (form: FormBuilder, data: Dictionary) -> Dictionary[String, Control]
var detail_builder: Callable = Callable()

## Function that formats item display text for the list.
## Signature: (data: Dictionary, index: int) -> String
var display_formatter: Callable = Callable()

## Function that extracts data from the detail fields (optional).
## If not set, auto-extracts based on control types.
## Signature: (fields: Dictionary) -> Dictionary
var data_extractor: Callable = Callable()

## Function that creates a new item with default values.
## Signature: () -> Dictionary
var data_factory: Callable = Callable()

## Text for the Add button
@export var add_button_text: String = "Add":
	set(value):
		add_button_text = value
		if _add_button:
			_add_button.text = value

## Text for the Remove button
@export var remove_button_text: String = "Remove":
	set(value):
		remove_button_text = value
		if _remove_button:
			_remove_button.text = value

## Text for the Update button
@export var update_button_text: String = "Update":
	set(value):
		update_button_text = value
		if _update_button:
			_update_button.text = value

## Whether to show the Update button (some patterns auto-update)
@export var show_update_button: bool = true

## Whether to show numbered items in the list
@export var show_item_numbers: bool = true

## Minimum height for the ItemList
@export var list_min_height: int = 100

## Label width for detail form fields
@export var label_width: int = 120

## Placeholder text when no item is selected
@export var empty_selection_text: String = "Select an item to edit":
	set(value):
		empty_selection_text = value
		if _placeholder_label and _selected_index < 0:
			_placeholder_label.text = value

## Whether clicking an already-selected item deselects it
@export var allow_deselect: bool = true

# =============================================================================
# INTERNAL STATE
# =============================================================================

var _item_list: ItemList
var _detail_container: VBoxContainer
var _button_container: HBoxContainer
var _add_button: Button
var _remove_button: Button
var _update_button: Button
var _placeholder_label: Label

var _data: Array[Dictionary] = []
var _selected_index: int = -1
var _current_fields: Dictionary = {}  # field_name -> Control
var _updating_ui: bool = false


func _init() -> void:
	add_theme_constant_override("separation", 4)


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# ItemList
	_item_list = ItemList.new()
	_item_list.custom_minimum_size.y = list_min_height
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_list.item_selected.connect(_on_item_selected)
	_item_list.allow_reselect = true
	add_child(_item_list)

	# Detail container (will be populated when item is selected)
	_detail_container = VBoxContainer.new()
	_detail_container.add_theme_constant_override("separation", 8)
	_detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_detail_container)

	# Placeholder text
	_placeholder_label = Label.new()
	_placeholder_label.text = empty_selection_text
	_placeholder_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	_placeholder_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	_detail_container.add_child(_placeholder_label)

	# Button row
	_button_container = HBoxContainer.new()
	_button_container.add_theme_constant_override("separation", 8)
	add_child(_button_container)

	_add_button = Button.new()
	_add_button.text = add_button_text
	_add_button.pressed.connect(_on_add_pressed)
	_button_container.add_child(_add_button)

	_remove_button = Button.new()
	_remove_button.text = remove_button_text
	_remove_button.disabled = true
	_remove_button.pressed.connect(_on_remove_pressed)
	_button_container.add_child(_remove_button)

	if show_update_button:
		_update_button = Button.new()
		_update_button.text = update_button_text
		_update_button.disabled = true
		_update_button.pressed.connect(_on_update_pressed)
		_button_container.add_child(_update_button)


# =============================================================================
# PUBLIC API
# =============================================================================

## Load data from an array of dictionaries
func load_data(data_array: Array) -> void:
	_data.clear()
	for item: Variant in data_array:
		if item is Dictionary:
			_data.append(item.duplicate(true))

	_selected_index = -1
	_rebuild_list()
	_clear_detail()
	item_count_changed.emit(_data.size())


## Get all data as an array of dictionaries
func get_all_data() -> Array[Dictionary]:
	# Ensure currently selected item is up-to-date
	_save_current_selection()
	return _data.duplicate(true)


## Get the currently selected item's data
func get_selected_data() -> Dictionary:
	if _selected_index >= 0 and _selected_index < _data.size():
		return _data[_selected_index].duplicate(true)
	return {}


## Get the current selection index (-1 if none)
func get_selected_index() -> int:
	return _selected_index


## Get the item count
func get_item_count() -> int:
	return _data.size()


## Select an item by index
func select_item(index: int) -> void:
	if index >= 0 and index < _data.size():
		_item_list.select(index)
		_on_item_selected(index)
	elif index < 0:
		_item_list.deselect_all()
		_selected_index = -1
		_clear_detail()
		_update_buttons()
		item_deselected.emit()


## Clear selection
func deselect() -> void:
	select_item(-1)


## Add a new item (uses data_factory if set, otherwise empty dict)
func add_item(data: Dictionary = {}) -> int:
	var new_data: Dictionary = data
	if new_data.is_empty() and data_factory.is_valid():
		new_data = data_factory.call()

	_data.append(new_data)
	_rebuild_list()

	var new_index: int = _data.size() - 1
	item_count_changed.emit(_data.size())
	data_changed.emit()

	return new_index


## Remove an item by index
func remove_item(index: int) -> void:
	if index < 0 or index >= _data.size():
		return

	_data.remove_at(index)

	# Adjust selection
	if _selected_index == index:
		_selected_index = -1
		_clear_detail()
		item_deselected.emit()
	elif _selected_index > index:
		_selected_index -= 1

	_rebuild_list()
	_update_buttons()

	# Restore selection in list if still valid
	if _selected_index >= 0:
		_item_list.select(_selected_index)

	item_count_changed.emit(_data.size())
	data_changed.emit()


## Update the currently selected item with data from detail fields
func update_selected() -> void:
	_save_current_selection()
	_rebuild_list()
	if _selected_index >= 0:
		_item_list.select(_selected_index)
	data_changed.emit()


## Clear all items
func clear() -> void:
	_data.clear()
	_selected_index = -1
	_rebuild_list()
	_clear_detail()
	item_count_changed.emit(0)
	data_changed.emit()


## Refresh the list display without changing data
func refresh_list() -> void:
	_rebuild_list()
	if _selected_index >= 0 and _selected_index < _item_list.item_count:
		_item_list.select(_selected_index)


## Enable or disable the entire list editor
## When disabled, the list and all buttons become non-interactive
func set_enabled(enabled: bool) -> void:
	if _item_list:
		_item_list.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
		_item_list.modulate.a = 1.0 if enabled else 0.5
	if _add_button:
		_add_button.disabled = not enabled
	if _remove_button:
		_remove_button.disabled = not enabled
	if _update_button:
		_update_button.disabled = not enabled
	if _detail_container:
		_detail_container.modulate.a = 1.0 if enabled else 0.5
		_set_container_enabled(_detail_container, enabled)


## Recursively enable/disable controls in a container
func _set_container_enabled(container: Control, enabled: bool) -> void:
	for child: Node in container.get_children():
		if child is Button:
			child.disabled = not enabled
		elif child is LineEdit or child is TextEdit:
			child.editable = enabled
		elif child is OptionButton or child is SpinBox or child is CheckBox:
			child.disabled = not enabled
		elif child is Control:
			_set_container_enabled(child, enabled)


# =============================================================================
# INTERNAL METHODS
# =============================================================================

func _rebuild_list() -> void:
	_item_list.clear()

	for i: int in range(_data.size()):
		var item_data: Dictionary = _data[i]
		var display_text: String

		if display_formatter.is_valid():
			display_text = display_formatter.call(item_data, i)
		else:
			# Default formatting
			if show_item_numbers:
				display_text = "%d. %s" % [i + 1, str(item_data)]
			else:
				display_text = str(item_data)

		_item_list.add_item(display_text)


func _on_item_selected(index: int) -> void:
	# Handle deselect on re-click
	if allow_deselect and index == _selected_index:
		_item_list.deselect_all()
		_save_current_selection()
		_selected_index = -1
		_clear_detail()
		_update_buttons()
		item_deselected.emit()
		return

	# Save previous selection before switching
	_save_current_selection()

	_selected_index = index
	_build_detail_for_item(index)
	_update_buttons()
	item_selected.emit(index)


func _save_current_selection() -> void:
	if _selected_index < 0 or _selected_index >= _data.size():
		return
	if _current_fields.is_empty():
		return

	var extracted: Dictionary = _extract_data_from_fields()
	if not extracted.is_empty():
		_data[_selected_index] = extracted


func _extract_data_from_fields() -> Dictionary:
	if _current_fields.is_empty():
		return {}

	# Use custom extractor if provided
	if data_extractor.is_valid():
		return data_extractor.call(_current_fields)

	# Auto-extract based on control types
	var result: Dictionary = {}
	for field_name: String in _current_fields.keys():
		var control: Control = _current_fields[field_name]
		result[field_name] = _extract_value_from_control(control)

	return result


func _extract_value_from_control(control: Control) -> Variant:
	if control is LineEdit:
		return control.text
	elif control is TextEdit:
		return control.text
	elif control is SpinBox:
		return control.value
	elif control is CheckBox:
		return control.button_pressed
	elif control is OptionButton:
		# Return metadata if set, otherwise index
		var idx: int = control.selected
		if idx >= 0:
			var metadata: Variant = control.get_item_metadata(idx)
			if metadata != null:
				return metadata
		return idx
	elif control is ColorPickerButton:
		return control.color
	elif control.has_method("get_value"):
		return control.get_value()
	elif control.has_method("get_selected_resource"):
		return control.get_selected_resource()
	else:
		push_warning("ListEditor: Unknown control type for auto-extraction: %s" % control.get_class())
		return null


func _build_detail_for_item(index: int) -> void:
	if index < 0 or index >= _data.size():
		_clear_detail()
		return

	# Clear existing detail UI
	for child: Node in _detail_container.get_children():
		_detail_container.remove_child(child)
		child.queue_free()

	_current_fields.clear()

	var item_data: Dictionary = _data[index]

	# Build detail fields using the builder callback
	if detail_builder.is_valid():
		var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(_detail_container, label_width)
		_current_fields = detail_builder.call(form, item_data)
	else:
		# No builder - show placeholder
		var label: Label = Label.new()
		label.text = "No detail_builder configured"
		label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
		_detail_container.add_child(label)


func _clear_detail() -> void:
	for child: Node in _detail_container.get_children():
		_detail_container.remove_child(child)
		child.queue_free()

	_current_fields.clear()

	# Show placeholder
	_placeholder_label = Label.new()
	_placeholder_label.text = empty_selection_text
	_placeholder_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	_placeholder_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	_detail_container.add_child(_placeholder_label)


func _update_buttons() -> void:
	var has_selection: bool = _selected_index >= 0
	_remove_button.disabled = not has_selection
	if _update_button:
		_update_button.disabled = not has_selection


func _on_add_pressed() -> void:
	var new_index: int = add_item()
	# Select the new item
	select_item(new_index)


func _on_remove_pressed() -> void:
	if _selected_index >= 0:
		remove_item(_selected_index)


func _on_update_pressed() -> void:
	update_selected()


# =============================================================================
# UTILITY - COMMON FIELD PATTERNS
# =============================================================================

## Helper to populate an OptionButton field from the detail_builder
## Returns the OptionButton for easy chaining
static func populate_dropdown(dropdown: OptionButton, options: Array, selected_value: Variant = null) -> OptionButton:
	dropdown.clear()
	var selected_idx: int = 0

	for i: int in range(options.size()):
		var opt: Variant = options[i]
		if opt is Dictionary:
			var label: String = opt.get("label", str(opt))
			var value: Variant = opt.get("value", i)
			dropdown.add_item(label, i)
			dropdown.set_item_metadata(i, value)
			if selected_value != null and value == selected_value:
				selected_idx = i
		else:
			dropdown.add_item(str(opt), i)
			dropdown.set_item_metadata(i, opt)
			if selected_value != null and opt == selected_value:
				selected_idx = i

	if dropdown.item_count > 0:
		dropdown.selected = selected_idx

	return dropdown
