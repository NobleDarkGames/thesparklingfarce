extends RefCounted

## QueuedItem - Represents a single item entry in the shop order queue
##
## Tracks item ID, quantity, unit price, and whether it's a deal item.
## Unit price is captured at queue time to preserve deal pricing.
##
## Note: class_name removed to avoid load order issues when used as autoload dependency

## Cached script reference to avoid repeated load() calls
const _SelfScript: GDScript = preload("res://scenes/ui/shops/resources/queued_item.gd")

## The item being purchased
var item_id: String = ""

## Quantity of this item in the queue
var quantity: int = 0

## Unit price at time of queueing (captures deal pricing)
var unit_price: int = 0

## Whether this was queued from deals menu
var is_deal: bool = false


## Total cost for this queue entry
func get_total_cost() -> int:
	return unit_price * quantity


## Create a new queued item
static func create(p_item_id: String, p_quantity: int, p_unit_price: int, p_is_deal: bool = false) -> RefCounted:
	var item: RefCounted = _SelfScript.new()
	item.item_id = p_item_id
	item.quantity = p_quantity
	item.unit_price = p_unit_price
	item.is_deal = p_is_deal
	return item


## Create a copy of this queued item
func duplicate_item() -> RefCounted:
	return _SelfScript.call("create", item_id, quantity, unit_price, is_deal)
