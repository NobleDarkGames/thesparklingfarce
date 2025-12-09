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

# Undo/Redo manager for editor operations
var undo_redo: EditorUndoRedoManager

# Enable undo/redo for save operations
var enable_undo_redo: bool = true

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

# Track unsaved changes
var is_dirty: bool = false

# Dialogs and feedback panels
var confirmation_dialog: ConfirmationDialog
var unsaved_changes_dialog: AcceptDialog
var error_panel: PanelContainer
var error_label: RichTextLabel
var _pending_confirmation_action: Callable
var _pending_unsaved_callback: Callable

# Mod workflow buttons (shown when viewing cross-mod resources)
var copy_to_mod_button: Button
var create_override_button: Button
var mod_workflow_container: HBoxContainer

# =============================================================================
# DEPENDENCY TRACKING
# =============================================================================

## Resource types this editor depends on for caches/dropdowns.
## When resources of these types are created, saved, or deleted in other tabs,
## the _on_dependencies_changed() method is called automatically.
##
## Example usage in child class:
##   func _ready() -> void:
##       resource_dependencies = ["item", "npc"]  # Set BEFORE super._ready()
##       super._ready()
##
##   func _on_dependencies_changed(changed_type: String) -> void:
##       _refresh_my_caches()
var resource_dependencies: Array[String] = []

# Track if we've connected to EditorEventBus (prevent double-connection)
var _dependencies_connected: bool = false


func _ready() -> void:
	# Get the EditorUndoRedoManager from EditorInterface
	if Engine.is_editor_hint():
		undo_redo = EditorInterface.get_editor_undo_redo()
	_setup_base_ui()
	_create_detail_form()
	_refresh_list()

	# Auto-subscribe to EditorEventBus for declared dependencies
	_setup_dependency_tracking()


func _exit_tree() -> void:
	# Clean up EditorEventBus signal connections to prevent memory leaks
	var event_bus: Node = get_node_or_null("/root/EditorEventBus")
	if event_bus:
		if event_bus.resource_saved.is_connected(_on_dependency_resource_changed):
			event_bus.resource_saved.disconnect(_on_dependency_resource_changed)
		if event_bus.resource_created.is_connected(_on_dependency_resource_changed):
			event_bus.resource_created.disconnect(_on_dependency_resource_changed)
		if event_bus.resource_deleted.is_connected(_on_dependency_resource_deleted):
			event_bus.resource_deleted.disconnect(_on_dependency_resource_deleted)
	_dependencies_connected = false


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
		# Ctrl+F: Focus search filter
		elif event.ctrl_pressed and event.keycode == KEY_F:
			get_viewport().set_input_as_handled()
			if search_filter:
				search_filter.grab_focus()
				search_filter.select_all()
		# Ctrl+D: Duplicate selected resource
		elif event.ctrl_pressed and event.keycode == KEY_D:
			get_viewport().set_input_as_handled()
			_on_duplicate_resource()
		# Delete: Delete selected resource (with confirmation)
		elif event.keycode == KEY_DELETE and not event.ctrl_pressed:
			# Only if list has focus and not editing text
			if resource_list and resource_list.has_focus():
				get_viewport().set_input_as_handled()
				_on_delete()
		# Escape: Clear search filter
		elif event.keycode == KEY_ESCAPE:
			if search_filter and not search_filter.text.is_empty():
				get_viewport().set_input_as_handled()
				search_filter.text = ""
				_on_search_filter_changed("")


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
	hsplit.clip_contents = true  # Ensure children are properly clipped
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
	help_label.add_theme_color_override("font_color", EditorThemeUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", 16)
	left_panel.add_child(help_label)

	# Search filter
	search_filter = LineEdit.new()
	search_filter.placeholder_text = "Search..."
	search_filter.clear_button_enabled = true
	search_filter.text_changed.connect(_on_search_filter_changed)
	left_panel.add_child(search_filter)

	# Button row at top (so list can expand to fill remaining space)
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)

	var create_button: Button = Button.new()
	create_button.text = "New"
	create_button.tooltip_text = "Create New " + resource_type_name
	create_button.pressed.connect(_on_create_new)
	btn_row.add_child(create_button)

	var refresh_button: Button = Button.new()
	refresh_button.text = "Refresh"
	refresh_button.tooltip_text = "Refresh List"
	refresh_button.pressed.connect(_refresh_list)
	btn_row.add_child(refresh_button)

	left_panel.add_child(btn_row)

	# Resource list now expands to fill available vertical space
	resource_list = ItemList.new()
	resource_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	resource_list.item_selected.connect(_on_resource_selected)
	left_panel.add_child(resource_list)

	hsplit.add_child(left_panel)

	# Right side: Resource details (populated by child class)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(350, 0)  # Reduced from 400 for better laptop support
	# Ensure vertical scrolling works properly - disable horizontal to prevent width issues
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# Auto-scroll to focused elements (when tabbing through form fields)
	scroll.follow_focus = true
	scroll.clip_contents = true

	detail_panel = VBoxContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# IMPORTANT: Do not set SIZE_EXPAND_FILL for vertical - let VBox size to content
	# Add some spacing between sections for visual clarity
	detail_panel.add_theme_constant_override("separation", 8)

	var detail_label: Label = Label.new()
	detail_label.text = resource_type_name + " Details"
	detail_label.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(detail_label)

	# Buttons will be added after child creates form
	# Note: A separator will be added before button_container when it's added to detail_panel
	button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 8)

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

	# Create unsaved changes dialog
	_create_unsaved_changes_dialog()

	# Create error panel (hidden by default)
	error_panel = PanelContainer.new()
	error_panel.visible = false
	var error_style: StyleBoxFlat = EditorThemeUtils.create_error_panel_style()
	error_panel.add_theme_stylebox_override("panel", error_style)

	error_label = RichTextLabel.new()
	error_label.bbcode_enabled = true
	error_label.fit_content = true
	error_label.custom_minimum_size = Vector2(0, 40)
	error_label.scroll_active = false
	error_panel.add_child(error_label)

	# Error panel will be inserted before button_container in child's _create_detail_form


