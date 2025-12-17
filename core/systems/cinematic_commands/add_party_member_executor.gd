## Add party member command executor
## Recruits a character to the party during a cinematic
##
## Params:
##   character_id: String - ID of the character in ModRegistry
##   to_active: bool (default true) - Add to active party vs reserves
##   recruitment_chapter: String (optional) - Chapter ID for tracking when joined
class_name AddPartyMemberExecutor
extends CinematicCommandExecutor


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
			}
		}
	}


func execute(command: Dictionary, _manager: Node) -> bool:
	var params: Dictionary = command.get("params", {})
	var character_id: String = params.get("character_id", "")
	var to_active: bool = params.get("to_active", true)
	var recruitment_chapter: String = params.get("recruitment_chapter", "")

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

	return true  # Synchronous, completes immediately


## Resolve character from ID (supports both resource ID like "max" and character_uid like "hk7wm4np")
func _resolve_character(character_id: String) -> CharacterData:
	# First try by character_uid (what the editor stores)
	var character: CharacterData = ModLoader.registry.get_character_by_uid(character_id)
	if character:
		return character

	# Fallback to resource ID lookup
	return ModLoader.registry.get_resource("character", character_id) as CharacterData
