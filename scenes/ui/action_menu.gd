## ActionMenu - Shining Force style action selection menu
##
## Displays available actions (Attack, Magic, Item, Stay) with context-aware highlighting.
## Features keyboard/mouse navigation, hover states, and sound feedback.
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

## Hover tracking
var _hover_index: int = -1

## Colors
const COLOR_NORMAL: Color = Color(0.8, 0.8, 0.8, 1.0)
const COLOR_DISABLED: Color = Color(0.4, 0.4, 0.4, 1.0)
const COLOR_SELECTED: Color = Color(1.0, 1.0, 0.3, 1.0)  # Bright yellow
const COLOR_HOVER: Color = Color(0.95, 0.95, 0.85, 1.0)  # Subtle hover highlight

## Animation settings
const MENU_SLIDE_DURATION: float = 0.15
const MENU_SLIDE_OFFSET: float = 30.0  # Pixels to slide from
const SELECTION_PULSE_SCALE: float = 1.1
const SELECTION_PULSE_DURATION: float = 0.08

## Animation state
var _slide_tween: Tween = null
var _pulse_tween: Tween = null


func _ready() -> void:
	# Hide by default
	visible = false
	set_process_input(false)  # Disable input processing when hidden
	set_process(false)  # Disable _process when hidden

	# Build menu item array
	menu_items = [
		{"label": move_label, "action": "Move"},
		{"label": attack_label, "action": "Attack"},
		{"label": magic_label, "action": "Magic"},
		{"label": item_label, "action": "Item"},
		{"label": stay_label, "action": "Stay"},
	]

	# Set pivot for scale animations on each label
	for item: Dictionary in menu_items:
		var label: Label = item["label"]
		# Pivot on left-center for nice scale effect
		label.pivot_offset = Vector2(0, label.size.y / 2.0)


func _process(_delta: float) -> void:
	# Track mouse hover for visual feedback
	if not visible:
		return

	var mouse_pos: Vector2 = get_global_mouse_position()
	var new_hover: int = -1

	for i in range(menu_items.size()):
		var label: Label = menu_items[i]["label"]
		var action: String = menu_items[i]["action"]

		if action not in available_actions:
			continue

		var label_rect: Rect2 = label.get_global_rect()
		if label_rect.has_point(mouse_pos):
			new_hover = i
			break

	# Update hover state if changed
	if new_hover != _hover_index:
		_hover_index = new_hover

		# Play hover sound when entering a new valid item (not the selected one)
		if new_hover != -1 and new_hover != selected_index:
			AudioManager.play_sfx("cursor_hover", AudioManager.SFXCategory.UI)

		_update_selection_visual()


## Show menu with specific available actions
## session_id: The turn session ID from InputManager - will be emitted with signals
## NOTE: Position must be set by caller BEFORE calling show_menu()
func show_menu(actions: Array[String], default_action: String = "", session_id: int = -1) -> void:
	available_actions = actions
	_menu_session_id = session_id
	_hover_index = -1  # Reset hover state

	# Kill any existing slide animation
	if _slide_tween:
		_slide_tween.kill()
		_slide_tween = null

	# Update menu item visibility/colors
	for item in menu_items:
		var label: Label = item["label"]
		var action: String = item["action"]

		if action in available_actions:
			label.modulate = COLOR_NORMAL
		else:
			label.modulate = COLOR_DISABLED
		# Reset scale from any previous pulse
		label.scale = Vector2.ONE

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

	# Animate slide-in from right (relative to current position set by caller)
	# The target position is wherever the caller placed us
	var target_position: Vector2 = position
	position = target_position + Vector2(MENU_SLIDE_OFFSET, 0)
	modulate.a = 0.0
	visible = true

	_slide_tween = create_tween()
	_slide_tween.set_parallel(true)
	_slide_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_slide_tween.tween_property(self, "position", target_position, MENU_SLIDE_DURATION)
	_slide_tween.tween_property(self, "modulate:a", 1.0, MENU_SLIDE_DURATION * 0.7)

	set_process_input(true)  # Enable input processing when shown
	set_process(true)  # Enable hover tracking


