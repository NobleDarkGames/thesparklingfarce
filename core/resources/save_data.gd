class_name SaveData
extends Resource

## SaveData - Main save file resource
##
## Stores all campaign progress, party state, inventory, and mod compatibility data.
## Designed to be serialized to JSON for platform-independent saves.
##
## File location: user://saves/slot_N.sav
## Format: JSON

# ============================================================================
# METADATA
# ============================================================================

## Save version (for migration if data structure changes)
## Version history:
##   1 = Initial version
##   2 = Added depot_items for Caravan shared storage
@export var save_version: int = 2

## When this save was created (Unix timestamp)
@export var created_timestamp: int = 0

## When this save was last modified (Unix timestamp)
@export var last_played_timestamp: int = 0

## Total playtime in seconds
@export var playtime_seconds: int = 0

## Which slot this save occupies (1, 2, or 3)
@export var slot_number: int = 1

# ============================================================================
# MOD COMPATIBILITY
# ============================================================================

## List of mods that were active when this save was created
## Format: Array of {mod_id: String, version: String}
@export var active_mods: Array[Dictionary] = []

## Base game version
@export var game_version: String = "0.1.0"

# ============================================================================
# SCENE PROGRESS
# ============================================================================

## Current scene path (where to load when resuming)
@export var current_scene_path: String = ""

## Current spawn point ID within the scene (optional, used if player_position not set)
@export var current_spawn_point: String = ""

## Player's exact grid position when saved (takes priority over spawn point)
@export var player_grid_position: Vector2i = Vector2i(-1, -1)

## Player's facing direction when saved
@export var player_facing: String = ""

## Last safe location scene path (for Egress/defeat returns)
@export var last_safe_location: String = ""

## Current location name (for display in save menu)
## Example: "Mudford", "Overworld", "Ancient Shrine"
@export var current_location: String = "headquarters"

## Story flags (quest completion, dialogue choices, etc.)
## Format: {"flag_name": bool}
@export var story_flags: Dictionary = {}

## Completed battles (by battle resource ID)
## Example: ["battle_prologue", "battle_1", "battle_2"]
@export var completed_battles: Array[String] = []

## Available battles (unlocked but not yet completed)
@export var available_battles: Array[String] = []

# ============================================================================
# PARTY STATE
# ============================================================================

## Active party members (persistent character data)
## These are CharacterSaveData resources that track levels, XP, equipment
@export var party_members: Array[CharacterSaveData] = []

## Reserve/headquarters roster (recruited but not deployed)
@export var reserve_members: Array[CharacterSaveData] = []

## Maximum party size (can increase through story)
@export var max_party_size: int = 8

# ============================================================================
# INVENTORY & ECONOMY
# ============================================================================

## Current gold amount
@export var gold: int = 0

## Items in inventory (legacy field - prefer per-character inventory)
## Format: [{item_id: String, mod_id: String, quantity: int}]
@export var inventory: Array[Dictionary] = []

## Caravan Depot - Shared party storage (SF2-style)
## Format: Array of item IDs (simple strings, duplicates allowed for stacking)
## Example: ["healing_seed", "healing_seed", "bronze_sword", "power_ring"]
## Unlimited capacity by default (SF2-authentic)
@export var depot_items: Array[String] = []

# ============================================================================
# STATISTICS (for player reference)
# ============================================================================

@export var total_battles: int = 0
@export var battles_won: int = 0
@export var total_enemies_defeated: int = 0
@export var total_damage_dealt: int = 0
@export var total_healing_done: int = 0


# ============================================================================
# SERIALIZATION
# ============================================================================

## Helper to deserialize a typed string array from save data
## @param data: Source dictionary
## @param key: Key to look up
## @param target: Array to populate (will be cleared first)
static func _deserialize_string_array(data: Dictionary, key: String, target: Array[String]) -> void:
	if key not in data:
		return
	target.clear()
	var source: Variant = data.get(key)
	if source is Array:
		for entry: Variant in source:
			if entry is String:
				target.append(entry)


