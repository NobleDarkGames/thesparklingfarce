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

## Emitted when a custom service is requested (from mods)
signal custom_service_requested(service_id: String, scene_path: String)

# =============================================================================
# CONSTANTS
# =============================================================================

const COLOR_PANEL_BG: Color = Color(0.1, 0.1, 0.15, 0.95)
const COLOR_PANEL_BORDER: Color = Color(0.4, 0.35, 0.25, 1.0)
const COLOR_OPTION_NORMAL: Color = Color(0.85, 0.85, 0.85, 1.0)
const COLOR_OPTION_SELECTED: Color = Color(1.0, 0.95, 0.4, 1.0)
const COLOR_OPTION_DISABLED: Color = Color(0.4, 0.4, 0.4, 1.0)

## Fallback menu options if CaravanController unavailable
const FALLBACK_OPTIONS: Array[Dictionary] = [
	{"id": "party", "label": "Party", "description": "Manage party members"},
	{"id": "items", "label": "Items", "description": "Access item storage"},
	{"id": "rest", "label": "Rest", "description": "Heal all party members"},
	{"id": "exit", "label": "Exit", "description": "Leave the Caravan"},
]

# =============================================================================
# STATE
# =============================================================================

## Currently selected option index
var _selected_index: int = 0

## Whether the menu is actively accepting input
var _active: bool = false

## Options that are currently disabled (legacy, kept for compatibility)
var _disabled_options: Array[String] = []

## Dynamic menu options (populated from CaravanController)
var _menu_options: Array[Dictionary] = []

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

func _create_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = UIUtils.create_panel_style(COLOR_PANEL_BG, COLOR_PANEL_BORDER, 2, 4)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


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
	_panel.add_theme_stylebox_override("panel", _create_panel_style())
	add_child(_panel)

	# Content container
	var content: VBoxContainer = VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 4)
	_panel.add_child(content)

	# Title
	_title_label = Label.new()
	_title_label.text = "Caravan"
	UIUtils.apply_monogram_style(_title_label, 24)
	_title_label.add_theme_color_override("font_color", COLOR_PANEL_BORDER)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_title_label)

	# Separator
	var sep: HSeparator = HSeparator.new()
	sep.custom_minimum_size.y = 8
	content.add_child(sep)

	# Options container (populated dynamically)
	_options_container = VBoxContainer.new()
	_options_container.name = "OptionsContainer"
	_options_container.add_theme_constant_override("separation", 2)
	content.add_child(_options_container)

	# Description area
	var desc_sep: HSeparator = HSeparator.new()
	desc_sep.custom_minimum_size.y = 8
	content.add_child(desc_sep)

	_description_label = Label.new()
	_description_label.text = "Select an option..."
	UIUtils.apply_monogram_style(_description_label, 16)
	_description_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_description_label)

	# Build initial options (will be refreshed on show_menu)
	_refresh_menu_options()


## Refresh menu options from CaravanController (supports mod custom services)
func _refresh_menu_options() -> void:
	# Clear existing option UI
	for child: Node in _options_container.get_children():
		child.queue_free()
	_option_labels.clear()

	# Get options from CaravanController or use fallback
	if CaravanController and CaravanController.has_method("get_menu_options"):
		_menu_options = CaravanController.get_menu_options()
	else:
		_menu_options = []
		for opt: Dictionary in FALLBACK_OPTIONS:
			_menu_options.append(opt.duplicate())

	# Wait a frame for queue_free to complete
	await get_tree().process_frame

	# Create option labels dynamically
	for i: int in range(_menu_options.size()):
		var option: Dictionary = _menu_options[i]

		var option_row: HBoxContainer = HBoxContainer.new()
		option_row.add_theme_constant_override("separation", 8)
		_options_container.add_child(option_row)

		# Cursor indicator (hidden until selected)
		var cursor: Label = Label.new()
		cursor.text = ">"
		UIUtils.apply_monogram_style(cursor, 16)
		cursor.add_theme_color_override("font_color", COLOR_OPTION_SELECTED)
		cursor.custom_minimum_size.x = 12
		cursor.visible = (i == 0)  # First option selected by default
		option_row.add_child(cursor)

		if i == 0:
			_cursor = cursor

		# Option label
		var label: Label = Label.new()
		label.text = option.get("label", "???")
		UIUtils.apply_monogram_style(label, 16)

		# Check if option is enabled
		var is_enabled: bool = option.get("enabled", true)
		if is_enabled:
			label.add_theme_color_override("font_color", COLOR_OPTION_NORMAL)
		else:
			label.add_theme_color_override("font_color", COLOR_OPTION_DISABLED)

		option_row.add_child(label)
		_option_labels.append(label)

	# Update description for first option
	if not _menu_options.is_empty():
		_description_label.text = _menu_options[0].get("description", "")


