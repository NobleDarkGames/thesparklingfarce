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

# Magic number constants
const TOTAL_CONVERSION_PRIORITY: int = 9000  # Priority threshold for total conversion mods
const REMAP_SUFFIX: String = ".remap"  # Godot adds this suffix in export builds
const REMAP_SUFFIX_LENGTH: int = 6  # Length of ".remap" for substring operations

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
	"maps": "map",  # MapMetadata resources for exploration maps
	"terrain": "terrain",  # TerrainData resources for battle terrain effects
	"experience_configs": "experience_config",  # ExperienceConfig resources for XP/leveling settings
	"caravans": "caravan",  # CaravanData resources for mobile HQ configuration
	"npcs": "npc",  # NPCData resources for interactable NPCs
	"shops": "shop",  # ShopData resources for weapon/item shops, churches, crafters
	"new_game_configs": "new_game_config",  # NewGameConfigData resources for starting game state
	"ai_behaviors": "ai_behavior",  # AIBehaviorData resources for configurable enemy AI
	"status_effects": "status_effect",  # StatusEffectData resources for data-driven status effects
	"crafting_recipes": "crafting_recipe",  # CraftingRecipeData resources for crafting system
	"crafters": "crafter",  # CrafterData resources for crafter NPCs and locations
	"interactables": "interactable"  # InteractableData resources for chests, bookshelves, etc.
}

# Resource types that support JSON loading (in addition to .tres)
const JSON_SUPPORTED_TYPES: Array[String] = ["cinematic", "map"]

# Preload loaders for JSON resources
const CinematicLoader = preload("res://core/systems/cinematic_loader.gd")
const MapMetadataLoader = preload("res://core/systems/map_metadata_loader.gd")

# Preload resource classes needed before class_name is available
const NewGameConfigDataClass = preload("res://core/resources/new_game_config_data.gd")

# Preload type registry classes
const EquipmentRegistryClass = preload("res://core/registries/equipment_registry.gd")
const UnitCategoryRegistryClass = preload("res://core/registries/unit_category_registry.gd")
const AnimationOffsetRegistryClass = preload("res://core/registries/animation_offset_registry.gd")
const TriggerTypeRegistryClass = preload("res://core/registries/trigger_type_registry.gd")
const TerrainRegistryClass = preload("res://core/registries/terrain_registry.gd")
const EquipmentSlotRegistryClass = preload("res://core/registries/equipment_slot_registry.gd")
const EquipmentTypeRegistryClass = preload("res://core/registries/equipment_type_registry.gd")
const InventoryConfigClass = preload("res://core/systems/inventory_config.gd")
const AIBrainRegistryClass = preload("res://core/registries/ai_brain_registry.gd")
const TilesetRegistryClass = preload("res://core/registries/tileset_registry.gd")
const AIModeRegistryClass = preload("res://core/registries/ai_mode_registry.gd")
const StatusEffectRegistryClass = preload("res://core/registries/status_effect_registry.gd")

## Signal emitted when all mods have finished loading
signal mods_loaded()

## Signal emitted when the active mod changes (for systems like AudioManager)
## @param mod_path: Full path to the mod directory (e.g., "res://mods/_base_game")
signal active_mod_changed(mod_path: String)

## Signal emitted when a path security violation is detected (path traversal attempt)
## @param path: The offending path that was rejected
## @param reason: Description of why the path was rejected
signal path_security_violation(path: String, reason: String)

var registry: ModRegistry = ModRegistry.new()
var loaded_mods: Array[ModManifest] = []
var active_mod_id: String = "_base_game"  # Default active mod

# Type registries for mod-extensible enums
var equipment_registry: EquipmentRegistry = EquipmentRegistryClass.new()
var unit_category_registry: UnitCategoryRegistry = UnitCategoryRegistryClass.new()
var animation_offset_registry: AnimationOffsetRegistry = AnimationOffsetRegistryClass.new()
var trigger_type_registry: TriggerTypeRegistry = TriggerTypeRegistryClass.new()
var terrain_registry: TerrainRegistry = TerrainRegistryClass.new()

