@tool
class_name BattleData
extends Resource

## Represents a complete battle scenario.
## Contains map information, unit placement, victory/defeat conditions, and battle flow.

enum VictoryCondition {
	DEFEAT_ALL_ENEMIES,
	DEFEAT_BOSS,
	SURVIVE_TURNS,
	REACH_LOCATION,
	PROTECT_UNIT,
	CUSTOM
}

enum DefeatCondition {
	ALL_UNITS_DEFEATED,
	LEADER_DEFEATED,
	TURN_LIMIT,
	UNIT_DIES,
	CUSTOM
}

@export var battle_name: String = ""
@export_multiline var battle_description: String = ""

@export_group("Map Configuration")
## Map scene contains grid dimensions, spawn points, and terrain
@export var map_scene: PackedScene
## Starting position for the player party (first unit spawns here, others use formation offsets)
@export var player_spawn_point: Vector2i = Vector2i(2, 2)

@export_group("Player Forces")
## Player party to deploy in this battle.
## If null, uses PartyManager's current party.
## If set, temporarily loads this party for the battle.
@export var player_party: PartyData

@export_group("Enemy Forces")
## Array of dictionaries with these fields:
## - character: CharacterData (required)
## - position: Vector2i (required)
## - ai_behavior: AIBehaviorData (required) - Resource reference to AI behavior configuration
## - spawn_delay: int (optional, default 0) - Turn number when this enemy spawns.
##   0 or absent = spawns at battle start. 3 = appears at start of turn 3.
@export var enemies: Array[Dictionary] = []

@export_group("Neutral/NPC Forces")
## Array of dictionaries with these fields:
## - character: CharacterData (required)
## - position: Vector2i (required)
## - ai_behavior: AIBehaviorData (required) - Resource reference to AI behavior configuration
@export var neutrals: Array[Dictionary] = []

@export_group("Victory Conditions")
@export var victory_condition: VictoryCondition = VictoryCondition.DEFEAT_ALL_ENEMIES
@export var victory_target_position: Vector2i = Vector2i.ZERO
@export var victory_boss_index: int = -1  ## Which enemy is the boss (for DEFEAT_BOSS)
@export var victory_protect_index: int = -1  ## Which neutral to protect (for PROTECT_UNIT)
@export var victory_turn_count: int = 0
@export var custom_victory_script: GDScript

@export_group("Defeat Conditions")
@export var defeat_condition: DefeatCondition = DefeatCondition.LEADER_DEFEATED
@export var defeat_protect_index: int = -1  ## Which neutral must survive (for UNIT_DIES)
@export var defeat_turn_limit: int = 0
@export var custom_defeat_script: GDScript

@export_group("Battle Flow")
## If true, this is a story-critical battle that cannot be quit via the game menu.
## The "Quit" option will be grayed out. Used for mandatory plot battles.
@export var is_story_battle: bool = false
## Dialogue to show before battle starts
@export var pre_battle_dialogue: DialogueData
## Dialogue to show when player wins
@export var victory_dialogue: DialogueData
## Dialogue to show when player loses
@export var defeat_dialogue: DialogueData
## Dialogue to show at specific turns: {turn_number: DialogueData}
@export var turn_dialogues: Dictionary = {}

@export_group("Audio")
@export var music_id: String = ""  ## Battle music track ID (empty = use default based on battle type)
@export var victory_music_id: String = ""  ## Victory fanfare ID (empty = use "battle_victory")
@export var defeat_music_id: String = ""  ## Defeat music ID (empty = use "battle_defeat")

@export_group("Rewards")
@export var experience_reward: int = 0
@export var gold_reward: int = 0
@export var item_rewards: Array[ItemData] = []
@export var character_rewards: Array[CharacterData] = []  ## Characters that join the party on victory

## Validate enemy dictionary structure
func validate_enemies() -> bool:
	return _validate_unit_array(enemies, "Enemy")


## Validate neutral dictionary structure
func validate_neutrals() -> bool:
	return _validate_unit_array(neutrals, "Neutral")


