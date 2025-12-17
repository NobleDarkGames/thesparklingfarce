## Add party member command executor
## Recruits a character to the party during a cinematic
##
## Params:
##   character_id: String - ID of the character in ModRegistry
##   to_active: bool (default true) - Add to active party vs reserves
##   recruitment_chapter: String (optional) - Chapter ID for tracking when joined
##   show_message: bool (default true) - Show "{name} joins the force!" message
##   custom_message: String (optional) - Custom message (supports {char:id} interpolation)
class_name AddPartyMemberExecutor
extends CinematicCommandExecutor

## Default message shown when a character joins
const DEFAULT_JOIN_MESSAGE: String = "{char:%s} joined the force!"

## Counter for generating unique inline dialog IDs
static var _inline_dialog_counter: int = 0


func get_editor_metadata() -> Dictionary:
	return {
		"description": "Add a character to the party (recruitment)",
		"category": "Party",
		"icon": "AddUser",
		"has_target": false,
		"params": {
			"character_id": {
				"type": "character",
				"default": "",
				"hint": "Character to recruit (from ModRegistry)"
			},
			"to_active": {
				"type": "bool",
				"default": true,
				"hint": "Add to active party (true) or reserves (false)"
			},
			"recruitment_chapter": {
				"type": "string",
				"default": "",
				"hint": "Chapter ID for tracking when they joined (optional)"
			},
			"show_message": {
				"type": "bool",
				"default": true,
				"hint": "Show system message when character joins"
			},
			"custom_message": {
				"type": "string",
				"default": "",
				"hint": "Custom message (leave empty for default). Use {char:id} for names."
			}
		}
	}


func execute(command: Dictionary, manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})
	var character_id: String = params.get("character_id", "")
	var to_active: bool = params.get("to_active", true)
	var recruitment_chapter: String = params.get("recruitment_chapter", "")
	var show_message: bool = params.get("show_message", true)
	var custom_message: String = params.get("custom_message", "")

	if character_id.is_empty():
		push_error("AddPartyMemberExecutor: Missing character_id parameter")
		return true  # Complete immediately on error

	# Look up character in ModRegistry (supports both resource ID and character_uid)
	var character: CharacterData = _resolve_character(character_id)
	if not character:
		push_error("AddPartyMemberExecutor: Character '%s' not found in ModRegistry" % character_id)
		return true

	# Check if already in party
	if character in PartyManager.party_members:
		push_warning("AddPartyMemberExecutor: Character '%s' is already in party" % character_id)
		return true

	# Add to party
	var success: bool = PartyManager.add_member(character, to_active)
	if not success:
		push_error("AddPartyMemberExecutor: Failed to add character '%s' to party" % character_id)
		return true

	# Set recruitment chapter if provided
	if not recruitment_chapter.is_empty():
		var save_data: CharacterSaveData = PartyManager.get_member_save_data(character.character_uid)
		if save_data:
			save_data.recruitment_chapter = recruitment_chapter

	# Show system message if enabled
	if show_message:
		var message: String = custom_message if not custom_message.is_empty() else DEFAULT_JOIN_MESSAGE % character.character_uid
		return _show_system_message(message, manager)

	return true  # Synchronous, completes immediately


## Show a system message dialog and wait for player input
func _show_system_message(message: String, manager: Node) -> bool:
	# Create temporary DialogueData with one line
	var dialogue: DialogueData = DialogueData.new()

	# Generate unique ID
	_inline_dialog_counter += 1
	dialogue.dialogue_id = "_party_msg_%d_%d" % [Time.get_ticks_msec(), _inline_dialog_counter]

	# Add the message line (will be interpolated by DialogBox)
	dialogue.lines.append({
		"text": message,
		"speaker_name": ""  # No speaker for system messages
	})

	# Start dialog via DialogManager
	if DialogManager.start_dialog_from_resource(dialogue):
		manager.current_state = manager.State.WAITING_FOR_DIALOG
		manager._is_waiting = true
		return false  # Async - wait for dialog to complete
	else:
		push_warning("AddPartyMemberExecutor: Failed to show system message")
		return true  # Complete anyway


## Resolve character from ID (supports both resource ID like "max" and character_uid like "hk7wm4np")
func _resolve_character(character_id: String) -> CharacterData:
	# First try by character_uid (what the editor stores)
	var character: CharacterData = ModLoader.registry.get_character_by_uid(character_id)
	if character:
		return character

	# Fallback to resource ID lookup
	return ModLoader.registry.get_resource("character", character_id) as CharacterData