# Equipment system configuration (data-driven slots and inventory)
var equipment_slot_registry: EquipmentSlotRegistry = EquipmentSlotRegistryClass.new()
var equipment_type_registry: EquipmentTypeRegistry = EquipmentTypeRegistryClass.new()
var inventory_config: InventoryConfig = InventoryConfigClass.new()

# AI brain registry (declared in mod.json with metadata)
var ai_brain_registry: AIBrainRegistry = AIBrainRegistryClass.new()

# Tileset registry (declared in mod.json with metadata, also auto-discovered)
var tileset_registry: TilesetRegistry = TilesetRegistryClass.new()

# AI mode registry (for configurable AI behaviors)
var ai_mode_registry: AIModeRegistry = AIModeRegistryClass.new()

# Status effect registry (data-driven status effects)
var status_effect_registry: StatusEffectRegistry = StatusEffectRegistryClass.new()

## Loading state tracking
var _is_loading: bool = false


## Print debug message if running in debug build
func _debug_print(message: String) -> void:
	if OS.is_debug_build():
		print("ModLoader: " + message)

## Async load cancellation - set to true to abandon pending threaded loads
var _async_load_cancelled: bool = false

## Tracks paths with pending ResourceLoader.load_threaded_request() calls
## Used to avoid accessing results after cancellation
var _pending_threaded_paths: Array[String] = []


## Check if mods are currently being loaded
## @return: true if mod loading is in progress
func is_loading() -> bool:
	return _is_loading


## Cancel any pending async load operations
## Call this before freeing ModLoader to prevent orphaned load requests
## from attempting to access freed memory
func cancel_async_loads() -> void:
	if _pending_threaded_paths.is_empty():
		return

	_async_load_cancelled = true
	push_warning("ModLoader: Cancelling %d pending async load requests" % _pending_threaded_paths.size())
	# Note: ResourceLoader.load_threaded_request() cannot be cancelled,
	# but we prevent accessing results by checking _async_load_cancelled
	_pending_threaded_paths.clear()


## Handle cleanup when being freed
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		cancel_async_loads()


func _ready() -> void:
	# Initialize equipment type defaults before mods load
	# Mods can override these via "replace_all": true in custom_types.equipment_types
	equipment_type_registry.init_defaults()

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


## Discover mods, resolve dependencies, and sort by priority
## Returns sorted mods ready for loading, or empty array if issues prevent loading
func _discover_and_resolve_mods() -> Array[ModManifest]:
	var discovered_mods: Array[ModManifest] = _discover_mods()
	if discovered_mods.is_empty():
		push_warning("ModLoader: No mods found in " + MODS_DIRECTORY)
		return []

	var resolved_mods: Array[ModManifest] = _topological_sort_with_cycle_detection(discovered_mods)
	if resolved_mods.is_empty() and not discovered_mods.is_empty():
		push_error("ModLoader: Cannot proceed due to circular dependencies")
		return []

	resolved_mods.sort_custom(_sort_by_priority)
	return resolved_mods


## Discover all mods and load them in priority order (sync version for editor/reload)
func _discover_and_load_mods() -> void:
	var resolved_mods: Array[ModManifest] = _discover_and_resolve_mods()

	for manifest: ModManifest in resolved_mods:
		_load_mod(manifest)


## Discover all mods and load them asynchronously (for game startup)
func _discover_and_load_mods_async() -> void:
	_is_loading = true
	var resolved_mods: Array[ModManifest] = _discover_and_resolve_mods()
	if resolved_mods.is_empty():
		_is_loading = false
		return

	for manifest: ModManifest in resolved_mods:
		await _load_mod_async(manifest)
		# Guard against being freed during async load
		if not is_instance_valid(self):
			return

	_is_loading = false


