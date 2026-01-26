## Shared test fixture for creating units with specific stat configurations
##
## Useful for combat, status effect, and equipment tests that need
## predictable stat values for calculation verification.
##
## Dependencies:
## - CharacterFactory (for base character creation)
## - UnitFactory (for unit spawning)
## - GridManager autoload (must be initialized for unit placement)
##
## Usage:
##   var tank: Unit = UnitStatsFactory.create_tank(container, Vector2i(5, 5))
##   var glass_cannon: Unit = UnitStatsFactory.create_glass_cannon(container, Vector2i(6, 5))
##   var wounded: Unit = UnitStatsFactory.create_wounded(container, Vector2i(7, 5), 0.25)
class_name UnitStatsFactory
extends RefCounted


const CharacterFactoryScript = preload("res://tests/fixtures/character_factory.gd")
const UnitFactoryScript = preload("res://tests/fixtures/unit_factory.gd")


## Create a balanced unit (moderate stats across the board)
## HP: 50, MP: 20, STR: 15, DEF: 15, AGI: 15, INT: 15, LUK: 10
static func create_balanced(
	parent: Node,
	cell: Vector2i,
	faction: String = "player",
	unit_name: String = "Balanced"
) -> Unit:
	var character: CharacterData = CharacterFactoryScript.create_character(unit_name, {
		"hp": 50,
		"mp": 20,
		"strength": 15,
		"defense": 15,
		"agility": 15,
		"intelligence": 15,
		"luck": 10
	})
	return UnitFactoryScript.spawn_unit(character, cell, faction, parent)


## Alias for create_balanced() for backward compatibility
static func create_default(
	parent: Node,
	cell: Vector2i,
	faction: String = "player",
	unit_name: String = "Balanced"
) -> Unit:
	return create_balanced(parent, cell, faction, unit_name)


## Create a tank unit (high HP and defense, low speed)
## HP: 100, MP: 10, STR: 20, DEF: 30, AGI: 5, INT: 10, LUK: 5
static func create_tank(
	parent: Node,
	cell: Vector2i,
	faction: String = "player",
	unit_name: String = "Tank"
) -> Unit:
	var character: CharacterData = CharacterFactoryScript.create_character(unit_name, {
		"hp": 100,
		"mp": 10,
		"strength": 20,
		"defense": 30,
		"agility": 5,
		"intelligence": 10,
		"luck": 5
	})
	return UnitFactoryScript.spawn_unit(character, cell, faction, parent)


## Create a glass cannon (high attack, low HP/defense)
## HP: 25, MP: 30, STR: 35, DEF: 5, AGI: 20, INT: 20, LUK: 10
static func create_glass_cannon(
	parent: Node,
	cell: Vector2i,
	faction: String = "player",
	unit_name: String = "GlassCannon"
) -> Unit:
	var character: CharacterData = CharacterFactoryScript.create_character(unit_name, {
		"hp": 25,
		"mp": 30,
		"strength": 35,
		"defense": 5,
		"agility": 20,
		"intelligence": 20,
		"luck": 10
	})
	return UnitFactoryScript.spawn_unit(character, cell, faction, parent)


## Create a speedster (high agility, moderate other stats)
## HP: 40, MP: 15, STR: 15, DEF: 10, AGI: 30, INT: 15, LUK: 15
static func create_speedster(
	parent: Node,
	cell: Vector2i,
	faction: String = "player",
	unit_name: String = "Speedster"
) -> Unit:
	var character: CharacterData = CharacterFactoryScript.create_character(unit_name, {
		"hp": 40,
		"mp": 15,
		"strength": 15,
		"defense": 10,
		"agility": 30,
		"intelligence": 15,
		"luck": 15
	})
	return UnitFactoryScript.spawn_unit(character, cell, faction, parent)


