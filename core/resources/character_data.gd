class_name CharacterData
extends Resource

## Represents a single character/unit in the game.
## Contains all stats, appearance, and equipment information.

@export var character_name: String = ""
@export var character_class: ClassData
@export_group("Stats")
@export var base_hp: int = 10
@export var base_mp: int = 5
@export var base_strength: int = 5
@export var base_defense: int = 5
@export var base_agility: int = 5
@export var base_intelligence: int = 5
@export var base_luck: int = 5

@export_group("Growth Rates")
@export_range(0, 100) var hp_growth: int = 50
@export_range(0, 100) var mp_growth: int = 50
@export_range(0, 100) var strength_growth: int = 50
@export_range(0, 100) var defense_growth: int = 50
@export_range(0, 100) var agility_growth: int = 50
@export_range(0, 100) var intelligence_growth: int = 50
@export_range(0, 100) var luck_growth: int = 50

@export_group("Appearance")
@export var portrait: Texture2D
@export var battle_sprite: Texture2D  ## Map sprite used on battlefield
@export var combat_animation_data: CombatAnimationData  ## Combat screen animations (optional - uses placeholder if null)

@export_group("Starting Configuration")
@export var starting_level: int = 1
@export var starting_equipment: Array[ItemData] = []

@export_group("Lore")
@export_multiline var biography: String = ""


## Get base stat value by name
func get_base_stat(stat_name: String) -> int:
	if stat_name in self:
		return get(stat_name)
	return 0


## Get growth rate by stat name
func get_growth_rate(stat_name: String) -> int:
	var growth_key: String = stat_name + "_growth"
	if growth_key in self:
		return get(growth_key)
	return 0


## Validate that required fields are set
func validate() -> bool:
	if character_name.is_empty():
		push_error("CharacterData: character_name is required")
		return false
	if character_class == null:
		push_error("CharacterData: character_class is required")
		return false
	if starting_level < 1:
		push_error("CharacterData: starting_level must be at least 1")
		return false
	return true
