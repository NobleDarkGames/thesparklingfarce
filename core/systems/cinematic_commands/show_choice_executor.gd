## ShowChoiceExecutor - Presents choices to the player during a cinematic
##
## Each choice triggers one action when selected. Keeps things simple:
## one choice = one action = one value.
##
## Parameters:
##   choices: Array[Dictionary] - Each choice has:
##     - label: String - Text shown to player
##     - action: String - What to do: "battle", "set_flag", "cinematic", "set_variable", "shop", "none"
##     - value: String - Parameter for the action (battle_id, flag_name, cinematic_id, etc.)
##     - description: String (optional) - Tooltip/secondary text
##     Battle-specific options (only used when action = "battle"):
##     - on_victory_cinematic: String (optional) - Cinematic to play on victory
##     - on_defeat_cinematic: String (optional) - Cinematic to play on defeat
##     - on_victory_flags: Array[String] (optional) - Flags to set on victory
##     - on_defeat_flags: Array[String] (optional) - Flags to set on defeat
##
## Supported Actions:
##   - battle: Start a battle (value = battle_id), with optional victory/defeat branching
##   - set_flag: Set a GameState flag (value = flag_name)
##   - cinematic: Play another cinematic (value = cinematic_id)
##   - set_variable: Set a variable (value = "key:value")
##   - shop: Open a shop (value = shop_id)
##   - none: Continue without action (for dismiss/cancel choices)
##
## Usage in cinematic JSON:
##   {
##     "type": "show_choice",
##     "params": {
##       "choices": [
##         {
##           "label": "Fight!",
##           "action": "battle",
##           "value": "goblin_ambush",
##           "on_victory_cinematic": "victory_scene",
##           "on_victory_flags": ["defeated_goblins"]
##         },
##         {"label": "Run away", "action": "set_flag", "value": "fled_goblins"},
##         {"label": "Never mind", "action": "none", "value": ""}
##       ]
##     }
##   }
class_name ShowChoiceExecutor
extends CinematicCommandExecutor

var _manager: Node = null
var _choices: Array[Dictionary] = []

# Battle outcome tracking (mirrors trigger_battle_executor)
var _on_victory_cinematic: String = ""
var _on_defeat_cinematic: String = ""
var _on_victory_flags: Array[String] = []
var _on_defeat_flags: Array[String] = []


func execute(command: Dictionary, manager: Node) -> bool:
	_manager = manager
	var params: Dictionary = command.get("params", {})
	var raw_choices: Array = params.get("choices", [])

	if raw_choices.is_empty():
		push_error("ShowChoiceExecutor: No choices provided")
		return true  # Complete immediately on error

	# Validate and store choices
	_choices.clear()
	for choice_val: Variant in raw_choices:
		if choice_val is Dictionary:
			var choice: Dictionary = choice_val
			if "label" in choice:
				_choices.append({
					"label": choice.get("label", ""),
					"value": choice.get("value", ""),
					"action": choice.get("action", "none"),
					"description": choice.get("description", ""),
					# Battle-specific options (same as trigger_battle command)
					"on_victory_cinematic": choice.get("on_victory_cinematic", ""),
					"on_defeat_cinematic": choice.get("on_defeat_cinematic", ""),
					"on_victory_flags": choice.get("on_victory_flags", []),
					"on_defeat_flags": choice.get("on_defeat_flags", [])
				})

	if _choices.is_empty():
		push_error("ShowChoiceExecutor: No valid choices after validation")
		return true

	# Connect to choice_selected signal before showing choices
	if not DialogManager.choice_selected.is_connected(_on_choice_selected):
		DialogManager.choice_selected.connect(_on_choice_selected)

	# SF2-authentic: Choices cannot be cancelled - player must pick one.
	# Content authors should include a "Never mind" option (action: "none") when appropriate.

	# Show choices via DialogManager's external choice API
	if not DialogManager.show_choices(_choices):
		push_error("ShowChoiceExecutor: Failed to show choices")
		_cleanup()
		return true

	# Set manager state to wait for choice
	manager.current_state = manager.State.WAITING_FOR_COMMAND
	return false  # Async - waiting for player choice


func _on_choice_selected(choice_index: int, _next_dialogue: DialogueData) -> void:
	# Disconnect immediately to avoid duplicate calls
	if DialogManager.choice_selected.is_connected(_on_choice_selected):
		DialogManager.choice_selected.disconnect(_on_choice_selected)

	# Get the selected choice
	if choice_index < 0 or choice_index >= _choices.size():
		push_error("ShowChoiceExecutor: Invalid choice index %d" % choice_index)
		_complete()
		return

	var choice: Dictionary = _choices[choice_index]

	# Clear external choices from DialogManager
	DialogManager.clear_external_choices()

	# Execute the action (pass full choice for action-specific options)
	_execute_action(choice)


func _execute_action(choice: Dictionary) -> void:
	var action: String = choice.get("action", "none")
	var value: String = choice.get("value", "")

	match action:
		"battle":
			_action_battle(choice)
		"set_flag":
			_action_set_flag(value)
		"cinematic":
			_action_cinematic(value)
		"set_variable":
			_action_set_variable(value)
		"shop":
			_action_shop(value)
		"none", "":
			# Just continue the cinematic
			_complete()
		_:
			push_warning("ShowChoiceExecutor: Unknown action '%s', continuing" % action)
			_complete()


