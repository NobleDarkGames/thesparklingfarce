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

## Common crafter types used by CrafterEditor and CraftingRecipeEditor
const CRAFTER_TYPES: Array[String] = [
	"(Custom)",
	"blacksmith",
	"enchanter",
	"alchemist",
	"jeweler",
	"tailor",
	"weaponsmith"
]

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
# Resource Loading Helpers
# =============================================================================

## Safely load a texture from path, returning null if invalid
static func load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var loaded: Resource = load(path)
	return loaded if loaded is Texture2D else null


## Load a texture into a TextureRect preview with appropriate tooltip
## Shared helper for portrait/sprite preview panels in various editors
static func load_texture_preview(preview: TextureRect, path: String, empty_tooltip: String = "No image assigned") -> void:
	var clean_path: String = path.strip_edges()
	if clean_path.is_empty():
		preview.texture = null
		preview.tooltip_text = empty_tooltip
		return
	if ResourceLoader.exists(clean_path):
		var loaded: Resource = load(clean_path)
		preview.texture = loaded if loaded is Texture2D else null
		preview.tooltip_text = clean_path
	else:
		preview.texture = null
		preview.tooltip_text = "File not found: " + clean_path


## Get the default asset path for a given asset type (portraits, sprites, etc.)
## Returns the most appropriate path from the active mod, or fallback
static func get_default_asset_path(asset_type: String) -> String:
	var mod_path: String = get_active_mod_path()
	if mod_path.is_empty():
		return "res://mods/"
	var assets_dir: String = mod_path.path_join("assets/" + asset_type + "/")
	if DirAccess.dir_exists_absolute(assets_dir):
		return assets_dir
	var generic_assets_dir: String = mod_path.path_join("assets/")
	if DirAccess.dir_exists_absolute(generic_assets_dir):
		return generic_assets_dir
	return mod_path


# =============================================================================
# Registry Dropdown Helpers
# =============================================================================

## Populate an OptionButton with resources from the registry
## This handles the common pattern of querying resources and adding them to a dropdown
## with mod attribution labels. Returns the number of items added (excluding none item).
##
## Parameters:
## - option: The OptionButton to populate
## - resource_type: Registry resource type (e.g., "ai_behavior", "party")
## - none_label: Text for the "none" option (e.g., "(None)")
## - id_extractor: Callable(resource) -> String that extracts the ID
## - name_extractor: Callable(resource) -> String that extracts the display name
## - store_resource: If true, stores resource as metadata; if false, stores ID string
static func populate_registry_dropdown(
	option: OptionButton,
	resource_type: String,
	none_label: String,
	id_extractor: Callable,
	name_extractor: Callable,
	store_resource: bool = true
) -> int:
	option.clear()
	option.add_item(none_label, -1)
	if not store_resource:
		option.set_item_metadata(0, "")

	var count: int = 0
	if ModLoader and ModLoader.registry:
		var resources: Array[Resource] = ModLoader.registry.get_all_resources(resource_type)
		for resource: Resource in resources:
			if not resource:
				continue
			var resource_id: String = id_extractor.call(resource)
			var display_name: String = name_extractor.call(resource)
			var label: String = get_display_with_mod_by_id(resource_type, resource_id, display_name)
			option.add_item(label)
			var metadata: Variant = resource if store_resource else resource_id
			option.set_item_metadata(option.item_count - 1, metadata)
			count += 1

	return count


## Populate an OptionButton with AI behaviors from the registry
## Convenience method for the common AI behavior dropdown pattern
static func populate_ai_behavior_dropdown(option: OptionButton, none_label: String = "(None)") -> int:
	return populate_registry_dropdown(
		option,
		"ai_behavior",
		none_label,
		func(res: Resource) -> String:
			var ai: AIBehaviorData = res as AIBehaviorData
			if ai and not ai.behavior_id.is_empty():
				return ai.behavior_id
			return res.resource_path.get_file().get_basename(),
		func(res: Resource) -> String:
			var ai: AIBehaviorData = res as AIBehaviorData
			if ai and ai.display_name:
				return ai.display_name
			var fallback_id: String = res.resource_path.get_file().get_basename()
			if ai and not ai.behavior_id.is_empty():
				fallback_id = ai.behavior_id
			return fallback_id.capitalize(),
		true  # Store resource as metadata
	)


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
# String Parsing Helpers
# =============================================================================

