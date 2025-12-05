@tool
extends Control

## Base class for all resource editors (Classes, Characters, Items, etc.)
## Provides common functionality for list management, save/delete/refresh operations

# Directory where resources are stored (legacy - kept for backward compatibility)
var resource_directory: String = ""

# Resource type name for display (override in child class)
var resource_type_name: String = "Resource"

# Resource type for ModRegistry lookup (override in child class)
# Values: "character", "class", "item", "ability", "dialogue", "battle"
var resource_type_id: String = ""

# UI Components (created by base class)
var resource_list: ItemList
var search_filter: LineEdit
var detail_panel: VBoxContainer
var button_container: HBoxContainer
var save_button: Button
var delete_button: Button

# All loaded resources (unfiltered) for search
var all_resources: Array[Resource] = []
var all_resource_paths: Array[String] = []

# Current resource being edited
var current_resource: Resource

# Track source mod of current resource (for write protection)
var current_resource_source_mod: String = ""

# Available resources for reference (e.g., classes list for character editor)
var available_resources: Array[Resource] = []

# Dialogs and feedback panels
var confirmation_dialog: ConfirmationDialog
var error_panel: PanelContainer
var error_label: RichTextLabel
var _pending_confirmation_action: Callable

# Mod workflow buttons (shown when viewing cross-mod resources)
var copy_to_mod_button: Button
var create_override_button: Button
var mod_workflow_container: HBoxContainer


func _ready() -> void:
	_setup_base_ui()
	_create_detail_form()
	_refresh_list()


func _input(event: InputEvent) -> void:
	# Only handle input when this editor is visible and has focus
	if not is_visible_in_tree():
		return

	if event is InputEventKey and event.pressed:
		# Ctrl+S: Save
		if event.ctrl_pressed and event.keycode == KEY_S:
			get_viewport().set_input_as_handled()
			_on_save()
		# Ctrl+N: Create new
		elif event.ctrl_pressed and event.keycode == KEY_N:
			get_viewport().set_input_as_handled()
			_on_create_new()


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
	hsplit.split_offset = 150  # Default split position - left panel gets ~150px
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
	help_label.add_theme_font_size_override("font_size", 16)
	left_panel.add_child(help_label)

	# Search filter
	search_filter = LineEdit.new()
	search_filter.placeholder_text = "Search..."
	search_filter.clear_button_enabled = true
	search_filter.text_changed.connect(_on_search_filter_changed)
	left_panel.add_child(search_filter)

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
	detail_label.add_theme_font_size_override("font_size", 16)
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

	# Mod workflow buttons (shown when viewing resources from other mods)
	mod_workflow_container = HBoxContainer.new()
	mod_workflow_container.visible = false
	mod_workflow_container.add_theme_constant_override("separation", 8)

	var sep: VSeparator = VSeparator.new()
	mod_workflow_container.add_child(sep)

	copy_to_mod_button = Button.new()
	copy_to_mod_button.text = "Copy to My Mod"
	copy_to_mod_button.tooltip_text = "Create a copy in your active mod with a new unique ID"
	copy_to_mod_button.pressed.connect(_on_copy_to_mod)
	mod_workflow_container.add_child(copy_to_mod_button)

	create_override_button = Button.new()
	create_override_button.text = "Create Override"
	create_override_button.tooltip_text = "Create an override in your active mod with the same ID (higher priority wins)"
	create_override_button.pressed.connect(_on_create_override)
	mod_workflow_container.add_child(create_override_button)

	button_container.add_child(mod_workflow_container)

	scroll.add_child(detail_panel)
	hsplit.add_child(scroll)

	# Create confirmation dialog
	confirmation_dialog = ConfirmationDialog.new()
	confirmation_dialog.title = "Confirm Action"
	confirmation_dialog.confirmed.connect(_on_confirmation_confirmed)
	add_child(confirmation_dialog)

	# Create error panel (hidden by default)
	error_panel = PanelContainer.new()
	error_panel.visible = false
	var error_style: StyleBoxFlat = StyleBoxFlat.new()
	error_style.bg_color = Color(0.6, 0.15, 0.15, 0.95)
	error_style.border_width_left = 3
	error_style.border_width_right = 3
	error_style.border_width_top = 3
	error_style.border_width_bottom = 3
	error_style.border_color = Color(0.9, 0.3, 0.3, 1.0)
	error_style.corner_radius_top_left = 4
	error_style.corner_radius_top_right = 4
	error_style.corner_radius_bottom_left = 4
	error_style.corner_radius_bottom_right = 4
	error_style.content_margin_left = 8
	error_style.content_margin_right = 8
	error_style.content_margin_top = 6
	error_style.content_margin_bottom = 6
	error_panel.add_theme_stylebox_override("panel", error_style)

	error_label = RichTextLabel.new()
	error_label.bbcode_enabled = true
	error_label.fit_content = true
	error_label.custom_minimum_size = Vector2(0, 40)
	error_label.scroll_active = false
	error_panel.add_child(error_label)

	# Error panel will be inserted before button_container in child's _create_detail_form


