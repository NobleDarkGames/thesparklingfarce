class_name ItemActionMenu
extends Control

## ItemActionMenu - Context-sensitive item action sub-menu
##
## Displays available actions for a selected item based on:
## - Item type (consumable, equipment, key item)
## - Context (exploration vs battle)
## - Item properties (can_be_dropped, usable_on_field)
##
## Follows ActionMenu patterns for navigation and visual style.
##
## Actions:
## - Use: For consumables with usable_on_field (exploration) or usable_in_battle
## - Equip: For equippable items (exploration only, unless battle_equip enabled)
## - Give: Transfer to another party member (exploration only)
## - Drop: Discard item (if can_be_dropped is true)
## - Info: Show detailed item information (always available)

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when an action is selected
## action: "use", "equip", "give", "drop", "info"
signal action_selected(action: String, item_id: String)

## Emitted when menu is cancelled
signal menu_cancelled()

# =============================================================================
# ENUMS
# =============================================================================

enum Context {
	EXPLORATION,      ## Field/exploration mode - item in inventory
	BATTLE,           ## During battle
	EQUIPMENT_SLOT,   ## Item currently equipped (for unequip action)
	FIELD_MENU        ## Field menu item - no GIVE action (transfers are Caravan-only)
}

enum ActionType {
	USE,
	EQUIP,
	UNEQUIP,
	GIVE,
	DROP,
	INFO
}

# =============================================================================
# CONSTANTS
# =============================================================================

const COLOR_PANEL_BG: Color = Color(0.1, 0.1, 0.15, 0.98)
const COLOR_BORDER: Color = Color(0.6, 0.6, 0.7, 1.0)
const COLOR_NORMAL: Color = Color(0.8, 0.8, 0.8, 1.0)
const COLOR_DISABLED: Color = Color(0.4, 0.4, 0.4, 1.0)
const COLOR_SELECTED: Color = Color(1.0, 1.0, 0.3, 1.0)
const COLOR_HOVER: Color = Color(0.95, 0.95, 0.85, 1.0)
const COLOR_ITEM_NAME: Color = Color(1.0, 1.0, 0.9, 1.0)

const MONOGRAM_FONT: Font = preload("res://assets/fonts/monogram.ttf")

# Action display names (typed array indexed by ActionType enum values)
const ACTION_NAMES: Array[String] = ["Use", "Equip", "Unequip", "Give", "Drop", "Info"]

# =============================================================================
# STATE
# =============================================================================

## Current item being acted on
var _current_item_id: String = ""
var _current_item_data: ItemData = null

## Current context (exploration or battle)
var _context: Context = Context.EXPLORATION

## Available actions for current item
var _available_actions: Array[ActionType] = []

## Currently selected action index
var _selected_index: int = 0

## Whether menu is currently showing
var _is_showing: bool = false

## Hover tracking
var _hover_index: int = -1

# =============================================================================
# UI REFERENCES
# =============================================================================

var _panel: PanelContainer = null
var _item_name_label: Label = null
var _actions_container: VBoxContainer = null
var _action_labels: Array[Label] = []

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_build_ui()
	visible = false
	set_process_input(false)
	set_process(false)


func _create_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_content_margin_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style


func _build_ui() -> void:
	# Panel container
	_panel = PanelContainer.new()
	_panel.name = "ActionPanel"
	_panel.custom_minimum_size = Vector2(80, 40)
	_panel.add_theme_stylebox_override("panel", _create_panel_style())
	add_child(_panel)

	# Main layout
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	_panel.add_child(vbox)

	# Item name header
	_item_name_label = Label.new()
	_item_name_label.name = "ItemNameLabel"
	_item_name_label.add_theme_font_override("font", MONOGRAM_FONT)
	_item_name_label.add_theme_font_size_override("font_size", 16)
	_item_name_label.modulate = COLOR_ITEM_NAME
	vbox.add_child(_item_name_label)

	# Separator
	var separator: HSeparator = HSeparator.new()
	separator.add_theme_constant_override("separation", 2)
	vbox.add_child(separator)

	# Actions container
	_actions_container = VBoxContainer.new()
	_actions_container.name = "ActionsContainer"
	_actions_container.add_theme_constant_override("separation", 0)
	vbox.add_child(_actions_container)


func _process(_delta: float) -> void:
	# Track mouse hover for visual feedback
	if not visible or not _is_showing:
		return

	var mouse_pos: Vector2 = get_global_mouse_position()
	var new_hover: int = -1

	for i: int in range(_action_labels.size()):
		var label: Label = _action_labels[i]
		var label_rect: Rect2 = label.get_global_rect()
		if label_rect.has_point(mouse_pos):
			new_hover = i
			break

	# Update hover state if changed
	if new_hover != _hover_index:
		_hover_index = new_hover
		if new_hover != -1 and new_hover != _selected_index:
			AudioManager.play_sfx("cursor_hover", AudioManager.SFXCategory.UI)
		_update_selection_visual()


# =============================================================================
# PUBLIC API
# =============================================================================

## Show the action menu for an item
## @param item_id: The item ID to show actions for
## @param context: EXPLORATION or BATTLE
## @param screen_position: Where to position the menu (optional)
func show_menu(item_id: String, context: Context = Context.EXPLORATION, screen_position: Vector2 = Vector2.ZERO) -> void:
	_current_item_id = item_id
	_context = context
	_hover_index = -1

	# Load item data
	_current_item_data = ModLoader.registry.get_item(item_id)
	if not _current_item_data:
		push_error("ItemActionMenu: Could not load item '%s'" % item_id)
		return

	# Update item name
	_item_name_label.text = _current_item_data.item_name

	# Determine available actions
	_determine_available_actions()

	if _available_actions.is_empty():
		push_warning("ItemActionMenu: No actions available for item '%s'" % item_id)
		return

	# Rebuild action labels
	_rebuild_action_labels()

	# Select first action
	_selected_index = 0
	_update_selection_visual()

	# Position the menu
	if screen_position != Vector2.ZERO:
		position = screen_position

	# Show menu
	_is_showing = true
	visible = true
	set_process_input(true)
	set_process(true)

	AudioManager.play_sfx("menu_open", AudioManager.SFXCategory.UI)


