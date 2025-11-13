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


## Validate that required fields are set
func validate() -> bool:
	if display_name.is_empty():
		push_error("ClassData: display_name is required")
		return false
	if movement_range < 1:
		push_error("ClassData: movement_range must be at least 1")
		return false
	return true