func _refresh_list() -> void:
	resource_list.clear()
	available_resources.clear()
	all_resources.clear()
	all_resource_paths.clear()

	# Use ModRegistry if available and resource_type_id is set
	if resource_type_id != "" and ModLoader:
		var active_mod: ModManifest = ModLoader.get_active_mod()
		if not active_mod:
			push_warning("No active mod set in ModLoader")
			return

		# Get directory for this resource type in active mod
		var resource_dirs: Dictionary = ModLoader.get_resource_directories(active_mod.mod_id)
		if resource_type_id in resource_dirs:
			var dir_path: String = resource_dirs[resource_type_id]
			_scan_directory_for_resources(dir_path)
		else:
			push_error("Resource type '%s' not found in mod directories" % resource_type_id)
	# Fallback to legacy directory scanning
	elif resource_directory != "":
		_scan_directory_for_resources(resource_directory)
	else:
		push_error("No resource_type_id or resource_directory set")


## Scan a directory for .tres resource files and populate the list
func _scan_directory_for_resources(dir_path: String) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var full_path: String = dir_path.path_join(file_name)
				var resource: Resource = load(full_path)
				if resource:
					# Store in master lists for filtering
					all_resources.append(resource)
					all_resource_paths.append(full_path)
					available_resources.append(resource)
			file_name = dir.get_next()
		dir.list_dir_end()

		# Apply current filter (or show all if no filter)
		_apply_filter()
	else:
		push_error("Failed to open directory: " + dir_path)


## Apply the current search filter to the resource list
func _apply_filter() -> void:
	resource_list.clear()

	var filter_text: String = search_filter.text.strip_edges().to_lower() if search_filter else ""

	for i in range(all_resources.size()):
		var resource: Resource = all_resources[i]
		var display_name: String = _get_resource_display_name(resource)

		# Show all if no filter, otherwise check for match
		if filter_text.is_empty() or display_name.to_lower().contains(filter_text):
			resource_list.add_item(display_name)
			resource_list.set_item_metadata(resource_list.item_count - 1, all_resource_paths[i])


## Called when search filter text changes
func _on_search_filter_changed(_new_text: String) -> void:
	_apply_filter()


func _on_resource_selected(index: int) -> void:
	var path: String = resource_list.get_item_metadata(index)
	# Load and duplicate to make it editable (load() returns read-only cached resource)
	var loaded_resource: Resource = load(path)
	current_resource = loaded_resource.duplicate(true)
	# Keep the original path so we can save to the same location
	current_resource.take_over_path(path)

	# Track source mod for write protection
	current_resource_source_mod = _get_mod_from_path(path)

	# Hide any previous errors when selecting a new resource
	_hide_errors()

	# Show/hide mod workflow buttons based on whether resource is from another mod
	_update_mod_workflow_buttons()

	# Check for namespace conflicts and show warning (informational)
	_check_and_show_namespace_info(path)

	_load_resource_data()


## Determine which mod a resource path belongs to
func _get_mod_from_path(path: String) -> String:
	# Paths are like: res://mods/_base_game/data/characters/hero.tres
	# Split by "/" gives: ["res:", "", "mods", "_base_game", "data", ...]
	if path.begins_with("res://mods/"):
		var parts: PackedStringArray = path.split("/")
		if parts.size() >= 4:
			return parts[3]  # The mod folder name (index 3 due to "res://" splitting)
	return ""