## Hide the menu
func hide_menu() -> void:
	_is_showing = false
	visible = false
	set_process_input(false)
	set_process(false)
	_hover_index = -1


## Check if menu is currently visible
func is_menu_active() -> bool:
	return _is_showing


## Get the current item ID
func get_current_item_id() -> String:
	return _current_item_id


# =============================================================================
# ACTION DETERMINATION
# =============================================================================

func _determine_available_actions() -> void:
	_available_actions.clear()

	if not _current_item_data:
		return

	var is_exploration: bool = _context == Context.EXPLORATION or _context == Context.FIELD_MENU
	var is_battle: bool = _context == Context.BATTLE
	var is_equipment_slot: bool = _context == Context.EQUIPMENT_SLOT
	var is_field_menu: bool = _context == Context.FIELD_MENU

	# EQUIPMENT_SLOT context: Item is currently equipped
	if is_equipment_slot:
		# Unequip is the primary action for equipped items
		_available_actions.append(ActionType.UNEQUIP)
		# Info is always available
		_available_actions.append(ActionType.INFO)
		return

	# USE: Consumables with appropriate usability
	if _current_item_data.item_type == ItemData.ItemType.CONSUMABLE:
		if is_exploration and _current_item_data.usable_on_field:
			_available_actions.append(ActionType.USE)
		elif is_battle and _current_item_data.usable_in_battle:
			_available_actions.append(ActionType.USE)

	# EQUIP: Equippable items (exploration only by default)
	# TODO: Add battle equip setting check
	if _current_item_data.is_equippable() and is_exploration:
		_available_actions.append(ActionType.EQUIP)

	# GIVE: Transfer to another party member (exploration only, NOT field menu)
	# Field menu is for quick item use - transfers require the Caravan (SF2 authentic)
	if is_exploration and not is_field_menu:
		_available_actions.append(ActionType.GIVE)

	# DROP: If item can be dropped
	if _current_item_data.can_be_dropped:
		_available_actions.append(ActionType.DROP)

	# INFO: Always available
	_available_actions.append(ActionType.INFO)


func _rebuild_action_labels() -> void:
	# Clear existing labels
	for label: Label in _action_labels:
		if is_instance_valid(label):
			label.queue_free()
	_action_labels.clear()

	# Create label for each available action
	for action_type: ActionType in _available_actions:
		var label: Label = _create_action_label(ACTION_NAMES[action_type])
		_actions_container.add_child(label)
		_action_labels.append(label)


func _create_action_label(action_name: String) -> Label:
	var label: Label = Label.new()
	label.text = "  " + action_name
	label.add_theme_font_override("font", MONOGRAM_FONT)
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = COLOR_NORMAL
	return label


func _update_selection_visual() -> void:
	for i: int in range(_action_labels.size()):
		var label: Label = _action_labels[i]
		var action_name: String = ACTION_NAMES[_available_actions[i]]
		var is_selected: bool = (i == _selected_index)
		var is_hovered: bool = (i == _hover_index)

		label.text = ("> " if is_selected else "  ") + action_name
		if is_selected:
			label.modulate = COLOR_SELECTED
		elif is_hovered:
			label.modulate = COLOR_HOVER
		else:
			label.modulate = COLOR_NORMAL


# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if not _is_showing:
		return

	# Mouse click
	if event is InputEventMouseButton:
		if _handle_mouse_click(event):
			return

	# Navigate up
	if event.is_action_pressed("ui_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()

	# Navigate down
	elif event.is_action_pressed("ui_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()

	# Confirm selection
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("sf_confirm"):
		_confirm_selection()
		get_viewport().set_input_as_handled()

	# Cancel menu
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("sf_cancel"):
		_cancel_menu()
		get_viewport().set_input_as_handled()


func _handle_mouse_click(event: InputEvent) -> bool:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return false

	var mouse_pos: Vector2 = get_global_mouse_position()

	# Check if clicked on an action label
	for i: int in range(_action_labels.size()):
		if _action_labels[i].get_global_rect().has_point(mouse_pos):
			_selected_index = i
			_confirm_selection()
			get_viewport().set_input_as_handled()
			return true

	# Click outside panel cancels menu
	if not _panel.get_global_rect().has_point(mouse_pos):
		_cancel_menu()
		get_viewport().set_input_as_handled()
		return true

	return false


func _move_selection(direction: int) -> void:
	var new_index: int = wrapi(_selected_index + direction, 0, _available_actions.size())
	if new_index != _selected_index:
		_selected_index = new_index
		_update_selection_visual()
		AudioManager.play_sfx("cursor_move", AudioManager.SFXCategory.UI)


func _confirm_selection() -> void:
	if not _is_showing or _available_actions.is_empty():
		return

	var selected_action: ActionType = _available_actions[_selected_index]
	var action_string: String = ACTION_NAMES[selected_action].to_lower()
	var item_id: String = _current_item_id

	AudioManager.play_sfx("menu_confirm", AudioManager.SFXCategory.UI)
	hide_menu()
	action_selected.emit(action_string, item_id)


func _cancel_menu() -> void:
	AudioManager.play_sfx("menu_cancel", AudioManager.SFXCategory.UI)
	hide_menu()
	menu_cancelled.emit()
