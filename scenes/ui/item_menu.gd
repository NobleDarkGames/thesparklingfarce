## ItemMenu - Shining Force style battle item selection menu
##
## Displays character's inventory items for battle use.
## Features keyboard/mouse navigation, item descriptions, and smart defaults.
## Follows ActionMenu patterns for session IDs and signal handling.
class_name ItemMenu
extends Control

## Signals - session_id prevents stale signals from previous turns
signal item_selected(item_id: String, session_id: int)
signal menu_cancelled(session_id: int)

## UI element references (built dynamically)
var _item_labels: Array[Label] = []
var _description_label: Label = null
var _header_label: Label = null
var _panel: ColorRect = null
var _container: VBoxContainer = null

## Inventory data
var _inventory_items: Array[String] = []  ## Item IDs from CharacterSaveData
var _item_data_cache: Array[ItemData] = []  ## Loaded ItemData for each slot

## Current selection
var selected_index: int = 0

## Session ID - stored when menu opens, emitted with signals to prevent stale signals
var _menu_session_id: int = -1

## Hover tracking
var _hover_index: int = -1

## Configuration
var _max_slots: int = 4  ## Default SF-style (4 slots per character)

## Colors (matching ActionMenu pattern)
const COLOR_NORMAL: Color = Color(0.9, 0.9, 0.9, 1.0)  ## Bright white for usable
const COLOR_DISABLED: Color = Color(0.4, 0.4, 0.4, 1.0)  ## Grayed out
const COLOR_EMPTY: Color = Color(0.35, 0.35, 0.35, 1.0)  ## Faded gray for empty
const COLOR_SELECTED: Color = Color(1.0, 1.0, 0.3, 1.0)  ## Bright yellow
const COLOR_HOVER: Color = Color(0.95, 0.95, 0.85, 1.0)  ## Subtle hover highlight
const PANEL_COLOR: Color = Color(0.1, 0.1, 0.15, 0.95)
const BORDER_COLOR: Color = Color(0.8, 0.8, 0.9, 1.0)


func _ready() -> void:
	# Build the UI structure
	_build_ui()

	# Hide by default
	visible = false
	set_process_input(false)
	set_process(false)


## Build the menu UI dynamically
func _build_ui() -> void:
	# Main container with border
	var border: ColorRect = ColorRect.new()
	border.name = "Border"
	border.color = BORDER_COLOR
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(border)

	# Inner panel
	_panel = ColorRect.new()
	_panel.name = "InnerPanel"
	_panel.color = PANEL_COLOR
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 2.0
	_panel.offset_top = 2.0
	_panel.offset_right = -2.0
	_panel.offset_bottom = -2.0
	border.add_child(_panel)

	# VBox for layout
	_container = VBoxContainer.new()
	_container.name = "VBoxContainer"
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.offset_left = 8.0
	_container.offset_top = 8.0
	_container.offset_right = -8.0
	_container.offset_bottom = -8.0
	_panel.add_child(_container)

	# Header label
	_header_label = Label.new()
	_header_label.name = "Header"
	_header_label.text = "Items"
	_header_label.add_theme_font_size_override("font_size", 16)
	_header_label.modulate = COLOR_NORMAL
	_container.add_child(_header_label)

	# Separator
	var separator: HSeparator = HSeparator.new()
	separator.add_theme_constant_override("separation", 4)
	_container.add_child(separator)

	# Item labels will be created dynamically when showing menu

	# Description label at bottom (will be added after item labels)
	_description_label = Label.new()
	_description_label.name = "Description"
	_description_label.text = ""
	_description_label.add_theme_font_size_override("font_size", 16)
	_description_label.modulate = Color(0.7, 0.7, 0.7, 1.0)
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD


## Create item slot labels based on inventory size
func _create_item_labels(slot_count: int) -> void:
	# Clear existing labels
	for label: Label in _item_labels:
		if is_instance_valid(label):
			label.queue_free()
	_item_labels.clear()

	# Remove description label temporarily (we'll re-add at bottom)
	if _description_label.get_parent() == _container:
		_container.remove_child(_description_label)

	# Create new labels
	for i: int in range(slot_count):
		var label: Label = Label.new()
		label.name = "ItemSlot%d" % i
		label.text = "(Empty)"
		label.add_theme_font_size_override("font_size", 16)
		label.modulate = COLOR_EMPTY
		_container.add_child(label)
		_item_labels.append(label)

	# Add separator before description
	var desc_sep: HSeparator = HSeparator.new()
	desc_sep.name = "DescSeparator"
	desc_sep.add_theme_constant_override("separation", 4)
	_container.add_child(desc_sep)

	# Re-add description at bottom
	_container.add_child(_description_label)


func _process(_delta: float) -> void:
	if not visible:
		return

	var new_hover: int = _get_label_index_at_position(get_global_mouse_position())
	if new_hover == _hover_index:
		return

	_hover_index = new_hover
	if new_hover != -1 and new_hover != selected_index:
		AudioManager.play_sfx("cursor_hover", AudioManager.SFXCategory.UI)
	_update_selection_visual()