## Helper to deserialize a typed dictionary array from save data
## @param data: Source dictionary
## @param key: Key to look up
## @param target: Array to populate (will be cleared first)
static func _deserialize_dict_array(data: Dictionary, key: String, target: Array[Dictionary]) -> void:
	if key not in data:
		return
	target.clear()
	var source: Variant = data.get(key)
	if source is Array:
		for entry: Variant in source:
			if entry is Dictionary:
				target.append(entry)


## Helper to deserialize CharacterSaveData array from save data
## @param data: Source dictionary
## @param key: Key to look up
## @param target: Array to populate (will be cleared first)
static func _deserialize_character_array(data: Dictionary, key: String, target: Array[CharacterSaveData]) -> void:
	if key not in data:
		return
	target.clear()
	var source: Variant = data.get(key)
	if source is Array:
		for entry: Variant in source:
			if entry is Dictionary:
				var char_save: CharacterSaveData = CharacterSaveData.new()
				char_save.deserialize_from_dict(entry)
				target.append(char_save)


## Serialize save data to Dictionary for JSON export
## @return: Dictionary representation of all save data
func serialize_to_dict() -> Dictionary:
	var data: Dictionary = {
		"save_version": save_version,
		"created_timestamp": created_timestamp,
		"last_played_timestamp": last_played_timestamp,
		"playtime_seconds": playtime_seconds,
		"slot_number": slot_number,
		"active_mods": active_mods.duplicate(),
		"game_version": game_version,
		# Scene progress
		"current_scene_path": current_scene_path,
		"current_spawn_point": current_spawn_point,
		"player_grid_position": {"x": player_grid_position.x, "y": player_grid_position.y},
		"player_facing": player_facing,
		"last_safe_location": last_safe_location,
		"current_location": current_location,
		"story_flags": story_flags.duplicate(),
		"completed_battles": completed_battles.duplicate(),
		"available_battles": available_battles.duplicate(),
		"max_party_size": max_party_size,
		"gold": gold,
		"inventory": inventory.duplicate(),
		"depot_items": depot_items.duplicate(),
		"total_battles": total_battles,
		"battles_won": battles_won,
		"total_enemies_defeated": total_enemies_defeated,
		"total_damage_dealt": total_damage_dealt,
		"total_healing_done": total_healing_done,
	}

	# Serialize party members
	var party_array: Array[Dictionary] = []
	for char_save: CharacterSaveData in party_members:
		if char_save != null:
			party_array.append(char_save.serialize_to_dict())
	data["party_members"] = party_array

	# Serialize reserve members
	var reserve_array: Array[Dictionary] = []
	for char_save: CharacterSaveData in reserve_members:
		if char_save != null:
			reserve_array.append(char_save.serialize_to_dict())
	data["reserve_members"] = reserve_array

	return data


## Deserialize save data from Dictionary (loaded from JSON)
## Uses type coercion helpers for safety against corrupted/malformed data
## @param data: Dictionary loaded from JSON file
func deserialize_from_dict(data: Dictionary) -> void:
	# Metadata
	save_version = DictUtils.get_int(data, "save_version", 1)
	created_timestamp = DictUtils.get_int(data, "created_timestamp", 0)
	last_played_timestamp = DictUtils.get_int(data, "last_played_timestamp", 0)
	playtime_seconds = maxi(0, DictUtils.get_int(data, "playtime_seconds", 0))
	slot_number = clampi(DictUtils.get_int(data, "slot_number", 1), 1, 3)
	_deserialize_dict_array(data, "active_mods", active_mods)
	game_version = DictUtils.get_string(data, "game_version", "0.1.0")

	# Scene progress
	current_scene_path = DictUtils.get_string(data, "current_scene_path", "")
	current_spawn_point = DictUtils.get_string(data, "current_spawn_point", "")
	player_facing = DictUtils.get_string(data, "player_facing", "")
	player_grid_position = _deserialize_vector2i(data, "player_grid_position", Vector2i(-1, -1))
	last_safe_location = DictUtils.get_string(data, "last_safe_location", "")
	current_location = DictUtils.get_string(data, "current_location", "headquarters")

	# Story state
	if "story_flags" in data:
		var flags_data: Variant = data.get("story_flags")
		if flags_data is Dictionary:
			story_flags = flags_data.duplicate()
		else:
			push_warning("SaveData: story_flags is not a Dictionary, using empty")
			story_flags = {}
	_deserialize_string_array(data, "completed_battles", completed_battles)
	_deserialize_string_array(data, "available_battles", available_battles)

	# Party/Inventory
	max_party_size = clampi(DictUtils.get_int(data, "max_party_size", 8), 1, 30)
	gold = maxi(0, DictUtils.get_int(data, "gold", 0))
	_deserialize_dict_array(data, "inventory", inventory)
	_deserialize_string_array(data, "depot_items", depot_items)

	# Statistics (non-negative enforcement)
	total_battles = maxi(0, DictUtils.get_int(data, "total_battles", 0))
	battles_won = maxi(0, DictUtils.get_int(data, "battles_won", 0))
	total_enemies_defeated = maxi(0, DictUtils.get_int(data, "total_enemies_defeated", 0))
	total_damage_dealt = maxi(0, DictUtils.get_int(data, "total_damage_dealt", 0))
	total_healing_done = maxi(0, DictUtils.get_int(data, "total_healing_done", 0))

	# Party and reserve members
	_deserialize_character_array(data, "party_members", party_members)
	_deserialize_character_array(data, "reserve_members", reserve_members)


