extends CanvasLayer

## ShopInterface - Runtime shop UI for player transactions
##
## Implements SF2-authentic shopping experience with QoL improvements:
## - Three-column layout (item list, details, character selection)
## - "Who equips this?" flow after purchase
## - Caravan storage option
## - Bulk buying for consumables
## - Stat comparison panel
## - Clean single-button exit
##
## Design by Lt. Clauderina, SF2 Purist approved
##
## Usage:
##   Listens for ShopManager.shop_opened signal
##   Displays shop UI with proper context
##   Calls ShopManager.close_shop() on exit

# ============================================================================
# SIGNALS
# ============================================================================

signal transaction_completed()
signal shop_exited()

# ============================================================================
# NODE REFERENCES
# ============================================================================

## The main panel containing all shop UI elements
@onready var shop_panel: Control = $ShopPanel

@onready var shop_title_label: Label = %ShopTitleLabel
@onready var greeting_label: Label = %GreetingLabel
@onready var gold_label: Label = %GoldLabel

# Left column: Item list
@onready var item_list_container: VBoxContainer = %ItemListContainer
@onready var item_list_scroll: ScrollContainer = %ItemListScroll

# Center column: Details/comparison
@onready var details_panel: PanelContainer = %DetailsPanel
@onready var item_name_label: Label = %ItemNameLabel
@onready var item_stats_label: Label = %ItemStatsLabel
@onready var item_price_label: Label = %ItemPriceLabel
@onready var stat_comparison_container: VBoxContainer = %StatComparisonContainer

# Right column: Character selection / Caravan
@onready var character_panel: PanelContainer = %CharacterPanel
@onready var character_grid: GridContainer = %CharacterGrid
@onready var caravan_button: Button = %CaravanButton

# Bottom: Action buttons
@onready var buy_button: Button = %BuyButton
@onready var sell_button: Button = %SellButton
@onready var deals_button: Button = %DealsButton
@onready var exit_button: Button = %ExitButton

# Quantity selector (for bulk buying consumables)
@onready var quantity_panel: PanelContainer = %QuantityPanel
@onready var quantity_label: Label = %QuantityLabel
@onready var quantity_spinbox: SpinBox = %QuantitySpinBox

# ============================================================================
# STATE
# ============================================================================

var current_shop: ShopData = null
var current_mode: String = "browse"  # "browse", "buy", "sell", "deals"
var selected_item_id: String = ""
var selected_character_uid: String = ""
var selected_quantity: int = 1

# Item button references (for highlighting)
var item_buttons: Array[Button] = []