## Discover all mods in the mods/ directory
func _discover_mods() -> Array[ModManifest]:
	var mods: Array[ModManifest] = []

	var is_exported: bool = not OS.has_feature("editor")
	_debug_print("Running in %s mode" % ("EXPORT" if is_exported else "EDITOR"))
	_debug_print("Attempting to open: %s" % MODS_DIRECTORY)

	var dir: DirAccess = DirAccess.open(MODS_DIRECTORY)
	if not dir:
		push_error("ModLoader: Failed to open mods directory: " + MODS_DIRECTORY)
		push_error("ModLoader: DirAccess error: %s" % DirAccess.get_open_error())
		return mods

	_debug_print("Successfully opened mods directory")
	dir.list_dir_begin()
	var folder_name: String = dir.get_next()

	while folder_name != "":
		_debug_print("Found folder/file: '%s' (is_dir: %s)" % [folder_name, dir.current_is_dir()])
		if dir.current_is_dir() and not folder_name.begins_with("."):
			var mod_json_path: String = MODS_DIRECTORY.path_join(folder_name).path_join("mod.json")

			_debug_print("Checking for mod.json at: %s" % mod_json_path)
			if FileAccess.file_exists(mod_json_path):
				_debug_print("Found mod.json, loading...")
				var manifest: ModManifest = ModManifest.load_from_file(mod_json_path)
				if manifest:
					_debug_print("Loaded mod '%s' from %s" % [manifest.mod_id, folder_name])
					mods.append(manifest)
				else:
					push_warning("ModLoader: Failed to load manifest for mod in folder: " + folder_name)
			else:
				_debug_print("No mod.json at %s" % mod_json_path)

		folder_name = dir.get_next()

	dir.list_dir_end()
	_debug_print("Discovered %d mods total" % mods.size())
	return mods


## Load a single mod and register all its resources
func _load_mod(manifest: ModManifest) -> void:
	if not _check_mod_dependencies(manifest):
		return

	_register_mod_type_definitions(manifest)

	# Load resources from data directory
	var data_dir: String = manifest.get_data_directory()
	for dir_name: String in RESOURCE_TYPE_DIRS:
		var resource_type: String = RESOURCE_TYPE_DIRS[dir_name]
		var type_dir: String = data_dir.path_join(dir_name)
		_load_resources_from_directory(type_dir, resource_type, manifest.mod_id)

	_finalize_mod_loading(manifest)