func _on_save() -> void:
	if not current_resource:
		_show_errors(["No " + resource_type_name.to_lower() + " selected"])
		return

	# Check if we have a selected item
	var selected_items: PackedInt32Array = resource_list.get_selected_items()
	if selected_items.size() == 0:
		_show_errors(["No " + resource_type_name.to_lower() + " selected in list"])
		return

	# Hide any previous errors
	_hide_errors()

	# Check for cross-mod write protection
	var active_mod_folder: String = ""
	if ModLoader:
		var active_mod: ModManifest = ModLoader.get_active_mod()
		if active_mod:
			# Get the folder name from mod directory
			active_mod_folder = active_mod.mod_directory.get_file()

	# If resource came from a different mod than the active one, warn
	if current_resource_source_mod != "" and active_mod_folder != "":
		if current_resource_source_mod != active_mod_folder:
			_show_cross_mod_warning(current_resource_source_mod, active_mod_folder)
			return

	# Validate first
	var validation: Dictionary = _validate_resource()
	if not validation.valid:
		_show_errors(validation.errors)
		return

	# Perform the actual save
	_perform_save()


## Actually perform the save operation (called after validation/confirmation)
func _perform_save() -> void:
	# Save UI data to resource
	_save_resource_data()

	# Save to file
	var selected_items: PackedInt32Array = resource_list.get_selected_items()
	var path: String = resource_list.get_item_metadata(selected_items[0])
	var err: Error = ResourceSaver.save(current_resource, path)
	if err == OK:
		# Notify other editors that a resource was saved
		var event_bus: Node = get_node_or_null("/root/EditorEventBus")
		if event_bus:
			event_bus.notify_resource_saved(resource_type_id, path, current_resource)

		_hide_errors()
		_refresh_list()
	else:
		_show_errors(["Failed to save " + resource_type_name.to_lower() + ": " + str(err)])


func _on_create_new() -> void:
	var new_resource: Resource = _create_new_resource()
	if not new_resource:
		push_error("Failed to create new " + resource_type_name.to_lower())
		return

	# Determine save directory
	var save_dir: String = ""
	var active_mod_id: String = ""
	if resource_type_id != "" and ModLoader:
		var active_mod: ModManifest = ModLoader.get_active_mod()
		if active_mod:
			active_mod_id = active_mod.mod_id
			var resource_dirs: Dictionary = ModLoader.get_resource_directories(active_mod.mod_id)
			save_dir = resource_dirs.get(resource_type_id, "")

	# Fallback to legacy directory
	if save_dir == "":
		save_dir = resource_directory

	if save_dir == "":
		push_error("No save directory available for " + resource_type_name.to_lower())
		return

	# Generate unique filename with mod prefix to avoid conflicts
	var timestamp: int = Time.get_unix_time_from_system()
	var prefix: String = active_mod_id + "_" if active_mod_id != "" and not active_mod_id.begins_with("_") else ""
	var filename: String = prefix + resource_type_name.to_lower() + "_%d.tres" % timestamp
	var full_path: String = save_dir.path_join(filename)

	# Save the resource
	var err: Error = ResourceSaver.save(new_resource, full_path)
	if err == OK:
		# Notify other editors that a resource was created
		var event_bus: Node = get_node_or_null("/root/EditorEventBus")
		if event_bus:
			event_bus.notify_resource_created(resource_type_id, full_path, new_resource)

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
		var ref_list: String = ""
		for i in range(mini(references.size(), 5)):
			ref_list += "\n  - " + references[i].get_file()
		if references.size() > 5:
			ref_list += "\n  ... and %d more" % (references.size() - 5)
		_show_errors(["Cannot delete '%s'" % _get_resource_display_name(current_resource),
					  "Referenced by %d resource(s):%s" % [references.size(), ref_list]])
		return

	# Get the file path
	var selected_items: PackedInt32Array = resource_list.get_selected_items()
	if selected_items.size() == 0:
		return

	# Show confirmation dialog
	var resource_name: String = _get_resource_display_name(current_resource)
	_show_confirmation(
		"Delete " + resource_type_name + "?",
		"Are you sure you want to delete '%s'?\n\nThis action cannot be undone." % resource_name,
		_perform_delete
	)