# Character button references
var character_buttons: Array[Button] = []

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Connect to ShopManager signals
	if ShopManager:
		ShopManager.shop_opened.connect(_on_shop_opened)
		ShopManager.shop_closed.connect(_on_shop_closed)
		ShopManager.purchase_completed.connect(_on_purchase_completed)
		ShopManager.purchase_failed.connect(_on_purchase_failed)
		ShopManager.sale_completed.connect(_on_sale_completed)
		ShopManager.sale_failed.connect(_on_sale_failed)
		ShopManager.gold_changed.connect(_on_gold_changed)

	# Connect button signals
	buy_button.pressed.connect(_on_buy_pressed)
	sell_button.pressed.connect(_on_sell_pressed)
	deals_button.pressed.connect(_on_deals_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	caravan_button.pressed.connect(_on_caravan_selected)

	# Hide by default - use shop_panel for visibility since CanvasLayer has no show/hide
	_hide_shop()

	# Hide quantity panel by default
	if quantity_panel:
		quantity_panel.hide()


# ============================================================================
# VISIBILITY HELPERS (CanvasLayer doesn't have show/hide)
# ============================================================================

func _show_shop() -> void:
	shop_panel.show()
	visible = true


func _hide_shop() -> void:
	shop_panel.hide()
	visible = false


# ============================================================================
# SHOP LIFECYCLE
# ============================================================================

func _on_shop_opened(shop_data: ShopData) -> void:
	current_shop = shop_data
	_setup_shop_ui()
	_show_shop()


func _on_shop_closed() -> void:
	current_shop = null
	_hide_shop()
	shop_exited.emit()


func _setup_shop_ui() -> void:
	if not current_shop:
		return

	# Set shop title and greeting
	shop_title_label.text = current_shop.shop_name
	greeting_label.text = current_shop.greeting_text

	# Update gold display
	_update_gold_display()

	# Configure buttons based on shop type
	sell_button.visible = current_shop.can_sell
	deals_button.visible = current_shop.has_active_deals()

	# Start in buy mode
	_switch_to_buy_mode()


# ============================================================================
# MODE SWITCHING
# ============================================================================

func _switch_to_buy_mode() -> void:
	current_mode = "buy"
	_clear_item_list()
	_populate_item_list(current_shop.get_all_item_ids(), false)
	_show_character_selection()
	buy_button.disabled = true
	sell_button.disabled = false
	deals_button.disabled = false


func _switch_to_sell_mode() -> void:
	current_mode = "sell"
	# TODO: Show character selection first, then their inventory
	_clear_item_list()
	_hide_character_selection()
	buy_button.disabled = false
	sell_button.disabled = true
	deals_button.disabled = false


func _switch_to_deals_mode() -> void:
	current_mode = "deals"
	_clear_item_list()
	_populate_item_list(current_shop.deals_inventory, true)
	_show_character_selection()
	buy_button.disabled = false
	sell_button.disabled = false
	deals_button.disabled = true


# ============================================================================
# ITEM LIST MANAGEMENT
# ============================================================================

func _clear_item_list() -> void:
	for button: Button in item_buttons:
		button.queue_free()
	item_buttons.clear()
	selected_item_id = ""


func _populate_item_list(item_ids: Array, is_deals: bool) -> void:
	_clear_item_list()

	for item_id: String in item_ids:
		var item_data: ItemData = _get_item_data(item_id)
		if not item_data:
			continue

		var button: Button = _create_item_button(item_id, item_data, is_deals)
		item_list_container.add_child(button)
		item_buttons.append(button)

		button.pressed.connect(_on_item_selected.bind(item_id))

	# Auto-select first item
	if item_buttons.size() > 0:
		_on_item_selected(item_ids[0])


func _create_item_button(item_id: String, item_data: ItemData, is_deal: bool) -> Button:
	var button: Button = Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 24)
	button.add_theme_font_size_override("font_size", 16)

	# Format: "ITEM NAME         PRICE"
	var price: int = current_shop.get_effective_buy_price(item_id, is_deal)
	var price_text: String = "%dG" % price if price >= 0 else "---"

	# Add strikethrough for deals showing original price
	var button_text: String = item_data.item_name.to_upper()
	if is_deal:
		var original_price: int = current_shop.get_effective_buy_price(item_id, false)
		button_text += "  [s]%dG[/s] %s" % [original_price, price_text]
		button.text = button_text
	else:
		# Right-align price using spaces (monospace font)
		var spacing: int = 18 - button_text.length()
		button_text += " ".repeat(max(1, spacing)) + price_text
		button.text = button_text

	return button


# ============================================================================
# ITEM SELECTION & DETAILS
# ============================================================================

func _on_item_selected(item_id: String) -> void:
	selected_item_id = item_id
	_update_details_panel()
	_update_character_can_equip_indicators()