# =============================================================================
# PUBLIC REFRESH INTERFACE
# =============================================================================

## Standard refresh method for EditorTabRegistry
## Override this if you need custom refresh behavior
func refresh() -> void:
	_refresh_list()


## Helper method for child classes to add the button container with proper spacing
## Call this instead of `detail_panel.add_child(button_container)` in _create_detail_form()
func _add_button_container_to_detail_panel() -> void:
	# Add separator for visual clarity between content and action buttons
	var separator: HSeparator = HSeparator.new()
	detail_panel.add_child(separator)
	# Add the button container
	detail_panel.add_child(button_container)


# =============================================================================
# DEPENDENCY TRACKING SYSTEM
# =============================================================================

## Set up automatic EditorEventBus subscriptions for declared dependencies.
## Called automatically at end of _ready(). Only subscribes if resource_dependencies
## has entries and we haven't already connected.
func _setup_dependency_tracking() -> void:
	if resource_dependencies.is_empty():
		return

	if _dependencies_connected:
		return

	var event_bus: Node = get_node_or_null("/root/EditorEventBus")
	if not event_bus:
		return

	# Connect to all three resource change signals
	if not event_bus.resource_saved.is_connected(_on_dependency_resource_changed):
		event_bus.resource_saved.connect(_on_dependency_resource_changed)
	if not event_bus.resource_created.is_connected(_on_dependency_resource_changed):
		event_bus.resource_created.connect(_on_dependency_resource_changed)
	if not event_bus.resource_deleted.is_connected(_on_dependency_resource_deleted):
		event_bus.resource_deleted.connect(_on_dependency_resource_deleted)

	_dependencies_connected = true


## Internal handler for resource saved/created events.
## Checks if the changed resource type is in our dependencies list.
func _on_dependency_resource_changed(res_type: String, _res_id: String, _resource: Resource) -> void:
	if res_type in resource_dependencies:
		_on_dependencies_changed(res_type)


## Internal handler for resource deleted events.
## Checks if the deleted resource type is in our dependencies list.
func _on_dependency_resource_deleted(res_type: String, _res_id: String) -> void:
	if res_type in resource_dependencies:
		_on_dependencies_changed(res_type)