## Load a single mod asynchronously using threaded resource loading
func _load_mod_async(manifest: ModManifest) -> void:
	if not _check_mod_dependencies(manifest):
		return

	_register_mod_type_definitions(manifest)

	# Collect all resource paths from data directory
	var data_dir: String = manifest.get_data_directory()
	var resource_requests: Array[Dictionary] = []

	for dir_name: String in RESOURCE_TYPE_DIRS:
		var resource_type: String = RESOURCE_TYPE_DIRS[dir_name]
		var type_dir: String = data_dir.path_join(dir_name)
		var requests: Array[Dictionary] = _collect_resource_paths(type_dir, resource_type, manifest.mod_id)
		resource_requests.append_array(requests)

	# Request all .tres resources to load in background threads
	var tres_paths: Array[String] = []
	for req: Dictionary in resource_requests:
		var req_path: String = DictUtils.get_string(req, "path", "")
		if req_path.ends_with(".tres"):
			ResourceLoader.load_threaded_request(req_path, "", true)  # true = use_sub_threads
			tres_paths.append(req_path)
			_pending_threaded_paths.append(req_path)

	# Wait for all threaded loads to complete (polling with yield to not block)
	if not tres_paths.is_empty():
		await _wait_for_threaded_loads(tres_paths)

	# Check cancellation after await - if cancelled, abandon resource registration
	if _async_load_cancelled:
		push_warning("ModLoader: Async load cancelled for mod '%s', skipping resource registration" % manifest.mod_id)
		return

	# Retrieve and register all resources
	for req: Dictionary in resource_requests:
		var req_path: String = DictUtils.get_string(req, "path", "")
		var req_resource_type: String = DictUtils.get_string(req, "resource_type", "")
		var req_resource_id: String = DictUtils.get_string(req, "resource_id", "")

		var resource: Resource = null
		if req_path.ends_with(".tres"):
			resource = ResourceLoader.load_threaded_get(req_path)
			# Remove from pending list after retrieval
			_pending_threaded_paths.erase(req_path)
		elif req_path.ends_with(".json"):
			resource = _load_json_resource(req_path, req_resource_type)

		if resource:
			_register_resource_with_type_handling(resource, req_resource_type, req_resource_id, manifest.mod_id)
		else:
			push_warning("ModLoader: Failed to load resource: " + req_path)

	_finalize_mod_loading(manifest)


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
			# Strip .remap suffix when listing directories (for export builds)
			var original_name: String = file_name
			if file_name.ends_with(REMAP_SUFFIX):
				original_name = file_name.substr(0, file_name.length() - REMAP_SUFFIX_LENGTH)

			if original_name.ends_with(".tres"):
				var full_path: String = directory.path_join(original_name)
				requests.append({
					"path": full_path,
					"resource_type": resource_type,
					"resource_id": original_name.get_basename(),
					"mod_id": mod_id
				})
			elif original_name.ends_with(".json") and supports_json:
				var full_path: String = directory.path_join(original_name)
				requests.append({
					"path": full_path,
					"resource_type": resource_type,
					"resource_id": original_name.get_basename(),
					"mod_id": mod_id
				})

		file_name = dir.get_next()

	dir.list_dir_end()
	return requests


## Wait for all threaded resource loads to complete
func _wait_for_threaded_loads(paths: Array[String]) -> void:
	var pending: Array[String] = paths.duplicate()

	while not pending.is_empty():
		# Check cancellation flag at start of each poll cycle
		if _async_load_cancelled:
			push_warning("ModLoader: Async load cancelled, abandoning %d pending resources" % pending.size())
			return

		var still_pending: Array[String] = []

		for path: String in pending:
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
			# Guard against being removed from tree mid-load
			if not get_tree():
				push_warning("ModLoader: Removed from tree during async load, aborting wait")
				return
			await get_tree().process_frame
			# Guard against being freed during await
			if not is_instance_valid(self):
				return


## Load all .tres and .json resources from a directory
func _load_resources_from_directory(directory: String, resource_type: String, mod_id: String) -> int:
	var count: int = 0
	var dir: DirAccess = DirAccess.open(directory)

	if not dir:
		# Directory might not exist in this mod (that's okay)
		# But log it for character type to debug export issues
		if resource_type == "character":
			_debug_print("Could not open %s directory: %s (error: %s)" % [resource_type, directory, DirAccess.get_open_error()])
		return 0

	if resource_type == "character":
		_debug_print("Scanning %s directory: %s" % [resource_type, directory])

	var supports_json: bool = resource_type in JSON_SUPPORTED_TYPES

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir():
			# In exports, Godot creates .remap files - strip the suffix to get original name
			var original_name: String = file_name
			if file_name.ends_with(REMAP_SUFFIX):
				original_name = file_name.substr(0, file_name.length() - REMAP_SUFFIX_LENGTH)  # Remove ".remap"

			var full_path: String = directory.path_join(original_name)
			var resource: Resource = null
			var resource_id: String = ""

			if resource_type == "character":
				_debug_print("Found %s file: %s -> %s" % [resource_type, file_name, original_name])

			if original_name.ends_with(".tres"):
				# Standard Godot resource (load using original path - Godot handles remapping)
				resource = load(full_path)
				resource_id = original_name.get_basename()

			elif original_name.ends_with(".json") and supports_json:
				# JSON resource (cinematics, maps)
				resource = _load_json_resource(full_path, resource_type)
				resource_id = original_name.get_basename()
				# Set resource_path so JSON-loaded resources can be identified like .tres resources
				if resource:
					resource.resource_path = full_path

			if resource:
				_register_resource_with_type_handling(resource, resource_type, resource_id, mod_id)
				if resource_type == "character" and resource is CharacterData:
					var char: CharacterData = resource
					_debug_print("Registered character '%s' (uid: %s)" % [char.character_name, char.character_uid])
				count += 1
			elif not resource_id.is_empty():
				push_warning("ModLoader: Failed to load resource: " + full_path)

		file_name = dir.get_next()

	dir.list_dir_end()
	if resource_type == "character":
		_debug_print("Loaded %d characters from %s" % [count, directory])
	return count


