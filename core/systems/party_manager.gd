extends Node

## PartyManager - Manages the player's party across battles
##
## Full Shining Force-style party system with:
## - Party member CharacterSaveData (inventory, equipment, stats, levels)
## - Recruitment via add_member/remove_member/rejoin_departed_member
## - Maximum party size limits (configurable by mods)
## - Reserve/active member management (Caravan system)

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when an item is transferred between party members
signal item_transferred(from_uid: String, to_uid: String, item_id: String)

## Emitted when a party member's inventory changes
## MED-002: Signal is now emitted when inventory changes
signal member_inventory_changed(character_uid: String)

## Emitted when a party member departs (removed with preserved data)
signal member_departed(character_uid: String, reason: String)

## Emitted when a departed member rejoins the party
signal member_rejoined(character_uid: String)

## Emitted when a new member is added to the party
signal member_added(character: CharacterData)

## Emitted when the active/reserve roster split changes
signal active_roster_changed()

# ============================================================================
# PARTY DATA
# ============================================================================

## Current party members (CharacterData resources)
## Order matters: first member is leader, spawn order follows array order
var party_members: Array[CharacterData] = []

## Runtime save data for each party member, keyed by character_uid
## This stores mutable state (inventory, equipment changes, stat gains)
## Initialized when characters are added to the party
var _member_save_data: Dictionary[String, CharacterSaveData] = {}

## Save data for characters who have departed (died, left, captured, etc.)
## Preserved so they can potentially rejoin or for save game persistence
## Keyed by character_uid
var _departed_save_data: Dictionary[String, CharacterSaveData] = {}

## Maximum ACTIVE party size (goes into battle) - SF2 allows 12
## Can be modified by mods at runtime, but bounds checked
const DEFAULT_MAX_ACTIVE_SIZE: int = 12
const MIN_ACTIVE_SIZE: int = 1
const ABSOLUTE_MAX_ACTIVE_SIZE: int = 30  # Hard limit for engine stability

## Current maximum active size (modifiable at runtime with bounds)
var MAX_ACTIVE_SIZE: int = DEFAULT_MAX_ACTIVE_SIZE

## Maximum party size is unlimited (roster can grow indefinitely)
## This constant is kept for backwards compatibility but no longer enforced
const MAX_PARTY_SIZE: int = 12

## Default spawn formation (relative positions from spawn point)
## Format: Array of Vector2i offsets
## Example: [(0,0), (1,0), (0,1), (1,1)] = 2x2 grid
const DEFAULT_FORMATION: Array[Vector2i] = [
	Vector2i(0, 0),   # Leader position
	Vector2i(1, 0),   # Right of leader
	Vector2i(0, 1),   # Below leader
	Vector2i(1, 1),   # Diagonal from leader
	Vector2i(2, 0),   # Far right
	Vector2i(0, 2),   # Far below
	Vector2i(2, 1),   # Middle right
	Vector2i(1, 2),   # Middle below
]


# ============================================================================
# MOD API: PARTY SIZE CONFIGURATION
# ============================================================================

## Set the maximum active party size (mod API)
## @param new_size: Desired maximum size (will be clamped to valid range)
## @param source_mod_id: Optional mod ID for tracking who changed it
## @return: The actual value set after bounds checking
func set_max_active_size(new_size: int, source_mod_id: String = "") -> int:
	var clamped: int = clampi(new_size, MIN_ACTIVE_SIZE, ABSOLUTE_MAX_ACTIVE_SIZE)

	if clamped != new_size:
		push_warning("PartyManager: Requested max_active_size %d clamped to %d (valid range: %d-%d)%s" % [
			new_size, clamped, MIN_ACTIVE_SIZE, ABSOLUTE_MAX_ACTIVE_SIZE,
			" by mod '%s'" % source_mod_id if not source_mod_id.is_empty() else ""
		])

	var old_size: int = MAX_ACTIVE_SIZE
	var old_active_count: int = get_active_count()
	MAX_ACTIVE_SIZE = clamped

	# If party size decreased, members beyond the limit move to reserves automatically
	# (active/reserve split is index-based, so no data movement needed)
	if clamped < old_size and old_active_count > clamped:
		push_warning("PartyManager: Party size reduced from %d to %d - %d members moved to reserves" % [
			old_size, clamped, old_active_count - clamped
		])

	if clamped != old_size:
		active_roster_changed.emit()

	return clamped


