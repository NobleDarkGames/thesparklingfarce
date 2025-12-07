extends CanvasLayer

## ShopInterface - Runtime shop UI for player transactions
##
## Redesigned for full mouse/keyboard/gamepad support with clear visual feedback.
## Flow: Select Item -> Select Destination -> Click Action Button
##
## Key Design Decisions:
## - Action buttons (BUY FOR XG, SELL FOR XG) are separate from mode buttons
## - Mode buttons (BUY/SELL/DEALS/EXIT) switch between shop modes
## - All interactive elements have focus_mode = ALL for keyboard navigation
## - Visual states: Normal, Hover, Focus, Selected, Disabled

# ============================================================================
# SIGNALS
# ============================================================================

signal transaction_completed()
signal shop_exited()

# ============================================================================
# ENUMS
# ============================================================================

enum ShopMode {
	BUY,
	SELL,
	DEALS
}

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
@onready var right_column_header: Label = %RightColumnHeader
@onready var character_panel: PanelContainer = %CharacterPanel
@onready var character_grid: GridContainer = %CharacterGrid
@onready var caravan_button: Button = %CaravanButton

# Message feedback
@onready var message_label: Label = %MessageLabel

# Bottom: Action buttons (execute transactions)
@onready var buy_action_button: Button = %BuyActionButton
@onready var sell_action_button: Button = %SellActionButton

# Bottom: Mode buttons (switch between modes)
@onready var buy_mode_button: Button = %BuyModeButton
@onready var sell_mode_button: Button = %SellModeButton
@onready var deals_mode_button: Button = %DealsModeButton
@onready var exit_button: Button = %ExitButton

# Quantity selector (for bulk buying consumables)
@onready var quantity_panel: PanelContainer = %QuantityPanel
@onready var quantity_label: Label = %QuantityLabel
@onready var quantity_spinbox: SpinBox = %QuantitySpinBox

# ============================================================================
# STATE
# ============================================================================

var current_shop: ShopData = null
var current_mode: ShopMode = ShopMode.BUY
var selected_item_id: String = ""
var selected_destination: String = ""  # Character UID or "caravan"
var selected_quantity: int = 1

# For sell mode: which character are we selling from?
var selling_from_character: String = ""

# Item button references (for highlighting and focus)
var item_buttons: Array[Button] = []

# Character/destination button references
var character_buttons: Array[Button] = []

# Track which button is currently highlighted as selected destination
var _selected_destination_button: Button = null

# Track which item button is currently selected
var _selected_item_button: Button = null

# Style for selected destination (blue highlight)
var _selected_style: StyleBoxFlat

# Style for active mode button
var _active_mode_style: StyleBoxFlat

# Message timer for auto-clear
var _message_timer: SceneTreeTimer = null

# ============================================================================
# CONSTANTS
# ============================================================================