## Load a resource from a JSON file based on resource type
func _load_json_resource(json_path: String, resource_type: String) -> Resource:
	match resource_type:
		"cinematic":
			return CinematicLoader.load_from_json(json_path)
		"map":
			return MapMetadataLoader.load_from_json(json_path)
		_:
			push_warning("ModLoader: JSON loading not supported for resource type: " + resource_type)
			return null


## Register a resource and handle special type-specific registrations
func _register_resource_with_type_handling(resource: Resource, resource_type: String, resource_id: String, mod_id: String) -> void:
	registry.register_resource(resource, resource_type, resource_id, mod_id)
	# Special handling for terrain resources - also register with terrain_registry
	if resource_type == "terrain" and resource is TerrainData:
		terrain_registry.register_terrain(resource, mod_id)
	# Special handling for status effect resources - also register with status_effect_registry
	if resource_type == "status_effect" and resource is StatusEffectData:
		status_effect_registry.register_effect(resource, mod_id)


## Complete mod loading by registering scenes, triggers, tilesets and marking as loaded
func _finalize_mod_loading(manifest: ModManifest) -> void:
	_register_mod_scenes(manifest)
	_discover_trigger_scripts(manifest)
	_discover_tilesets(manifest)
	manifest.is_loaded = true
	loaded_mods.append(manifest)


## Check if all dependencies for a mod are loaded
## Returns true if all dependencies are satisfied, false otherwise (with error logging)
func _check_mod_dependencies(manifest: ModManifest) -> bool:
	for dep_id: String in manifest.dependencies:
		if not _is_mod_loaded(dep_id):
			push_error("ModLoader: Mod '%s' requires dependency '%s' which is not loaded" % [manifest.mod_id, dep_id])
			return false
	return true


## Register custom type definitions from a mod manifest
## This populates the type registries with mod-defined extensions
func _register_mod_type_definitions(manifest: ModManifest) -> void:
	# Equipment types
	if not manifest.custom_weapon_types.is_empty():
		equipment_registry.register_weapon_types(manifest.mod_id, manifest.custom_weapon_types)
	if not manifest.custom_armor_types.is_empty():
		equipment_registry.register_armor_types(manifest.mod_id, manifest.custom_armor_types)

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

	# AI mode declarations (from mod.json)
	if not manifest.ai_modes.is_empty():
		ai_mode_registry.register_from_config(manifest.mod_id, manifest.ai_modes)


## Register scenes from a mod manifest
func _register_mod_scenes(manifest: ModManifest) -> int:
	var count: int = 0

	for scene_id: String in manifest.scenes:
		var relative_path: String = manifest.scenes[scene_id]
		var full_path: String = manifest.mod_directory.path_join(relative_path)

		# Verify scene file exists - use ResourceLoader.exists() for export compatibility
		# (FileAccess.file_exists() fails because .tscn becomes .tscn.remap in exports)
		if not ResourceLoader.exists(full_path):
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
	# Use the tileset registry for discovery (handles both declared and auto-discovered)
	var tileset_count: int = tileset_registry.discover_from_directory(manifest.mod_id, manifest.mod_directory)

	# Also discover AI brains from directory
	ai_brain_registry.discover_from_directory(manifest.mod_id, manifest.mod_directory)

	return tileset_count


