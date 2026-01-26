@tool
extends Control
class_name JsonEditorBase

## Base class for JSON-based editors (MapMetadata, Cinematic, Campaign)
## Provides common functionality for error panels, JSON loading/saving,
## and directory scanning that was previously duplicated across editors.
##
## Usage:
##   extends JsonEditorBase
##
##   func _ready():
##       resource_type_name = "Cinematic"
##       resource_dir_name = "cinematics"
##       super._ready()

## The type name for display in UI (e.g., "Cinematic", "Map", "Campaign")
var resource_type_name: String = "Resource"

## The directory name under mods/*/data/ (e.g., "cinematics", "maps", "campaigns")
var resource_dir_name: String = ""

## File extension to scan for (default: ".json")
var file_extension: String = ".json"

## Common UI components
var error_panel: PanelContainer
var error_label: RichTextLabel

## Track dirty state for unsaved changes
var is_dirty: bool = false

## Flag to prevent change callbacks during programmatic UI updates
var _updating_ui: bool = false


# =============================================================================
# PUBLIC REFRESH INTERFACE
# =============================================================================

## Standard refresh method for EditorTabRegistry
## Override this in child classes to call the appropriate refresh method
func refresh() -> void:
	# Default implementation does nothing
	# Child classes should override to call their specific refresh method
	# e.g., _refresh_cinematic_list(), _refresh_campaign_list(), etc.
	pass


# =============================================================================
# JSON File Operations
# =============================================================================

