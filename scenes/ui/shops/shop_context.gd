extends RefCounted

## ShopContext - Shared state container for shop session
##
## Owns the OrderQueue and tracks all state needed across screens:
## - Current shop data
## - Shopping mode (BUY, SELL, DEALS)
## - Selected items and destinations
## - Screen navigation history
## - Transaction results
##
## Note: class_name removed to avoid load order issues when used as autoload dependency

# Preload OrderQueue script
const OrderQueueScript = preload("res://scenes/ui/shops/order_queue.gd")

## Shopping modes
enum Mode { BUY, SELL, DEALS, HEAL, REVIVE, UNCURSE, CRAFT }

## The ShopData resource for the current shop
var shop: ShopData = null

## Current shopping mode
var mode: Mode = Mode.BUY

## The order queue (for consumable bulk purchases OR batch selling)
var queue: RefCounted = null  # Actually OrderQueue

## Currently selected item (for equipment flow)
var selected_item_id: String = ""

## Quantity for current selection (equipment = 1, consumables use queue)
var selected_quantity: int = 1

## Selected destination for equipment ("caravan" or character_uid)
var selected_destination: String = ""

## In sell mode: whose inventory are we selling from?
var selling_from_uid: String = ""

## In craft mode: the selected recipe ID
var selected_recipe_id: String = ""

## In craft mode: selected output choice index (for CHOICE mode recipes)
var selected_output_index: int = 0

## Reference to SaveData (for gold operations)
var save_data: SaveData = null

## Screen navigation history (for back button)
var screen_history: Array[String] = []

## Last transaction results (for result screen)
var last_result: Dictionary = {}


## Initialize context for a new shop session
func initialize(p_shop: ShopData, p_save_data: SaveData) -> void:
	shop = p_shop
	save_data = p_save_data
	mode = Mode.BUY
	queue = OrderQueueScript.new()
	selected_item_id = ""
	selected_quantity = 1
	selected_destination = ""
	selling_from_uid = ""
	selected_recipe_id = ""
	selected_output_index = 0
	screen_history.clear()
	last_result.clear()


## Clean up when closing shop
func cleanup() -> void:
	if queue:
		queue.clear()
		queue = null
	shop = null
	save_data = null
	screen_history.clear()
	last_result.clear()


## Check if we're in deals mode
func is_deals_mode() -> bool:
	return mode == Mode.DEALS


## Check if we're in buy mode (includes deals)
func is_buy_mode() -> bool:
	return mode == Mode.BUY or mode == Mode.DEALS


## Check if we're in sell mode
func is_sell_mode() -> bool:
	return mode == Mode.SELL


## Get current gold (real-time, reflects any charges)
func get_current_gold() -> int:
	if save_data:
		return save_data.gold
	# Fallback to SaveManager
	if SaveManager and SaveManager.current_save:
		return SaveManager.current_save.gold
	return 0


## Set current gold (for transactions)
func set_current_gold(amount: int) -> void:
	if save_data:
		save_data.gold = maxi(0, amount)
	elif SaveManager and SaveManager.current_save:
		SaveManager.current_save.gold = maxi(0, amount)


## Get gold available for NEW queue additions (gold - queue total)
func get_available_for_queue() -> int:
	var current_gold: int = get_current_gold()
	var queue_total: int = queue.get_total_cost() if queue else 0
	return current_gold - queue_total


## Push screen to history
func push_to_history(screen_name: String) -> void:
	screen_history.append(screen_name)


## Pop and return previous screen (or empty string if at root)
func pop_from_history() -> String:
	if screen_history.is_empty():
		return ""
	return screen_history.pop_back()


## Peek at the previous screen without popping
func peek_history() -> String:
	if screen_history.is_empty():
		return ""
	return screen_history[-1]


## Clear history (when resetting to action select)
func clear_history() -> void:
	screen_history.clear()


## Get item data from ModLoader registry
func get_item_data(item_id: String) -> ItemData:
	if item_id.is_empty():
		return null
	return ModLoader.registry.get_item(item_id)


## Get effective buy price for an item
func get_buy_price(item_id: String) -> int:
	if not shop:
		return -1
	return shop.get_effective_buy_price(item_id, is_deals_mode())


## Get effective sell price for an item
func get_sell_price(item_id: String) -> int:
	if not shop:
		return -1
	return shop.get_effective_sell_price(item_id)


## Store transaction result for display
func set_result(result_type: String, data: Dictionary) -> void:
	last_result = data.duplicate()
	last_result["type"] = result_type


## Check if shop has active deals
func has_deals() -> bool:
	return shop and shop.has_active_deals()


## Check if shop allows selling
func can_sell() -> bool:
	return shop and shop.can_sell


## Check if shop can store to caravan
func can_store_to_caravan() -> bool:
	return shop and shop.can_store_to_caravan


## Check if we're in craft mode
func is_craft_mode() -> bool:
	return mode == Mode.CRAFT


## Get CrafterData for the current crafter shop
func get_crafter_data() -> CrafterData:
	if not shop or shop.crafter_id.is_empty():
		return null
	return ModLoader.registry.get_crafter(shop.crafter_id)


## Get CraftingRecipeData by ID
func get_recipe_data(recipe_id: String) -> CraftingRecipeData:
	if recipe_id.is_empty():
		return null
	return ModLoader.registry.get_crafting_recipe(recipe_id)


## Get the currently selected recipe
func get_selected_recipe() -> CraftingRecipeData:
	return get_recipe_data(selected_recipe_id)
