## Set character status command executor
## Modifies is_alive/is_available flags on a character's save data
## Works on both active party members and departed characters
##
## Params:
##   character_id: String - ID of the character in ModRegistry
##   is_alive: bool (optional) - Set alive status
##   is_available: bool (optional) - Set availability status
class_name SetCharacterStatusExecutor
extends CinematicCommandExecutor


func get_editor_metadata() -> Dictionary:
	return {
		"description": "Set a character's alive/available status flags",
		"category": "Party",
		"icon": "StatusWarning",
		"has_target": false,
		"params": {
			"character_id": {
				"type": "character",
				"default": "",
				"hint": "Character to modify (in party or departed)"
			},
			"is_alive": {
				"type": "enum",
				"default": "",
				"options": ["", "true", "false"],
				"hint": "Set alive status (empty = no change)"
			},
			"is_available": {
				"type": "enum",
				"default": "",
				"options": ["", "true", "false"],
				"hint": "Set availability status (empty = no change)"
			}
		}
	}


func execute(command: Dictionary, _manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})
	var character_id: String = params.get("character_id", "")

	if character_id.is_empty():
		push_error("SetCharacterStatusExecutor: Missing character_id parameter")
		return true  # Complete immediately on error

	# Look up character in ModRegistry (supports both resource ID and character_uid)
	var character: CharacterData = CinematicCommandExecutor.resolve_character(character_id)
	if not character:
		push_error("SetCharacterStatusExecutor: Character '%s' not found in ModRegistry" % character_id)
		return true

	var uid: String = character.character_uid

	# Try to find save data - check active party first, then departed
	var save_data: CharacterSaveData = PartyManager.get_member_save_data(uid)
	if not save_data:
		save_data = PartyManager.get_departed_save_data(uid)

	if not save_data:
		push_error("SetCharacterStatusExecutor: No save data found for character '%s' (not in party or departed)" % character_id)
		return true

	# Apply status changes if provided
	if "is_alive" in params:
		var alive_value: bool = params["is_alive"]
		save_data.is_alive = alive_value
		# If marked dead, also mark unavailable
		if not alive_value:
			save_data.is_available = false

	if "is_available" in params:
		var available_value: bool = params["is_available"]
		save_data.is_available = available_value

	return true  # Synchronous, completes immediately
