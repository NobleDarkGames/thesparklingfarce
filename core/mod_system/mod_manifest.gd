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

## Reserved mod IDs that cannot be used (security + system reserved)
const RESERVED_MOD_IDS: Array[String] = [
	"core", "engine", "godot", "system", "base", "default", "null", "none",
	"res", "user", "uid", "tmp", "temp", "root", "admin"
]

## Maximum allowed length for mod IDs
const MAX_MOD_ID_LENGTH: int = 64

## Cached regex for mod ID validation
static var _mod_id_regex: RegEx = null

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
@export var custom_unit_categories: Array[String] = []
@export var custom_animation_offset_types: Array[String] = []
@export var custom_trigger_types: Array[String] = []

## Equipment slot layout - allows total conversion mods to redefine equipment slots
## Format: [{id: String, display_name: String, accepts_types: Array[String]}]
## If set, completely replaces the default SF-style layout
@export var equipment_slot_layout: Array[Dictionary] = []

## Equipment type configuration - maps subtypes to categories for slot matching
## Format: {
##   "replace_all": bool (optional, wipes all previous registrations),
##   "subtypes": {subtype_id: {category: String, display_name: String}},
##   "categories": {category_id: {display_name: String}}
## }
## Example: {"subtypes": {"laser": {"category": "weapon", "display_name": "Laser Gun"}}}
@export var equipment_type_config: Dictionary = {}

## Inventory configuration - allows mods to change inventory behavior
## Format: {slots_per_character: int, allow_duplicates: bool}
@export var inventory_config: Dictionary = {}

## Party configuration - allows total conversion mods to replace default party
## When true, default party members from lower-priority mods are ignored
@export var replaces_default_party: bool = false

## Editor extensions - allows mods to provide custom editor tabs
## Format: {"tab_id": {"resource_type": String, "editor_scene": String, "tab_name": String}}
## editor_scene is relative to mod directory
@export var editor_extensions: Dictionary = {}

## Hidden campaigns - patterns for campaigns to hide from the selection UI
## Total conversion mods use this to hide base game campaigns
## Supports glob-style patterns: "base_game:*" hides all campaigns with that prefix
## Exact IDs also work: "base_game:main_story" hides that specific campaign
@export var hidden_campaigns: Array[String] = []

## Caravan configuration - allows mods to customize or disable the Caravan system
## Format: {
##   "enabled": bool (default true, set false to disable caravan entirely),
##   "caravan_data_id": String (override which CaravanData resource to use),
##   "custom_services": {service_id: {scene_path: String, display_name: String}}
## }
@export var caravan_config: Dictionary = {}

## AI brain declarations - allows mods to provide AI brains with metadata
## Format: {brain_id: {path: String, display_name: String, description: String}}
## Example: {"aggressive": {"path": "ai_brains/ai_aggressive.gd", "display_name": "Aggressive"}}
@export var ai_brains: Dictionary = {}

## Tileset declarations - allows mods to provide tilesets with metadata
## Format: {tileset_id: {path: String, display_name: String, description: String}}
## Example: {"terrain": {"path": "tilesets/terrain.tres", "display_name": "Terrain Tiles"}}
## Note: Tilesets are also auto-discovered from tilesets/ directory for backwards compatibility
@export var tilesets: Dictionary = {}

## AI role declarations - allows mods to define custom AI roles with behavior scripts
## Format: {role_id: {display_name: String, description: String, script_path: String (optional)}}
## Example: {"hacking": {"display_name": "Hacking", "description": "Disables enemy systems", "script_path": "ai_roles/hacking_role.gd"}}
@export var ai_roles: Dictionary = {}

## AI mode declarations - allows mods to define custom AI behavior modes
## Format: {mode_id: {display_name: String, description: String}}
## Example: {"berserk": {"display_name": "Berserk", "description": "Maximum aggression, ignores self-preservation"}}
@export var ai_modes: Dictionary = {}

