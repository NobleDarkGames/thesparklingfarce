class_name CaravanMainMenu
extends Control

## CaravanMainMenu - SF2-style Caravan services menu
##
## Centered panel with options:
## - Party: Open party management (swap active/reserve)
## - Items: Open depot storage panel
## - Rest: Free heal all party members
## - Exit: Close menu
##
## Keyboard/gamepad navigation with visual feedback.

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when a menu option is selected
signal option_selected(option: String)

## Emitted when menu is cancelled/closed
signal close_requested()

## Emitted when party management is requested
signal party_requested()

## Emitted when item storage is requested
signal items_requested()

## Emitted when rest service is requested
signal rest_requested()

# =============================================================================
# CONSTANTS
# =============================================================================

const COLOR_PANEL_BG: Color = Color(0.1, 0.1, 0.15, 0.95)
const COLOR_PANEL_BORDER: Color = Color(0.4, 0.35, 0.25, 1.0)
const COLOR_OPTION_NORMAL: Color = Color(0.85, 0.85, 0.85, 1.0)
const COLOR_OPTION_SELECTED: Color = Color(1.0, 0.95, 0.4, 1.0)
const COLOR_OPTION_DISABLED: Color = Color(0.4, 0.4, 0.4, 1.0)

const MENU_OPTIONS: Array[Dictionary] = [
	{"id": "party", "label": "Party", "description": "Manage party members"},
	{"id": "items", "label": "Items", "description": "Access item storage"},
	{"id": "rest", "label": "Rest", "description": "Heal all party members"},
	{"id": "exit", "label": "Exit", "description": "Leave the Caravan"},
]

const MONOGRAM_FONT: Font = preload("res://assets/fonts/monogram.ttf")

# =============================================================================
# STATE
# =============================================================================

## Currently selected option index
var _selected_index: int = 0

## Whether the menu is actively accepting input
var _active: bool = false

## Options that are currently disabled
var _disabled_options: Array[String] = []

# =============================================================================
# UI REFERENCES
# =============================================================================

var _panel: PanelContainer = null
var _title_label: Label = null
var _options_container: VBoxContainer = null
var _option_labels: Array[Label] = []
var _description_label: Label = null
var _cursor: Label = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_build_ui()
	visible = false
	set_process_input(false)


func _input(event: InputEvent) -> void:
	if not _active:
		return

	if event.is_action_pressed("ui_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("sf_confirm"):
		_confirm_selection()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("sf_cancel"):
		_cancel()
		get_viewport().set_input_as_handled()


# =============================================================================
# UI BUILDING
# =============================================================================

func _build_ui() -> void:
	# Fill the screen so we can center the panel within
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through empty areas

	# Main panel - centered within the full-screen control
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(160, 140)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = COLOR_PANEL_BG
	panel_style.border_color = COLOR_PANEL_BORDER
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(4)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	# Content container
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	_panel.add_child(content)

	# Title
	_title_label = Label.new()
	_title_label.text = "Caravan"
	_title_label.add_theme_font_override("font", MONOGRAM_FONT)
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", COLOR_PANEL_BORDER)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_title_label)

	# Separator
	var sep: HSeparator = HSeparator.new()
	sep.custom_minimum_size.y = 8
	content.add_child(sep)

	# Options container
	_options_container = VBoxContainer.new()
	_options_container.add_theme_constant_override("separation", 2)
	content.add_child(_options_container)

	# Create option labels
	for i in range(MENU_OPTIONS.size()):
		var option: Dictionary = MENU_OPTIONS[i]

		var option_row: HBoxContainer = HBoxContainer.new()
		option_row.add_theme_constant_override("separation", 8)
		_options_container.add_child(option_row)

		# Cursor indicator (hidden until selected)
		var cursor: Label = Label.new()
		cursor.text = ">"
		cursor.add_theme_font_override("font", MONOGRAM_FONT)
		cursor.add_theme_font_size_override("font_size", 16)
		cursor.add_theme_color_override("font_color", COLOR_OPTION_SELECTED)
		cursor.custom_minimum_size.x = 12
		cursor.visible = (i == 0)  # First option selected by default
		option_row.add_child(cursor)

		if i == 0:
			_cursor = cursor

		# Option label
		var label: Label = Label.new()
		label.text = option.label
		label.add_theme_font_override("font", MONOGRAM_FONT)
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", COLOR_OPTION_NORMAL)
		option_row.add_child(label)

		_option_labels.append(label)

	# Description area
	var desc_sep: HSeparator = HSeparator.new()
	desc_sep.custom_minimum_size.y = 8
	content.add_child(desc_sep)

	_description_label = Label.new()
	_description_label.text = MENU_OPTIONS[0].description
	_description_label.add_theme_font_override("font", MONOGRAM_FONT)
	_description_label.add_theme_font_size_override("font_size", 12)
	_description_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_description_label)


