@tool
class_name DynamicRowList
extends VBoxContainer

## Reusable component for managing dynamic lists of rows with add/remove functionality
##
## This component consolidates the common pattern of:
## - Creating dynamic rows with Remove buttons
## - Adding items to a VBoxContainer
## - Loading existing data into rows
## - Collecting data from rows on save
##
## Usage:
##   var row_list: DynamicRowList = DynamicRowList.new()
##   row_list.row_factory = _create_ability_row
##   row_list.data_extractor = _extract_ability_data
##   row_list.add_button_text = "Add Ability"
##   parent.add_child(row_list)
##
##   # Load existing data
##   row_list.load_data([{level = 1, ability_id = "heal"}, ...])
##
##   # Get current data for saving
##   var data: Array[Dictionary] = row_list.get_all_data()
##
## Row Factory Function Signature:
##   func _create_row(data: Dictionary, row_container: HBoxContainer) -> void:
##     # Populate row_container with your UI elements
##     # data is the item data (empty dict for new rows)
##
## Data Extractor Function Signature:
##   func _extract_data(row_container: HBoxContainer) -> Dictionary:
##     # Return the data from this row's UI elements
##     # Return empty dict {} to skip this row

## Emitted when a row is added (passes the row container)
signal row_added(row: HBoxContainer)

## Emitted when a row is removed (passes the row container before removal)
signal row_removed(row: HBoxContainer)

## Emitted when any data changes (row added, removed, or content edited)
signal data_changed()

## Emitted when row count changes (useful for validation)
signal row_count_changed(count: int)

# Configuration (set before adding to tree)

## Factory function that creates row content. Signature: (data: Dictionary, row: HBoxContainer) -> void
var row_factory: Callable = Callable()

## Function that extracts data from a row. Signature: (row: HBoxContainer) -> Dictionary
var data_extractor: Callable = Callable()

## Text for the Add button
@export var add_button_text: String = "Add Row":
	set(value):
		add_button_text = value
		if _add_button:
			_add_button.text = value

## Tooltip for the Add button
@export var add_button_tooltip: String = "":
	set(value):
		add_button_tooltip = value
		if _add_button:
			_add_button.tooltip_text = value

## Whether to show numbered headers for rows (e.g., "Enemy #1", "Enemy #2")
@export var show_row_numbers: bool = false

## Prefix for row number headers (e.g., "Enemy" -> "Enemy #1")
@export var row_number_prefix: String = "Item"

## Whether rows can be reordered (future feature, currently not implemented)
@export var allow_reorder: bool = false

## Whether to show remove button on each row
@export var show_remove_buttons: bool = true

## Text for remove buttons
@export var remove_button_text: String = "X"

## Minimum number of rows (prevents removing below this count)
@export var min_rows: int = 0

## Maximum number of rows (0 = unlimited)
@export var max_rows: int = 0

## Whether to wrap rows in a ScrollContainer
@export var use_scroll_container: bool = false

## Minimum height for scroll container (if used)
@export var scroll_min_height: int = 100

## Spacing between rows
@export var row_spacing: int = 4

# Internal state
var _rows_container: VBoxContainer
var _add_button: Button
var _scroll_container: ScrollContainer
var _row_list: Array[HBoxContainer] = []


func _init() -> void:
	add_theme_constant_override("separation", 4)


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Create rows container (optionally wrapped in scroll)
	_rows_container = VBoxContainer.new()
	_rows_container.add_theme_constant_override("separation", row_spacing)
	_rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if use_scroll_container:
		_scroll_container = ScrollContainer.new()
		_scroll_container.custom_minimum_size.y = scroll_min_height
		_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_scroll_container.add_child(_rows_container)
		add_child(_scroll_container)
	else:
		add_child(_rows_container)

	# Create add button
	_add_button = Button.new()
	_add_button.text = add_button_text
	_add_button.tooltip_text = add_button_tooltip
	_add_button.pressed.connect(_on_add_button_pressed)
	add_child(_add_button)


# =============================================================================
# PUBLIC API
# =============================================================================

## Add a new row with the given data (empty dict for blank row)
func add_row(data: Dictionary = {}) -> HBoxContainer:
	if max_rows > 0 and _row_list.size() >= max_rows:
		push_warning("DynamicRowList: Maximum row count reached (%d)" % max_rows)
		return null

	var row: HBoxContainer = _create_row_container(data)
	_rows_container.add_child(row)
	_row_list.append(row)

	_update_row_numbers()
	_update_add_button_visibility()

	row_added.emit(row)
	row_count_changed.emit(_row_list.size())
	data_changed.emit()

	return row