## Reset max active size to default (call when unloading a mod)
func reset_max_active_size() -> void:
	MAX_ACTIVE_SIZE = DEFAULT_MAX_ACTIVE_SIZE


## Get current max active size (for UI display)
func get_max_active_size() -> int:
	return MAX_ACTIVE_SIZE


## Get remaining slots in active party
func get_available_active_slots() -> int:
	return maxi(0, MAX_ACTIVE_SIZE - get_active_count())


# ============================================================================
# PARTY MANAGEMENT
# ============================================================================

## Set the entire party at once
## @param characters: Array of CharacterData resources
## Note: Roster size is unlimited. First MAX_ACTIVE_SIZE are active (battle), rest are reserve.
func set_party(characters: Array[CharacterData]) -> void:
	party_members = characters.duplicate()

	# Ensure hero is always first
	_ensure_hero_is_leader()

	# Create save data for all party members
	for character: CharacterData in party_members:
		_ensure_save_data(character)


## Add a character to the party (roster)
## @param character: CharacterData to add
## @param to_active: If true, insert into active party (if room), else add to reserves
## @return: true if added successfully
func add_member(character: CharacterData, to_active: bool = true) -> bool:
	if character in party_members:
		push_warning("PartyManager: Character '%s' is already in the party" % character.character_name)
		return false
	_insert_member(character, to_active)
	_ensure_save_data(character)
	member_added.emit(character)
	return true


## Remove a character from the party
## @param character: CharacterData to remove
## @return: true if removed successfully, false if not found
func remove_member(character: CharacterData) -> bool:
	# Prevent removing the hero
	if character.is_hero:
		push_error("PartyManager: Cannot remove hero from party! Hero must always be present.")
		return false

	var index: int = party_members.find(character)
	if index == -1:
		push_warning("PartyManager: Cannot remove member, not in party")
		return false

	party_members.remove_at(index)

	# Clean up save data for removed member
	var uid: String = character.get_uid()
	if uid in _member_save_data:
		_member_save_data.erase(uid)

	return true


## Remove a character from the party but preserve their save data
## Use this for story departures (death, capture, leaving) where character may return
## or where we want to track their final state for narrative purposes
## @param character: CharacterData to remove
## @param reason: Why they left ("died", "left", "captured", etc.)
## @return: The preserved CharacterSaveData, or null if removal failed
func remove_member_preserve_data(character: CharacterData, reason: String = "left") -> CharacterSaveData:
	# Prevent removing the hero
	if character.is_hero:
		push_error("PartyManager: Cannot remove hero from party! Hero must always be present.")
		return null

	var index: int = party_members.find(character)
	if index == -1:
		push_warning("PartyManager: Cannot remove member, not in party")
		return null

	var uid: String = character.get_uid()

	# Ensure save data exists before preserving (create from character if missing)
	_ensure_save_data(character)

	# Preserve save data before removal
	var preserved_data: CharacterSaveData = _member_save_data[uid]
	_departed_save_data[uid] = preserved_data
	_member_save_data.erase(uid)

	party_members.remove_at(index)

	# Emit signal for UI/story tracking
	member_departed.emit(uid, reason)

	return preserved_data


## Get save data for a departed character
## @param character_uid: The unique identifier of the departed character
## @return: CharacterSaveData if found, null otherwise
func get_departed_save_data(character_uid: String) -> CharacterSaveData:
	return _departed_save_data.get(character_uid, null)


## Check if a character has departed (is in departed list)
## @param character_uid: The unique identifier to check
## @return: true if character is in departed list
func is_departed(character_uid: String) -> bool:
	return character_uid in _departed_save_data


