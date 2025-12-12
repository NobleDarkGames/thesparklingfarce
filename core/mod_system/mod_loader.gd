@tool
extends Node

## ModLoader - Autoload singleton for managing game mods
## Discovers mods in mods/ directory, loads them in priority order,
## and populates the ModRegistry with all resources
##
## Mod Load Priority Strategy (0-9999):
##   0-99:      Official game content from core development team
##   100-8999:  User mods
##   9000-9999: High priority and total conversion mods
##
## When multiple mods share the same priority, they load in alphabetical
## order by mod_id to ensure consistent cross-platform behavior.

const MODS_DIRECTORY: String = "res://mods/"

# Resource type mappings: file path pattern -> resource type name
const RESOURCE_TYPE_DIRS: Dictionary = {
	"characters": "character",
	"classes": "class",
	"items": "item",
	"abilities": "ability",
	"dialogues": "dialogue",
	"cinematics": "cinematic",
	"parties": "party",
	"battles": "battle",
	"campaigns": "campaign",
	"maps": "map",  # MapMetadata resources for exploration maps
	"terrain": "terrain",  # TerrainData resources for battle terrain effects
	"experience_configs": "experience_config",  # ExperienceConfig resources for XP/leveling settings
	"caravans": "caravan",  # CaravanData resources for mobile HQ configuration
	"npcs": "npc",  # NPCData resources for interactable NPCs
	"shops": "shop",  # ShopData resources for weapon/item shops, churches, crafters
	"new_game_configs": "new_game_config",  # NewGameConfigData resources for starting game state
	"ai_behaviors": "ai_behavior"  # AIBehaviorData resources for configurable enemy AI
}

# Resource types that support JSON loading (in addition to .tres)
const JSON_SUPPORTED_TYPES: Array[String] = ["cinematic", "campaign", "map"]

# Preload loaders for JSON resources
const CinematicLoader: GDScript = preload("res://core/systems/cinematic_loader.gd")
const CampaignLoader: GDScript = preload("res://core/systems/campaign_loader.gd")
const MapMetadataLoader: GDScript = preload("res://core/systems/map_metadata_loader.gd")

# Preload resource classes needed before class_name is available
const NewGameConfigDataClass: GDScript = preload("res://core/resources/new_game_config_data.gd")

# Preload type registry classes
const EquipmentRegistryClass: GDScript = preload("res://core/registries/equipment_registry.gd")
const EnvironmentRegistryClass: GDScript = preload("res://core/registries/environment_registry.gd")
const UnitCategoryRegistryClass: GDScript = preload("res://core/registries/unit_category_registry.gd")
const AnimationOffsetRegistryClass: GDScript = preload("res://core/registries/animation_offset_registry.gd")
const TriggerTypeRegistryClass: GDScript = preload("res://core/registries/trigger_type_registry.gd")
const TerrainRegistryClass: GDScript = preload("res://core/registries/terrain_registry.gd")
const EquipmentSlotRegistryClass: GDScript = preload("res://core/registries/equipment_slot_registry.gd")
const EquipmentTypeRegistryClass: GDScript = preload("res://core/registries/equipment_type_registry.gd")
const InventoryConfigClass: GDScript = preload("res://core/systems/inventory_config.gd")
const AIBrainRegistryClass: GDScript = preload("res://core/registries/ai_brain_registry.gd")
const TilesetRegistryClass: GDScript = preload("res://core/registries/tileset_registry.gd")
const AIRoleRegistryClass: GDScript = preload("res://core/registries/ai_role_registry.gd")
const AIModeRegistryClass: GDScript = preload("res://core/registries/ai_mode_registry.gd")

## Signal emitted when all mods have finished loading
signal mods_loaded()

## Signal emitted when the active mod changes (for systems like AudioManager)
## @param mod_path: Full path to the mod directory (e.g., "res://mods/_base_game")
signal active_mod_changed(mod_path: String)

var registry: ModRegistry = ModRegistry.new()
var loaded_mods: Array[ModManifest] = []
var active_mod_id: String = "_base_game"  # Default active mod

# Type registries for mod-extensible enums
var equipment_registry: RefCounted = EquipmentRegistryClass.new()
var environment_registry: RefCounted = EnvironmentRegistryClass.new()
var unit_category_registry: RefCounted = UnitCategoryRegistryClass.new()
var animation_offset_registry: RefCounted = AnimationOffsetRegistryClass.new()
var trigger_type_registry: RefCounted = TriggerTypeRegistryClass.new()
var terrain_registry: RefCounted = TerrainRegistryClass.new()

# Equipment system configuration (data-driven slots and inventory)
var equipment_slot_registry: RefCounted = EquipmentSlotRegistryClass.new()
var equipment_type_registry: RefCounted = EquipmentTypeRegistryClass.new()
var inventory_config: RefCounted = InventoryConfigClass.new()

# AI brain registry (declared in mod.json with metadata)
var ai_brain_registry: RefCounted = AIBrainRegistryClass.new()

# Tileset registry (declared in mod.json with metadata, also auto-discovered)
var tileset_registry: RefCounted = TilesetRegistryClass.new()

# AI role and mode registries (for configurable AI behaviors)
var ai_role_registry: RefCounted = AIRoleRegistryClass.new()
var ai_mode_registry: RefCounted = AIModeRegistryClass.new()

# Legacy tileset registry for backwards compatibility
# TODO: Migrate to tileset_registry and remove this
var _tileset_registry: Dictionary = {}

## Loading state tracking
var _is_loading: bool = false


func _ready() -> void:
	# Initial load is SYNCHRONOUS to ensure all resources are available
	# before any scenes try to use them. Use reload_mods_async() for
	# runtime hot-reloading if needed.
	_discover_and_load_mods()

	# Safety net: validate active_mod_id exists, fall back to first loaded mod if not
	if not loaded_mods.is_empty() and not get_mod(active_mod_id):
		var fallback_mod: ModManifest = loaded_mods[0]
		push_warning("ModLoader: Default active mod '%s' not found, falling back to '%s'" % [active_mod_id, fallback_mod.mod_id])
		active_mod_id = fallback_mod.mod_id

	mods_loaded.emit()
	# Notify listeners (like AudioManager) of the active mod path
	_emit_active_mod_changed()


