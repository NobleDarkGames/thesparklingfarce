@tool
extends RefCounted
class_name ModRegistry

## Central registry for all loaded mod resources
## Tracks resources by type and provides lookup functions
## Handles resource overrides (later mods override earlier ones)

# Constants
const DEFAULT_MOD_PRIORITY: int = 0

# Resource type string constants
const TYPE_CHARACTER: String = "character"
const TYPE_NPC: String = "npc"
const TYPE_SHOP: String = "shop"

# Dictionary structure: { "resource_type": { "resource_id": Resource } }
# Example: { "character": { "hero": CharacterData, "mage": CharacterData } }
var _resources_by_type: Dictionary = {}

# Dictionary structure: { "resource_type:resource_id": "mod_id" }
# Tracks which mod provided each resource (uses composite key to avoid collisions
# between resources of different types with the same ID, e.g., character "hero" vs item "hero")
var _resource_sources: Dictionary[String, String] = {}

# Dictionary structure: { "mod_id": Array[String] of composite_ids (type:id) }
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


## Create a composite key from resource type and ID
func _make_composite_id(resource_type: String, resource_id: String) -> String:
	return "%s:%s" % [resource_type, resource_id]


## Get the type dictionary for a resource type, or null if not exists
func _get_type_dict(resource_type: String) -> Variant:
	if resource_type not in _resources_by_type:
		return null
	return _resources_by_type[resource_type]


## Ensure type dictionary exists, creating if needed
func _ensure_type_dict(resource_type: String) -> Dictionary:
	if resource_type not in _resources_by_type:
		_resources_by_type[resource_type] = {}
	return _resources_by_type[resource_type]


## Find a resource by searching for a property value (linear search)
## Used for UID/ID lookups like get_character_by_uid, get_npc_by_id, get_shop_by_id
func _find_by_property(resource_type: String, property: String, value: Variant) -> Resource:
	if value == null or (value is String and value.is_empty()):
		return null
	var type_dict: Variant = _get_type_dict(resource_type)
	if type_dict == null:
		return null
	for resource: Resource in type_dict.values():
		if resource and resource.get(property) == value:
			return resource
	return null


## Register a resource from a mod
## Detects and warns about same-priority conflicts
func register_resource(resource: Resource, resource_type: String, resource_id: String, mod_id: String) -> void:
	if not resource:
		push_error("Attempted to register null resource: " + resource_id)
		return

	var type_resources: Dictionary = _ensure_type_dict(resource_type)
	var composite_id: String = _make_composite_id(resource_type, resource_id)

	# Check for conflicts and track override chain
	if resource_id in type_resources:
		_handle_resource_conflict(composite_id, resource_type, resource_id, mod_id)

	# Register the resource (overrides any existing resource with same ID)
	type_resources[resource_id] = resource
	_resource_sources[composite_id] = mod_id

	# Track mod's resources
	_track_mod_resource(mod_id, composite_id)


## Handle resource conflict detection and override chain tracking
func _handle_resource_conflict(composite_id: String, resource_type: String, resource_id: String, mod_id: String) -> void:
	var existing_mod_id: String = _resource_sources.get(composite_id, "")
	if existing_mod_id.is_empty() or existing_mod_id == mod_id:
		return

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


## Track a resource as belonging to a mod
func _track_mod_resource(mod_id: String, composite_id: String) -> void:
	if mod_id not in _mod_resources:
		_mod_resources[mod_id] = []
	var mod_resource_list: Array = _mod_resources[mod_id]
	if composite_id not in mod_resource_list:
		mod_resource_list.append(composite_id)


## Get a mod's priority (helper for conflict detection)
## Returns DEFAULT_MOD_PRIORITY if mod not found
func _get_mod_priority(mod_id: String) -> int:
	var mod_loader: Node = _get_mod_loader()
	if mod_loader and mod_loader.has_method("get_mod"):
		var manifest: ModManifest = mod_loader.get_mod(mod_id) as ModManifest
		if manifest:
			return manifest.load_priority
	return DEFAULT_MOD_PRIORITY


## Get the ModLoader autoload if available
func _get_mod_loader() -> Node:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var scene_tree: SceneTree = main_loop as SceneTree
		return scene_tree.root.get_node_or_null("/root/ModLoader")
	return null


## Get a specific resource by type and ID
func get_resource(resource_type: String, resource_id: String) -> Resource:
	var type_dict: Variant = _get_type_dict(resource_type)
	if type_dict == null:
		return null
	var res_val: Variant = type_dict.get(resource_id, null)
	return res_val if res_val is Resource else null