const COLOR_SELECTED: Color = Color(0.3, 0.5, 0.8, 1.0)  # Blue highlight
const COLOR_ACTIVE_MODE: Color = Color(0.2, 0.4, 0.6, 1.0)  # Darker blue for mode

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Create styles
	_create_styles()

	# Connect to ShopManager signals
	if ShopManager:
		ShopManager.shop_opened.connect(_on_shop_opened)
		ShopManager.shop_closed.connect(_on_shop_closed)
		ShopManager.purchase_completed.connect(_on_purchase_completed)
		ShopManager.purchase_failed.connect(_on_purchase_failed)
		ShopManager.sale_completed.connect(_on_sale_completed)
		ShopManager.sale_failed.connect(_on_sale_failed)
		ShopManager.gold_changed.connect(_on_gold_changed)

	# Connect action button signals
	buy_action_button.pressed.connect(_on_buy_action_pressed)
	sell_action_button.pressed.connect(_on_sell_action_pressed)

	# Connect mode button signals
	buy_mode_button.pressed.connect(_on_buy_mode_pressed)
	sell_mode_button.pressed.connect(_on_sell_mode_pressed)
	deals_mode_button.pressed.connect(_on_deals_mode_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	# Caravan button
	caravan_button.pressed.connect(_on_caravan_pressed)

	# Hide by default
	_hide_shop()

	# Hide quantity panel by default
	if quantity_panel:
		quantity_panel.hide()


func _create_styles() -> void:
	# Style for selected destination button
	_selected_style = StyleBoxFlat.new()
	_selected_style.bg_color = COLOR_SELECTED
	_selected_style.set_corner_radius_all(2)

	# Style for active mode button
	_active_mode_style = StyleBoxFlat.new()
	_active_mode_style.bg_color = COLOR_ACTIVE_MODE
	_active_mode_style.border_width_bottom = 2
	_active_mode_style.border_color = Color(0.5, 0.8, 1.0, 1.0)
	_active_mode_style.set_corner_radius_all(2)


# ============================================================================
# INPUT HANDLING
# ============================================================================

func _input(event: InputEvent) -> void:
	if not visible or not shop_panel.visible:
		return

	# Cancel closes shop
	if event.is_action_pressed("ui_cancel"):
		_on_exit_pressed()
		get_viewport().set_input_as_handled()


# ============================================================================
# VISIBILITY HELPERS
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

	# Clear any previous messages
	_clear_message()

	# Update gold display
	_update_gold_display()

	# Configure mode buttons based on shop capabilities
	sell_mode_button.visible = current_shop.can_sell
	deals_mode_button.visible = current_shop.has_active_deals()

	# Start in buy mode
	_set_mode(ShopMode.BUY)

	# Grab focus on first item after a frame
	await get_tree().process_frame
	if item_buttons.size() > 0:
		item_buttons[0].grab_focus()


# ============================================================================
# MODE MANAGEMENT
# ============================================================================

func _set_mode(mode: ShopMode) -> void:
	current_mode = mode

	# Clear selections when changing mode
	_clear_item_selection()
	_clear_destination_selection()
	selling_from_character = ""

	# Update mode button styles
	_update_mode_button_styles()

	# Update UI for this mode
	match mode:
		ShopMode.BUY:
			_setup_buy_mode()
		ShopMode.SELL:
			_setup_sell_mode()
		ShopMode.DEALS:
			_setup_deals_mode()


func _update_mode_button_styles() -> void:
	# Clear all mode button styles
	buy_mode_button.remove_theme_stylebox_override("normal")
	sell_mode_button.remove_theme_stylebox_override("normal")
	deals_mode_button.remove_theme_stylebox_override("normal")

	# Apply active style to current mode
	match current_mode:
		ShopMode.BUY:
			buy_mode_button.add_theme_stylebox_override("normal", _active_mode_style)
		ShopMode.SELL:
			sell_mode_button.add_theme_stylebox_override("normal", _active_mode_style)
		ShopMode.DEALS:
			deals_mode_button.add_theme_stylebox_override("normal", _active_mode_style)


func _setup_buy_mode() -> void:
	# Show buy action, hide sell action
	buy_action_button.visible = true
	sell_action_button.visible = false

	# Update header
	right_column_header.text = "WHO GETS IT?"

	# Populate character selection
	_populate_character_grid()
	character_panel.show()

	# Populate item list with shop inventory
	_populate_item_list(current_shop.get_all_item_ids(), false)

	# Update action button state
	_update_buy_action_state()


func _setup_sell_mode() -> void:
	# Show sell action, hide buy action
	buy_action_button.visible = false
	sell_action_button.visible = true
	sell_action_button.disabled = true
	sell_action_button.text = "SELL"

	# Update header - first need to select whose inventory
	right_column_header.text = "WHOSE INVENTORY?"

	# Populate character selection
	_populate_character_grid_for_selling()
	character_panel.show()

	# Clear item list with instruction
	_clear_item_list()
	var instruction_label: Label = Label.new()
	instruction_label.text = "SELECT CHARACTER FIRST"
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.add_theme_font_size_override("font_size", 14)
	instruction_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	item_list_container.add_child(instruction_label)


func _setup_deals_mode() -> void:
	# Show buy action, hide sell action
	buy_action_button.visible = true
	sell_action_button.visible = false

	# Update header
	right_column_header.text = "WHO GETS IT?"

	# Populate character selection
	_populate_character_grid()
	character_panel.show()

	# Populate item list with deals inventory
	_populate_item_list(current_shop.deals_inventory, true)

	# Update action button state
	_update_buy_action_state()


# ============================================================================
# ITEM LIST MANAGEMENT
# ============================================================================

func _clear_item_list() -> void:
	for child in item_list_container.get_children():
		child.queue_free()
	item_buttons.clear()
	_selected_item_button = null
	selected_item_id = ""


func _clear_item_selection() -> void:
	if _selected_item_button:
		_selected_item_button.remove_theme_stylebox_override("normal")
	_selected_item_button = null
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

		# Connect with both item_id and button reference
		button.pressed.connect(_on_item_button_pressed.bind(item_id, button))
		button.focus_entered.connect(_on_item_focus_entered.bind(item_id))

	# Auto-select first item if available
	if item_buttons.size() > 0:
		_select_item(item_ids[0], item_buttons[0])

	# Setup focus neighbors for item list
	_setup_item_focus_neighbors()


func _create_item_button(item_id: String, item_data: ItemData, is_deal: bool) -> Button:
	var button: Button = Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 28)
	button.add_theme_font_size_override("font_size", 16)
	button.focus_mode = Control.FOCUS_ALL

	# Format: "ITEM NAME         PRICE"
	var price: int = current_shop.get_effective_buy_price(item_id, is_deal)
	var price_text: String = "%dG" % price if price >= 0 else "---"

	var button_text: String = item_data.item_name.to_upper()
	if is_deal:
		var original_price: int = current_shop.get_effective_buy_price(item_id, false)
		button_text += "  %dG -> %s" % [original_price, price_text]
		button.text = button_text
	else:
		# Right-align price using spaces (monospace font)
		var spacing: int = 16 - button_text.length()
		button_text += " ".repeat(max(1, spacing)) + price_text
		button.text = button_text

	return button


