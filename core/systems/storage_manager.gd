extends Node

## StorageManager - Autoload singleton for Caravan Depot shared storage
##
## Manages the shared party storage (SF2-style Caravan Depot):
## - Unlimited item storage (by default)
## - Items stored as simple IDs (duplicates allowed for stacking)
## - Reactive signals for UI updates
##
## Storage persists via SaveData.depot_items. Use export_state()/import_state()
## to sync with save system.
##
## Usage:
##   StorageManager.add_to_depot("healing_seed")
##   StorageManager.remove_from_depot("bronze_sword")
##   var items = StorageManager.get_depot_contents()
##   var count = StorageManager.get_item_count("healing_seed")

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when depot contents change (add, remove, clear)
signal depot_changed()

## Emitted when an item is added to depot
signal item_added(item_id: String)

## Emitted when an item is removed from depot
signal item_removed(item_id: String)

## Emitted when depot is cleared
signal depot_cleared()

# ============================================================================
# CONFIGURATION
# ============================================================================

## Capacity limit for depot (-1 = unlimited, SF2-authentic)
## Can be overridden by mods via caravan_config in mod.json
var capacity_limit: int = -1


# ============================================================================
# CARAVAN AVAILABILITY
# ============================================================================

## Check if player has access to Caravan storage
## This is based on campaign unlock status, NOT current map location.
## The Caravan is accessible from shops whenever it's unlocked, regardless
## of whether it's visible on the current map.
func is_caravan_available() -> bool:
	# Check if caravan is unlocked in the campaign
	if GameState:
		return GameState.has_flag("caravan_unlocked")
	# Fallback: assume available if no GameState
	return true


## Caravan has no capacity limit (when available)
## Per Captain's Rule #3: "Caravan storage is infinite"
func can_store_in_caravan(_item_id: String = "", _quantity: int = 1) -> bool:
	if not is_caravan_available():
		return false
	return true  # Infinite storage


## Get remaining caravan space (always effectively infinite)
func get_caravan_space_remaining() -> int:
	if not is_caravan_available():
		return 0
	return 999999  # Effectively infinite

# ============================================================================
# RUNTIME STATE
# ============================================================================

## Runtime depot contents (synced to/from SaveData.depot_items)
var _depot_items: Array[String] = []

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Depot starts empty - will be populated when save is loaded
	_depot_items.clear()


# ============================================================================
# DEPOT OPERATIONS
# ============================================================================

## Add an item to the depot
## @param item_id: ID of the item to add
## @return: true if added successfully, false if depot full or invalid
func add_to_depot(item_id: String) -> bool:
	if item_id.is_empty():
		push_warning("StorageManager: Cannot add empty item_id to depot")
		return false

	# Check capacity (if limited)
	if capacity_limit > 0 and _depot_items.size() >= capacity_limit:
		push_warning("StorageManager: Depot full (%d/%d)" % [_depot_items.size(), capacity_limit])
		return false

	_depot_items.append(item_id)
	item_added.emit(item_id)
	depot_changed.emit()
	return true


## Remove an item from the depot (first matching instance)
## @param item_id: ID of the item to remove
## @return: true if removed successfully, false if not found
func remove_from_depot(item_id: String) -> bool:
	if item_id.is_empty():
		push_warning("StorageManager: Cannot remove empty item_id from depot")
		return false

	var index: int = _depot_items.find(item_id)
	if index == -1:
		push_warning("StorageManager: Item '%s' not found in depot" % item_id)
		return false

	_depot_items.remove_at(index)
	item_removed.emit(item_id)
	depot_changed.emit()
	return true


## Remove all instances of an item from depot
## @param item_id: ID of the item to remove
## @return: Number of items removed
func remove_all_from_depot(item_id: String) -> int:
	if item_id.is_empty():
		return 0

	var removed_count: int = 0
	var i: int = _depot_items.size() - 1

	while i >= 0:
		if _depot_items[i] == item_id:
			_depot_items.remove_at(i)
			removed_count += 1
		i -= 1

	if removed_count > 0:
		item_removed.emit(item_id)
		depot_changed.emit()

	return removed_count


## Clear all items from depot
func clear_depot() -> void:
	if _depot_items.is_empty():
		return

	_depot_items.clear()
	depot_cleared.emit()
	depot_changed.emit()


# ============================================================================
# DEPOT QUERIES
# ============================================================================

## Get all depot contents
## @return: Array of item IDs (duplicate of internal array)
func get_depot_contents() -> Array[String]:
	return _depot_items.duplicate()


## Get depot contents grouped by item type
## @return: Dictionary of {item_type_name: Array[item_id]}
func get_depot_contents_grouped() -> Dictionary:
	var grouped: Dictionary = {}

	for item_id: String in _depot_items:
		var item_data: ItemData = ModLoader.registry.get_resource("item", item_id) as ItemData
		var item_type_name: String = "unknown"

		if item_data:
			# Convert enum to string name for grouping
			item_type_name = ItemData.ItemType.keys()[item_data.item_type].to_lower()

		if item_type_name not in grouped:
			grouped[item_type_name] = []
		grouped[item_type_name].append(item_id)

	return grouped