func _update_details_panel() -> void:
	if selected_item_id.is_empty():
		details_panel.hide()
		return

	var item_data: ItemData = _get_item_data(selected_item_id)
	if not item_data:
		details_panel.hide()
		return

	details_panel.show()

	# Item name
	item_name_label.text = item_data.item_name.to_upper()

	# Item stats
	var stats_text: String = _format_item_stats(item_data)
	item_stats_label.text = stats_text

	# Price
	var is_deal: bool = current_mode == "deals"
	var price: int = current_shop.get_effective_buy_price(selected_item_id, is_deal)

	if current_mode == "sell":
		price = current_shop.get_effective_sell_price(selected_item_id)
		item_price_label.text = "SELL FOR: %dG" % price
	else:
		item_price_label.text = "BUY: %dG" % price

		# Check if can afford
		if not ShopManager.can_afford(selected_item_id, 1, is_deal):
			item_price_label.add_theme_color_override("font_color", Color.RED)
		else:
			item_price_label.remove_theme_color_override("font_color")

	# Show quantity selector for consumables
	if item_data.item_type == ItemData.ItemType.CONSUMABLE and current_mode != "sell":
		_show_quantity_selector(item_data)
	else:
		_hide_quantity_selector()


func _format_item_stats(item_data: ItemData) -> String:
	var lines: Array[String] = []

	# Attack power for weapons
	if item_data.item_type == ItemData.ItemType.WEAPON:
		lines.append("AT  %d" % item_data.attack_power)

	# Defense for armor (uses defense_modifier)
	if item_data.item_type == ItemData.ItemType.ARMOR:
		lines.append("DF  %d" % item_data.defense_modifier)

	# Stat modifiers
	var stat_mods: Dictionary = {}
	var stat_names: Array[String] = ["hp", "mp", "strength", "defense", "agility", "intelligence", "luck"]
	for stat: String in stat_names:
		var mod: int = item_data.get_stat_modifier(stat)
		if mod != 0:
			stat_mods[stat.to_upper()] = mod

	if not stat_mods.is_empty():
		var mod_parts: Array[String] = []
		for stat_name: String in stat_mods.keys():
			var val: int = stat_mods[stat_name]
			var sign: String = "+" if val > 0 else ""
			mod_parts.append("%s %s%d" % [stat_name.substr(0, 3).to_upper(), sign, val])
		lines.append("  ".join(mod_parts))

	# Description for consumables
	if item_data.item_type == ItemData.ItemType.CONSUMABLE:
		lines.append(item_data.description)

	return "\n".join(lines)


func _show_quantity_selector(item_data: ItemData) -> void:
	if not quantity_panel:
		return

	quantity_panel.show()
	quantity_spinbox.min_value = 1
	quantity_spinbox.max_value = 99  # SF2 had no stack limits, but we'll cap at 99
	quantity_spinbox.value = 1
	selected_quantity = 1

	quantity_spinbox.value_changed.connect(_on_quantity_changed, CONNECT_ONE_SHOT)


func _hide_quantity_selector() -> void:
	if quantity_panel:
		quantity_panel.hide()
	selected_quantity = 1


func _on_quantity_changed(value: float) -> void:
	selected_quantity = int(value)
	_update_details_panel()  # Refresh price display


# ============================================================================
# CHARACTER SELECTION
# ============================================================================

func _show_character_selection() -> void:
	character_panel.show()
	_populate_character_grid()


func _hide_character_selection() -> void:
	character_panel.hide()


func _populate_character_grid() -> void:
	# Clear existing buttons
	for button: Button in character_buttons:
		button.queue_free()
	character_buttons.clear()

	# Get party members
	if not PartyManager:
		return

	for character: CharacterData in PartyManager.party_members:
		var button: Button = _create_character_button(character)
		character_grid.add_child(button)
		character_buttons.append(button)

		button.pressed.connect(_on_character_selected.bind(character.character_uid))

	# Caravan button is always available in buy mode
	caravan_button.visible = current_shop.can_store_to_caravan


func _create_character_button(character: CharacterData) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(80, 28)
	button.add_theme_font_size_override("font_size", 16)

	# TODO: Add character portrait when available
	button.text = character.character_name

	return button


