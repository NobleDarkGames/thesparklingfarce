extends "res://scenes/ui/shops/screens/shop_screen_base.gd"

## SellConfirm - Confirm batch sale of queued items
##
## Shows all items to be sold with their values.
## Executes the batch sale via ShopManager on confirm.

@onready var items_list: VBoxContainer = %ItemsList
@onready var total_label: Label = %TotalLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton


func _on_initialized() -> void:
	_populate_items_list()
	_update_total()

	confirm_button.pressed.connect(_on_confirm)
	cancel_button.pressed.connect(_on_cancel)

	await get_tree().process_frame
	confirm_button.grab_focus()


func _populate_items_list() -> void:
	for child: Node in items_list.get_children():
		child.queue_free()

	for queued: RefCounted in context.queue.get_all_items():
		var item_data: ItemData = get_item_data(queued.item_id)
		var label: Label = Label.new()
		label.text = "%dx %s → +%dG" % [
			queued.quantity,
			item_data.item_name if item_data else queued.item_id,
			queued.get_total_cost()
		]
		items_list.add_child(label)


func _update_total() -> void:
	total_label.text = "TOTAL: +%dG" % context.queue.get_total_cost()


func _on_confirm() -> void:
	var total_earned: int = 0
	var items_sold: int = 0

	for queued: RefCounted in context.queue.get_all_items():
		for i: int in range(queued.quantity):
			var result: Dictionary = ShopManager.sell_item(
				queued.item_id,
				context.selling_from_uid,
				1
			)

			if result.get("success", false):
				total_earned += queued.unit_price
				items_sold += 1

	context.queue.clear()

	context.set_result("sell_complete", {
		"items_sold": items_sold,
		"total_earned": total_earned
	})

	replace_with("transaction_result")


func _on_cancel() -> void:
	go_back()
