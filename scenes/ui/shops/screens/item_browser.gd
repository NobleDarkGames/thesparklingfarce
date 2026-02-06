extends "res://scenes/ui/shops/screens/shop_screen_base.gd"

## ItemBrowser - Browse and select items for purchase
##
## Handles both equipment and consumables:
## - Equipment: Select item -> push to char_select screen
## - Consumables: Add to queue with quantity -> proceed to placement_mode
##
## The queue building for consumables happens here.

## Currently selected item ID
var selected_item_id: String = ""

## Current quantity for consumable selection
var selected_quantity: int = 1

## Item button references
var item_buttons: Array[Button] = []

## Selected button reference
var _selected_button: Button = null

## Style for selected item
var _selected_style: StyleBoxFlat

@onready var item_list: VBoxContainer = %ItemList
@onready var item_scroll: ScrollContainer = %ItemScroll
@onready var details_panel: PanelContainer = %DetailsPanel
@onready var item_name_label: Label = %ItemNameLabel
@onready var item_desc_label: Label = %ItemDescLabel
@onready var item_stats_label: Label = %ItemStatsLabel
@onready var item_price_label: Label = %ItemPriceLabel

# Quantity selector (for consumables)
@onready var quantity_panel: HBoxContainer = %QuantityPanel
@onready var quantity_spinbox: SpinBox = %QuantitySpinbox
@onready var quantity_cost_label: Label = %QuantityCostLabel

# Action buttons
@onready var buy_button: Button = %BuyButton
@onready var add_to_queue_button: Button = %AddToQueueButton
@onready var proceed_button: Button = %ProceedButton
@onready var back_button: Button = %BackButton


func _on_initialized() -> void:
	_create_styles()
	_populate_item_list()
	_update_details_panel()
	_update_action_buttons()

	# Connect buttons
	buy_button.pressed.connect(_on_buy_pressed)
	add_to_queue_button.pressed.connect(_on_add_to_queue_pressed)
	proceed_button.pressed.connect(_on_proceed_pressed)
	back_button.pressed.connect(_on_back_pressed)
	quantity_spinbox.value_changed.connect(_on_quantity_changed)

	# Show queue panel if queue has items
	show_queue_panel(context.queue and not context.queue.is_empty())


func _create_styles() -> void:
	_selected_style = UIUtils.create_panel_style(Color(0.3, 0.5, 0.8, 1.0), Color.TRANSPARENT, 0, 2)


func _populate_item_list() -> void:
	# Clear existing
	for child: Node in item_list.get_children():
		child.queue_free()
	item_buttons.clear()

	# Get item IDs based on mode
	var item_ids: Array[String] = []
	if context.is_deals_mode():
		item_ids = context.shop.deals_inventory.duplicate()
	else:
		item_ids = context.shop.get_all_item_ids()

	# Create buttons for each item
	for item_id: String in item_ids:
		var item_data: ItemData = get_item_data(item_id)
		if not item_data:
			continue

		# Skip out-of-stock items
		if not context.shop.has_item_in_stock(item_id):
			continue

		var button: Button = _create_item_button(item_id, item_data)
		item_list.add_child(button)
		item_buttons.append(button)

		button.pressed.connect(_select_item.bind(item_id, button))

	# Auto-select first item
	if item_buttons.size() > 0:
		_select_item(item_ids[0], item_buttons[0])
		await get_tree().process_frame
		if not is_instance_valid(self):
			return
		if item_buttons.size() > 0 and is_instance_valid(item_buttons[0]):
			item_buttons[0].grab_focus()


func _create_item_button(item_id: String, item_data: ItemData) -> Button:
	var button: Button = Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 32)
	button.focus_mode = Control.FOCUS_ALL

	# Get price
	var price: int = context.get_buy_price(item_id)
	var can_afford: bool = ShopManager.can_afford(item_id, 1, context.is_deals_mode())

	# Format button text
	var text: String = item_data.item_name.to_upper()
	var spacing: int = 20 - text.length()
	text += " ".repeat(max(1, spacing)) + "%dG" % price

	button.text = text

	# Grey out if can't afford
	if not can_afford:
		button.add_theme_color_override("font_color", UIColors.MENU_DISABLED)

	return button


