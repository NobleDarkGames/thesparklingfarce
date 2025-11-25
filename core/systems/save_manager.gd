extends Node

## SaveManager - Autoload singleton for game save system
##
## Manages all save file operations: save, load, delete, copy
## Stores saves in user://saves/ directory as JSON files
##
## File Structure:
## - user://saves/slot_1.sav (SaveData as JSON)
## - user://saves/slot_2.sav
## - user://saves/slot_3.sav
## - user://saves/slots.meta (Array of SlotMetadata as JSON)
##
## Usage:
##   SaveManager.save_to_slot(1, save_data)
##   var loaded_save = SaveManager.load_from_slot(1)
##   SaveManager.delete_slot(2)
##   SaveManager.copy_slot(1, 3)

# ============================================================================
# CONSTANTS
# ============================================================================

const SAVE_DIRECTORY: String = "user://saves/"
const SLOT_FILE_PATTERN: String = "slot_%d.sav"
const METADATA_FILE: String = "slots.meta"
const MAX_SLOTS: int = 3

# ============================================================================
# SIGNALS
# ============================================================================

signal save_completed(slot_number: int, success: bool)
signal save_loaded(slot_number: int, save_data: SaveData)
signal save_deleted(slot_number: int)
signal save_copied(from_slot: int, to_slot: int)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	print("SaveManager: Initializing...")
	_ensure_save_directory_exists()
	_initialize_metadata_if_missing()
	print("SaveManager: Ready")


## Ensure save directory exists
func _ensure_save_directory_exists() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if not dir:
		push_error("SaveManager: Failed to open user:// directory")
		return

	if not dir.dir_exists("saves"):
		var err: Error = dir.make_dir("saves")
		if err != OK:
			push_error("SaveManager: Failed to create saves directory: %d" % err)
		else:
			print("SaveManager: Created saves directory")


## Initialize metadata file if it doesn't exist
func _initialize_metadata_if_missing() -> void:
	var metadata_path: String = SAVE_DIRECTORY.path_join(METADATA_FILE)

	if not FileAccess.file_exists(metadata_path):
		print("SaveManager: Initializing metadata file")

		# Create empty metadata for all slots
		var metadata_array: Array[SlotMetadata] = []
		for i: int in range(MAX_SLOTS):
			var meta: SlotMetadata = SlotMetadata.new()
			meta.slot_number = i + 1
			meta.is_occupied = false
			metadata_array.append(meta)

		_save_metadata_file(metadata_array)


# ============================================================================
# SAVE OPERATIONS
# ============================================================================

## Save game data to specified slot
## @param slot_number: Slot number (1-3)
## @param save_data: SaveData to save
## @return: true if successful, false if failed
func save_to_slot(slot_number: int, save_data: SaveData) -> bool:
	if not _validate_slot_number(slot_number):
		return false

	if not save_data:
		push_error("SaveManager: Cannot save null SaveData")
		save_completed.emit(slot_number, false)
		return false

	# Validate save data
	if not save_data.validate():
		push_error("SaveManager: SaveData validation failed")
		save_completed.emit(slot_number, false)
		return false

	# Update slot number in save data
	save_data.slot_number = slot_number

	# Serialize to JSON
	var save_dict: Dictionary = save_data.serialize_to_dict()
	var json_string: String = JSON.stringify(save_dict, "\t")

	# Write to file
	var file_path: String = _get_slot_file_path(slot_number)
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)

	if not file:
		push_error("SaveManager: Failed to open file for writing: %s" % file_path)
		save_completed.emit(slot_number, false)
		return false

	file.store_string(json_string)
	file.close()

	print("SaveManager: Saved game to slot %d" % slot_number)

	# Update metadata
	_update_metadata_for_slot(slot_number, save_data)

	save_completed.emit(slot_number, true)
	return true


