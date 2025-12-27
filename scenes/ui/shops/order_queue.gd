extends RefCounted

## OrderQueue - Manages the queue of items for bulk purchase/sale
##
## Key Features:
## - Pay-per-placement model: Gold validated at queue time, charged at placement
## - Tracks multiple items with quantities
## - Emits signals for UI updates
## - Supports both buy and sell queues
##
## Captain's Rules:
## 1. Players can only queue what they can afford
## 2. Gold is charged per placement, not upfront
## 3. Caravan storage is infinite
##
## Note: class_name removed to avoid load order issues when used as autoload dependency

# Preload QueuedItem script
const QueuedItemScript = preload("res://scenes/ui/shops/resources/queued_item.gd")

## Signal emitted when queue contents change
signal queue_changed()

## Signal emitted when an item is added
signal item_added(item_id: String, quantity: int)

## Signal emitted when an item is removed (placement or manual removal)
signal item_removed(item_id: String, quantity: int)

## Internal storage: Dictionary[String, QueuedItem] keyed by item_id
var _items: Dictionary = {}

## Cached total cost (updated on modification)
var _cached_total: int = 0


## Add items to the queue
## Returns true if successfully added, false if would exceed budget
## @param item_id: The item to add
## @param quantity: How many to add
## @param unit_price: Price per item
## @param is_deal: Whether from deals menu
## @param available_gold: Current gold minus existing queue total
func add_item(item_id: String, quantity: int, unit_price: int, is_deal: bool, available_gold: int) -> bool:
	var additional_cost: int = unit_price * quantity

	# Captain's Rule #1: Cannot queue more than we can afford
	if _cached_total + additional_cost > available_gold:
		return false

	if item_id in _items:
		_items[item_id].quantity += quantity
	else:
		_items[item_id] = QueuedItemScript.create(item_id, quantity, unit_price, is_deal)

	_cached_total += additional_cost
	item_added.emit(item_id, quantity)
	queue_changed.emit()
	return true


## Remove ONE item from the queue (used during placement)
## Returns the QueuedItem info for the removed item, or null if not found
func remove_one(item_id: String) -> RefCounted:
	if item_id not in _items:
		return null

	var queued: RefCounted = _items[item_id]
	var unit_price: int = queued.unit_price

	queued.quantity -= 1
	_cached_total -= unit_price

	var removed_item: RefCounted = QueuedItemScript.create(item_id, 1, unit_price, queued.is_deal)

	if queued.quantity <= 0:
		_items.erase(item_id)

	item_removed.emit(item_id, 1)
	queue_changed.emit()

	return removed_item


## Remove specific quantity from queue
## Returns actual number removed
func remove_item(item_id: String, quantity: int) -> int:
	if item_id not in _items:
		return 0

	var queued: RefCounted = _items[item_id]
	var actual_removed: int = mini(quantity, queued.quantity)

	queued.quantity -= actual_removed
	_cached_total -= queued.unit_price * actual_removed

	if queued.quantity <= 0:
		_items.erase(item_id)

	item_removed.emit(item_id, actual_removed)
	queue_changed.emit()
	return actual_removed


## Get quantity of specific item in queue
func get_quantity(item_id: String) -> int:
	if item_id in _items:
		return _items[item_id].quantity
	return 0


## Get unit price for item (needed for per-placement charging)
func get_unit_price(item_id: String) -> int:
	if item_id in _items:
		return _items[item_id].unit_price
	return 0


## Get total cost of entire queue
func get_total_cost() -> int:
	return _cached_total


## Get total number of items (sum of all quantities)
func get_total_item_count() -> int:
	var total: int = 0
	for item: RefCounted in _items.values():
		total += item.quantity
	return total


## Check if queue is empty
func is_empty() -> bool:
	return _items.is_empty()


## Clear the entire queue (used on cancel)
func clear() -> void:
	var had_items: bool = not _items.is_empty()
	_items.clear()
	_cached_total = 0
	if had_items:
		queue_changed.emit()


## Get all queued items as array (for iteration)
func get_all_items() -> Array[RefCounted]:
	var result: Array[RefCounted] = []
	for item: RefCounted in _items.values():
		result.append(item)
	return result


## Get first item in queue (for placement mode display)
func get_first_item() -> RefCounted:
	if _items.is_empty():
		return null
	return _items.values()[0]


## Check if a specific item is in the queue
func has_item(item_id: String) -> bool:
	return item_id in _items


## Get the max quantity that can be added for an item given available gold
func get_max_affordable_quantity(unit_price: int, available_gold: int) -> int:
	if unit_price <= 0:
		return 0
	var remaining_gold: int = available_gold - _cached_total
	if remaining_gold <= 0:
		return 0
	return remaining_gold / unit_price
