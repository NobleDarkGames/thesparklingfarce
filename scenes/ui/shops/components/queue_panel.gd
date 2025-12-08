extends PanelContainer

## QueuePanel - Displays the current order queue
##
## Shows queued items, their quantities, unit prices, and totals.
## Updates automatically when queue changes.

# Preload dependencies to avoid load order issues
const OrderQueueClass: GDScript = preload("res://scenes/ui/shops/order_queue.gd")
const QueuedItemClass: GDScript = preload("res://scenes/ui/shops/resources/queued_item.gd")

@onready var queue_items: VBoxContainer = %QueueItems
@onready var queue_total_label: Label = %QueueTotalLabel
@onready var queue_after_label: Label = %QueueAfterLabel

var _queue_ref: RefCounted = null  # Actually OrderQueue


func _ready() -> void:
	# Hide by default
	hide()


## Refresh the queue display
## @param queue: The OrderQueue to display
## @param current_gold: Current gold amount for "after" calculation
func refresh(queue: RefCounted, current_gold: int) -> void:
	_queue_ref = queue

	if not queue or queue.is_empty():
		hide()
		return

	show()
	_update_items_display(queue)
	_update_totals(queue, current_gold)


## Update the items list
func _update_items_display(queue: RefCounted) -> void:
	# Clear existing
	for child in queue_items.get_children():
		child.queue_free()

	# Add each queued item
	for queued: RefCounted in queue.get_all_items():
		var item_label: Label = Label.new()

		var item_data: ItemData = _get_item_data(queued.item_id)
		var item_name: String = item_data.item_name if item_data else queued.item_id

		item_label.text = "%dx %s  %dG" % [
			queued.quantity,
			item_name,
			queued.get_total_cost()
		]

		if queued.is_deal:
			item_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))

		queue_items.add_child(item_label)


## Update total and after-purchase display
func _update_totals(queue: RefCounted, current_gold: int) -> void:
	var total: int = queue.get_total_cost()
	var after: int = current_gold - total

	queue_total_label.text = "TOTAL: %dG" % total

	if after >= 0:
		queue_after_label.text = "AFTER: %dG" % after
		queue_after_label.remove_theme_color_override("font_color")
	else:
		queue_after_label.text = "AFTER: -%dG" % abs(after)
		queue_after_label.add_theme_color_override("font_color", Color.RED)


func _get_item_data(item_id: String) -> ItemData:
	if item_id.is_empty():
		return null
	return ModLoader.registry.get_resource("item", item_id) as ItemData