## Get a TileSet resource by name
## Returns the highest-priority mod's version of the tileset
## Auto-generates tile definitions based on texture dimensions if missing
## @param tileset_name: The tileset name (e.g., "terrain_placeholder")
## @return: The TileSet resource, or null if not found
func get_tileset(tileset_name: String) -> TileSet:
	return tileset_registry.get_tileset(tileset_name)


## Get the path to a TileSet by name (without loading it)
## Useful for scene files that need the path at edit time
func get_tileset_path(tileset_name: String) -> String:
	return tileset_registry.get_tileset_path(tileset_name)


## Check if a tileset is registered
func has_tileset(tileset_name: String) -> bool:
	return tileset_registry.has_tileset(tileset_name)


## Get all registered tileset names
func get_tileset_names() -> Array[String]:
	return tileset_registry.get_all_tileset_ids()


## Get which mod provides a tileset
func get_tileset_source(tileset_name: String) -> String:
	return tileset_registry.get_source_mod(tileset_name)


## Check if a mod with the given ID is loaded
func _is_mod_loaded(mod_id: String) -> bool:
	for manifest: ModManifest in loaded_mods:
		if manifest.mod_id == mod_id:
			return true
	return false


# =============================================================================
# Scene Override System (Phase 2.1)
# =============================================================================

## Load a scene from a path, returning null if not found or not a PackedScene
func _load_scene_from_path(path: String) -> PackedScene:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var loaded: Resource = load(path)
	return loaded if loaded is PackedScene else null


## Get a scene by registry ID, with fallback to default path
## Used by systems like BattleManager to allow mods to override core scenes
##
## @param scene_id: The registered scene ID (e.g., "unit_scene", "combat_anim_scene")
## @param fallback_path: Default path if no mod provides this scene
## @return: Loaded PackedScene, or null if neither found
func get_scene_or_fallback(scene_id: String, fallback_path: String) -> PackedScene:
	# First check if a mod has registered this scene
	var mod_path: String = registry.get_scene_path(scene_id)
	var scene: PackedScene = _load_scene_from_path(mod_path)
	if scene:
		return scene
	elif not mod_path.is_empty():
		push_warning("ModLoader: Failed to load mod scene '%s' at: %s, using fallback" % [scene_id, mod_path])

	# Fallback to default path
	scene = _load_scene_from_path(fallback_path)
	if scene:
		return scene
	elif not fallback_path.is_empty():
		push_error("ModLoader: Failed to load fallback scene '%s' at: %s" % [scene_id, fallback_path])

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
		var reason: String = "Path contains directory traversal (..)"
		push_error("ModLoader: Invalid asset path (contains ..): %s" % relative_path)
		path_security_violation.emit(relative_path, reason)
		return ""

	if relative_path.begins_with("/") or relative_path.begins_with("\\"):
		var reason: String = "Absolute paths not allowed"
		push_error("ModLoader: Invalid asset path (absolute path not allowed): %s" % relative_path)
		path_security_violation.emit(relative_path, reason)
		return ""

	# Check mods in descending priority order (highest priority first)
	var mods: Array[ModManifest] = get_mods_by_priority_descending()
	for mod: ModManifest in mods:
		var full_path: String = mod.get_assets_directory().path_join(relative_path)
		# Use ResourceLoader.exists() for export compatibility
		if ResourceLoader.exists(full_path):
			return full_path

	# Fallback to base path
	if not fallback_base_path.is_empty():
		var fallback_full: String = fallback_base_path.path_join(relative_path)
		# Use ResourceLoader.exists() for export compatibility
		if ResourceLoader.exists(fallback_full):
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
	var loaded: Resource = load(path)
	return loaded if loaded is Texture2D else null


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
			var dep_val: Variant = mod_map[dep_id]
			var dep_manifest: ModManifest = dep_val if dep_val is ModManifest else null
			if dep_manifest and not _visit_mod_for_sort(dep_manifest, mod_map, permanent, temporary, sorted, path):
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
	for manifest: ModManifest in loaded_mods:
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