## Get the index of the label at the given position, or -1 if none
func _get_label_index_at_position(pos: Vector2) -> int:
	for i: int in range(_item_labels.size()):
		if _item_labels[i].get_global_rect().has_point(pos):
			return i
	return -1


## Show menu with unit's inventory
## @param unit: The Unit whose inventory to display
## @param session_id: Turn session ID from InputManager
func show_menu(unit: Unit, session_id: int) -> void:
	_menu_session_id = session_id
	_hover_index = -1

	# Get inventory configuration
	if ModLoader and "inventory_config" in ModLoader:
		_max_slots = ModLoader.inventory_config.get_max_slots()
	else:
		_max_slots = InventoryConfig.DEFAULT_SLOTS_PER_CHARACTER

	# Get inventory from unit's save data
	_load_inventory_from_unit(unit)

	# Create labels if needed
	if _item_labels.size() != _max_slots:
		_create_item_labels(_max_slots)

	# Populate item labels
	_populate_item_labels()

	# Smart default selection
	_select_smart_default(unit)

	# Check if there are any usable items
	var has_usable: bool = _has_any_usable_items()

	# SHINING FORCE AUTHENTIC: Show menu even if empty
	# Player can see their inventory state and press B to cancel
	# This prevents confusion from instant auto-cancel

	# Update visuals
	_update_selection_visual()
	_update_description()

	# Size the menu appropriately
	_resize_menu()

	# Show menu
	visible = true
	set_process_input(true)
	set_process(true)


## Load inventory from unit's save data
func _load_inventory_from_unit(unit: Unit) -> void:
	_inventory_items.clear()
	_item_data_cache.clear()

	# Try to get CharacterSaveData from PartyManager
	var save_data: CharacterSaveData = null

	if unit and unit.character_data:
		# PartyManager may not have get_member_save_data yet
		# For MVP, we'll check if it exists
		var has_method: bool = PartyManager.has_method("get_member_save_data")
		if has_method:
			save_data = PartyManager.get_member_save_data(unit.character_data.character_uid)

	if save_data:
		# Copy inventory from save data
		for item_id: String in save_data.inventory:
			_inventory_items.append(item_id)

	# Pad with empty strings up to max slots
	while _inventory_items.size() < _max_slots:
		_inventory_items.append("")

	# Load ItemData for each slot
	for item_id: String in _inventory_items:
		if item_id.is_empty():
			_item_data_cache.append(null)
		else:
			var item: ItemData = ModLoader.registry.get_item(item_id)
			_item_data_cache.append(item)


## Populate item labels with inventory contents
func _populate_item_labels() -> void:
	for i: int in range(_item_labels.size()):
		var label: Label = _item_labels[i]

		if i < _item_data_cache.size() and _item_data_cache[i]:
			var item: ItemData = _item_data_cache[i]
			label.text = item.item_name
		else:
			label.text = "(Empty)"


## Check if an item at index is usable in battle
func _is_item_usable(index: int) -> bool:
	if index < 0 or index >= _item_data_cache.size():
		return false

	var item: ItemData = _item_data_cache[index]
	if not item:
		return false

	# Only consumables with usable_in_battle = true can be used
	return item.item_type == ItemData.ItemType.CONSUMABLE and item.usable_in_battle


## Check if any usable items exist
func _has_any_usable_items() -> bool:
	for i: int in range(_item_data_cache.size()):
		if _is_item_usable(i):
			return true
	return false


## Smart default selection based on unit state
func _select_smart_default(unit: Unit) -> void:
	# Check if unit is injured (HP < max HP)
	var is_injured: bool = false
	if unit and unit.stats:
		is_injured = unit.stats.current_hp < unit.stats.max_hp

	# If injured, try to select first healing item
	if is_injured:
		for i: int in range(_item_data_cache.size()):
			var item: ItemData = _item_data_cache[i]
			if item and _is_item_usable(i):
				# Check if it's a healing item (has heal effect)
				if item.effect is AbilityData:
					var ability: AbilityData = item.effect as AbilityData
					if ability.ability_type == AbilityData.AbilityType.HEAL:
						selected_index = i
						return

	# Otherwise select first usable item
	for i: int in range(_item_data_cache.size()):
		if _is_item_usable(i):
			selected_index = i
			return

	# Fallback to first slot
	selected_index = 0


## Update visual highlighting
func _update_selection_visual() -> void:
	for i: int in range(_item_labels.size()):
		var label: Label = _item_labels[i]
		var color: Color = _get_item_color(i)
		label.modulate = color

		if i == selected_index:
			label.add_theme_color_override("font_color", color)
		else:
			label.remove_theme_color_override("font_color")