## Helper to deserialize a Vector2i from save data
## @param data: Source dictionary
## @param key: Key to look up
## @param default: Default value if key missing or invalid
static func _deserialize_vector2i(data: Dictionary, key: String, default: Vector2i) -> Vector2i:
	if key not in data:
		return default
	var pos_data: Variant = data.get(key)
	if pos_data is Dictionary:
		return Vector2i(
			DictUtils.get_int(pos_data, "x", default.x),
			DictUtils.get_int(pos_data, "y", default.y)
		)
	return default


# ============================================================================
# VALIDATION
# ============================================================================

## Validate that save data is complete and valid
## @return: true if valid, false if corrupted/invalid
func validate() -> bool:
	var checks: Array = [
		[save_version < 1, "Invalid save_version: %d" % save_version],
		[slot_number < 1 or slot_number > 3, "Invalid slot_number: %d (must be 1-3)" % slot_number],
		[game_version.is_empty(), "game_version is empty"],
	]
	for check: Array in checks:
		if check[0]:
			push_error("SaveData: " + check[1])
			return false

	# Validate party members
	for char_save: CharacterSaveData in party_members:
		if not char_save.validate():
			return false
	return true


# ============================================================================
# UTILITY
# ============================================================================

## Get display summary for save slot menu
## @return: Human-readable summary string
func get_display_summary() -> String:
	var leader_name: String = "Empty"
	if not party_members.is_empty():
		var leader: CharacterSaveData = party_members[0]
		leader_name = leader.fallback_character_name

	var avg_level: int = _calculate_average_level()
	var playtime_str: String = _format_playtime()

	return "%s - Lv. %d - %s - %s" % [
		leader_name,
		avg_level,
		current_location,
		playtime_str
	]


## Calculate average party level
## @return: Average level of all party members
func _calculate_average_level() -> int:
	if party_members.is_empty():
		return 1

	var total_level: int = 0
	for char_save: CharacterSaveData in party_members:
		total_level += char_save.level

	return total_level / party_members.size()


## Format playtime as HH:MM:SS
## @return: Formatted playtime string
func _format_playtime() -> String:
	var hours: int = playtime_seconds / 3600
	var minutes: int = (playtime_seconds % 3600) / 60
	var seconds: int = playtime_seconds % 60

	return "%02d:%02d:%02d" % [hours, minutes, seconds]


# ============================================================================
# MOD DEPENDENCY VALIDATION (2B.2)
# ============================================================================