## Clear all loaded mods and registries (used before reload)
func _clear_all_registries() -> void:
	loaded_mods.clear()
	registry.clear()
	equipment_registry.clear_mod_registrations()
	unit_category_registry.clear_mod_registrations()
	animation_offset_registry.clear_mod_registrations()
	trigger_type_registry.clear_mod_registrations()
	terrain_registry.clear_mod_registrations()
	equipment_slot_registry.clear_mod_registrations()
	equipment_type_registry.clear_mod_registrations()
	inventory_config.reset_to_defaults()
	ai_brain_registry.clear_mod_registrations()
	tileset_registry.clear_mod_registrations()
	ai_mode_registry.clear_mod_registrations()
	status_effect_registry.clear_mod_registrations()


## Reload all mods synchronously (useful for editor/development)
## Blocks until all mods are loaded - safe but may cause brief freeze
func reload_mods() -> void:
	_clear_all_registries()
	_discover_and_load_mods()
	mods_loaded.emit()


## Reload all mods asynchronously (useful for runtime hot-reloading)
## Does not block - emits mods_loaded signal when complete
##
## WARNING: Race condition hazard! This function clears all registries immediately,
## then awaits async loading. During this window, registry access returns empty results.
## Callers MUST either:
##   1. Check is_loading() before accessing registry, OR
##   2. Await the mods_loaded signal before accessing mod resources
## Failure to do so will result in missing resources during the reload window.
func reload_mods_async() -> void:
	if _is_loading:
		push_warning("ModLoader: Reload already in progress, ignoring")
		return
	_clear_all_registries()
	await _discover_and_load_mods_async()
	if not is_instance_valid(self):
		return
	mods_loaded.emit()


## Get list of all available resource directories for a mod
func get_resource_directories(mod_id: String) -> Dictionary:
	var manifest: ModManifest = get_mod(mod_id)
	if not manifest:
		return {}

	var dirs: Dictionary = {}
	var data_dir: String = manifest.get_data_directory()

	for dir_name: String in RESOURCE_TYPE_DIRS:
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
	for c: String in mod_folder_name:
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
	var data_subdirs: Array[String] = ["characters", "classes", "items", "abilities", "battles", "parties", "dialogues", "cinematics", "maps", "terrain", "experience_configs"]

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
	return manifest.load_priority >= TOTAL_CONVERSION_PRIORITY


## Check if the active mod is a total conversion
func is_active_mod_total_conversion() -> bool:
	return is_total_conversion(active_mod_id)


## Get all mods that are total conversions (priority 9000+)
func get_total_conversion_mods() -> Array[ModManifest]:
	var result: Array[ModManifest] = []
	for manifest: ModManifest in loaded_mods:
		if manifest.load_priority >= TOTAL_CONVERSION_PRIORITY:
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
	for character: CharacterData in all_characters:
		if not character:
			continue
		if character.is_hero and character.unit_category == "player":
			# Get the resource ID from the resource path
			var resource_id: String = character.resource_path.get_file().get_basename()
			var source_mod: String = registry.get_resource_source(resource_id, "character")
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
			var candidate_mod_id: String = DictUtils.get_string(candidate, "mod_id", "")
			if candidate_mod_id == manifest.mod_id:
				var char_value: Variant = candidate.get("character")
				return char_value if char_value is CharacterData else null

	# Fallback: return first hero if mod lookup fails
	var first_candidate: Dictionary = hero_candidates[0]
	var first_char_value: Variant = first_candidate.get("character")
	return first_char_value if first_char_value is CharacterData else null


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

	for character: CharacterData in all_characters:
		if not character:
			continue
		if character.is_default_party_member and character.unit_category == "player":
			# If there's a cutoff, check the source mod's priority
			if cutoff_priority >= 0:
				var resource_id: String = character.resource_path.get_file().get_basename()
				var source_mod_id: String = registry.get_resource_source(resource_id, "character")
				var source_mod: ModManifest = get_mod(source_mod_id)
				if source_mod and source_mod.load_priority < cutoff_priority:
					continue  # Skip characters from lower-priority mods
			members.append(character)

	return members


