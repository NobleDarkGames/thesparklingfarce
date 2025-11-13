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
@export var map_scene: PackedScene
@export var grid_width: int = 20
@export var grid_height: int = 15
## Tile size in pixels
@export var tile_size: int = 32

@export_group("Player Forces")
@export var player_units: Array[CharacterData] = []
@export var player_positions: Array[Vector2i] = []
## Maximum number of units player can deploy
@export var max_player_units: int = 12
## Can player choose deployment positions?
@export var allow_custom_deployment: bool = false

@export_group("Enemy Forces")
@export var enemy_units: Array[CharacterData] = []
@export var enemy_positions: Array[Vector2i] = []
## Enemy AI behavior ("aggressive", "defensive", "patrol")
@export var enemy_ai_behavior: String = "aggressive"

@export_group("Neutral/NPC Forces")
@export var neutral_units: Array[CharacterData] = []
@export var neutral_positions: Array[Vector2i] = []

@export_group("Victory Conditions")
@export var victory_condition: VictoryCondition = VictoryCondition.DEFEAT_ALL_ENEMIES
@export var victory_target_position: Vector2i = Vector2i.ZERO
@export var victory_target_unit: CharacterData
@export var victory_turn_count: int = 0
@export var custom_victory_script: GDScript

@export_group("Defeat Conditions")
@export var defeat_condition: DefeatCondition = DefeatCondition.ALL_UNITS_DEFEATED
@export var defeat_target_unit: CharacterData
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


## Validate unit positions match unit counts
func validate_unit_placement() -> bool:
	if player_units.size() != player_positions.size():
		push_error("BattleData: player_units and player_positions size mismatch")
		return false
	if enemy_units.size() != enemy_positions.size():
		push_error("BattleData: enemy_units and enemy_positions size mismatch")
		return false
	if neutral_units.size() != neutral_positions.size():
		push_error("BattleData: neutral_units and neutral_positions size mismatch")
		return false
	return true


## Check if position is within grid bounds
func is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < grid_width and pos.y >= 0 and pos.y < grid_height


## Validate all unit positions are within bounds
func validate_positions() -> bool:
	for pos in player_positions:
		if not is_valid_position(pos):
			push_error("BattleData: Invalid player position: " + str(pos))
			return false
	for pos in enemy_positions:
		if not is_valid_position(pos):
			push_error("BattleData: Invalid enemy position: " + str(pos))
			return false
	for pos in neutral_positions:
		if not is_valid_position(pos):
			push_error("BattleData: Invalid neutral position: " + str(pos))
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
	if grid_width < 1 or grid_height < 1:
		push_error("BattleData: grid dimensions must be positive")
		return false
	if not validate_unit_placement():
		return false
	if not validate_positions():
		return false
	return true
