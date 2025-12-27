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
var _resource_sources: Dictionary[String, String] = {}

# Dictionary structure: { "mod_id": Array[String] of resource_ids }
# Tracks all resources provided by each mod
var _mod_resources: Dictionary = {}

# Scene registration (separate from resources - scenes are paths, not Resource objects)
# Dictionary structure: { "scene_id": "scene_path" }
var _scenes: Dictionary[String, String] = {}

# Dictionary structure: { "scene_id": "mod_id" }
# Tracks which mod provided each scene
var _scene_sources: Dictionary[String, String] = {}

# Override chains - tracks the history of resource overrides for debugging
# Dictionary structure: { "resource_type:resource_id": Array[{mod_id, priority}] }
var _override_chains: Dictionary = {}


## Register a resource from a mod
## Detects and warns about same-priority conflicts
func register_resource(resource: Resource, resource_type: String, resource_id: String, mod_id: String) -> void:
	if not resource:
		push_error("Attempted to register null resource: " + resource_id)
		return

	# Ensure type dictionary exists
	if resource_type not in _resources_by_type:
		_resources_by_type[resource_type] = {}

	# Check for conflicts and track override chain
	var composite_id: String = "%s:%s" % [resource_type, resource_id]
	var type_resources: Dictionary = _resources_by_type[resource_type]
	if resource_id in type_resources:
		var existing_mod_id: String = _resource_sources.get(resource_id, "")
		if not existing_mod_id.is_empty() and existing_mod_id != mod_id:
			var existing_priority: int = _get_mod_priority(existing_mod_id)
			var new_priority: int = _get_mod_priority(mod_id)

			# Track the override chain
			if composite_id not in _override_chains:
				_override_chains[composite_id] = []
			var override_chain: Array = _override_chains[composite_id]
			override_chain.append({
				"mod_id": existing_mod_id,
				"priority": existing_priority
			})

			# Warn about same-priority conflicts
			if existing_priority == new_priority:
				push_warning("ModRegistry: Same-priority conflict for %s '%s' - mod '%s' overrides '%s' (both priority %d, alphabetical wins)" % [
					resource_type, resource_id, mod_id, existing_mod_id, new_priority
				])

	# Register the resource (overrides any existing resource with same ID)
	_resources_by_type[resource_type][resource_id] = resource
	_resource_sources[resource_id] = mod_id

	# Track mod's resources
	if mod_id not in _mod_resources:
		_mod_resources[mod_id] = []
	var mod_resource_list: Array = _mod_resources[mod_id]
	if resource_id not in mod_resource_list:
		mod_resource_list.append(resource_id)


## Get a mod's priority (helper for conflict detection)
## Returns 0 if mod not found
func _get_mod_priority(mod_id: String) -> int:
	if Engine.has_singleton("ModLoader"):
		return 0  # Can't access priority from singleton
	# Try to get ModLoader from autoloads
	var mod_loader: Node = null
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var scene_tree: SceneTree = main_loop as SceneTree
		mod_loader = scene_tree.root.get_node_or_null("/root/ModLoader")
	if mod_loader and mod_loader.has_method("get_mod"):
		var manifest: ModManifest = mod_loader.get_mod(mod_id) as ModManifest
		if manifest:
			return manifest.load_priority
	return 0


## Get a specific resource by type and ID
func get_resource(resource_type: String, resource_id: String) -> Resource:
	if resource_type not in _resources_by_type:
		return null
	var type_dict: Dictionary = _resources_by_type[resource_type]
	var res_val: Variant = type_dict.get(resource_id, null)
	return res_val if res_val is Resource else null


## Get all resources of a specific type
func get_all_resources(resource_type: String) -> Array[Resource]:
	var result: Array[Resource] = []
	if resource_type in _resources_by_type:
		var type_dict: Dictionary = _resources_by_type[resource_type]
		for resource: Resource in type_dict.values():
			result.append(resource)
	return result


## Get a character by their unique ID (character_uid)
## Returns null if no character with that UID exists
func get_character_by_uid(uid: String) -> CharacterData:
	if uid.is_empty():
		return null

	if "character" not in _resources_by_type:
		return null

	var character_dict: Dictionary = _resources_by_type["character"]
	for character: Resource in character_dict.values():
		var char_data: CharacterData = character as CharacterData
		if char_data and char_data.character_uid == uid:
			return char_data

	return null


## Get a character's display name by their UID
## Returns empty string if character not found
func get_character_name_by_uid(uid: String) -> String:
	var character: CharacterData = get_character_by_uid(uid)
	if character:
		return character.character_name
	return ""


## Get an NPC by their npc_id
## Returns null if no NPC with that ID exists
func get_npc_by_id(npc_id: String) -> NPCData:
	if npc_id.is_empty():
		return null

	if "npc" not in _resources_by_type:
		return null

	var npc_dict: Dictionary = _resources_by_type["npc"]
	for npc: Resource in npc_dict.values():
		var npc_data: NPCData = npc as NPCData
		if npc_data and npc_data.npc_id == npc_id:
			return npc_data

	return null


## Get the hero character (primary protagonist)
## Returns null if no hero exists or if multiple heroes exist (with warning)
func get_hero_character() -> CharacterData:
	if "character" not in _resources_by_type:
		return null

	var heroes: Array[CharacterData] = []
	var character_dict: Dictionary = _resources_by_type["character"]
	for character: Resource in character_dict.values():
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
		var type_dict: Dictionary = _resources_by_type[resource_type]
		for resource_id: String in type_dict.keys():
			result.append(resource_id)
	return result


