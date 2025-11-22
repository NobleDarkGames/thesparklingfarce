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

@export_group("Enemy Forces")
## Array of dictionaries with these fields:
## - character: CharacterData (required)
## - position: Vector2i (required)
## - ai_brain: AIBrain (required) - Resource reference to AI behavior
@export var enemies: Array[Dictionary] = []

@export_group("Neutral/NPC Forces")
## Array of dictionaries with these fields:
## - character: CharacterData (required)
## - position: Vector2i (required)
## - ai_brain: AIBrain (required) - Resource reference to AI behavior
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
## Dialogue to show before battle starts
@export var pre_battle_dialogue: DialogueData
## Dialogue to show when player wins
@export var victory_dialogue: DialogueData
## Dialogue to show when player loses
@export var defeat_dialogue: DialogueData
## Dialogue to show at specific turns: {turn_number: DialogueData}
@export var turn_dialogues: Dictionary = {}

@export_group("Audio")
@export var background_music: AudioStream
@export var victory_music: AudioStream
@export var defeat_music: AudioStream

@export_group("Rewards")
@export var experience_reward: int = 0
@export var gold_reward: int = 0
@export var item_rewards: Array[ItemData] = []

@export_group("Environmental Settings")
## Weather effects ("none", "rain", "snow", "fog")
@export var weather: String = "none"
## Time of day ("day", "night", "dawn", "dusk")
@export var time_of_day: String = "day"


## Validate enemy dictionary structure
func validate_enemies() -> bool:
	for i in range(enemies.size()):
		var enemy: Dictionary = enemies[i]
		if not 'character' in enemy or enemy.character == null:
			push_error("BattleData: Enemy %d missing character" % i)
			return false
		if not 'position' in enemy:
			push_error("BattleData: Enemy %d missing position" % i)
			return false
		if not 'ai_brain' in enemy or enemy.ai_brain == null:
			push_error("BattleData: Enemy %d missing ai_brain" % i)
			return false
	return true


## Validate neutral dictionary structure
func validate_neutrals() -> bool:
	for i in range(neutrals.size()):
		var neutral: Dictionary = neutrals[i]
		if not 'character' in neutral or neutral.character == null:
			push_error("BattleData: Neutral %d missing character" % i)
			return false
		if not 'position' in neutral:
			push_error("BattleData: Neutral %d missing position" % i)
			return false
		if not 'ai_brain' in neutral or neutral.ai_brain == null:
			push_error("BattleData: Neutral %d missing ai_brain" % i)
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


## Get dialogue for a specific turn (if any)
func get_turn_dialogue(turn: int) -> DialogueData:
	if turn in turn_dialogues:
		return turn_dialogues[turn]
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
