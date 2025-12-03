class_name CharacterSaveData
extends Resource

## CharacterSaveData - Persistent character state for saves
##
## Stores character stats, equipment, and abilities that persist across battles.
## References the base CharacterData template by mod_id + resource_id.
##
## Design Philosophy:
## - CharacterData = Immutable template (base stats, starting level)
## - CharacterSaveData = Mutable instance (current level, XP, equipment)
##
## This allows the same CharacterData template to be used for multiple instances,
## while also supporting campaign progression where characters level up.

# ============================================================================
# CHARACTER REFERENCE
# ============================================================================

## Reference to base CharacterData (mod_id + resource_id)
## Used to load the original character template from ModRegistry
@export var character_mod_id: String = ""
@export var character_resource_id: String = ""

## Fallback data if base CharacterData is missing (mod removed)
## Allows save to load even if mod is no longer available
@export var fallback_character_name: String = ""
@export var fallback_class_name: String = ""

# ============================================================================
# PERSISTENT STATS (Override CharacterData base stats)
# ============================================================================

## Current level (after leveling up from battles)
@export var level: int = 1

## Current experience points
@export var current_xp: int = 0

## Current and maximum hit points
@export var current_hp: int = 10
@export var max_hp: int = 10

## Current and maximum magic points
@export var current_mp: int = 5
@export var max_mp: int = 5

## Combat stats (after level-ups and stat growth)
@export var strength: int = 5
@export var defense: int = 5
@export var agility: int = 5
@export var intelligence: int = 5
@export var luck: int = 5

# ============================================================================
# EQUIPMENT (Persistent across battles)
# ============================================================================

## Equipped items (by mod_id + resource_id)
## Format: [{slot: String, mod_id: String, item_id: String, curse_broken: bool}]
## Slots (default SF layout): "weapon", "ring_1", "ring_2", "accessory"
## curse_broken: If true, a cursed item can now be unequipped (curse was removed)
@export var equipped_items: Array[Dictionary] = []

## Inventory - items the character is carrying but not equipped
## Format: Array of item IDs (duplicates allowed, supports 4 slots by default)
## Example: ["healing_herb", "healing_herb", "antidote", "power_ring"]
@export var inventory: Array[String] = []

# ============================================================================
# ABILITIES (Learned abilities persist)
# ============================================================================

## Learned abilities (by mod_id + resource_id)
## Format: [{mod_id: String, ability_id: String}]
@export var learned_abilities: Array[Dictionary] = []

# ============================================================================
# STATUS (For campaign persistence)
# ============================================================================

## If character is alive (for permadeath scenarios - future feature)
@export var is_alive: bool = true

## If character is available (not temporarily unavailable due to story)
@export var is_available: bool = true

## If this character is the primary Hero/protagonist
## Hero cannot be removed from party and is always the leader
@export var is_hero: bool = false

## Recruitment chapter (when they joined the party)
@export var recruitment_chapter: String = ""

# ============================================================================
# PROMOTION TRACKING
# ============================================================================

## Total levels earned across all promotions (for ability learning)
## Spells in SF2 are learned at "cumulative levels" not current level
@export var cumulative_level: int = 1

## Number of times this character has been promoted
@export var promotion_count: int = 0

## Current class (may differ from CharacterData's starting class after promotion)
## Stored as mod_id + resource_id for mod-safe loading
@export var current_class_mod_id: String = ""
@export var current_class_resource_id: String = ""


# ============================================================================
# INITIALIZATION
# ============================================================================

## Populate from a CharacterData template
## Used when starting a new game or recruiting a new character
## @param character: CharacterData template to copy from
func populate_from_character_data(character: CharacterData) -> void:
	if not character:
		push_error("CharacterSaveData: Cannot populate from null CharacterData")
		return

	# Get mod_id and resource_id from ModRegistry
	character_mod_id = _get_mod_id_for_resource(character)
	character_resource_id = _get_resource_id_for_resource(character)

	# Fallback data
	fallback_character_name = character.character_name
	if character.character_class:
		fallback_class_name = character.character_class.display_name
	else:
		fallback_class_name = "Unknown"

	# Copy base stats
	level = character.starting_level
	current_xp = 0

	max_hp = character.base_hp
	current_hp = max_hp

	max_mp = character.base_mp
	current_mp = max_mp

	strength = character.base_strength
	defense = character.base_defense
	agility = character.base_agility
	intelligence = character.base_intelligence
	luck = character.base_luck

	# Copy starting equipment
	equipped_items.clear()
	for item: ItemData in character.starting_equipment:
		if item:
			equipped_items.append({
				"slot": item.equipment_slot if not item.equipment_slot.is_empty() else "weapon",
				"mod_id": _get_mod_id_for_resource(item),
				"item_id": _get_resource_id_for_resource(item),
				"curse_broken": false  # Freshly equipped items have unbroken curses
			})

	# Copy starting inventory
	inventory.clear()
	for item_id: String in character.starting_inventory:
		if not item_id.is_empty():
			inventory.append(item_id)

	# Start with no learned abilities (will gain through leveling)
	learned_abilities.clear()

	# Status
	is_alive = true
	is_available = true
	is_hero = character.is_hero
	recruitment_chapter = ""