func _setup_item_focus_neighbors() -> void:
	for i: int in range(item_buttons.size()):
		var button: Button = item_buttons[i]

		# Vertical navigation within list
		if i > 0:
			button.focus_neighbor_top = button.get_path_to(item_buttons[i - 1])
		if i < item_buttons.size() - 1:
			button.focus_neighbor_bottom = button.get_path_to(item_buttons[i + 1])

		# Right goes to character grid
		if character_buttons.size() > 0:
			button.focus_neighbor_right = button.get_path_to(character_buttons[0])
		elif caravan_button.visible:
			button.focus_neighbor_right = button.get_path_to(caravan_button)


# ============================================================================
# ITEM SELECTION
# ============================================================================

func _on_item_button_pressed(item_id: String, button: Button) -> void:
	print("[SHOP] Item button pressed: %s" % item_id)
	_select_item(item_id, button)


func _on_item_focus_entered(item_id: String) -> void:
	# Update details panel on focus (for keyboard navigation preview)
	_update_details_panel_for_item(item_id)


func _select_item(item_id: String, button: Button) -> void:
	# Clear previous selection highlight
	if _selected_item_button:
		_selected_item_button.remove_theme_stylebox_override("normal")

	# Set new selection
	selected_item_id = item_id
	_selected_item_button = button

	# Highlight selected item
	button.add_theme_stylebox_override("normal", _selected_style)

	# Update details panel
	_update_details_panel()
	_update_character_can_equip_indicators()
	_update_action_button_state()


func _update_details_panel() -> void:
	_update_details_panel_for_item(selected_item_id)