# =============================================================================
# MENU CONTROL
# =============================================================================

## Show the menu and activate input with smooth transition
func show_menu() -> void:
	# Refresh options from CaravanController (picks up mod custom services)
	await _refresh_menu_options()

	_selected_index = 0
	_update_selection_visual()
	visible = true
	_active = true
	set_process_input(true)

	# Smooth fade-in animation
	if _panel:
		_panel.modulate.a = 0.0
		_panel.scale = Vector2(0.9, 0.9)
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(_panel, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT)
		tween.tween_property(_panel, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	_play_sfx("menu_open")


## Hide the menu and deactivate input with smooth transition
func hide_menu() -> void:
	_active = false
	set_process_input(false)

	# Smooth fade-out animation
	if _panel and visible:
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(_panel, "modulate:a", 0.0, 0.1).set_ease(Tween.EASE_IN)
		tween.tween_property(_panel, "scale", Vector2(0.95, 0.95), 0.1).set_ease(Tween.EASE_IN)
		await tween.finished

	visible = false


## Set which options are disabled
func set_disabled_options(disabled: Array[String]) -> void:
	_disabled_options = disabled
	_update_selection_visual()


func _move_selection(direction: int) -> void:
	if _menu_options.is_empty():
		return

	var new_index: int = _selected_index
	var attempts: int = 0

	# Find next valid (enabled) option
	while attempts < _menu_options.size():
		new_index = (new_index + direction + _menu_options.size()) % _menu_options.size()
		var option: Dictionary = _menu_options[new_index]
		var is_enabled: bool = option.get("enabled", true)
		if is_enabled:
			break
		attempts += 1

	if new_index != _selected_index:
		_selected_index = new_index
		_update_selection_visual()
		_play_sfx("cursor_move")


func _update_selection_visual() -> void:
	if _menu_options.is_empty():
		return

	for i: int in range(mini(_option_labels.size(), _menu_options.size())):
		var label: Label = _option_labels[i]
		var is_enabled: bool = _menu_options[i].get("enabled", true)
		var is_selected: bool = (i == _selected_index)
		var cursor: Label = _get_cursor_for_row(i)

		# Update label color
		var color: Color = COLOR_OPTION_DISABLED
		if is_enabled:
			color = COLOR_OPTION_SELECTED if is_selected else COLOR_OPTION_NORMAL
		label.add_theme_color_override("font_color", color)

		# Update cursor visibility
		if cursor:
			cursor.visible = is_enabled and is_selected

	# Update description
	if _selected_index < _menu_options.size():
		_description_label.text = _menu_options[_selected_index].get("description", "")


func _get_cursor_for_row(index: int) -> Label:
	var row: Node = _options_container.get_child(index)
	if row.get_child_count() > 0 and row.get_child(0) is Label:
		return row.get_child(0) as Label
	return null


func _confirm_selection() -> void:
	if _menu_options.is_empty() or _selected_index >= _menu_options.size():
		return

	var option: Dictionary = _menu_options[_selected_index]
	var is_enabled: bool = option.get("enabled", true)

	if not is_enabled:
		_play_sfx("error")
		return

	_play_sfx("menu_select")

	var option_id: String = option.get("id", "")

	# Handle custom services from mods
	if option.get("is_custom", false):
		custom_service_requested.emit(option_id, option.get("scene_path", ""))
		option_selected.emit(option_id)
		return

	# Emit appropriate signal for built-in services
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
	_play_sfx("menu_cancel")
	close_requested.emit()


func _play_sfx(sfx_name: String) -> void:
	if AudioManager:
		AudioManager.play_sfx(sfx_name, AudioManager.SFXCategory.UI)


## Show a temporary message in the description area
func show_message(message: String) -> void:
	if _description_label:
		_description_label.text = message
		_description_label.add_theme_color_override("font_color", COLOR_OPTION_SELECTED)
