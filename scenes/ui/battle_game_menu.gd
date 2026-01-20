class_name BattleGameMenu
extends Control

## BattleGameMenu - SF2-style in-battle options menu
##
## Appears when player presses confirm on an empty cell during INSPECTING state.
## Provides access to: Map (tactical overview), Speed (animation speed toggle),
## Status (party overview), and Quit (return to HQ with confirmation).
##
## SF2-authentic behavior:
## - Fixed position in bottom-left corner (doesn't follow cursor)
## - INSTANT cursor movement (no animation delays)
## - Cursor wrapping (down from bottom -> top)
## - Speed toggle cycles inline (menu stays open)
## - Quit disabled (grayed) in story battles

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when menu is closed (by cancel or completing an action)
signal menu_closed()

## Emitted when map overlay should be shown
signal map_requested()

## Emitted when status screen should be shown
signal status_requested()

## Emitted when quit is confirmed
signal quit_confirmed()

# =============================================================================
# ENUMS
# =============================================================================

enum MenuOption {
	MAP,
	SPEED,
	STATUS,
	QUIT
}

# =============================================================================
# CONSTANTS - VISUAL SPECIFICATIONS (SF2-authentic with modern polish)
# =============================================================================

const PANEL_MIN_SIZE: Vector2 = Vector2(100, 80)
const PANEL_BG: Color = Color(0.1, 0.1, 0.15, 0.95)
const PANEL_BORDER: Color = Color(0.5, 0.5, 0.6, 1.0)
const PANEL_BORDER_WIDTH: int = 2
const PANEL_CORNER_RADIUS: int = 4

# Padding/margins
const CONTENT_MARGIN_TOP: int = 8
const CONTENT_MARGIN_BOTTOM: int = 8
const CONTENT_MARGIN_LEFT: int = 8
const CONTENT_MARGIN_RIGHT: int = 8
const OPTION_SEPARATION: int = 2

# Text colors (consistent with existing menus)
const TEXT_NORMAL: Color = Color(0.85, 0.85, 0.85)
const TEXT_SELECTED: Color = Color(1.0, 0.95, 0.4)  # Yellow highlight
const TEXT_DISABLED: Color = Color(0.4, 0.4, 0.4)
const TEXT_HOVER: Color = Color(0.95, 0.95, 0.85)

# Cursor
const CURSOR_CHAR: String = ">"
const CURSOR_SPACING: int = 8

# Font (MANDATORY)
const MONOGRAM_FONT: Font = preload("res://assets/fonts/monogram.ttf")
const FONT_SIZE: int = 16

# Menu animation timing
const MENU_OPEN_DURATION: float = 0.08
const MENU_CLOSE_DURATION: float = 0.05

# Cursor Movement: INSTANT (no animation - SF2 purist requirement)
const CURSOR_MOVE_DURATION: float = 0.0

# Positioning (bottom-left corner)
const MENU_MARGIN_LEFT: float = 8.0
const MENU_MARGIN_BOTTOM: float = 8.0

# Speed toggle values (animation speed multipliers)
const SPEED_VALUES: Array[float] = [1.0, 2.0, 3.0]

# =============================================================================
# STATE
# =============================================================================

## Currently selected option index
var _selected_index: int = 0

## Whether the menu is actively accepting input
var _is_active: bool = false

## Hover tracking for mouse support
var _hover_index: int = -1

## Whether quit option is disabled (story battles)
var _quit_disabled: bool = false

## Current speed index (cycles through SPEED_VALUES)
var _speed_index: int = 0

## Reference to confirmation dialog (created on demand)
var _confirm_dialog: SFConfirmationDialog = null

## Reference to map overlay (created on demand)
var _map_overlay: BattleMapOverlay = null

# =============================================================================
# UI REFERENCES
# =============================================================================

var _panel: PanelContainer = null
var _options_container: VBoxContainer = null
var _option_labels: Array[Label] = []

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_build_ui()
	_sync_speed_from_game_juice()
	visible = false
	set_process_input(false)
	set_process(false)


func _build_ui() -> void:
	# This control is the root
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Panel container
	_panel = PanelContainer.new()
	_panel.name = "GameMenuPanel"
	_panel.custom_minimum_size = PANEL_MIN_SIZE

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG
	panel_style.border_color = PANEL_BORDER
	panel_style.set_border_width_all(PANEL_BORDER_WIDTH)
	panel_style.set_corner_radius_all(PANEL_CORNER_RADIUS)
	panel_style.content_margin_top = CONTENT_MARGIN_TOP
	panel_style.content_margin_bottom = CONTENT_MARGIN_BOTTOM
	panel_style.content_margin_left = CONTENT_MARGIN_LEFT
	panel_style.content_margin_right = CONTENT_MARGIN_RIGHT
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	# Options container
	_options_container = VBoxContainer.new()
	_options_container.name = "OptionsContainer"
	_options_container.add_theme_constant_override("separation", OPTION_SEPARATION)
	_panel.add_child(_options_container)

	# Build option labels
	_rebuild_option_labels()


