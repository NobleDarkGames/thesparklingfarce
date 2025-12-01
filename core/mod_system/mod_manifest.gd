@tool
extends Resource
class_name ModManifest

## Represents a mod's metadata and configuration
## Loaded from mod.json files in the mods/ directory
##
## Load Priority Strategy (0-9999):
##   0-99:      Official game content from core development team
##   100-8999:  User mods
##   9000-9999: High priority and total conversion mods

const MIN_PRIORITY: int = 0
const MAX_PRIORITY: int = 9999

@export var mod_id: String = ""
@export var mod_name: String = ""
@export var version: String = "1.0.0"
@export var author: String = ""
@export var description: String = ""
@export var godot_version: String = "4.5"
@export var dependencies: Array[String] = []
@export var load_priority: int = 0
@export var data_path: String = "data/"
@export var assets_path: String = "assets/"
@export var overrides: Array[String] = []
@export var tags: Array[String] = []

## Scene mappings: { "scene_id": "relative/path/to/scene.tscn" }
## Allows mods to provide/override game scenes like opening_cinematic, main_menu, etc.
@export var scenes: Dictionary = {}

## Custom type definitions - allows mods to extend available options
## These are registered with the type registries on mod load
@export var custom_weapon_types: Array[String] = []
@export var custom_armor_types: Array[String] = []
@export var custom_weather_types: Array[String] = []
@export var custom_time_of_day: Array[String] = []
@export var custom_unit_categories: Array[String] = []
@export var custom_animation_offset_types: Array[String] = []
@export var custom_trigger_types: Array[String] = []

# Runtime properties (not serialized)
var mod_directory: String = ""
var is_loaded: bool = false


## Load manifest from a mod.json file
static func load_from_file(json_path: String) -> ModManifest:
	var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		push_error("Failed to open mod.json at: " + json_path)
		return null

	var json_string: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse mod.json at: " + json_path + " - Error: " + str(parse_result))
		return null

	var data: Dictionary = json.data
	if not data is Dictionary:
		push_error("mod.json is not a valid dictionary at: " + json_path)
		return null

	# Validate required fields
	if not _validate_manifest_data(data):
		push_error("Invalid mod.json structure at: " + json_path)
		return null

	# Create manifest and populate fields
	var manifest: ModManifest = ModManifest.new()
	manifest.mod_id = data.get("id", "")
	manifest.mod_name = data.get("name", "Unnamed Mod")
	manifest.version = data.get("version", "1.0.0")
	manifest.author = data.get("author", "Unknown")
	manifest.description = data.get("description", "")
	manifest.godot_version = data.get("godot_version", "4.5")
	manifest.load_priority = data.get("load_priority", 0)

	# Parse arrays
	if "dependencies" in data and data.dependencies is Array:
		for dep: Variant in data.dependencies:
			manifest.dependencies.append(str(dep))

	if "overrides" in data and data.overrides is Array:
		for override: Variant in data.overrides:
			manifest.overrides.append(str(override))

	if "tags" in data and data.tags is Array:
		for tag: Variant in data.tags:
			manifest.tags.append(str(tag))

	# Parse content paths
	if "content" in data and data.content is Dictionary:
		manifest.data_path = data.content.get("data_path", "data/")
		manifest.assets_path = data.content.get("assets_path", "assets/")

	# Parse scene mappings
	if "scenes" in data and data.scenes is Dictionary:
		for scene_id: String in data.scenes.keys():
			var scene_path: Variant = data.scenes[scene_id]
			if scene_path is String:
				manifest.scenes[scene_id] = scene_path

	# Parse custom type definitions
	if "custom_types" in data and data.custom_types is Dictionary:
		var custom_types: Dictionary = data.custom_types

		if "weapon_types" in custom_types and custom_types.weapon_types is Array:
			for wt: Variant in custom_types.weapon_types:
				manifest.custom_weapon_types.append(str(wt))

		if "armor_types" in custom_types and custom_types.armor_types is Array:
			for at: Variant in custom_types.armor_types:
				manifest.custom_armor_types.append(str(at))

		if "weather_types" in custom_types and custom_types.weather_types is Array:
			for wt: Variant in custom_types.weather_types:
				manifest.custom_weather_types.append(str(wt))

		if "time_of_day" in custom_types and custom_types.time_of_day is Array:
			for tod: Variant in custom_types.time_of_day:
				manifest.custom_time_of_day.append(str(tod))

		if "unit_categories" in custom_types and custom_types.unit_categories is Array:
			for uc: Variant in custom_types.unit_categories:
				manifest.custom_unit_categories.append(str(uc))

		if "animation_offset_types" in custom_types and custom_types.animation_offset_types is Array:
			for aot: Variant in custom_types.animation_offset_types:
				manifest.custom_animation_offset_types.append(str(aot))

		if "trigger_types" in custom_types and custom_types.trigger_types is Array:
			for tt: Variant in custom_types.trigger_types:
				manifest.custom_trigger_types.append(str(tt))

	# Set mod directory (parent of mod.json)
	manifest.mod_directory = json_path.get_base_dir()

	return manifest


## Validate that required fields exist in the JSON data
static func _validate_manifest_data(data: Dictionary) -> bool:
	# Required fields
	if not "id" in data:
		push_error("mod.json missing required field: 'id'")
		return false

	if not "name" in data:
		push_error("mod.json missing required field: 'name'")
		return false

	# Validate load_priority if present
	if "load_priority" in data:
		if not data.load_priority is float and not data.load_priority is int:
			push_error("mod.json 'load_priority' must be a number")
			return false

		var priority: int = int(data.load_priority)
		if priority < MIN_PRIORITY or priority > MAX_PRIORITY:
			push_error("mod.json 'load_priority' must be between %d and %d (got %d)" % [MIN_PRIORITY, MAX_PRIORITY, priority])
			return false

	return true


## Get the full path to the mod's data directory
func get_data_directory() -> String:
	return mod_directory.path_join(data_path)


## Get the full path to the mod's assets directory
func get_assets_directory() -> String:
	return mod_directory.path_join(assets_path)


## Check if this mod has a specific tag
func has_tag(tag: String) -> bool:
	return tag in tags


## Get a human-readable string representation
func _to_string() -> String:
	return "[Mod: %s v%s by %s]" % [mod_name, version, author]