## Get all resources of a specific type
func get_all_resources(resource_type: String) -> Array[Resource]:
	var result: Array[Resource] = []
	var type_dict: Variant = _get_type_dict(resource_type)
	if type_dict != null:
		for resource: Resource in type_dict.values():
			if resource:
				result.append(resource)
	return result


## Get a character by their unique ID (character_uid)
## Returns null if no character with that UID exists
func get_character_by_uid(uid: String) -> CharacterData:
	var r: Resource = _find_by_property(TYPE_CHARACTER, "character_uid", uid)
	return r if r is CharacterData else null


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
	var r: Resource = _find_by_property(TYPE_NPC, "npc_id", npc_id)
	return r if r is NPCData else null


## Get the hero character (primary protagonist)
## Returns null if no hero exists or if multiple heroes exist (with warning)
func get_hero_character() -> CharacterData:
	var character_dict: Variant = _get_type_dict(TYPE_CHARACTER)
	if character_dict == null:
		return null

	var heroes: Array[CharacterData] = []
	for character: CharacterData in character_dict.values():
		if character and character.is_hero:
			heroes.append(character)

	if heroes.is_empty():
		return null

	if heroes.size() > 1:
		push_warning("ModRegistry: Multiple heroes detected! Only one hero should exist. Using first found.")
		for hero: CharacterData in heroes:
			var source_mod: String = get_resource_source(hero.resource_path.get_file().get_basename(), TYPE_CHARACTER)
			push_warning("  - Hero '%s' from mod '%s'" % [hero.character_name, source_mod])

	return heroes[0]


## Get all resource IDs of a specific type
func get_resource_ids(resource_type: String) -> Array[String]:
	var result: Array[String] = []
	var type_dict: Variant = _get_type_dict(resource_type)
	if type_dict != null:
		for resource_id: String in type_dict.keys():
			result.append(resource_id)
	return result


## Get the mod ID that provided a specific resource
## If resource_type is provided, uses the composite key for accurate lookup
## If resource_type is empty, attempts a simple lookup (for backwards compatibility,
## but may return wrong result if multiple types have same resource_id)
func get_resource_source(resource_id: String, resource_type: String = "") -> String:
	if resource_type.is_empty():
		# Backwards-compatible: search all composite keys for this resource_id
		# This may return the wrong mod if multiple types have same ID
		for composite_key: String in _resource_sources.keys():
			if composite_key.ends_with(":" + resource_id):
				return _resource_sources[composite_key]
		return ""
	var composite_id: String = _make_composite_id(resource_type, resource_id)
	return _resource_sources.get(composite_id, "")


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
	var type_dict: Variant = _get_type_dict(resource_type)
	if type_dict == null:
		return 0
	return type_dict.size()


## Get total count of all resources
func get_total_resource_count() -> int:
	var count: int = 0
	for type_dict: Dictionary in _resources_by_type.values():
		count += type_dict.size()
	return count


## Check if a resource exists
func has_resource(resource_type: String, resource_id: String) -> bool:
	var type_dict: Variant = _get_type_dict(resource_type)
	if type_dict == null:
		return false
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
	var composite_id: String = _make_composite_id(resource_type, resource_id)
	var chain_val: Variant = _override_chains.get(composite_id, [])
	var chain: Array = chain_val if chain_val is Array else []
	return chain.duplicate()


## Clear all resources from a specific mod
func clear_mod_resources(mod_id: String) -> void:
	if mod_id not in _mod_resources:
		return

	# Remove each resource registered by this mod
	for composite_id: String in _mod_resources[mod_id]:
		_remove_resource_by_composite_id(composite_id)

	_mod_resources.erase(mod_id)


## Remove a resource from the registry by its composite ID
func _remove_resource_by_composite_id(composite_id: String) -> void:
	var parts: PackedStringArray = composite_id.split(":", true, 1)
	if parts.size() == 2:
		var res_type: String = parts[0]
		var res_id: String = parts[1]
		var type_dict: Variant = _get_type_dict(res_type)
		if type_dict != null:
			type_dict.erase(res_id)
	_resource_sources.erase(composite_id)


## Unregister a single resource by type and ID
## Used by the editor when deleting resources
func unregister_resource(resource_type: String, resource_id: String) -> void:
	var composite_id: String = _make_composite_id(resource_type, resource_id)

	# Get the mod that owned this resource before removing from sources
	var mod_id: String = _resource_sources.get(composite_id, "")

	# Remove from type dictionary and sources
	_remove_resource_by_composite_id(composite_id)

	# Remove from mod resources tracking
	if not mod_id.is_empty() and mod_id in _mod_resources:
		var mod_res: Array = _mod_resources[mod_id]
		var idx: int = mod_res.find(composite_id)
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