## Rejoin a departed character to the party
## Restores their preserved save data (levels, equipment, etc.)
## @param character: CharacterData to rejoin
## @param to_active: Whether to add to active party (true) or reserves (false)
## @return: true if rejoined successfully
func rejoin_departed_member(character: CharacterData, to_active: bool = true) -> bool:
	var uid: String = character.get_uid()

	if uid not in _departed_save_data:
		push_warning("PartyManager: Character '%s' is not in departed list" % character.character_name)
		return false

	if character in party_members:
		push_warning("PartyManager: Character '%s' is already in party" % character.character_name)
		return false

	# Restore save data
	var restored_data: CharacterSaveData = _departed_save_data[uid]
	_departed_save_data.erase(uid)
	_member_save_data[uid] = restored_data

	# Reset availability (is_alive is NOT auto-reset - use set_character_status for resurrection)
	restored_data.is_available = true

	_insert_member(character, to_active)
	member_rejoined.emit(uid)

	return true


## Clear the entire party
func clear_party() -> void:
	party_members.clear()
	_member_save_data.clear()
	_departed_save_data.clear()


## Load party from PartyData resource
## @param party_data: PartyData resource to load from
func load_from_party_data(party_data: PartyData) -> void:
	if not party_data:
		push_warning("PartyManager: Cannot load from null PartyData")
		return

	if not party_data.validate():
		push_error("PartyManager: PartyData '%s' failed validation" % party_data.party_name)
		return

	party_members.clear()
	_member_save_data.clear()

	for member_dict: Dictionary in party_data.members:
		if "character" in member_dict and member_dict.character:
			var character: CharacterData = member_dict.character
			party_members.append(character)
			_ensure_save_data(character)

	# Enforce hero-at-position-0 invariant
	_ensure_hero_is_leader()


## Get party size
## @return: Number of characters in party
func get_party_size() -> int:
	return party_members.size()


## Check if party is empty
## @return: true if no party members
func is_empty() -> bool:
	return party_members.is_empty()


## Get party leader (first member)
## @return: CharacterData of leader, or null if no party
func get_leader() -> CharacterData:
	if party_members.is_empty():
		return null
	return party_members[0]


# ============================================================================
# ACTIVE / RESERVE ROSTER MANAGEMENT (SF2-style Caravan system)
# ============================================================================

## Get the active party (first MAX_ACTIVE_SIZE members who go into battle)
## @return: Array of CharacterData for active party members
func get_active_party() -> Array[CharacterData]:
	if party_members.size() <= MAX_ACTIVE_SIZE:
		return party_members.duplicate()
	return party_members.slice(0, MAX_ACTIVE_SIZE)


## Get the reserve party (members beyond MAX_ACTIVE_SIZE, waiting at Caravan)
## @return: Array of CharacterData for reserve party members
func get_reserve_party() -> Array[CharacterData]:
	if party_members.size() <= MAX_ACTIVE_SIZE:
		return []
	return party_members.slice(MAX_ACTIVE_SIZE)


## Get the number of active party members
func get_active_count() -> int:
	return mini(party_members.size(), MAX_ACTIVE_SIZE)


## Get the number of reserve party members
func get_reserve_count() -> int:
	return maxi(0, party_members.size() - MAX_ACTIVE_SIZE)


## Check if active party is full
func is_active_party_full() -> bool:
	return party_members.size() >= MAX_ACTIVE_SIZE


## Swap a character between active and reserve roster
## @param active_index: Index within active party (0 to MAX_ACTIVE_SIZE-1)
## @param reserve_index: Index within reserve party (0-based)
## @return: Dictionary with {success: bool, error: String}
func swap_active_reserve(active_index: int, reserve_index: int) -> Dictionary:
	var error: String = _validate_active_index(active_index)
	if not error.is_empty():
		return _swap_error(error)

	error = _validate_reserve_index(reserve_index)
	if not error.is_empty():
		return _swap_error(error)

	# Hero (slot 0) cannot be swapped out
	if active_index == 0:
		return _swap_error("Cannot swap hero out of active party")

	var reserve_array_index: int = MAX_ACTIVE_SIZE + reserve_index
	_swap_members(active_index, reserve_array_index)

	return _swap_success()


