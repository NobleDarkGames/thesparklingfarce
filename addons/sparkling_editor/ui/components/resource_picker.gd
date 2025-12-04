@tool
extends HBoxContainer
class_name ResourcePicker

## Reusable mod-aware resource picker for the Sparkling Editor
##
## Displays resources from ALL loaded mods with source attribution.
## Format: "[mod_id] Resource Name"
##
## Usage:
##   var picker: ResourcePicker = ResourcePicker.new()
##   picker.resource_type = "character"
##   picker.resource_selected.connect(_on_character_selected)
##   add_child(picker)
##
## The picker uses ModLoader.registry to get resources, ensuring:
## - All mods' resources are visible (not just active mod)
## - Priority ordering is respected (higher priority mods override)
## - Source mod is displayed for each resource

## Emitted when a resource is selected
## metadata contains: { "mod_id": String, "resource_id": String, "resource": Resource }
## metadata is empty Dictionary when "(None)" is selected
signal resource_selected(metadata: Dictionary)

## Emitted when the picker is refreshed (e.g., after mods reload)
signal picker_refreshed()

## The resource type to display (e.g., "character", "class", "item", "ability")
## Must match a type registered in ModLoader.RESOURCE_TYPE_DIRS
@export var resource_type: String = "":
	set(value):
		resource_type = value
		if is_inside_tree():
			refresh()

## Optional filter function to exclude certain resources
## Signature: func(resource: Resource) -> bool
## Return true to include the resource, false to exclude
var filter_function: Callable = Callable()

## Label text shown before the dropdown (empty string hides the label)
@export var label_text: String = "":
	set(value):
		label_text = value
		if _label:
			_label.text = value
			_label.visible = not value.is_empty()

## Minimum width for the label (for alignment)
@export var label_min_width: float = 0.0:
	set(value):
		label_min_width = value
		if _label:
			_label.custom_minimum_size.x = value

## The placeholder text shown when nothing is selected
@export var none_text: String = "(None)"

## Whether to allow selecting "(None)" (no resource selected)
@export var allow_none: bool = true

## Whether to show the refresh button
@export var show_refresh_button: bool = false:
	set(value):
		show_refresh_button = value
		if _refresh_button:
			_refresh_button.visible = value

## Internal references
var _label: Label
var _option_button: OptionButton
var _refresh_button: Button

## Currently selected metadata (empty if none selected)
var _current_metadata: Dictionary = {}

## Track override information for each resource (resource_id -> Array of mod_ids)
var _override_info: Dictionary = {}


func _init() -> void:
	# Set up layout
	add_theme_constant_override("separation", 8)


func _ready() -> void:
	_setup_ui()

	# Connect to EditorEventBus for mod reload notifications
	var event_bus: Node = get_node_or_null("/root/EditorEventBus")
	if event_bus:
		if not event_bus.mods_reloaded.is_connected(_on_mods_reloaded):
			event_bus.mods_reloaded.connect(_on_mods_reloaded)

	# Initial refresh if resource_type is set
	if not resource_type.is_empty():
		refresh()


func _exit_tree() -> void:
	# Clean up signal connections
	var event_bus: Node = get_node_or_null("/root/EditorEventBus")
	if event_bus:
		if event_bus.mods_reloaded.is_connected(_on_mods_reloaded):
			event_bus.mods_reloaded.disconnect(_on_mods_reloaded)


func _setup_ui() -> void:
	# Create label (optional)
	_label = Label.new()
	_label.text = label_text
	_label.visible = not label_text.is_empty()
	_label.custom_minimum_size.x = label_min_width
	add_child(_label)

	# Create option button (the dropdown)
	_option_button = OptionButton.new()
	_option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_option_button.custom_minimum_size.x = 200
	_option_button.item_selected.connect(_on_item_selected)
	add_child(_option_button)

	# Create refresh button (optional)
	_refresh_button = Button.new()
	_refresh_button.text = "R"
	_refresh_button.tooltip_text = "Refresh resource list"
	_refresh_button.custom_minimum_size.x = 30
	_refresh_button.visible = show_refresh_button
	_refresh_button.pressed.connect(refresh)
	add_child(_refresh_button)