## Create a mage (high intelligence/MP, low physical stats)
## HP: 30, MP: 50, STR: 8, DEF: 8, AGI: 12, INT: 30, LUK: 12
static func create_mage(
	parent: Node,
	cell: Vector2i,
	faction: String = "player",
	unit_name: String = "Mage"
) -> Unit:
	var character: CharacterData = CharacterFactoryScript.create_character(unit_name, {
		"hp": 30,
		"mp": 50,
		"strength": 8,
		"defense": 8,
		"agility": 12,
		"intelligence": 30,
		"luck": 12
	})
	return UnitFactoryScript.spawn_unit(character, cell, faction, parent)


## Create a healer (moderate stats, high MP)
## HP: 35, MP: 40, STR: 10, DEF: 12, AGI: 15, INT: 25, LUK: 8
static func create_healer(
	parent: Node,
	cell: Vector2i,
	faction: String = "player",
	unit_name: String = "Healer"
) -> Unit:
	var character: CharacterData = CharacterFactoryScript.create_character(unit_name, {
		"hp": 35,
		"mp": 40,
		"strength": 10,
		"defense": 12,
		"agility": 15,
		"intelligence": 25,
		"luck": 8
	})
	return UnitFactoryScript.spawn_unit(character, cell, faction, parent)


## Create a wounded unit (starts at reduced HP percentage)
## Uses balanced stats by default, then reduces current HP
## hp_percent: 0.0 to 1.0 (e.g., 0.25 = 25% HP)
static func create_wounded(
	parent: Node,
	cell: Vector2i,
	faction: String = "player",
	unit_name: String = "Wounded",
	hp_percent: float = 0.25
) -> Unit:
	var unit: Unit = create_balanced(parent, cell, faction, unit_name)
	var max_hp: int = unit.stats.max_hp
	unit.stats.current_hp = maxi(1, int(max_hp * hp_percent))
	return unit


## Create a unit with specific stats (full control)
## stats: Dictionary with any combination of stat keys
## Valid keys: hp, mp, strength, defense, agility, intelligence, luck, level
static func create_with_stats(
	parent: Node,
	cell: Vector2i,
	stats: Dictionary,
	faction: String = "player",
	unit_name: String = "Custom"
) -> Unit:
	# Start with balanced defaults, then apply overrides
	var merged_stats: Dictionary = {
		"hp": stats.get("hp", 50),
		"mp": stats.get("mp", 20),
		"strength": stats.get("strength", 15),
		"defense": stats.get("defense", 15),
		"agility": stats.get("agility", 15),
		"intelligence": stats.get("intelligence", 15),
		"luck": stats.get("luck", 10),
		"level": stats.get("level", 1)
	}
	var character: CharacterData = CharacterFactoryScript.create_character(unit_name, merged_stats)
	return UnitFactoryScript.spawn_unit(character, cell, faction, parent)


## Alias for create_with_stats() for backward compatibility
static func create_custom(
	parent: Node,
	cell: Vector2i,
	overrides: Dictionary,
	faction: String = "player",
	unit_name: String = "Custom"
) -> Unit:
	return create_with_stats(parent, cell, overrides, faction, unit_name)


## Create a pair of combatants for damage calculation tests
## Returns Dictionary with "attacker" and "defender" keys
static func create_combat_pair(
	parent: Node,
	attacker_stats: Dictionary,
	defender_stats: Dictionary,
	attacker_cell: Vector2i = Vector2i(5, 5),
	defender_cell: Vector2i = Vector2i(6, 5)
) -> Dictionary:
	var attacker: Unit = create_with_stats(
		parent, attacker_cell, attacker_stats, "enemy", "Attacker"
	)
	var defender: Unit = create_with_stats(
		parent, defender_cell, defender_stats, "player", "Defender"
	)
	return {"attacker": attacker, "defender": defender}


## Create opposing units for range/movement tests
## Returns Dictionary with "player_unit" and "enemy_unit" keys
static func create_opposing_units(
	parent: Node,
	player_cell: Vector2i,
	enemy_cell: Vector2i,
	player_name: String = "Player",
	enemy_name: String = "Enemy"
) -> Dictionary:
	var player_unit: Unit = create_balanced(parent, player_cell, "player", player_name)
	var enemy_unit: Unit = create_balanced(parent, enemy_cell, "enemy", enemy_name)
	return {"player_unit": player_unit, "enemy_unit": enemy_unit}