## Load game data from specified slot
## @param slot_number: Slot number (1-3)
## @return: SaveData if successful, null if failed
func load_from_slot(slot_number: int) -> SaveData:
	if not _validate_slot_number(slot_number):
		return null

	if not is_slot_occupied(slot_number):
		push_warning("SaveManager: Slot %d is empty, cannot load" % slot_number)
		return null

	# Read file
	var file_path: String = _get_slot_file_path(slot_number)
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)

	if not file:
		push_error("SaveManager: Failed to open file for reading: %s" % file_path)
		return null

	var json_string: String = file.get_as_text()
	file.close()

	# Parse JSON
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)

	if parse_result != OK:
		push_error("SaveManager: Failed to parse JSON from slot %d: %s" % [
			slot_number,
			json.get_error_message()
		])
		return null

	var save_dict: Dictionary = json.data

	# Deserialize to SaveData
	var save_data: SaveData = SaveData.new()
	save_data.deserialize_from_dict(save_dict)

	# Validate loaded data
	if not save_data.validate():
		push_error("SaveManager: Loaded SaveData from slot %d failed validation" % slot_number)
		return null

	print("SaveManager: Loaded game from slot %d" % slot_number)

	save_loaded.emit(slot_number, save_data)
	return save_data


## Delete save from specified slot
## @param slot_number: Slot number (1-3)
## @return: true if successful, false if failed
func delete_slot(slot_number: int) -> bool:
	if not _validate_slot_number(slot_number):
		return false

	if not is_slot_occupied(slot_number):
		push_warning("SaveManager: Slot %d is already empty" % slot_number)
		return true  # Not an error

	# Delete file
	var file_path: String = _get_slot_file_path(slot_number)
	var dir: DirAccess = DirAccess.open(SAVE_DIRECTORY)

	if not dir:
		push_error("SaveManager: Failed to open saves directory")
		return false

	var err: Error = dir.remove(file_path)
	if err != OK:
		push_error("SaveManager: Failed to delete file: %s (error %d)" % [file_path, err])
		return false

	print("SaveManager: Deleted save from slot %d" % slot_number)

	# Update metadata
	_mark_slot_as_empty(slot_number)

	save_deleted.emit(slot_number)
	return true


## Copy save from one slot to another
## @param from_slot: Source slot number (1-3)
## @param to_slot: Destination slot number (1-3)
## @return: true if successful, false if failed
func copy_slot(from_slot: int, to_slot: int) -> bool:
	if not _validate_slot_number(from_slot) or not _validate_slot_number(to_slot):
		return false

	if from_slot == to_slot:
		push_warning("SaveManager: Cannot copy slot to itself")
		return false

	if not is_slot_occupied(from_slot):
		push_error("SaveManager: Source slot %d is empty, cannot copy" % from_slot)
		return false

	# Load from source
	var save_data: SaveData = load_from_slot(from_slot)
	if not save_data:
		return false

	# Save to destination (this will overwrite if destination is occupied)
	save_data.slot_number = to_slot  # Update slot number
	var success: bool = save_to_slot(to_slot, save_data)

	if success:
		print("SaveManager: Copied slot %d to slot %d" % [from_slot, to_slot])
		save_copied.emit(from_slot, to_slot)

	return success


# ============================================================================
# METADATA OPERATIONS
# ============================================================================

## Get metadata for a specific slot
## @param slot_number: Slot number (1-3)
## @return: SlotMetadata for the slot
func get_slot_metadata(slot_number: int) -> SlotMetadata:
	if not _validate_slot_number(slot_number):
		var empty_meta: SlotMetadata = SlotMetadata.new()
		empty_meta.slot_number = slot_number
		empty_meta.is_occupied = false
		return empty_meta

	var all_metadata: Array[SlotMetadata] = _load_metadata_file()

	for meta: SlotMetadata in all_metadata:
		if meta.slot_number == slot_number:
			return meta

	# If not found, return empty metadata
	var meta: SlotMetadata = SlotMetadata.new()
	meta.slot_number = slot_number
	meta.is_occupied = false
	return meta


## Get metadata for all slots
## @return: Array of SlotMetadata (size 3)
func get_all_slot_metadata() -> Array[SlotMetadata]:
	return _load_metadata_file()


## Check if a slot is occupied
## @param slot_number: Slot number (1-3)
## @return: true if slot has a save file
func is_slot_occupied(slot_number: int) -> bool:
	if not _validate_slot_number(slot_number):
		return false

	var file_path: String = _get_slot_file_path(slot_number)
	return FileAccess.file_exists(file_path)


# ============================================================================
# METADATA FILE OPERATIONS
# ============================================================================

