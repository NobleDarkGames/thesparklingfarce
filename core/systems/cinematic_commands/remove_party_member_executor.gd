## Remove party member command executor
## Removes a character from the party during a cinematic (story departure/death)
##
## Params:
##   character_id: String - ID of the character in ModRegistry
##   reason: String (optional) - "left", "died", "captured", etc. for narrative context
##   mark_dead: bool (default false) - If true, sets is_alive=false on save data
##   mark_unavailable: bool (default false) - If true, sets is_available=false (temporary absence)
##   show_message: bool (default true) - Show system message when character leaves
##   custom_message: String (optional) - Custom message (supports {char:id} interpolation)
class_name RemovePartyMemberExecutor
extends CinematicCommandExecutor

## Default messages by reason (use %s for character_uid)
const DEFAULT_MESSAGES: Dictionary = {
	"left": "{char:%s} has left the party.",
	"died": "{char:%s} has fallen...",
	"captured": "{char:%s} was captured!",
	"betrayed": "{char:%s} has betrayed the force!",
	"missing": "{char:%s} has gone missing."
}


func get_editor_metadata() -> Dictionary:
	return {
		"description": "Remove a character from the party (departure/death)",
		"category": "Party",
		"icon": "RemoveUser",
		"has_target": false,
		"params": {
			"character_id": {
				"type": "character",
				"default": "",
				"hint": "Character to remove (from ModRegistry)"
			},
			"reason": {
				"type": "enum",
				"default": "left",
				"options": ["left", "died", "captured", "betrayed", "missing"],
				"hint": "Why they left (for narrative tracking)"
			},
			"mark_dead": {
				"type": "bool",
				"default": false,
				"hint": "Set is_alive=false (permanent death)"
			},
			"mark_unavailable": {
				"type": "bool",
				"default": false,
				"hint": "Set is_available=false (temporary absence)"
			},
			"show_message": {
				"type": "bool",
				"default": true,
				"hint": "Show system message when character leaves"
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
	var reason: String = params.get("reason", "left")
	var mark_dead: bool = params.get("mark_dead", false)
	var mark_unavailable: bool = params.get("mark_unavailable", false)
	var show_message: bool = params.get("show_message", true)
	var custom_message: String = params.get("custom_message", "")

	if character_id.is_empty():
		push_error("RemovePartyMemberExecutor: Missing character_id parameter")
		return true  # Complete immediately on error

	# Look up character in ModRegistry (supports both resource ID and character_uid)
	var character: CharacterData = CinematicCommandExecutor.resolve_character(character_id) as CharacterData
	if not character:
		push_error("RemovePartyMemberExecutor: Character '%s' not found in ModRegistry" % character_id)
		return true

	# Check if in party
	if character not in PartyManager.party_members:
		push_warning("RemovePartyMemberExecutor: Character '%s' is not in party" % character_id)
		return true

	# Remove with preserved save data (for potential rejoin or save tracking)
	var save_data: CharacterSaveData = PartyManager.remove_member_preserve_data(character, reason)
	if not save_data:
		# Hero removal blocked - this is intentional game design
		push_warning("RemovePartyMemberExecutor: Could not remove '%s' (reason: %s) - hero cannot be removed" % [character_id, reason])
		return true

	# Update status flags on preserved save data
	if mark_dead:
		save_data.is_alive = false
		save_data.is_available = false  # Dead characters are also unavailable
	elif mark_unavailable:
		save_data.is_available = false

	# Show system message if enabled
	if show_message:
		var message: String = custom_message
		if message.is_empty():
			var template: String = str(DEFAULT_MESSAGES.get(reason, DEFAULT_MESSAGES["left"]))
			message = template % character.character_uid
		return CinematicCommandExecutor.show_system_message(message, manager)

	return true  # Synchronous, completes immediately
