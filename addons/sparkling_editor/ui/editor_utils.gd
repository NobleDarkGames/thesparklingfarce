@tool
class_name SparklingEditorUtils
extends RefCounted

## Unified utility class for Sparkling Editor
## Provides shared constants, theme colors, and helper functions used across all editors
## Consolidates the former EditorThemeUtils functionality

# =============================================================================
# UI Constants
# =============================================================================

## Standard label width for form fields (ensures alignment across editors)
const DEFAULT_LABEL_WIDTH: int = 140

## Font size for section headers
const SECTION_FONT_SIZE: int = 16

## Font size for help/hint text
const HELP_FONT_SIZE: int = 12

## Font size for standard body text
const BODY_FONT_SIZE: int = 14


# =============================================================================
# Color Access (formerly EditorThemeUtils)
# =============================================================================

## Get a color from the editor theme
## Common names: "error_color", "warning_color", "success_color",
## "font_color", "font_disabled_color", "accent_color"
static func get_editor_color(color_name: String) -> Color:
	if not Engine.is_editor_hint():
		# Fallback colors for runtime (shouldn't happen but be safe)
		return _get_fallback_color(color_name)

	var base_control: Control = EditorInterface.get_base_control()
	if not base_control:
		return _get_fallback_color(color_name)

	return base_control.get_theme_color(color_name, "Editor")


## Get error color (red) - for validation errors
static func get_error_color() -> Color:
	return get_editor_color("error_color")


## Get warning color (orange/yellow) - for non-blocking issues
static func get_warning_color() -> Color:
	return get_editor_color("warning_color")


## Get success color (green) - for confirmations
static func get_success_color() -> Color:
	# Godot doesn't have a standard "success_color", so we define one
	# that works well with both light and dark themes
	if Engine.is_editor_hint():
		var base_control: Control = EditorInterface.get_base_control()
		if base_control:
			# Try to get a green-ish color from the theme
			var accent: Color = base_control.get_theme_color("accent_color", "Editor")
			# Create a green variant
			return Color(0.4, 0.8, 0.4)
	return Color(0.4, 0.8, 0.4)


## Get disabled/hint text color
static func get_disabled_color() -> Color:
	return get_editor_color("font_disabled_color")


## Get help text color (subdued, for hints and secondary info)
static func get_help_color() -> Color:
	var base_control: Control = EditorInterface.get_base_control() if Engine.is_editor_hint() else null
	if base_control:
		return base_control.get_theme_color("font_disabled_color", "Editor")
	return Color(0.7, 0.7, 0.7)


## Get accent color (used for highlights, selections)
static func get_accent_color() -> Color:
	return get_editor_color("accent_color")


## Get font color (main text)
static func get_font_color() -> Color:
	return get_editor_color("font_color")


# =============================================================================
# StyleBox Creation (formerly EditorThemeUtils)
# =============================================================================

## Create a panel StyleBox for error display
static func create_error_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var error_color: Color = get_error_color()

	# Use a darker/lighter version for background based on error color
	style.bg_color = Color(error_color.r * 0.3, error_color.g * 0.3, error_color.b * 0.3, 0.95)
	style.border_color = error_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)

	return style


## Create a panel StyleBox for info display
static func create_info_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var accent_color: Color = get_accent_color()

	style.bg_color = Color(accent_color.r * 0.2, accent_color.g * 0.2, accent_color.b * 0.3, 0.95)
	style.border_color = Color(accent_color.r * 0.6, accent_color.g * 0.6, accent_color.b * 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)

	return style


## Create a panel StyleBox for success display
static func create_success_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var success_color: Color = get_success_color()

	style.bg_color = Color(success_color.r * 0.2, success_color.g * 0.3, success_color.b * 0.2, 0.95)
	style.border_color = success_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)

	return style


# =============================================================================
# Fallback Colors
# =============================================================================

