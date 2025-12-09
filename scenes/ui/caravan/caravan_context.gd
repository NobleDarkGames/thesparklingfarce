extends RefCounted

## CaravanContext - Shared state container for caravan depot session
##
## Owns all state needed across screens:
## - Filter/sort preferences (persists across navigation)
## - Selected items and characters (for operations)
## - Screen navigation history
## - Operation mode (take vs store)
##
## Modeled after ShopContext but without gold/queue (depot transfers are free).

## Operation modes
enum Mode { BROWSE, TAKE, STORE }

## Current operation mode
var mode: Mode = Mode.BROWSE

## Screen navigation history (for back button)
var screen_history: Array[String] = []

# =============================================================================
# FILTER/SORT STATE (persists across screens)
# =============================================================================

## Current filter type ("" = all, "weapon", "armor", "accessory", "consumable")
var depot_filter: String = ""

## Current sort method ("none", "name", "type", "value")
var depot_sort: String = "none"

# =============================================================================
# SELECTION STATE (cleared after operations)
# =============================================================================

## Currently selected depot item ID
var selected_depot_item_id: String = ""

## Currently selected character UID (for take/store operations)
var selected_character_uid: String = ""

## Selected inventory slot index (for store operations)
var selected_inventory_index: int = -1

# =============================================================================
# LIFECYCLE
# =============================================================================

## Initialize context for a new depot session
func initialize() -> void:
	mode = Mode.BROWSE
	screen_history.clear()
	# Note: Filter/sort are intentionally NOT reset - they persist across sessions
	_clear_selection()


## Clean up when closing depot
func cleanup() -> void:
	screen_history.clear()
	_clear_selection()


## Clear selection state (after operations or mode change)
func _clear_selection() -> void:
	selected_depot_item_id = ""
	selected_character_uid = ""
	selected_inventory_index = -1

# =============================================================================
# MODE HELPERS
# =============================================================================

## Set mode to browse (viewing depot items)
func set_browse_mode() -> void:
	mode = Mode.BROWSE
	_clear_selection()


## Set mode to take (giving depot item to character)
func set_take_mode() -> void:
	mode = Mode.TAKE


## Set mode to store (storing character item in depot)
func set_store_mode() -> void:
	mode = Mode.STORE
	selected_depot_item_id = ""  # Clear depot selection for store mode


## Check if we're in take mode
func is_take_mode() -> bool:
	return mode == Mode.TAKE


## Check if we're in store mode
func is_store_mode() -> bool:
	return mode == Mode.STORE

# =============================================================================
# NAVIGATION HISTORY
# =============================================================================

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

# =============================================================================
# DATA ACCESS HELPERS
# =============================================================================

## Get filtered and sorted depot contents
func get_filtered_depot_items() -> Array[String]:
	if not StorageManager:
		return []

	var all_items: Array[String] = StorageManager.get_depot_contents()
	var result: Array[String] = []

	# Apply filter
	if depot_filter.is_empty():
		result = all_items.duplicate()
	else:
		for item_id: String in all_items:
			var item_data: ItemData = ModLoader.registry.get_resource("item", item_id) as ItemData
			if item_data:
				var type_name: String = ItemData.ItemType.keys()[item_data.item_type].to_lower()
				if type_name == depot_filter:
					result.append(item_id)

	# Apply sort
	if depot_sort != "none" and result.size() > 1:
		result.sort_custom(_sort_items)

	return result


## Comparison function for sorting items
func _sort_items(a_id: String, b_id: String) -> bool:
	var a_data: ItemData = ModLoader.registry.get_resource("item", a_id) as ItemData
	var b_data: ItemData = ModLoader.registry.get_resource("item", b_id) as ItemData

	if not a_data:
		return false
	if not b_data:
		return true

	match depot_sort:
		"name":
			return a_data.item_name.to_lower() < b_data.item_name.to_lower()
		"type":
			if a_data.item_type != b_data.item_type:
				return a_data.item_type < b_data.item_type
			return a_data.item_name.to_lower() < b_data.item_name.to_lower()
		"value":
			if a_data.buy_price != b_data.buy_price:
				return a_data.buy_price > b_data.buy_price
			return a_data.item_name.to_lower() < b_data.item_name.to_lower()
		_:
			return false

	return false


## Get item data from ModLoader registry
func get_item_data(item_id: String) -> ItemData:
	if item_id.is_empty():
		return null
	return ModLoader.registry.get_resource("item", item_id) as ItemData


## Get character inventory
func get_character_inventory(character_uid: String) -> Array[String]:
	if character_uid.is_empty() or not PartyManager:
		return []

	var save_data: CharacterSaveData = PartyManager.get_member_save_data(character_uid)
	if save_data:
		return save_data.inventory
	return []


## Get max inventory slots (from mod config)
func get_max_inventory_slots() -> int:
	if ModLoader and ModLoader.inventory_config:
		return ModLoader.inventory_config.get_max_slots()
	return 4  # Default