## Move a reserve character to the active party (if room)
## @param reserve_index: Index within reserve party (0-based)
## @return: Dictionary with {success: bool, error: String}
func promote_to_active(reserve_index: int) -> Dictionary:
	var error: String = _validate_reserve_index(reserve_index)
	if not error.is_empty():
		return _swap_error(error)

	if is_active_party_full():
		return _swap_error("Active party is full")

	var reserve_array_index: int = MAX_ACTIVE_SIZE + reserve_index
	var character: CharacterData = party_members[reserve_array_index]
	party_members.remove_at(reserve_array_index)

	var insert_pos: int = get_active_count()
	party_members.insert(insert_pos, character)

	return _swap_success()


## Move an active character to reserves
## @param active_index: Index within active party (0 to MAX_ACTIVE_SIZE-1)
## @return: Dictionary with {success: bool, error: String}
func demote_to_reserve(active_index: int) -> Dictionary:
	var error: String = _validate_active_index(active_index)
	if not error.is_empty():
		return _swap_error(error)

	if active_index == 0:
		return _swap_error("Cannot move hero to reserves")

	var character: CharacterData = party_members[active_index]
	party_members.remove_at(active_index)
	party_members.append(character)

	return _swap_success()


## Swap two positions within the active party
## @param idx1: First index (0 to MAX_ACTIVE_SIZE-1)
## @param idx2: Second index (0 to MAX_ACTIVE_SIZE-1)
## @return: Dictionary with {success: bool, error: String}
func swap_within_active(idx1: int, idx2: int) -> Dictionary:
	var error: String = _validate_active_index(idx1, "Invalid first index")
	if not error.is_empty():
		return _swap_error(error)

	error = _validate_active_index(idx2, "Invalid second index")
	if not error.is_empty():
		return _swap_error(error)

	if idx1 == 0 or idx2 == 0:
		return _swap_error("Cannot swap hero position")

	if idx1 == idx2:
		return _swap_success()

	_swap_members(idx1, idx2)
	return _swap_success()


## Swap two positions within the reserve party
## @param idx1: First index within reserve (0-based)
## @param idx2: Second index within reserve (0-based)
## @return: Dictionary with {success: bool, error: String}
func swap_within_reserve(idx1: int, idx2: int) -> Dictionary:
	var error: String = _validate_reserve_index(idx1, "Invalid first reserve index")
	if not error.is_empty():
		return _swap_error(error)

	error = _validate_reserve_index(idx2, "Invalid second reserve index")
	if not error.is_empty():
		return _swap_error(error)

	if idx1 == idx2:
		return _swap_success()

	var real_idx1: int = MAX_ACTIVE_SIZE + idx1
	var real_idx2: int = MAX_ACTIVE_SIZE + idx2
	_swap_members(real_idx1, real_idx2)

	return _swap_success()


# ============================================================================
# SWAP HELPER FUNCTIONS
# ============================================================================

## Insert a character into the party at the appropriate position
func _insert_member(character: CharacterData, to_active: bool) -> void:
	if to_active and party_members.size() < MAX_ACTIVE_SIZE:
		# Room in active party - add at end of active section
		party_members.append(character)
	else:
		# Active full or reserve requested - add to end of reserves
		party_members.append(character)


## Validate an active party index, returns error message or empty string
func _validate_active_index(index: int, error_msg: String = "Invalid active party index") -> String:
	if index < 0 or index >= get_active_count():
		return error_msg
	return ""


## Validate a reserve party index, returns error message or empty string
func _validate_reserve_index(index: int, error_msg: String = "Invalid reserve party index") -> String:
	if index < 0 or index >= get_reserve_count():
		return error_msg
	return ""


## Swap two members at the given array indices
func _swap_members(idx1: int, idx2: int) -> void:
	var temp: CharacterData = party_members[idx1]
	party_members[idx1] = party_members[idx2]
	party_members[idx2] = temp


## Return a success result dictionary
func _swap_success() -> Dictionary:
	return {"success": true, "error": ""}


## Return an error result dictionary
func _swap_error(error: String) -> Dictionary:
	return {"success": false, "error": error}