func _select_item(item_id: String, button: Button) -> void:
	# Clear previous selection
	if _selected_button:
		_selected_button.remove_theme_stylebox_override("normal")

	selected_item_id = item_id
	_selected_button = button

	# Highlight new selection
	button.add_theme_stylebox_override("normal", _selected_style)

	# Reset quantity
	selected_quantity = 1
	quantity_spinbox.value = 1

	_update_details_panel()
	_update_action_buttons()


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
	item_desc_label.text = item_data.description if item_data.description else ""

	# Build stats text
	var stats_lines: Array[String] = []
	if item_data.item_type == ItemData.ItemType.WEAPON:
		stats_lines.append("AT: %d" % item_data.attack_power)
	if item_data.defense_modifier > 0:
		stats_lines.append("DF: %d" % item_data.defense_modifier)
	item_stats_label.text = "\n".join(stats_lines)

	# Show price
	var price: int = context.get_buy_price(selected_item_id)
	item_price_label.text = "%dG" % price

	# Show/hide quantity panel based on item type
	var is_consumable: bool = item_data.item_type == ItemData.ItemType.CONSUMABLE
	quantity_panel.visible = is_consumable

	if is_consumable:
		_update_quantity_display()


func _update_quantity_display() -> void:
	var price: int = context.get_buy_price(selected_item_id)
	var total_cost: int = price * selected_quantity
	quantity_cost_label.text = "= %dG" % total_cost

	# Check if can afford
	var available: int = get_available_gold()
	if total_cost > available:
		quantity_cost_label.add_theme_color_override("font_color", Color.RED)
	else:
		quantity_cost_label.remove_theme_color_override("font_color")


func _on_quantity_changed(value: float) -> void:
	selected_quantity = int(value)
	_update_quantity_display()
	_update_action_buttons()


func _update_action_buttons() -> void:
	if selected_item_id.is_empty():
		buy_button.disabled = true
		add_to_queue_button.disabled = true
		proceed_button.visible = false
		return

	var item_data: ItemData = get_item_data(selected_item_id)
	if not item_data:
		buy_button.disabled = true
		add_to_queue_button.disabled = true
		return

	var is_equipment: bool = item_data.is_equippable()
	var is_consumable: bool = not is_equipment

	# Equipment: show "BUY" button, hide queue buttons
	# Consumable: show "ADD TO QUEUE" button, show "PROCEED" when queue has items
	buy_button.visible = is_equipment
	add_to_queue_button.visible = is_consumable

	if is_equipment:
		# Check if we can afford it
		var can_afford: bool = ShopManager.can_afford(selected_item_id, 1, context.is_deals_mode())
		buy_button.disabled = not can_afford
		buy_button.text = "BUY - %dG" % context.get_buy_price(selected_item_id)
	else:
		# Consumable - check if we can afford the quantity
		var price: int = context.get_buy_price(selected_item_id)
		var total_cost: int = price * selected_quantity
		var available: int = get_available_gold()
		add_to_queue_button.disabled = total_cost > available or selected_quantity < 1
		add_to_queue_button.text = "ADD %d TO QUEUE" % selected_quantity

	# Show proceed button if queue has items
	proceed_button.visible = is_consumable and context.queue and not context.queue.is_empty()
	if proceed_button.visible:
		var queue_count: int = context.queue.get_total_item_count()
		proceed_button.text = "PROCEED (%d items)" % queue_count


func _on_buy_pressed() -> void:
	# Equipment purchase: save selection and go to character select
	context.selected_item_id = selected_item_id
	context.selected_quantity = 1
	push_screen("char_select")


func _on_add_to_queue_pressed() -> void:
	var price: int = context.get_buy_price(selected_item_id)
	var success: bool = context.queue.add_item(
		selected_item_id,
		selected_quantity,
		price,
		context.is_deals_mode(),
		get_current_gold()  # Use actual gold for validation
	)

	if success:
		# Reset quantity selector
		quantity_spinbox.value = 1
		selected_quantity = 1

		# Update UI
		_update_action_buttons()
		show_queue_panel(true)


func _on_proceed_pressed() -> void:
	# Go to placement mode
	push_screen("placement_mode")


func _on_back_pressed() -> void:
	go_back()


func _on_back_requested() -> void:
	# SF2-style: instant cancel, no confirmation - queue panel provides visibility
	if context.queue and not context.queue.is_empty():
		context.queue.clear()
		show_queue_panel(false)

	go_back()