func _update_character_can_equip_indicators() -> void:
	if selected_item_id.is_empty():
		return

	var item_data: ItemData = _get_item_data(selected_item_id)
	if not item_data or not item_data.is_equippable():
		# Non-equipment: everyone can receive
		for button: Button in character_buttons:
			button.disabled = false
		return

	# Equipment: filter by who can equip
	var can_equip_uids: Array[String] = []
	var equipable_chars: Array[Dictionary] = ShopManager.get_characters_who_can_equip(selected_item_id)
	for entry: Dictionary in equipable_chars:
		can_equip_uids.append(entry.character_uid)

	# Disable buttons for characters who can't equip
	for i: int in range(character_buttons.size()):
		var button: Button = character_buttons[i]
		var character: CharacterData = PartyManager.party_members[i]
		button.disabled = character.character_uid not in can_equip_uids


func _on_character_selected(character_uid: String) -> void:
	selected_character_uid = character_uid
	_execute_purchase()


func _on_caravan_selected() -> void:
	selected_character_uid = "caravan"
	_execute_purchase()


# ============================================================================
# PURCHASE EXECUTION
# ============================================================================

func _execute_purchase() -> void:
	if selected_item_id.is_empty() or selected_character_uid.is_empty():
		return

	if current_mode == "buy" or current_mode == "deals":
		var result: Dictionary = ShopManager.buy_item(
			selected_item_id,
			selected_quantity,
			selected_character_uid
		)

		if not result.success:
			# Error handled by ShopManager signals
			return

	elif current_mode == "sell":
		var result: Dictionary = ShopManager.sell_item(
			selected_item_id,
			selected_character_uid,
			selected_quantity
		)

		if not result.success:
			return

	# Reset selection
	selected_character_uid = ""
	_update_details_panel()


# ============================================================================
# TRANSACTION CALLBACKS
# ============================================================================

func _on_purchase_completed(transaction: Dictionary) -> void:
	print("ShopInterface: Purchase completed - %s x%d for %dG" % [
		transaction.item_name,
		transaction.quantity,
		transaction.total_cost
	])

	# Refresh item list (in case stock changed)
	if current_mode == "buy":
		_switch_to_buy_mode()
	elif current_mode == "deals":
		_switch_to_deals_mode()

	transaction_completed.emit()


func _on_purchase_failed(reason: String) -> void:
	print("ShopInterface: Purchase failed - %s" % reason)
	# TODO: Show error dialog
	push_warning("Purchase failed: %s" % reason)


func _on_sale_completed(transaction: Dictionary) -> void:
	print("ShopInterface: Sale completed - %s x%d for %dG" % [
		transaction.item_name,
		transaction.quantity,
		transaction.total_earned
	])

	transaction_completed.emit()


func _on_sale_failed(reason: String) -> void:
	print("ShopInterface: Sale failed - %s" % reason)
	# TODO: Show error dialog
	push_warning("Sale failed: %s" % reason)


func _on_gold_changed(old_amount: int, new_amount: int) -> void:
	_update_gold_display()


# ============================================================================
# UI UPDATES
# ============================================================================

func _update_gold_display() -> void:
	var gold: int = ShopManager.get_gold()
	gold_label.text = "GOLD: %dG" % gold


# ============================================================================
# BUTTON HANDLERS
# ============================================================================

func _on_buy_pressed() -> void:
	_switch_to_buy_mode()


func _on_sell_pressed() -> void:
	_switch_to_sell_mode()


func _on_deals_pressed() -> void:
	_switch_to_deals_mode()


func _on_exit_pressed() -> void:
	# Show farewell message
	if current_shop:
		greeting_label.text = current_shop.farewell_text
		# Brief delay before closing
		await get_tree().create_timer(1.0).timeout

	ShopManager.close_shop()


# ============================================================================
# HELPERS
# ============================================================================

func _get_item_data(item_id: String) -> ItemData:
	if item_id.is_empty():
		return null
	return ModLoader.registry.get_resource("item", item_id) as ItemData