## Load a JSON file and return parsed data
## Returns empty Dictionary on failure, errors are shown via _show_errors()
func load_json_file(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		_show_errors(["Failed to open: " + path])
		return {}

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var err: Error = json.parse(json_text)
	if err != OK:
		_show_errors(["JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()]])
		return {}

	if not json.data is Dictionary:
		_show_errors(["Invalid JSON format: expected Dictionary"])
		return {}

	return json.data


## Save data to a JSON file
## Returns true on success, shows errors on failure
func save_json_file(path: String, data: Dictionary) -> bool:
	var json_text: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		_show_errors(["Failed to write: " + path])
		return false

	file.store_string(json_text)
	file.close()
	return true


## Ensure a directory exists, creating it if needed
## Returns true if directory exists or was created successfully
## Note: Delegates to SparklingEditorUtils but shows UI error on failure
func ensure_directory_exists(dir_path: String) -> bool:
	var success: bool = SparklingEditorUtils.ensure_directory_exists(dir_path)
	if not success:
		_show_errors(["Failed to create directory: " + dir_path])
	return success


# =============================================================================
# Resource Scanning
# =============================================================================

## Scan all mods for resources of this type
## Returns Array of { "mod_id": String, "path": String, "display": String }
func scan_all_mods_for_resources() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	if resource_dir_name.is_empty():
		push_error("JsonEditorBase: resource_dir_name not set")
		return results

	var mods_dir: DirAccess = DirAccess.open("res://mods/")
	if not mods_dir:
		push_error("Cannot open mods directory")
		return results

	mods_dir.list_dir_begin()
	var mod_name: String = mods_dir.get_next()

	while mod_name != "":
		if mods_dir.current_is_dir() and not mod_name.begins_with("."):
			var resource_path: String = "res://mods/%s/data/%s/" % [mod_name, resource_dir_name]
			var mod_resources: Array[Dictionary] = _scan_directory(resource_path, mod_name)
			results.append_array(mod_resources)
		mod_name = mods_dir.get_next()

	mods_dir.list_dir_end()
	return results


## Scan a single directory for resources
func _scan_directory(dir_path: String, mod_id: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	var dir: DirAccess = DirAccess.open(dir_path)
	if not dir:
		return results

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(file_extension):
			var full_path: String = dir_path + file_name
			var resource_id: String = file_name.get_basename()
			var display_name: String = "[%s] %s" % [mod_id, resource_id]

			results.append({
				"mod_id": mod_id,
				"path": full_path,
				"resource_id": resource_id,
				"display": display_name
			})
		file_name = dir.get_next()

	dir.list_dir_end()
	return results


## Get the active mod's resource directory for this type
## Creates the directory if it doesn't exist
func get_active_mod_resource_dir() -> String:
	if not ModLoader:
		_show_errors(["ModLoader not available"])
		return ""

	var active_mod: ModManifest = ModLoader.get_active_mod()
	if not active_mod:
		_show_errors(["No active mod selected"])
		return ""

	var dir_path: String = "res://mods/%s/data/%s/" % [active_mod.mod_id, resource_dir_name]

	if not ensure_directory_exists(dir_path):
		return ""

	return dir_path


# =============================================================================
# Error Panel
# =============================================================================

## Create the standard error panel (call this from child's _setup_ui)
func create_error_panel() -> PanelContainer:
	error_panel = PanelContainer.new()
	error_panel.visible = false

	var style: StyleBoxFlat = SparklingEditorUtils.create_error_panel_style()
	error_panel.add_theme_stylebox_override("panel", style)

	error_label = RichTextLabel.new()
	error_label.bbcode_enabled = true
	error_label.fit_content = true
	error_label.scroll_active = false
	error_panel.add_child(error_label)

	return error_panel


## Show error messages
func _show_errors(errors: Array) -> void:
	if not error_label or not error_panel:
		# Fallback if error panel not created yet
		for err in errors:
			push_error(str(err))
		return

	error_label.text = "[color=white]" + "\n".join(errors) + "[/color]"
	error_panel.visible = true

	# Brief pulse animation
	var tween: Tween = create_tween()
	if tween:
		tween.tween_property(error_panel, "modulate:a", 0.6, 0.15)
		tween.tween_property(error_panel, "modulate:a", 1.0, 0.15)


## Hide error messages
func _hide_errors() -> void:
	if error_panel:
		error_panel.visible = false
	if error_label:
		error_label.text = ""


# =============================================================================
# UI Helpers (delegating to SparklingEditorUtils for consistency)
# =============================================================================

## Create a section with title - delegates to SparklingEditorUtils
func create_section(title: String, parent: Node = null) -> VBoxContainer:
	return SparklingEditorUtils.create_section(title, parent as Control)


## Create a labeled field row - delegates to SparklingEditorUtils
func create_field_row(label_text: String, label_width: int = SparklingEditorUtils.DEFAULT_LABEL_WIDTH, parent: Node = null) -> HBoxContainer:
	return SparklingEditorUtils.create_field_row(label_text, label_width, parent as Control)


## Create a standard LineEdit field with label
func create_line_edit_field(label_text: String, parent: VBoxContainer, placeholder: String = "", label_width: int = SparklingEditorUtils.DEFAULT_LABEL_WIDTH) -> LineEdit:
	var row: HBoxContainer = SparklingEditorUtils.create_field_row(label_text, label_width)

	var edit: LineEdit = LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.placeholder_text = placeholder
	row.add_child(edit)

	parent.add_child(row)
	return edit


## Add a horizontal separator - delegates to SparklingEditorUtils
func add_separator(parent: VBoxContainer, min_height: float = 10.0) -> HSeparator:
	return SparklingEditorUtils.add_separator(parent, min_height)


# =============================================================================
# EditorEventBus Integration
# =============================================================================

## Convert directory name (e.g., "cinematics") to resource type (e.g., "cinematic")
## ResourcePicker listens for the singular type name, not the directory name
func _get_resource_type_from_dir() -> String:
	if ModLoader and "RESOURCE_TYPE_DIRS" in ModLoader:
		return ModLoader.RESOURCE_TYPE_DIRS.get(resource_dir_name, resource_dir_name)
	# Fallback: strip trailing 's' if present (works for most cases)
	if resource_dir_name.ends_with("s"):
		return resource_dir_name.substr(0, resource_dir_name.length() - 1)
	return resource_dir_name


## Notify that a resource was saved
## Use this instead of emitting mods_reloaded directly
func notify_resource_saved(resource_id: String) -> void:
	var event_bus: Node = get_node_or_null("/root/EditorEventBus")
	var resource_type: String = _get_resource_type_from_dir()
	if event_bus and event_bus.has_method("notify_resource_saved"):
		# For JSON resources, we don't have a Resource object
		event_bus.notify_resource_saved(resource_type, resource_id, null)
	elif event_bus:
		# Fallback: emit the signal directly if method doesn't exist
		event_bus.resource_saved.emit(resource_type, resource_id, null)


## Notify that a resource was created
func notify_resource_created(resource_id: String) -> void:
	var event_bus: Node = get_node_or_null("/root/EditorEventBus")
	var resource_type: String = _get_resource_type_from_dir()
	if event_bus and event_bus.has_method("notify_resource_created"):
		event_bus.notify_resource_created(resource_type, resource_id, null)
	elif event_bus:
		event_bus.resource_created.emit(resource_type, resource_id, null)


## Notify that a resource was deleted
func notify_resource_deleted(resource_id: String) -> void:
	var event_bus: Node = get_node_or_null("/root/EditorEventBus")
	var resource_type: String = _get_resource_type_from_dir()
	if event_bus and event_bus.has_method("notify_resource_deleted"):
		event_bus.notify_resource_deleted(resource_type, resource_id)
	elif event_bus:
		event_bus.resource_deleted.emit(resource_type, resource_id)


# =============================================================================
# JSON Validation Helpers
# =============================================================================

## Validate a JSON string and return parsed result or null
## Useful for validating user-entered JSON fields
static func validate_json_string(json_string: String) -> Variant:
	if json_string.strip_edges().is_empty():
		return null

	var json: JSON = JSON.new()
	var err: Error = json.parse(json_string)
	if err != OK:
		return null

	return json.data


## Check if a string is valid JSON
static func is_valid_json(json_string: String) -> bool:
	if json_string.strip_edges().is_empty():
		return true  # Empty is valid (means "not set")

	var json: JSON = JSON.new()
	return json.parse(json_string) == OK


# =============================================================================
# Lifecycle
# =============================================================================

## Clean up signal connections when removed from tree
## Child classes that connect to EditorEventBus should override this
## and call super._exit_tree() to ensure proper cleanup
func _exit_tree() -> void:
	# Base class has no EditorEventBus connections to clean up
	# Child classes should override this method to disconnect their signals:
	#
	# func _exit_tree() -> void:
	#     var event_bus: Node = get_node_or_null("/root/EditorEventBus")
	#     if event_bus:
	#         if event_bus.some_signal.is_connected(_my_handler):
	#             event_bus.some_signal.disconnect(_my_handler)
	#     super._exit_tree()
	pass