# ============================================================================
# HERO MANAGEMENT
# ============================================================================

## Ensure the hero is always at index 0 (leader position)
func _ensure_hero_is_leader() -> void:
	if party_members.is_empty():
		return

	# Find the hero in the party
	var hero_index: int = -1
	for i: int in range(party_members.size()):
		var member: CharacterData = party_members[i]
		if member.is_hero:
			hero_index = i
			break

	# If hero exists but not at index 0, move them there
	if hero_index > 0:
		var hero: CharacterData = party_members[hero_index]
		party_members.remove_at(hero_index)
		party_members.insert(0, hero)
	elif hero_index == -1:
		push_warning("PartyManager: No hero found in party! This may cause issues.")


## Check if the party has a hero
## @return: true if hero is present in party
func has_hero() -> bool:
	for character: CharacterData in party_members:
		if character.is_hero:
			return true
	return false


## Get the hero character from the party
## @return: Hero CharacterData or null if not present
func get_hero() -> CharacterData:
	for character: CharacterData in party_members:
		if character.is_hero:
			return character
	return null


# ============================================================================
# BATTLE SPAWNING
# ============================================================================

## Get party spawn data for BattleManager
## Calculates spawn positions based on spawn point and formation
##
## @param spawn_point: Top-left position where party should spawn (default: Vector2i(2, 2))
## @return: Array of Dictionaries with format:
##          [{character: CharacterData, position: Vector2i}, ...]
func get_battle_spawn_data(spawn_point: Vector2i = Vector2i(2, 2)) -> Array[Dictionary]:
	var spawn_data: Array[Dictionary] = []
	var active_party: Array[CharacterData] = get_active_party()

	for i: int in range(active_party.size()):
		var character: CharacterData = active_party[i]

		# Calculate position using formation offset
		var offset: Vector2i = DEFAULT_FORMATION[i] if i < DEFAULT_FORMATION.size() else Vector2i(i % 3, i / 3)
		var position: Vector2i = spawn_point + offset

		spawn_data.append({
			"character": character,
			"position": position
		})

	return spawn_data


## Get custom spawn data with specific positions
## Useful for battles with predefined spawn points
##
## @param spawn_positions: Array of Vector2i positions (must match party size)
## @return: Array of spawn data dictionaries
func get_custom_spawn_data(spawn_positions: Array[Vector2i]) -> Array[Dictionary]:
	if spawn_positions.size() != party_members.size():
		push_error("PartyManager: Spawn positions (%d) don't match party size (%d)" % [
			spawn_positions.size(),
			party_members.size()
		])
		return []

	var spawn_data: Array[Dictionary] = []

	for i: int in range(party_members.size()):
		var character: CharacterData = party_members[i]
		var spawn_pos: Vector2i = spawn_positions[i]
		spawn_data.append({
			"character": character,
			"position": spawn_pos
		})

	return spawn_data


# ============================================================================
# RUNTIME SAVE DATA ACCESS
# ============================================================================

## Get the CharacterSaveData for a party member by character_uid
## This is used to access inventory, equipment, and other mutable state
## @param character_uid: The unique identifier of the character
## @return: CharacterSaveData or null if character not in party
func get_member_save_data(character_uid: String) -> CharacterSaveData:
	if character_uid.is_empty():
		push_warning("PartyManager: get_member_save_data called with empty character_uid")
		return null

	if character_uid in _member_save_data:
		return _member_save_data[character_uid]

	push_warning("PartyManager: No save data found for character_uid: %s" % character_uid)
	return null


## Ensure a CharacterSaveData exists for the given CharacterData
## Creates one from the template if it doesn't exist
## @param character: CharacterData to ensure save data for
func _ensure_save_data(character: CharacterData) -> void:
	if not character:
		return

	# Auto-generate UID if character doesn't have one (legacy/template characters)
	if character.character_uid.is_empty():
		character.ensure_uid()

	var uid: String = character.character_uid
	if uid.is_empty():
		push_error("PartyManager: Character '%s' failed to generate UID" % character.character_name)
		return

	if uid not in _member_save_data:
		var save_data: CharacterSaveData = CharacterSaveData.new()
		save_data.populate_from_character_data(character)
		_member_save_data[uid] = save_data