## Provide fallback colors when editor theme is unavailable
static func _get_fallback_color(color_name: String) -> Color:
	match color_name:
		"error_color":
			return Color(1.0, 0.3, 0.3)
		"warning_color":
			return Color(1.0, 0.7, 0.2)
		"font_color":
			return Color(0.9, 0.9, 0.9)
		"font_disabled_color":
			return Color(0.6, 0.6, 0.6)
		"accent_color":
			return Color(0.4, 0.6, 1.0)
		_:
			return Color(1.0, 1.0, 1.0)


# =============================================================================
# UI Creation Helpers
# =============================================================================

## Create a section container with a styled header label
## Returns the VBoxContainer - add your fields to it after the header
static func create_section(title: String, parent: Control = null) -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)

	var label: Label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", SECTION_FONT_SIZE)
	section.add_child(label)

	var sep: HSeparator = HSeparator.new()
	section.add_child(sep)

	if parent:
		parent.add_child(section)

	return section


## Create a horizontal row with a label of standard width
## Returns the HBoxContainer - add your control(s) after the label
static func create_field_row(label_text: String, label_width: int = DEFAULT_LABEL_WIDTH, parent: Control = null) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = label_width
	row.add_child(label)

	if parent:
		parent.add_child(row)

	return row


## Create a help/hint label with subdued styling
static func create_help_label(text: String, parent: Control = null) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", get_help_color())
	label.add_theme_font_size_override("font_size", HELP_FONT_SIZE)

	if parent:
		parent.add_child(label)

	return label


## Add a standard separator to a container
static func add_separator(parent: VBoxContainer, min_height: float = 10.0) -> HSeparator:
	var sep: HSeparator = HSeparator.new()
	sep.custom_minimum_size.y = min_height
	parent.add_child(sep)
	return sep


# =============================================================================
# Active Mod Helpers
# =============================================================================

## Get the active mod's base directory path, or empty string if none selected
## Callers should check for empty return and show appropriate error
static func get_active_mod_path() -> String:
	if not ModLoader:
		return ""
	var active_mod: ModManifest = ModLoader.get_active_mod()
	if active_mod:
		return active_mod.mod_directory
	return ""


## Get the active mod's ID, or empty string if none selected
static func get_active_mod_id() -> String:
	if not ModLoader:
		return ""
	var active_mod: ModManifest = ModLoader.get_active_mod()
	if active_mod:
		return active_mod.mod_id
	return ""


## Get the active mod's folder name (e.g., "_sandbox" from path)
static func get_active_mod_folder() -> String:
	if not ModLoader:
		return ""
	var active_mod: ModManifest = ModLoader.get_active_mod()
	if active_mod:
		return active_mod.mod_directory.get_file()
	return ""


# =============================================================================
# Mod Directory Scanning
# =============================================================================

## Scan all mod directories and return their folder names
## Returns Array of mod folder names (not full paths)
static func scan_all_mod_directories() -> Array[String]:
	var mods: Array[String] = []
	var mods_dir: DirAccess = DirAccess.open("res://mods/")
	if not mods_dir:
		return mods

	mods_dir.list_dir_begin()
	var mod_name: String = mods_dir.get_next()

	while mod_name != "":
		if mods_dir.current_is_dir() and not mod_name.begins_with("."):
			mods.append(mod_name)
		mod_name = mods_dir.get_next()

	mods_dir.list_dir_end()
	return mods


