class_name ClassData
extends Resource

## Represents a character class (e.g., Warrior, Mage, Archer).
## Defines movement capabilities, equipment restrictions, and learnable abilities.

enum MovementType {
	WALKING,    ## Ground movement only, affected by terrain
	FLYING,     ## Can fly over obstacles, ignores terrain penalties
	FLOATING,   ## Hovers over terrain, some terrain penalties
	SWIMMING,   ## Aquatic movement (merfolk, water units) - water terrain preferred
	CUSTOM      ## Mod-defined type (use custom_movement_type field)
}

@export var display_name: String = ""
@export var movement_type: MovementType = MovementType.WALKING
## Custom movement type ID (only used when movement_type == CUSTOM)
## Allows mods to define their own movement types beyond the core set
@export var custom_movement_type: String = ""
@export var movement_range: int = 4

@export_group("Combat Rates")
## Counter rate determines chance to counterattack when attacked (SF2 uses 3, 6, 12, or 25%)
## 25 = 1/4 (25%), 12 = 1/8 (~12.5%), 6 = 1/16 (~6%), 3 = 1/32 (~3%)
@export_range(0, 50) var counter_rate: int = 12
## Double attack rate (chance for second attack) - future implementation
@export_range(0, 50) var double_attack_rate: int = 6
## Critical hit rate bonus (added to base crit calculation)
@export_range(0, 50) var crit_rate_bonus: int = 0

@export_group("Growth Rates")
## Stat growth rates determine how stats increase on level up (0-100%)
## These rates define the class's growth pattern, matching Shining Force mechanics
@export_range(0, 100) var hp_growth: int = 50
@export_range(0, 100) var mp_growth: int = 50
@export_range(0, 100) var strength_growth: int = 50
@export_range(0, 100) var defense_growth: int = 50
@export_range(0, 100) var agility_growth: int = 50
@export_range(0, 100) var intelligence_growth: int = 50
@export_range(0, 100) var luck_growth: int = 50

@export_group("Equipment")
## Weapon types this class can equip (e.g., "sword", "axe", "bow")
## Note: SF2 did not have armor - equipment was weapon + rings only
@export var equippable_weapon_types: Array[String] = []

@export_group("Abilities")
## Active spells/abilities granted by this class (PRIMARY spell source)
## Characters get their spells from their class, not individually
## Example: MAGE class has [blaze_1, blaze_2, blaze_3, blaze_4]
@export var class_abilities: Array[AbilityData] = []

## Level requirements for each ability {"ability_id": level_required}
## Abilities not in this dict are available at level 1
## Example: {"blaze_2": 8, "blaze_3": 16, "blaze_4": 24}
@export var ability_unlock_levels: Dictionary = {}

@export_group("Promotion")
## The class this promotes to (standard path, optional)
@export var promotion_class: ClassData
## Level required to promote
@export var promotion_level: int = 10
## Alternative promotion path requiring a specific item (SF2 style)
## Example: Knight -> Pegasus Knight requires "Pegasus Wing" item
@export var special_promotion_class: ClassData
## Item required for special promotion (if special_promotion_class is set)
## If null but special_promotion_class is set, special promotion is always available
@export var special_promotion_item: ItemData

@export_group("Appearance")
@export var class_icon: Texture2D


## Check if this class can equip a specific weapon type
## Supports category wildcards: "weapon:*" matches any weapon subtype
func can_equip_weapon(weapon_type: String) -> bool:
	var lower_type: String = weapon_type.to_lower()

	for allowed: String in equippable_weapon_types:
		# Use EquipmentTypeRegistry for wildcard matching if available
		if ModLoader and ModLoader.equipment_type_registry:
			if ModLoader.equipment_type_registry.matches_accept_type(lower_type, allowed):
				return true
		else:
			# Fallback: direct match only
			if allowed.to_lower() == lower_type:
				return true

	return false


## Get all class abilities unlocked at a given level
## Uses class_abilities array filtered by ability_unlock_levels dictionary
## Abilities without an entry in ability_unlock_levels are available at level 1
func get_unlocked_class_abilities(level: int) -> Array[AbilityData]:
	var unlocked: Array[AbilityData] = []
	for ability: AbilityData in class_abilities:
		if ability == null:
			continue
		var unlock_level: int = 1
		if ability.ability_id in ability_unlock_levels:
			unlock_level = ability_unlock_levels[ability.ability_id]
		if level >= unlock_level:
			unlocked.append(ability)
	return unlocked


## Check if a specific ability is unlocked at a given level
func is_ability_unlocked(ability_id: String, level: int) -> bool:
	var unlock_level: int = 1
	if ability_id in ability_unlock_levels:
		unlock_level = ability_unlock_levels[ability_id]
	return level >= unlock_level


## Get the level required to unlock a specific ability
## Returns 1 if ability is not in unlock dictionary (available immediately)
## Returns -1 if ability is not in class_abilities at all
func get_ability_unlock_level(ability_id: String) -> int:
	# Verify the ability exists in class_abilities
	var found: bool = false
	for ability: AbilityData in class_abilities:
		if ability != null and ability.ability_id == ability_id:
			found = true
			break
	if not found:
		return -1

	if ability_id in ability_unlock_levels:
		return ability_unlock_levels[ability_id]
	return 1


## Get growth rate by stat name (for dynamic access)
func get_growth_rate(stat_name: String) -> int:
	var growth_key: String = stat_name + "_growth"
	if growth_key in self:
		return get(growth_key)
	return 0


## Check if this class has a special promotion path defined
func has_special_promotion() -> bool:
	return special_promotion_class != null


## Get all available promotion paths for this class
## Returns array containing standard and special promotions (if defined)
func get_all_promotion_paths() -> Array[ClassData]:
	var paths: Array[ClassData] = []
	if promotion_class != null:
		paths.append(promotion_class)
	if special_promotion_class != null:
		paths.append(special_promotion_class)
	return paths


## Validate that required fields are set
func validate() -> bool:
	if display_name.is_empty():
		push_error("ClassData: display_name is required")
		return false
	if movement_range < 1:
		push_error("ClassData: movement_range must be at least 1")
		return false
	return true