## Actually perform the delete operation (called after confirmation)
func _perform_delete() -> void:
	var selected_items: PackedInt32Array = resource_list.get_selected_items()
	if selected_items.size() == 0:
		return

	var path: String = resource_list.get_item_metadata(selected_items[0])

	# Delete the file
	var dir: DirAccess = DirAccess.open(path.get_base_dir())
	if dir:
		var err: Error = dir.remove(path)
		if err == OK:
			# Notify other editors that a resource was deleted
			var event_bus: Node = get_node_or_null("/root/EditorEventBus")
			if event_bus:
				event_bus.notify_resource_deleted(resource_type_id, path)

			current_resource = null
			current_resource_source_mod = ""
			_hide_errors()
			_refresh_list()
		else:
			_show_errors(["Failed to delete " + resource_type_name.to_lower() + " file: " + str(err)])
	else:
		_show_errors(["Failed to access directory for deletion"])


## Show error messages in the visual error panel
func _show_errors(errors: Array) -> void:
	var error_text: String = "[b]Error:[/b]\n"
	for error in errors:
		error_text += "• " + str(error) + "\n"
	error_label.text = error_text

	# Insert error panel before button_container if not already there
	if error_panel.get_parent() != detail_panel:
		var button_index: int = button_container.get_index()
		detail_panel.add_child(error_panel)
		detail_panel.move_child(error_panel, button_index)

	error_panel.show()

	# Brief pulse animation to draw attention
	var tween: Tween = create_tween()
	tween.tween_property(error_panel, "modulate:a", 0.6, 0.15)
	tween.tween_property(error_panel, "modulate:a", 1.0, 0.15)


## Hide the error panel
func _hide_errors() -> void:
	error_panel.hide()
	error_label.text = ""


## Show a confirmation dialog
func _show_confirmation(title: String, message: String, on_confirm: Callable) -> void:
	confirmation_dialog.title = title
	confirmation_dialog.dialog_text = message
	_pending_confirmation_action = on_confirm
	confirmation_dialog.popup_centered()


## Called when confirmation dialog is confirmed
func _on_confirmation_confirmed() -> void:
	if _pending_confirmation_action.is_valid():
		_pending_confirmation_action.call()
	_pending_confirmation_action = Callable()


## Show warning about cross-mod write attempt
func _show_cross_mod_warning(source_mod: String, active_mod: String) -> void:
	_show_confirmation(
		"Cross-Mod Write Warning",
		"This resource belongs to mod '%s' but you're editing mod '%s'.\n\n" % [source_mod, active_mod] +
		"Saving will modify the original mod's files.\n\n" +
		"Are you sure you want to continue?",
		_perform_save
	)


# =============================================================================
# Mod Workflow Functions (Copy to My Mod, Create Override)
# =============================================================================

## Update visibility of mod workflow buttons based on current resource
func _update_mod_workflow_buttons() -> void:
	if not mod_workflow_container:
		return

	var active_mod_folder: String = ""
	if ModLoader:
		var active_mod: ModManifest = ModLoader.get_active_mod()
		if active_mod:
			active_mod_folder = active_mod.mod_directory.get_file()

	# Show buttons when viewing a resource from a different mod
	var is_cross_mod: bool = (
		current_resource_source_mod != "" and
		active_mod_folder != "" and
		current_resource_source_mod != active_mod_folder
	)

	mod_workflow_container.visible = is_cross_mod


