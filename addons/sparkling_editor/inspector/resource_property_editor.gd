@tool
extends EditorProperty
class_name ResourcePropertyEditor

## Custom EditorProperty that uses ResourcePicker for mod-aware resource selection.
##
## Shows a dropdown with format: [mod_id] Resource Name
## Replaces Godot's default resource picker for specified properties.
##
## Features:
## - Shows all resources from all loaded mods
## - Source mod attribution for each resource
## - Override indicators when same ID exists in multiple mods
## - Proper undo/redo support via emit_changed()

const ResourcePicker = preload("res://addons/sparkling_editor/ui/components/resource_picker.gd")

## The resource type to query from the registry (e.g., "interactable", "npc")
var resource_type: String = ""

## Internal picker instance
var _picker: ResourcePicker

## Flag to prevent signal feedback loops during UI updates
var _updating: bool = false


func _init() -> void:
	# Create the ResourcePicker
	_picker = ResourcePicker.new()
	_picker.allow_none = true
	_picker.none_text = "(None - Select Resource)"
	_picker.resource_selected.connect(_on_resource_selected)

	add_child(_picker)


func _ready() -> void:
	# Set resource type after we're in the tree
	_picker.resource_type = resource_type

	# Make the option button focusable for proper editor integration
	var option_btn: OptionButton = _picker.get_option_button()
	if option_btn:
		add_focusable(option_btn)


func _update_property() -> void:
	# Called by Godot when the property value changes externally
	# (e.g., from undo/redo, or scene reload)
	_updating = true

	var current_value: Resource = get_edited_object().get(get_edited_property())
	if current_value:
		_picker.select_resource(current_value)
	else:
		_picker.select_none()

	_updating = false


func _on_resource_selected(metadata: Dictionary) -> void:
	if _updating:
		return

	var resource: Resource = metadata.get("resource", null)

	# Use emit_changed for proper undo/redo support
	# Godot's EditorProperty system handles the rest
	emit_changed(get_edited_property(), resource)
