## Rejoin party member command executor
## Returns a departed character to the party (rescued, returned, resurrected)
##
## Params:
##   character_id: String - ID of the character in ModRegistry
##   to_active: bool (default true) - Add to active party vs reserves
##   resurrect: bool (default false) - If true, also sets is_alive=true
class_name RejoinPartyMemberExecutor
extends CinematicCommandExecutor


func get_editor_metadata() -> Dictionary:
	return {
		"description": "Return a departed character to the party",
		"category": "Party",
		"icon": "Loop",
		"has_target": false,
		"params": {
			"character_id": {
				"type": "character",
				"default": "",
				"hint": "Character to rejoin (must be in departed list)"
			},
			"to_active": {
				"type": "bool",
				"default": true,
				"hint": "Add to active party (true) or reserves (false)"
			},
			"resurrect": {
				"type": "bool",
				"default": false,
				"hint": "Also set is_alive=true (for previously dead characters)"
			}
		}
	}


func execute(command: Dictionary, _manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})
	var character_id: String = params.get("character_id", "")
	var to_active: bool = params.get("to_active", true)
	var resurrect: bool = params.get("resurrect", false)

	if character_id.is_empty():
		push_error("RejoinPartyMemberExecutor: Missing character_id parameter")
		return true  # Complete immediately on error

	# Look up character in ModRegistry (supports both resource ID and character_uid)
	var character: CharacterData = _resolve_character(character_id)
	if not character:
		push_error("RejoinPartyMemberExecutor: Character '%s' not found in ModRegistry" % character_id)
		return true

	# Check if character is in departed list
	if not PartyManager.is_departed(character.character_uid):
		# Maybe they were never in the party - try regular add
		if character not in PartyManager.party_members:
			push_warning("RejoinPartyMemberExecutor: Character '%s' was not departed, adding as new member" % character_id)
			PartyManager.add_member(character, to_active)
		else:
			push_warning("RejoinPartyMemberExecutor: Character '%s' is already in party" % character_id)
		return true

	# Handle resurrection before rejoin if needed
	if resurrect:
		var departed_data: CharacterSaveData = PartyManager.get_departed_save_data(character.character_uid)
		if departed_data:
			departed_data.is_alive = true

	# Rejoin from departed list (restores save data)
	var success: bool = PartyManager.rejoin_departed_member(character, to_active)
	if not success:
		push_error("RejoinPartyMemberExecutor: Failed to rejoin character '%s'" % character_id)

	return true  # Synchronous, completes immediately


## Resolve character from ID (supports both resource ID like "max" and character_uid like "hk7wm4np")
func _resolve_character(character_id: String) -> CharacterData:
	# First try by character_uid (what the editor stores)
	var character: CharacterData = ModLoader.registry.get_character_by_uid(character_id)
	if character:
		return character

	# Fallback to resource ID lookup
	return ModLoader.registry.get_resource("character", character_id) as CharacterData
