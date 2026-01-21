extends "res://scenes/ui/shops/screens/shop_screen_base.gd"

## SellInventory - Browse character inventory to queue items for sale
##
## Displays items from the selected character or Caravan.
## Items are added to a sell queue, then confirmed in sell_confirm screen.

var selected_item_id: String = ""
var item_buttons: Array[Button] = []
var _selected_button: Button = null
var _selected_style: StyleBoxFlat

@onready var header_label: Label = %HeaderLabel
@onready var item_list: VBoxContainer = %ItemList
@onready var item_scroll: ScrollContainer = %ItemScroll
@onready var details_panel: PanelContainer = %DetailsPanel
@onready var item_name_label: Label = %ItemNameLabel
@onready var item_price_label: Label = %ItemPriceLabel
@onready var add_button: Button = %AddButton
@onready var confirm_button: Button = %ConfirmButton
@onready var back_button: Button = %BackButton


func _on_initialized() -> void:
	_create_styles()

	# Clear any previous sell queue
	context.queue.clear()

	# Set header based on source
	if context.selling_from_uid == "caravan":
		header_label.text = "CARAVAN ITEMS"
	else:
		header_label.text = "%s'S ITEMS" % get_character_name(context.selling_from_uid).to_upper()

	_populate_item_list()
	_update_buttons()

	add_button.pressed.connect(_on_add_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	back_button.pressed.connect(_on_back_pressed)

	show_queue_panel(false)


func _create_styles() -> void:
	_selected_style = StyleBoxFlat.new()
	_selected_style.bg_color = Color(0.3, 0.5, 0.8, 1.0)
	_selected_style.set_corner_radius_all(2)


func _populate_item_list() -> void:
	# Clear existing
	for child: Node in item_list.get_children():
		child.queue_free()
	item_buttons.clear()

	var items: Array[String] = _get_source_items()

	if items.is_empty():
		var label: Label = Label.new()
		label.text = "No items to sell"
		label.add_theme_color_override("font_color", UIColors.MENU_DISABLED)
		item_list.add_child(label)
		return

	for item_id: String in items:
		var item_data: ItemData = get_item_data(item_id)
		if not item_data:
			continue

		var button: Button = _create_item_button(item_id, item_data)
		item_list.add_child(button)
		item_buttons.append(button)

		button.pressed.connect(_on_item_selected.bind(item_id, button))

	if item_buttons.size() > 0:
		await get_tree().process_frame
		item_buttons[0].grab_focus()
		_select_item(items[0], item_buttons[0])


func _get_source_items() -> Array[String]:
	var items: Array[String] = []

	if context.selling_from_uid == "caravan":
		items = StorageManager.get_depot_contents()
	else:
		var save_data: CharacterSaveData = PartyManager.get_member_save_data(context.selling_from_uid)
		if save_data:
			for item_id: String in save_data.inventory:
				items.append(item_id)

	return items


func _create_item_button(item_id: String, item_data: ItemData) -> Button:
	var button: Button = Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 32)
	button.focus_mode = Control.FOCUS_ALL

	var sell_price: int = context.get_sell_price(item_id)
	var text: String = item_data.item_name.to_upper()
	var spacing: int = 20 - text.length()
	text += " ".repeat(max(1, spacing)) + "%dG" % sell_price

	button.text = text

	# Check if already in queue
	if context.queue.has_item(item_id):
		button.add_theme_color_override("font_color", UIColors.ITEM_QUEUED)

	return button


func _on_item_selected(item_id: String, button: Button) -> void:
	_select_item(item_id, button)


func _select_item(item_id: String, button: Button) -> void:
	if _selected_button:
		_selected_button.remove_theme_stylebox_override("normal")

	selected_item_id = item_id
	_selected_button = button
	button.add_theme_stylebox_override("normal", _selected_style)

	_update_details_panel()
	_update_buttons()


func _update_details_panel() -> void:
	if selected_item_id.is_empty():
		details_panel.hide()
		return

	var item_data: ItemData = get_item_data(selected_item_id)
	if not item_data:
		details_panel.hide()
		return

	details_panel.show()
	item_name_label.text = item_data.item_name.to_upper()

	var sell_price: int = context.get_sell_price(selected_item_id)
	item_price_label.text = "+%dG" % sell_price


func _update_buttons() -> void:
	# Add button: enabled if item selected and not already in queue
	var can_add: bool = not selected_item_id.is_empty() and not context.queue.has_item(selected_item_id)
	add_button.disabled = not can_add

	# Confirm button: enabled if queue has items
	var has_items: bool = not context.queue.is_empty()
	confirm_button.visible = has_items
	if has_items:
		var total: int = context.queue.get_total_cost()
		confirm_button.text = "CONFIRM SALE (+%dG)" % total

	show_queue_panel(has_items)


func _on_add_pressed() -> void:
	if selected_item_id.is_empty():
		return

	var sell_price: int = context.get_sell_price(selected_item_id)

	# For sell queue, we use get_current_gold() as "available" since we're earning, not spending
	# We can always add to sell queue (no gold limit)
	context.queue.add_item(
		selected_item_id,
		1,
		sell_price,
		false,
		999999  # No gold limit for selling
	)

	# Update button color to show it's queued
	if _selected_button:
		_selected_button.add_theme_color_override("font_color", UIColors.ITEM_QUEUED)

	_update_buttons()


func _on_confirm_pressed() -> void:
	push_screen("sell_confirm")


func _on_back_pressed() -> void:
	# Clear queue on back
	context.queue.clear()
	go_back()


func _on_back_requested() -> void:
	_on_back_pressed()
