@tool
class_name SparklingEditorUtils
extends RefCounted

## Utility class for common editor operations
## Provides shared constants and helper functions used across multiple editors

# =============================================================================
# Constants - UI Sizing
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
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
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