## Generic validation for unit arrays (enemies, neutrals)
func _validate_unit_array(units: Array[Dictionary], unit_type: String) -> bool:
	for i: int in range(units.size()):
		var unit: Dictionary = units[i]
		if "character" not in unit:
			push_error("BattleData: %s %d missing character" % [unit_type, i])
			return false
		var character: Variant = unit.get("character")
		if character == null:
			push_error("BattleData: %s %d missing character" % [unit_type, i])
			return false
		if "position" not in unit:
			push_error("BattleData: %s %d missing position" % [unit_type, i])
			return false
		if "ai_behavior" not in unit:
			push_error("BattleData: %s %d missing ai_behavior" % [unit_type, i])
			return false
		var ai_behavior: Variant = unit.get("ai_behavior")
		if ai_behavior == null:
			push_error("BattleData: %s %d missing ai_behavior" % [unit_type, i])
			return false
	return true


## Validate victory condition configuration
func validate_victory_condition() -> bool:
	match victory_condition:
		VictoryCondition.DEFEAT_BOSS:
			if victory_boss_index < 0 or victory_boss_index >= enemies.size():
				push_error("BattleData: Invalid victory_boss_index: %d" % victory_boss_index)
				return false
		VictoryCondition.SURVIVE_TURNS:
			if victory_turn_count <= 0:
				push_error("BattleData: victory_turn_count must be > 0")
				return false
		VictoryCondition.PROTECT_UNIT:
			if victory_protect_index < 0 or victory_protect_index >= neutrals.size():
				push_error("BattleData: Invalid victory_protect_index: %d" % victory_protect_index)
				return false
	return true


## Validate defeat condition configuration
func validate_defeat_condition() -> bool:
	match defeat_condition:
		DefeatCondition.TURN_LIMIT:
			if defeat_turn_limit <= 0:
				push_error("BattleData: defeat_turn_limit must be > 0")
				return false
		DefeatCondition.UNIT_DIES:
			if defeat_protect_index < 0 or defeat_protect_index >= neutrals.size():
				push_error("BattleData: Invalid defeat_protect_index: %d" % defeat_protect_index)
				return false
	return true


## Get enemies that should spawn at battle start (spawn_delay == 0 or absent)
func get_initial_enemies() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy: Dictionary in enemies:
		var delay: int = enemy.get("spawn_delay", 0)
		if delay <= 0:
			result.append(enemy)
	return result


## Get enemies that should spawn as reinforcements on the given turn
func get_reinforcements_for_turn(turn: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy: Dictionary in enemies:
		if "spawn_delay" in enemy:
			var delay: int = enemy["spawn_delay"] as int
			if delay == turn:
				result.append(enemy)
	return result


## Get ALL enemies with spawn_delay greater than the current turn
## Used by early reinforcement spawning when all visible enemies are dead
func get_all_pending_reinforcements(current_turn: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy: Dictionary in enemies:
		if "spawn_delay" in enemy:
			var delay: int = enemy["spawn_delay"] as int
			if delay > current_turn:
				result.append(enemy)
	return result


## Check if any enemies have a spawn_delay greater than the given turn
func has_pending_reinforcements(current_turn: int) -> bool:
	for enemy: Dictionary in enemies:
		if "spawn_delay" in enemy:
			var delay: int = enemy["spawn_delay"] as int
			if delay > current_turn:
				return true
	return false


## Get dialogue for a specific turn (if any)
func get_turn_dialogue(turn: int) -> DialogueData:
	if turn in turn_dialogues:
		return turn_dialogues[turn] as DialogueData
	return null


## Validate that required fields are set
func validate() -> bool:
	if battle_name.is_empty():
		push_error("BattleData: battle_name is required")
		return false
	if map_scene == null:
		push_error("BattleData: map_scene is required")
		return false
	if not validate_enemies():
		return false
	if not validate_neutrals():
		return false
	if not validate_victory_condition():
		return false
	if not validate_defeat_condition():
		return false
	return true
