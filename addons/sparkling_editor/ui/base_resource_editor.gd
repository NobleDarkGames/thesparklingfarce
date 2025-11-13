@tool
extends Control

## Base class for all resource editors (Classes, Characters, Items, etc.)
## Provides common functionality for list management, save/delete/refresh operations

# Directory where resources are stored (override in child class)
var resource_directory: String = ""

# Resource type name for display (override in child class)
var resource_type_name: String = "Resource"

# UI Components (created by base class)
var resource_list: ItemList
var detail_panel: VBoxContainer
var button_container: HBoxContainer
var save_button: Button
var delete_button: Button

# Current resource being edited
var current_resource: Resource

# Available resources for reference (e.g., classes list for character editor)
var available_resources: Array[Resource] = []


func _ready() -> void:
	print("base_resource_editor _ready called for: ", resource_type_name)
	_setup_base_ui()
	_create_detail_form()
	_refresh_list()


## Override this in child classes to create the specific detail form
func _create_detail_form() -> void:
	push_error("_create_detail_form() must be overridden in child class")


## Override this in child classes to load resource data into UI
func _load_resource_data() -> void:
	push_error("_load_resource_data() must be overridden in child class")


## Override this in child classes to save UI data to resource
func _save_resource_data() -> void:
	push_error("_save_resource_data() must be overridden in child class")


## Override this in child classes to validate resource before saving
## Returns Dictionary with {valid: bool, errors: Array[String]}
func _validate_resource() -> Dictionary:
	return {valid = true, errors = []}


## Override this in child classes to check for references before deletion
## Returns Array[String] of file paths that reference this resource
func _check_resource_references(resource_to_check: Resource) -> Array[String]:
	return []


## Override this in child classes to create a new resource with defaults
func _create_new_resource() -> Resource:
	push_error("_create_new_resource() must be overridden in child class")
	return null


## Override this to get the display name from a resource
func _get_resource_display_name(resource: Resource) -> String:
	return "Unnamed"


func _setup_base_ui() -> void:
	# Note: TabContainer children must use anchors to fill available space
	# Using full anchors to stretch both horizontally and vertically
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = 0.0
	offset_bottom = 0.0

	var hsplit: HSplitContainer = HSplitContainer.new()
	# HSplitContainer uses anchors to fill the parent Control
	hsplit.anchor_right = 1.0
	hsplit.anchor_bottom = 1.0
	hsplit.split_offset = 300  # Default split position - left panel gets ~300px
	add_child(hsplit)

	# Left side: Resource list
	var left_panel: VBoxContainer = VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var list_label: Label = Label.new()
	list_label.text = resource_type_name + "s"
	list_label.add_theme_font_size_override("font_size", 16)
	left_panel.add_child(list_label)

	var help_label: Label = Label.new()
	help_label.text = "Select a " + resource_type_name.to_lower() + " to edit"
	help_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	help_label.add_theme_font_size_override("font_size", 11)
	left_panel.add_child(help_label)

	resource_list = ItemList.new()
	resource_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Don't use SIZE_EXPAND_FILL vertically - just set a fixed height
	resource_list.custom_minimum_size = Vector2(0, 150)  # Fixed height to keep buttons visible
	resource_list.item_selected.connect(_on_resource_selected)
	left_panel.add_child(resource_list)

	var create_button: Button = Button.new()
	create_button.text = "Create New " + resource_type_name
	create_button.pressed.connect(_on_create_new)
	left_panel.add_child(create_button)

	var refresh_button: Button = Button.new()
	refresh_button.text = "Refresh List"
	refresh_button.pressed.connect(_refresh_list)
	left_panel.add_child(refresh_button)

	hsplit.add_child(left_panel)

	# Right side: Resource details (populated by child class)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(400, 0)  # Ensure right panel has minimum width

	detail_panel = VBoxContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var detail_label: Label = Label.new()
	detail_label.text = resource_type_name + " Details"
	detail_label.add_theme_font_size_override("font_size", 18)
	detail_panel.add_child(detail_label)

	# Buttons will be added after child creates form
	button_container = HBoxContainer.new()

	save_button = Button.new()
	save_button.text = "Save Changes"
	save_button.pressed.connect(_on_save)
	button_container.add_child(save_button)

	delete_button = Button.new()
	delete_button.text = "Delete " + resource_type_name
	delete_button.pressed.connect(_on_delete)
	button_container.add_child(delete_button)

	scroll.add_child(detail_panel)
	hsplit.add_child(scroll)

	# Debug - use call_deferred to check sizes after layout
	call_deferred("_debug_sizes", hsplit, left_panel, scroll)


