class_name ClassData
extends Resource

## Represents a character class (e.g., Warrior, Mage, Archer).
## Defines movement capabilities, equipment restrictions, and learnable abilities.

enum MovementType {
	WALKING,    ## Ground movement only, affected by terrain
	FLYING,     ## Can fly over obstacles, ignores terrain penalties
	FLOATING    ## Hovers over terrain, some terrain penalties
}

@export var display_name: String = ""
@export var movement_type: MovementType = MovementType.WALKING
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
@export var equippable_weapon_types: Array[String] = []
## Armor types this class can equip (e.g., "light", "heavy", "robe")
@export var equippable_armor_types: Array[String] = []

@export_group("Abilities")
## Abilities learned at specific levels: {level: AbilityData}
@export var learnable_abilities: Dictionary = {}

@export_group("Promotion")
## The class this promotes to (optional)
@export var promotion_class: ClassData
## Level required to promote
@export var promotion_level: int = 10

@export_group("Appearance")
@export var class_icon: Texture2D


## Check if this class can equip a specific weapon type
func can_equip_weapon(weapon_type: String) -> bool:
	return weapon_type in equippable_weapon_types


## Check if this class can equip a specific armor type
func can_equip_armor(armor_type: String) -> bool:
	return armor_type in equippable_armor_types


## Get ability learned at a specific level (if any)
func get_ability_at_level(level: int) -> Resource:
	if level in learnable_abilities:
		return learnable_abilities[level]
	return null


## Get all abilities learned up to a specific level
func get_abilities_up_to_level(level: int) -> Array[Resource]:
	var abilities: Array[Resource] = []
	for learn_level: int in learnable_abilities.keys():
		if learn_level <= level:
			var ability: Resource = learnable_abilities[learn_level]
			if ability != null:
				abilities.append(ability)
	return abilities


## Get growth rate by stat name (for dynamic access)
func get_growth_rate(stat_name: String) -> int:
	var growth_key: String = stat_name + "_growth"
	if growth_key in self:
		return get(growth_key)
	return 0


## Validate that required fields are set
func validate() -> bool:
	if display_name.is_empty():
		push_error("ClassData: display_name is required")
		return false
	if movement_range < 1:
		push_error("ClassData: movement_range must be at least 1")
		return false
	return true
