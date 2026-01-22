## Base class for spawnable entity handlers
## Mods can extend this to add custom entity types that can be spawned in cinematics
class_name SpawnableEntityHandler
extends RefCounted


## Return the entity type identifier (e.g., "character", "interactable", "npc")
func get_type_id() -> String:
	push_error("SpawnableEntityHandler.get_type_id() must be overridden")
	return ""


## Return human-readable display name for the editor
func get_display_name() -> String:
	return get_type_id().capitalize()


## Return list of available entity IDs for this type from the registry
## Each entry is a Dictionary with at least: {"id": String, "name": String}
func get_available_entities() -> Array[Dictionary]:
	push_error("SpawnableEntityHandler.get_available_entities() must be overridden")
	return []


## Helper to build entity list from registry resources
## name_extractor: Callable(resource: Resource) -> String that extracts display name
func _build_entity_list_from_registry(resource_type: String, name_extractor: Callable) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []

	if not ModLoader or not ModLoader.registry:
		return entities

	var resources: Array = ModLoader.registry.get_all_resources(resource_type)
	for entry: Dictionary in resources:
		if "resource" not in entry:
			continue
		var resource: Resource = entry["resource"]
		if resource:
			var entity_id: String = str(entry["id"]) if "id" in entry else ""
			var display_name: String = name_extractor.call(resource, entity_id)
			entities.append({
				"id": entity_id,
				"name": display_name,
				"resource": resource
			})

	return entities


## Create the visual node (sprite) for the entity
## Returns the sprite node or null on failure
func create_sprite_node(entity_id: String, facing: String) -> Node2D:
	push_error("SpawnableEntityHandler.create_sprite_node() must be overridden")
	return null


## Get editor metadata for this entity type's parameters
## Returns parameter hints for the cinematic editor
func get_editor_hints() -> Dictionary:
	return {
		"entity_id_hint": "Select a %s" % get_display_name().to_lower()
	}
