## TriggerBattleExecutor - Triggers a battle and branches based on outcome
##
## Starts a battle by ID, waits for completion, then branches to different
## cinematics based on victory or defeat. Optionally sets flags on each outcome.
##
## Parameters:
##   battle_id: String - The battle ID to start (from mod registry)
##   on_victory_cinematic: String (optional) - Cinematic to play on victory
##   on_defeat_cinematic: String (optional) - Cinematic to play on defeat
##   on_victory_flags: Array[String] (optional) - Flags to set on victory
##   on_defeat_flags: Array[String] (optional) - Flags to set on defeat
##
## Usage in cinematic JSON:
##   {
##     "type": "trigger_battle",
##     "params": {
##       "battle_id": "goblin_ambush",
##       "on_victory_cinematic": "victory_scene",
##       "on_defeat_cinematic": "defeat_scene",
##       "on_victory_flags": ["defeated_goblins"],
##       "on_defeat_flags": ["fled_battle"]
##     }
##   }
class_name TriggerBattleExecutor
extends CinematicCommandExecutor

var _manager: Node = null
var _on_victory_cinematic: String = ""
var _on_defeat_cinematic: String = ""
var _on_victory_flags: Array[String] = []
var _on_defeat_flags: Array[String] = []


func execute(command: Dictionary, manager: Node) -> bool:
	_manager = manager
	var params: Dictionary = command.get("params", {})

	# Get battle ID (required)
	var battle_id: String = params.get("battle_id", "")
	if battle_id.is_empty():
		push_error("TriggerBattleExecutor: battle_id is required")
		return true  # Complete immediately on error

	# Validate battle exists before starting
	var battle_data: BattleData = ModLoader.registry.get_battle(battle_id)
	if not battle_data:
		push_error("TriggerBattleExecutor: Battle '%s' not found in registry" % battle_id)
		return true

	# Store outcome handlers
	_on_victory_cinematic = params.get("on_victory_cinematic", "")
	_on_defeat_cinematic = params.get("on_defeat_cinematic", "")

	# Parse flag arrays (accept string or array)
	_on_victory_flags = CinematicCommandExecutor.parse_flag_array(params.get("on_victory_flags", []))
	_on_defeat_flags = CinematicCommandExecutor.parse_flag_array(params.get("on_defeat_flags", []))

	# Connect to BattleManager's battle_ended signal
	if not BattleManager.battle_ended.is_connected(_on_battle_ended):
		BattleManager.battle_ended.connect(_on_battle_ended)

	# Set manager state to waiting (cinematic pauses during battle)
	manager.current_state = manager.State.WAITING_FOR_COMMAND

	# Tell BattleManager that we'll handle post-battle transitions
	GameState.external_battle_handler = true

	# Start the battle - this will transition to battle scene
	# The cinematic will resume when battle_ended fires
	TriggerManager.start_battle(battle_id)

	return false  # Async - waiting for battle to complete


func _on_battle_ended(victory: bool) -> void:
	# Disconnect immediately to avoid duplicate calls
	if BattleManager.battle_ended.is_connected(_on_battle_ended):
		BattleManager.battle_ended.disconnect(_on_battle_ended)

	# Set flags based on outcome
	if victory:
		for flag: String in _on_victory_flags:
			GameState.set_flag(flag)
	else:
		for flag: String in _on_defeat_flags:
			GameState.set_flag(flag)

	# Determine follow-up cinematic
	var follow_up_cinematic: String = _on_victory_cinematic if victory else _on_defeat_cinematic

	# Capture manager reference BEFORE _complete() nulls it
	var manager_ref: Node = _manager

	# Complete this command first
	_complete()

	# Play follow-up cinematic if specified, otherwise return to map
	if not follow_up_cinematic.is_empty():
		# Defer to next frame to ensure clean state after battle cleanup
		if is_instance_valid(manager_ref):
			manager_ref.call_deferred("play_cinematic", follow_up_cinematic)
	else:
		# No follow-up cinematic - return to the map we came from
		TriggerManager.call_deferred("return_to_map")


func _complete() -> void:
	CinematicCommandExecutor.complete_async_command(_manager, true)
	_cleanup()


func _cleanup() -> void:
	_on_victory_cinematic = ""
	_on_defeat_cinematic = ""
	_on_victory_flags.clear()
	_on_defeat_flags.clear()
	_manager = null


func interrupt() -> void:
	# Clean up signal connections if cinematic is skipped
	if BattleManager.battle_ended.is_connected(_on_battle_ended):
		BattleManager.battle_ended.disconnect(_on_battle_ended)
	_cleanup()


func get_editor_metadata() -> Dictionary:
	return {
		"description": "Start a battle and branch based on victory/defeat",
		"category": "Battle",
		"icon": "AudioStreamPlayer",  # Using Godot's built-in icon
		"has_target": false,
		"params": {
			"battle_id": {
				"type": "battle",  # Custom picker type for battle resources
				"default": "",
				"hint": "The battle to start (from mod registry)"
			},
			"on_victory_cinematic": {
				"type": "cinematic",  # Custom picker type for cinematics
				"default": "",
				"hint": "Cinematic to play when battle is won (optional)"
			},
			"on_defeat_cinematic": {
				"type": "cinematic",
				"default": "",
				"hint": "Cinematic to play when battle is lost (optional)"
			},
			"on_victory_flags": {
				"type": "string_array",
				"default": [],
				"hint": "Flags to set when battle is won (optional)"
			},
			"on_defeat_flags": {
				"type": "string_array",
				"default": [],
				"hint": "Flags to set when battle is lost (optional)"
			}
		}
	}
