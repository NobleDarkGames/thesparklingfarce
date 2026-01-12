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
## Stat growth rates determine how stats increase on level up.
## Enhanced Shining Force-style system:
##   0-99:  Percentage chance of +1 (e.g., 50 = 50% chance of +1)
##   100+:  Guaranteed +1, remainder% chance of +2 (e.g., 150 = +1 always, 50% for +2)
## A 5% "lucky roll" can grant +1 extra for rates >= 50, creating memorable level-ups.
## Typical ranges: HP 80-150, MP 30-80, combat stats 40-100
@export_range(0, 200) var hp_growth: int = 100
@export_range(0, 200) var mp_growth: int = 60
@export_range(0, 200) var strength_growth: int = 80
@export_range(0, 200) var defense_growth: int = 80
@export_range(0, 200) var agility_growth: int = 70
@export_range(0, 200) var intelligence_growth: int = 70
@export_range(0, 200) var luck_growth: int = 50

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
## Available promotion paths for this class
## Each path specifies a target class and optional required item
@export var promotion_paths: Array[PromotionPath] = []
## Level required to promote (applies to all paths)
@export var promotion_level: int = 10
## Whether level resets to 1 on promotion (SF2 style). If false, level continues.
@export var promotion_resets_level: bool = true
## Whether promotion items are consumed when used (applies to all paths)
@export var consume_promotion_item: bool = true

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
	print("ClassData.get_unlocked_class_abilities: class='%s', level=%d, class_abilities.size()=%d" % [
		display_name, level, class_abilities.size()
	])
	var unlocked: Array[AbilityData] = []
	for ability: AbilityData in class_abilities:
		if ability == null:
			print("ClassData.get_unlocked_class_abilities: Skipping null ability")
			continue
		var unlock_level: int = 1
		if ability.ability_id in ability_unlock_levels:
			var level_value: Variant = ability_unlock_levels[ability.ability_id]
			if level_value is int:
				unlock_level = level_value
			elif level_value is float:
				unlock_level = int(level_value)
		print("ClassData.get_unlocked_class_abilities: ability='%s', unlock_level=%d, current_level=%d, unlocked=%s" % [
			ability.ability_name, unlock_level, level, str(level >= unlock_level)
		])
		if level >= unlock_level:
			unlocked.append(ability)
	print("ClassData.get_unlocked_class_abilities: Returning %d abilities" % unlocked.size())
	return unlocked


## Check if a specific ability is unlocked at a given level
func is_ability_unlocked(ability_id: String, level: int) -> bool:
	var unlock_level: int = 1
	if ability_id in ability_unlock_levels:
		var level_value: Variant = ability_unlock_levels[ability_id]
		if level_value is int:
			unlock_level = level_value
		elif level_value is float:
			unlock_level = int(level_value)
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
		var level_value: Variant = ability_unlock_levels[ability_id]
		if level_value is int:
			return level_value
		elif level_value is float:
			var float_val: float = level_value
			return int(float_val)
	return 1


## Get growth rate by stat name (for dynamic access)
func get_growth_rate(stat_name: String) -> int:
	var growth_key: String = stat_name + "_growth"
	if growth_key in self:
		var value: Variant = get(growth_key)
		if value is int:
			return value
		elif value is float:
			var float_val: float = value
			return int(float_val)
	return 0


## Check if this class has any item-gated promotion paths
func has_special_promotion() -> bool:
	for path: PromotionPath in promotion_paths:
		if path and path.requires_item():
			return true
	return false


## Get all available promotion paths for this class
## Returns array of target ClassData for all defined paths
func get_all_promotion_paths() -> Array[ClassData]:
	var classes: Array[ClassData] = []
	for path: PromotionPath in promotion_paths:
		if path and path.target_class:
			classes.append(path.target_class)
	return classes


## Get all promotion path resources (full PromotionPath objects)
func get_promotion_path_resources() -> Array[PromotionPath]:
	var valid_paths: Array[PromotionPath] = []
	for path: PromotionPath in promotion_paths:
		if path and path.is_valid():
			valid_paths.append(path)
	return valid_paths


## Get the promotion path for a specific target class
## Returns null if no path leads to that class
func get_promotion_path_for_class(target: ClassData) -> PromotionPath:
	for path: PromotionPath in promotion_paths:
		if path and path.target_class == target:
			return path
	return null


## Check if this class can promote (has at least one valid promotion path)
func can_promote() -> bool:
	for path: PromotionPath in promotion_paths:
		if path and path.is_valid():
			return true
	return false


## Validate that required fields are set
func validate() -> bool:
	if display_name.is_empty():
		push_error("ClassData: display_name is required")
		return false
	if movement_range < 1:
		push_error("ClassData: movement_range must be at least 1")
		return false
	return true
