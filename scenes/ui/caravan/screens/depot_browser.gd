extends "res://scenes/ui/caravan/screens/caravan_screen_base.gd"

## DepotBrowser - Browse depot items and select one to take
##
## Features:
## - Grid of depot items
## - L/R bumper: cycle filter (All/Weapons/Armor/Accessories/Consumables)
## - Select item -> push to char_select to choose recipient

## Filter types in order
const FILTER_TYPES: Array[String] = ["", "weapon", "armor", "accessory", "consumable"]
const FILTER_LABELS: Array[String] = ["All", "Weapons", "Armor", "Accessories", "Consumables"]

## Sort types in order
const SORT_TYPES: Array[String] = ["none", "name", "type", "value"]
const SORT_LABELS: Array[String] = ["--", "Name", "Type", "Value"]

## Current filter index
var filter_index: int = 0

## Current sort index
var sort_index: int = 0

## Item button references
var item_buttons: Array[Button] = []

## Currently focused item index
var focused_item_index: int = 0


@onready var filter_label: Label = %FilterLabel
@onready var sort_label: Label = %SortLabel
@onready var item_grid: GridContainer = %ItemGrid
@onready var item_scroll: ScrollContainer = %ItemScroll
@onready var item_name_label: Label = %ItemNameLabel
@onready var item_desc_label: Label = %ItemDescLabel
@onready var take_button: Button = %TakeButton
@onready var back_button: Button = %BackButton
@onready var item_count_label: Label = %ItemCountLabel


func _on_initialized() -> void:
	# Restore filter/sort from context
	if context:
		var filter_found: int = FILTER_TYPES.find(context.depot_filter)
		if filter_found >= 0:
			filter_index = filter_found
		var sort_found: int = SORT_TYPES.find(context.depot_sort)
		if sort_found >= 0:
			sort_index = sort_found

	_update_filter_label()
	_update_sort_label()
	_populate_item_grid()
	_update_details_panel("")

	# Connect buttons
	take_button.pressed.connect(_on_take_pressed)
	back_button.pressed.connect(_on_back_pressed)

	take_button.disabled = true


func _input(event: InputEvent) -> void:
	if not visible:
		return

	# L/R bumpers for filter cycling (shoulder buttons optional - may not be mapped)
	var left_shoulder: bool = InputMap.has_action("sf_left_shoulder") and event.is_action_pressed("sf_left_shoulder")
	var right_shoulder: bool = InputMap.has_action("sf_right_shoulder") and event.is_action_pressed("sf_right_shoulder")

	if left_shoulder or event.is_action_pressed("ui_page_up"):
		_cycle_filter(-1)
		get_viewport().set_input_as_handled()
	elif right_shoulder or event.is_action_pressed("ui_page_down"):
		_cycle_filter(1)
		get_viewport().set_input_as_handled()
	# Triggers for sort cycling (or use Select button)
	elif event.is_action_pressed("ui_home"):  # Can map to select/back button
		_cycle_sort(1)
		get_viewport().set_input_as_handled()


func _cycle_filter(delta: int) -> void:
	filter_index = (filter_index + delta + FILTER_TYPES.size()) % FILTER_TYPES.size()
	if context:
		context.depot_filter = FILTER_TYPES[filter_index]
	_update_filter_label()
	_populate_item_grid()
	play_sfx("cursor_move")


func _cycle_sort(delta: int) -> void:
	sort_index = (sort_index + delta + SORT_TYPES.size()) % SORT_TYPES.size()
	if context:
		context.depot_sort = SORT_TYPES[sort_index]
	_update_sort_label()
	_populate_item_grid()
	play_sfx("cursor_move")


func _update_filter_label() -> void:
	if filter_label:
		filter_label.text = "Filter: %s (L/R)" % FILTER_LABELS[filter_index]


func _update_sort_label() -> void:
	if sort_label:
		sort_label.text = "Sort: %s" % SORT_LABELS[sort_index]


