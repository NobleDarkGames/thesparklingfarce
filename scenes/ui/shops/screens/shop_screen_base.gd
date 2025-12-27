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
# SHOP-SPECIFIC HELPERS
# =============================================================================

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
