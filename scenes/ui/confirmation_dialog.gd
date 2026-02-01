class_name SFConfirmationDialog
extends Control

## SFConfirmationDialog - Reusable yes/no confirmation prompt
##
## A modal dialog for destructive actions that require user confirmation.
## Follows existing UI patterns from ActionMenu and ItemMenu.
##
## Usage:
##   var dialog: SFConfirmationDialog = SFConfirmationDialog.new()
##   add_child(dialog)
##   var confirmed: bool = await dialog.show_confirmation(
##       "Drop Item?",
##       "Discard Healing Herb?"
##   )
##   if confirmed:
##       # Do the action

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when user confirms the action
signal confirmed()

## Emitted when user cancels the action
signal cancelled()

# =============================================================================
# CONSTANTS
# =============================================================================

const COLOR_PANEL_BG: Color = Color(0.1, 0.1, 0.15, 0.98)
const COLOR_BORDER: Color = Color(0.6, 0.6, 0.7, 1.0)
const COLOR_TITLE: Color = Color(1.0, 1.0, 0.9, 1.0)
const COLOR_MESSAGE: Color = Color(0.8, 0.8, 0.85, 1.0)
const COLOR_BUTTON_NORMAL: Color = Color(0.2, 0.2, 0.25, 1.0)
const COLOR_BUTTON_HOVER: Color = Color(0.3, 0.3, 0.35, 1.0)
const COLOR_BUTTON_SELECTED: Color = Color(1.0, 1.0, 0.3, 1.0)
const COLOR_BUTTON_TEXT: Color = Color(0.9, 0.9, 0.9, 1.0)

# =============================================================================
# STATE
# =============================================================================

## Currently selected button (0 = Yes, 1 = No)
var _selected_index: int = 1  # Default to "No" for safety

## Whether the dialog is currently showing
var _is_showing: bool = false

# =============================================================================
# UI REFERENCES
# =============================================================================

var _panel: PanelContainer = null
var _title_label: Label = null
var _message_label: Label = null
var _button_container: HBoxContainer = null
var _yes_button: Button = null
var _no_button: Button = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_build_ui()
	visible = false
	set_process_input(false)


func _build_ui() -> void:
	# Full screen semi-transparent background to block clicks
	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.0, 0.0, 0.0, 0.5)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Center panel
	_panel = PanelContainer.new()
	_panel.name = "DialogPanel"
	_panel.custom_minimum_size = Vector2(200, 80)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)

	var panel_style: StyleBoxFlat = UIUtils.create_panel_style(COLOR_PANEL_BG, COLOR_BORDER, 2)
	panel_style.content_margin_bottom = 8
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 8
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	# Main layout
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	UIUtils.apply_monogram_style(_title_label, 16)
	_title_label.modulate = COLOR_TITLE
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Message
	_message_label = Label.new()
	_message_label.name = "MessageLabel"
	UIUtils.apply_monogram_style(_message_label, 16)
	_message_label.modulate = COLOR_MESSAGE
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_message_label)

	# Button container
	_button_container = HBoxContainer.new()
	_button_container.name = "ButtonContainer"
	_button_container.add_theme_constant_override("separation", 16)
	_button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_button_container)

	# Yes button
	_yes_button = _create_button("Yes")
	_yes_button.pressed.connect(_on_yes_pressed)
	_button_container.add_child(_yes_button)

	# No button
	_no_button = _create_button("No")
	_no_button.pressed.connect(_on_no_pressed)
	_button_container.add_child(_no_button)


func _create_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	UIUtils.apply_monogram_style(button, 16)
	button.custom_minimum_size = Vector2(48, 20)

	var normal_style: StyleBoxFlat = UIUtils.create_panel_style(COLOR_BUTTON_NORMAL, Color(0.4, 0.4, 0.5, 1.0), 1)
	button.add_theme_stylebox_override("normal", normal_style)

	var hover_style: StyleBoxFlat = normal_style.duplicate()
	hover_style.bg_color = COLOR_BUTTON_HOVER
	button.add_theme_stylebox_override("hover", hover_style)

	var focus_style: StyleBoxFlat = normal_style.duplicate()
	focus_style.bg_color = COLOR_BUTTON_HOVER
	focus_style.border_color = COLOR_BUTTON_SELECTED
	button.add_theme_stylebox_override("focus", focus_style)

	return button


# =============================================================================
# PUBLIC API
# =============================================================================

## Show the confirmation dialog and wait for user response
## @param title: Short title text (e.g., "Drop Item?")
## @param message: Longer descriptive message (e.g., "Discard Healing Herb?")
## @return: true if confirmed, false if cancelled
func show_confirmation(title: String, message: String) -> bool:
	_title_label.text = title
	_message_label.text = message

	# Default to "No" for safety
	_selected_index = 1
	_update_button_visuals()

	_is_showing = true
	visible = true
	set_process_input(true)

	# Play dialog open sound
	AudioManager.play_sfx("menu_open", AudioManager.SFXCategory.UI)

	# Wait for user response
	var result: Array = await _wait_for_response()
	var first_val: Variant = result[0] if result.size() > 0 else false
	return first_val if first_val is bool else false


## Check if the dialog is currently visible
func is_dialog_active() -> bool:
	return _is_showing


# =============================================================================
# INTERNAL
# =============================================================================

func _wait_for_response() -> Array:
	# Wait for either confirmed or cancelled signal
	var signals: Array[Signal] = [confirmed, cancelled]

	# Use a simple approach - wait for the first signal
	while _is_showing:
		await get_tree().process_frame

	# Return result based on which signal was emitted
	return [_selected_index == 0]


func _update_button_visuals() -> void:
	# Update Yes button
	if _selected_index == 0:
		_yes_button.modulate = COLOR_BUTTON_SELECTED
	else:
		_yes_button.modulate = COLOR_BUTTON_TEXT

	# Update No button
	if _selected_index == 1:
		_no_button.modulate = COLOR_BUTTON_SELECTED
	else:
		_no_button.modulate = COLOR_BUTTON_TEXT


func _confirm() -> void:
	_selected_index = 0
	_hide_dialog()
	AudioManager.play_sfx("menu_confirm", AudioManager.SFXCategory.UI)
	confirmed.emit()


func _cancel() -> void:
	_selected_index = 1
	_hide_dialog()
	AudioManager.play_sfx("menu_cancel", AudioManager.SFXCategory.UI)
	cancelled.emit()


func _hide_dialog() -> void:
	_is_showing = false
	visible = false
	set_process_input(false)


# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if not _is_showing:
		return

	# Left/Right navigation
	if event.is_action_pressed("ui_left"):
		if _selected_index != 0:
			_selected_index = 0
			_update_button_visuals()
			AudioManager.play_sfx("cursor_move", AudioManager.SFXCategory.UI)
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_right"):
		if _selected_index != 1:
			_selected_index = 1
			_update_button_visuals()
			AudioManager.play_sfx("cursor_move", AudioManager.SFXCategory.UI)
		get_viewport().set_input_as_handled()

	# Confirm selection
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("sf_confirm"):
		if _selected_index == 0:
			_confirm()
		else:
			_cancel()
		get_viewport().set_input_as_handled()

	# Cancel (always means No)
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("sf_cancel"):
		_cancel()
		get_viewport().set_input_as_handled()


# =============================================================================
# BUTTON HANDLERS
# =============================================================================

func _on_yes_pressed() -> void:
	_confirm()


func _on_no_pressed() -> void:
	_cancel()