## Called when a dependent resource type changes (created, saved, or deleted).
## Override this in child classes to refresh caches, repopulate dropdowns, etc.
##
## @param changed_type: The resource type that changed (e.g., "item", "npc", "character")
##
## Example implementation:
##   func _on_dependencies_changed(changed_type: String) -> void:
##       if changed_type == "item":
##           _items_cache = ModLoader.registry.get_all_resources("item")
##       elif changed_type == "npc":
##           _npcs_cache = ModLoader.registry.get_all_resources("npc")
##           _populate_npc_picker()
func _on_dependencies_changed(_changed_type: String) -> void:
	# Default implementation does nothing - child classes override this
	pass


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
		var path: String = all_resource_paths[i]
		var display_name: String = _get_resource_display_name(resource)

		# Show all if no filter, otherwise check for match
		if filter_text.is_empty() or _matches_search(display_name, path, filter_text):
			resource_list.add_item(display_name)
			resource_list.set_item_metadata(resource_list.item_count - 1, path)


## Check if a resource matches the search filter
## Searches in: display name, resource ID (filename), and source mod ID
func _matches_search(display_name: String, path: String, filter: String) -> bool:
	var display_lower: String = display_name.to_lower()
	var filename: String = path.get_file().get_basename().to_lower()

	# Extract mod ID from path: mods/MOD_ID/data/...
	var mod_id: String = ""
	if "/mods/" in path:
		var after_mods: String = path.split("/mods/")[1]
		var parts: PackedStringArray = after_mods.split("/")
		if parts.size() > 0:
			mod_id = parts[0].to_lower()

	return display_lower.contains(filter) or \
		   filename.contains(filter) or \
		   mod_id.contains(filter)


## Called when search filter text changes
func _on_search_filter_changed(_new_text: String) -> void:
	_apply_filter()


func _on_resource_selected(index: int) -> void:
	# Check for unsaved changes before switching resources
	if not _check_unsaved_changes(_do_resource_selection.bind(index)):
		return

	_do_resource_selection(index)


## Internal: Perform the actual resource selection (after unsaved changes check)
func _do_resource_selection(index: int) -> void:
	var path: String = resource_list.get_item_metadata(index)
	# Load and duplicate to make it editable (load() returns read-only cached resource)
	var loaded_resource: Resource = load(path)
	current_resource = loaded_resource.duplicate(true)
	# Keep the original path so we can save to the same location
	current_resource.take_over_path(path)

	# Track source mod for write protection
	current_resource_source_mod = _get_mod_from_path(path)

	# Clear dirty flag when loading a new resource
	is_dirty = false

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

	# Perform the actual save (with or without undo/redo)
	if enable_undo_redo and undo_redo:
		_perform_save_with_undo()
	else:
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
		# Clear dirty flag on successful save
		is_dirty = false

		# Notify other editors that a resource was saved
		var event_bus: Node = get_node_or_null("/root/EditorEventBus")
		if event_bus:
			event_bus.notify_resource_saved(resource_type_id, path, current_resource)

		_hide_errors()
		var display_name: String = _get_resource_display_name(current_resource)
		_show_success_message("Saved '%s' successfully!" % display_name)
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


func _on_duplicate_resource() -> void:
	if not current_resource:
		_show_errors(["No " + resource_type_name.to_lower() + " selected to duplicate"])
		return

	# Get the file path of the current resource
	var selected_items: PackedInt32Array = resource_list.get_selected_items()
	if selected_items.size() == 0:
		_show_errors(["No " + resource_type_name.to_lower() + " selected in list"])
		return

	# Determine save directory (use active mod)
	var save_dir: String = ""
	var active_mod_id: String = ""
	if resource_type_id != "" and ModLoader:
		var active_mod: ModManifest = ModLoader.get_active_mod()
		if active_mod:
			active_mod_id = active_mod.mod_id
			var resource_dirs: Dictionary = ModLoader.get_resource_directories(active_mod.mod_id)
			save_dir = resource_dirs.get(resource_type_id, "")

	if save_dir.is_empty():
		save_dir = resource_directory

	if save_dir.is_empty():
		_show_errors(["No save directory available for duplicating " + resource_type_name.to_lower()])
		return

	# Create a duplicate resource
	var new_resource: Resource = current_resource.duplicate(true)

	# Update the resource's name to indicate it's a copy
	var original_name: String = _get_resource_display_name(current_resource)
	_update_resource_id_for_copy(new_resource, original_name)

	# Generate unique filename with timestamp
	var timestamp: int = Time.get_unix_time_from_system()
	var safe_name: String = original_name.to_lower().replace(" ", "_").replace("'", "")
	var filename: String = "%s_copy_%d.tres" % [safe_name, timestamp]
	var full_path: String = save_dir.path_join(filename)

	# Save the resource
	var err: Error = ResourceSaver.save(new_resource, full_path)
	if err == OK:
		# Notify other editors
		var event_bus: Node = get_node_or_null("/root/EditorEventBus")
		if event_bus:
			event_bus.notify_resource_created(resource_type_id, full_path, new_resource)

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

		_show_success_message("Duplicated '%s' successfully!" % original_name)
	else:
		_show_errors(["Failed to duplicate " + resource_type_name.to_lower() + ": " + str(err)])


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

	# Insert error panel just before button_container (where user's attention is)
	if error_panel.get_parent() != detail_panel:
		detail_panel.add_child(error_panel)
	var button_index: int = button_container.get_index()
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