## Discover all mods and load them in priority order (sync version for editor/reload)
func _discover_and_load_mods() -> void:
	var discovered_mods: Array[ModManifest] = _discover_mods()
	if discovered_mods.is_empty():
		push_warning("ModLoader: No mods found in " + MODS_DIRECTORY)
		return

	# Check for circular dependencies before proceeding
	var resolved_mods: Array[ModManifest] = _topological_sort_with_cycle_detection(discovered_mods)
	if resolved_mods.is_empty() and not discovered_mods.is_empty():
		push_error("ModLoader: Cannot proceed due to circular dependencies - no mods loaded")
		return

	# Sort by load priority (lower priority loads first, can be overridden by higher)
	resolved_mods.sort_custom(_sort_by_priority)

	# Load each mod
	for manifest in resolved_mods:
		_load_mod(manifest)


## Discover all mods and load them asynchronously (for game startup)
func _discover_and_load_mods_async() -> void:
	_is_loading = true
	var discovered_mods: Array[ModManifest] = _discover_mods()
	if discovered_mods.is_empty():
		push_warning("ModLoader: No mods found in " + MODS_DIRECTORY)
		_is_loading = false
		return

	# Check for circular dependencies before proceeding
	var resolved_mods: Array[ModManifest] = _topological_sort_with_cycle_detection(discovered_mods)
	if resolved_mods.is_empty() and not discovered_mods.is_empty():
		push_error("ModLoader: Cannot proceed due to circular dependencies - no mods loaded")
		_is_loading = false
		return

	# Sort by load priority (lower priority loads first, can be overridden by higher)
	resolved_mods.sort_custom(_sort_by_priority)

	# Load each mod asynchronously
	for manifest in resolved_mods:
		await _load_mod_async(manifest)

	_is_loading = false


## Discover all mods in the mods/ directory
func _discover_mods() -> Array[ModManifest]:
	var mods: Array[ModManifest] = []

	var dir: DirAccess = DirAccess.open(MODS_DIRECTORY)
	if not dir:
		push_error("ModLoader: Failed to open mods directory: " + MODS_DIRECTORY)
		return mods

	dir.list_dir_begin()
	var folder_name: String = dir.get_next()

	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with("."):
			var mod_json_path: String = MODS_DIRECTORY.path_join(folder_name).path_join("mod.json")

			# Check if mod.json exists
			if FileAccess.file_exists(mod_json_path):
				var manifest: ModManifest = ModManifest.load_from_file(mod_json_path)
				if manifest:
					mods.append(manifest)
				else:
					push_warning("ModLoader: Failed to load manifest for mod in folder: " + folder_name)

		folder_name = dir.get_next()

	dir.list_dir_end()
	return mods


## Load a single mod and register all its resources
func _load_mod(manifest: ModManifest) -> void:
	# Check dependencies (simple check - just verify they're loaded)
	for dep_id in manifest.dependencies:
		if not _is_mod_loaded(dep_id):
			push_error("ModLoader: Mod '%s' requires dependency '%s' which is not loaded" % [manifest.mod_id, dep_id])
			return

	# Register custom type definitions from manifest
	_register_mod_type_definitions(manifest)

	# Load resources from data directory
	var data_dir: String = manifest.get_data_directory()
	var loaded_count: int = 0

	for dir_name: String in RESOURCE_TYPE_DIRS.keys():
		var resource_type: String = RESOURCE_TYPE_DIRS[dir_name]
		var type_dir: String = data_dir.path_join(dir_name)
		loaded_count += _load_resources_from_directory(type_dir, resource_type, manifest.mod_id)

	# Register scenes from manifest
	var scene_count: int = _register_mod_scenes(manifest)

	# Discover and register trigger scripts and tilesets
	_discover_trigger_scripts(manifest)
	_discover_tilesets(manifest)

	# Mark mod as loaded
	manifest.is_loaded = true
	loaded_mods.append(manifest)


## Load a single mod asynchronously using threaded resource loading
func _load_mod_async(manifest: ModManifest) -> void:
	# Check dependencies (simple check - just verify they're loaded)
	for dep_id in manifest.dependencies:
		if not _is_mod_loaded(dep_id):
			push_error("ModLoader: Mod '%s' requires dependency '%s' which is not loaded" % [manifest.mod_id, dep_id])
			return

	# Collect all resource paths from data directory
	var data_dir: String = manifest.get_data_directory()
	var resource_requests: Array[Dictionary] = []

	for dir_name: String in RESOURCE_TYPE_DIRS.keys():
		var resource_type: String = RESOURCE_TYPE_DIRS[dir_name]
		var type_dir: String = data_dir.path_join(dir_name)
		var requests: Array[Dictionary] = _collect_resource_paths(type_dir, resource_type, manifest.mod_id)
		resource_requests.append_array(requests)

	# Request all .tres resources to load in background threads
	var tres_paths: Array[String] = []
	for req in resource_requests:
		if req.path.ends_with(".tres"):
			ResourceLoader.load_threaded_request(req.path, "", true)  # true = use_sub_threads
			tres_paths.append(req.path)

	# Wait for all threaded loads to complete (polling with yield to not block)
	if not tres_paths.is_empty():
		await _wait_for_threaded_loads(tres_paths)

	# Now retrieve and register all resources
	var loaded_count: int = 0
	for req in resource_requests:
		var resource: Resource = null

		if req.path.ends_with(".tres"):
			# Get the threaded-loaded resource
			resource = ResourceLoader.load_threaded_get(req.path)
		elif req.path.ends_with(".json"):
			# JSON resources are loaded synchronously (they're small text files)
			resource = _load_json_resource(req.path, req.resource_type)

		if resource:
			registry.register_resource(resource, req.resource_type, req.resource_id, manifest.mod_id)
			# Special handling for terrain resources - also register with terrain_registry
			if req.resource_type == "terrain" and resource is TerrainData:
				terrain_registry.register_terrain(resource, manifest.mod_id)
			loaded_count += 1
		else:
			push_warning("ModLoader: Failed to load resource: " + req.path)

	# Register scenes from manifest
	var scene_count: int = _register_mod_scenes(manifest)

	# Discover and register trigger scripts and tilesets
	_discover_trigger_scripts(manifest)
	_discover_tilesets(manifest)

	# Mark mod as loaded
	manifest.is_loaded = true
	loaded_mods.append(manifest)


