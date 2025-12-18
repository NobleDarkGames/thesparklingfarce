@tool
class_name TexturePickerBase
extends HBoxContainer

## Base class for texture/sprite picker components.
## Provides mod-aware file browsing, validation infrastructure, and preview panels.
## Subclasses override validation and preview behavior for specific asset types.
##
## Usage:
##   # Create a subclass that overrides _validate_texture() and optionally
##   # _create_preview_control(), _update_preview(), and _clear_preview()
##   var picker: PortraitPicker = PortraitPicker.new()
##   picker.texture_selected.connect(_on_portrait_selected)
##   add_child(picker)
##
## This base class handles:
## - Mod-aware file browsing (opens to active mod's directory)
## - Path validation and texture loading
## - Preview panel with consistent styling
## - Validation icon states (success, warning, error, none)
## - Clear button functionality

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when a texture is selected (path may be empty on load failure)
signal texture_selected(path: String, texture: Texture2D)

## Emitted when the texture is cleared (user clicked Clear or set empty path)
signal texture_cleared()

## Emitted when validation state changes
## is_valid: Whether the current texture passes validation
## message: Human-readable validation message (empty if valid with no warnings)
signal validation_changed(is_valid: bool, message: String)

# =============================================================================
# EXPORTED CONFIGURATION PROPERTIES
# =============================================================================

## Label text displayed before the picker controls
@export var label_text: String = "Texture:":
	set(value):
		label_text = value
		if _label:
			_label.text = value
			_label.visible = not value.is_empty()

## Minimum width for the label (for alignment across multiple pickers)
@export var label_min_width: float = 120.0:
	set(value):
		label_min_width = value
		if _label:
			_label.custom_minimum_size.x = value

## Placeholder text shown in the path LineEdit when empty
@export var placeholder_text: String = "res://mods/<mod>/assets/...":
	set(value):
		placeholder_text = value
		if _path_edit:
			_path_edit.placeholder_text = value

## Size of the preview panel (content area, not including padding)
@export var preview_size: Vector2 = Vector2(48, 48):
	set(value):
		preview_size = value
		if _preview_control:
			_preview_control.custom_minimum_size = value

## File type filters for the browse dialog
@export var file_filters: PackedStringArray = PackedStringArray(["*.png ; PNG", "*.webp ; WebP"])

## Default subdirectory within mod folder for browse dialog
## e.g., "assets/portraits/" opens to res://mods/<active_mod>/assets/portraits/
@export var default_browse_subpath: String = "assets/"

## Whether this picker allows clearing (showing Clear button)
@export var allow_clear: bool = true:
	set(value):
		allow_clear = value
		if _clear_button:
			_clear_button.visible = value

## Tooltip text for the browse button
@export var browse_tooltip: String = "Browse for texture file":
	set(value):
		browse_tooltip = value
		if _browse_button:
			_browse_button.tooltip_text = value

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Currently selected texture path (empty string if none)
var _current_path: String = ""

## Currently loaded texture (null if none or load failed)
var _current_texture: Texture2D = null

## Whether current selection passes validation
var _is_valid: bool = false

## Current validation message (empty if valid with no warnings)
var _validation_message: String = ""

## Current validation severity ("error", "warning", "info", "success", or "none")
var _validation_severity: String = "none"

# =============================================================================
# UI COMPONENTS
# =============================================================================

var _label: Label
var _preview_panel: PanelContainer
var _preview_control: Control  # TextureRect or AnimatedSprite2D (subclass chooses)
var _path_edit: LineEdit
var _browse_button: Button
var _clear_button: Button
var _validation_icon: TextureRect
var _file_dialog: EditorFileDialog

## Track if we've been initialized
var _initialized: bool = false


func _init() -> void:
	# Set up layout
	add_theme_constant_override("separation", 6)


func _ready() -> void:
	_setup_ui()
	_initialized = true

	# Apply initial validation state (no selection)
	_update_validation_display()


func _exit_tree() -> void:
	# Clean up the file dialog if it exists
	if _file_dialog and is_instance_valid(_file_dialog):
		_file_dialog.queue_free()
		_file_dialog = null


# =============================================================================
# UI SETUP
# =============================================================================

