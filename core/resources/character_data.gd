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

@export_group("Appearance")
@export var portrait: Texture2D
@export var battle_sprite: Texture2D  ## Map sprite used on battlefield
@export var combat_animation_data: CombatAnimationData  ## Combat screen animations (optional - uses placeholder if null)

@export_group("Starting Configuration")
@export var starting_level: int = 1
@export var starting_equipment: Array[ItemData] = []

@export_group("Lore")
@export_multiline var biography: String = ""

@export_group("Battle Configuration")
## Category helps organize characters in the editor and determines default behavior
## "player" - Playable characters (heroes, party members)
## "enemy" - Standard enemy units (can be spawned multiple times)
## "boss" - Unique boss enemies (usually spawned once)
## "neutral" - Non-combatant or ally NPCs
@export_enum("player", "enemy", "boss", "neutral") var unit_category: String = "player"

## If false, this is a template that can be used multiple times in battles (like "Goblin")
## If true, this is a unique character that should only appear once (like "Max" or "Kane")
@export var is_unique: bool = true

## If true, this character is the primary Hero/protagonist
## Only one hero can exist per party/save slot
## The hero is always the first member of the player party
@export var is_hero: bool = false

## Default AI behavior for this unit when used as an enemy
## Can be overridden in BattleData on a per-instance basis
@export var default_ai_brain: AIBrain = null


## Get base stat value by name
func get_base_stat(stat_name: String) -> int:
	if stat_name in self:
		return get(stat_name)
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