## Collect all resource file paths from a directory (without loading them)
func _collect_resource_paths(directory: String, resource_type: String, mod_id: String) -> Array[Dictionary]:
	var requests: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open(directory)

	if not dir:
		return requests

	var supports_json: bool = resource_type in JSON_SUPPORTED_TYPES

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir():
			var full_path: String = directory.path_join(file_name)

			if file_name.ends_with(".tres"):
				requests.append({
					"path": full_path,
					"resource_type": resource_type,
					"resource_id": file_name.get_basename(),
					"mod_id": mod_id
				})
			elif file_name.ends_with(".json") and supports_json:
				requests.append({
					"path": full_path,
					"resource_type": resource_type,
					"resource_id": file_name.get_basename(),
					"mod_id": mod_id
				})

		file_name = dir.get_next()

	dir.list_dir_end()
	return requests


## Wait for all threaded resource loads to complete
func _wait_for_threaded_loads(paths: Array[String]) -> void:
	var pending: Array[String] = paths.duplicate()

	while not pending.is_empty():
		var still_pending: Array[String] = []

		for path in pending:
			var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
			match status:
				ResourceLoader.THREAD_LOAD_LOADED:
					pass  # Done, don't add to still_pending
				ResourceLoader.THREAD_LOAD_IN_PROGRESS:
					still_pending.append(path)
				ResourceLoader.THREAD_LOAD_FAILED:
					push_warning("ModLoader: Failed to load resource: " + path)
				ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
					push_warning("ModLoader: Invalid resource: " + path)

		pending = still_pending

		# Yield to allow other processing (don't block the main thread)
		if not pending.is_empty():
			await get_tree().process_frame


## Load all .tres and .json resources from a directory
func _load_resources_from_directory(directory: String, resource_type: String, mod_id: String) -> int:
	var count: int = 0
	var dir: DirAccess = DirAccess.open(directory)

	if not dir:
		# Directory might not exist in this mod (that's okay)
		return 0

	var supports_json: bool = resource_type in JSON_SUPPORTED_TYPES

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir():
			var full_path: String = directory.path_join(file_name)
			var resource: Resource = null
			var resource_id: String = ""

			if file_name.ends_with(".tres"):
				# Standard Godot resource
				resource = load(full_path)
				resource_id = file_name.get_basename()

			elif file_name.ends_with(".json") and supports_json:
				# JSON resource (currently only cinematics)
				resource = _load_json_resource(full_path, resource_type)
				resource_id = file_name.get_basename()

			if resource:
				registry.register_resource(resource, resource_type, resource_id, mod_id)
				# Special handling for terrain resources - also register with terrain_registry
				if resource_type == "terrain" and resource is TerrainData:
					terrain_registry.register_terrain(resource, mod_id)
				count += 1
			elif not resource_id.is_empty():
				push_warning("ModLoader: Failed to load resource: " + full_path)

		file_name = dir.get_next()

	dir.list_dir_end()
	return count


## Load a resource from a JSON file based on resource type
func _load_json_resource(json_path: String, resource_type: String) -> Resource:
	match resource_type:
		"cinematic":
			return CinematicLoader.load_from_json(json_path)
		"campaign":
			return CampaignLoader.load_from_json(json_path)
		"map":
			return MapMetadataLoader.load_from_json(json_path)
		_:
			push_warning("ModLoader: JSON loading not supported for resource type: " + resource_type)
			return null


## Register custom type definitions from a mod manifest
## This populates the type registries with mod-defined extensions
func _register_mod_type_definitions(manifest: ModManifest) -> void:
	# Equipment types
	if not manifest.custom_weapon_types.is_empty():
		equipment_registry.register_weapon_types(manifest.mod_id, manifest.custom_weapon_types)
	if not manifest.custom_armor_types.is_empty():
		equipment_registry.register_armor_types(manifest.mod_id, manifest.custom_armor_types)

	# Environment types
	if not manifest.custom_weather_types.is_empty():
		environment_registry.register_weather_types(manifest.mod_id, manifest.custom_weather_types)
	if not manifest.custom_time_of_day.is_empty():
		environment_registry.register_time_of_day(manifest.mod_id, manifest.custom_time_of_day)

	# Unit categories
	if not manifest.custom_unit_categories.is_empty():
		unit_category_registry.register_categories(manifest.mod_id, manifest.custom_unit_categories)

	# Animation offset types
	if not manifest.custom_animation_offset_types.is_empty():
		animation_offset_registry.register_offset_types(manifest.mod_id, manifest.custom_animation_offset_types)

	# Trigger types
	if not manifest.custom_trigger_types.is_empty():
		trigger_type_registry.register_trigger_types(manifest.mod_id, manifest.custom_trigger_types)

	# Equipment slot layout (higher priority mods completely replace the layout)
	if not manifest.equipment_slot_layout.is_empty():
		equipment_slot_registry.register_slot_layout(manifest.mod_id, manifest.equipment_slot_layout)

	# Equipment type mappings (subtype -> category for slot matching)
	if not manifest.equipment_type_config.is_empty():
		equipment_type_registry.register_from_config(manifest.mod_id, manifest.equipment_type_config)

	# Inventory configuration (higher priority mods completely replace the config)
	if not manifest.inventory_config.is_empty():
		inventory_config.load_from_manifest(manifest.mod_id, manifest.inventory_config)

	# AI brain declarations (from mod.json)
	if not manifest.ai_brains.is_empty():
		ai_brain_registry.register_from_config(manifest.mod_id, manifest.ai_brains, manifest.mod_directory)

	# Tileset declarations (from mod.json)
	if not manifest.tilesets.is_empty():
		tileset_registry.register_from_config(manifest.mod_id, manifest.tilesets, manifest.mod_directory)

	# AI role declarations (from mod.json)
	if not manifest.ai_roles.is_empty():
		ai_role_registry.register_from_config(manifest.mod_id, manifest.ai_roles, manifest.mod_directory)

	# AI mode declarations (from mod.json)
	if not manifest.ai_modes.is_empty():
		ai_mode_registry.register_from_config(manifest.mod_id, manifest.ai_modes)