# =============================================================================
# TYPE-SAFE GETTERS
# =============================================================================
# These methods provide type-safe access to resources without requiring casts.
# Use these instead of get_resource() + as SomeType to avoid UNSAFE_CAST warnings.

## Get an item by ID (type-safe)
func get_item(item_id: String) -> ItemData:
	var r: Resource = get_resource("item", item_id)
	return r if r is ItemData else null


## Get a character by ID (type-safe)
func get_character(character_id: String) -> CharacterData:
	var r: Resource = get_resource("character", character_id)
	return r if r is CharacterData else null


## Get an ability by ID (type-safe)
func get_ability(ability_id: String) -> AbilityData:
	var r: Resource = get_resource("ability", ability_id)
	return r if r is AbilityData else null


## Get a class by ID (type-safe)
## Note: Named get_class_data to avoid conflict with Object.get_class()
func get_class_data(class_id: String) -> ClassData:
	var r: Resource = get_resource("class", class_id)
	return r if r is ClassData else null


## Get a dialogue by ID (type-safe)
func get_dialogue(dialogue_id: String) -> DialogueData:
	var r: Resource = get_resource("dialogue", dialogue_id)
	return r if r is DialogueData else null


## Get a battle by ID (type-safe)
func get_battle(battle_id: String) -> BattleData:
	var r: Resource = get_resource("battle", battle_id)
	return r if r is BattleData else null


## Get a cinematic by ID (type-safe)
func get_cinematic(cinematic_id: String) -> CinematicData:
	var r: Resource = get_resource("cinematic", cinematic_id)
	return r if r is CinematicData else null


## Get a shop by ID (type-safe)
func get_shop(shop_id: String) -> ShopData:
	var r: Resource = get_resource("shop", shop_id)
	return r if r is ShopData else null


## Get a shop by their shop_id property (semantic lookup)
## This does a linear search through all shops to find one with matching shop_id
## Returns null if no shop with that ID exists
func get_shop_by_id(shop_id: String) -> ShopData:
	var r: Resource = _find_by_property(TYPE_SHOP, "shop_id", shop_id)
	return r if r is ShopData else null


## Get a crafter by ID (type-safe)
func get_crafter(crafter_id: String) -> CrafterData:
	var r: Resource = get_resource("crafter", crafter_id)
	return r if r is CrafterData else null


## Get a crafting recipe by ID (type-safe)
func get_crafting_recipe(recipe_id: String) -> CraftingRecipeData:
	var r: Resource = get_resource("crafting_recipe", recipe_id)
	return r if r is CraftingRecipeData else null


## Get an interactable by ID (type-safe)
func get_interactable(interactable_id: String) -> InteractableData:
	var r: Resource = get_resource("interactable", interactable_id)
	return r if r is InteractableData else null


## Get an NPC by resource ID (type-safe) - different from get_npc_by_id which uses npc_id field
func get_npc(npc_resource_id: String) -> NPCData:
	var r: Resource = get_resource("npc", npc_resource_id)
	return r if r is NPCData else null


## Get a status effect by ID (type-safe)
func get_status_effect(effect_id: String) -> StatusEffectData:
	var r: Resource = get_resource("status_effect", effect_id)
	return r if r is StatusEffectData else null


## Get a terrain by ID (type-safe)
func get_terrain(terrain_id: String) -> TerrainData:
	var r: Resource = get_resource("terrain", terrain_id)
	return r if r is TerrainData else null


## Get an AI behavior by ID (type-safe)
func get_ai_behavior(behavior_id: String) -> AIBehaviorData:
	var r: Resource = get_resource("ai_behavior", behavior_id)
	return r if r is AIBehaviorData else null


## Get a map metadata by ID (type-safe)
func get_map(map_id: String) -> MapMetadata:
	var r: Resource = get_resource("map", map_id)
	return r if r is MapMetadata else null


## Get a new game config by ID (type-safe)
func get_new_game_config(config_id: String) -> NewGameConfigData:
	var r: Resource = get_resource("new_game_config", config_id)
	return r if r is NewGameConfigData else null


## Get a party by ID (type-safe)
func get_party(party_id: String) -> PartyData:
	var r: Resource = get_resource("party", party_id)
	return r if r is PartyData else null