## Show a success message (auto-dismisses after 2 seconds)
func _show_success_message(message: String) -> void:
	if not error_label or not error_panel:
		return

	# Use success styling
	var success_color: Color = EditorThemeUtils.get_success_color()
	error_label.text = "[color=#%s][b]Success:[/b] %s[/color]" % [success_color.to_html(false), message]

	# Apply success panel style
	var success_style: StyleBoxFlat = EditorThemeUtils.create_success_panel_style()
	error_panel.add_theme_stylebox_override("panel", success_style)

	# Insert error panel just before button_container (where user's attention is)
	if error_panel.get_parent() != detail_panel:
		detail_panel.add_child(error_panel)
	var button_index: int = button_container.get_index()
	detail_panel.move_child(error_panel, button_index)

	error_panel.show()

	# Auto-dismiss after 2 seconds
	var tween: Tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(_hide_success_and_restore_style)


## Hide success message and restore error styling for future errors
func _hide_success_and_restore_style() -> void:
	error_panel.hide()
	error_label.text = ""

	# Restore error styling for next use
	var error_style: StyleBoxFlat = EditorThemeUtils.create_error_panel_style()
	error_panel.add_theme_stylebox_override("panel", error_style)


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


# =============================================================================
# Active Mod Helper Methods
# =============================================================================

## Get the active mod's ID (or empty string if none)
func _get_active_mod_id() -> String:
	if not ModLoader:
		return ""
	var active_mod: ModManifest = ModLoader.get_active_mod()
	if active_mod:
		return active_mod.mod_id
	return ""


## Get the active mod's folder name (e.g., "_sandbox" from "res://mods/_sandbox/")
func _get_active_mod_folder() -> String:
	if not ModLoader:
		return ""
	var active_mod: ModManifest = ModLoader.get_active_mod()
	if active_mod:
		return active_mod.mod_directory.get_file()
	return ""


## Get the active mod's base directory path
func _get_active_mod_directory() -> String:
	if not ModLoader:
		return ""
	var active_mod: ModManifest = ModLoader.get_active_mod()
	if active_mod:
		return active_mod.mod_directory
	return ""


## Get the directory path for a specific resource type in the active mod
func _get_active_mod_resource_directory(type_id: String) -> String:
	if not ModLoader:
		return ""
	var active_mod: ModManifest = ModLoader.get_active_mod()
	if not active_mod:
		return ""

	var resource_dirs: Dictionary = ModLoader.get_resource_directories(active_mod.mod_id)
	if type_id in resource_dirs:
		return resource_dirs[type_id]
	return ""


