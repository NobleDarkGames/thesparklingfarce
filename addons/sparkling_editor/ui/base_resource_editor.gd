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
var detail_panel: VBoxContainer
var button_container: HBoxContainer
var save_button: Button
var delete_button: Button

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


func _ready() -> void:
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
					resource_list.add_item(_get_resource_display_name(resource))
					resource_list.set_item_metadata(resource_list.item_count - 1, full_path)
					available_resources.append(resource)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		push_error("Failed to open directory: " + dir_path)


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

	_load_resource_data()


## Determine which mod a resource path belongs to
func _get_mod_from_path(path: String) -> String:
	# Paths are like: res://mods/_base_game/data/characters/hero.tres
	if path.begins_with("res://mods/"):
		var parts: PackedStringArray = path.split("/")
		if parts.size() >= 3:
			return parts[2]  # The mod folder name
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
		if EditorEventBus:
			EditorEventBus.notify_resource_saved(resource_type_id, path, current_resource)

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
	if resource_type_id != "" and ModLoader:
		var active_mod: ModManifest = ModLoader.get_active_mod()
		if active_mod:
			var resource_dirs: Dictionary = ModLoader.get_resource_directories(active_mod.mod_id)
			save_dir = resource_dirs.get(resource_type_id, "")

	# Fallback to legacy directory
	if save_dir == "":
		save_dir = resource_directory

	if save_dir == "":
		push_error("No save directory available for " + resource_type_name.to_lower())
		return

	# Generate unique filename
	var timestamp: int = Time.get_unix_time_from_system()
	var filename: String = resource_type_name.to_lower() + "_%d.tres" % timestamp
	var full_path: String = save_dir.path_join(filename)

	# Save the resource
	var err: Error = ResourceSaver.save(new_resource, full_path)
	if err == OK:
		# Notify other editors that a resource was created
		if EditorEventBus:
			EditorEventBus.notify_resource_created(resource_type_id, full_path, new_resource)

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
			if EditorEventBus:
				EditorEventBus.notify_resource_deleted(resource_type_id, path)

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