func _action_battle(choice: Dictionary) -> void:
	var battle_id: String = choice.get("value", "")
	if battle_id.is_empty():
		push_error("ShowChoiceExecutor: battle action requires battle_id")
		_complete()
		return

	# Validate battle exists
	var battle_data: BattleData = ModLoader.registry.get_battle(battle_id)
	if not battle_data:
		push_error("ShowChoiceExecutor: Battle '%s' not found in registry" % battle_id)
		_complete()
		return

	# Store outcome handlers (same as trigger_battle_executor)
	_on_victory_cinematic = choice.get("on_victory_cinematic", "")
	_on_defeat_cinematic = choice.get("on_defeat_cinematic", "")

	# Parse flag arrays (accept string or array)
	_on_victory_flags = CinematicCommandExecutor.parse_flag_array(choice.get("on_victory_flags", []))
	_on_defeat_flags = CinematicCommandExecutor.parse_flag_array(choice.get("on_defeat_flags", []))

	# Connect to BattleManager's battle_ended signal
	if not BattleManager.battle_ended.is_connected(_on_battle_ended):
		BattleManager.battle_ended.connect(_on_battle_ended)

	# Tell BattleManager that we'll handle post-battle transitions
	GameState.external_battle_handler = true

	# Start the battle - cinematic will resume when battle_ended fires
	TriggerManager.start_battle(battle_id)


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

	# Complete this command
	_complete()

	# Play follow-up cinematic if specified, otherwise return to map
	if not follow_up_cinematic.is_empty():
		CinematicsManager.call_deferred("play_cinematic", follow_up_cinematic)
	else:
		TriggerManager.call_deferred("return_to_map")


func _action_set_flag(flag_name: String) -> void:
	if flag_name.is_empty():
		push_warning("ShowChoiceExecutor: set_flag action has empty flag name")
	else:
		GameState.set_flag(flag_name)
	_complete()


func _action_cinematic(cinematic_id: String) -> void:
	if cinematic_id.is_empty():
		push_error("ShowChoiceExecutor: cinematic action requires cinematic_id")
		_complete()
		return

	# Complete current command, then queue the new cinematic
	# The cinematic will play after the current one ends (via chaining)
	# For immediate play, we need to end current cinematic first
	_complete()

	# Play the new cinematic - this works because we've completed our command
	# and the manager will check for more commands, find none (or process them),
	# then this cinematic takes over
	CinematicsManager.play_cinematic(cinematic_id)


func _action_set_variable(key_value: String) -> void:
	if key_value.is_empty():
		push_warning("ShowChoiceExecutor: set_variable has empty value")
		_complete()
		return

	# Parse "key:value" format
	var colon_pos: int = key_value.find(":")
	if colon_pos <= 0:
		# No colon - treat as flag
		GameState.set_flag(key_value)
	else:
		var key: String = key_value.substr(0, colon_pos)
		var val: String = key_value.substr(colon_pos + 1)
		GameState.set_campaign_data(key, val)

	_complete()


func _action_shop(shop_id: String) -> void:
	if shop_id.is_empty():
		push_error("ShowChoiceExecutor: shop action requires shop_id")
		_complete()
		return

	# Look up the shop
	var shop_data: ShopData = ModLoader.registry.get_shop(shop_id)
	if not shop_data:
		push_error("ShowChoiceExecutor: Shop '%s' not found" % shop_id)
		_complete()
		return

	# Get save data for gold
	var save_data: SaveData = null
	if SaveManager and "current_save" in SaveManager:
		save_data = SaveManager.current_save

	# Open shop - we need to wait for it to close
	ShopManager.open_shop(shop_data, save_data)

	# Connect to shop_closed to know when to resume
	if not ShopManager.shop_closed.is_connected(_on_shop_closed):
		ShopManager.shop_closed.connect(_on_shop_closed)


func _on_shop_closed() -> void:
	if ShopManager.shop_closed.is_connected(_on_shop_closed):
		ShopManager.shop_closed.disconnect(_on_shop_closed)
	_complete()


func _complete() -> void:
	CinematicCommandExecutor.complete_async_command(_manager, true)
	_cleanup()


func _cleanup() -> void:
	_choices.clear()
	_on_victory_cinematic = ""
	_on_defeat_cinematic = ""
	_on_victory_flags.clear()
	_on_defeat_flags.clear()
	_manager = null


func interrupt() -> void:
	# Clean up signal connections if cinematic is skipped
	if DialogManager.choice_selected.is_connected(_on_choice_selected):
		DialogManager.choice_selected.disconnect(_on_choice_selected)
	if ShopManager.shop_closed.is_connected(_on_shop_closed):
		ShopManager.shop_closed.disconnect(_on_shop_closed)
	if BattleManager.battle_ended.is_connected(_on_battle_ended):
		BattleManager.battle_ended.disconnect(_on_battle_ended)

	# Clear any pending external choices
	DialogManager.clear_external_choices()

	_cleanup()


func get_editor_metadata() -> Dictionary:
	return {
		"description": "Show choices to player, each triggers an action",
		"category": "Dialog",
		"icon": "OptionButton",
		"has_target": false,
		"params": {
			"choices": {
				"type": "choices",
				"default": [],
				"hint": "Each choice has a label, action type, and value"
			}
		}
	}