## Load metadata file
## @return: Array of SlotMetadata
func _load_metadata_file() -> Array[SlotMetadata]:
	var metadata_path: String = SAVE_DIRECTORY.path_join(METADATA_FILE)

	if not FileAccess.file_exists(metadata_path):
		push_warning("SaveManager: Metadata file missing, reinitializing")
		_initialize_metadata_if_missing()

	var file: FileAccess = FileAccess.open(metadata_path, FileAccess.READ)
	if not file:
		push_error("SaveManager: Failed to open metadata file")
		return _create_empty_metadata_array()

	var json_string: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)

	if parse_result != OK:
		push_error("SaveManager: Failed to parse metadata JSON: %s" % json.get_error_message())
		return _create_empty_metadata_array()

	var metadata_array: Array[SlotMetadata] = []
	for meta_dict: Dictionary in json.data:
		var meta: SlotMetadata = SlotMetadata.new()
		meta.deserialize_from_dict(meta_dict)
		metadata_array.append(meta)

	return metadata_array


## Save metadata file
## @param metadata_array: Array of SlotMetadata to save
func _save_metadata_file(metadata_array: Array[SlotMetadata]) -> void:
	var metadata_path: String = SAVE_DIRECTORY.path_join(METADATA_FILE)

	# Serialize to array of dictionaries
	var dict_array: Array = []
	for meta: SlotMetadata in metadata_array:
		dict_array.append(meta.serialize_to_dict())

	var json_string: String = JSON.stringify(dict_array, "\t")

	var file: FileAccess = FileAccess.open(metadata_path, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Failed to open metadata file for writing")
		return

	file.store_string(json_string)
	file.close()


## Update metadata for a specific slot
## @param slot_number: Slot number (1-3)
## @param save_data: SaveData to extract metadata from
func _update_metadata_for_slot(slot_number: int, save_data: SaveData) -> void:
	var all_metadata: Array[SlotMetadata] = _load_metadata_file()

	# Find or create metadata for this slot
	var slot_meta: SlotMetadata = null
	for meta: SlotMetadata in all_metadata:
		if meta.slot_number == slot_number:
			slot_meta = meta
			break

	if not slot_meta:
		slot_meta = SlotMetadata.new()
		slot_meta.slot_number = slot_number
		all_metadata.append(slot_meta)

	# Populate from save data
	slot_meta.populate_from_save_data(save_data)

	# Save updated metadata
	_save_metadata_file(all_metadata)


## Mark slot as empty in metadata
## @param slot_number: Slot number (1-3)
func _mark_slot_as_empty(slot_number: int) -> void:
	var all_metadata: Array[SlotMetadata] = _load_metadata_file()

	for meta: SlotMetadata in all_metadata:
		if meta.slot_number == slot_number:
			meta.is_occupied = false
			meta.party_leader_name = ""
			meta.current_location = ""
			meta.average_level = 1
			meta.playtime_seconds = 0
			meta.last_played_timestamp = 0
			meta.has_mod_mismatch = false
			break

	_save_metadata_file(all_metadata)


## Create empty metadata array for all slots
## @return: Array of empty SlotMetadata
func _create_empty_metadata_array() -> Array[SlotMetadata]:
	var metadata_array: Array[SlotMetadata] = []

	for i: int in range(MAX_SLOTS):
		var meta: SlotMetadata = SlotMetadata.new()
		meta.slot_number = i + 1
		meta.is_occupied = false
		metadata_array.append(meta)

	return metadata_array


# ============================================================================
# UTILITY METHODS
# ============================================================================

## Validate slot number
## @param slot_number: Slot number to validate
## @return: true if valid (1-3), false otherwise
func _validate_slot_number(slot_number: int) -> bool:
	if slot_number < 1 or slot_number > MAX_SLOTS:
		push_error("SaveManager: Invalid slot number: %d (must be 1-%d)" % [slot_number, MAX_SLOTS])
		return false
	return true


## Get file path for a slot
## @param slot_number: Slot number (1-3)
## @return: Full file path string
func _get_slot_file_path(slot_number: int) -> String:
	var filename: String = SLOT_FILE_PATTERN % slot_number
	return SAVE_DIRECTORY.path_join(filename)


# ============================================================================
# DEBUG METHODS
# ============================================================================

## Print all slot metadata (for debugging)
func print_all_slots() -> void:
	print("SaveManager: Slot Status:")
	var all_metadata: Array[SlotMetadata] = get_all_slot_metadata()

	for meta: SlotMetadata in all_metadata:
		if meta.is_occupied:
			print("  Slot %d: %s" % [meta.slot_number, meta.get_display_string()])
		else:
			print("  Slot %d: Empty" % meta.slot_number)