func _process(_delta: float) -> void:
	# Track mouse hover for visual feedback
	if not visible or not _is_active:
		return

	var mouse_pos: Vector2 = get_global_mouse_position()
	var new_hover: int = -1

	for i: int in range(_option_labels.size()):
		var label: Label = _option_labels[i]
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

## Show the game menu
## @param is_story_battle: If true, Quit option is disabled (grayed out)
func show_menu(is_story_battle: bool = false) -> void:
	_quit_disabled = is_story_battle
	_hover_index = -1

	# Sync speed display with GameJuice
	_sync_speed_from_game_juice()

	# Rebuild labels (updates Speed display and Quit state)
	_rebuild_option_labels()

	# Select first option
	_selected_index = 0
	_update_selection_visual()

	# Position in bottom-left corner
	_position_menu()

	# Show menu with fast animation
	_is_active = true
	visible = true
	set_process_input(true)
	set_process(true)

	# Animate open
	if MENU_OPEN_DURATION > 0:
		_panel.modulate.a = 0.0
		_panel.scale = Vector2(0.9, 0.9)
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(_panel, "modulate:a", 1.0, MENU_OPEN_DURATION).set_ease(Tween.EASE_OUT)
		tween.tween_property(_panel, "scale", Vector2.ONE, MENU_OPEN_DURATION).set_ease(Tween.EASE_OUT)
	else:
		_panel.modulate.a = 1.0
		_panel.scale = Vector2.ONE

	AudioManager.play_sfx("menu_open", AudioManager.SFXCategory.UI)


## Hide the menu
func hide_menu() -> void:
	_is_active = false
	set_process_input(false)
	set_process(false)
	_hover_index = -1

	# Animate close
	if MENU_CLOSE_DURATION > 0 and visible:
		var tween: Tween = create_tween()
		tween.tween_property(_panel, "modulate:a", 0.0, MENU_CLOSE_DURATION).set_ease(Tween.EASE_IN)
		await tween.finished

	visible = false


## Check if menu is currently active
func is_menu_active() -> bool:
	return _is_active


## Set reference to map overlay (for showing tactical map)
func set_map_overlay(overlay: BattleMapOverlay) -> void:
	_map_overlay = overlay


# =============================================================================
# OPTION BUILDING
# =============================================================================

func _rebuild_option_labels() -> void:
	# Clear existing labels
	for label: Label in _option_labels:
		if is_instance_valid(label):
			label.queue_free()
	_option_labels.clear()

	# Create labels for each option
	var options: Array[Dictionary] = _get_menu_options()

	for option: Dictionary in options:
		var label: Label = Label.new()
		var option_text: String = DictUtils.get_string(option, "label", "")
		label.text = "  " + option_text  # Indent for cursor space
		label.add_theme_font_override("font", MONOGRAM_FONT)
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		label.add_theme_color_override("font_color", TEXT_NORMAL)
		_options_container.add_child(label)
		_option_labels.append(label)


func _get_menu_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []

	options.append({
		"id": "map",
		"label": "Map",
		"action": MenuOption.MAP,
		"enabled": true
	})

	# Speed shows current value inline
	var speed_label: String = "Speed: %d" % int(SPEED_VALUES[_speed_index])
	options.append({
		"id": "speed",
		"label": speed_label,
		"action": MenuOption.SPEED,
		"enabled": true
	})

	options.append({
		"id": "status",
		"label": "Status",
		"action": MenuOption.STATUS,
		"enabled": true
	})

	options.append({
		"id": "quit",
		"label": "Quit",
		"action": MenuOption.QUIT,
		"enabled": not _quit_disabled
	})

	return options


func _sync_speed_from_game_juice() -> void:
	# Find which speed index matches current GameJuice.animation_speed
	var current_speed: float = GameJuice.animation_speed
	for i: int in range(SPEED_VALUES.size()):
		if absf(SPEED_VALUES[i] - current_speed) < 0.01:
			_speed_index = i
			return
	# Default to first if no match
	_speed_index = 0


## Update visual selection (cursor and colors)
func _update_selection_visual() -> void:
	var options: Array[Dictionary] = _get_menu_options()

	for i: int in range(_option_labels.size()):
		var label: Label = _option_labels[i]
		var option: Dictionary = options[i]
		var option_label: String = DictUtils.get_string(option, "label", "")
		var is_enabled: bool = DictUtils.get_bool(option, "enabled", true)

		if not is_enabled:
			# Disabled option
			label.add_theme_color_override("font_color", TEXT_DISABLED)
			if i == _selected_index:
				label.text = CURSOR_CHAR + " " + option_label
			else:
				label.text = "  " + option_label
		elif i == _selected_index:
			# Selected: show cursor and yellow text
			label.add_theme_color_override("font_color", TEXT_SELECTED)
			label.text = CURSOR_CHAR + " " + option_label
		elif i == _hover_index:
			# Hovered: lighter text, no cursor
			label.add_theme_color_override("font_color", TEXT_HOVER)
			label.text = "  " + option_label
		else:
			# Normal: default text, no cursor
			label.add_theme_color_override("font_color", TEXT_NORMAL)
			label.text = "  " + option_label