## Field menu options - allows mods to add custom options to the exploration field menu
## Format: {option_id: {label: String, scene_path: String, position: String}}
## position options: "start", "end" (default), "after_item", "after_magic", "after_search", "after_member"
## Example: {"bestiary": {"label": "Bestiary", "scene_path": "scenes/ui/bestiary.tscn", "position": "end"}}
## Special key "_replace_all": true removes all base options (for total conversions)
@export var field_menu_options: Dictionary = {}

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

	# Sanitize and validate mod ID (security critical)
	var raw_id: String = str(data.get("id", ""))
	var sanitized_id: String = _sanitize_mod_id(raw_id, json_path)
	if sanitized_id.is_empty():
		# Error already logged by _sanitize_mod_id
		return null
	manifest.mod_id = sanitized_id

	manifest.mod_name = str(data.get("name", "Unnamed Mod"))
	manifest.version = str(data.get("version", "1.0.0"))
	manifest.author = str(data.get("author", "Unknown"))
	manifest.description = str(data.get("description", ""))
	manifest.godot_version = str(data.get("godot_version", "4.5"))

	# Sanitize load_priority with clamping
	manifest.load_priority = _sanitize_load_priority(data.get("load_priority", 0), json_path)

	# Parse arrays
	if "dependencies" in data and data.dependencies is Array:
		var dependencies_arr: Array = data.dependencies
		for dep: Variant in dependencies_arr:
			manifest.dependencies.append(str(dep))

	if "overrides" in data and data.overrides is Array:
		var overrides_arr: Array = data.overrides
		for override: Variant in overrides_arr:
			manifest.overrides.append(str(override))

	if "tags" in data and data.tags is Array:
		var tags_arr: Array = data.tags
		for tag: Variant in tags_arr:
			manifest.tags.append(str(tag))

	# Parse content paths
	if "content" in data and data.content is Dictionary:
		var content_dict: Dictionary = data.content
		manifest.data_path = str(content_dict.get("data_path", "data/"))
		manifest.assets_path = str(content_dict.get("assets_path", "assets/"))

	# Parse scene mappings
	if "scenes" in data and data.scenes is Dictionary:
		var scenes_dict: Dictionary = data.scenes
		for scene_id: String in scenes_dict.keys():
			var scene_path_value: Variant = scenes_dict[scene_id]
			if scene_path_value is String:
				var scene_path: String = scene_path_value
				manifest.scenes[scene_id] = scene_path

	# Parse custom type definitions
	if "custom_types" in data and data.custom_types is Dictionary:
		var custom_types: Dictionary = data.custom_types

		if "weapon_types" in custom_types and custom_types.weapon_types is Array:
			var weapon_types_arr: Array = custom_types.weapon_types
			for wt: Variant in weapon_types_arr:
				manifest.custom_weapon_types.append(str(wt))

		if "armor_types" in custom_types and custom_types.armor_types is Array:
			var armor_types_arr: Array = custom_types.armor_types
			for at: Variant in armor_types_arr:
				manifest.custom_armor_types.append(str(at))

		if "unit_categories" in custom_types and custom_types.unit_categories is Array:
			var unit_categories_arr: Array = custom_types.unit_categories
			for uc: Variant in unit_categories_arr:
				manifest.custom_unit_categories.append(str(uc))

		if "animation_offset_types" in custom_types and custom_types.animation_offset_types is Array:
			var anim_offset_types_arr: Array = custom_types.animation_offset_types
			for aot: Variant in anim_offset_types_arr:
				manifest.custom_animation_offset_types.append(str(aot))

		if "trigger_types" in custom_types and custom_types.trigger_types is Array:
			var trigger_types_arr: Array = custom_types.trigger_types
			for tt: Variant in trigger_types_arr:
				manifest.custom_trigger_types.append(str(tt))

	# Parse equipment slot layout (total conversion support)
	if "equipment_slot_layout" in data and data.equipment_slot_layout is Array:
		var slot_layout_arr: Array = data.equipment_slot_layout
		for slot_def: Variant in slot_layout_arr:
			if slot_def is Dictionary:
				var slot_dict: Dictionary = slot_def
				manifest.equipment_slot_layout.append(slot_dict)

	# Parse equipment type configuration (subtype -> category mappings)
	# Can be at top level or nested under custom_types
	if "equipment_types" in data and data.equipment_types is Dictionary:
		var equip_types_dict: Dictionary = data.equipment_types
		manifest.equipment_type_config = equip_types_dict
	elif "custom_types" in data and data.custom_types is Dictionary:
		var custom_types_dict: Dictionary = data.custom_types
		if "equipment_types" in custom_types_dict and custom_types_dict.equipment_types is Dictionary:
			var nested_equip_dict: Dictionary = custom_types_dict.equipment_types
			manifest.equipment_type_config = nested_equip_dict

	# Parse inventory configuration
	if "inventory_config" in data and data.inventory_config is Dictionary:
		var inventory_dict: Dictionary = data.inventory_config
		manifest.inventory_config = inventory_dict

	# Parse party configuration
	if "party_config" in data and data.party_config is Dictionary:
		var party_config: Dictionary = data.party_config
		if "replaces_lower_priority" in party_config:
			var replaces_val: Variant = party_config.replaces_lower_priority
			if replaces_val is bool:
				manifest.replaces_default_party = replaces_val

	# Parse editor extensions (allows mods to add custom editor tabs)
	if "editor_extensions" in data and data.editor_extensions is Dictionary:
		var editor_ext_dict: Dictionary = data.editor_extensions
		for ext_id: String in editor_ext_dict.keys():
			var ext_data: Variant = editor_ext_dict[ext_id]
			if ext_data is Dictionary:
				var ext_dict: Dictionary = ext_data
				manifest.editor_extensions[ext_id] = ext_dict

	# Parse hidden campaigns (for total conversion mods to hide base content)
	if "hidden_campaigns" in data and data.hidden_campaigns is Array:
		var hidden_arr: Array = data.hidden_campaigns
		for pattern: Variant in hidden_arr:
			manifest.hidden_campaigns.append(str(pattern))

	# Parse caravan configuration
	if "caravan_config" in data and data.caravan_config is Dictionary:
		var caravan_dict: Dictionary = data.caravan_config
		manifest.caravan_config = caravan_dict

	# Parse AI brain declarations
	if "ai_brains" in data and data.ai_brains is Dictionary:
		var ai_brains_dict: Dictionary = data.ai_brains
		for brain_id: String in ai_brains_dict.keys():
			var brain_data: Variant = ai_brains_dict[brain_id]
			if brain_data is Dictionary:
				var brain_dict: Dictionary = brain_data
				manifest.ai_brains[brain_id] = brain_dict

	# Parse tileset declarations
	if "tilesets" in data and data.tilesets is Dictionary:
		var tilesets_dict: Dictionary = data.tilesets
		for tileset_id: String in tilesets_dict.keys():
			var tileset_data: Variant = tilesets_dict[tileset_id]
			if tileset_data is Dictionary:
				var tileset_dict: Dictionary = tileset_data
				manifest.tilesets[tileset_id] = tileset_dict

	# Parse AI role declarations
	if "ai_roles" in data and data.ai_roles is Dictionary:
		var ai_roles_dict: Dictionary = data.ai_roles
		for role_id: String in ai_roles_dict.keys():
			var role_data: Variant = ai_roles_dict[role_id]
			if role_data is Dictionary:
				var role_dict: Dictionary = role_data
				manifest.ai_roles[role_id] = role_dict

	# Parse AI mode declarations
	if "ai_modes" in data and data.ai_modes is Dictionary:
		var ai_modes_dict: Dictionary = data.ai_modes
		for mode_id: String in ai_modes_dict.keys():
			var mode_data: Variant = ai_modes_dict[mode_id]
			if mode_data is Dictionary:
				var mode_dict: Dictionary = mode_data
				manifest.ai_modes[mode_id] = mode_dict

	# Parse field menu options
	if "field_menu_options" in data and data.field_menu_options is Dictionary:
		var field_menu_dict: Dictionary = data.field_menu_options
		for option_id: String in field_menu_dict.keys():
			var option_data: Variant = field_menu_dict[option_id]
			# Handle special _replace_all key (boolean)
			if option_id == "_replace_all":
				if option_data is bool:
					manifest.field_menu_options[option_id] = option_data
			elif option_data is Dictionary:
				var option_dict: Dictionary = option_data
				manifest.field_menu_options[option_id] = option_dict

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

	# Note: load_priority validation moved to _sanitize_load_priority for clamping behavior
	return true