## Populate from a Unit instance (in battle)
## Used when saving during/after a battle
## @param unit: Unit node with current battle stats
func populate_from_unit(unit: Unit) -> void:
	if not unit:
		push_error("CharacterSaveData: Cannot populate from null Unit")
		return

	# Get base character reference
	var char_data: CharacterData = unit.character_data
	if char_data:
		character_mod_id = _get_mod_id_for_resource(char_data)
		character_resource_id = _get_resource_id_for_resource(char_data)
		fallback_character_name = char_data.character_name
		if char_data.character_class:
			fallback_class_name = char_data.character_class.display_name
	else:
		push_warning("CharacterSaveData: Unit has no CharacterData reference")

	# Copy current stats from unit
	if unit.stats:
		level = unit.stats.level
		current_xp = unit.stats.current_xp

		current_hp = unit.stats.current_hp
		max_hp = unit.stats.max_hp

		current_mp = unit.stats.current_mp
		max_mp = unit.stats.max_mp

		strength = unit.stats.strength
		defense = unit.stats.defense
		agility = unit.stats.agility
		intelligence = unit.stats.intelligence
		luck = unit.stats.luck

	# TODO: Copy equipped items when equipment system is implemented
	# TODO: Copy learned abilities when ability learning system is implemented


# ============================================================================
# SERIALIZATION
# ============================================================================

## Serialize character save data to Dictionary for JSON export
## @return: Dictionary representation of character data
func serialize_to_dict() -> Dictionary:
	return {
		"character_mod_id": character_mod_id,
		"character_resource_id": character_resource_id,
		"fallback_character_name": fallback_character_name,
		"fallback_class_name": fallback_class_name,
		"level": level,
		"current_xp": current_xp,
		"current_hp": current_hp,
		"max_hp": max_hp,
		"current_mp": current_mp,
		"max_mp": max_mp,
		"strength": strength,
		"defense": defense,
		"agility": agility,
		"intelligence": intelligence,
		"luck": luck,
		"equipped_items": equipped_items.duplicate(true),
		"inventory": inventory.duplicate(),
		"learned_abilities": learned_abilities.duplicate(),
		"is_alive": is_alive,
		"is_available": is_available,
		"is_hero": is_hero,
		"recruitment_chapter": recruitment_chapter,
		"cumulative_level": cumulative_level,
		"promotion_count": promotion_count,
		"current_class_mod_id": current_class_mod_id,
		"current_class_resource_id": current_class_resource_id
	}


## Deserialize character save data from Dictionary (loaded from JSON)
## @param data: Dictionary loaded from JSON file
func deserialize_from_dict(data: Dictionary) -> void:
	if "character_mod_id" in data:
		character_mod_id = data.character_mod_id
	if "character_resource_id" in data:
		character_resource_id = data.character_resource_id
	if "fallback_character_name" in data:
		fallback_character_name = data.fallback_character_name
	if "fallback_class_name" in data:
		fallback_class_name = data.fallback_class_name
	if "level" in data:
		level = data.level
	if "current_xp" in data:
		current_xp = data.current_xp
	if "current_hp" in data:
		current_hp = data.current_hp
	if "max_hp" in data:
		max_hp = data.max_hp
	if "current_mp" in data:
		current_mp = data.current_mp
	if "max_mp" in data:
		max_mp = data.max_mp
	if "strength" in data:
		strength = data.strength
	if "defense" in data:
		defense = data.defense
	if "agility" in data:
		agility = data.agility
	if "intelligence" in data:
		intelligence = data.intelligence
	if "luck" in data:
		luck = data.luck
	if "equipped_items" in data:
		equipped_items.clear()
		var items_array: Array = data.equipped_items
		for i in range(items_array.size()):
			var item_dict: Dictionary = items_array[i]
			# Ensure curse_broken field exists (backward compatibility)
			if "curse_broken" not in item_dict:
				item_dict["curse_broken"] = false
			equipped_items.append(item_dict)
	if "inventory" in data:
		inventory.clear()
		var inv_array: Array = data.inventory
		for i in range(inv_array.size()):
			var item_id: Variant = inv_array[i]
			if item_id is String:
				inventory.append(item_id)
	if "learned_abilities" in data:
		learned_abilities.clear()
		var abilities_array: Array = data.learned_abilities
		for i in range(abilities_array.size()):
			var ability_dict: Dictionary = abilities_array[i]
			learned_abilities.append(ability_dict)
	if "is_alive" in data:
		is_alive = data.is_alive
	if "is_available" in data:
		is_available = data.is_available
	if "is_hero" in data:
		is_hero = data.is_hero
	if "recruitment_chapter" in data:
		recruitment_chapter = data.recruitment_chapter
	if "cumulative_level" in data:
		cumulative_level = data.cumulative_level
	if "promotion_count" in data:
		promotion_count = data.promotion_count
	if "current_class_mod_id" in data:
		current_class_mod_id = data.current_class_mod_id
	if "current_class_resource_id" in data:
		current_class_resource_id = data.current_class_resource_id