# =============================================================================
# MENU CONTROL
# =============================================================================

## Show the menu and activate input
func show_menu() -> void:
	_selected_index = 0
	_update_selection_visual()
	visible = true
	_active = true
	set_process_input(true)

	# Play open sound
	if AudioManager:
		AudioManager.play_sfx("menu_open", AudioManager.SFXCategory.UI)


## Hide the menu and deactivate input
func hide_menu() -> void:
	visible = false
	_active = false
	set_process_input(false)


## Set which options are disabled
func set_disabled_options(disabled: Array[String]) -> void:
	_disabled_options = disabled
	_update_selection_visual()


func _move_selection(direction: int) -> void:
	var new_index: int = _selected_index
	var attempts: int = 0

	# Find next valid (non-disabled) option
	while attempts < MENU_OPTIONS.size():
		new_index = (new_index + direction + MENU_OPTIONS.size()) % MENU_OPTIONS.size()
		var option_id: String = MENU_OPTIONS[new_index].id
		if option_id not in _disabled_options:
			break
		attempts += 1

	if new_index != _selected_index:
		_selected_index = new_index
		_update_selection_visual()

		# Play cursor sound
		if AudioManager:
			AudioManager.play_sfx("cursor_move", AudioManager.SFXCategory.UI)


func _update_selection_visual() -> void:
	for i in range(_option_labels.size()):
		var label: Label = _option_labels[i]
		var option_id: String = MENU_OPTIONS[i].id
		var cursor: Label = _options_container.get_child(i).get_child(0) as Label

		if option_id in _disabled_options:
			label.add_theme_color_override("font_color", COLOR_OPTION_DISABLED)
			cursor.visible = false
		elif i == _selected_index:
			label.add_theme_color_override("font_color", COLOR_OPTION_SELECTED)
			cursor.visible = true
		else:
			label.add_theme_color_override("font_color", COLOR_OPTION_NORMAL)
			cursor.visible = false

	# Update description
	_description_label.text = MENU_OPTIONS[_selected_index].description


func _confirm_selection() -> void:
	var option: Dictionary = MENU_OPTIONS[_selected_index]
	var option_id: String = option.id

	if option_id in _disabled_options:
		# Play error sound
		if AudioManager:
			AudioManager.play_sfx("error", AudioManager.SFXCategory.UI)
		return

	# Play confirm sound
	if AudioManager:
		AudioManager.play_sfx("menu_select", AudioManager.SFXCategory.UI)

	# Emit appropriate signal
	match option_id:
		"party":
			party_requested.emit()
		"items":
			items_requested.emit()
		"rest":
			rest_requested.emit()
		"exit":
			close_requested.emit()

	option_selected.emit(option_id)


func _cancel() -> void:
	# Play cancel sound
	if AudioManager:
		AudioManager.play_sfx("menu_cancel", AudioManager.SFXCategory.UI)

	close_requested.emit()