func _update_details_panel_for_item(item_id: String) -> void:
	if item_id.is_empty():
		details_panel.hide()
		return

	var item_data: ItemData = _get_item_data(item_id)
	if not item_data:
		details_panel.hide()
		return

	details_panel.show()

	# Item name
	item_name_label.text = item_data.item_name.to_upper()

	# Item stats
	var stats_text: String = _format_item_stats(item_data)
	item_stats_label.text = stats_text

	# Price based on mode
	var is_deal: bool = current_mode == ShopMode.DEALS

	if current_mode == ShopMode.SELL:
		var price: int = current_shop.get_effective_sell_price(item_id)
		item_price_label.text = "SELL FOR: %dG" % price
		item_price_label.remove_theme_color_override("font_color")
	else:
		var price: int = current_shop.get_effective_buy_price(item_id, is_deal)
		item_price_label.text = "BUY: %dG" % price

		# Check if can afford
		if not ShopManager.can_afford(item_id, 1, is_deal):
			item_price_label.add_theme_color_override("font_color", Color.RED)
		else:
			item_price_label.remove_theme_color_override("font_color")

	# Show quantity selector for consumables in buy/deals mode
	if item_data.item_type == ItemData.ItemType.CONSUMABLE and current_mode != ShopMode.SELL:
		_show_quantity_selector(item_data)
	else:
		_hide_quantity_selector()


func _format_item_stats(item_data: ItemData) -> String:
	var lines: Array[String] = []

	# Attack power for weapons
	if item_data.item_type == ItemData.ItemType.WEAPON:
		lines.append("AT  %d" % item_data.attack_power)

	# Defense for armor
	if item_data.item_type == ItemData.ItemType.ARMOR:
		lines.append("DF  %d" % item_data.defense_modifier)

	# Description for consumables
	if item_data.item_type == ItemData.ItemType.CONSUMABLE:
		lines.append(item_data.description)

	return "\n".join(lines)


func _show_quantity_selector(_item_data: ItemData) -> void:
	if not quantity_panel:
		return

	quantity_panel.show()
	quantity_spinbox.min_value = 1
	quantity_spinbox.max_value = 99
	quantity_spinbox.value = 1
	selected_quantity = 1

	# Disconnect existing connection before reconnecting
	if quantity_spinbox.value_changed.is_connected(_on_quantity_changed):
		quantity_spinbox.value_changed.disconnect(_on_quantity_changed)
	quantity_spinbox.value_changed.connect(_on_quantity_changed)


func _hide_quantity_selector() -> void:
	if quantity_panel:
		quantity_panel.hide()
	selected_quantity = 1


func _on_quantity_changed(value: float) -> void:
	selected_quantity = int(value)
	_update_action_button_state()


# ============================================================================
# CHARACTER/DESTINATION GRID
# ============================================================================

func _populate_character_grid() -> void:
	# Clear existing buttons
	for button: Button in character_buttons:
		button.queue_free()
	character_buttons.clear()
	_selected_destination_button = null

	if not PartyManager:
		print("[SHOP] PartyManager not available!")
		return

	print("[SHOP] Populating character grid with %d party members" % PartyManager.party_members.size())

	for character: CharacterData in PartyManager.party_members:
		var button: Button = _create_character_button(character)
		character_grid.add_child(button)
		character_buttons.append(button)

		var uid: String = character.character_uid
		var char_name: String = character.character_name
		print("[SHOP] Created button for '%s' (UID: %s)" % [char_name, uid])

		# Connect using both pressed and gui_input for debugging
		button.pressed.connect(func() -> void:
			print("[SHOP] PRESSED signal for: %s" % char_name)
			_on_character_button_pressed(uid, button)
		)
		button.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				print("[SHOP] GUI_INPUT click on: %s" % char_name)
		)

	# Setup caravan button
	caravan_button.visible = current_shop.can_store_to_caravan
	print("[SHOP] Caravan button visible: %s" % caravan_button.visible)

	# Add debug for caravan button clicks
	if not caravan_button.gui_input.is_connected(_debug_caravan_input):
		caravan_button.gui_input.connect(_debug_caravan_input)

	# Setup focus neighbors
	_setup_character_focus_neighbors()