func _populate_item_grid() -> void:
	_clear_container(item_grid)
	item_buttons.clear()

	# Get filtered items from context
	var items: Array[String] = get_filtered_depot_items()

	# Update count label
	var total: int = get_depot_size()
	if filter_index == 0:
		item_count_label.text = "%d items" % total
	else:
		item_count_label.text = "%d/%d items" % [items.size(), total]

	# Create buttons for each item
	for item_id: String in items:
		var item_data: ItemData = get_item_data(item_id)
		if not item_data:
			continue

		var button: Button = _create_item_button(item_id, item_data)
		item_grid.add_child(button)
		item_buttons.append(button)

		button.pressed.connect(_on_item_pressed.bind(item_id))
		button.focus_entered.connect(_on_item_focus_entered.bind(item_id, item_buttons.size() - 1))

	# Handle empty depot - focus BACK button so user can exit
	if item_buttons.is_empty():
		_update_details_panel("")
		take_button.disabled = true
		await get_tree().process_frame
		if is_instance_valid(self) and is_instance_valid(back_button):
			back_button.grab_focus()
		return

	# Focus first item
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	if item_buttons.size() > 0 and is_instance_valid(item_buttons[0]):
		item_buttons[0].grab_focus()
		focused_item_index = 0


func _create_item_button(item_id: String, item_data: ItemData) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(100, 32)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 16)

	# Show item name
	button.text = item_data.item_name
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT

	# Add type icon prefix based on type
	var type_prefix: String = ""
	match item_data.item_type:
		ItemData.ItemType.WEAPON:
			type_prefix = "[W] "
		ItemData.ItemType.ACCESSORY:
			type_prefix = "[A] "  # Accessories (rings, etc.)
		ItemData.ItemType.CONSUMABLE:
			type_prefix = "[I] "
	button.text = type_prefix + item_data.item_name

	return button


func _on_item_focus_entered(item_id: String, index: int) -> void:
	focused_item_index = index
	_update_details_panel(item_id)
	play_sfx("cursor_move")


func _on_item_pressed(item_id: String) -> void:
	# Select this item and proceed to character select
	if context:
		context.selected_depot_item_id = item_id
	play_sfx("menu_select")
	push_screen("char_select")


func _update_details_panel(item_id: String) -> void:
	if item_id.is_empty():
		item_name_label.text = "No items"
		item_desc_label.text = "Depot is empty" if get_depot_size() == 0 else "No items match filter"
		take_button.disabled = true
		return

	var item_data: ItemData = get_item_data(item_id)
	if not item_data:
		item_name_label.text = "Unknown"
		item_desc_label.text = item_id
		take_button.disabled = true
		return

	item_name_label.text = item_data.item_name.to_upper()

	# Build description with stats
	var desc_lines: Array[String] = []
	if not item_data.description.is_empty():
		desc_lines.append(item_data.description)

	# Add stats
	if item_data.item_type == ItemData.ItemType.WEAPON and item_data.attack_power > 0:
		desc_lines.append("AT: %d" % item_data.attack_power)
	if item_data.defense_modifier > 0:
		desc_lines.append("DF: %d" % item_data.defense_modifier)

	item_desc_label.text = "\n".join(desc_lines) if desc_lines.size() > 0 else "No description"

	# Enable take button and store the item_id for when pressed
	take_button.disabled = false
	take_button.text = "TAKE"


func _on_take_pressed() -> void:
	# Use currently focused item
	if focused_item_index >= 0 and focused_item_index < item_buttons.size():
		var items: Array[String] = get_filtered_depot_items()
		if focused_item_index < items.size():
			var item_id: String = items[focused_item_index]
			if context:
				context.selected_depot_item_id = item_id
			play_sfx("menu_select")
			push_screen("char_select")


func _on_back_pressed() -> void:
	go_back()


func _on_screen_exit() -> void:
	# Clean up connections
	if is_instance_valid(take_button) and take_button.pressed.is_connected(_on_take_pressed):
		take_button.pressed.disconnect(_on_take_pressed)
	if is_instance_valid(back_button) and back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.disconnect(_on_back_pressed)
