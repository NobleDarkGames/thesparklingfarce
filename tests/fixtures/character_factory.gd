## Shared test fixture for creating CharacterData resources
##
## Dependencies: None (pure resource creation)
##
## This fixture is safe for both unit and integration tests.
## Characters are RefCounted resources that don't need explicit cleanup;
## they are garbage collected when unreferenced.
##
## Usage:
##   var char: CharacterData = CharacterFactory.create_character("Hero", {
##       "hp": 50, "mp": 10, "strength": 15, "defense": 10, "agility": 10
##   })
class_name CharacterFactory
extends RefCounted


## Create a CharacterData with the specified name and stats
## Options dictionary keys: hp, mp, strength, defense, agility, intelligence, luck, level, is_hero, ensure_uid
static func create_character(
	p_name: String,
	options: Dictionary = {}
) -> CharacterData:
	var character: CharacterData = CharacterData.new()
	character.character_name = p_name
	character.base_hp = options.get("hp", 50)
	character.base_mp = options.get("mp", 10)
	character.base_strength = options.get("strength", 10)
	character.base_defense = options.get("defense", 10)
	character.base_agility = options.get("agility", 10)
	character.base_intelligence = options.get("intelligence", 10)
	character.base_luck = options.get("luck", 5)
	character.starting_level = options.get("level", 1)
	character.is_hero = options.get("is_hero", false)

	# Create default class if not provided
	var class_data: ClassData = options.get("class_data", null)
	if class_data == null:
		class_data = _create_default_class()
	character.character_class = class_data

	# Generate UID if requested (needed for PartyManager tests)
	if options.get("ensure_uid", false):
		character.ensure_uid()

	return character


## Create a minimal ClassData for testing
static func _create_default_class() -> ClassData:
	var class_data: ClassData = ClassData.new()
	class_data.display_name = "Warrior"
	class_data.movement_type = ClassData.MovementType.WALKING
	class_data.movement_range = 4
	class_data.hp_growth = 60
	class_data.mp_growth = 20
	class_data.strength_growth = 50
	class_data.defense_growth = 40
	class_data.agility_growth = 30
	class_data.intelligence_growth = 20
	class_data.luck_growth = 20
	return class_data


## Create a character with specific combat stats (shorthand)
static func create_combatant(
	p_name: String,
	hp: int,
	mp: int,
	strength: int,
	defense: int,
	agility: int,
	level: int = 1
) -> CharacterData:
	return create_character(p_name, {
		"hp": hp,
		"mp": mp,
		"strength": strength,
		"defense": defense,
		"agility": agility,
		"level": level
	})
