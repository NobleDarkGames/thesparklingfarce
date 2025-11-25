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
@export var save_version: int = 1

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
# CAMPAIGN PROGRESS
# ============================================================================

## Current campaign chapter/location
## Example: "chapter_1", "headquarters", "battle_5"
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

## Items in inventory
## Format: [{item_id: String, mod_id: String, quantity: int}]
@export var inventory: Array[Dictionary] = []

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
		"current_location": current_location,
		"story_flags": story_flags.duplicate(),
		"completed_battles": completed_battles.duplicate(),
		"available_battles": available_battles.duplicate(),
		"max_party_size": max_party_size,
		"gold": gold,
		"inventory": inventory.duplicate(),
		"total_battles": total_battles,
		"battles_won": battles_won,
		"total_enemies_defeated": total_enemies_defeated,
		"total_damage_dealt": total_damage_dealt,
		"total_healing_done": total_healing_done,
	}

	# Serialize party members
	var party_array: Array = []
	for char_save: CharacterSaveData in party_members:
		party_array.append(char_save.serialize_to_dict())
	data["party_members"] = party_array

	# Serialize reserve members
	var reserve_array: Array = []
	for char_save: CharacterSaveData in reserve_members:
		reserve_array.append(char_save.serialize_to_dict())
	data["reserve_members"] = reserve_array

	return data


## Deserialize save data from Dictionary (loaded from JSON)
## @param data: Dictionary loaded from JSON file
func deserialize_from_dict(data: Dictionary) -> void:
	if "save_version" in data:
		save_version = data.save_version
	if "created_timestamp" in data:
		created_timestamp = data.created_timestamp
	if "last_played_timestamp" in data:
		last_played_timestamp = data.last_played_timestamp
	if "playtime_seconds" in data:
		playtime_seconds = data.playtime_seconds
	if "slot_number" in data:
		slot_number = data.slot_number
	if "active_mods" in data:
		active_mods.clear()
		for mod_dict: Dictionary in data.active_mods:
			active_mods.append(mod_dict)
	if "game_version" in data:
		game_version = data.game_version
	if "current_location" in data:
		current_location = data.current_location
	if "story_flags" in data:
		story_flags = data.story_flags.duplicate()
	if "completed_battles" in data:
		completed_battles.clear()
		for battle_id: String in data.completed_battles:
			completed_battles.append(battle_id)
	if "available_battles" in data:
		available_battles.clear()
		for battle_id: String in data.available_battles:
			available_battles.append(battle_id)
	if "max_party_size" in data:
		max_party_size = data.max_party_size
	if "gold" in data:
		gold = data.gold
	if "inventory" in data:
		inventory.clear()
		for item_dict: Dictionary in data.inventory:
			inventory.append(item_dict)
	if "total_battles" in data:
		total_battles = data.total_battles
	if "battles_won" in data:
		battles_won = data.battles_won
	if "total_enemies_defeated" in data:
		total_enemies_defeated = data.total_enemies_defeated
	if "total_damage_dealt" in data:
		total_damage_dealt = data.total_damage_dealt
	if "total_healing_done" in data:
		total_healing_done = data.total_healing_done

	# Deserialize party members
	party_members.clear()
	if "party_members" in data:
		for char_dict: Dictionary in data.party_members:
			var char_save: CharacterSaveData = CharacterSaveData.new()
			char_save.deserialize_from_dict(char_dict)
			party_members.append(char_save)

	# Deserialize reserve members
	reserve_members.clear()
	if "reserve_members" in data:
		for char_dict: Dictionary in data.reserve_members:
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
		leader_name = party_members[0].fallback_character_name

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