## Validate and sanitize a mod ID
## Returns sanitized ID or empty string if invalid (rejection required)
## Security: Prevents path traversal, reserved word abuse, and injection attacks
static func _sanitize_mod_id(raw_id: String, json_path: String) -> String:
	if raw_id.is_empty():
		push_error("mod.json: 'id' cannot be empty at: %s" % json_path)
		return ""

	var sanitized: String = raw_id.strip_edges()

	# Security: Check for path traversal attempts
	if ".." in sanitized or "/" in sanitized or "\\" in sanitized:
		push_error("mod.json: 'id' contains invalid path characters (potential path traversal): '%s' at: %s" % [raw_id, json_path])
		return ""

	# Security: Check for null bytes or control characters
	for i: int in range(sanitized.length()):
		var code: int = sanitized.unicode_at(i)
		if code < 32 or code == 127:  # Control characters
			push_error("mod.json: 'id' contains invalid control characters: '%s' at: %s" % [raw_id, json_path])
			return ""

	# Check against reserved words (case-insensitive)
	if sanitized.to_lower() in RESERVED_MOD_IDS:
		push_error("mod.json: 'id' uses reserved word '%s' at: %s" % [sanitized, json_path])
		return ""

	# Validate format: must start with letter, only alphanumeric/underscore/hyphen allowed
	# Pattern: ^[a-zA-Z_][a-zA-Z0-9_-]*$
	if _mod_id_regex == null:
		_mod_id_regex = RegEx.new()
		_mod_id_regex.compile("^[a-zA-Z_][a-zA-Z0-9_-]*$")

	if not _mod_id_regex.search(sanitized):
		push_error("mod.json: 'id' must start with a letter or underscore and contain only letters, numbers, underscores, hyphens. Got: '%s' at: %s" % [raw_id, json_path])
		return ""

	# Length check
	if sanitized.length() > MAX_MOD_ID_LENGTH:
		push_error("mod.json: 'id' exceeds maximum length of %d characters (got %d) at: %s" % [MAX_MOD_ID_LENGTH, sanitized.length(), json_path])
		return ""

	return sanitized


## Sanitize and clamp load_priority to valid range
## Returns clamped value and emits warning if clamping was needed
static func _sanitize_load_priority(raw_priority: Variant, json_path: String) -> int:
	var priority: int = 0

	if raw_priority is int or raw_priority is float:
		priority = int(raw_priority)
	else:
		push_warning("mod.json: 'load_priority' must be a number, using default 0 at: %s" % json_path)
		return 0

	# Clamp to valid range with warning
	if priority < MIN_PRIORITY:
		push_warning("mod.json: 'load_priority' %d clamped to %d (minimum) at: %s" % [priority, MIN_PRIORITY, json_path])
		return MIN_PRIORITY
	elif priority > MAX_PRIORITY:
		push_warning("mod.json: 'load_priority' %d clamped to %d (maximum) at: %s" % [priority, MAX_PRIORITY, json_path])
		return MAX_PRIORITY

	return priority


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