## Register scenes from a mod manifest
func _register_mod_scenes(manifest: ModManifest) -> int:
	var count: int = 0

	for scene_id: String in manifest.scenes.keys():
		var relative_path: String = manifest.scenes[scene_id]
		var full_path: String = manifest.mod_directory.path_join(relative_path)

		# Verify scene file exists
		if not FileAccess.file_exists(full_path):
			push_warning("ModLoader: Scene '%s' not found at: %s" % [scene_id, full_path])
			continue

		registry.register_scene(scene_id, full_path, manifest.mod_id)
		count += 1

	return count


## Discover and register trigger scripts from a mod's triggers/ directory
## Trigger scripts should extend MapTrigger and define custom behavior
## File naming convention: {trigger_type}_trigger.gd (e.g., puzzle_trigger.gd)
func _discover_trigger_scripts(manifest: ModManifest) -> int:
	var triggers_dir: String = manifest.mod_directory.path_join("triggers")
	var dir: DirAccess = DirAccess.open(triggers_dir)

	if not dir:
		# No triggers directory - that's okay, not all mods have custom triggers
		return 0

	var count: int = 0
	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with("_trigger.gd"):
			var full_path: String = triggers_dir.path_join(file_name)
			# Extract trigger type from filename: puzzle_trigger.gd -> puzzle
			var trigger_type: String = file_name.replace("_trigger.gd", "").to_lower()

			if not trigger_type.is_empty():
				trigger_type_registry.register_trigger_script(trigger_type, full_path, manifest.mod_id)
				# Also register the trigger type if not already registered
				if not trigger_type_registry.is_valid_trigger_type(trigger_type):
					trigger_type_registry.register_trigger_types(manifest.mod_id, [trigger_type])
				count += 1

		file_name = dir.get_next()

	dir.list_dir_end()
	return count


## Discover and register tilesets from a mod's tilesets/ directory
## TileSets are registered by their filename (without extension) as the tileset name
## Higher-priority mods override lower-priority tilesets with the same name
func _discover_tilesets(manifest: ModManifest) -> int:
	# Use the new tileset registry for discovery (handles both declared and auto-discovered)
	var new_count: int = tileset_registry.discover_from_directory(manifest.mod_id, manifest.mod_directory)

	# Also discover AI brains from directory for backwards compatibility
	ai_brain_registry.discover_from_directory(manifest.mod_id, manifest.mod_directory)

	# Legacy registry support - keep in sync for backwards compatibility
	var tilesets_dir: String = manifest.mod_directory.path_join("tilesets")
	var dir: DirAccess = DirAccess.open(tilesets_dir)

	if not dir:
		# No tilesets directory - that's okay
		return new_count

	var count: int = 0
	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path: String = tilesets_dir.path_join(file_name)
			# Extract tileset name from filename: terrain_placeholder.tres -> terrain_placeholder
			var tileset_name: String = file_name.get_basename().to_lower()

			if not tileset_name.is_empty():
				# Register (or override) the tileset in legacy registry
				_tileset_registry[tileset_name] = {
					"path": full_path,
					"mod_id": manifest.mod_id,
					"resource": null  # Lazy-loaded on first access
				}
				count += 1

		file_name = dir.get_next()

	dir.list_dir_end()
	return count + new_count


## Get a TileSet resource by name
## Returns the highest-priority mod's version of the tileset
## @param tileset_name: The tileset name (e.g., "terrain_placeholder")
## @return: The TileSet resource, or null if not found
func get_tileset(tileset_name: String) -> TileSet:
	var name_lower: String = tileset_name.to_lower()

	if name_lower not in _tileset_registry:
		push_warning("ModLoader: TileSet '%s' not found in registry" % tileset_name)
		return null

	var entry: Dictionary = _tileset_registry[name_lower]

	# Lazy-load the resource on first access
	if entry.resource == null:
		entry.resource = load(entry.path) as TileSet
		if entry.resource == null:
			push_error("ModLoader: Failed to load TileSet from: %s" % entry.path)
			return null

	return entry.resource


## Get the path to a TileSet by name (without loading it)
## Useful for scene files that need the path at edit time
func get_tileset_path(tileset_name: String) -> String:
	var name_lower: String = tileset_name.to_lower()

	if name_lower not in _tileset_registry:
		return ""

	return _tileset_registry[name_lower].path


## Check if a tileset is registered
func has_tileset(tileset_name: String) -> bool:
	return tileset_name.to_lower() in _tileset_registry


## Get all registered tileset names
func get_tileset_names() -> Array[String]:
	var names: Array[String] = []
	for name: String in _tileset_registry.keys():
		names.append(name)
	return names


## Get which mod provides a tileset
func get_tileset_source(tileset_name: String) -> String:
	var name_lower: String = tileset_name.to_lower()

	if name_lower not in _tileset_registry:
		return ""

	return _tileset_registry[name_lower].mod_id


## Check if a mod with the given ID is loaded
func _is_mod_loaded(mod_id: String) -> bool:
	for manifest in loaded_mods:
		if manifest.mod_id == mod_id:
			return true
	return false


# =============================================================================
# Scene Override System (Phase 2.1)
# =============================================================================