## Copy the current resource to the active mod with a new unique ID
func _on_copy_to_mod() -> void:
	if not current_resource:
		_show_errors(["No resource selected"])
		return

	if not ModLoader:
		_show_errors(["ModLoader not available"])
		return

	var active_mod: ModManifest = ModLoader.get_active_mod()
	if not active_mod:
		_show_errors(["No active mod selected"])
		return

	# Get the save directory
	var save_dir: String = ""
	if resource_type_id != "":
		var resource_dirs: Dictionary = ModLoader.get_resource_directories(active_mod.mod_id)
		save_dir = resource_dirs.get(resource_type_id, "")

	if save_dir.is_empty():
		save_dir = resource_directory

	if save_dir.is_empty():
		_show_errors(["No save directory available"])
		return

	# Generate unique filename with timestamp
	var timestamp: int = Time.get_unix_time_from_system()
	var original_name: String = _get_resource_display_name(current_resource)
	var safe_name: String = original_name.to_lower().replace(" ", "_").replace("'", "")
	var filename: String = "%s_copy_%d.tres" % [safe_name, timestamp]
	var full_path: String = save_dir.path_join(filename)

	# Create a duplicate resource
	var new_resource: Resource = current_resource.duplicate(true)

	# Try to update the resource's ID/name if it has common properties
	_update_resource_id_for_copy(new_resource, original_name)

	# Save the resource
	var err: Error = ResourceSaver.save(new_resource, full_path)
	if err == OK:
		# Notify other editors
		var event_bus: Node = get_node_or_null("/root/EditorEventBus")
		if event_bus:
			event_bus.notify_resource_created(resource_type_id, full_path, new_resource)
			event_bus.resource_copied.emit(resource_type_id, current_resource.resource_path, active_mod.mod_id, full_path)

		# Refresh and select the new resource
		EditorInterface.get_resource_filesystem().scan()
		await get_tree().process_frame
		_refresh_list()

		# Select the newly created resource
		for i in range(resource_list.item_count):
			if resource_list.get_item_metadata(i) == full_path:
				resource_list.select(i)
				_on_resource_selected(i)
				break

		_hide_errors()
	else:
		_show_errors(["Failed to copy resource: " + str(err)])


## Create an override of the current resource in the active mod (same ID)
func _on_create_override() -> void:
	if not current_resource:
		_show_errors(["No resource selected"])
		return

	if not ModLoader:
		_show_errors(["ModLoader not available"])
		return

	var active_mod: ModManifest = ModLoader.get_active_mod()
	if not active_mod:
		_show_errors(["No active mod selected"])
		return

	# Get the original filename
	var original_filename: String = current_resource.resource_path.get_file()

	# Get the save directory
	var save_dir: String = ""
	if resource_type_id != "":
		var resource_dirs: Dictionary = ModLoader.get_resource_directories(active_mod.mod_id)
		save_dir = resource_dirs.get(resource_type_id, "")

	if save_dir.is_empty():
		save_dir = resource_directory

	if save_dir.is_empty():
		_show_errors(["No save directory available"])
		return

	var full_path: String = save_dir.path_join(original_filename)

	# Check if override already exists
	if FileAccess.file_exists(full_path):
		_show_errors(["Override already exists at: " + full_path, "Delete the existing override first or use 'Copy to My Mod' for a new file."])
		return

	# Show confirmation dialog explaining override behavior
	_show_confirmation(
		"Create Override?",
		"This will create an override of '%s' in your mod '%s'.\n\n" % [_get_resource_display_name(current_resource), active_mod.mod_name] +
		"Because your mod has higher priority, this override will be used instead of the original.\n\n" +
		"Original: %s\n" % current_resource.resource_path +
		"Override: %s\n\n" % full_path +
		"Continue?",
		_perform_create_override.bind(full_path)
	)


## Actually create the override after confirmation
func _perform_create_override(override_path: String) -> void:
	# Create a duplicate resource (keep all data including any internal IDs)
	var override_resource: Resource = current_resource.duplicate(true)

	# Save the override
	var err: Error = ResourceSaver.save(override_resource, override_path)
	if err == OK:
		# Notify other editors
		var event_bus: Node = get_node_or_null("/root/EditorEventBus")
		if event_bus:
			var active_mod: ModManifest = ModLoader.get_active_mod()
			event_bus.notify_resource_created(resource_type_id, override_path, override_resource)
			if event_bus.has_signal("resource_override_created"):
				event_bus.resource_override_created.emit(resource_type_id, override_path.get_file().get_basename(), active_mod.mod_id if active_mod else "")

		# Refresh and select the override
		EditorInterface.get_resource_filesystem().scan()
		await get_tree().process_frame
		_refresh_list()

		# Select the override
		for i in range(resource_list.item_count):
			if resource_list.get_item_metadata(i) == override_path:
				resource_list.select(i)
				_on_resource_selected(i)
				break

		_hide_errors()
	else:
		_show_errors(["Failed to create override: " + str(err)])


