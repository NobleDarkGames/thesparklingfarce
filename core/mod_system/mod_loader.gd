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
	"terrain": "terrain"  # TerrainData resources for battle terrain effects
}

# Resource types that support JSON loading (in addition to .tres)
const JSON_SUPPORTED_TYPES: Array[String] = ["cinematic", "campaign", "map"]

# Preload loaders for JSON resources
const CinematicLoader: GDScript = preload("res://core/systems/cinematic_loader.gd")
const CampaignLoader: GDScript = preload("res://core/systems/campaign_loader.gd")
const MapMetadataLoader: GDScript = preload("res://core/systems/map_metadata_loader.gd")

# Preload type registry classes
const EquipmentRegistryClass: GDScript = preload("res://core/registries/equipment_registry.gd")
const EnvironmentRegistryClass: GDScript = preload("res://core/registries/environment_registry.gd")
const UnitCategoryRegistryClass: GDScript = preload("res://core/registries/unit_category_registry.gd")
const AnimationOffsetRegistryClass: GDScript = preload("res://core/registries/animation_offset_registry.gd")
const TriggerTypeRegistryClass: GDScript = preload("res://core/registries/trigger_type_registry.gd")
const TerrainRegistryClass: GDScript = preload("res://core/registries/terrain_registry.gd")

## Signal emitted when all mods have finished loading
signal mods_loaded()

var registry: ModRegistry = ModRegistry.new()
var loaded_mods: Array[ModManifest] = []
var active_mod_id: String = "_base_game"  # Default active mod for editor

# Type registries for mod-extensible enums
var equipment_registry: RefCounted = EquipmentRegistryClass.new()
var environment_registry: RefCounted = EnvironmentRegistryClass.new()
var unit_category_registry: RefCounted = UnitCategoryRegistryClass.new()
var animation_offset_registry: RefCounted = AnimationOffsetRegistryClass.new()
var trigger_type_registry: RefCounted = TriggerTypeRegistryClass.new()
var terrain_registry: RefCounted = TerrainRegistryClass.new()

# TileSet registry: tileset_name -> {path: String, mod_id: String, resource: TileSet}
var _tileset_registry: Dictionary = {}

## Loading state tracking
var _is_loading: bool = false
var _pending_loads: Dictionary = {}  # path -> {resource_type, resource_id, mod_id}


func _ready() -> void:
	# Initial load is SYNCHRONOUS to ensure all resources are available
	# before any scenes try to use them. Use reload_mods_async() for
	# runtime hot-reloading if needed.
	_discover_and_load_mods()
	mods_loaded.emit()


## Discover all mods and load them in priority order (sync version for editor/reload)
func _discover_and_load_mods() -> void:
	var discovered_mods: Array[ModManifest] = _discover_mods()
	if discovered_mods.is_empty():
		push_warning("ModLoader: No mods found in " + MODS_DIRECTORY)
		return

	# Sort by load priority (lower priority loads first, can be overridden by higher)
	discovered_mods.sort_custom(_sort_by_priority)

	# Load each mod
	for manifest in discovered_mods:
		_load_mod(manifest)


## Discover all mods and load them asynchronously (for game startup)
func _discover_and_load_mods_async() -> void:
	_is_loading = true
	var discovered_mods: Array[ModManifest] = _discover_mods()
	if discovered_mods.is_empty():
		push_warning("ModLoader: No mods found in " + MODS_DIRECTORY)
		_is_loading = false
		return

	# Sort by load priority (lower priority loads first, can be overridden by higher)
	discovered_mods.sort_custom(_sort_by_priority)

	# Load each mod asynchronously
	for manifest in discovered_mods:
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
	var tilesets_dir: String = manifest.mod_directory.path_join("tilesets")
	var dir: DirAccess = DirAccess.open(tilesets_dir)

	if not dir:
		# No tilesets directory - that's okay
		return 0

	var count: int = 0
	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path: String = tilesets_dir.path_join(file_name)
			# Extract tileset name from filename: terrain_placeholder.tres -> terrain_placeholder
			var tileset_name: String = file_name.get_basename().to_lower()

			if not tileset_name.is_empty():
				# Register (or override) the tileset
				_tileset_registry[tileset_name] = {
					"path": full_path,
					"mod_id": manifest.mod_id,
					"resource": null  # Lazy-loaded on first access
				}
				count += 1

		file_name = dir.get_next()

	dir.list_dir_end()
	return count


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


## Set the active mod (for editor)
func set_active_mod(mod_id: String) -> bool:
	if _is_mod_loaded(mod_id):
		active_mod_id = mod_id
		return true
	else:
		push_error("ModLoader: Cannot set active mod - mod '%s' is not loaded" % mod_id)
		return false


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
	# Clear tileset registry
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
	# Clear tileset registry
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