## Get a scene by registry ID, with fallback to default path
## Used by systems like BattleManager to allow mods to override core scenes
##
## @param scene_id: The registered scene ID (e.g., "unit_scene", "combat_anim_scene")
## @param fallback_path: Default path if no mod provides this scene
## @return: Loaded PackedScene, or null if neither found
func get_scene_or_fallback(scene_id: String, fallback_path: String) -> PackedScene:
	# First check if a mod has registered this scene
	var mod_path: String = registry.get_scene_path(scene_id)
	if not mod_path.is_empty():
		if FileAccess.file_exists(mod_path):
			var scene: PackedScene = load(mod_path) as PackedScene
			if scene:
				return scene
			else:
				push_warning("ModLoader: Failed to load mod scene '%s' at: %s, using fallback" % [scene_id, mod_path])
		else:
			push_warning("ModLoader: Mod scene '%s' not found at: %s, using fallback" % [scene_id, mod_path])

	# Fallback to default path
	if not fallback_path.is_empty():
		if FileAccess.file_exists(fallback_path):
			var scene: PackedScene = load(fallback_path) as PackedScene
			if scene:
				return scene
			else:
				push_error("ModLoader: Failed to load fallback scene '%s' at: %s" % [scene_id, fallback_path])
		else:
			push_error("ModLoader: Fallback scene '%s' not found at: %s" % [scene_id, fallback_path])

	return null


# =============================================================================
# Asset Override System (Phase 2.2)
# =============================================================================

## Resolve an asset path through the mod override system
## Checks mods in descending priority order for a matching asset path
## Enables "drop-in replacement" workflow for casual artists
##
## @param relative_path: Path relative to mod's assets directory (e.g., "icons/items/sword.png")
## @param fallback_base_path: Base path to check if no mod provides the asset (e.g., "res://mods/_base_game/assets/")
## @return: The full resolved path, or empty string if not found
func resolve_asset_path(relative_path: String, fallback_base_path: String = "") -> String:
	# Security: Prevent path traversal attacks
	if ".." in relative_path:
		push_error("ModLoader: Invalid asset path (contains ..): %s" % relative_path)
		return ""

	if relative_path.begins_with("/") or relative_path.begins_with("\\"):
		push_error("ModLoader: Invalid asset path (absolute path not allowed): %s" % relative_path)
		return ""

	# Check mods in descending priority order (highest priority first)
	var mods: Array[ModManifest] = get_mods_by_priority_descending()
	for mod: ModManifest in mods:
		var full_path: String = mod.get_assets_directory().path_join(relative_path)
		if FileAccess.file_exists(full_path):
			return full_path

	# Fallback to base path
	if not fallback_base_path.is_empty():
		var fallback_full: String = fallback_base_path.path_join(relative_path)
		if FileAccess.file_exists(fallback_full):
			return fallback_full

	return ""


## Load a texture through the mod override system
## Convenience wrapper around resolve_asset_path for common use case
##
## @param relative_path: Path relative to mod's assets directory (e.g., "icons/items/sword.png")
## @return: The loaded Texture2D, or null if not found
func load_texture_override(relative_path: String) -> Texture2D:
	var path: String = resolve_asset_path(relative_path, "res://mods/_base_game/assets/")
	if path.is_empty():
		return null
	return load(path) as Texture2D


## Load a resource through the mod override system
## Generic version for any resource type
##
## @param relative_path: Path relative to mod's assets directory
## @return: The loaded Resource, or null if not found
func load_resource_override(relative_path: String) -> Resource:
	var path: String = resolve_asset_path(relative_path, "res://mods/_base_game/assets/")
	if path.is_empty():
		return null
	return load(path)


# =============================================================================
# Circular Dependency Detection
# =============================================================================

## Perform topological sort with cycle detection on mod dependencies
## Returns sorted mods in valid load order, or empty array if cycle detected
## Uses depth-first search with "visiting" markers to detect back edges (cycles)
func _topological_sort_with_cycle_detection(mods: Array[ModManifest]) -> Array[ModManifest]:
	var sorted: Array[ModManifest] = []
	var permanent_marks: Dictionary = {}  # mod_id -> true (fully processed)
	var temporary_marks: Dictionary = {}  # mod_id -> true (currently visiting - cycle detection)
	var mod_map: Dictionary = {}  # mod_id -> ModManifest for quick lookup

	# Build lookup map
	for mod: ModManifest in mods:
		mod_map[mod.mod_id] = mod

	# Visit each node using DFS
	for mod: ModManifest in mods:
		if mod.mod_id not in permanent_marks:
			var cycle_path: Array[String] = []
			if not _visit_mod_for_sort(mod, mod_map, permanent_marks, temporary_marks, sorted, cycle_path):
				# Cycle detected - error already logged
				return []

	return sorted


## DFS visit function for topological sort
## Returns false if cycle detected, true otherwise
func _visit_mod_for_sort(
	mod: ModManifest,
	mod_map: Dictionary,
	permanent: Dictionary,
	temporary: Dictionary,
	sorted: Array[ModManifest],
	path: Array[String]
) -> bool:
	var mod_id: String = mod.mod_id

	# Already fully processed
	if mod_id in permanent:
		return true

	# Currently visiting this node - we've found a cycle!
	if mod_id in temporary:
		_emit_cycle_error(mod_id, path)
		return false

	# Mark as currently visiting and track in path
	temporary[mod_id] = true
	path.append(mod_id)

	# Visit all dependencies first
	for dep_id: String in mod.dependencies:
		if dep_id in mod_map:
			if not _visit_mod_for_sort(mod_map[dep_id], mod_map, permanent, temporary, sorted, path):
				return false
		# Note: Missing dependencies are handled later in _load_mod()

	# Done visiting - move from temporary to permanent
	temporary.erase(mod_id)
	path.pop_back()
	permanent[mod_id] = true
	sorted.append(mod)
	return true


## Emit a detailed error message when a circular dependency is detected
func _emit_cycle_error(cycle_start: String, path: Array[String]) -> void:
	# Build the cycle path string for clear error reporting
	var cycle_start_idx: int = path.find(cycle_start)
	var cycle_mods: Array[String] = []

	if cycle_start_idx >= 0:
		# Extract just the cycle portion
		for i: int in range(cycle_start_idx, path.size()):
			cycle_mods.append(path[i])
		cycle_mods.append(cycle_start)  # Complete the cycle
	else:
		# Fallback if index not found
		cycle_mods = path.duplicate()
		cycle_mods.append(cycle_start)

	var cycle_str: String = " -> ".join(cycle_mods)
	push_error("ModLoader: Circular dependency detected: %s" % cycle_str)
	push_error("ModLoader: To fix, remove one of the dependencies in this cycle")