## Validate that all referenced mods are still loaded
## Returns Dictionary with:
##   valid: bool - true if all mods present
##   missing_mods: Array[String] - list of missing mod IDs
##   orphaned_items: Array[String] - items from missing mods
##   orphaned_characters: Array[String] - characters from missing mods
func validate_mod_dependencies() -> Dictionary:
	var missing_mods: Array[String] = []
	var orphaned_items: Array[String] = []
	var orphaned_characters: Array[String] = []
	var is_valid: bool = true

	# Get currently loaded mod IDs
	var loaded_mods: Array[String] = _get_loaded_mod_ids()

	# Check active_mods against loaded mods
	for mod_info: Dictionary in active_mods:
		var mod_id: String = DictUtils.get_string(mod_info, "mod_id", "")
		if not mod_id.is_empty() and mod_id not in loaded_mods:
			missing_mods.append(mod_id)
			is_valid = false

	# Check inventory items
	for item_dict: Dictionary in inventory:
		var item_mod_id: String = DictUtils.get_string(item_dict, "mod_id", "_base_game")
		if item_mod_id not in loaded_mods and item_mod_id != "_base_game":
			var item_id: String = DictUtils.get_string(item_dict, "item_id", "unknown")
			orphaned_items.append(item_id)
			if item_mod_id not in missing_mods:
				missing_mods.append(item_mod_id)
			is_valid = false

	# Check depot items (resolve mod source from registry)
	if ModLoader:
		for item_id: String in depot_items:
			if not ModLoader.registry.has_resource("item", item_id):
				orphaned_items.append(item_id)
				is_valid = false

	# Check all characters (party and reserve)
	for char_save: CharacterSaveData in _get_all_characters():
		if char_save.character_mod_id.is_empty():
			continue
		if char_save.character_mod_id not in loaded_mods:
			orphaned_characters.append(char_save.fallback_character_name)
			if char_save.character_mod_id not in missing_mods:
				missing_mods.append(char_save.character_mod_id)
			is_valid = false

	return {
		"valid": is_valid,
		"missing_mods": missing_mods,
		"orphaned_items": orphaned_items,
		"orphaned_characters": orphaned_characters
	}


## Get list of currently loaded mod IDs
func _get_loaded_mod_ids() -> Array[String]:
	var loaded_mods: Array[String] = []
	if ModLoader:
		for mod: ModManifest in ModLoader.loaded_mods:
			loaded_mods.append(mod.mod_id)
	return loaded_mods


## Get all characters (party + reserve) for iteration
func _get_all_characters() -> Array[CharacterSaveData]:
	var all_chars: Array[CharacterSaveData] = []
	all_chars.append_array(party_members)
	all_chars.append_array(reserve_members)
	return all_chars


## Remove content from mods that are no longer loaded
func remove_orphaned_content(mod_check: Dictionary) -> void:
	# Extract orphaned content lists with type safety
	var orphaned_items_variant: Variant = mod_check.get("orphaned_items", [])
	var orphaned_items_list: Array = orphaned_items_variant if orphaned_items_variant is Array else []
	var orphaned_characters_variant: Variant = mod_check.get("orphaned_characters", [])
	var orphaned_characters_list: Array = orphaned_characters_variant if orphaned_characters_variant is Array else []

	# Remove orphaned inventory items
	inventory = _filter_inventory(inventory, orphaned_items_list)

	# Remove orphaned depot items
	depot_items = _filter_string_array(depot_items, orphaned_items_list)

	# Remove orphaned characters from party and reserve
	party_members = _filter_characters(party_members, orphaned_characters_list)
	reserve_members = _filter_characters(reserve_members, orphaned_characters_list)


## Filter inventory to exclude orphaned items
func _filter_inventory(source: Array[Dictionary], orphaned: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_dict: Dictionary in source:
		var item_id: String = DictUtils.get_string(item_dict, "item_id", "")
		if item_id not in orphaned:
			result.append(item_dict)
	return result


## Filter string array to exclude orphaned entries
func _filter_string_array(source: Array[String], orphaned: Array) -> Array[String]:
	var result: Array[String] = []
	for entry: String in source:
		if entry not in orphaned:
			result.append(entry)
	return result


## Filter character array to exclude orphaned characters by name
func _filter_characters(source: Array[CharacterSaveData], orphaned: Array) -> Array[CharacterSaveData]:
	var result: Array[CharacterSaveData] = []
	for char_save: CharacterSaveData in source:
		if char_save.fallback_character_name not in orphaned:
			result.append(char_save)
	return result