## Update a party member's CharacterSaveData
## Used after battles to persist stat changes, inventory, etc.
## @param character_uid: The unique identifier of the character
## @param save_data: The updated CharacterSaveData
func update_member_save_data(character_uid: String, save_data: CharacterSaveData) -> void:
	if character_uid.is_empty():
		push_warning("PartyManager: update_member_save_data called with empty character_uid")
		return

	_member_save_data[character_uid] = save_data


## Remove an item from a party member's inventory
## @param character_uid: The unique identifier of the character
## @param item_id: ID of the item to remove
## @return: true if removed successfully, false if not found or error
func remove_item_from_member(character_uid: String, item_id: String) -> bool:
	var save_data: CharacterSaveData = get_member_save_data(character_uid)
	if not save_data:
		push_warning("PartyManager: Cannot remove item - no save data for character_uid: %s" % character_uid)
		return false

	var result: bool = save_data.remove_item_from_inventory(item_id)
	# MED-002: Emit signal when inventory changes
	if result:
		member_inventory_changed.emit(character_uid)
	return result


## Add an item to a party member's inventory
## @param character_uid: The unique identifier of the character
## @param item_id: ID of the item to add
## @return: true if added successfully, false if full or error
func add_item_to_member(character_uid: String, item_id: String) -> bool:
	var save_data: CharacterSaveData = get_member_save_data(character_uid)
	if not save_data:
		push_warning("PartyManager: Cannot add item - no save data for character_uid: %s" % character_uid)
		return false

	var result: bool = save_data.add_item_to_inventory(item_id)
	# MED-002: Emit signal when inventory changes
	if result:
		member_inventory_changed.emit(character_uid)
	return result


## Transfer an item between two party members
## @param from_uid: Source character's unique identifier
## @param to_uid: Destination character's unique identifier
## @param item_id: ID of the item to transfer
## @return: Dictionary with {success: bool, error: String}
func transfer_item_between_members(from_uid: String, to_uid: String, item_id: String) -> Dictionary:
	if from_uid.is_empty() or to_uid.is_empty():
		return _swap_error("Invalid character UID")
	if item_id.is_empty():
		return _swap_error("Invalid item ID")
	if from_uid == to_uid:
		return _swap_error("Cannot transfer to same character")

	var from_save: CharacterSaveData = get_member_save_data(from_uid)
	var to_save: CharacterSaveData = get_member_save_data(to_uid)

	if not from_save:
		return _swap_error("Source character not found")
	if not to_save:
		return _swap_error("Destination character not found")
	if not from_save.has_item_in_inventory(item_id):
		return _swap_error("Item not in source inventory")

	const DEFAULT_MAX_INVENTORY_SLOTS: int = 4
	var max_slots: int = DEFAULT_MAX_INVENTORY_SLOTS
	if ModLoader and ModLoader.inventory_config:
		max_slots = ModLoader.inventory_config.get_max_slots()

	if to_save.inventory.size() >= max_slots:
		return _swap_error("Destination inventory full")

	if not from_save.remove_item_from_inventory(item_id):
		return _swap_error("Failed to remove from source")

	if not to_save.add_item_to_inventory(item_id):
		from_save.add_item_to_inventory(item_id)  # Rollback
		return _swap_error("Failed to add to destination")

	item_transferred.emit(from_uid, to_uid, item_id)
	member_inventory_changed.emit(from_uid)
	member_inventory_changed.emit(to_uid)
	return _swap_success()


# ============================================================================
# SAVE SYSTEM INTEGRATION
# ============================================================================

## Export party to save data
## Returns runtime CharacterSaveData (with inventory, level-ups, etc.)
## @return: Array of CharacterSaveData representing current party
func export_to_save() -> Array[CharacterSaveData]:
	var save_array: Array[CharacterSaveData] = []

	for character_data: CharacterData in party_members:
		var uid: String = character_data.character_uid
		if uid in _member_save_data:
			# Use runtime save data (has inventory, level-ups, etc.)
			save_array.append(_member_save_data[uid])
		else:
			# Fallback: create fresh save data from template
			var char_save: CharacterSaveData = CharacterSaveData.new()
			char_save.populate_from_character_data(character_data)
			save_array.append(char_save)

	return save_array