## Refresh the dropdown with resources from all mods
func refresh() -> void:
	if not _option_button:
		return

	_option_button.clear()
	_override_info.clear()

	# Add "(None)" option if allowed
	if allow_none:
		_option_button.add_item(none_text)
		_option_button.set_item_metadata(0, {})

	# Check if ModLoader is available
	if not ModLoader:
		push_warning("ResourcePicker: ModLoader not available")
		return

	if resource_type.is_empty():
		push_warning("ResourcePicker: No resource_type set")
		return

	# Get all resources of the specified type from the registry
	var all_resources: Array[Resource] = ModLoader.registry.get_all_resources(resource_type)

	if all_resources.is_empty():
		# No resources found - this might be expected or a configuration issue
		return

	# Scan directories to detect override situations (same filename in multiple mods)
	_override_info = _scan_for_overrides()

	# Collect all resources from the registry
	var sorted_resources: Array[Dictionary] = []

	for resource: Resource in all_resources:
		# Apply filter if set
		if filter_function.is_valid():
			if not filter_function.call(resource):
				continue

		var display_name: String = _get_display_name(resource)
		var resource_id: String = _get_resource_id(resource)
		var mod_id: String = ModLoader.registry.get_resource_source(resource_id)

		var entry: Dictionary = {
			"display_name": display_name,
			"resource_id": resource_id,
			"mod_id": mod_id,
			"resource": resource
		}

		sorted_resources.append(entry)

	# Sort alphabetically by display name
	sorted_resources.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.display_name.to_lower() < b.display_name.to_lower()
	)

	# Add items to dropdown with override indicators
	for entry: Dictionary in sorted_resources:
		var item_text: String = _format_item_text(entry)
		var item_index: int = _option_button.item_count
		_option_button.add_item(item_text)
		_option_button.set_item_metadata(item_index, {
			"mod_id": entry.mod_id,
			"resource_id": entry.resource_id,
			"resource": entry.resource,
			"has_override": entry.resource_id in _override_info
		})

	# Restore previous selection if possible
	if not _current_metadata.is_empty():
		_select_by_metadata(_current_metadata)

	picker_refreshed.emit()


## Format the display text for an item, including override indicators
func _format_item_text(entry: Dictionary) -> String:
	var resource_id: String = entry.resource_id
	var mod_id: String = entry.mod_id
	var display_name: String = entry.display_name

	var text: String = "[%s] %s" % [mod_id, display_name]

	# Check if this resource has overrides in other mods
	if resource_id in _override_info:
		var mods: Array = _override_info[resource_id]
		var other_mods: Array = []
		for m in mods:
			if m != mod_id:
				other_mods.append(m)

		if other_mods.size() > 0:
			# This is the active version - show what it overrides or is overridden by
			var active_source: String = ModLoader.registry.get_resource_source(resource_id)
			if active_source == mod_id:
				# This IS the active version (higher priority won)
				text += " [ACTIVE - overrides: %s]" % ", ".join(other_mods)
			else:
				# This is being overridden by another mod
				text += " [overridden by: %s]" % active_source

	return text


## Scan all mods to detect resources with the same ID across multiple mods
## Returns a Dictionary mapping resource_id -> Array of mod_ids that have that resource
func _scan_for_overrides() -> Dictionary:
	var overrides: Dictionary = {}

	if not ModLoader:
		return overrides

	# Get the directory name for this resource type
	var type_dir_map: Dictionary = ModLoader.RESOURCE_TYPE_DIRS if "RESOURCE_TYPE_DIRS" in ModLoader else {}
	var dir_name: String = type_dir_map.get(resource_type, resource_type + "s")

	# Scan each mod's data directory
	var mods_dir: DirAccess = DirAccess.open("res://mods/")
	if not mods_dir:
		return overrides

	mods_dir.list_dir_begin()
	var mod_name: String = mods_dir.get_next()

	while mod_name != "":
		if mods_dir.current_is_dir() and not mod_name.begins_with("."):
			var resource_path: String = "res://mods/%s/data/%s/" % [mod_name, dir_name]
			var res_dir: DirAccess = DirAccess.open(resource_path)

			if res_dir:
				res_dir.list_dir_begin()
				var file_name: String = res_dir.get_next()

				while file_name != "":
					if not res_dir.current_is_dir() and file_name.ends_with(".tres"):
						var res_id: String = file_name.get_basename()
						if res_id not in overrides:
							overrides[res_id] = []
						overrides[res_id].append(mod_name)
					file_name = res_dir.get_next()

				res_dir.list_dir_end()

		mod_name = mods_dir.get_next()

	mods_dir.list_dir_end()

	# Filter to only resources that exist in multiple mods
	var multi_mod_resources: Dictionary = {}
	for res_id: String in overrides.keys():
		if overrides[res_id].size() > 1:
			multi_mod_resources[res_id] = overrides[res_id]

	return multi_mod_resources