## Remove a specific row
func remove_row(row: HBoxContainer) -> void:
	if not row in _row_list:
		push_warning("DynamicRowList: Row not found in list")
		return

	if _row_list.size() <= min_rows:
		push_warning("DynamicRowList: Cannot remove row, minimum count reached (%d)" % min_rows)
		return

	row_removed.emit(row)
	_row_list.erase(row)
	_rows_container.remove_child(row)
	row.queue_free()

	_update_row_numbers()
	_update_add_button_visibility()

	row_count_changed.emit(_row_list.size())
	data_changed.emit()


## Clear all rows
func clear_rows() -> void:
	for row: HBoxContainer in _row_list.duplicate():
		row_removed.emit(row)
		_rows_container.remove_child(row)
		row.queue_free()

	_row_list.clear()
	_update_add_button_visibility()

	row_count_changed.emit(0)
	data_changed.emit()


## Load data from an array of dictionaries (clears existing rows first)
func load_data(data_array: Array) -> void:
	clear_rows()

	for item: Variant in data_array:
		if item is Dictionary:
			add_row(item)


## Get all data from current rows as an array of dictionaries
## Rows that return empty dicts from the extractor are skipped
func get_all_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if not data_extractor.is_valid():
		push_warning("DynamicRowList: No data_extractor set, returning empty array")
		return result

	for row: HBoxContainer in _row_list:
		var row_data: Dictionary = data_extractor.call(row)
		if not row_data.is_empty():
			result.append(row_data)

	return result


## Get the current row count
func get_row_count() -> int:
	return _row_list.size()


## Get a specific row by index
func get_row(index: int) -> HBoxContainer:
	if index >= 0 and index < _row_list.size():
		return _row_list[index]
	return null


## Get all row containers
func get_all_rows() -> Array[HBoxContainer]:
	return _row_list.duplicate()


## Manually trigger a data_changed signal (useful when row content changes)
func notify_data_changed() -> void:
	data_changed.emit()


## Check if empty (no rows or all rows have empty data)
func is_empty() -> bool:
	if _row_list.is_empty():
		return true

	# Check if any row has actual data
	var all_data: Array[Dictionary] = get_all_data()
	return all_data.is_empty()


# =============================================================================
# INTERNAL METHODS
# =============================================================================

func _create_row_container(data: Dictionary) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Add row number label if enabled
	if show_row_numbers:
		var index_label: Label = Label.new()
		index_label.name = "RowNumberLabel"
		index_label.text = "%s #%d" % [row_number_prefix, _row_list.size() + 1]
		index_label.custom_minimum_size.x = 80
		row.add_child(index_label)

	# Call factory to populate the row
	if row_factory.is_valid():
		row_factory.call(data, row)
	else:
		push_warning("DynamicRowList: No row_factory set, creating empty row")

	# Add remove button
	if show_remove_buttons:
		var remove_btn: Button = Button.new()
		remove_btn.name = "RemoveButton"
		remove_btn.text = remove_button_text
		remove_btn.tooltip_text = "Remove this row"
		remove_btn.custom_minimum_size.x = 30
		remove_btn.pressed.connect(_on_remove_row.bind(row))
		row.add_child(remove_btn)

	return row


func _on_add_button_pressed() -> void:
	add_row({})


func _on_remove_row(row: HBoxContainer) -> void:
	remove_row(row)


func _update_row_numbers() -> void:
	if not show_row_numbers:
		return

	for i: int in range(_row_list.size()):
		var row: HBoxContainer = _row_list[i]
		var label: Label = row.get_node_or_null("RowNumberLabel") as Label
		if label:
			label.text = "%s #%d" % [row_number_prefix, i + 1]


func _update_add_button_visibility() -> void:
	if not _add_button:
		return

	# Disable add button if at max rows
	if max_rows > 0 and _row_list.size() >= max_rows:
		_add_button.disabled = true
		_add_button.tooltip_text = "Maximum rows reached (%d)" % max_rows
	else:
		_add_button.disabled = false
		_add_button.tooltip_text = add_button_tooltip


# =============================================================================
# UTILITY - COMMON ROW PATTERNS
# =============================================================================
# These static methods help build common row UI patterns

## Create a SpinBox for level/quantity fields
static func create_level_spinbox(row: HBoxContainer, name: String, min_val: int, max_val: int, default_val: int, tooltip: String = "") -> SpinBox:
	var spin: SpinBox = SpinBox.new()
	spin.name = name
	spin.min_value = min_val
	spin.max_value = max_val
	spin.value = default_val
	spin.custom_minimum_size.x = 70
	if not tooltip.is_empty():
		spin.tooltip_text = tooltip
	row.add_child(spin)
	return spin


## Create a label for row UI
static func create_label(row: HBoxContainer, text: String, min_width: int = 0) -> Label:
	var label: Label = Label.new()
	label.text = text
	if min_width > 0:
		label.custom_minimum_size.x = min_width
	row.add_child(label)
	return label