## Get the display color for an item slot
func _get_item_color(index: int) -> Color:
	var is_usable: bool = _is_item_usable(index)
	var is_empty: bool = index >= _item_data_cache.size() or _item_data_cache[index] == null
	var is_selected: bool = index == selected_index
	var is_hovered: bool = index == _hover_index

	if is_selected and (is_usable or is_empty):
		return COLOR_SELECTED
	if is_hovered and (is_usable or is_empty):
		return COLOR_HOVER
	if is_empty:
		return COLOR_EMPTY
	if is_usable:
		return COLOR_NORMAL
	return COLOR_DISABLED


## Update description label based on selected item
func _update_description() -> void:
	if selected_index < 0 or selected_index >= _item_data_cache.size():
		_description_label.text = ""
		return

	var item: ItemData = _item_data_cache[selected_index]
	if not item:
		_description_label.text = ""
		return

	_description_label.text = _build_item_description(item)


## Build description text for an item
func _build_item_description(item: ItemData) -> String:
	var parts: Array[String] = []

	if not item.description.is_empty():
		parts.append(item.description)

	var effect_text: String = _get_ability_effect_text(item.effect)
	if not effect_text.is_empty():
		parts.append(effect_text)

	if parts.is_empty():
		return "Use in battle" if _is_item_usable(selected_index) else "Cannot use in battle"

	return "\n".join(parts)


## Get effect text for an ability (used by item effects)
func _get_ability_effect_text(effect: Resource) -> String:
	if not effect is AbilityData:
		return ""

	var ability: AbilityData = effect as AbilityData
	match ability.ability_type:
		AbilityData.AbilityType.HEAL:
			return "Heals: %d HP" % ability.potency
		AbilityData.AbilityType.ATTACK:
			return "Damage: %d" % ability.potency
		AbilityData.AbilityType.SUPPORT:
			return "Buff effect"
		AbilityData.AbilityType.DEBUFF:
			return "Debuff effect"
	return ""


## Resize menu to fit contents
func _resize_menu() -> void:
	# Base size
	var width: float = 180.0
	var height: float = 60.0  # Header + separator

	# Add height for each item slot
	height += _item_labels.size() * 22.0

	# Add height for description
	height += 40.0

	custom_minimum_size = Vector2(width, height)
	size = custom_minimum_size


## Hide menu
func hide_menu() -> void:
	set_process_input(false)
	set_process(false)
	visible = false
	_hover_index = -1


## Reset menu to clean state
func reset_menu() -> void:
	set_process_input(false)
	set_process(false)

	_inventory_items.clear()
	_item_data_cache.clear()
	selected_index = 0
	_menu_session_id = -1
	_hover_index = -1

	visible = false


## Handle input
func _input(event: InputEvent) -> void:
	if not visible:
		return

	if _handle_mouse_click(event):
		return

	_handle_keyboard_input(event)


## Handle mouse click input, returns true if handled
func _handle_mouse_click(event: InputEvent) -> bool:
	if not event is InputEventMouseButton:
		return false

	var mouse_event: InputEventMouseButton = event
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return false

	var clicked_index: int = _get_label_index_at_position(get_global_mouse_position())
	if clicked_index >= 0:
		selected_index = clicked_index
		_update_selection_visual()
		_update_description()
		_try_confirm_selection()
		get_viewport().set_input_as_handled()
		return true

	return false


## Handle keyboard navigation input
func _handle_keyboard_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_try_confirm_selection()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("sf_cancel"):
		_cancel_menu()
		get_viewport().set_input_as_handled()


## Move selection up or down
func _move_selection(direction: int) -> void:
	var start_index: int = selected_index

	# Loop through items to find next selectable one
	for _i: int in range(_item_labels.size()):
		selected_index = wrapi(selected_index + direction, 0, _item_labels.size())

		# Allow selecting any slot (for visual feedback), but only usable items can be confirmed
		if selected_index != start_index:
			AudioManager.play_sfx("cursor_move", AudioManager.SFXCategory.UI)
			_update_selection_visual()
			_update_description()
			return


## Try to confirm current selection
func _try_confirm_selection() -> void:
	# Safety checks
	if not is_processing_input():
		return
	if not visible:
		return

	# Check if selected item is usable
	if not _is_item_usable(selected_index):
		# Play error sound - can't use this item
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		return

	# Get the item ID
	var item_id: String = _inventory_items[selected_index]

	if item_id.is_empty():
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		return

	# Play confirm sound
	AudioManager.play_sfx("menu_confirm", AudioManager.SFXCategory.UI)

	# Emit selection signal before hiding
	var emit_session_id: int = _menu_session_id
	item_selected.emit(item_id, emit_session_id)
	hide_menu()


## Cancel menu and return to action menu
func _cancel_menu() -> void:
	# Play cancel sound
	AudioManager.play_sfx("menu_cancel", AudioManager.SFXCategory.UI)

	# Emit cancel signal before hiding
	var emit_session_id: int = _menu_session_id
	menu_cancelled.emit(emit_session_id)
	hide_menu()
