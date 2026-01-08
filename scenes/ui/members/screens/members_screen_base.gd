extends "res://scenes/ui/components/modal_screen_base.gd"

## MembersScreenBase - Base class for all members management screens
##
## Extends ModalScreenBase with members-specific helpers:
## - Current member access and cycling
## - Character inventory access
## - Item data lookup
## - Give operation helpers
##
## Uses CaravanContext (with GIVE mode extensions) for session state.

# =============================================================================
# MEMBERS-SPECIFIC HELPERS
# =============================================================================

## Close the members interface
func close_interface() -> void:
	_close_interface()


## Get item data from ModLoader
func get_item_data(item_id: String) -> ItemData:
	if item_id.is_empty():
		return null
	return ModLoader.registry.get_item(item_id)


## Get character inventory from context
func get_character_inventory(uid: String) -> Array[String]:
	if context and context.has_method("get_character_inventory"):
		return context.get_character_inventory(uid)
	return []


## Get max inventory slots from context
func get_max_inventory_slots() -> int:
	if context and context.has_method("get_max_inventory_slots"):
		return context.get_max_inventory_slots()
	return 4


## Get the currently selected member's UID
func get_current_member_uid() -> String:
	if context and context.has_method("get_current_member_uid"):
		return context.get_current_member_uid()
	return ""


## Get CharacterData for a given UID
func get_character_data(uid: String) -> CharacterData:
	if not PartyManager:
		return null
	for character: CharacterData in PartyManager.party_members:
		if character.character_uid == uid:
			return character
	return null


## Get CharacterSaveData for a given UID
func get_character_save_data(uid: String) -> CharacterSaveData:
	if not PartyManager:
		return null
	return PartyManager.get_member_save_data(uid)


## Cycle to next/previous member (for L/R bumper handling)
func cycle_member(delta: int) -> void:
	if context and context.has_method("cycle_member"):
		context.cycle_member(delta)


## Check if we're in give mode
func is_give_mode() -> bool:
	if context and context.has_method("is_give_mode"):
		return context.is_give_mode()
	return false


## Get party size
func get_party_size() -> int:
	if PartyManager:
		return PartyManager.party_members.size()
	return 0


## Transfer item between characters (for Give action)
## Returns { success: bool, error: String }
func transfer_item_between_members(from_uid: String, to_uid: String, item_id: String) -> Dictionary:
	if not PartyManager:
		return { "success": false, "error": "PartyManager not available" }
	return PartyManager.transfer_item_between_members(from_uid, to_uid, item_id)


## Check if character can equip an item
func can_character_equip(uid: String, item_id: String) -> bool:
	if ShopManager and ShopManager.has_method("can_character_equip"):
		return ShopManager.can_character_equip(uid, item_id)
	# Fallback: assume yes
	return true


## Show result message with success/error styling
## Subclasses must have a result_label: Label node
func _show_result_on_label(label: Label, message: String, success: bool) -> void:
	label.text = message
	if success:
		label.add_theme_color_override("font_color", UIColors.RESULT_SUCCESS)
		if not message.is_empty():
			play_sfx("menu_confirm")
	else:
		label.add_theme_color_override("font_color", UIColors.RESULT_ERROR)
		if not message.is_empty():
			play_sfx("menu_error")
