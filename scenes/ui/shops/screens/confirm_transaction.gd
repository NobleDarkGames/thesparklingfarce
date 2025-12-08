extends "res://scenes/ui/shops/screens/shop_screen_base.gd"

## ConfirmTransaction - Final confirmation for equipment purchase
##
## Shows: "Buy [ITEM] for [PRICE]G?"
## Executes the purchase via ShopManager on confirm.

@onready var confirm_label: Label = %ConfirmLabel
@onready var item_label: Label = %ItemLabel
@onready var price_label: Label = %PriceLabel
@onready var destination_label: Label = %DestinationLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton


func _on_initialized() -> void:
	var item_data: ItemData = get_item_data(context.selected_item_id)
	var item_name: String = item_data.item_name if item_data else context.selected_item_id
	var price: int = context.get_buy_price(context.selected_item_id)

	item_label.text = item_name.to_upper()
	price_label.text = "%dG" % price

	# Show destination
	if context.selected_destination == "caravan":
		destination_label.text = "→ Store in Caravan"
	else:
		var character: CharacterData = _get_character_by_uid(context.selected_destination)
		if character:
			destination_label.text = "→ %s equips" % character.character_name
		else:
			destination_label.text = "→ %s" % context.selected_destination

	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)

	await get_tree().process_frame
	confirm_button.grab_focus()


func _on_confirm_pressed() -> void:
	# Execute purchase
	var result: Dictionary = ShopManager.buy_item(
		context.selected_item_id,
		1,
		context.selected_destination
	)

	if result.success:
		var item_data: ItemData = get_item_data(context.selected_item_id)
		context.set_result("purchase_complete", {
			"item_id": context.selected_item_id,
			"item_name": item_data.item_name if item_data else context.selected_item_id,
			"total_cost": result.transaction.total_cost,
			"destination": context.selected_destination
		})
		replace_with("transaction_result")
	else:
		# Show error and go back
		context.set_result("purchase_failed", {
			"error": result.error
		})
		replace_with("transaction_result")


func _on_cancel_pressed() -> void:
	go_back()


func _get_character_by_uid(uid: String) -> CharacterData:
	if not PartyManager:
		return null
	for character: CharacterData in PartyManager.party_members:
		if character.character_uid == uid:
			return character
	return null