# ============================================================================
# VALIDATION
# ============================================================================

## Validate that character save data is complete and valid
## @return: true if valid, false if corrupted/invalid
func validate() -> bool:
	if character_mod_id.is_empty():
		push_error("CharacterSaveData: character_mod_id is empty")
		return false

	if character_resource_id.is_empty():
		push_error("CharacterSaveData: character_resource_id is empty")
		return false

	if fallback_character_name.is_empty():
		push_error("CharacterSaveData: fallback_character_name is empty")
		return false

	if level < 1:
		push_error("CharacterSaveData: Invalid level: %d" % level)
		return false

	if max_hp < 1:
		push_error("CharacterSaveData: Invalid max_hp: %d" % max_hp)
		return false

	return true


# ============================================================================
# MOD COMPATIBILITY HELPERS
# ============================================================================

## Get mod_id for a resource by searching ModRegistry
## @param resource: Resource to find mod_id for
## @return: mod_id string, or "" if not found
func _get_mod_id_for_resource(resource: Resource) -> String:
	if not resource:
		return ""

	# Search through ModRegistry to find which mod owns this resource
	var resource_path: String = resource.resource_path
	if resource_path.is_empty():
		push_warning("CharacterSaveData: Resource has no resource_path")
		return ""

	# Extract mod_id from path (e.g., "res://mods/_base_game/..." → "_base_game")
	if resource_path.begins_with("res://mods/"):
		var path_parts: PackedStringArray = resource_path.split("/")
		if path_parts.size() >= 3:
			return path_parts[2]  # mods/[mod_id]/...

	push_warning("CharacterSaveData: Could not determine mod_id from path: %s" % resource_path)
	return ""


## Get resource_id for a resource (filename without extension)
## @param resource: Resource to get ID for
## @return: resource_id string, or "" if not found
func _get_resource_id_for_resource(resource: Resource) -> String:
	if not resource:
		return ""

	var resource_path: String = resource.resource_path
	if resource_path.is_empty():
		push_warning("CharacterSaveData: Resource has no resource_path")
		return ""

	# Extract filename without extension
	var filename: String = resource_path.get_file()
	var resource_id: String = filename.get_basename()

	return resource_id


# ============================================================================
# INVENTORY MANAGEMENT
# ============================================================================

## Add an item to the character's inventory
## @param item_id: ID of the item to add
## @return: true if added successfully, false if inventory full
func add_item_to_inventory(item_id: String) -> bool:
	if item_id.is_empty():
		push_warning("CharacterSaveData: Cannot add empty item_id to inventory")
		return false

	# Check inventory limit (default 4 slots in SF)
	var max_slots: int = 4
	if ModLoader and "inventory_config" in ModLoader:
		max_slots = ModLoader.inventory_config.get_max_slots()

	if inventory.size() >= max_slots:
		push_warning("CharacterSaveData: Inventory full (%d/%d)" % [inventory.size(), max_slots])
		return false

	inventory.append(item_id)
	return true


## Remove an item from the character's inventory
## @param item_id: ID of the item to remove
## @return: true if removed successfully, false if not found
func remove_item_from_inventory(item_id: String) -> bool:
	if item_id.is_empty():
		push_warning("CharacterSaveData: Cannot remove empty item_id from inventory")
		return false

	var index: int = inventory.find(item_id)
	if index == -1:
		push_warning("CharacterSaveData: Item '%s' not found in inventory" % item_id)
		return false

	inventory.remove_at(index)
	print("[CharacterSaveData] Removed item '%s' from inventory (remaining: %d items)" % [item_id, inventory.size()])
	return true


## Check if the character has a specific item in inventory
## @param item_id: ID of the item to check
## @return: true if item is in inventory
func has_item_in_inventory(item_id: String) -> bool:
	return item_id in inventory


## Get the count of a specific item in inventory (supports duplicates)
## @param item_id: ID of the item to count
## @return: Number of this item in inventory
func get_item_count(item_id: String) -> int:
	var count: int = 0
	for inv_item: String in inventory:
		if inv_item == item_id:
			count += 1
	return count
