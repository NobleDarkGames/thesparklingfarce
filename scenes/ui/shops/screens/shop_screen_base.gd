extends "res://scenes/ui/components/modal_screen_base.gd"

## ShopScreenBase - Base class for all shop screens
##
## Extends ModalScreenBase with shop-specific helpers:
## - Gold display and queue management
## - Item data access via context
## - Price calculations
##
## Shares navigation, input blocking, and lifecycle with CaravanScreenBase.

# Preload ShopContext for Mode enum access
const ShopContextScript = preload("res://scenes/ui/shops/shop_context.gd")

# =============================================================================
# SHARED UI CONSTANTS
# =============================================================================

## Standard UI colors - use centralized UIColors class

# =============================================================================
# SHOP-SPECIFIC HELPERS
# =============================================================================

## Get character's display name by UID (returns UID if not found)
func get_character_name(uid: String) -> String:
	var character: CharacterData = get_character_by_uid(uid)
	return character.character_name if character else uid

## Request the controller to close the shop
func close_shop() -> void:
	_close_interface()


## Update the gold display in the controller
func update_gold_display() -> void:
	if controller and controller.has_method("update_gold_display"):
		controller.update_gold_display()


## Show the queue panel in the controller
func show_queue_panel(p_visible: bool) -> void:
	if controller and controller.has_method("show_queue_panel"):
		controller.show_queue_panel(p_visible)


## Get item data from context
func get_item_data(item_id: String) -> ItemData:
	if context and context.has_method("get_item_data"):
		return context.get_item_data(item_id)
	return null


## Get current gold from context
func get_current_gold() -> int:
	if context and context.has_method("get_current_gold"):
		return context.get_current_gold()
	return 0


## Get gold available for queueing from context
func get_available_gold() -> int:
	if context and context.has_method("get_available_for_queue"):
		return context.get_available_for_queue()
	return 0


## Get max inventory slots from config
func get_max_inventory_slots() -> int:
	if ModLoader and ModLoader.inventory_config:
		return ModLoader.inventory_config.get_max_slots()
	return 4  # Default fallback


## Get character's inventory usage info
func get_inventory_status(character_uid: String) -> Dictionary:
	var save_data: CharacterSaveData = PartyManager.get_member_save_data(character_uid) if PartyManager else null
	var slots_used: int = save_data.inventory.size() if save_data else 0
	var slots_max: int = get_max_inventory_slots()
	return {
		"used": slots_used,
		"max": slots_max,
		"full": slots_used >= slots_max,
		"save_data": save_data
	}
