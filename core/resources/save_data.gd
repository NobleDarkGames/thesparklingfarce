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

## Current spawn point ID within the scene (optional)
@export var current_spawn_point: String = ""

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
	# Metadata - with type safety using .get() to avoid Variant warnings
	save_version = DictUtils.get_int(data, "save_version", 1)
	created_timestamp = DictUtils.get_int(data, "created_timestamp", 0)
	last_played_timestamp = DictUtils.get_int(data, "last_played_timestamp", 0)
	playtime_seconds = maxi(0, DictUtils.get_int(data, "playtime_seconds", 0))
	slot_number = clampi(DictUtils.get_int(data, "slot_number", 1), 1, 3)
	if "active_mods" in data:
		active_mods.clear()
		var mods_data: Variant = data.get("active_mods")
		if mods_data is Array:
			var mods_array: Array = mods_data
			for mod_entry: Variant in mods_array:
				if mod_entry is Dictionary:
					active_mods.append(mod_entry)
	game_version = DictUtils.get_string(data, "game_version", "0.1.0")

	# Scene progress - with type safety
	current_scene_path = DictUtils.get_string(data, "current_scene_path", "")
	current_spawn_point = DictUtils.get_string(data, "current_spawn_point", "")
	last_safe_location = DictUtils.get_string(data, "last_safe_location", "")
	current_location = DictUtils.get_string(data, "current_location", "headquarters")

	if "story_flags" in data:
		var flags_data: Variant = data.get("story_flags")
		if flags_data is Dictionary:
			var flags_dict: Dictionary = flags_data
			story_flags = flags_dict.duplicate()
		else:
			push_warning("SaveData: story_flags is not a Dictionary, using empty")
			story_flags = {}
	if "completed_battles" in data:
		completed_battles.clear()
		var completed_data: Variant = data.get("completed_battles")
		if completed_data is Array:
			var completed_array: Array = completed_data
			for battle_entry: Variant in completed_array:
				if battle_entry is String:
					completed_battles.append(battle_entry)
	if "available_battles" in data:
		available_battles.clear()
		var available_data: Variant = data.get("available_battles")
		if available_data is Array:
			var available_array: Array = available_data
			for battle_entry: Variant in available_array:
				if battle_entry is String:
					available_battles.append(battle_entry)

	# Party/Inventory - with type safety and bounds checking
	max_party_size = clampi(DictUtils.get_int(data, "max_party_size", 8), 1, 30)
	gold = maxi(0, DictUtils.get_int(data, "gold", 0))
	if "inventory" in data:
		inventory.clear()
		var inventory_data: Variant = data.get("inventory")
		if inventory_data is Array:
			var inventory_array: Array = inventory_data
			for item_entry: Variant in inventory_array:
				if item_entry is Dictionary:
					inventory.append(item_entry)
	if "depot_items" in data:
		depot_items.clear()
		var depot_data: Variant = data.get("depot_items")
		if depot_data is Array:
			var depot_array: Array = depot_data
			for item_entry: Variant in depot_array:
				if item_entry is String:
					depot_items.append(item_entry)

	# Statistics - with type safety and non-negative enforcement
	total_battles = maxi(0, DictUtils.get_int(data, "total_battles", 0))
	battles_won = maxi(0, DictUtils.get_int(data, "battles_won", 0))
	total_enemies_defeated = maxi(0, DictUtils.get_int(data, "total_enemies_defeated", 0))
	total_damage_dealt = maxi(0, DictUtils.get_int(data, "total_damage_dealt", 0))
	total_healing_done = maxi(0, DictUtils.get_int(data, "total_healing_done", 0))

	# Deserialize party members
	party_members.clear()
	if "party_members" in data:
		var party_data: Variant = data.get("party_members")
		if party_data is Array:
			var party_array: Array = party_data
			for i: int in range(party_array.size()):
				var char_entry: Variant = party_array[i]
				if char_entry is Dictionary:
					var char_dict: Dictionary = char_entry
					var char_save: CharacterSaveData = CharacterSaveData.new()
					char_save.deserialize_from_dict(char_dict)
					party_members.append(char_save)

	# Deserialize reserve members
	reserve_members.clear()
	if "reserve_members" in data:
		var reserve_data: Variant = data.get("reserve_members")
		if reserve_data is Array:
			var reserve_array: Array = reserve_data
			for i: int in range(reserve_array.size()):
				var char_entry: Variant = reserve_array[i]
				if char_entry is Dictionary:
					var char_dict: Dictionary = char_entry
					var char_save: CharacterSaveData = CharacterSaveData.new()
					char_save.deserialize_from_dict(char_dict)
					reserve_members.append(char_save)