func _populate_character_grid_for_selling() -> void:
	# Clear existing buttons
	for button: Button in character_buttons:
		button.queue_free()
	character_buttons.clear()
	_selected_destination_button = null

	if not PartyManager:
		return

	for character: CharacterData in PartyManager.party_members:
		var button: Button = _create_character_button(character)
		character_grid.add_child(button)
		character_buttons.append(button)

		var uid: String = character.character_uid
		button.pressed.connect(_on_character_selected_for_selling.bind(uid))

	# Caravan can also sell items
	caravan_button.visible = current_shop.can_sell
	if caravan_button.visible:
		# Disconnect old connections
		if caravan_button.pressed.is_connected(_on_caravan_pressed):
			caravan_button.pressed.disconnect(_on_caravan_pressed)
		caravan_button.pressed.connect(_on_caravan_selected_for_selling)

	_setup_character_focus_neighbors()


func _create_character_button(character: CharacterData) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(80, 24)
	button.add_theme_font_size_override("font_size", 16)
	button.text = character.character_name
	button.focus_mode = Control.FOCUS_ALL
	return button


func _setup_character_focus_neighbors() -> void:
	var cols: int = character_grid.columns

	for i: int in range(character_buttons.size()):
		var button: Button = character_buttons[i]

		# Vertical neighbors
		if i >= cols:
			button.focus_neighbor_top = button.get_path_to(character_buttons[i - cols])
		if i + cols < character_buttons.size():
			button.focus_neighbor_bottom = button.get_path_to(character_buttons[i + cols])

		# Horizontal neighbors
		if i % cols > 0:
			button.focus_neighbor_left = button.get_path_to(character_buttons[i - 1])
		else:
			# First column links to item list
			if item_buttons.size() > 0:
				var item_idx: int = mini(i / cols, item_buttons.size() - 1)
				button.focus_neighbor_left = button.get_path_to(item_buttons[item_idx])

		if i % cols < cols - 1 and i + 1 < character_buttons.size():
			button.focus_neighbor_right = button.get_path_to(character_buttons[i + 1])

	# Bottom row connects to caravan
	if character_buttons.size() > 0 and caravan_button.visible:
		var last_row_start: int = (character_buttons.size() - 1) / cols * cols
		for i: int in range(last_row_start, character_buttons.size()):
			character_buttons[i].focus_neighbor_bottom = character_buttons[i].get_path_to(caravan_button)
		caravan_button.focus_neighbor_top = caravan_button.get_path_to(character_buttons[last_row_start])


func _update_character_can_equip_indicators() -> void:
	if selected_item_id.is_empty():
		return

	var item_data: ItemData = _get_item_data(selected_item_id)
	if not item_data or not item_data.is_equippable():
		# Non-equipment: everyone can receive
		for button: Button in character_buttons:
			button.disabled = false
		caravan_button.disabled = false
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

	# Caravan can always store equipment
	caravan_button.disabled = false


# ============================================================================
# DESTINATION SELECTION (Buy/Deals Mode)
# ============================================================================

func _on_character_button_pressed(character_uid: String, button: Button) -> void:
	print("[SHOP] Character button pressed: %s" % character_uid)
	_select_destination(character_uid, button)


func _debug_caravan_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("[SHOP] GUI_INPUT click on CARAVAN button")


func _on_caravan_pressed() -> void:
	print("[SHOP] Caravan button pressed")
	_select_destination("caravan", caravan_button)


func _select_destination(destination: String, button: Button) -> void:
	# If clicking already-selected destination, deselect
	if selected_destination == destination:
		_clear_destination_selection()
		return

	# Clear previous selection
	if _selected_destination_button:
		_selected_destination_button.remove_theme_stylebox_override("normal")

	# Set new selection
	selected_destination = destination
	_selected_destination_button = button

	# Highlight
	button.add_theme_stylebox_override("normal", _selected_style)
	print("[SHOP] Destination selected: %s" % destination)

	# Update action button
	_update_action_button_state()


func _clear_destination_selection() -> void:
	if _selected_destination_button:
		_selected_destination_button.remove_theme_stylebox_override("normal")
	_selected_destination_button = null
	selected_destination = ""
	_update_action_button_state()


# ============================================================================
# SELL MODE CHARACTER SELECTION
# ============================================================================