func _debug_sizes(hsplit: HSplitContainer, left: Control, right: Control) -> void:
	print("  [", resource_type_name, "] ROOT CONTROL size: ", size)
	print("  [", resource_type_name, "] ROOT CONTROL custom_minimum_size: ", custom_minimum_size)
	print("  [", resource_type_name, "] ROOT CONTROL anchors: (", anchor_left, ", ", anchor_top, ", ", anchor_right, ", ", anchor_bottom, ")")
	print("  [", resource_type_name, "] ROOT CONTROL offsets: (", offset_left, ", ", offset_top, ", ", offset_right, ", ", offset_bottom, ")")
	print("  [", resource_type_name, "] ROOT CONTROL parent: ", get_parent().get_class() if get_parent() else "null")
	print("  [", resource_type_name, "] ROOT CONTROL parent size: ", get_parent().size if get_parent() else "null")
	print("  [", resource_type_name, "] HSplit size: ", hsplit.size, " split_offset: ", hsplit.split_offset)
	print("  [", resource_type_name, "] HSplit custom_minimum_size: ", hsplit.custom_minimum_size)
	print("  [", resource_type_name, "] Left panel size: ", left.size)
	print("  [", resource_type_name, "] Right panel (ScrollContainer) size: ", right.size)
	print("  [", resource_type_name, "] Right panel custom_minimum_size: ", right.custom_minimum_size)
	print("  [", resource_type_name, "] HSplit children count: ", hsplit.get_child_count())


func _refresh_list() -> void:
	resource_list.clear()
	available_resources.clear()

	var dir: DirAccess = DirAccess.open(resource_directory)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var full_path: String = resource_directory + file_name
				var resource: Resource = load(full_path)
				if resource:
					resource_list.add_item(_get_resource_display_name(resource))
					resource_list.set_item_metadata(resource_list.item_count - 1, full_path)
					available_resources.append(resource)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		push_error("Failed to open directory: " + resource_directory)


func _on_resource_selected(index: int) -> void:
	var path: String = resource_list.get_item_metadata(index)
	# Load and duplicate to make it editable (load() returns read-only cached resource)
	var loaded_resource: Resource = load(path)
	current_resource = loaded_resource.duplicate(true)
	# Keep the original path so we can save to the same location
	current_resource.take_over_path(path)
	_load_resource_data()


func _on_save() -> void:
	if not current_resource:
		push_warning("No " + resource_type_name.to_lower() + " selected")
		return

	# Check if we have a selected item
	var selected_items: PackedInt32Array = resource_list.get_selected_items()
	if selected_items.size() == 0:
		push_warning("No " + resource_type_name.to_lower() + " selected in list")
		return

	# Validate first
	var validation: Dictionary = _validate_resource()
	if not validation.valid:
		var error_msg: String = "Cannot save " + resource_type_name.to_lower() + ":\n"
		for error in validation.errors:
			error_msg += "- " + error + "\n"
		push_error(error_msg)
		return

	# Save UI data to resource
	_save_resource_data()

	# Save to file
	var path: String = resource_list.get_item_metadata(selected_items[0])
	var err: Error = ResourceSaver.save(current_resource, path)
	if err == OK:
		_refresh_list()
	else:
		push_error("Failed to save " + resource_type_name.to_lower() + ": " + str(err))


func _on_create_new() -> void:
	var new_resource: Resource = _create_new_resource()
	if not new_resource:
		push_error("Failed to create new " + resource_type_name.to_lower())
		return

	# Generate unique filename
	var timestamp: int = Time.get_unix_time_from_system()
	var filename: String = resource_type_name.to_lower() + "_%d.tres" % timestamp
	var full_path: String = resource_directory + filename

	# Save the resource
	var err: Error = ResourceSaver.save(new_resource, full_path)
	if err == OK:
		# Force Godot to rescan filesystem and reload the resource
		EditorInterface.get_resource_filesystem().scan()
		# Wait a frame for the scan to complete, then refresh
		await get_tree().process_frame
		_refresh_list()

		# Auto-select the newly created resource
		for i in range(resource_list.item_count):
			if resource_list.get_item_metadata(i) == full_path:
				resource_list.select(i)
				_on_resource_selected(i)
				break
	else:
		push_error("Failed to create " + resource_type_name.to_lower() + ": " + str(err))


func _on_delete() -> void:
	if not current_resource:
		return

	# Check if this resource is referenced elsewhere
	var references: Array[String] = _check_resource_references(current_resource)
	if references.size() > 0:
		push_error("Cannot delete %s: Referenced by %d resource(s)" % [_get_resource_display_name(current_resource), references.size()])
		return

	# Get the file path
	var selected_items: PackedInt32Array = resource_list.get_selected_items()
	if selected_items.size() == 0:
		return

	var path: String = resource_list.get_item_metadata(selected_items[0])

	# Delete the file
	var dir: DirAccess = DirAccess.open(path.get_base_dir())
	if dir:
		var err: Error = dir.remove(path)
		if err == OK:
			current_resource = null
			_refresh_list()
		else:
			push_error("Failed to delete " + resource_type_name.to_lower() + " file: " + str(err))
	else:
		push_error("Failed to access directory for deletion")