## Sort function for mod priority (lower numbers load first)
## If priorities match, uses alphabetical order by mod_id as tiebreaker
func _sort_by_priority(a: ModManifest, b: ModManifest) -> bool:
	if a.load_priority != b.load_priority:
		return a.load_priority < b.load_priority
	# Tiebreaker: alphabetical by mod_id for consistent cross-platform behavior
	return a.mod_id < b.mod_id


## Get a mod manifest by ID
func get_mod(mod_id: String) -> ModManifest:
	for manifest in loaded_mods:
		if manifest.mod_id == mod_id:
			return manifest
	return null


## Get all loaded mods
func get_all_mods() -> Array[ModManifest]:
	return loaded_mods.duplicate()


## Get all loaded mods in priority order (highest priority first)
## Useful for checking which mod provides override resources
func get_mods_by_priority_descending() -> Array[ModManifest]:
	var mods: Array[ModManifest] = loaded_mods.duplicate()
	mods.reverse()  # Reverse since loaded_mods is sorted low to high
	return mods


## Get the currently active mod (for editor)
func get_active_mod() -> ModManifest:
	return get_mod(active_mod_id)


## Get the currently active mod's ID
## Convenience method for editors that just need the ID string
func get_active_mod_id() -> String:
	return active_mod_id


## Get the active mod's data directory path
## Returns the full path like "res://mods/_sandbox/data"
## Returns empty string if no active mod is set
func get_active_mod_data_path() -> String:
	var manifest: ModManifest = get_active_mod()
	if manifest:
		return manifest.get_data_directory()
	return ""


## Get the active mod's base directory path
## Returns the full path like "res://mods/_sandbox"
## Returns empty string if no active mod is set
func get_active_mod_path() -> String:
	var manifest: ModManifest = get_active_mod()
	if manifest:
		return manifest.mod_directory
	return ""


## Set the active mod (for editor and runtime)
## Also notifies listeners (like AudioManager) of the change
func set_active_mod(mod_id: String) -> bool:
	if _is_mod_loaded(mod_id):
		active_mod_id = mod_id
		_emit_active_mod_changed()
		return true
	else:
		push_error("ModLoader: Cannot set active mod - mod '%s' is not loaded" % mod_id)
		return false


## Emit the active_mod_changed signal with the current mod's directory path
## Called after mods load and when the active mod changes
func _emit_active_mod_changed() -> void:
	var manifest: ModManifest = get_active_mod()
	if manifest:
		active_mod_changed.emit(manifest.mod_directory)
	else:
		# Fallback if no manifest found (shouldn't happen in normal operation)
		push_warning("ModLoader: No active mod manifest found, using default path")
		active_mod_changed.emit(MODS_DIRECTORY.path_join(active_mod_id))


## Reload all mods synchronously (useful for editor/development)
## Blocks until all mods are loaded - safe but may cause brief freeze
func reload_mods() -> void:
	loaded_mods.clear()
	registry.clear()
	# Clear type registries
	equipment_registry.clear_mod_registrations()
	environment_registry.clear_mod_registrations()
	unit_category_registry.clear_mod_registrations()
	animation_offset_registry.clear_mod_registrations()
	trigger_type_registry.clear_mod_registrations()
	terrain_registry.clear_mod_registrations()
	# Clear equipment system registries
	equipment_slot_registry.clear_mod_registrations()
	equipment_type_registry.clear_mod_registrations()
	inventory_config.reset_to_defaults()
	# Clear AI brain and tileset registries
	ai_brain_registry.clear_mod_registrations()
	tileset_registry.clear_mod_registrations()
	# Clear AI role and mode registries
	ai_role_registry.clear_mod_registrations()
	ai_mode_registry.clear_mod_registrations()
	# Clear legacy tileset registry
	_tileset_registry.clear()
	_discover_and_load_mods()
	mods_loaded.emit()


## Reload all mods asynchronously (useful for runtime hot-reloading)
## Does not block - emits mods_loaded signal when complete
## WARNING: Scenes should wait for mods_loaded before accessing mod resources
func reload_mods_async() -> void:
	loaded_mods.clear()
	registry.clear()
	# Clear type registries
	equipment_registry.clear_mod_registrations()
	environment_registry.clear_mod_registrations()
	unit_category_registry.clear_mod_registrations()
	animation_offset_registry.clear_mod_registrations()
	trigger_type_registry.clear_mod_registrations()
	terrain_registry.clear_mod_registrations()
	# Clear equipment system registries
	equipment_slot_registry.clear_mod_registrations()
	equipment_type_registry.clear_mod_registrations()
	inventory_config.reset_to_defaults()
	# Clear AI brain and tileset registries
	ai_brain_registry.clear_mod_registrations()
	tileset_registry.clear_mod_registrations()
	# Clear AI role and mode registries
	ai_role_registry.clear_mod_registrations()
	ai_mode_registry.clear_mod_registrations()
	# Clear legacy tileset registry
	_tileset_registry.clear()
	await _discover_and_load_mods_async()
	mods_loaded.emit()


## Get list of all available resource directories for a mod
func get_resource_directories(mod_id: String) -> Dictionary:
	var manifest: ModManifest = get_mod(mod_id)
	if not manifest:
		return {}

	var dirs: Dictionary = {}
	var data_dir: String = manifest.get_data_directory()

	for dir_name: String in RESOURCE_TYPE_DIRS.keys():
		var resource_type: String = RESOURCE_TYPE_DIRS[dir_name]
		dirs[resource_type] = data_dir.path_join(dir_name)

	return dirs


# =============================================================================
# Mod Creation Support (for Editor Mod Wizard)
# =============================================================================

