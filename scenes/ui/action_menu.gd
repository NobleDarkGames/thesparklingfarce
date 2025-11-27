## ActionMenu - Shining Force style action selection menu
##
## Displays available actions (Attack, Magic, Item, Stay) with context-aware highlighting
extends Control

## Signals - session_id prevents stale signals from previous turns
signal action_selected(action: String, session_id: int)
signal menu_cancelled(session_id: int)

## Menu items
@onready var move_label: Label = $VBoxContainer/MoveButton
@onready var attack_label: Label = $VBoxContainer/AttackButton
@onready var magic_label: Label = $VBoxContainer/MagicButton
@onready var item_label: Label = $VBoxContainer/ItemButton
@onready var stay_label: Label = $VBoxContainer/StayButton

## Available actions (set by InputManager)
var available_actions: Array[String] = []

## Current selection
var selected_index: int = 0
var menu_items: Array[Dictionary] = []

## Session ID - stored when menu opens, emitted with signals to prevent stale signals
var _menu_session_id: int = -1

## Colors
const COLOR_NORMAL: Color = Color(0.8, 0.8, 0.8, 1.0)
const COLOR_DISABLED: Color = Color(0.4, 0.4, 0.4, 1.0)
const COLOR_SELECTED: Color = Color(1.0, 1.0, 0.3, 1.0)  # Bright yellow


func _ready() -> void:
	# Hide by default
	visible = false
	set_process_input(false)  # Disable input processing when hidden

	# Build menu item array
	menu_items = [
		{"label": move_label, "action": "Move"},
		{"label": attack_label, "action": "Attack"},
		{"label": magic_label, "action": "Magic"},
		{"label": item_label, "action": "Item"},
		{"label": stay_label, "action": "Stay"},
	]


## Show menu with specific available actions
## session_id: The turn session ID from InputManager - will be emitted with signals
func show_menu(actions: Array[String], default_action: String = "", session_id: int = -1) -> void:
	available_actions = actions
	_menu_session_id = session_id

	# Update menu item visibility/colors
	for item in menu_items:
		var label: Label = item["label"]
		var action: String = item["action"]

		if action in available_actions:
			label.modulate = COLOR_NORMAL
		else:
			label.modulate = COLOR_DISABLED

	# Auto-select default action (context-aware)
	if default_action != "" and default_action in available_actions:
		_select_action_by_name(default_action)
	elif "Attack" in available_actions:
		_select_action_by_name("Attack")
	elif "Move" in available_actions:
		_select_action_by_name("Move")
	else:
		_select_action_by_name("Stay")

	# Update selection visual
	_update_selection_visual()

	# Show menu
	visible = true
	set_process_input(true)  # Enable input processing when shown


## Hide menu
func hide_menu() -> void:
	set_process_input(false)  # Disable input processing FIRST
	visible = false


## Reset menu to clean state (called when turn ends to prevent stale state)
func reset_menu() -> void:
	# Completely disable input processing
	set_process_input(false)

	# Clear all state including session ID
	available_actions.clear()
	selected_index = 0
	_menu_session_id = -1  # Invalidate session ID

	# Hide menu
	visible = false

	# Reset all labels to default state
	for item in menu_items:
		var label: Label = item["label"]
		label.modulate = COLOR_DISABLED
		label.remove_theme_color_override("font_color")


## Handle input
func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Mouse click on menu items
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Check which label was clicked
			var mouse_pos: Vector2 = get_global_mouse_position()
			for i in range(menu_items.size()):
				var label: Label = menu_items[i]["label"]
				var action: String = menu_items[i]["action"]

				# Check if mouse is over this label
				var label_rect: Rect2 = label.get_global_rect()
				if label_rect.has_point(mouse_pos) and action in available_actions:
					selected_index = i
					_update_selection_visual()
					_confirm_selection()
					get_viewport().set_input_as_handled()
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
	elif event.is_action_pressed("ui_accept"):
		_confirm_selection()
		get_viewport().set_input_as_handled()

	# Cancel menu
	elif event.is_action_pressed("ui_cancel"):
		_cancel_menu()
		get_viewport().set_input_as_handled()

	# Number key shortcuts
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				if "Attack" in available_actions:
					_select_action_by_name("Attack")
					_confirm_selection()
			KEY_2:
				if "Magic" in available_actions:
					_select_action_by_name("Magic")
					_confirm_selection()
			KEY_3:
				if "Item" in available_actions:
					_select_action_by_name("Item")
					_confirm_selection()
			KEY_4:
				if "Stay" in available_actions:
					_select_action_by_name("Stay")
					_confirm_selection()


## Move selection up or down
func _move_selection(direction: int) -> void:
	var start_index: int = selected_index

	# Loop until we find an available action
	for i in range(menu_items.size()):
		selected_index = wrapi(selected_index + direction, 0, menu_items.size())

		var item: Dictionary = menu_items[selected_index]
		if item["action"] in available_actions:
			_update_selection_visual()
			return

		# Prevent infinite loop if no actions available
		if selected_index == start_index:
			break


## Select action by name
func _select_action_by_name(action: String) -> void:
	for i in range(menu_items.size()):
		if menu_items[i]["action"] == action:
			selected_index = i
			break


## Update visual highlighting
func _update_selection_visual() -> void:
	for i in range(menu_items.size()):
		var item: Dictionary = menu_items[i]
		var label: Label = item["label"]
		var action: String = item["action"]

		if i == selected_index and action in available_actions:
			# Selected item
			label.modulate = COLOR_SELECTED
			label.add_theme_color_override("font_color", COLOR_SELECTED)
		elif action in available_actions:
			# Available but not selected
			label.modulate = COLOR_NORMAL
			label.remove_theme_color_override("font_color")
		else:
			# Disabled
			label.modulate = COLOR_DISABLED
			label.remove_theme_color_override("font_color")


## Confirm current selection
func _confirm_selection() -> void:
	# DEFENSE IN DEPTH: Multiple safety checks before emitting signal

	# Safety check 1: Don't emit if input processing is disabled
	if not is_processing_input():
		return

	# Safety check 2: Don't emit signals if menu is not visible
	if not visible:
		return

	# Safety check 3: Don't emit if no actions available (stale state)
	if available_actions.is_empty():
		return

	var selected_action: String = menu_items[selected_index]["action"]

	# Safety check 4: Don't emit if selected action is not in available list
	if selected_action not in available_actions:
		return

	# CRITICAL: Capture session ID and emit signal BEFORE hide_menu()
	# This prevents any state changes from affecting the emission
	var emit_session_id: int = _menu_session_id
	action_selected.emit(selected_action, emit_session_id)
	hide_menu()


## Cancel menu
func _cancel_menu() -> void:
	# CRITICAL: Capture session ID and emit signal BEFORE hide_menu()
	var emit_session_id: int = _menu_session_id
	menu_cancelled.emit(emit_session_id)
	hide_menu()
