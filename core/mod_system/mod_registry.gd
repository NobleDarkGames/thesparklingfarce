@tool
extends RefCounted
class_name ModRegistry

## Central registry for all loaded mod resources
## Tracks resources by type and provides lookup functions
## Handles resource overrides (later mods override earlier ones)

# Dictionary structure: { "resource_type": { "resource_id": Resource } }
# Example: { "character": { "hero": CharacterData, "mage": CharacterData } }
var _resources_by_type: Dictionary = {}

# Dictionary structure: { "resource_id": "mod_id" }
# Tracks which mod provided each resource
var _resource_sources: Dictionary = {}

# Dictionary structure: { "mod_id": Array[String] of resource_ids }
# Tracks all resources provided by each mod
var _mod_resources: Dictionary = {}


## Register a resource from a mod
func register_resource(resource: Resource, resource_type: String, resource_id: String, mod_id: String) -> void:
	if not resource:
		push_error("Attempted to register null resource: " + resource_id)
		return

	# Ensure type dictionary exists
	if not resource_type in _resources_by_type:
		_resources_by_type[resource_type] = {}

	# Check if this resource ID already exists (override scenario)
	if resource_id in _resources_by_type[resource_type]:
		var existing_mod: String = _resource_sources.get(resource_id, "unknown")
		print("ModRegistry: Mod '%s' overriding resource '%s' from mod '%s'" % [mod_id, resource_id, existing_mod])

	# Register the resource
	_resources_by_type[resource_type][resource_id] = resource
	_resource_sources[resource_id] = mod_id

	# Track mod's resources
	if not mod_id in _mod_resources:
		_mod_resources[mod_id] = []
	if not resource_id in _mod_resources[mod_id]:
		_mod_resources[mod_id].append(resource_id)


## Get a specific resource by type and ID
func get_resource(resource_type: String, resource_id: String) -> Resource:
	if not resource_type in _resources_by_type:
		return null
	return _resources_by_type[resource_type].get(resource_id, null)


## Get all resources of a specific type
func get_all_resources(resource_type: String) -> Array[Resource]:
	var result: Array[Resource] = []
	if resource_type in _resources_by_type:
		for resource: Resource in _resources_by_type[resource_type].values():
			result.append(resource)
	return result


## Get the hero character (primary protagonist)
## Returns null if no hero exists or if multiple heroes exist (with warning)
func get_hero_character() -> CharacterData:
	if not "character" in _resources_by_type:
		return null

	var heroes: Array[CharacterData] = []
	for character: Resource in _resources_by_type["character"].values():
		var char_data: CharacterData = character as CharacterData
		if char_data and char_data.is_hero:
			heroes.append(char_data)

	if heroes.is_empty():
		return null

	if heroes.size() > 1:
		push_warning("ModRegistry: Multiple heroes detected! Only one hero should exist. Using first found.")
		for hero: CharacterData in heroes:
			var source_mod: String = get_resource_source(hero.resource_path.get_file().get_basename())
			push_warning("  - Hero '%s' from mod '%s'" % [hero.character_name, source_mod])

	return heroes[0]


## Get all resource IDs of a specific type
func get_resource_ids(resource_type: String) -> Array[String]:
	var result: Array[String] = []
	if resource_type in _resources_by_type:
		for resource_id: String in _resources_by_type[resource_type].keys():
			result.append(resource_id)
	return result


## Get the mod ID that provided a specific resource
func get_resource_source(resource_id: String) -> String:
	return _resource_sources.get(resource_id, "")


## Get all resources provided by a specific mod
func get_mod_resources(mod_id: String) -> Array[String]:
	return _mod_resources.get(mod_id, []).duplicate()


## Get all registered resource types
func get_resource_types() -> Array[String]:
	var result: Array[String] = []
	for type_name: String in _resources_by_type.keys():
		result.append(type_name)
	return result


## Get count of resources of a specific type
func get_resource_count(resource_type: String) -> int:
	if not resource_type in _resources_by_type:
		return 0
	return _resources_by_type[resource_type].size()


## Get total count of all resources
func get_total_resource_count() -> int:
	var count: int = 0
	for type_dict: Dictionary in _resources_by_type.values():
		count += type_dict.size()
	return count


## Check if a resource exists
func has_resource(resource_type: String, resource_id: String) -> bool:
	if not resource_type in _resources_by_type:
		return false
	return resource_id in _resources_by_type[resource_type]


## Clear all registered resources
func clear() -> void:
	_resources_by_type.clear()
	_resource_sources.clear()
	_mod_resources.clear()


## Clear all resources from a specific mod
func clear_mod_resources(mod_id: String) -> void:
	if not mod_id in _mod_resources:
		return

	# Remove each resource registered by this mod
	for resource_id: String in _mod_resources[mod_id]:
		# Find and remove from type dictionaries
		for type_dict: Dictionary in _resources_by_type.values():
			if resource_id in type_dict:
				type_dict.erase(resource_id)
		# Remove from sources
		_resource_sources.erase(resource_id)

	# Clear mod's resource list
	_mod_resources.erase(mod_id)


## Get statistics about loaded resources
func get_statistics() -> Dictionary:
	var stats: Dictionary = {}
	stats.total_resources = get_total_resource_count()
	stats.resource_types = get_resource_types()
	stats.type_counts = {}
	for resource_type: String in stats.resource_types:
		stats.type_counts[resource_type] = get_resource_count(resource_type)
	stats.loaded_mods = _mod_resources.keys()
	return stats


## Print debug information about the registry
func print_debug() -> void:
	print("=== ModRegistry Debug ===")
	print("Total resources: %d" % get_total_resource_count())
	print("Resource types: %s" % str(get_resource_types()))
	for resource_type: String in get_resource_types():
		print("  - %s: %d resources" % [resource_type, get_resource_count(resource_type)])
	print("Loaded mods: %s" % str(_mod_resources.keys()))
	print("========================")