func _setup_ui() -> void:
	# Create label
	_label = Label.new()
	_label.text = label_text
	_label.visible = not label_text.is_empty()
	_label.custom_minimum_size.x = label_min_width
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)

	# Create preview panel with styling
	_preview_panel = PanelContainer.new()
	_preview_panel.custom_minimum_size = preview_size + Vector2(8, 8)  # Add padding
	_preview_panel.add_theme_stylebox_override("panel", _create_preview_panel_style())
	add_child(_preview_panel)

	# Create preview control (subclasses can override _create_preview_control)
	_preview_control = _create_preview_control()
	if _preview_control:
		_preview_panel.add_child(_preview_control)

	# Create path LineEdit
	_path_edit = LineEdit.new()
	_path_edit.placeholder_text = placeholder_text
	_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_edit.custom_minimum_size.x = 150
	_path_edit.text_submitted.connect(_on_path_submitted)
	_path_edit.focus_exited.connect(_on_path_focus_exited)
	add_child(_path_edit)

	# Create Browse button
	_browse_button = Button.new()
	_browse_button.text = "Browse"
	_browse_button.tooltip_text = browse_tooltip
	_browse_button.custom_minimum_size.x = 60
	_browse_button.pressed.connect(_on_browse_pressed)
	add_child(_browse_button)

	# Create Clear button
	_clear_button = Button.new()
	_clear_button.text = "Clear"
	_clear_button.tooltip_text = "Clear the selected texture"
	_clear_button.custom_minimum_size.x = 50
	_clear_button.visible = allow_clear
	_clear_button.pressed.connect(_on_clear_pressed)
	add_child(_clear_button)

	# Create validation icon
	_validation_icon = TextureRect.new()
	_validation_icon.custom_minimum_size = Vector2(20, 20)
	_validation_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_validation_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(_validation_icon)

	# Create the file dialog (deferred to ensure EditorInterface is available)
	call_deferred("_setup_file_dialog")


func _setup_file_dialog() -> void:
	if not Engine.is_editor_hint():
		return

	# Guard against duplicate setup on plugin reload
	if _file_dialog:
		return

	_file_dialog = EditorFileDialog.new()
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_file_dialog.title = "Select Texture"

	# Set file filters
	for filter: String in file_filters:
		_file_dialog.add_filter(filter)

	# Check for existing connection before connecting (safety on plugin reload)
	if not _file_dialog.file_selected.is_connected(_on_file_selected):
		_file_dialog.file_selected.connect(_on_file_selected)

	# Add to editor base control so it appears properly
	var base_control: Control = EditorInterface.get_base_control()
	if base_control:
		base_control.add_child(_file_dialog)


func _create_preview_panel_style() -> StyleBoxFlat:
	## Create the preview panel StyleBox with dark background and subtle border
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15)  # Dark background
	style.border_color = Color(0.23, 0.23, 0.27)  # Subtle border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	return style


# =============================================================================
# PUBLIC API METHODS
# =============================================================================

func set_texture_path(path: String) -> void:
	## Set the texture by path. Loads texture, validates, updates preview.
	## Emits texture_selected if load succeeds, validation_changed always.

	_current_path = path

	if _path_edit:
		_path_edit.text = path

	if path.is_empty():
		_current_texture = null
		_is_valid = false
		_validation_message = ""
		_validation_severity = "none"
		_clear_preview()
		_update_validation_display()
		texture_cleared.emit()
		validation_changed.emit(false, "")
		return

	# Attempt to load the texture
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			_current_texture = loaded as Texture2D
		else:
			_current_texture = null
	else:
		_current_texture = null

	# Validate the texture
	var validation_result: Dictionary = _validate_texture(path, _current_texture)
	_is_valid = validation_result.get("valid", false)
	_validation_message = validation_result.get("message", "")
	_validation_severity = validation_result.get("severity", "error")

	# Update preview
	if _current_texture:
		_update_preview(_current_texture)
	else:
		_clear_preview()

	# Update validation display
	_update_validation_display()

	# Emit signals
	texture_selected.emit(path, _current_texture)
	validation_changed.emit(_is_valid, _validation_message)


func get_texture_path() -> String:
	## Get the currently selected path (empty string if none)
	return _current_path


func get_texture() -> Texture2D:
	## Get the currently loaded texture (null if none or invalid)
	return _current_texture


func is_valid() -> bool:
	## Check if current selection is valid (passes validation)
	return _is_valid


func get_validation_message() -> String:
	## Get the current validation message
	return _validation_message


func clear() -> void:
	## Clear the current selection. Emits texture_cleared.
	set_texture_path("")


func revalidate() -> void:
	## Force revalidation of current texture (useful after external changes)
	if not _current_path.is_empty():
		set_texture_path(_current_path)


# =============================================================================
# VIRTUAL METHODS (Override in Subclasses)
# =============================================================================

func _validate_texture(path: String, texture: Texture2D) -> Dictionary:
	## Validate the loaded texture. Override to implement type-specific validation.
	## Returns Dictionary: { "valid": bool, "message": String, "severity": String }
	## severity: "error" (red), "warning" (yellow), "info" (blue), "success" (green)

	# Base implementation: just check file exists
	if texture == null:
		return { "valid": false, "message": "File not found or not a valid texture", "severity": "error" }

	return { "valid": true, "message": "", "severity": "success" }


func _create_preview_control() -> Control:
	## Create the preview control. Override to use AnimatedSprite2D instead of TextureRect.
	## Called once during _setup_ui().

	var rect: TextureRect = TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = preview_size
	return rect


func _update_preview(texture: Texture2D) -> void:
	## Update the preview display. Override for animated previews.
	## Called after texture is loaded and validated.

	if _preview_control is TextureRect:
		(_preview_control as TextureRect).texture = texture