## Parse a comma-separated string of flags into an array
## Empty strings and whitespace-only entries are filtered out
static func parse_flag_string(flag_string: String) -> Array[String]:
	var result: Array[String] = []
	for flag in flag_string.split(","):
		var trimmed: String = flag.strip_edges()
		if not trimmed.is_empty():
			result.append(trimmed)
	return result


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
# Mod Attribution Formatting
# =============================================================================

## Format a display name with mod prefix: "[mod_id] display_name"
## Handles empty/null mod_id by using "unknown"
static func format_with_mod(mod_id: String, display_name: String) -> String:
	var safe_mod: String = mod_id if not mod_id.is_empty() else "unknown"
	return "[%s] %s" % [safe_mod, display_name]


## Extract mod_id from a resource path (res://mods/<mod_id>/...)
## Returns "unknown" if path doesn't match expected format
static func get_mod_id_from_path(path: String) -> String:
	var parts: PackedStringArray = path.split("/")
	# Expected: ["res:", "", "mods", "<mod_id>", ...]
	if parts.size() >= 4 and parts[2] == "mods":
		return parts[3]
	return "unknown"


## Get display text for a resource by type and ID, with mod attribution
## Queries the registry for mod source and formats as "[mod_id] display_name"
static func get_display_with_mod_by_id(resource_type: String, resource_id: String, display_name: String) -> String:
	var mod_id: String = ""
	if ModLoader and ModLoader.registry:
		mod_id = ModLoader.registry.get_resource_source(resource_id, resource_type)
	return format_with_mod(mod_id, display_name)


## Get item display text with mod attribution by item_id
## Convenience wrapper that looks up the item name from registry
static func get_item_display_with_mod(item_id: String) -> String:
	if ModLoader and ModLoader.registry:
		var item: ItemData = ModLoader.registry.get_item(item_id)
		if item:
			var mod_id: String = ModLoader.registry.get_resource_source(item_id, "item")
			return format_with_mod(mod_id, item.item_name)
	return format_with_mod("", item_id)


## Get status effect display text with mod attribution by effect_id
## Uses status_effect_registry for source lookup
static func get_status_effect_display_with_mod(effect_id: String) -> String:
	if ModLoader and ModLoader.status_effect_registry:
		var effect: StatusEffectData = ModLoader.status_effect_registry.get_effect(effect_id)
		var display_name: String = effect.display_name if effect and not effect.display_name.is_empty() else effect_id.capitalize()
		var mod_id: String = ModLoader.status_effect_registry.get_source_mod(effect_id)
		return format_with_mod(mod_id, display_name)
	return format_with_mod("", effect_id.capitalize())