## Update a resource's internal ID/name for copy operation
## Tries to modify common name properties to indicate it's a copy
func _update_resource_id_for_copy(resource: Resource, original_name: String) -> void:
	var copy_suffix: String = " (Copy)"

	# Try common name properties
	var name_properties: Array[String] = [
		"display_name",
		"character_name",
		"item_name",
		"ability_name",
		"party_name",
		"battle_name",
		"class_name"
	]

	for prop: String in name_properties:
		if prop in resource:
			var current_value: Variant = resource.get(prop)
			if current_value is String and not current_value.is_empty():
				# Don't add multiple copy suffixes
				if not current_value.ends_with(copy_suffix):
					resource.set(prop, current_value + copy_suffix)
				return

	# If no name property found, try to set display_name if it exists
	if "display_name" in resource:
		resource.set("display_name", original_name + copy_suffix)


# =============================================================================
# Namespace Conflict Detection
# =============================================================================

## Check if a resource ID exists in other mods (potential namespace conflict)
## Returns Array of mod_ids that have the same resource ID
func _check_namespace_conflicts(resource_id: String, excluding_mod: String) -> Array[String]:
	var conflicts: Array[String] = []

	if not ModLoader or resource_type_id.is_empty():
		return conflicts

	# Get the directory name for this resource type
	var type_dir_map: Dictionary = ModLoader.RESOURCE_TYPE_DIRS if "RESOURCE_TYPE_DIRS" in ModLoader else {}
	var dir_name: String = type_dir_map.get(resource_type_id, resource_type_id + "s")

	# Scan each mod's data directory
	var mods_dir: DirAccess = DirAccess.open("res://mods/")
	if not mods_dir:
		return conflicts

	mods_dir.list_dir_begin()
	var mod_name: String = mods_dir.get_next()

	while mod_name != "":
		if mods_dir.current_is_dir() and not mod_name.begins_with("."):
			if mod_name != excluding_mod:
				var resource_path: String = "res://mods/%s/data/%s/%s.tres" % [mod_name, dir_name, resource_id]
				if FileAccess.file_exists(resource_path):
					conflicts.append(mod_name)
		mod_name = mods_dir.get_next()

	mods_dir.list_dir_end()
	return conflicts


## Show warning about namespace conflict
func _show_namespace_conflict_warning(resource_id: String, conflicting_mods: Array[String]) -> void:
	var mod_list: String = ", ".join(conflicting_mods)
	_show_errors([
		"Namespace Warning",
		"A resource with ID '%s' already exists in: %s" % [resource_id, mod_list],
		"If you save with this ID, it will create an override (higher priority wins at runtime).",
		"Consider renaming to avoid unintentional conflicts."
	])


## Check for namespace conflicts and show informational message
func _check_and_show_namespace_info(resource_path: String) -> void:
	var resource_id: String = resource_path.get_file().get_basename()
	var source_mod: String = _get_mod_from_path(resource_path)

	var conflicts: Array[String] = _check_namespace_conflicts(resource_id, source_mod)

	if conflicts.size() > 0:
		# Show informational message about the override situation
		var active_mod_folder: String = ""
		if ModLoader:
			var active_mod: ModManifest = ModLoader.get_active_mod()
			if active_mod:
				active_mod_folder = active_mod.mod_directory.get_file()

		# Determine if this resource is the "winning" override or being overridden
		var winning_source: String = ""
		if ModLoader and ModLoader.registry:
			winning_source = ModLoader.registry.get_resource_source(resource_id)

		if winning_source == source_mod:
			# This resource is the active override
			_show_info_message(
				"Override Active",
				"This resource overrides the same ID from: " + ", ".join(conflicts)
			)
		else:
			# This resource is being overridden
			_show_info_message(
				"Overridden Resource",
				"This resource is overridden by: " + winning_source
			)


## Show an informational message (less alarming than errors)
func _show_info_message(title: String, message: String) -> void:
	if not error_label or not error_panel:
		return

	# Use a different color for info messages
	error_label.text = "[color=#6699cc][b]%s:[/b] %s[/color]" % [title, message]

	# Insert error panel if not already there
	if error_panel.get_parent() != detail_panel:
		var button_index: int = button_container.get_index()
		detail_panel.add_child(error_panel)
		detail_panel.move_child(error_panel, button_index)

	# Use info styling (blue instead of red)
	var style: StyleBoxFlat = error_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		var info_style: StyleBoxFlat = style.duplicate()
		info_style.bg_color = Color(0.15, 0.25, 0.4, 0.95)
		info_style.border_color = Color(0.3, 0.5, 0.8, 1.0)
		error_panel.add_theme_stylebox_override("panel", info_style)

	error_panel.show()