## Scan a specific subdirectory across all mods
## Returns Array of {mod_id: String, path: String, filename: String}
static func scan_mods_for_files(subdir: String, extension: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	var mods: Array[String] = scan_all_mod_directories()
	for mod_name: String in mods:
		var dir_path: String = "res://mods/%s/%s" % [mod_name, subdir]
		var dir: DirAccess = DirAccess.open(dir_path)
		if not dir:
			continue

		dir.list_dir_begin()
		var file_name: String = dir.get_next()

		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(extension):
				results.append({
					"mod_id": mod_name,
					"path": dir_path.path_join(file_name),
					"filename": file_name
				})
			file_name = dir.get_next()

		dir.list_dir_end()

	return results


# =============================================================================
# ID Generation
# =============================================================================

## Generate a valid snake_case ID from a display name
## Example: "Town Guard" -> "town_guard"
static func generate_id_from_name(display_name: String) -> String:
	var name_text: String = display_name.strip_edges()
	if name_text.is_empty():
		return ""

	# Convert to snake_case
	var id: String = name_text.to_lower()
	id = id.replace(" ", "_")
	id = id.replace("-", "_")

	# Remove non-alphanumeric characters except underscore
	var valid_id: String = ""
	for c: String in id:
		var code: int = c.unicode_at(0)
		var is_digit: bool = code >= 48 and code <= 57
		if c.is_valid_identifier() or c == "_" or is_digit:
			valid_id += c

	# Clean up consecutive underscores
	while "__" in valid_id:
		valid_id = valid_id.replace("__", "_")

	return valid_id.strip_edges()


## Generate a namespaced ID (mod_id:resource_id)
static func generate_namespaced_id(mod_id: String, resource_name: String) -> String:
	var clean_name: String = generate_id_from_name(resource_name)
	if clean_name.is_empty():
		return ""
	return "%s:%s" % [mod_id, clean_name]


# =============================================================================
# File Operations
# =============================================================================

## Ensure a directory exists, creating it if needed
## Returns true if directory exists or was created successfully
static func ensure_directory_exists(dir_path: String) -> bool:
	if DirAccess.dir_exists_absolute(dir_path):
		return true

	var err: Error = DirAccess.make_dir_recursive_absolute(dir_path)
	if err != OK:
		push_error("SparklingEditorUtils: Failed to create directory: %s - %s" % [dir_path, error_string(err)])
		return false

	return true


## Get a unique filename by appending a number if the file already exists
## Example: "npc.tres" -> "npc_2.tres" if npc.tres exists
static func get_unique_filename(directory: String, base_name: String, extension: String) -> String:
	var full_path: String = directory.path_join(base_name + extension)
	if not FileAccess.file_exists(full_path):
		return base_name + extension

	var counter: int = 2
	while FileAccess.file_exists(directory.path_join("%s_%d%s" % [base_name, counter, extension])):
		counter += 1

	return "%s_%d%s" % [base_name, counter, extension]


# =============================================================================
# Resource Display Helpers
# =============================================================================

## Get a resource display name with source mod prefix: "[mod_id] Name"
## Works with CharacterData, NPCData, or any Resource with a name property
static func get_resource_display_name_with_mod(resource: Resource, name_property: String = "character_name") -> String:
	if not resource:
		return "(Unknown)"

	# Get the name from the resource with proper null handling
	# Note: str(null) returns "Null" which would display incorrectly to users
	var display_name: String = ""
	var raw_value: Variant = resource.get(name_property) if name_property in resource else null

	if raw_value != null and str(raw_value).strip_edges() != "":
		display_name = str(raw_value)
	elif "resource_name" in resource:
		var resource_name_value: Variant = resource.get("resource_name")
		if resource_name_value != null and str(resource_name_value).strip_edges() != "":
			display_name = str(resource_name_value)
		else:
			display_name = resource.resource_path.get_file().get_basename()
	else:
		display_name = resource.resource_path.get_file().get_basename()

	# Get source mod
	var mod_id: String = ""
	if ModLoader and ModLoader.registry:
		var resource_id: String = resource.resource_path.get_file().get_basename()
		mod_id = ModLoader.registry.get_resource_source(resource_id)

	if mod_id.is_empty():
		return display_name
	return "[%s] %s" % [mod_id, display_name]


## Get character display name with source mod prefix (convenience wrapper)
static func get_character_display_name(character: CharacterData) -> String:
	return get_resource_display_name_with_mod(character, "character_name")


# =============================================================================
# FormBuilder - Fluent API for Building Editor Forms
# =============================================================================

## Creates a FormBuilder for constructing editor forms with a fluent API.
## Reduces boilerplate code when building consistent labeled fields.
##
## Usage:
##   var form = SparklingEditorUtils.create_form(detail_panel)
##   name_edit = form.add_text_field("Name:", "Enter character name...")
##   level_spin = form.add_number_field("Level:", 1, 99)
##   form.add_section("Stats")
##   hp_spin = form.add_number_field("HP:", 1, 999, 20)
static func create_form(parent: Control, label_width: int = DEFAULT_LABEL_WIDTH) -> FormBuilder:
	return FormBuilder.new(parent, label_width)


## FormBuilder class for fluent form construction
class FormBuilder extends RefCounted:
	var _parent: Control
	var _label_width: int
	var _current_section: VBoxContainer
	var _dirty_callback: Callable

	## Public access to the current container (current section or parent)
	var container: Control:
		get:
			return _get_container()

	func _init(parent: Control, label_width: int = DEFAULT_LABEL_WIDTH) -> void:
		_parent = parent
		_label_width = label_width
		_current_section = null
		_dirty_callback = Callable()

	## Set a callback to invoke when any field value changes (for dirty tracking)
	func on_change(callback: Callable) -> FormBuilder:
		_dirty_callback = callback
		return self

	## Start a new section with a header
	func add_section(title: String) -> FormBuilder:
		_current_section = VBoxContainer.new()
		_current_section.add_theme_constant_override("separation", 8)

		var label: Label = Label.new()
		label.text = title
		label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
		_current_section.add_child(label)

		var sep: HSeparator = HSeparator.new()
		_current_section.add_child(sep)

		_parent.add_child(_current_section)
		return self

	## Get the container to add fields to (current section or parent)
	func _get_container() -> Control:
		if _current_section:
			return _current_section
		return _parent

	## Add a text input field (LineEdit)
	func add_text_field(label_text: String, placeholder: String = "", tooltip: String = "") -> LineEdit:
		var container: Control = _get_container()
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var label: Label = Label.new()
		label.text = label_text
		label.custom_minimum_size.x = _label_width
		if not tooltip.is_empty():
			label.tooltip_text = tooltip
		row.add_child(label)

		var edit: LineEdit = LineEdit.new()
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.placeholder_text = placeholder
		if not tooltip.is_empty():
			edit.tooltip_text = tooltip
		if _dirty_callback.is_valid():
			edit.text_changed.connect(func(_t: String) -> void: _dirty_callback.call())
		row.add_child(edit)

		container.add_child(row)
		return edit

	## Add a multi-line text field (TextEdit)
	func add_text_area(label_text: String, min_height: float = 80, tooltip: String = "") -> TextEdit:
		var container: Control = _get_container()

		var label: Label = Label.new()
		label.text = label_text
		if not tooltip.is_empty():
			label.tooltip_text = tooltip
		container.add_child(label)

		var edit: TextEdit = TextEdit.new()
		edit.custom_minimum_size.y = min_height
		if not tooltip.is_empty():
			edit.tooltip_text = tooltip
		if _dirty_callback.is_valid():
			edit.text_changed.connect(_dirty_callback)
		container.add_child(edit)

		return edit

	## Add a number input field (SpinBox)
	func add_number_field(label_text: String, min_val: float = 0, max_val: float = 100,
			default_val: float = 0, tooltip: String = "") -> SpinBox:
		var container: Control = _get_container()
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var label: Label = Label.new()
		label.text = label_text
		label.custom_minimum_size.x = _label_width
		if not tooltip.is_empty():
			label.tooltip_text = tooltip
		row.add_child(label)

		var spin: SpinBox = SpinBox.new()
		spin.min_value = min_val
		spin.max_value = max_val
		spin.value = default_val
		if not tooltip.is_empty():
			spin.tooltip_text = tooltip
		if _dirty_callback.is_valid():
			spin.value_changed.connect(func(_v: float) -> void: _dirty_callback.call())
		row.add_child(spin)

		container.add_child(row)
		return spin

	## Add a float number field with step control
	func add_float_field(label_text: String, min_val: float = 0.0, max_val: float = 1.0,
			step: float = 0.1, default_val: float = 0.0, tooltip: String = "") -> SpinBox:
		var spin: SpinBox = add_number_field(label_text, min_val, max_val, default_val, tooltip)
		spin.step = step
		return spin

	## Add a dropdown field (OptionButton)
	func add_dropdown(label_text: String, options: Array, tooltip: String = "") -> OptionButton:
		var container: Control = _get_container()
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var label: Label = Label.new()
		label.text = label_text
		label.custom_minimum_size.x = _label_width
		if not tooltip.is_empty():
			label.tooltip_text = tooltip
		row.add_child(label)

		var dropdown: OptionButton = OptionButton.new()
		dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not tooltip.is_empty():
			dropdown.tooltip_text = tooltip

		for i in range(options.size()):
			var opt: Variant = options[i]
			if opt is Dictionary:
				dropdown.add_item(opt.get("label", ""), opt.get("id", i))
			else:
				dropdown.add_item(str(opt), i)

		if _dirty_callback.is_valid():
			dropdown.item_selected.connect(func(_idx: int) -> void: _dirty_callback.call())
		row.add_child(dropdown)

		container.add_child(row)
		return dropdown

	## Add a checkbox field
	func add_checkbox(label_text: String, checkbox_text: String = "",
			default_checked: bool = false, tooltip: String = "") -> CheckBox:
		var container: Control = _get_container()
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var label: Label = Label.new()
		label.text = label_text
		label.custom_minimum_size.x = _label_width
		if not tooltip.is_empty():
			label.tooltip_text = tooltip
		row.add_child(label)

		var check: CheckBox = CheckBox.new()
		check.text = checkbox_text
		check.button_pressed = default_checked
		if not tooltip.is_empty():
			check.tooltip_text = tooltip
		if _dirty_callback.is_valid():
			check.toggled.connect(func(_pressed: bool) -> void: _dirty_callback.call())
		row.add_child(check)

		container.add_child(row)
		return check

	## Add a standalone checkbox (no label column, just the checkbox with its text)
	func add_standalone_checkbox(checkbox_text: String, default_checked: bool = false,
			tooltip: String = "") -> CheckBox:
		var container: Control = _get_container()

		var check: CheckBox = CheckBox.new()
		check.text = checkbox_text
		check.button_pressed = default_checked
		if not tooltip.is_empty():
			check.tooltip_text = tooltip
		if _dirty_callback.is_valid():
			check.toggled.connect(func(_pressed: bool) -> void: _dirty_callback.call())
		container.add_child(check)

		return check

	## Add a help/hint label
	func add_help_text(text: String) -> Label:
		var container: Control = _get_container()

		var label: Label = Label.new()
		label.text = text
		label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
		label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		container.add_child(label)

		return label

	## Add a separator
	func add_separator(min_height: float = 10.0) -> HSeparator:
		var container: Control = _get_container()

		var sep: HSeparator = HSeparator.new()
		sep.custom_minimum_size.y = min_height
		container.add_child(sep)

		return sep

	## Add a custom control with a label
	func add_labeled_control(label_text: String, control: Control, tooltip: String = "") -> Control:
		var container: Control = _get_container()
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var label: Label = Label.new()
		label.text = label_text
		label.custom_minimum_size.x = _label_width
		if not tooltip.is_empty():
			label.tooltip_text = tooltip
		row.add_child(label)

		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not tooltip.is_empty():
			control.tooltip_text = tooltip
		row.add_child(control)

		container.add_child(row)
		return control

	## Add a section label without creating a new container (inline section header)
	func add_section_label(text: String) -> Label:
		var container: Control = _get_container()

		var label: Label = Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
		container.add_child(label)

		return label

	## Get the current parent container
	func get_container() -> Control:
		return _get_container()

	## Get the form's root parent
	func get_parent() -> Control:
		return _parent