## Get the mod ID that provided a specific resource
func get_resource_source(resource_id: String) -> String:
	return _resource_sources.get(resource_id, "")


## Get all resources provided by a specific mod
func get_mod_resources(mod_id: String) -> Array[String]:
	var mod_res_val: Variant = _mod_resources.get(mod_id, [])
	var mod_res: Array = mod_res_val if mod_res_val is Array else []
	var result: Array[String] = []
	for res_id: Variant in mod_res:
		if res_id is String:
			result.append(res_id)
	return result


## Get all registered resource types
func get_resource_types() -> Array[String]:
	var result: Array[String] = []
	for type_name: String in _resources_by_type.keys():
		result.append(type_name)
	return result


## Get count of resources of a specific type
func get_resource_count(resource_type: String) -> int:
	if resource_type not in _resources_by_type:
		return 0
	var type_dict: Dictionary = _resources_by_type[resource_type]
	return type_dict.size()


## Get total count of all resources
func get_total_resource_count() -> int:
	var count: int = 0
	for type_dict: Dictionary in _resources_by_type.values():
		count += type_dict.size()
	return count


## Check if a resource exists
func has_resource(resource_type: String, resource_id: String) -> bool:
	if resource_type not in _resources_by_type:
		return false
	var type_dict: Dictionary = _resources_by_type[resource_type]
	return resource_id in type_dict


## Clear all registered resources and scenes
func clear() -> void:
	_resources_by_type.clear()
	_resource_sources.clear()
	_mod_resources.clear()
	_scenes.clear()
	_scene_sources.clear()
	_override_chains.clear()


## Get the override chain for a resource (for debugging/editor display)
## Returns array of {mod_id, priority} entries showing previous providers
func get_override_chain(resource_type: String, resource_id: String) -> Array:
	var composite_id: String = "%s:%s" % [resource_type, resource_id]
	var chain_val: Variant = _override_chains.get(composite_id, [])
	var chain: Array = chain_val if chain_val is Array else []
	return chain.duplicate()


## Clear all resources from a specific mod
func clear_mod_resources(mod_id: String) -> void:
	if mod_id not in _mod_resources:
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


## Unregister a single resource by type and ID
## Used by the editor when deleting resources
func unregister_resource(resource_type: String, resource_id: String) -> void:
	# Remove from type dictionary
	if resource_type in _resources_by_type:
		var type_dict: Dictionary = _resources_by_type[resource_type]
		type_dict.erase(resource_id)

	# Get the mod that owned this resource before removing from sources
	var mod_id: String = _resource_sources.get(resource_id, "")

	# Remove from source tracking
	_resource_sources.erase(resource_id)

	# Remove from mod resources tracking
	if mod_id != "" and mod_id in _mod_resources:
		var mod_res: Array = _mod_resources[mod_id]
		var idx: int = mod_res.find(resource_id)
		if idx >= 0:
			mod_res.remove_at(idx)


# =============================================================================
# Scene Registration (for moddable scenes like opening cinematic, main menu)
# =============================================================================

## Register a scene path from a mod
## scene_id: Unique identifier (e.g., "opening_cinematic", "main_menu")
## scene_path: Full path to the scene file
## mod_id: ID of the mod providing this scene
func register_scene(scene_id: String, scene_path: String, mod_id: String) -> void:
	if scene_id.is_empty():
		push_error("ModRegistry: Cannot register scene with empty scene_id")
		return

	if scene_path.is_empty():
		push_error("ModRegistry: Cannot register scene '%s' with empty path" % scene_id)
		return

	# Register scene (overrides any existing scene with same ID)
	_scenes[scene_id] = scene_path
	_scene_sources[scene_id] = mod_id


## Get the scene path for a given scene ID
## Returns empty string if scene is not registered
func get_scene_path(scene_id: String) -> String:
	return _scenes.get(scene_id, "")


## Check if a scene is registered
func has_scene(scene_id: String) -> bool:
	return scene_id in _scenes


## Get the mod ID that provided a specific scene
func get_scene_source(scene_id: String) -> String:
	return _scene_sources.get(scene_id, "")


## Get all registered scene IDs
func get_scene_ids() -> Array[String]:
	var result: Array[String] = []
	for scene_id: String in _scenes.keys():
		result.append(scene_id)
	return result


## Get count of registered scenes
func get_scene_count() -> int:
	return _scenes.size()


## Get statistics about loaded resources
func get_statistics() -> Dictionary:
	var stats: Dictionary = {}
	stats.total_resources = get_total_resource_count()
	stats.resource_types = get_resource_types()
	stats.type_counts = {}
	for resource_type: String in stats.resource_types:
		stats.type_counts[resource_type] = get_resource_count(resource_type)
	stats.loaded_mods = _mod_resources.keys()
	stats.scene_count = get_scene_count()
	stats.scene_ids = get_scene_ids()
	return stats


## Get debug string about the registry (for debugging)
func get_debug_string() -> String:
	var output: String = "=== ModRegistry Debug ===\n"
	output += "Total resources: %d\n" % get_total_resource_count()
	output += "Resource types: %s\n" % str(get_resource_types())
	for resource_type: String in get_resource_types():
		output += "  - %s: %d resources\n" % [resource_type, get_resource_count(resource_type)]
	output += "Registered scenes: %d\n" % get_scene_count()
	for scene_id: String in get_scene_ids():
		output += "  - %s -> %s\n" % [scene_id, _scenes[scene_id]]
	output += "Loaded mods: %s\n" % str(_mod_resources.keys())
	output += "========================"
	return output
