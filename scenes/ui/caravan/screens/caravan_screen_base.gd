extends "res://scenes/ui/components/modal_screen_base.gd"

## CaravanScreenBase - Base class for all caravan depot screens
##
## Extends ModalScreenBase with caravan-specific helpers:
## - Depot item access (filtered/sorted)
## - Character inventory access
## - Storage operations
##
## Shares navigation, input blocking, and lifecycle with ShopScreenBase.

# =============================================================================
# CARAVAN-SPECIFIC HELPERS
# =============================================================================

## Close the caravan interface
func close_interface() -> void:
	_close_interface()


## Get item data from context
func get_item_data(item_id: String) -> ItemData:
	if context and context.has_method("get_item_data"):
		return context.get_item_data(item_id)
	return null


## Get filtered depot items from context
func get_filtered_depot_items() -> Array[String]:
	if context and context.has_method("get_filtered_depot_items"):
		return context.get_filtered_depot_items()
	return []


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


## Get depot item count (unfiltered)
func get_depot_size() -> int:
	if StorageManager:
		return StorageManager.get_depot_size()
	return 0


## Get CharacterData for a given UID
func get_character_data(uid: String) -> CharacterData:
	if not PartyManager:
		return null
	for character: CharacterData in PartyManager.party_members:
		if character.character_uid == uid:
			return character
	return null


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