# ============================================================================
# VALIDATION
# ============================================================================

## Validate that save data is complete and valid
## @return: true if valid, false if corrupted/invalid
func validate() -> bool:
	if save_version < 1:
		push_error("SaveData: Invalid save_version: %d" % save_version)
		return false

	if slot_number < 1 or slot_number > 3:
		push_error("SaveData: Invalid slot_number: %d (must be 1-3)" % slot_number)
		return false

	if game_version.is_empty():
		push_error("SaveData: game_version is empty")
		return false

	# Validate party members
	for i: int in range(party_members.size()):
		var char_save: CharacterSaveData = party_members[i]
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
	# Use typed arrays for type safety
	var missing_mods: Array[String] = []
	var orphaned_items: Array[String] = []
	var orphaned_characters: Array[String] = []
	var is_valid: bool = true

	# Get currently loaded mod IDs
	var loaded_mods: Array[String] = []
	if ModLoader:
		for mod: ModManifest in ModLoader.loaded_mods:
			loaded_mods.append(mod.mod_id)

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

	# Check party members
	for char_save: CharacterSaveData in party_members:
		if not char_save.character_mod_id.is_empty():
			if char_save.character_mod_id not in loaded_mods:
				orphaned_characters.append(char_save.fallback_character_name)
				if char_save.character_mod_id not in missing_mods:
					missing_mods.append(char_save.character_mod_id)
				is_valid = false

	# Check reserve members
	for char_save: CharacterSaveData in reserve_members:
		if not char_save.character_mod_id.is_empty():
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


## Remove content from mods that are no longer loaded
func remove_orphaned_content(mod_check: Dictionary) -> void:
	# Extract orphaned content lists with type safety
	var orphaned_items_variant: Variant = mod_check.get("orphaned_items", [])
	var orphaned_items_list: Array = orphaned_items_variant if orphaned_items_variant is Array else []
	var orphaned_characters_variant: Variant = mod_check.get("orphaned_characters", [])
	var orphaned_characters_list: Array = orphaned_characters_variant if orphaned_characters_variant is Array else []

	# Remove orphaned inventory items
	var valid_inventory: Array[Dictionary] = []
	for item_dict: Dictionary in inventory:
		var item_id: String = DictUtils.get_string(item_dict, "item_id", "")
		if item_id not in orphaned_items_list:
			valid_inventory.append(item_dict)
	inventory = valid_inventory

	# Remove orphaned depot items
	var valid_depot: Array[String] = []
	for item_id: String in depot_items:
		if item_id not in orphaned_items_list:
			valid_depot.append(item_id)
	depot_items = valid_depot

	# Remove orphaned party members
	var valid_party: Array[CharacterSaveData] = []
	for char_save: CharacterSaveData in party_members:
		if char_save.fallback_character_name not in orphaned_characters_list:
			valid_party.append(char_save)
	party_members = valid_party

	# Remove orphaned reserve members
	var valid_reserve: Array[CharacterSaveData] = []
	for char_save: CharacterSaveData in reserve_members:
		if char_save.fallback_character_name not in orphaned_characters_list:
			valid_reserve.append(char_save)
	reserve_members = valid_reserve
