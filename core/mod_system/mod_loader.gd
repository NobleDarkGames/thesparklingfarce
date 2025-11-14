@tool
extends Node

## ModLoader - Autoload singleton for managing game mods
## Discovers mods in mods/ directory, loads them in priority order,
## and populates the ModRegistry with all resources

const MODS_DIRECTORY: String = "res://mods/"

# Resource type mappings: file path pattern -> resource type name
const RESOURCE_TYPE_DIRS: Dictionary = {
	"characters": "character",
	"classes": "class",
	"items": "item",
	"abilities": "ability",
	"dialogues": "dialogue",
	"battles": "battle"
}

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

	# Mark mod as loaded
	manifest.is_loaded = true
	loaded_mods.append(manifest)

	print("ModLoader: Mod '%s' loaded successfully (%d resources)" % [manifest.mod_name, loaded_count])


## Load all .tres resources from a directory
func _load_resources_from_directory(directory: String, resource_type: String, mod_id: String) -> int:
	var count: int = 0
	var dir: DirAccess = DirAccess.open(directory)

	if not dir:
		# Directory might not exist in this mod (that's okay)
		return 0

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path: String = directory.path_join(file_name)
			var resource: Resource = load(full_path)

			if resource:
				# Use filename without extension as resource ID
				var resource_id: String = file_name.get_basename()
				registry.register_resource(resource, resource_type, resource_id, mod_id)
				count += 1
			else:
				push_warning("ModLoader: Failed to load resource: " + full_path)

		file_name = dir.get_next()

	dir.list_dir_end()
	return count


## Check if a mod with the given ID is loaded
func _is_mod_loaded(mod_id: String) -> bool:
	for manifest in loaded_mods:
		if manifest.mod_id == mod_id:
			return true
	return false


## Sort function for mod priority (lower numbers load first)
func _sort_by_priority(a: ModManifest, b: ModManifest) -> bool:
	return a.load_priority < b.load_priority


## Get a mod manifest by ID
func get_mod(mod_id: String) -> ModManifest:
	for manifest in loaded_mods:
		if manifest.mod_id == mod_id:
			return manifest
	return null


## Get all loaded mods
func get_all_mods() -> Array[ModManifest]:
	return loaded_mods.duplicate()


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
