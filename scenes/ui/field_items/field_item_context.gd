extends RefCounted

## FieldItemContext - Minimal state for field item interface
##
## Unlike CaravanContext, this is single-character focused:
## - Always shows hero's inventory (SF2 authentic)
## - No character cycling (L/R does nothing)
## - No GIVE mode (transfers are Caravan-only)
##
## Uses same helper method signatures as CaravanContext for
## compatibility with shared screen patterns.

# =============================================================================
# STATE
# =============================================================================

## The character UID we're showing (always hero)
var character_uid: String = ""

## Screen navigation history (single level for field items)
var screen_history: Array[String] = []

# =============================================================================
# LIFECYCLE
# =============================================================================

## Initialize with the hero character
func initialize() -> void:
	screen_history.clear()
	_set_hero_character()


func cleanup() -> void:
	screen_history.clear()
	character_uid = ""


func _set_hero_character() -> void:
	# Get the hero (first party member, always the protagonist)
	if PartyManager and not PartyManager.party_members.is_empty():
		var hero: CharacterData = PartyManager.party_members[0]
		if hero:
			character_uid = hero.character_uid

# =============================================================================
# CARAVAN CONTEXT-COMPATIBLE INTERFACE
# =============================================================================
# These methods match CaravanContext signatures for screen compatibility

## Always returns hero UID (no cycling)
func get_current_member_uid() -> String:
	return character_uid


## Cycling is disabled - does nothing (SF2 authentic: field menu is hero only)
func cycle_member(_delta: int) -> void:
	pass  # Intentionally empty - no cycling in field menu


## Get party size (for compatibility - always returns 1 for field context)
func get_party_size() -> int:
	return 1  # Field menu treats party as single character


## Not in give mode (ever) - GIVE is Caravan-only
func is_give_mode() -> bool:
	return false


## Set give mode - NOT SUPPORTED in field context
func set_give_mode(_from_uid: String, _item_id: String) -> void:
	push_warning("FieldItemContext: Give mode not supported in field menu - use Caravan")


## Set browse mode - no-op, always in browse mode
func set_browse_mode() -> void:
	pass

# =============================================================================
# NAVIGATION HISTORY
# =============================================================================

func push_to_history(screen_name: String) -> void:
	screen_history.append(screen_name)


func pop_from_history() -> String:
	if screen_history.is_empty():
		return ""
	return screen_history.pop_back()


func clear_history() -> void:
	screen_history.clear()

# =============================================================================
# DATA ACCESS (matching CaravanContext signatures)
# =============================================================================

func get_item_data(item_id: String) -> ItemData:
	if item_id.is_empty():
		return null
	return ModLoader.registry.get_item(item_id)


func get_character_data(uid: String) -> CharacterData:
	if uid.is_empty():
		return null
	for member: CharacterData in PartyManager.party_members:
		if member.character_uid == uid:
			return member
	return null


func get_character_save_data(uid: String) -> CharacterSaveData:
	if uid.is_empty() or not PartyManager:
		return null
	return PartyManager.get_member_save_data(uid)


func get_character_inventory(uid: String) -> Array[String]:
	if uid.is_empty() or not PartyManager:
		return []
	var save_data: CharacterSaveData = PartyManager.get_member_save_data(uid)
	if save_data:
		return save_data.inventory
	return []


func get_max_inventory_slots() -> int:
	if ModLoader and ModLoader.inventory_config:
		return ModLoader.inventory_config.get_max_slots()
	return 4