## Import party from save data
## Loads characters from CharacterSaveData, resolving them from ModRegistry
## @param saved_characters: Array of CharacterSaveData to load
func import_from_save(saved_characters: Array[CharacterSaveData]) -> void:
	party_members.clear()
	_member_save_data.clear()

	for char_save: CharacterSaveData in saved_characters:
		# Try to resolve CharacterData from ModRegistry
		var character_data: CharacterData = _resolve_character_from_save(char_save)

		if character_data:
			party_members.append(character_data)
			# Store the imported save data (preserves inventory, equipment, levels)
			_member_save_data[character_data.character_uid] = char_save
		else:
			push_warning("PartyManager: Failed to import character '%s' from mod '%s'" % [
				char_save.fallback_character_name,
				char_save.character_mod_id
			])

	# Ensure hero is at the front of the party
	_ensure_hero_is_leader()


## Resolve CharacterData from save data
## Attempts to load character from ModRegistry, with fallback handling
## @param char_save: CharacterSaveData to resolve
## @return: CharacterData if found, null if mod missing
func _resolve_character_from_save(char_save: CharacterSaveData) -> CharacterData:
	# Try to get from ModRegistry (note: ModRegistry doesn't filter by mod_id in get_resource)
	var resource: Resource = ModLoader.registry.get_resource(
		"character",
		char_save.character_resource_id
	)
	var character_data: CharacterData = resource as CharacterData if resource is CharacterData else null

	if character_data:
		return character_data

	# Character not found - mod might be missing
	if char_save.character_mod_id in ["_base_game", "base_game"]:
		push_error("PartyManager: CRITICAL - Base game character missing: %s" % char_save.character_resource_id)
		return null

	# Optional mod character missing
	push_warning("PartyManager: Character '%s' from mod '%s' not found (mod may be removed)" % [
		char_save.fallback_character_name,
		char_save.character_mod_id
	])

	# TODO Phase 2: Create placeholder character from fallback data
	# For now, just return null and skip this character
	return null


## Export departed members to save data
## Returns CharacterSaveData for all characters who have left/died
## @return: Array of CharacterSaveData representing departed members
func export_departed_to_save() -> Array[CharacterSaveData]:
	var save_array: Array[CharacterSaveData] = []

	for uid: String in _departed_save_data:
		var departed_data: CharacterSaveData = _departed_save_data[uid]
		save_array.append(departed_data)

	return save_array


## Import departed members from save data
## Restores the departed character tracking from a save file
## @param saved_departed: Array of CharacterSaveData for departed members
func import_departed_from_save(saved_departed: Array[CharacterSaveData]) -> void:
	_departed_save_data.clear()

	for char_save: CharacterSaveData in saved_departed:
		# We don't need to resolve CharacterData for departed - just store the save data
		# The CharacterData will be resolved if/when they rejoin
		var uid: String = ""

		# Try to get UID from the save data or resolve from registry
		var character_data: CharacterData = _resolve_character_from_save(char_save)
		if character_data:
			uid = character_data.character_uid
		else:
			# Fallback: use resource_id as key (won't match if mod is missing)
			uid = char_save.character_resource_id
			push_warning("PartyManager: Departed character '%s' from mod '%s' not found - storing with fallback key" % [
				char_save.fallback_character_name,
				char_save.character_mod_id
			])

		if not uid.is_empty():
			_departed_save_data[uid] = char_save


## Clear departed members list
func clear_departed() -> void:
	_departed_save_data.clear()


# ============================================================================
# FUTURE EXPANSION NOTES
# ============================================================================

## Future enhancements (nice-to-have):
## - Character loyalty/morale system
## - Party formation editor UI
## - Pre-battle party selection screen
## - Create placeholder characters when mod removed (line 806)
