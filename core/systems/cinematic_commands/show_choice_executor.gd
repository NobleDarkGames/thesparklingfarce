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
##
## Supported Actions:
##   - battle: Start a battle (value = battle_id)
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
##         {"label": "Fight!", "action": "battle", "value": "goblin_ambush"},
##         {"label": "Run away", "action": "set_flag", "value": "fled_goblins"},
##         {"label": "Never mind", "action": "none", "value": ""}
##       ]
##     }
##   }
class_name ShowChoiceExecutor
extends CinematicCommandExecutor

var _manager: Node = null
var _choices: Array[Dictionary] = []


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
					"description": choice.get("description", "")
				})

	if _choices.is_empty():
		push_error("ShowChoiceExecutor: No valid choices after validation")
		return true

	# Connect to choice_selected signal before showing choices
	if not DialogManager.choice_selected.is_connected(_on_choice_selected):
		DialogManager.choice_selected.connect(_on_choice_selected)

	# Connect to dialog_cancelled to handle player backing out
	if not DialogManager.dialog_cancelled.is_connected(_on_dialog_cancelled):
		DialogManager.dialog_cancelled.connect(_on_dialog_cancelled)

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
	if DialogManager.dialog_cancelled.is_connected(_on_dialog_cancelled):
		DialogManager.dialog_cancelled.disconnect(_on_dialog_cancelled)

	# Get the selected choice
	if choice_index < 0 or choice_index >= _choices.size():
		push_error("ShowChoiceExecutor: Invalid choice index %d" % choice_index)
		_complete()
		return

	var choice: Dictionary = _choices[choice_index]
	var action: String = choice.get("action", "none")
	var value: String = choice.get("value", "")

	# Clear external choices from DialogManager
	DialogManager.clear_external_choices()

	# Execute the action
	_execute_action(action, value)


func _on_dialog_cancelled() -> void:
	# Player backed out of the choice menu
	if DialogManager.choice_selected.is_connected(_on_choice_selected):
		DialogManager.choice_selected.disconnect(_on_choice_selected)
	if DialogManager.dialog_cancelled.is_connected(_on_dialog_cancelled):
		DialogManager.dialog_cancelled.disconnect(_on_dialog_cancelled)

	# Clear external choices from DialogManager
	DialogManager.clear_external_choices()

	# End the cinematic (player chose to cancel)
	CinematicsManager.skip_cinematic()
	_cleanup()


func _execute_action(action: String, value: String) -> void:
	match action:
		"battle":
			_action_battle(value)
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


func _action_battle(battle_id: String) -> void:
	if battle_id.is_empty():
		push_error("ShowChoiceExecutor: battle action requires battle_id")
		_complete()
		return

	# Battle ends the cinematic and transitions to battle scene
	# Complete first so cinematic can clean up, then trigger battle
	_complete()

	# Use TriggerManager to start the battle
	TriggerManager.start_battle(battle_id)


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
	if _manager:
		_manager.current_state = _manager.State.PLAYING
		_manager._command_completed = true
	_cleanup()


func _cleanup() -> void:
	_choices.clear()
	_manager = null


func interrupt() -> void:
	# Clean up signal connections if cinematic is skipped
	if DialogManager.choice_selected.is_connected(_on_choice_selected):
		DialogManager.choice_selected.disconnect(_on_choice_selected)
	if DialogManager.dialog_cancelled.is_connected(_on_dialog_cancelled):
		DialogManager.dialog_cancelled.disconnect(_on_dialog_cancelled)
	if ShopManager.shop_closed.is_connected(_on_shop_closed):
		ShopManager.shop_closed.disconnect(_on_shop_closed)

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
