@tool
extends EditorInspectorPlugin
class_name ResourceInspectorPlugin

## Custom inspector plugin that replaces default resource pickers
## with mod-aware ResourcePicker dropdowns for specific property types.
##
## Handles:
## - InteractableNode.interactable_data -> ResourcePicker for "interactable"
## - NPCNode.npc_data -> ResourcePicker for "npc"
##
## This provides a much better UX for modders by showing:
## - All resources from all loaded mods
## - Source mod attribution: "[mod_id] Resource Name"
## - Override indicators when resources exist in multiple mods

const ResourcePropertyEditor = preload("res://addons/sparkling_editor/inspector/resource_property_editor.gd")

## Map of class_name -> { property_name: resource_type }
## Add entries here to support additional node types
const HANDLED_PROPERTIES: Dictionary = {
	"InteractableNode": {
		"interactable_data": "interactable"
	},
	"NPCNode": {
		"npc_data": "npc"
	}
}


func _can_handle(object: Object) -> bool:
	# Check if this object's script class is one we handle
	var script_class: String = _get_script_class_name(object)
	return script_class in HANDLED_PROPERTIES


func _parse_property(object: Object, type: Variant.Type, name: String,
		hint_type: PropertyHint, hint_string: String,
		usage_flags: int, wide: bool) -> bool:
	var script_class: String = _get_script_class_name(object)

	if script_class not in HANDLED_PROPERTIES:
		return false

	var class_props: Dictionary = HANDLED_PROPERTIES[script_class]
	if name not in class_props:
		return false

	# This is a property we want to override
	var resource_type: String = class_props[name]

	# Create our custom property editor
	var editor: ResourcePropertyEditor = ResourcePropertyEditor.new()
	editor.resource_type = resource_type

	add_property_editor(name, editor)
	return true  # We handled this property


## Get the script class name from an object
## Returns the class_name defined in the script, or empty string if none
func _get_script_class_name(object: Object) -> String:
	var script: Script = object.get_script()
	if not script:
		return ""

	# Get the global class name if defined
	var global_name: String = script.get_global_name()
	if not global_name.is_empty():
		return global_name

	return ""