func _on_character_selected_for_selling(character_uid: String) -> void:
	print("[SHOP] Character selected for selling: %s" % character_uid)
	selling_from_character = character_uid

	# Get character's sellable items
	var character: CharacterData = _get_character_by_uid(character_uid)
	if not character:
		return

	# Update header
	right_column_header.text = "%s'S ITEMS" % character.character_name.to_upper()

	# Hide character panel (selection complete)
	character_panel.hide()

	# Populate item list with character's inventory
	_populate_sell_item_list(character)


func _on_caravan_selected_for_selling() -> void:
	print("[SHOP] Caravan selected for selling")
	selling_from_character = "caravan"

	right_column_header.text = "CARAVAN ITEMS"
	character_panel.hide()

	# TODO: Populate with caravan items
	_clear_item_list()
	var label: Label = Label.new()
	label.text = "CARAVAN SELLING NOT YET IMPLEMENTED"
	label.add_theme_font_size_override("font_size", 14)
	item_list_container.add_child(label)


func _populate_sell_item_list(character: CharacterData) -> void:
	_clear_item_list()

	# Get items from character's inventory
	var inventory_items: Array = character.inventory if "inventory" in character else []

	if inventory_items.is_empty():
		var label: Label = Label.new()
		label.text = "NO ITEMS TO SELL"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		item_list_container.add_child(label)
		return

	for item_id: String in inventory_items:
		var item_data: ItemData = _get_item_data(item_id)
		if not item_data:
			continue

		var button: Button = Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 28)
		button.add_theme_font_size_override("font_size", 16)
		button.focus_mode = Control.FOCUS_ALL

		var sell_price: int = current_shop.get_effective_sell_price(item_id)
		var button_text: String = item_data.item_name.to_upper()
		var spacing: int = 16 - button_text.length()
		button_text += " ".repeat(max(1, spacing)) + "%dG" % sell_price
		button.text = button_text

		item_list_container.add_child(button)
		item_buttons.append(button)

		button.pressed.connect(_on_sell_item_button_pressed.bind(item_id, button))

	_setup_item_focus_neighbors()

	if item_buttons.size() > 0:
		item_buttons[0].grab_focus()


func _on_sell_item_button_pressed(item_id: String, button: Button) -> void:
	print("[SHOP] Sell item selected: %s" % item_id)
	_select_item(item_id, button)
	_update_sell_action_state()


# ============================================================================
# ACTION BUTTON STATE MANAGEMENT
# ============================================================================

func _update_action_button_state() -> void:
	match current_mode:
		ShopMode.BUY, ShopMode.DEALS:
			_update_buy_action_state()
		ShopMode.SELL:
			_update_sell_action_state()


func _update_buy_action_state() -> void:
	var can_buy: bool = (
		not selected_item_id.is_empty() and
		not selected_destination.is_empty()
	)

	# Check affordability
	if can_buy:
		var is_deal: bool = current_mode == ShopMode.DEALS
		if not ShopManager.can_afford(selected_item_id, selected_quantity, is_deal):
			can_buy = false

	buy_action_button.disabled = not can_buy

	if can_buy:
		var is_deal: bool = current_mode == ShopMode.DEALS
		var price: int = current_shop.get_effective_buy_price(selected_item_id, is_deal) * selected_quantity
		buy_action_button.text = "BUY FOR %dG" % price
	else:
		buy_action_button.text = "BUY"

	print("[SHOP] Buy action state: item=%s, dest=%s, can_buy=%s" % [selected_item_id, selected_destination, can_buy])


func _update_sell_action_state() -> void:
	var can_sell: bool = (
		not selected_item_id.is_empty() and
		not selling_from_character.is_empty()
	)

	sell_action_button.disabled = not can_sell

	if can_sell:
		var price: int = current_shop.get_effective_sell_price(selected_item_id)
		sell_action_button.text = "SELL FOR %dG" % price
	else:
		sell_action_button.text = "SELL"


# ============================================================================
# ACTION EXECUTION
# ============================================================================

func _on_buy_action_pressed() -> void:
	if buy_action_button.disabled:
		return

	print("[SHOP] Executing purchase: %s x%d -> %s" % [selected_item_id, selected_quantity, selected_destination])

	var result: Dictionary = ShopManager.buy_item(
		selected_item_id,
		selected_quantity,
		selected_destination
	)

	if result.success:
		# Clear destination but keep item selected for repeat buys
		_clear_destination_selection()