## Create a new mod with minimal mod.json
## @param mod_folder_name: The folder name (e.g., "my_mod")
## @param mod_name: Human-readable name (e.g., "My Awesome Mod")
## @param author: Author name
## @param load_priority: Load priority (100-8999 for user mods, 9000+ for total conversions)
## @return: Dictionary with {success: bool, error: String, mod_path: String}
func create_mod(mod_folder_name: String, mod_name: String, author: String = "", load_priority: int = 100) -> Dictionary:
	# Validate folder name
	if mod_folder_name.is_empty():
		return {"success": false, "error": "Mod folder name cannot be empty", "mod_path": ""}

	# Sanitize folder name (only alphanumeric, underscore, hyphen)
	var safe_folder_name: String = ""
	for c in mod_folder_name:
		if c.is_valid_identifier() or c == "-" or c == "_":
			safe_folder_name += c
		elif c == " ":
			safe_folder_name += "_"

	if safe_folder_name.is_empty():
		return {"success": false, "error": "Invalid folder name - use only letters, numbers, underscores, hyphens", "mod_path": ""}

	var mod_path: String = MODS_DIRECTORY.path_join(safe_folder_name)

	# Check if folder already exists
	if DirAccess.dir_exists_absolute(mod_path):
		return {"success": false, "error": "Mod folder already exists: " + safe_folder_name, "mod_path": ""}

	# Create folder structure
	var dir: DirAccess = DirAccess.open(MODS_DIRECTORY)
	if not dir:
		return {"success": false, "error": "Cannot access mods directory", "mod_path": ""}

	var err: Error = dir.make_dir(safe_folder_name)
	if err != OK:
		return {"success": false, "error": "Failed to create mod folder: " + str(err), "mod_path": ""}

	# Create standard subdirectories
	var subdirs: Array[String] = ["data", "assets", "scenes", "tilesets", "triggers"]
	var data_subdirs: Array[String] = ["characters", "classes", "items", "abilities", "battles", "parties", "dialogues", "cinematics", "maps", "campaigns", "terrain", "experience_configs"]

	for subdir: String in subdirs:
		err = DirAccess.make_dir_absolute(mod_path.path_join(subdir))
		if err != OK and err != ERR_ALREADY_EXISTS:
			push_warning("ModLoader: Failed to create subdir %s: %s" % [subdir, str(err)])

	for data_subdir: String in data_subdirs:
		err = DirAccess.make_dir_absolute(mod_path.path_join("data").path_join(data_subdir))
		if err != OK and err != ERR_ALREADY_EXISTS:
			push_warning("ModLoader: Failed to create data subdir %s: %s" % [data_subdir, str(err)])

	# Create mod.json
	var mod_json: Dictionary = {
		"id": safe_folder_name.replace("-", "_"),  # IDs use underscores
		"name": mod_name if not mod_name.is_empty() else safe_folder_name,
		"version": "1.0.0",
		"author": author if not author.is_empty() else "Unknown",
		"description": "",
		"godot_version": "4.5",
		"load_priority": load_priority,
		"dependencies": [],
		"content": {
			"data_path": "data/",
			"assets_path": "assets/"
		}
	}

	var mod_json_path: String = mod_path.path_join("mod.json")
	var file: FileAccess = FileAccess.open(mod_json_path, FileAccess.WRITE)
	if not file:
		return {"success": false, "error": "Failed to create mod.json", "mod_path": mod_path}

	file.store_string(JSON.stringify(mod_json, "\t"))
	file.close()

	return {"success": true, "error": "", "mod_path": mod_path}


## Check if a mod folder name is available (doesn't already exist)
func is_mod_folder_available(folder_name: String) -> bool:
	if folder_name.is_empty():
		return false
	var mod_path: String = MODS_DIRECTORY.path_join(folder_name)
	return not DirAccess.dir_exists_absolute(mod_path)


## Check if a mod is a total conversion (priority 9000+)
## Total conversions typically hide base game content and provide complete replacements
func is_total_conversion(mod_id: String) -> bool:
	var manifest: ModManifest = get_mod(mod_id)
	if not manifest:
		return false
	return manifest.load_priority >= 9000


## Check if the active mod is a total conversion
func is_active_mod_total_conversion() -> bool:
	return is_total_conversion(active_mod_id)


## Get all mods that are total conversions (priority 9000+)
func get_total_conversion_mods() -> Array[ModManifest]:
	var result: Array[ModManifest] = []
	for manifest: ModManifest in loaded_mods:
		if manifest.load_priority >= 9000:
			result.append(manifest)
	return result


# =============================================================================
# Default Party Resolution
# =============================================================================

## Get the default party composition based on loaded mods
## Returns: Array of CharacterData in party order (hero first)
## The hero is selected from the highest-priority mod that defines one.
## Default party members are collected from all loaded mods.
func get_default_party() -> Array[CharacterData]:
	var party: Array[CharacterData] = []

	# 1. Find the hero (highest priority mod wins)
	var hero: CharacterData = _find_hero_character()
	if not hero:
		push_error("CRITICAL: No hero character found! A character with is_hero=true is required for the game to function. Check that at least one mod defines a hero character.")
		return party
	party.append(hero)

	# 2. Find default party members
	var members: Array[CharacterData] = _find_default_party_members()
	for member: CharacterData in members:
		if member != hero:  # Don't duplicate hero
			party.append(member)

	return party


## Find the hero character from the highest-priority mod
## Searches mods in descending priority order and returns the first hero found
func _find_hero_character() -> CharacterData:
	# Get all characters from registry
	var all_characters: Array[Resource] = registry.get_all_resources("character")

	# Build a lookup of character resource_id -> CharacterData for heroes
	var hero_candidates: Array[Dictionary] = []
	for resource: Resource in all_characters:
		var character: CharacterData = resource as CharacterData
		if character and character.is_hero and character.unit_category == "player":
			# Get the resource ID from the resource path
			var resource_id: String = character.resource_path.get_file().get_basename()
			var source_mod: String = registry.get_resource_source(resource_id)
			hero_candidates.append({
				"character": character,
				"mod_id": source_mod
			})

	if hero_candidates.is_empty():
		return null

	# Find the hero from the highest-priority mod
	# loaded_mods is sorted low-to-high, so we iterate in reverse
	for i: int in range(loaded_mods.size() - 1, -1, -1):
		var manifest: ModManifest = loaded_mods[i]
		for candidate: Dictionary in hero_candidates:
			if candidate.mod_id == manifest.mod_id:
				return candidate.character

	# Fallback: return first hero if mod lookup fails
	return hero_candidates[0].character


