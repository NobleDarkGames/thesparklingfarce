@tool
class_name PartyData
extends Resource

## Represents a party composition for battle deployment.
## Can be used for both reusable party templates and campaign-persistent party state.
##
## Shining Force has two party concepts:
## 1. Headquarters roster (your full team)
## 2. Battle deployment (which members you bring)
##
## This resource can represent either, depending on context.

@export var party_name: String = "New Party"
@export_multiline var description: String = ""

@export_group("Party Composition")
## Array of dictionaries with these fields:
## - character: CharacterData (required) - The character in this slot
## - formation_offset: Vector2i (optional) - Relative spawn position in formation
##
## Formation offsets are relative to the battle's player spawn point.
## Example: [(0,0), (1,0), (0,1), (1,1)] creates a 2x2 grid
##
## If formation_offset is not specified, uses default formation from PartyManager
@export var members: Array[Dictionary] = []

@export_group("Party Limits")
## Maximum party size (Shining Force allows 12)
@export var max_size: int = 8

@export_group("Metadata")
## For campaign parties: track battle victories, etc.
@export var battles_won: int = 0
@export var total_gold: int = 0


## Validates that all members have required fields
func validate() -> bool:
	for i: int in range(members.size()):
		var member: Dictionary = members[i]

		if "character" not in member:
			push_error("PartyData '%s': Member %d missing 'character' field" % [party_name, i])
			return false

		var character_value: Variant = member.get("character")
		if not character_value is CharacterData:
			push_error("PartyData '%s': Member %d 'character' is not CharacterData" % [party_name, i])
			return false

	return true


## Returns the number of members in the party
func get_member_count() -> int:
	return members.size()


## Checks if party is at max capacity
func is_full() -> bool:
	return members.size() >= max_size


## Gets a member by index (returns null if out of bounds)
func get_member(index: int) -> Dictionary:
	if index < 0 or index >= members.size():
		return {}
	return members[index]


## Adds a member to the party
## Returns true if successful, false if party is full
func add_member(character: CharacterData, formation_offset: Vector2i = Vector2i.ZERO) -> bool:
	if is_full():
		push_warning("PartyData '%s': Cannot add member, party is full (%d/%d)" % [
			party_name,
			members.size(),
			max_size
		])
		return false

	var member_dict: Dictionary = {
		"character": character,
		"formation_offset": formation_offset
	}

	members.append(member_dict)
	return true


## Removes a member by index
## Returns true if successful, false if index invalid
func remove_member(index: int) -> bool:
	if index < 0 or index >= members.size():
		push_warning("PartyData '%s': Cannot remove member at index %d (out of bounds)" % [
			party_name,
			index
		])
		return false

	members.remove_at(index)
	return true


## Clears all members from the party
func clear_members() -> void:
	members.clear()


## Gets all character names as an array (useful for UI display)
func get_member_names() -> Array[String]:
	var names: Array[String] = []
	for member: Dictionary in members:
		if "character" in member:
			var character: CharacterData = member.get("character") as CharacterData
			if character:
				names.append(character.character_name)
			else:
				names.append("(Invalid)")
		else:
			names.append("(Invalid)")
	return names