## Scan a resource directory across all mods (for reference checking)
## Returns Array of {path: String, mod_id: String} for all matching resources
func _scan_all_mods_for_resource_type(type_id: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	if not ModLoader:
		return results

	var mods: Array[ModManifest] = ModLoader.get_all_mods()
	for mod: ModManifest in mods:
		var resource_dirs: Dictionary = ModLoader.get_resource_directories(mod.mod_id)
		if type_id in resource_dirs:
			var dir_path: String = resource_dirs[type_id]
			var dir: DirAccess = DirAccess.open(dir_path)
			if dir:
				dir.list_dir_begin()
				var file_name: String = dir.get_next()
				while file_name != "":
					if file_name.ends_with(".tres"):
						results.append({
							"path": dir_path.path_join(file_name),
							"mod_id": mod.mod_id
						})
					file_name = dir.get_next()
				dir.list_dir_end()

	return results


# =============================================================================
# Undo/Redo Helper Methods
# =============================================================================

## Begin an undoable action with a descriptive name
func _begin_undo_action(action_name: String) -> void:
	if undo_redo:
		undo_redo.create_action(action_name)


## Add an undo method to the current action
## Note: EditorUndoRedoManager uses (Object, StringName, ...) not Callable
## For methods with arguments, call add_undo_method directly with varargs
func _add_undo_method(obj: Object, method: StringName) -> void:
	if undo_redo:
		undo_redo.add_undo_method(obj, method)


## Add a do method to the current action
## Note: EditorUndoRedoManager uses (Object, StringName, ...) not Callable
## For methods with arguments, call add_do_method directly with varargs
func _add_do_method(obj: Object, method: StringName) -> void:
	if undo_redo:
		undo_redo.add_do_method(obj, method)


## Add a do/undo property pair to the current action
func _add_undo_property(obj: Object, property: StringName, old_value: Variant, new_value: Variant) -> void:
	if undo_redo:
		undo_redo.add_do_property(obj, property, new_value)
		undo_redo.add_undo_property(obj, property, old_value)


## Commit the current undoable action
func _commit_undo_action() -> void:
	if undo_redo:
		undo_redo.commit_action()


# =============================================================================
# Undo/Redo State Management
# =============================================================================

## Override this in subclasses to capture resource state for undo
## Returns a Dictionary containing all relevant resource properties
## This is called before save operations to preserve old state
func _capture_resource_state(resource: Resource) -> Dictionary:
	# Default implementation: use Godot's property list
	var state: Dictionary = {}
	for prop: Dictionary in resource.get_property_list():
		var prop_name: String = prop.get("name", "")
		var usage: int = prop.get("usage", 0)
		# Only capture exported/stored properties (not built-in ones)
		if usage & PROPERTY_USAGE_STORAGE:
			state[prop_name] = resource.get(prop_name)
	return state


## Override this in subclasses to restore resource state for undo
## Applies the state Dictionary back to the resource
func _restore_resource_state(resource: Resource, state: Dictionary) -> void:
	for prop_name: String in state.keys():
		if prop_name in resource:
			resource.set(prop_name, state[prop_name])


## Perform a save with undo/redo support
## Call this instead of _perform_save() when undo/redo is desired
func _perform_save_with_undo() -> void:
	if not current_resource or not undo_redo:
		# Fall back to regular save if undo not available
		_perform_save()
		return

	var selected_items: PackedInt32Array = resource_list.get_selected_items()
	if selected_items.is_empty():
		_perform_save()
		return

	var path: String = resource_list.get_item_metadata(selected_items[0])

	# Capture state before changes
	var old_state: Dictionary = _capture_resource_state(current_resource)

	# Create a temporary copy to hold new values
	_save_resource_data()  # Apply UI to resource

	# Capture state after changes
	var new_state: Dictionary = _capture_resource_state(current_resource)

	# Restore old state temporarily for proper undo setup
	_restore_resource_state(current_resource, old_state)

	# Create undo/redo action
	_begin_undo_action("Edit %s" % resource_type_name)

	# Store old and new states for property-based undo
	for prop_name: String in new_state.keys():
		if prop_name in old_state:
			var old_val: Variant = old_state.get(prop_name)
			var new_val: Variant = new_state.get(prop_name)
			# Only record if value actually changed
			if not _values_equal(old_val, new_val):
				undo_redo.add_do_property(current_resource, prop_name, new_val)
				undo_redo.add_undo_property(current_resource, prop_name, old_val)

	# Add do/undo callbacks for file saving and UI refresh
	undo_redo.add_do_method(self, &"_do_save_resource", path)
	undo_redo.add_undo_method(self, &"_do_save_resource", path)

	# Add UI refresh after undo/redo
	undo_redo.add_do_method(self, &"_refresh_current_resource_ui")
	undo_redo.add_undo_method(self, &"_refresh_current_resource_ui")

	_commit_undo_action()

	# Clear dirty flag and show success feedback (mirrors _perform_save behavior)
	is_dirty = false
	_hide_errors()
	var display_name: String = _get_resource_display_name(current_resource)
	_show_success_message("Saved '%s' successfully!" % display_name)
	_refresh_list()


## Internal: Save resource to disk (called by undo/redo system)
func _do_save_resource(path: String) -> void:
	if current_resource:
		var err: Error = ResourceSaver.save(current_resource, path)
		if err != OK:
			push_error("Failed to save resource: %s" % error_string(err))
		else:
			# Notify other editors
			var event_bus: Node = get_node_or_null("/root/EditorEventBus")
			if event_bus:
				event_bus.notify_resource_saved(resource_type_id, path, current_resource)


## Internal: Refresh UI after undo/redo
func _refresh_current_resource_ui() -> void:
	if current_resource:
		_load_resource_data()


## Compare two values for equality (handles arrays and dictionaries)
func _values_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Array:
		var arr_a: Array = a
		var arr_b: Array = b
		if arr_a.size() != arr_b.size():
			return false
		for i in range(arr_a.size()):
			if not _values_equal(arr_a[i], arr_b[i]):
				return false
		return true
	if a is Dictionary:
		var dict_a: Dictionary = a
		var dict_b: Dictionary = b
		if dict_a.size() != dict_b.size():
			return false
		for key: Variant in dict_a.keys():
			if key not in dict_b or not _values_equal(dict_a[key], dict_b[key]):
				return false
		return true
	return a == b


# =============================================================================
# Unsaved Changes Warning
# =============================================================================

## Create the unsaved changes dialog with Save/Discard/Cancel options
func _create_unsaved_changes_dialog() -> void:
	unsaved_changes_dialog = AcceptDialog.new()
	unsaved_changes_dialog.title = "Unsaved Changes"
	unsaved_changes_dialog.dialog_text = "You have unsaved changes. What would you like to do?"
	unsaved_changes_dialog.ok_button_text = "Save"

	# Add Discard button
	var discard_btn: Button = unsaved_changes_dialog.add_button("Discard", false, "discard")

	# Add Cancel button (right side)
	var cancel_btn: Button = unsaved_changes_dialog.add_cancel_button("Cancel")

	# Connect signals
	unsaved_changes_dialog.confirmed.connect(_on_unsaved_dialog_save)
	unsaved_changes_dialog.custom_action.connect(_on_unsaved_dialog_custom_action)
	unsaved_changes_dialog.canceled.connect(_on_unsaved_dialog_cancel)

	add_child(unsaved_changes_dialog)


## Check for unsaved changes before performing an action
## If there are unsaved changes, shows dialog and stores callback for later execution
## Returns true if the action can proceed immediately (no unsaved changes)
## Returns false if dialog was shown (action will proceed via callback if user chooses)
func _check_unsaved_changes(callback: Callable) -> bool:
	if not is_dirty:
		return true

	# Store callback for later execution
	_pending_unsaved_callback = callback

	# Show the dialog
	unsaved_changes_dialog.popup_centered()

	return false


## Called when user clicks "Save" in unsaved changes dialog
func _on_unsaved_dialog_save() -> void:
	# Save the current resource
	_perform_save()

	# Clear dirty flag
	is_dirty = false

	# Execute the pending callback
	if _pending_unsaved_callback.is_valid():
		_pending_unsaved_callback.call()
	_pending_unsaved_callback = Callable()


## Called when user clicks a custom button (Discard)
func _on_unsaved_dialog_custom_action(action: StringName) -> void:
	if action == &"discard":
		# Discard changes and proceed
		is_dirty = false

		# Execute the pending callback
		if _pending_unsaved_callback.is_valid():
			_pending_unsaved_callback.call()
		_pending_unsaved_callback = Callable()


## Called when user clicks "Cancel" or closes the dialog
func _on_unsaved_dialog_cancel() -> void:
	# Clear the pending callback - action is cancelled
	_pending_unsaved_callback = Callable()


## Mark the editor as having unsaved changes
## Call this from subclasses when user modifies any field
func _mark_dirty() -> void:
	is_dirty = true


## Clear the dirty flag (typically after saving)
func _clear_dirty() -> void:
	is_dirty = false
