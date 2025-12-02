extends Node

## PartyManager - Manages the player's party across battles
##
## Responsibilities:
## - Store party members (CharacterData references)
## - Track party composition and order
## - Provide party data to BattleManager for spawning
##
## This is a lightweight version for Phase 3 testing.
## TODO Phase 4+: Expand to full Shining Force-style party system:
## - Party member inventory management
## - Permanent stat changes (level-ups persist)
## - Party member recruitment
## - Maximum party size limits
## - Reserve/active member management

# ============================================================================
# PARTY DATA
# ============================================================================

## Current party members (CharacterData resources)
## Order matters: first member is leader, spawn order follows array order
var party_members: Array[CharacterData] = []

## Maximum party size (Shining Force allows 12)
## For now, we'll use a smaller limit for testing
const MAX_PARTY_SIZE: int = 8

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
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	pass


# ============================================================================
# PARTY MANAGEMENT
# ============================================================================

## Set the entire party at once
## @param characters: Array of CharacterData resources
func set_party(characters: Array[CharacterData]) -> void:
	if characters.size() > MAX_PARTY_SIZE:
		push_warning("PartyManager: Party size (%d) exceeds maximum (%d), truncating" % [
			characters.size(),
			MAX_PARTY_SIZE
		])
		party_members = characters.slice(0, MAX_PARTY_SIZE)
	else:
		party_members = characters.duplicate()

	# Ensure hero is always first
	_ensure_hero_is_leader()


## Add a character to the party
## @param character: CharacterData to add
## @return: true if added successfully, false if party full
func add_member(character: CharacterData) -> bool:
	if party_members.size() >= MAX_PARTY_SIZE:
		push_warning("PartyManager: Cannot add member, party full (%d/%d)" % [
			party_members.size(),
			MAX_PARTY_SIZE
		])
		return false

	party_members.append(character)
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
	return true


## Clear the entire party
func clear_party() -> void:
	party_members.clear()


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

	for member_dict in party_data.members:
		if "character" in member_dict and member_dict.character:
			party_members.append(member_dict.character)


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
# HERO MANAGEMENT
# ============================================================================

## Ensure the hero is always at index 0 (leader position)
## This is called internally whenever the party composition changes
func _ensure_hero_is_leader() -> void:
	if party_members.is_empty():
		return

	# Find the hero in the party
	var hero_index: int = -1
	for i in range(party_members.size()):
		if party_members[i].is_hero:
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
	for character in party_members:
		if character.is_hero:
			return true
	return false


## Get the hero character from the party
## @return: Hero CharacterData or null if not present
func get_hero() -> CharacterData:
	for character in party_members:
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

	for i in range(party_members.size()):
		var character: CharacterData = party_members[i]

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

	for i in range(party_members.size()):
		spawn_data.append({
			"character": party_members[i],
			"position": spawn_positions[i]
		})

	return spawn_data


# ============================================================================
# SAVE SYSTEM INTEGRATION
# ============================================================================

## Export party to save data
## Converts current party members to CharacterSaveData for saving
## @return: Array of CharacterSaveData representing current party
func export_to_save() -> Array[CharacterSaveData]:
	var save_array: Array[CharacterSaveData] = []

	for character_data: CharacterData in party_members:
		var char_save: CharacterSaveData = CharacterSaveData.new()
		char_save.populate_from_character_data(character_data)
		save_array.append(char_save)

	return save_array


## Import party from save data
## Loads characters from CharacterSaveData, resolving them from ModRegistry
## @param saved_characters: Array of CharacterSaveData to load
func import_from_save(saved_characters: Array[CharacterSaveData]) -> void:
	party_members.clear()

	for char_save: CharacterSaveData in saved_characters:
		# Try to resolve CharacterData from ModRegistry
		var character_data: CharacterData = _resolve_character_from_save(char_save)

		if character_data:
			party_members.append(character_data)
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
	var character_data: Resource = ModLoader.registry.get_resource(
		"character",
		char_save.character_resource_id
	)

	if character_data and character_data is CharacterData:
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


# ============================================================================
# FUTURE EXPANSION NOTES
# ============================================================================

## TODO Phase 4+: Add these features for full Shining Force experience
##
## Party Persistence:
## - Apply saved stats to characters (level, XP, equipment)
## - Track which characters have acted in current chapter
##
## Recruitment:
## - Add characters during story progression
## - Handle character death (permanent or temporary)
## - Character loyalty/morale system
##
## Management:
## - Active party (in battle) vs reserve (headquarters)
## - Party formation editor
## - Pre-battle party selection screen
##
## Integration:
## - Create placeholder characters for missing mods
## - Link with DialogueManager for recruitment events
## - Link with HeadquartersManager for party management UI
