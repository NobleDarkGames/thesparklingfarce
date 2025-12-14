extends "res://scenes/ui/shops/screens/shop_screen_base.gd"

## TransactionResult - Shows success/failure feedback after transactions

## Colors matching project standards
const COLOR_SUCCESS: Color = Color(0.4, 1.0, 0.4, 1.0)  # Soft green
const COLOR_ERROR: Color = Color(1.0, 0.4, 0.4, 1.0)  # Soft red
const COLOR_WARNING: Color = Color(1.0, 1.0, 0.4, 1.0)  # Soft yellow
##
## Displays the result stored in context.last_result
## Allows returning to item_browser (continue) or action_select (done)

@onready var result_label: Label = %ResultLabel
@onready var details_label: Label = %DetailsLabel
@onready var continue_button: Button = %ContinueButton
@onready var done_button: Button = %DoneButton


func _on_initialized() -> void:
	_display_result()

	continue_button.pressed.connect(_on_continue_pressed)
	done_button.pressed.connect(_on_done_pressed)

	await get_tree().process_frame
	continue_button.grab_focus()


func _display_result() -> void:
	var result: Dictionary = context.last_result
	var result_type: String = result.get("type", "unknown")

	match result_type:
		"purchase_complete":
			_show_purchase_success(result)
		"purchase_failed":
			_show_purchase_failed(result)
		"placement_complete":
			_show_placement_complete(result)
		"placement_cancelled":
			_show_placement_cancelled(result)
		"sell_complete":
			_show_sell_complete(result)
		_:
			result_label.text = "TRANSACTION COMPLETE"
			details_label.text = ""


func _show_purchase_success(result: Dictionary) -> void:
	var item_name: String = result.get("item_name", "Item")
	var cost: int = result.get("total_cost", 0)

	result_label.text = "PURCHASE COMPLETE!"
	result_label.add_theme_color_override("font_color", COLOR_SUCCESS)

	var dest: String = result.get("destination", "")
	if dest == "caravan":
		details_label.text = "%s stored in Caravan.\nSpent %dG" % [item_name, cost]
	else:
		var char_name: String = _get_character_name(dest)
		details_label.text = "%s equipped %s!\nSpent %dG" % [char_name, item_name, cost]


func _show_purchase_failed(result: Dictionary) -> void:
	var error: String = result.get("error", "Unknown error")

	result_label.text = "PURCHASE FAILED"
	result_label.add_theme_color_override("font_color", COLOR_ERROR)
	details_label.text = error


func _show_placement_complete(result: Dictionary) -> void:
	var placed: int = result.get("placed_count", 0)
	var spent: int = result.get("total_spent", 0)

	result_label.text = "ITEMS DISTRIBUTED!"
	result_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	details_label.text = "Placed %d items.\nTotal spent: %dG" % [placed, spent]


func _show_placement_cancelled(result: Dictionary) -> void:
	var placed: int = result.get("placed_count", 0)
	var cancelled: int = result.get("cancelled_count", 0)
	var spent: int = result.get("total_spent", 0)

	result_label.text = "ORDER CANCELLED"
	result_label.add_theme_color_override("font_color", COLOR_WARNING)

	if placed > 0:
		details_label.text = "Kept %d items (spent %dG).\n%d items returned to shop." % [placed, spent, cancelled]
	else:
		details_label.text = "%d items returned to shop.\nNo gold spent." % cancelled


func _show_sell_complete(result: Dictionary) -> void:
	var items_sold: int = result.get("items_sold", 0)
	var earned: int = result.get("total_earned", 0)

	result_label.text = "SALE COMPLETE!"
	result_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	details_label.text = "Sold %d items.\nEarned %dG" % [items_sold, earned]


func _on_continue_pressed() -> void:
	# Clear history and go back to appropriate screen based on mode
	context.clear_history()
	if _is_church_mode():
		push_screen("church_char_select")
	else:
		push_screen("item_browser")


func _on_done_pressed() -> void:
	# Clear history and go to action select
	context.clear_history()
	if _is_church_mode():
		push_screen("church_action_select")
	else:
		push_screen("action_select")


func _is_church_mode() -> bool:
	if not context:
		return false
	return context.mode in [ShopContextScript.Mode.HEAL, ShopContextScript.Mode.REVIVE, ShopContextScript.Mode.UNCURSE]


func _get_character_name(uid: String) -> String:
	if not PartyManager:
		return uid
	for character: CharacterData in PartyManager.party_members:
		if character.character_uid == uid:
			return character.character_name
	return uid


## Override back behavior - same as done
func _on_back_requested() -> void:
	_on_done_pressed()
