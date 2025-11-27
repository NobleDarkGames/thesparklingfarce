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
	"battles": "battle"
}

# Resource types that support JSON loading (in addition to .tres)
const JSON_SUPPORTED_TYPES: Array[String] = ["cinematic"]

# Preload the CinematicLoader for JSON cinematics
const CinematicLoader: GDScript = preload("res://core/systems/cinematic_loader.gd")

var registry: ModRegistry = ModRegistry.new()
var loaded_mods: Array[ModManifest] = []
var active_mod_id: String = "base_game"  # Default active mod for editor


func _ready() -> void:
	print("ModLoader: Initializing...")
	_discover_and_load_mods()
	registry.print_debug()


## Discover all mods and load them in priority order
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
					print("ModLoader: Discovered mod '%s' (%s)" % [manifest.mod_name, manifest.mod_id])
					mods.append(manifest)
				else:
					push_warning("ModLoader: Failed to load manifest for mod in folder: " + folder_name)
			else:
				push_warning("ModLoader: Folder '%s' has no mod.json, skipping" % folder_name)

		folder_name = dir.get_next()

	dir.list_dir_end()
	return mods


## Load a single mod and register all its resources
func _load_mod(manifest: ModManifest) -> void:
	print("ModLoader: Loading mod '%s' (priority: %d)..." % [manifest.mod_name, manifest.load_priority])

	# Check dependencies (simple check - just verify they're loaded)
	for dep_id in manifest.dependencies:
		if not _is_mod_loaded(dep_id):
			push_error("ModLoader: Mod '%s' requires dependency '%s' which is not loaded" % [manifest.mod_id, dep_id])
			return

	# Load resources from data directory
	var data_dir: String = manifest.get_data_directory()
	var loaded_count: int = 0

	for dir_name: String in RESOURCE_TYPE_DIRS.keys():
		var resource_type: String = RESOURCE_TYPE_DIRS[dir_name]
		var type_dir: String = data_dir.path_join(dir_name)
		loaded_count += _load_resources_from_directory(type_dir, resource_type, manifest.mod_id)

	# Register scenes from manifest
	var scene_count: int = _register_mod_scenes(manifest)

	# Mark mod as loaded
	manifest.is_loaded = true
	loaded_mods.append(manifest)

	print("ModLoader: Mod '%s' loaded successfully (%d resources, %d scenes)" % [manifest.mod_name, loaded_count, scene_count])


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
		_:
			push_warning("ModLoader: JSON loading not supported for resource type: " + resource_type)
			return null


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
		print("ModLoader: Active mod set to '%s'" % mod_id)
		return true
	else:
		push_error("ModLoader: Cannot set active mod - mod '%s' is not loaded" % mod_id)
		return false


## Reload all mods (useful for development)
func reload_mods() -> void:
	print("ModLoader: Reloading all mods...")
	loaded_mods.clear()
	registry.clear()
	_discover_and_load_mods()
	registry.print_debug()


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
