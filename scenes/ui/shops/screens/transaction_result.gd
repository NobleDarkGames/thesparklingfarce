extends "res://scenes/ui/shops/screens/shop_screen_base.gd"

## TransactionResult - Shows success/failure feedback after transactions
##
## SF2-authentic behavior: Auto-returns to appropriate screen after brief display.
## No Continue/Done choice - assumes you have more to do (SF2 pattern).
## Press B to skip directly to action menu if desired.

## Use shared color constants for consistency
const COLOR_SUCCESS: Color = UIColors.RESULT_SUCCESS
const COLOR_ERROR: Color = UIColors.RESULT_ERROR
const COLOR_WARNING: Color = UIColors.RESULT_WARNING

## Auto-return delay in seconds (SF2-style quick feedback)
const AUTO_RETURN_DELAY: float = 1.5

@onready var result_label: Label = %ResultLabel
@onready var details_label: Label = %DetailsLabel
@onready var continue_button: Button = %ContinueButton
@onready var done_button: Button = %DoneButton
@onready var button_row: HBoxContainer = %ContinueButton.get_parent()

var _auto_return_timer: SceneTreeTimer = null
var _return_destination: String = ""


func _on_initialized() -> void:
	_display_result()

	# Hide the buttons - SF2 didn't ask, it just kept you shopping
	button_row.visible = false

	# Determine return destination based on result type
	_return_destination = _get_return_destination()

	# Show hint about what's happening
	details_label.text += "\n\n[B: Menu]"

	# Start auto-return timer
	_auto_return_timer = get_tree().create_timer(AUTO_RETURN_DELAY)
	_auto_return_timer.timeout.connect(_on_auto_return)


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
		"promotion_complete":
			_show_promotion_complete(result)
		_:
			# Fallback for church services without explicit type
			if result.get("success", false):
				_show_generic_success(result)
			else:
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


func _show_promotion_complete(result: Dictionary) -> void:
	var message: String = result.get("message", "Promotion complete!")
	var cost: int = result.get("gold_spent", 0)

	result_label.text = "PROMOTION COMPLETE!"
	result_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	details_label.text = "%s\nSpent %dG" % [message, cost]


func _show_generic_success(result: Dictionary) -> void:
	var message: String = result.get("message", "Service complete!")
	var cost: int = result.get("gold_spent", 0)

	result_label.text = "SERVICE COMPLETE!"
	result_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	if cost > 0:
		details_label.text = "%s\nSpent %dG" % [message, cost]
	else:
		details_label.text = message


## Determine where to return based on result type (SF2-style defaults)
func _get_return_destination() -> String:
	var result: Dictionary = context.last_result
	var result_type: String = result.get("type", "unknown")

	# Promotion: return to action menu (character likely can't promote again)
	if result_type == "promotion_complete":
		return "church_action_select"

	# Church modes: return to character selection (heal more characters)
	if _is_church_mode():
		return "church_char_select"

	# Crafter mode: return to recipe browser
	if _is_crafter_mode():
		return "crafter_recipe_browser"

	# Sells: return to action menu (natural "done selling" point)
	if result_type == "sell_complete":
		return "action_select"

	# Purchases/placements: return to item browser (keep shopping - SF2 style)
	return "item_browser"


## Auto-return after timer expires
func _on_auto_return() -> void:
	if not is_inside_tree():
		return
	# Use replace_with so transaction_result isn't in history
	# This prevents the loop when user presses back on item_browser
	replace_with(_return_destination)


func _is_church_mode() -> bool:
	if not context:
		return false
	return context.mode in [ShopContextScript.Mode.HEAL, ShopContextScript.Mode.REVIVE, ShopContextScript.Mode.UNCURSE, ShopContextScript.Mode.PROMOTION]


func _is_crafter_mode() -> bool:
	if not context:
		return false
	return context.mode == ShopContextScript.Mode.CRAFT


func _get_character_name(uid: String) -> String:
	if not PartyManager:
		return uid
	for character: CharacterData in PartyManager.party_members:
		if character.character_uid == uid:
			return character.character_name
	return uid


## B button skips directly to action menu (escape hatch)
func _on_back_requested() -> void:
	# Cancel the auto-return timer if still pending
	_auto_return_timer = null
	# Use replace_with to avoid history loop
	if _is_church_mode():
		replace_with("church_action_select")
	elif _is_crafter_mode():
		replace_with("crafter_action_select")
	else:
		replace_with("action_select")