# =============================================================================
# New Game Configuration
# =============================================================================

## Get the active NewGameConfigData for starting new games
## Returns the default config (is_default=true) from the highest-priority mod
## If no configs exist, returns null (caller should use hardcoded defaults)
##
## Override semantics: Higher-priority mods completely replace lower-priority configs.
## No merging - if you want specific starting conditions, define them all in your config.
func get_new_game_config() -> NewGameConfigData:
	var all_configs: Array[Resource] = registry.get_all_resources("new_game_config")
	if all_configs.is_empty():
		return null

	# Build list of default configs with their source mod priorities
	var default_configs: Array[Dictionary] = []
	for config: NewGameConfigData in all_configs:
		if config and config.is_default:
			var resource_id: String = config.resource_path.get_file().get_basename()
			var source_mod_id: String = registry.get_resource_source(resource_id, "new_game_config")
			var source_mod: ModManifest = get_mod(source_mod_id)
			var priority: int = source_mod.load_priority if source_mod else 0
			default_configs.append({
				"config": config,
				"mod_id": source_mod_id,
				"priority": priority
			})

	if default_configs.is_empty():
		# No default configs found, try returning any config from highest-priority mod
		for i: int in range(loaded_mods.size() - 1, -1, -1):
			var manifest: ModManifest = loaded_mods[i]
			for config: NewGameConfigData in all_configs:
				if config:
					var resource_id: String = config.resource_path.get_file().get_basename()
					var source_mod_id: String = registry.get_resource_source(resource_id, "new_game_config")
					if source_mod_id == manifest.mod_id:
						return config
		return null

	# Find the default config from the highest-priority mod
	var best_config: NewGameConfigData = null
	var best_priority: int = -1
	for entry: Dictionary in default_configs:
		var entry_priority: int = DictUtils.get_int(entry, "priority", 0)
		if entry_priority > best_priority:
			best_priority = entry_priority
			var config_value: Variant = entry.get("config")
			best_config = config_value if config_value is NewGameConfigData else null

	return best_config


## Get a specific NewGameConfigData by config_id
## Searches all loaded mods, returning the config from the highest-priority mod
## that has a matching config_id
func get_new_game_config_by_id(config_id: String) -> NewGameConfigData:
	var all_configs: Array[Resource] = registry.get_all_resources("new_game_config")

	var matching_configs: Array[Dictionary] = []
	for config: NewGameConfigData in all_configs:
		if config and config.config_id == config_id:
			var resource_id: String = config.resource_path.get_file().get_basename()
			var source_mod_id: String = registry.get_resource_source(resource_id, "new_game_config")
			var source_mod: ModManifest = get_mod(source_mod_id)
			var priority: int = source_mod.load_priority if source_mod else 0
			matching_configs.append({
				"config": config,
				"priority": priority
			})

	if matching_configs.is_empty():
		return null

	# Return the config from the highest-priority mod
	var best_config: NewGameConfigData = null
	var best_priority: int = -1
	for entry: Dictionary in matching_configs:
		var entry_priority: int = DictUtils.get_int(entry, "priority", 0)
		if entry_priority > best_priority:
			best_priority = entry_priority
			var config_value: Variant = entry.get("config")
			best_config = config_value if config_value is NewGameConfigData else null

	return best_config


## Get all available NewGameConfigData resources
## Returns configs from all mods, useful for a "game mode" selection UI
func get_all_new_game_configs() -> Array[NewGameConfigData]:
	var all_configs: Array[Resource] = registry.get_all_resources("new_game_config")
	var result: Array[NewGameConfigData] = []

	for config: NewGameConfigData in all_configs:
		if config:
			result.append(config)

	return result
