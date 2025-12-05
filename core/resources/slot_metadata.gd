class_name SlotMetadata
extends Resource

# Note: SaveData will be available at runtime via class_name
# ModLoader is an autoload, available globally

## SlotMetadata - Quick preview data for save slot menu
##
## Lightweight data structure for displaying save slot information
## without loading the full SaveData file.
##
## Stored separately in user://saves/slots.meta as JSON array.

# ============================================================================
# SLOT IDENTIFICATION
# ============================================================================

## Slot number (1, 2, 3)
@export var slot_number: int = 1

## Is this slot occupied?
@export var is_occupied: bool = false

# ============================================================================
# QUICK DISPLAY INFO
# ============================================================================

## Party leader name (for slot preview)
@export var party_leader_name: String = ""

## Current location/chapter (for slot preview)
@export var current_location: String = ""

## Average party level (for slot preview)
@export var average_level: int = 1

## Total playtime in seconds
@export var playtime_seconds: int = 0

## When this save was last played (Unix timestamp)
@export var last_played_timestamp: int = 0

# ============================================================================
# MOD COMPATIBILITY WARNING
# ============================================================================

## If true, this save has mod mismatches (missing or changed mods)
## Display warning icon in save slot menu
@export var has_mod_mismatch: bool = false


# ============================================================================
# POPULATION
# ============================================================================

## Populate from SaveData
## Extracts only the necessary preview information
## @param save_data: Full SaveData to extract preview from
func populate_from_save_data(save_data: SaveData) -> void:
	if not save_data:
		push_error("SlotMetadata: Cannot populate from null SaveData")
		return

	slot_number = save_data.slot_number
	is_occupied = true

	# Get party leader name
	if not save_data.party_members.is_empty():
		party_leader_name = save_data.party_members[0].fallback_character_name
	else:
		party_leader_name = "Unknown"

	# Get location
	current_location = save_data.current_location

	# Calculate average level
	average_level = save_data._calculate_average_level()

	# Copy timestamps
	playtime_seconds = save_data.playtime_seconds
	last_played_timestamp = save_data.last_played_timestamp

	# Check mod compatibility (basic check)
	has_mod_mismatch = _check_mod_compatibility(save_data.active_mods)


## Check if mods from save match currently loaded mods
## @param saved_mods: Array of {mod_id: String, version: String} from save
## @return: true if any mods are missing or version mismatch
func _check_mod_compatibility(saved_mods: Array[Dictionary]) -> bool:
	for mod_dict: Dictionary in saved_mods:
		if "mod_id" not in mod_dict:
			continue

		var mod_id: String = mod_dict.mod_id

		# Check if mod is loaded
		var is_loaded: bool = false
		for manifest: ModManifest in ModLoader.loaded_mods:
			if manifest.mod_id == mod_id:
				is_loaded = true

				# Check version mismatch (optional - may be too strict)
				if "version" in mod_dict:
					var saved_version: String = mod_dict.version
					if manifest.version != saved_version:
						return true  # Version mismatch

				break

		# If mod is critical and not loaded, mark as mismatch
		if not is_loaded:
			if mod_id in ["_base_game", "base_game"]:
				return true  # Critical mod missing
			else:
				return true  # Optional mod missing (could be relaxed)

	return false


# ============================================================================
# SERIALIZATION
# ============================================================================

## Serialize to Dictionary for JSON export
## @return: Dictionary representation
func serialize_to_dict() -> Dictionary:
	return {
		"slot_number": slot_number,
		"is_occupied": is_occupied,
		"party_leader_name": party_leader_name,
		"current_location": current_location,
		"average_level": average_level,
		"playtime_seconds": playtime_seconds,
		"last_played_timestamp": last_played_timestamp,
		"has_mod_mismatch": has_mod_mismatch
	}


## Deserialize from Dictionary (loaded from JSON)
## @param data: Dictionary from JSON
func deserialize_from_dict(data: Dictionary) -> void:
	if "slot_number" in data:
		slot_number = data.slot_number
	if "is_occupied" in data:
		is_occupied = data.is_occupied
	if "party_leader_name" in data:
		party_leader_name = data.party_leader_name
	if "current_location" in data:
		current_location = data.current_location
	if "average_level" in data:
		average_level = data.average_level
	if "playtime_seconds" in data:
		playtime_seconds = data.playtime_seconds
	if "last_played_timestamp" in data:
		last_played_timestamp = data.last_played_timestamp
	if "has_mod_mismatch" in data:
		has_mod_mismatch = data.has_mod_mismatch


# ============================================================================
# DISPLAY HELPERS
# ============================================================================

## Format playtime as HH:MM:SS
## @return: Formatted playtime string
func get_playtime_string() -> String:
	var hours: int = playtime_seconds / 3600
	var minutes: int = (playtime_seconds % 3600) / 60
	var seconds: int = playtime_seconds % 60

	return "%02d:%02d:%02d" % [hours, minutes, seconds]


## Format last played timestamp as readable date
## @return: Formatted date string
func get_last_played_string() -> String:
	if last_played_timestamp == 0:
		return "Never"

	var datetime: Dictionary = Time.get_datetime_dict_from_unix_time(last_played_timestamp)

	return "%04d-%02d-%02d %02d:%02d" % [
		datetime.year,
		datetime.month,
		datetime.day,
		datetime.hour,
		datetime.minute
	]


## Get display string for save slot menu
## @return: Single-line summary
func get_display_string() -> String:
	if not is_occupied:
		return "Empty Slot"

	var warning: String = " ⚠" if has_mod_mismatch else ""
	return "%s - Lv.%d - %s - %s%s" % [
		party_leader_name,
		average_level,
		current_location,
		get_playtime_string(),
		warning
	]