## Format a stat name as a short abbreviation for UI display
## Examples: "max_hp" -> "HP", "strength" -> "STR", "defense" -> "DEF"
static func format_stat_abbreviation(stat_name: String) -> String:
	match stat_name.to_lower():
		"max_hp", "hp", "health":
			return "HP"
		"max_mp", "mp", "mana":
			return "MP"
		"strength", "str":
			return "STR"
		"defense", "def":
			return "DEF"
		"agility", "agi", "speed":
			return "AGI"
		"magic", "mag":
			return "MAG"
		"luck", "lck":
			return "LCK"
		"movement", "mov", "move":
			return "MOV"
		"attack", "atk":
			return "ATK"
		"evasion", "eva", "evade":
			return "EVA"
		_:
			# Fallback: uppercase first 3 chars
			var clean: String = stat_name.replace("_", " ").strip_edges()
			if clean.length() <= 3:
				return clean.to_upper()
			return clean.substr(0, 3).to_upper()


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
	## Note: step parameter is at the end for backward compatibility
	func add_number_field(label_text: String, min_val: float = 0, max_val: float = 100,
			default_val: float = 0, tooltip: String = "", step: float = 1) -> SpinBox:
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
		spin.step = step
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

		for i: int in range(options.size()):
			var opt: Variant = options[i]
			if opt is Dictionary:
				var opt_dict: Dictionary = opt
				var opt_label: String = DictUtils.get_string(opt_dict, "label", "")
				var opt_id: int = DictUtils.get_int(opt_dict, "id", i)
				dropdown.add_item(opt_label, opt_id)
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

	## Add a texture field with preview, path input, browse button, and clear button
	## Returns Dictionary with {preview: TextureRect, path_edit: LineEdit, browse_btn: Button, clear_btn: Button}
	func add_texture_field(label_text: String, placeholder: String = "", tooltip: String = "") -> Dictionary:
		var container: Control = _get_container()
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		# Label
		var label: Label = Label.new()
		label.text = label_text
		label.custom_minimum_size.x = _label_width
		if not tooltip.is_empty():
			label.tooltip_text = tooltip
		row.add_child(label)

		# Preview panel with styled background
		var preview_panel: PanelContainer = PanelContainer.new()
		preview_panel.custom_minimum_size = Vector2(36, 36)
		var preview_style: StyleBoxFlat = StyleBoxFlat.new()
		preview_style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
		preview_style.border_color = Color(0.4, 0.4, 0.5, 1.0)
		preview_style.set_border_width_all(1)
		preview_style.set_content_margin_all(2)
		preview_panel.add_theme_stylebox_override("panel", preview_style)

		var preview: TextureRect = TextureRect.new()
		preview.custom_minimum_size = Vector2(32, 32)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview_panel.add_child(preview)
		row.add_child(preview_panel)

		# Path input
		var path_edit: LineEdit = LineEdit.new()
		path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		path_edit.placeholder_text = placeholder
		if not tooltip.is_empty():
			path_edit.tooltip_text = tooltip
		if _dirty_callback.is_valid():
			path_edit.text_changed.connect(func(_t: String) -> void: _dirty_callback.call())
		row.add_child(path_edit)

		# Browse button
		var browse_btn: Button = Button.new()
		browse_btn.text = "Browse..."
		row.add_child(browse_btn)

		# Clear button
		var clear_btn: Button = Button.new()
		clear_btn.text = "X"
		clear_btn.tooltip_text = "Clear texture"
		row.add_child(clear_btn)

		container.add_child(row)

		return {
			"preview": preview,
			"path_edit": path_edit,
			"browse_btn": browse_btn,
			"clear_btn": clear_btn
		}

	## Add a Vector2i field with X and Y spinboxes
	## Returns Dictionary with {x: SpinBox, y: SpinBox}
	func add_vector2i_field(label_text: String, min_val: int = -100, max_val: int = 100,
			default: Vector2i = Vector2i.ZERO, tooltip: String = "") -> Dictionary:
		var container: Control = _get_container()
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		# Label
		var label: Label = Label.new()
		label.text = label_text
		label.custom_minimum_size.x = _label_width
		if not tooltip.is_empty():
			label.tooltip_text = tooltip
		row.add_child(label)

		# X label
		var x_label: Label = Label.new()
		x_label.text = "X:"
		row.add_child(x_label)

		# X spinbox
		var x_spin: SpinBox = SpinBox.new()
		x_spin.min_value = min_val
		x_spin.max_value = max_val
		x_spin.value = default.x
		x_spin.custom_minimum_size.x = 70
		if not tooltip.is_empty():
			x_spin.tooltip_text = tooltip
		if _dirty_callback.is_valid():
			x_spin.value_changed.connect(func(_v: float) -> void: _dirty_callback.call())
		row.add_child(x_spin)

		# Y label
		var y_label: Label = Label.new()
		y_label.text = "Y:"
		row.add_child(y_label)

		# Y spinbox
		var y_spin: SpinBox = SpinBox.new()
		y_spin.min_value = min_val
		y_spin.max_value = max_val
		y_spin.value = default.y
		y_spin.custom_minimum_size.x = 70
		if not tooltip.is_empty():
			y_spin.tooltip_text = tooltip
		if _dirty_callback.is_valid():
			y_spin.value_changed.connect(func(_v: float) -> void: _dirty_callback.call())
		row.add_child(y_spin)

		container.add_child(row)

		return {
			"x": x_spin,
			"y": y_spin
		}


# =============================================================================
# OptionButton Utilities
# =============================================================================

## Select an item in an OptionButton by matching its metadata value.
## Returns true if a matching item was found and selected, false otherwise.
## If no match is found, selects the fallback_index (default 0).
static func select_option_by_metadata(option: OptionButton, target_value: Variant, fallback_index: int = 0) -> bool:
	for i: int in range(option.item_count):
		if option.get_item_metadata(i) == target_value:
			option.select(i)
			return true
	if fallback_index >= 0 and fallback_index < option.item_count:
		option.select(fallback_index)
	return false


# =============================================================================
# Empty State Placeholders
# =============================================================================

## Create a styled placeholder label for empty lists/containers.
## Useful for "(No items)", "(None)", etc. messages.
static func add_empty_placeholder(container: Control, text: String = "(None)") -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", get_disabled_color())
	label.add_theme_font_size_override("font_size", HELP_FONT_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(label)
	return label
