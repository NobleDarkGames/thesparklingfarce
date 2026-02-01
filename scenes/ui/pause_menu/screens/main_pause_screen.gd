extends Control

## MainPauseScreen - Primary pause menu screen with navigation options
##
## Built programmatically following the BattleGameMenu/ExplorationFieldMenu pattern.
## Provides: Resume, Settings, Quit to Title.
##
## Quit to Title shows an SFConfirmationDialog before proceeding.

# =============================================================================
# ENUMS
# =============================================================================

enum MenuOption {
	RESUME,
	SETTINGS,
	QUIT_TO_TITLE
}

# =============================================================================
# CONSTANTS - VISUAL SPECIFICATIONS (match BattleGameMenu/ExplorationFieldMenu)
# =============================================================================

const PANEL_BG: Color = Color(0.1, 0.1, 0.15, 0.95)
const PANEL_BORDER: Color = Color(0.5, 0.5, 0.6, 1.0)
const PANEL_BORDER_WIDTH: int = 2
const PANEL_CORNER_RADIUS: int = 4
const PANEL_MIN_SIZE: Vector2 = Vector2(140, 100)

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

# Cursor
const CURSOR_CHAR: String = ">"

# Font size
const FONT_SIZE: int = 16

# =============================================================================
# STATE
# =============================================================================

## Reference to the PauseMenuController (set via initialize())
var _controller: CanvasLayer = null

## Currently selected option index
var _selected_index: int = 0

## Whether the screen is actively accepting input
var _is_active: bool = false

## Reference to confirmation dialog (created on demand)
var _confirm_dialog: SFConfirmationDialog = null

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
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_build_ui()
	set_process_input(false)


## Initialize with a reference to the controller
func initialize(controller: CanvasLayer) -> void:
	_controller = controller
	_rebuild_option_labels()
	_selected_index = 0
	_update_selection_visual()
	_is_active = true
	set_process_input(true)
	AudioManager.play_sfx("menu_open", AudioManager.SFXCategory.UI)

# =============================================================================
# UI CONSTRUCTION
# =============================================================================

func _build_ui() -> void:
	# Root control fills parent
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Centered panel
	_panel = PanelContainer.new()
	_panel.name = "PauseMenuPanel"
	_panel.custom_minimum_size = PANEL_MIN_SIZE
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)

	var panel_style: StyleBoxFlat = UIUtils.create_panel_style(PANEL_BG, PANEL_BORDER, PANEL_BORDER_WIDTH, PANEL_CORNER_RADIUS)
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

# =============================================================================
# OPTION BUILDING
# =============================================================================

func _get_menu_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []

	options.append({
		"id": "resume",
		"label": "Resume",
		"action": MenuOption.RESUME,
		"enabled": true
	})

	options.append({
		"id": "settings",
		"label": "Settings",
		"action": MenuOption.SETTINGS,
		"enabled": true
	})

	options.append({
		"id": "quit_to_title",
		"label": "Quit to Title",
		"action": MenuOption.QUIT_TO_TITLE,
		"enabled": true
	})

	return options


func _rebuild_option_labels() -> void:
	# Clear existing labels
	for label: Label in _option_labels:
		if is_instance_valid(label):
			label.queue_free()
	_option_labels.clear()

	# Create labels for each option
	var options: Array[Dictionary] = _get_menu_options()

	for option: Dictionary in options:
		var option_text: String = DictUtils.get_string(option, "label", "")
		var label: Label = Label.new()
		label.text = "  " + option_text  # Indent for cursor space
		UIUtils.apply_monogram_style(label, FONT_SIZE)
		label.add_theme_color_override("font_color", TEXT_NORMAL)
		_options_container.add_child(label)
		_option_labels.append(label)


func _update_selection_visual() -> void:
	var options: Array[Dictionary] = _get_menu_options()

	for i: int in range(_option_labels.size()):
		var label: Label = _option_labels[i]
		var option: Dictionary = options[i]
		var option_label: String = DictUtils.get_string(option, "label", "")
		var is_enabled: bool = DictUtils.get_bool(option, "enabled", true)
		var is_selected: bool = i == _selected_index

		# Determine text color
		var color: Color = TEXT_NORMAL
		if not is_enabled:
			color = TEXT_DISABLED
		elif is_selected:
			color = TEXT_SELECTED

		# Apply cursor prefix for selected items
		var prefix: String = CURSOR_CHAR + " " if is_selected else "  "
		label.text = prefix + option_label
		label.add_theme_color_override("font_color", color)

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if not _is_active:
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
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("sf_cancel") or event.is_action_pressed("sf_pause"):
		_handle_resume()
		get_viewport().set_input_as_handled()


## Move selection with wrapping
func _move_selection(direction: int) -> void:
	var options: Array[Dictionary] = _get_menu_options()
	if options.is_empty():
		return

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
		MenuOption.RESUME:
			_handle_resume()
		MenuOption.SETTINGS:
			_handle_settings()
		MenuOption.QUIT_TO_TITLE:
			_handle_quit_to_title()

# =============================================================================
# ACTION HANDLERS
# =============================================================================

## Resume: close the pause menu
func _handle_resume() -> void:
	AudioManager.play_sfx("menu_cancel", AudioManager.SFXCategory.UI)
	_is_active = false
	set_process_input(false)
	PauseMenuManager.close_pause_menu()


## Settings: push the settings screen
func _handle_settings() -> void:
	AudioManager.play_sfx("menu_confirm", AudioManager.SFXCategory.UI)
	if _controller:
		_controller.push_screen("settings")


## Quit to Title: show confirmation dialog, then navigate to main menu
func _handle_quit_to_title() -> void:
	AudioManager.play_sfx("menu_confirm", AudioManager.SFXCategory.UI)

	# Create confirmation dialog on demand
	if not _confirm_dialog:
		_confirm_dialog = SFConfirmationDialog.new()
		# CRITICAL: Dialog must process when paused since we are paused
		_confirm_dialog.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		add_child(_confirm_dialog)

	# Temporarily disable menu input while dialog is showing
	_is_active = false
	set_process_input(false)

	var confirmed: bool = await _confirm_dialog.show_confirmation(
		"Quit to Title",
		"Return to title screen? Unsaved progress will be lost."
	)

	# Scene may have been freed during dialog
	if not is_instance_valid(self):
		return

	if confirmed:
		PauseMenuManager.close_pause_menu()
		SceneManager.goto_main_menu()
	else:
		# Re-enable menu input
		_is_active = true
		set_process_input(true)

# =============================================================================
# HELPERS
# =============================================================================

## Called when this screen is being removed from the stack
func _on_screen_exit() -> void:
	_is_active = false
	set_process_input(false)
