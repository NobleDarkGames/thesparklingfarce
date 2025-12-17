## Remove party member command executor
## Removes a character from the party during a cinematic (story departure/death)
##
## Params:
##   character_id: String - ID of the character in ModRegistry
##   reason: String (optional) - "left", "died", "captured", etc. for narrative context
##   mark_dead: bool (default false) - If true, sets is_alive=false on save data
##   mark_unavailable: bool (default false) - If true, sets is_available=false (temporary absence)
class_name RemovePartyMemberExecutor
extends CinematicCommandExecutor


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
			}
		}
	}


func execute(command: Dictionary, _manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})
	var character_id: String = params.get("character_id", "")
	var reason: String = params.get("reason", "left")
	var mark_dead: bool = params.get("mark_dead", false)
	var mark_unavailable: bool = params.get("mark_unavailable", false)

	if character_id.is_empty():
		push_error("RemovePartyMemberExecutor: Missing character_id parameter")
		return true  # Complete immediately on error

	# Look up character in ModRegistry (supports both resource ID and character_uid)
	var character: CharacterData = _resolve_character(character_id)
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

	return true  # Synchronous, completes immediately


## Resolve character from ID (supports both resource ID like "max" and character_uid like "hk7wm4np")
func _resolve_character(character_id: String) -> CharacterData:
	# First try by character_uid (what the editor stores)
	var character: CharacterData = ModLoader.registry.get_character_by_uid(character_id)
	if character:
		return character

	# Fallback to resource ID lookup
	return ModLoader.registry.get_resource("character", character_id) as CharacterData