## Check if a resource has potential overrides (exists in multiple mods)
func has_override_info(resource_id: String) -> bool:
	return resource_id in _override_info


## Get the mods that have a specific resource ID
func get_mods_with_resource(resource_id: String) -> Array:
	return _override_info.get(resource_id, [])


## Get the display name from a resource (handles different resource types)
func _get_display_name(resource: Resource) -> String:
	# Try common name properties in order of preference
	if resource.has_method("get_display_name"):
		return resource.get_display_name()

	# Check for common name properties
	var name_properties: Array[String] = [
		"display_name",
		"character_name",
		"item_name",
		"ability_name",
		"dialogue_id",
		"party_name",
		"battle_name",
		"class_name"  # Note: ClassData uses display_name, but this is a fallback
	]

	for prop: String in name_properties:
		if prop in resource:
			var value: Variant = resource.get(prop)
			if value is String and not value.is_empty():
				return value

	# Fallback to resource path filename
	return resource.resource_path.get_file().get_basename()


## Get the resource ID from a resource
func _get_resource_id(resource: Resource) -> String:
	# The resource ID is typically the filename without extension
	return resource.resource_path.get_file().get_basename()


## Called when an item is selected in the dropdown
func _on_item_selected(index: int) -> void:
	var metadata: Variant = _option_button.get_item_metadata(index)

	if metadata is Dictionary:
		_current_metadata = metadata
		resource_selected.emit(metadata)
	else:
		_current_metadata = {}
		resource_selected.emit({})


## Called when mods are reloaded
func _on_mods_reloaded() -> void:
	refresh()


## Select a resource by its metadata (mod_id + resource_id)
func _select_by_metadata(metadata: Dictionary) -> void:
	if not _option_button:
		return

	if metadata.is_empty():
		if allow_none:
			_option_button.select(0)
		return

	var target_mod_id: String = metadata.get("mod_id", "")
	var target_resource_id: String = metadata.get("resource_id", "")

	for i in range(_option_button.item_count):
		var item_metadata: Variant = _option_button.get_item_metadata(i)
		if item_metadata is Dictionary:
			if item_metadata.get("mod_id", "") == target_mod_id:
				if item_metadata.get("resource_id", "") == target_resource_id:
					_option_button.select(i)
					return

	# Resource not found - might have been removed or mod unloaded
	# Select "(None)" if available
	if allow_none:
		_option_button.select(0)


## Select a resource by direct Resource reference
func select_resource(resource: Resource) -> void:
	if not resource:
		select_none()
		return

	var resource_id: String = _get_resource_id(resource)
	var mod_id: String = ModLoader.registry.get_resource_source(resource_id)

	_current_metadata = {
		"mod_id": mod_id,
		"resource_id": resource_id,
		"resource": resource
	}

	_select_by_metadata(_current_metadata)


## Select a resource by type and ID
func select_by_id(mod_id: String, resource_id: String) -> void:
	var resource: Resource = ModLoader.registry.get_resource(resource_type, resource_id)

	_current_metadata = {
		"mod_id": mod_id,
		"resource_id": resource_id,
		"resource": resource
	}

	_select_by_metadata(_current_metadata)


## Select "(None)" option
func select_none() -> void:
	_current_metadata = {}
	if allow_none and _option_button:
		_option_button.select(0)


## Get the currently selected resource (or null if none selected)
func get_selected_resource() -> Resource:
	if _current_metadata.is_empty():
		return null
	return _current_metadata.get("resource", null)


## Get the currently selected metadata
func get_selected_metadata() -> Dictionary:
	return _current_metadata.duplicate()


## Get the mod ID of the currently selected resource (or empty string)
func get_selected_mod_id() -> String:
	return _current_metadata.get("mod_id", "")


## Get the resource ID of the currently selected resource (or empty string)
func get_selected_resource_id() -> String:
	return _current_metadata.get("resource_id", "")


## Check if a resource is currently selected
func has_selection() -> bool:
	return not _current_metadata.is_empty()


## Set the dropdown to be disabled/enabled
func set_disabled(disabled: bool) -> void:
	if _option_button:
		_option_button.disabled = disabled


## Get the underlying OptionButton for advanced customization
func get_option_button() -> OptionButton:
	return _option_button