## Hide menu with optional slide-out animation
func hide_menu(animate: bool = false) -> void:
	set_process_input(false)  # Disable input processing FIRST
	set_process(false)  # Disable hover tracking
	_hover_index = -1

	# Kill any existing animations
	if _slide_tween:
		_slide_tween.kill()
		_slide_tween = null
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null

	if animate and visible:
		# Slide out to right (from current position)
		_slide_tween = create_tween()
		_slide_tween.set_parallel(true)
		_slide_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_slide_tween.tween_property(self, "position", position + Vector2(MENU_SLIDE_OFFSET, 0), MENU_SLIDE_DURATION * 0.7)
		_slide_tween.tween_property(self, "modulate:a", 0.0, MENU_SLIDE_DURATION * 0.5)
		_slide_tween.chain().tween_callback(func() -> void: visible = false)
	else:
		visible = false


## Reset menu to clean state (called when turn ends to prevent stale state)
func reset_menu() -> void:
	# Completely disable input processing
	set_process_input(false)
	set_process(false)

	# Clear all state including session ID
	available_actions.clear()
	selected_index = 0
	_menu_session_id = -1  # Invalidate session ID
	_hover_index = -1

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
				else:
					_play_error_sound()
			KEY_2:
				if "Magic" in available_actions:
					_select_action_by_name("Magic")
					_confirm_selection()
				else:
					_play_error_sound()
			KEY_3:
				if "Item" in available_actions:
					_select_action_by_name("Item")
					_confirm_selection()
				else:
					_play_error_sound()
			KEY_4:
				if "Stay" in available_actions:
					_select_action_by_name("Stay")
					_confirm_selection()
				else:
					_play_error_sound()


## Move selection up or down
func _move_selection(direction: int) -> void:
	var start_index: int = selected_index

	# Reset scale on previously selected item
	if start_index >= 0 and start_index < menu_items.size():
		menu_items[start_index]["label"].scale = Vector2.ONE

	# Loop until we find an available action
	for i in range(menu_items.size()):
		selected_index = wrapi(selected_index + direction, 0, menu_items.size())

		var item: Dictionary = menu_items[selected_index]
		if item["action"] in available_actions:
			# Only play sound and update if we actually moved
			if selected_index != start_index:
				AudioManager.play_sfx("cursor_move", AudioManager.SFXCategory.UI)
				_update_selection_visual()
				_pulse_selected_item()
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
			# Selected item - bright yellow
			label.modulate = COLOR_SELECTED
			label.add_theme_color_override("font_color", COLOR_SELECTED)
		elif i == _hover_index and action in available_actions:
			# Hovered but not selected - subtle highlight
			label.modulate = COLOR_HOVER
			label.remove_theme_color_override("font_color")
		elif action in available_actions:
			# Available but not selected or hovered
			label.modulate = COLOR_NORMAL
			label.remove_theme_color_override("font_color")
		else:
			# Disabled
			label.modulate = COLOR_DISABLED
			label.remove_theme_color_override("font_color")


## Play a quick pulse animation on the selected item
func _pulse_selected_item() -> void:
	if selected_index < 0 or selected_index >= menu_items.size():
		return

	var label: Label = menu_items[selected_index]["label"]

	# Kill existing pulse
	if _pulse_tween:
		_pulse_tween.kill()

	# Quick scale pulse
	_pulse_tween = create_tween()
	_pulse_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(label, "scale", Vector2(SELECTION_PULSE_SCALE, SELECTION_PULSE_SCALE), SELECTION_PULSE_DURATION)
	_pulse_tween.tween_property(label, "scale", Vector2.ONE, SELECTION_PULSE_DURATION * 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


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
		_play_error_sound()
		return

	# Play confirm sound
	AudioManager.play_sfx("menu_confirm", AudioManager.SFXCategory.UI)

	# CRITICAL: Capture session ID and emit signal BEFORE hide_menu()
	# This prevents any state changes from affecting the emission
	var emit_session_id: int = _menu_session_id
	action_selected.emit(selected_action, emit_session_id)
	hide_menu()


## Cancel menu
func _cancel_menu() -> void:
	# Play cancel sound
	AudioManager.play_sfx("menu_cancel", AudioManager.SFXCategory.UI)

	# CRITICAL: Capture session ID and emit signal BEFORE hide_menu()
	var emit_session_id: int = _menu_session_id
	menu_cancelled.emit(emit_session_id)
	hide_menu()


## Play error/invalid action sound
func _play_error_sound() -> void:
	AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