## Position the menu in bottom-left corner
func _position_menu() -> void:
	# Wait a frame for panel size to be calculated
	await get_tree().process_frame
	if not is_instance_valid(self) or not visible:
		return

	var viewport_rect: Rect2 = get_viewport_rect()
	var menu_size: Vector2 = _panel.get_combined_minimum_size()

	# Bottom-left corner positioning
	var desired_pos: Vector2 = Vector2(
		MENU_MARGIN_LEFT,
		viewport_rect.size.y - menu_size.y - MENU_MARGIN_BOTTOM
	)

	position = desired_pos


# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if not _is_active:
		return

	# Mouse click
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			var mouse_pos: Vector2 = get_global_mouse_position()
			for i: int in range(_option_labels.size()):
				var label: Label = _option_labels[i]
				var label_rect: Rect2 = label.get_global_rect()
				if label_rect.has_point(mouse_pos):
					_selected_index = i
					_confirm_selection()
					get_viewport().set_input_as_handled()
					return

			# Click outside panel - cancel
			if not _panel.get_global_rect().has_point(mouse_pos):
				_cancel_menu()
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
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("sf_confirm"):
		_confirm_selection()
		get_viewport().set_input_as_handled()

	# Cancel menu
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("sf_cancel"):
		_cancel_menu()
		get_viewport().set_input_as_handled()


## Move selection with wrapping (SF2-authentic)
func _move_selection(direction: int) -> void:
	var options: Array[Dictionary] = _get_menu_options()
	if options.is_empty():
		return

	# INSTANT cursor movement (SF2 purist requirement - no animation)
	var new_index: int = wrapi(_selected_index + direction, 0, options.size())

	if new_index != _selected_index:
		_selected_index = new_index
		_update_selection_visual()
		AudioManager.play_sfx("cursor_move", AudioManager.SFXCategory.UI)


## Confirm the currently selected option
func _confirm_selection() -> void:
	if not _is_active:
		return

	var options: Array[Dictionary] = _get_menu_options()
	if _selected_index >= options.size():
		return

	var selected_option: Dictionary = options[_selected_index]
	var is_enabled: bool = DictUtils.get_bool(selected_option, "enabled", true)

	if not is_enabled:
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		return

	var action: int = DictUtils.get_int(selected_option, "action", -1)

	match action:
		MenuOption.MAP:
			_handle_map_action()
		MenuOption.SPEED:
			_handle_speed_action()
		MenuOption.STATUS:
			_handle_status_action()
		MenuOption.QUIT:
			_handle_quit_action()


## Cancel and close the menu
func _cancel_menu() -> void:
	AudioManager.play_sfx("menu_cancel", AudioManager.SFXCategory.UI)
	hide_menu()
	menu_closed.emit()


# =============================================================================
# ACTION HANDLERS
# =============================================================================

func _handle_map_action() -> void:
	AudioManager.play_sfx("menu_confirm", AudioManager.SFXCategory.UI)
	hide_menu()

	# Show map overlay
	if _map_overlay:
		_map_overlay.show_overlay()
		await _map_overlay.overlay_closed
		# Scene may have been freed
		if not is_instance_valid(self):
			return

	menu_closed.emit()
	map_requested.emit()


func _handle_speed_action() -> void:
	# Cycle speed: 1 -> 2 -> 3 -> 1
	_speed_index = (_speed_index + 1) % SPEED_VALUES.size()
	var new_speed: float = SPEED_VALUES[_speed_index]

	# Update GameJuice
	GameJuice.animation_speed = new_speed

	# Update label text without rebuilding everything
	var speed_label: String = "Speed: %d" % int(new_speed)
	if _selected_index < _option_labels.size():
		var label: Label = _option_labels[_selected_index]
		label.text = CURSOR_CHAR + " " + speed_label

	AudioManager.play_sfx("menu_confirm", AudioManager.SFXCategory.UI)
	# Menu stays open for speed toggle


func _handle_status_action() -> void:
	AudioManager.play_sfx("menu_confirm", AudioManager.SFXCategory.UI)
	hide_menu()
	menu_closed.emit()
	status_requested.emit()
	# TODO: Show party status screen (stub for now)


func _handle_quit_action() -> void:
	AudioManager.play_sfx("menu_confirm", AudioManager.SFXCategory.UI)

	# Create confirmation dialog if needed
	if not _confirm_dialog:
		_confirm_dialog = SFConfirmationDialog.new()
		add_child(_confirm_dialog)

	# Temporarily disable menu input while dialog is showing
	set_process_input(false)

	var confirmed: bool = await _confirm_dialog.show_confirmation(
		"Quit Battle",
		"Quit battle? Progress will be lost."
	)

	# Scene may have been freed during dialog
	if not is_instance_valid(self):
		return

	if confirmed:
		hide_menu()
		menu_closed.emit()
		quit_confirmed.emit()
	else:
		# Re-enable menu input
		set_process_input(true)
