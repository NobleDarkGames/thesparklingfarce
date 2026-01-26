extends "res://scenes/ui/shops/screens/shop_screen_base.gd"

## CharSelect - "Who equips this?" screen for equipment purchases
##
## Shows party members who can equip the selected item, plus a Caravan option.
## SF2 authentic: selecting a character completes the purchase immediately.

var selected_destination: String = ""
var _selected_button: Button = null
var character_buttons: Array[Button] = []

var _selected_style: StyleBoxFlat

@onready var header_label: Label = %HeaderLabel
@onready var item_label: Label = %ItemLabel
@onready var price_label: Label = %PriceLabel
@onready var character_grid: GridContainer = %CharacterGrid
@onready var caravan_button: Button = %CaravanButton
@onready var confirm_button: Button = %ConfirmButton
@onready var back_button: Button = %BackButton
@onready var stat_comparison_panel: PanelContainer = %StatComparisonPanel
@onready var stat_comparison_label: RichTextLabel = %StatComparisonLabel


func _on_initialized() -> void:
	_create_styles()

	# Set up header info
	var item_data: ItemData = get_item_data(context.selected_item_id)
	if item_data:
		item_label.text = item_data.item_name.to_upper()
		# Set header text based on item type
		if item_data.is_equippable():
			header_label.text = "WHO EQUIPS THIS?"
		else:
			header_label.text = "WHO CARRIES THIS?"
	else:
		item_label.text = context.selected_item_id
		header_label.text = "WHO CARRIES THIS?"

	var price: int = context.get_buy_price(context.selected_item_id)
	price_label.text = "%dG" % price

	_populate_character_grid()
	_setup_caravan_button()

	confirm_button.pressed.connect(_on_confirm_pressed)
	back_button.pressed.connect(_on_back_pressed)

	confirm_button.disabled = true

	# Grab focus on first character button or caravan
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	if character_buttons.size() > 0:
		character_buttons[0].grab_focus()
	elif caravan_button.visible:
		caravan_button.grab_focus()


func _create_styles() -> void:
	_selected_style = StyleBoxFlat.new()
	_selected_style.bg_color = Color(0.3, 0.5, 0.8, 1.0)
	_selected_style.set_corner_radius_all(2)


func _populate_character_grid() -> void:
	# Clear existing
	for child: Node in character_grid.get_children():
		child.queue_free()
	character_buttons.clear()

	if not PartyManager:
		return

	# Get eligible characters based on item type (equipment vs consumable)
	var eligible: Array[Dictionary] = ShopManager.get_eligible_characters_for_item(context.selected_item_id)

	for entry: Dictionary in eligible:
		var button: Button = _create_character_button(entry)
		character_grid.add_child(button)
		character_buttons.append(button)

		var uid: String = DictUtils.get_string(entry, "character_uid", "")
		button.pressed.connect(_on_character_selected.bind(uid, button))

	# If no characters eligible, show a message
	if eligible.is_empty():
		var label: Label = Label.new()
		var item_data: ItemData = get_item_data(context.selected_item_id)
		if item_data and item_data.is_equippable():
			label.text = "No one can equip this item!"
		else:
			label.text = "Everyone's inventory is full!"
		label.add_theme_color_override("font_color", COLOR_DISABLED)
		character_grid.add_child(label)


func _create_character_button(entry: Dictionary) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(120, 40)
	button.focus_mode = Control.FOCUS_ALL

	var character_value: Variant = entry.get("character_data")
	var character: CharacterData = character_value as CharacterData if character_value is CharacterData else null
	if character:
		button.text = character.character_name
	else:
		button.text = DictUtils.get_string(entry, "character_name", "")

	return button


func _setup_caravan_button() -> void:
	# Caravan is always available for equipment storage if shop allows it
	caravan_button.visible = context.can_store_to_caravan() and StorageManager.is_caravan_available()
	if caravan_button.visible:
		caravan_button.pressed.connect(_on_caravan_selected)


func _on_character_selected(character_uid: String, button: Button) -> void:
	_select_destination(character_uid, button)
	_update_stat_comparison(character_uid)
	# SF2 authentic: selection IS confirmation, proceed directly
	_proceed_to_confirmation()


func _on_caravan_selected() -> void:
	_select_destination("caravan", caravan_button)
	stat_comparison_panel.hide()
	# SF2 authentic: selection IS confirmation, proceed directly
	_proceed_to_confirmation()


func _select_destination(destination: String, button: Button) -> void:
	# Clear previous selection
	if _selected_button:
		_selected_button.remove_theme_stylebox_override("normal")

	selected_destination = destination
	_selected_button = button

	button.add_theme_stylebox_override("normal", _selected_style)

	# Enable confirm button
	confirm_button.disabled = false

	# Update context
	context.selected_destination = destination


func _update_stat_comparison(character_uid: String) -> void:
	var comparison: Dictionary = ShopManager.get_stat_comparison(character_uid, context.selected_item_id)

	if comparison.is_empty():
		stat_comparison_panel.hide()
		return

	stat_comparison_panel.show()

	var lines: Array[String] = []
	for stat: String in comparison.keys():
		var diff: int = DictUtils.get_int(comparison, stat, 0)
		var prefix: String = "+" if diff > 0 else ""
		var color: String = "green" if diff > 0 else ("red" if diff < 0 else "white")
		lines.append("[color=%s]%s: %s%d[/color]" % [color, stat.to_upper(), prefix, diff])

	stat_comparison_label.text = "\n".join(lines)


func _proceed_to_confirmation() -> void:
	if selected_destination.is_empty():
		return
	context.selected_destination = selected_destination

	# SF2 authentic: selection IS confirmation - complete purchase immediately
	var result: Dictionary = ShopManager.buy_item(
		context.selected_item_id,
		1,
		selected_destination
	)

	if result.get("success", false):
		var item_data: ItemData = get_item_data(context.selected_item_id)
		var transaction_val: Variant = result.get("transaction", {})
		var transaction: Dictionary = transaction_val if transaction_val is Dictionary else {}
		context.set_result("purchase_complete", {
			"item_id": context.selected_item_id,
			"item_name": item_data.item_name if item_data else context.selected_item_id,
			"total_cost": transaction.get("total_cost", 0),
			"destination": selected_destination
		})
		replace_with("transaction_result")
	else:
		context.set_result("purchase_failed", {
			"error": result.get("error", "Unknown error")
		})
		replace_with("transaction_result")


func _on_confirm_pressed() -> void:
	# Fallback for CONFIRM button (kept for accessibility but not primary flow)
	_proceed_to_confirmation()


func _on_back_pressed() -> void:
	go_back()