## Get the priority cutoff for default party member selection
## If a mod has replaces_default_party=true, only characters from that mod
## and higher-priority mods are included in the default party.
## Returns: The load_priority of the cutoff mod, or -1 if no cutoff exists
func _get_party_cutoff_priority() -> int:
	# Iterate in descending priority order (highest priority first)
	for i: int in range(loaded_mods.size() - 1, -1, -1):
		var manifest: ModManifest = loaded_mods[i]
		if manifest.replaces_default_party:
			return manifest.load_priority
	return -1


## Find all characters marked as default party members
## Returns characters from mods at or above the party cutoff priority (player category only)
## If no mod sets replaces_default_party, returns characters from all loaded mods.
func _find_default_party_members() -> Array[CharacterData]:
	var members: Array[CharacterData] = []
	var all_characters: Array[Resource] = registry.get_all_resources("character")
	var cutoff_priority: int = _get_party_cutoff_priority()

	for resource: Resource in all_characters:
		var character: CharacterData = resource as CharacterData
		if character and character.is_default_party_member and character.unit_category == "player":
			# If there's a cutoff, check the source mod's priority
			if cutoff_priority >= 0:
				var resource_id: String = character.resource_path.get_file().get_basename()
				var source_mod_id: String = registry.get_resource_source(resource_id)
				var source_mod: ModManifest = get_mod(source_mod_id)
				if source_mod and source_mod.load_priority < cutoff_priority:
					continue  # Skip characters from lower-priority mods
			members.append(character)

	return members


# =============================================================================
# Hidden Campaign Patterns (for Total Conversion Mods)
# =============================================================================

## Get all hidden campaign patterns from loaded mods
## Returns patterns aggregated from all mods' hidden_campaigns arrays
## Patterns support glob-style matching: "base_game:*" matches all campaigns with that prefix
## Used by CampaignManager to filter campaigns from the selection UI
func get_hidden_campaign_patterns() -> Array[String]:
	var patterns: Array[String] = []

	for manifest: ModManifest in loaded_mods:
		for pattern: String in manifest.hidden_campaigns:
			if pattern not in patterns:
				patterns.append(pattern)

	return patterns


# =============================================================================
# New Game Configuration
# =============================================================================

## Get the active NewGameConfigData for starting new games
## Returns the default config (is_default=true) from the highest-priority mod
## If no configs exist, returns null (caller should use hardcoded defaults)
##
## Override semantics: Higher-priority mods completely replace lower-priority configs.
## No merging - if you want specific starting conditions, define them all in your config.
func get_new_game_config() -> Resource:  # Returns NewGameConfigData
	var all_configs: Array[Resource] = registry.get_all_resources("new_game_config")
	if all_configs.is_empty():
		print("[DEBUG] get_new_game_config: No configs found in registry")
		return null

	print("[DEBUG] get_new_game_config: Found %d configs" % all_configs.size())

	# Build list of default configs with their source mod priorities
	var default_configs: Array[Dictionary] = []
	for resource: Resource in all_configs:
		if resource.get_script() == NewGameConfigDataClass and resource.is_default:
			var resource_id: String = resource.resource_path.get_file().get_basename()
			var source_mod_id: String = registry.get_resource_source(resource_id)
			var source_mod: ModManifest = get_mod(source_mod_id)
			var priority: int = source_mod.load_priority if source_mod else 0
			print("[DEBUG]   Config '%s': resource_id='%s', source_mod='%s', priority=%d" % [
				resource.config_id, resource_id, source_mod_id, priority
			])
			default_configs.append({
				"config": resource,
				"mod_id": source_mod_id,
				"priority": priority
			})

	if default_configs.is_empty():
		# No default configs found, try returning any config from highest-priority mod
		for i: int in range(loaded_mods.size() - 1, -1, -1):
			var manifest: ModManifest = loaded_mods[i]
			for resource: Resource in all_configs:
				if resource.get_script() == NewGameConfigDataClass:
					var resource_id: String = resource.resource_path.get_file().get_basename()
					var source_mod_id: String = registry.get_resource_source(resource_id)
					if source_mod_id == manifest.mod_id:
						return resource
		return null

	# Find the default config from the highest-priority mod
	var best_config: Resource = null
	var best_priority: int = -1
	for entry: Dictionary in default_configs:
		if entry.priority > best_priority:
			best_priority = entry.priority
			best_config = entry.config

	print("[DEBUG] get_new_game_config: Selected config with priority %d: %s" % [
		best_priority,
		best_config.config_id if best_config else "NULL"
	])
	return best_config


## Get a specific NewGameConfigData by config_id
## Searches all loaded mods, returning the config from the highest-priority mod
## that has a matching config_id
func get_new_game_config_by_id(config_id: String) -> Resource:  # Returns NewGameConfigData
	var all_configs: Array[Resource] = registry.get_all_resources("new_game_config")

	var matching_configs: Array[Dictionary] = []
	for resource: Resource in all_configs:
		if resource.get_script() == NewGameConfigDataClass and resource.config_id == config_id:
			var resource_id: String = resource.resource_path.get_file().get_basename()
			var source_mod_id: String = registry.get_resource_source(resource_id)
			var source_mod: ModManifest = get_mod(source_mod_id)
			var priority: int = source_mod.load_priority if source_mod else 0
			matching_configs.append({
				"config": resource,
				"priority": priority
			})

	if matching_configs.is_empty():
		return null

	# Return the config from the highest-priority mod
	var best_config: Resource = null
	var best_priority: int = -1
	for entry: Dictionary in matching_configs:
		if entry.priority > best_priority:
			best_priority = entry.priority
			best_config = entry.config

	return best_config


## Get all available NewGameConfigData resources
## Returns configs from all mods, useful for a "game mode" selection UI
func get_all_new_game_configs() -> Array[Resource]:  # Returns Array of NewGameConfigData
	var all_configs: Array[Resource] = registry.get_all_resources("new_game_config")
	var result: Array[Resource] = []

	for resource: Resource in all_configs:
		if resource.get_script() == NewGameConfigDataClass:
			result.append(resource)

	return result