func _on_sell_action_pressed() -> void:
	if sell_action_button.disabled:
		return

	print("[SHOP] Executing sale: %s from %s" % [selected_item_id, selling_from_character])

	var result: Dictionary = ShopManager.sell_item(
		selected_item_id,
		selling_from_character,
		1  # TODO: quantity support for sell
	)

	if result.success:
		# Refresh the sell item list
		if selling_from_character != "caravan":
			var character: CharacterData = _get_character_by_uid(selling_from_character)
			if character:
				_populate_sell_item_list(character)


# ============================================================================
# MODE BUTTON HANDLERS
# ============================================================================

func _on_buy_mode_pressed() -> void:
	if current_mode != ShopMode.BUY:
		_set_mode(ShopMode.BUY)


func _on_sell_mode_pressed() -> void:
	if current_mode != ShopMode.SELL:
		_set_mode(ShopMode.SELL)


func _on_deals_mode_pressed() -> void:
	if current_mode != ShopMode.DEALS:
		_set_mode(ShopMode.DEALS)


func _on_exit_pressed() -> void:
	if current_shop:
		greeting_label.text = current_shop.farewell_text
		await get_tree().create_timer(0.5).timeout

	ShopManager.close_shop()


# ============================================================================
# TRANSACTION CALLBACKS
# ============================================================================

func _on_purchase_completed(transaction: Dictionary) -> void:
	print("[SHOP] Purchase completed: %s x%d for %dG" % [
		transaction.item_name,
		transaction.quantity,
		transaction.total_cost
	])
	_show_message("Bought %s!" % transaction.item_name, Color.GREEN)
	transaction_completed.emit()


func _on_purchase_failed(reason: String) -> void:
	print("[SHOP] Purchase failed: %s" % reason)
	# Make error messages user-friendly
	var message: String = reason
	if "gold" in reason.to_lower() or "afford" in reason.to_lower():
		message = "Not enough gold!"
	elif "inventory" in reason.to_lower() or "full" in reason.to_lower():
		message = "Inventory full!"
	elif "stock" in reason.to_lower():
		message = "Out of stock!"
	_show_message(message, Color.RED)


func _on_sale_completed(transaction: Dictionary) -> void:
	print("[SHOP] Sale completed: %s x%d for %dG" % [
		transaction.item_name,
		transaction.quantity,
		transaction.total_earned
	])
	_show_message("Sold %s for %dG!" % [transaction.item_name, transaction.total_earned], Color.GREEN)
	transaction_completed.emit()


func _on_sale_failed(reason: String) -> void:
	print("[SHOP] Sale failed: %s" % reason)
	_show_message(reason, Color.RED)


func _on_gold_changed(_old_amount: int, _new_amount: int) -> void:
	_update_gold_display()


# ============================================================================
# UI UPDATES
# ============================================================================

func _update_gold_display() -> void:
	var gold: int = ShopManager.get_gold()
	gold_label.text = "GOLD: %dG" % gold


func _show_message(text: String, color: Color = Color.WHITE, duration: float = 3.0) -> void:
	message_label.text = text
	message_label.add_theme_color_override("font_color", color)

	# Cancel previous timer if exists
	if _message_timer and _message_timer.time_left > 0:
		_message_timer.timeout.disconnect(_clear_message)

	# Set up auto-clear timer
	_message_timer = get_tree().create_timer(duration)
	_message_timer.timeout.connect(_clear_message)


func _clear_message() -> void:
	message_label.text = ""
	message_label.remove_theme_color_override("font_color")


# ============================================================================
# HELPERS
# ============================================================================

func _get_item_data(item_id: String) -> ItemData:
	if item_id.is_empty():
		return null
	return ModLoader.registry.get_resource("item", item_id) as ItemData


func _get_character_by_uid(uid: String) -> CharacterData:
	if not PartyManager:
		return null
	for character: CharacterData in PartyManager.party_members:
		if character.character_uid == uid:
			return character
	return null