## Get unique items with quantities (for display)
## @return: Array of {item_id: String, quantity: int}
func get_depot_contents_stacked() -> Array[Dictionary]:
	var counts: Dictionary = {}

	for item_id: String in _depot_items:
		if item_id in counts:
			counts[item_id] += 1
		else:
			counts[item_id] = 1

	var result: Array[Dictionary] = []
	for item_id: String in counts:
		result.append({
			"item_id": item_id,
			"quantity": counts[item_id]
		})

	return result


## Check if depot contains an item
## @param item_id: ID of the item to check
## @return: true if item is in depot
func has_item(item_id: String) -> bool:
	return item_id in _depot_items


## Get count of a specific item in depot
## @param item_id: ID of the item to count
## @return: Number of this item in depot
func get_item_count(item_id: String) -> int:
	var count: int = 0
	for depot_item: String in _depot_items:
		if depot_item == item_id:
			count += 1
	return count


## Get total number of items in depot
## @return: Total item count (counting duplicates)
func get_depot_size() -> int:
	return _depot_items.size()


## Get number of unique items in depot
## @return: Unique item count
func get_unique_item_count() -> int:
	var unique: Dictionary = {}
	for item_id: String in _depot_items:
		unique[item_id] = true
	return unique.size()


## Check if depot is empty
## @return: true if no items in depot
func is_empty() -> bool:
	return _depot_items.is_empty()


## Check if depot is full (only meaningful if capacity_limit > 0)
## @return: true if depot is at capacity limit
func is_full() -> bool:
	if capacity_limit <= 0:
		return false  # Unlimited
	return _depot_items.size() >= capacity_limit


## Get remaining capacity (returns -1 if unlimited)
## @return: Number of items that can still be added, or -1 if unlimited
func get_remaining_capacity() -> int:
	if capacity_limit <= 0:
		return -1  # Unlimited
	return capacity_limit - _depot_items.size()


# ============================================================================
# BATCH OPERATIONS
# ============================================================================

## Add multiple items to depot
## @param item_ids: Array of item IDs to add
## @return: Number of items successfully added
func add_multiple_to_depot(item_ids: Array[String]) -> int:
	var added_count: int = 0

	for item_id: String in item_ids:
		if add_to_depot(item_id):
			added_count += 1

	return added_count


## Remove multiple items from depot (one of each)
## @param item_ids: Array of item IDs to remove
## @return: Number of items successfully removed
func remove_multiple_from_depot(item_ids: Array[String]) -> int:
	var removed_count: int = 0

	for item_id: String in item_ids:
		if remove_from_depot(item_id):
			removed_count += 1

	return removed_count


# ============================================================================
# SAVE SYSTEM INTEGRATION
# ============================================================================

## Export depot state for save system
## @return: Array of item IDs
func export_state() -> Array[String]:
	return _depot_items.duplicate()


## Import depot state from save system
## @param items: Array of item IDs to load
func import_state(items: Array) -> void:
	_depot_items.clear()

	for i: int in range(items.size()):
		var item_id: Variant = items[i]
		if item_id is String and not item_id.is_empty():
			_depot_items.append(item_id)

	depot_changed.emit()


## Sync from SaveData (convenience method)
## @param save_data: SaveData to load depot from
func load_from_save_data(save_data: SaveData) -> void:
	if not save_data:
		push_warning("StorageManager: Cannot load from null SaveData")
		return

	import_state(save_data.depot_items)


## Sync to SaveData (convenience method)
## @param save_data: SaveData to save depot to
func save_to_save_data(save_data: SaveData) -> void:
	if not save_data:
		push_warning("StorageManager: Cannot save to null SaveData")
		return

	save_data.depot_items = export_state()


## Reset depot to empty (for new game)
func reset() -> void:
	clear_depot()
	capacity_limit = -1  # Reset to unlimited


# ============================================================================
# MOD CONFIGURATION
# ============================================================================

## Load depot configuration from mod manifest
## Called by ModLoader when processing mod.json
## @param mod_id: ID of the mod providing config
## @param config: Dictionary from mod.json "caravan_config" section
func load_config_from_manifest(mod_id: String, config: Dictionary) -> void:
	if "capacity" in config:
		var cap: Variant = config.capacity
		if cap is int or cap is float:
			capacity_limit = int(cap)
			print("StorageManager: Capacity set to %d by mod '%s'" % [capacity_limit, mod_id])

	# Future: Add more caravan config options here
	# - accessible_in_battle: bool
	# - accessible_in_towns: bool
	# - etc.


# ============================================================================
# DEBUG
# ============================================================================

## Get debug string for depot contents
func get_debug_string() -> String:
	var stacked: Array[Dictionary] = get_depot_contents_stacked()
	var output: String = "StorageManager: Depot (%d items, %d unique)\n" % [
		get_depot_size(),
		get_unique_item_count()
	]

	if capacity_limit > 0:
		output += "  Capacity: %d/%d\n" % [get_depot_size(), capacity_limit]
	else:
		output += "  Capacity: Unlimited\n"

	for item_dict: Dictionary in stacked:
		output += "  - %s x%d\n" % [item_dict.item_id, item_dict.quantity]

	return output