func _clear_preview() -> void:
	## Clear the preview display. Override for animated previews.

	if _preview_control is TextureRect:
		(_preview_control as TextureRect).texture = null


# =============================================================================
# INTERNAL METHODS
# =============================================================================

func _update_validation_display() -> void:
	## Update the validation icon and tooltip based on current state

	if not _validation_icon:
		return

	var icon_name: String = ""
	var tooltip: String = ""

	match _validation_severity:
		"success":
			icon_name = "StatusSuccess"
			tooltip = _validation_message if not _validation_message.is_empty() else "Valid"
		"warning":
			icon_name = "StatusWarning"
			tooltip = _validation_message
		"error":
			icon_name = "StatusError"
			tooltip = _validation_message
		"info":
			icon_name = "NodeInfo"  # Using NodeInfo as there's no StatusInfo
			tooltip = _validation_message
		"none", _:
			icon_name = ""
			tooltip = "No file selected"

	# Set the icon texture
	if not icon_name.is_empty() and Engine.is_editor_hint():
		_validation_icon.texture = _get_editor_icon(icon_name)
	else:
		_validation_icon.texture = null

	_validation_icon.tooltip_text = tooltip

	# Update path edit styling for errors
	if _path_edit:
		if _validation_severity == "error" and not _current_path.is_empty():
			_path_edit.add_theme_color_override("font_color", SparklingEditorUtils.get_error_color())
		else:
			_path_edit.remove_theme_color_override("font_color")


func _get_editor_icon(name: String) -> Texture2D:
	## Get an icon from the editor theme
	if Engine.is_editor_hint():
		var base_control: Control = EditorInterface.get_base_control()
		if base_control:
			return base_control.get_theme_icon(name, "EditorIcons")
	return null


func _get_active_mod_path() -> String:
	## Get the path to the active mod's directory
	## Returns empty string if no active mod
	## Note: Delegates to SparklingEditorUtils.get_active_mod_path()
	var mod_path: String = SparklingEditorUtils.get_active_mod_path()
	# Ensure trailing slash for backwards compatibility
	if not mod_path.is_empty() and not mod_path.ends_with("/"):
		return mod_path + "/"
	return mod_path


func _get_browse_initial_path() -> String:
	## Get the initial path for the browse dialog
	## Opens to: current path's directory, or active mod's default subpath, or res://

	# If we have a current path, use its directory
	if not _current_path.is_empty():
		var dir_path: String = _current_path.get_base_dir()
		if DirAccess.dir_exists_absolute(dir_path):
			return dir_path

	# Try to use the active mod's directory with default subpath
	var mod_path: String = _get_active_mod_path()
	if not mod_path.is_empty():
		var subpath: String = mod_path + default_browse_subpath
		# Ensure the directory exists
		if DirAccess.dir_exists_absolute(subpath):
			return subpath
		# Fall back to just the mod path
		if DirAccess.dir_exists_absolute(mod_path):
			return mod_path

	# Fall back to res://mods/ or res://
	if DirAccess.dir_exists_absolute("res://mods/"):
		return "res://mods/"

	return "res://"


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_browse_pressed() -> void:
	## Handle Browse button press - open the file dialog

	if not _file_dialog:
		push_warning("TexturePickerBase: File dialog not available")
		return

	# Set initial directory
	var initial_path: String = _get_browse_initial_path()
	_file_dialog.current_dir = initial_path

	_file_dialog.popup_centered_ratio(0.6)


func _on_file_selected(path: String) -> void:
	## Handle file selection from the dialog
	set_texture_path(path)


func _on_clear_pressed() -> void:
	## Handle Clear button press

	# Optional: Add a brief visual feedback (flash)
	if _preview_panel:
		var original_modulate: Color = _preview_panel.modulate
		_preview_panel.modulate = Color(1.5, 1.5, 1.5)

		var tween: Tween = create_tween()
		tween.tween_property(_preview_panel, "modulate", original_modulate, 0.15)

	clear()


func _on_path_submitted(new_path: String) -> void:
	## Handle Enter key in path LineEdit
	set_texture_path(new_path.strip_edges())


func _on_path_focus_exited() -> void:
	## Handle focus leaving the path LineEdit
	## Only update if the path changed

	if not _path_edit:
		return

	var entered_path: String = _path_edit.text.strip_edges()
	if entered_path != _current_path:
		set_texture_path(entered_path)


# =============================================================================
# ERROR ANIMATION (Optional UX Enhancement)
# =============================================================================

func _show_validation_error_animation() -> void:
	## Subtle shake animation when validation fails
	## Can be called by subclasses when they want to emphasize an error

	if not _path_edit:
		return

	var original_x: float = _path_edit.position.x
	var tween: Tween = create_tween()
	tween.tween_property(_path_edit, "position:x", original_x + 3, 0.05)
	tween.tween_property(_path_edit, "position:x", original_x - 3, 0.05)
	tween.tween_property(_path_edit, "position:x", original_x, 0.05)
