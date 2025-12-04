@tool
extends Node

## EditorEventBus - Centralized event system for Sparkling Editor
##
## This singleton allows different editor tabs to communicate with each other
## without tight coupling. When one tab modifies data, other tabs can automatically
## refresh their dependent data.
##
## Usage:
##   # Emit when saving a resource
##   EditorEventBus.resource_saved.emit("class", resource_id, resource)
##
##   # Listen for changes in another editor
##   EditorEventBus.resource_saved.connect(_on_resource_saved)

## Emitted when any resource is saved in any editor tab
## Parameters: resource_type (String), resource_id (String), resource (Resource)
signal resource_saved(resource_type: String, resource_id: String, resource: Resource)

## Emitted when any resource is created in any editor tab
## Parameters: resource_type (String), resource_id (String), resource (Resource)
signal resource_created(resource_type: String, resource_id: String, resource: Resource)

## Emitted when any resource is deleted in any editor tab
## Parameters: resource_type (String), resource_id (String)
signal resource_deleted(resource_type: String, resource_id: String)

## Emitted when the active mod changes
## Parameters: mod_id (String)
signal active_mod_changed(mod_id: String)

## Emitted when mods are reloaded
signal mods_reloaded()

## Emitted when a resource is copied to another mod
## Parameters: resource_type (String), source_path (String), target_mod_id (String), target_path (String)
signal resource_copied(resource_type: String, source_path: String, target_mod_id: String, target_path: String)

## Emitted when a resource override is created in a mod
## Parameters: resource_type (String), resource_id (String), mod_id (String)
signal resource_override_created(resource_type: String, resource_id: String, mod_id: String)


func _ready() -> void:
	if Engine.is_editor_hint():
		print("EditorEventBus: Initialized")


## Convenience method to emit resource_saved with automatic ID extraction
func notify_resource_saved(resource_type: String, resource_path: String, resource: Resource) -> void:
	var resource_id: String = resource_path.get_file().get_basename()
	resource_saved.emit(resource_type, resource_id, resource)


## Convenience method to emit resource_created with automatic ID extraction
func notify_resource_created(resource_type: String, resource_path: String, resource: Resource) -> void:
	var resource_id: String = resource_path.get_file().get_basename()
	resource_created.emit(resource_type, resource_id, resource)


## Convenience method to emit resource_deleted with automatic ID extraction
func notify_resource_deleted(resource_type: String, resource_path: String) -> void:
	var resource_id: String = resource_path.get_file().get_basename()
	resource_deleted.emit(resource_type, resource_id)
