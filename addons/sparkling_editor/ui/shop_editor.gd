@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Shop Editor UI
## Allows creating and editing ShopData resources with visual inventory management

# =============================================================================
# UI COMPONENTS
# =============================================================================

# Basic Info
var id_edit: LineEdit
var name_edit: LineEdit
var shop_type_option: OptionButton

# Presentation
var greeting_edit: TextEdit
var farewell_edit: LineEdit

# Inventory
var inventory_container: VBoxContainer
var inventory_list: ItemList
var add_item_button: Button
var remove_item_button: Button
var item_picker_popup: PopupMenu
var stock_spin: SpinBox
var price_override_spin: SpinBox
var inventory_edit_container: HBoxContainer

# Deals
var deals_container: VBoxContainer
var deals_list: ItemList
var add_deal_button: Button
var remove_deal_button: Button

# Economy
var buy_multiplier_spin: SpinBox
var sell_multiplier_spin: SpinBox
var deals_discount_spin: SpinBox

# Availability
var required_flags_edit: LineEdit
var forbidden_flags_edit: LineEdit

# Features
var can_sell_check: CheckBox
var can_store_check: CheckBox
var can_sell_caravan_check: CheckBox

# Church Services (conditional)
var church_section: VBoxContainer
var heal_cost_spin: SpinBox
var revive_base_spin: SpinBox
var revive_mult_spin: SpinBox
var uncurse_cost_spin: SpinBox

# Crafter (conditional)
var crafter_section: VBoxContainer
var crafter_id_edit: LineEdit

# Cached data
var _items_cache: Array[Resource] = []
var _npcs_cache: Array[Resource] = []
var _current_inventory: Array[Dictionary] = []
var _current_deals: Array[String] = []


func _ready() -> void:
	resource_type_id = "shop"
	resource_type_name = "Shop"
	# Declare dependencies BEFORE super._ready() so base class can auto-subscribe
	resource_dependencies = ["item", "npc"]
	super._ready()


## Override: Create the shop-specific detail form
func _create_detail_form() -> void:
	_refresh_caches()

	_add_basic_info_section()
	_add_presentation_section()
	_add_inventory_section()
	_add_deals_section()
	_add_economy_section()
	_add_availability_section()
	_add_features_section()
	_add_church_section()
	_add_crafter_section()

	# Add button container at end (with separator for visual clarity)
	_add_button_container_to_detail_panel()


## Override: Load shop data from resource into UI
func _load_resource_data() -> void:
	var shop: ShopData = current_resource as ShopData
	if not shop:
		return

	# Basic info
	id_edit.text = shop.shop_id
	name_edit.text = shop.shop_name
	shop_type_option.selected = shop.shop_type

	# Presentation
	greeting_edit.text = shop.greeting_text
	farewell_edit.text = shop.farewell_text

	# Inventory
	_current_inventory = shop.inventory.duplicate(true)
	_refresh_inventory_list()

	# Deals
	_current_deals = shop.deals_inventory.duplicate()
	_refresh_deals_list()

	# Economy
	buy_multiplier_spin.value = shop.buy_multiplier
	sell_multiplier_spin.value = shop.sell_multiplier
	deals_discount_spin.value = shop.deals_discount

	# Availability
	required_flags_edit.text = ",".join(shop.required_flags)
	forbidden_flags_edit.text = ",".join(shop.forbidden_flags)

	# Features
	can_sell_check.button_pressed = shop.can_sell
	can_store_check.button_pressed = shop.can_store_to_caravan
	can_sell_caravan_check.button_pressed = shop.can_sell_from_caravan

	# Church services
	heal_cost_spin.value = shop.heal_cost
	revive_base_spin.value = shop.revive_base_cost
	revive_mult_spin.value = shop.revive_level_multiplier
	uncurse_cost_spin.value = shop.uncurse_base_cost

	# Crafter
	crafter_id_edit.text = shop.crafter_id

	# Update conditional visibility
	_on_shop_type_changed(shop.shop_type)


## Override: Save UI data to resource
func _save_resource_data() -> void:
	var shop: ShopData = current_resource as ShopData
	if not shop:
		return

	# Basic info
	shop.shop_id = id_edit.text.strip_edges()
	shop.shop_name = name_edit.text.strip_edges()
	shop.shop_type = shop_type_option.selected

	# Presentation
	shop.greeting_text = greeting_edit.text
	shop.farewell_text = farewell_edit.text.strip_edges()

	# Inventory
	shop.inventory = _current_inventory.duplicate(true)

	# Deals
	shop.deals_inventory = _current_deals.duplicate()
	shop.has_deals = not _current_deals.is_empty()

	# Economy
	shop.buy_multiplier = buy_multiplier_spin.value
	shop.sell_multiplier = sell_multiplier_spin.value
	shop.deals_discount = deals_discount_spin.value

	# Availability
	shop.required_flags = _parse_flags(required_flags_edit.text)
	shop.forbidden_flags = _parse_flags(forbidden_flags_edit.text)

	# Features
	shop.can_sell = can_sell_check.button_pressed
	shop.can_store_to_caravan = can_store_check.button_pressed
	shop.can_sell_from_caravan = can_sell_caravan_check.button_pressed

	# Church services
	shop.heal_cost = int(heal_cost_spin.value)
	shop.revive_base_cost = int(revive_base_spin.value)
	shop.revive_level_multiplier = revive_mult_spin.value
	shop.uncurse_base_cost = int(uncurse_cost_spin.value)

	# Crafter
	shop.crafter_id = crafter_id_edit.text.strip_edges()


## Override: Validate resource before saving
func _validate_resource() -> Dictionary:
	var shop: ShopData = current_resource as ShopData
	if not shop:
		return {valid = false, errors = ["Invalid resource type"]}

	var errors: Array[String] = []

	if id_edit.text.strip_edges().is_empty():
		errors.append("Shop ID cannot be empty")

	if name_edit.text.strip_edges().is_empty():
		errors.append("Shop name cannot be empty")

	# Validate inventory item IDs exist
	for entry: Dictionary in _current_inventory:
		var item_id: String = entry.get("item_id", "")
		if not _item_exists(item_id):
			errors.append("Invalid item in inventory: '%s'" % item_id)

	# Validate deals item IDs exist
	for item_id: String in _current_deals:
		if not _item_exists(item_id):
			errors.append("Invalid item in deals: '%s'" % item_id)

	# Crafter validation
	if shop_type_option.selected == ShopData.ShopType.CRAFTER:
		if crafter_id_edit.text.strip_edges().is_empty():
			errors.append("Crafter shops require a crafter_id")

	return {valid = errors.is_empty(), errors = errors}


## Override: Create a new shop with defaults
func _create_new_resource() -> Resource:
	var new_shop: ShopData = ShopData.new()
	new_shop.shop_id = "new_shop_%d" % Time.get_unix_time_from_system()
	new_shop.shop_name = "New Shop"
	new_shop.shop_type = ShopData.ShopType.ITEM
	new_shop.greeting_text = "Welcome!"
	new_shop.farewell_text = "Come again!"
	new_shop.can_sell = true
	new_shop.can_store_to_caravan = true
	new_shop.can_sell_from_caravan = true
	return new_shop


## Override: Get the display name from a shop resource
func _get_resource_display_name(resource: Resource) -> String:
	var shop: ShopData = resource as ShopData
	if shop:
		return shop.shop_name if not shop.shop_name.is_empty() else shop.shop_id
	return "Unnamed Shop"


# =============================================================================
# UI CREATION HELPERS
# =============================================================================

func _add_basic_info_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Basic Information"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Shop ID
	var id_container: HBoxContainer = HBoxContainer.new()
	var id_label: Label = Label.new()
	id_label.text = "Shop ID:"
	id_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	id_container.add_child(id_label)

	id_edit = LineEdit.new()
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_edit.placeholder_text = "e.g., granseal_weapon_shop"
	id_edit.tooltip_text = "Unique ID for referencing this shop. Use snake_case, e.g., 'granseal_weapon_shop'."
	id_edit.text_changed.connect(_mark_dirty)
	id_container.add_child(id_edit)
	section.add_child(id_container)

	# Shop Name
	var name_container: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = "Shop Name:"
	name_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	name_container.add_child(name_label)

	name_edit = LineEdit.new()
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.placeholder_text = "e.g., Granseal Weapon Shop"
	name_edit.tooltip_text = "Display name shown to the player in menus and when entering the shop."
	name_edit.text_changed.connect(_mark_dirty)
	name_container.add_child(name_edit)
	section.add_child(name_container)

	# Shop Type
	var type_container: HBoxContainer = HBoxContainer.new()
	var type_label: Label = Label.new()
	type_label.text = "Shop Type:"
	type_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	type_container.add_child(type_label)

	shop_type_option = OptionButton.new()
	shop_type_option.tooltip_text = "Weapon = equipment, Item = consumables, Church = heal/revive, Crafter = forging, Special = unique."
	shop_type_option.add_item("Weapon", ShopData.ShopType.WEAPON)
	shop_type_option.add_item("Item", ShopData.ShopType.ITEM)
	shop_type_option.add_item("Church", ShopData.ShopType.CHURCH)
	shop_type_option.add_item("Crafter", ShopData.ShopType.CRAFTER)
	shop_type_option.add_item("Special", ShopData.ShopType.SPECIAL)
	shop_type_option.item_selected.connect(_on_shop_type_changed)
	type_container.add_child(shop_type_option)
	section.add_child(type_container)

	detail_panel.add_child(section)


func _add_presentation_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Presentation"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Greeting
	var greeting_label: Label = Label.new()
	greeting_label.text = "Greeting Text:"
	section.add_child(greeting_label)

	greeting_edit = TextEdit.new()
	greeting_edit.custom_minimum_size.y = 60
	greeting_edit.placeholder_text = "Welcome to my shop!"
	greeting_edit.tooltip_text = "Message displayed when player enters the shop. Multi-line supported."
	greeting_edit.text_changed.connect(_mark_dirty)
	section.add_child(greeting_edit)

	# Farewell
	var farewell_container: HBoxContainer = HBoxContainer.new()
	var farewell_label: Label = Label.new()
	farewell_label.text = "Farewell Text:"
	farewell_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	farewell_container.add_child(farewell_label)

	farewell_edit = LineEdit.new()
	farewell_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	farewell_edit.placeholder_text = "Come again!"
	farewell_edit.tooltip_text = "Message displayed when player leaves the shop."
	farewell_edit.text_changed.connect(_mark_dirty)
	farewell_container.add_child(farewell_edit)
	section.add_child(farewell_container)

	detail_panel.add_child(section)


func _add_inventory_section() -> void:
	inventory_container = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Inventory"
	section_label.add_theme_font_size_override("font_size", 16)
	inventory_container.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Items available for purchase in this shop"
	help_label.add_theme_color_override("font_color", EditorThemeUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", 12)
	inventory_container.add_child(help_label)

	# Inventory list
	inventory_list = ItemList.new()
	inventory_list.custom_minimum_size = Vector2(0, 150)
	inventory_list.item_selected.connect(_on_inventory_item_selected)
	inventory_container.add_child(inventory_list)

	# Edit controls for selected item
	inventory_edit_container = HBoxContainer.new()
	inventory_edit_container.visible = false

	var stock_label: Label = Label.new()
	stock_label.text = "Stock:"
	inventory_edit_container.add_child(stock_label)

	stock_spin = SpinBox.new()
	stock_spin.min_value = -1
	stock_spin.max_value = 999
	stock_spin.value = -1
	stock_spin.tooltip_text = "-1 = infinite stock"
	stock_spin.value_changed.connect(_on_stock_changed)
	inventory_edit_container.add_child(stock_spin)

	var price_label: Label = Label.new()
	price_label.text = "Price Override:"
	inventory_edit_container.add_child(price_label)

	price_override_spin = SpinBox.new()
	price_override_spin.min_value = -1
	price_override_spin.max_value = 999999
	price_override_spin.value = -1
	price_override_spin.tooltip_text = "-1 = use item's buy_price"
	price_override_spin.value_changed.connect(_on_price_override_changed)
	inventory_edit_container.add_child(price_override_spin)

	inventory_container.add_child(inventory_edit_container)

	# Buttons
	var button_row: HBoxContainer = HBoxContainer.new()

	add_item_button = Button.new()
	add_item_button.text = "Add Item..."
	add_item_button.pressed.connect(_on_add_inventory_item)
	button_row.add_child(add_item_button)

	remove_item_button = Button.new()
	remove_item_button.text = "Remove Selected"
	remove_item_button.pressed.connect(_on_remove_inventory_item)
	button_row.add_child(remove_item_button)

	inventory_container.add_child(button_row)

	# Item picker popup
	item_picker_popup = PopupMenu.new()
	item_picker_popup.id_pressed.connect(_on_item_picker_selected)
	add_child(item_picker_popup)

	detail_panel.add_child(inventory_container)


func _add_deals_section() -> void:
	deals_container = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Deals (Discounted Items)"
	section_label.add_theme_font_size_override("font_size", 16)
	deals_container.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Items shown in the 'Deals' menu with discount applied"
	help_label.add_theme_color_override("font_color", EditorThemeUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", 12)
	deals_container.add_child(help_label)

	deals_list = ItemList.new()
	deals_list.custom_minimum_size = Vector2(0, 80)
	deals_container.add_child(deals_list)

	var button_row: HBoxContainer = HBoxContainer.new()

	add_deal_button = Button.new()
	add_deal_button.text = "Add Deal Item..."
	add_deal_button.pressed.connect(_on_add_deal_item)
	button_row.add_child(add_deal_button)

	remove_deal_button = Button.new()
	remove_deal_button.text = "Remove Selected"
	remove_deal_button.pressed.connect(_on_remove_deal_item)
	button_row.add_child(remove_deal_button)

	deals_container.add_child(button_row)

	detail_panel.add_child(deals_container)


func _add_economy_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Economy"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Buy multiplier
	var buy_container: HBoxContainer = HBoxContainer.new()
	var buy_label: Label = Label.new()
	buy_label.text = "Buy Multiplier:"
	buy_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	buy_label.tooltip_text = "Multiplier on item buy prices (1.0 = normal)"
	buy_container.add_child(buy_label)

	buy_multiplier_spin = SpinBox.new()
	buy_multiplier_spin.min_value = 0.1
	buy_multiplier_spin.max_value = 2.0
	buy_multiplier_spin.step = 0.05
	buy_multiplier_spin.value = 1.0
	buy_multiplier_spin.tooltip_text = "Multiplier on item buy prices. 1.0 = normal, 1.5 = 50% markup, 0.8 = 20% discount."
	buy_multiplier_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	buy_container.add_child(buy_multiplier_spin)
	section.add_child(buy_container)

	# Sell multiplier
	var sell_container: HBoxContainer = HBoxContainer.new()
	var sell_label: Label = Label.new()
	sell_label.text = "Sell Multiplier:"
	sell_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	sell_label.tooltip_text = "Multiplier on item sell prices (1.0 = normal)"
	sell_container.add_child(sell_label)

	sell_multiplier_spin = SpinBox.new()
	sell_multiplier_spin.min_value = 0.1
	sell_multiplier_spin.max_value = 2.0
	sell_multiplier_spin.step = 0.05
	sell_multiplier_spin.value = 1.0
	sell_multiplier_spin.tooltip_text = "Multiplier on item sell prices. 1.0 = normal, 0.5 = pay half value, 1.2 = generous buyer."
	sell_multiplier_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	sell_container.add_child(sell_multiplier_spin)
	section.add_child(sell_container)

	# Deals discount
	var deals_container: HBoxContainer = HBoxContainer.new()
	var deals_label: Label = Label.new()
	deals_label.text = "Deals Discount:"
	deals_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	deals_label.tooltip_text = "Discount on deals items (0.75 = 25% off)"
	deals_container.add_child(deals_label)

	deals_discount_spin = SpinBox.new()
	deals_discount_spin.min_value = 0.1
	deals_discount_spin.max_value = 1.0
	deals_discount_spin.step = 0.05
	deals_discount_spin.value = 0.75
	deals_discount_spin.tooltip_text = "Price multiplier for deal items. 0.75 = 25% off, 0.5 = half price, 1.0 = no discount."
	deals_discount_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	deals_container.add_child(deals_discount_spin)
	section.add_child(deals_container)

	detail_panel.add_child(section)


func _add_availability_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Availability (Story Flags)"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Required flags
	var req_container: HBoxContainer = HBoxContainer.new()
	var req_label: Label = Label.new()
	req_label.text = "Required Flags:"
	req_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	req_label.tooltip_text = "All flags must be set for shop to be available"
	req_container.add_child(req_label)

	required_flags_edit = LineEdit.new()
	required_flags_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	required_flags_edit.placeholder_text = "e.g., chapter_2_started, rescued_princess"
	required_flags_edit.tooltip_text = "Comma-separated story flags. ALL must be set for shop to appear. Empty = always available."
	required_flags_edit.text_changed.connect(_mark_dirty)
	req_container.add_child(required_flags_edit)
	section.add_child(req_container)

	# Forbidden flags
	var forb_container: HBoxContainer = HBoxContainer.new()
	var forb_label: Label = Label.new()
	forb_label.text = "Forbidden Flags:"
	forb_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	forb_label.tooltip_text = "If any of these flags are set, shop is unavailable"
	forb_container.add_child(forb_label)

	forbidden_flags_edit = LineEdit.new()
	forbidden_flags_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forbidden_flags_edit.placeholder_text = "e.g., shop_destroyed"
	forbidden_flags_edit.tooltip_text = "Comma-separated story flags. If ANY is set, shop becomes unavailable. Use for destroyed/closed shops."
	forbidden_flags_edit.text_changed.connect(_mark_dirty)
	forb_container.add_child(forbidden_flags_edit)
	section.add_child(forb_container)

	detail_panel.add_child(section)


func _add_features_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Features"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	can_sell_check = CheckBox.new()
	can_sell_check.text = "Can Sell Items (shop buys from player)"
	can_sell_check.button_pressed = true
	can_sell_check.tooltip_text = "If enabled, players can sell their items to this shop for gold."
	can_sell_check.toggled.connect(func(_pressed: bool) -> void: _mark_dirty())
	section.add_child(can_sell_check)

	can_store_check = CheckBox.new()
	can_store_check.text = "Can Store to Caravan"
	can_store_check.button_pressed = true
	can_store_check.tooltip_text = "If enabled, players can transfer items to the Caravan storage from this shop."
	can_store_check.toggled.connect(func(_pressed: bool) -> void: _mark_dirty())
	section.add_child(can_store_check)

	can_sell_caravan_check = CheckBox.new()
	can_sell_caravan_check.text = "Can Sell from Caravan Storage"
	can_sell_caravan_check.button_pressed = true
	can_sell_caravan_check.tooltip_text = "If enabled, players can sell items directly from Caravan storage without moving them first."
	can_sell_caravan_check.toggled.connect(func(_pressed: bool) -> void: _mark_dirty())
	section.add_child(can_sell_caravan_check)

	detail_panel.add_child(section)


func _add_church_section() -> void:
	church_section = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Church Services"
	section_label.add_theme_font_size_override("font_size", 16)
	church_section.add_child(section_label)

	# Heal cost
	var heal_container: HBoxContainer = HBoxContainer.new()
	var heal_label: Label = Label.new()
	heal_label.text = "Heal Cost:"
	heal_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	heal_label.tooltip_text = "Cost to fully heal a character (0 = free)"
	heal_container.add_child(heal_label)

	heal_cost_spin = SpinBox.new()
	heal_cost_spin.min_value = 0
	heal_cost_spin.max_value = 9999
	heal_cost_spin.value = 0
	heal_cost_spin.tooltip_text = "Gold cost to fully heal one character. 0 = free healing (classic Shining Force style)."
	heal_cost_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	heal_container.add_child(heal_cost_spin)
	church_section.add_child(heal_container)

	# Revive base cost
	var revive_container: HBoxContainer = HBoxContainer.new()
	var revive_label: Label = Label.new()
	revive_label.text = "Revive Base Cost:"
	revive_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	revive_container.add_child(revive_label)

	revive_base_spin = SpinBox.new()
	revive_base_spin.min_value = 0
	revive_base_spin.max_value = 9999
	revive_base_spin.value = 200
	revive_base_spin.tooltip_text = "Base gold cost to revive a fallen character. Final cost = base + (level x multiplier)."
	revive_base_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	revive_container.add_child(revive_base_spin)
	church_section.add_child(revive_container)

	# Revive level multiplier
	var mult_container: HBoxContainer = HBoxContainer.new()
	var mult_label: Label = Label.new()
	mult_label.text = "Revive Level Mult:"
	mult_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	mult_label.tooltip_text = "Cost per character level added to base"
	mult_container.add_child(mult_label)

	revive_mult_spin = SpinBox.new()
	revive_mult_spin.min_value = 0.0
	revive_mult_spin.max_value = 100.0
	revive_mult_spin.step = 0.5
	revive_mult_spin.value = 10.0
	revive_mult_spin.tooltip_text = "Gold per character level added to revival cost. Example: 10 means level 20 adds 200G."
	revive_mult_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	mult_container.add_child(revive_mult_spin)
	church_section.add_child(mult_container)

	# Uncurse cost
	var uncurse_container: HBoxContainer = HBoxContainer.new()
	var uncurse_label: Label = Label.new()
	uncurse_label.text = "Uncurse Cost:"
	uncurse_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	uncurse_container.add_child(uncurse_label)

	uncurse_cost_spin = SpinBox.new()
	uncurse_cost_spin.min_value = 0
	uncurse_cost_spin.max_value = 9999
	uncurse_cost_spin.value = 500
	uncurse_cost_spin.tooltip_text = "Gold cost to remove a curse from equipped item. Cursed items cannot be unequipped otherwise."
	uncurse_cost_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	uncurse_container.add_child(uncurse_cost_spin)
	church_section.add_child(uncurse_container)

	# Preview
	var preview_label: Label = Label.new()
	preview_label.text = "Example: Level 10 revival = %d + (10 x 10) = %d G" % [200, 300]
	preview_label.add_theme_color_override("font_color", EditorThemeUtils.get_help_color())
	preview_label.add_theme_font_size_override("font_size", 12)
	church_section.add_child(preview_label)

	detail_panel.add_child(church_section)


func _add_crafter_section() -> void:
	crafter_section = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Crafter Integration"
	section_label.add_theme_font_size_override("font_size", 16)
	crafter_section.add_child(section_label)

	var id_container: HBoxContainer = HBoxContainer.new()
	var id_label: Label = Label.new()
	id_label.text = "Crafter ID:"
	id_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	id_label.tooltip_text = "ID of the CrafterData resource for forging"
	id_container.add_child(id_label)

	crafter_id_edit = LineEdit.new()
	crafter_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crafter_id_edit.placeholder_text = "e.g., mithril_forge"
	crafter_id_edit.tooltip_text = "ID of the CrafterData resource that defines available recipes. Required for Crafter-type shops."
	crafter_id_edit.text_changed.connect(_mark_dirty)
	id_container.add_child(crafter_id_edit)
	crafter_section.add_child(id_container)

	detail_panel.add_child(crafter_section)


# =============================================================================
# EVENT HANDLERS
# =============================================================================

func _on_shop_type_changed(index: int) -> void:
	_mark_dirty()

	# Show/hide conditional sections
	var is_church: bool = (index == ShopData.ShopType.CHURCH)
	var is_crafter: bool = (index == ShopData.ShopType.CRAFTER)

	church_section.visible = is_church
	crafter_section.visible = is_crafter

	# Show inventory for non-church shops
	var shows_inventory: bool = (index != ShopData.ShopType.CHURCH)
	inventory_container.visible = shows_inventory
	deals_container.visible = shows_inventory


func _on_inventory_item_selected(index: int) -> void:
	if index < 0 or index >= _current_inventory.size():
		inventory_edit_container.visible = false
		return

	inventory_edit_container.visible = true
	var entry: Dictionary = _current_inventory[index]
	stock_spin.value = entry.get("stock", -1)
	price_override_spin.value = entry.get("price_override", -1)


func _on_stock_changed(value: float) -> void:
	var selected: PackedInt32Array = inventory_list.get_selected_items()
	if selected.is_empty():
		return

	var index: int = selected[0]
	if index >= 0 and index < _current_inventory.size():
		_current_inventory[index]["stock"] = int(value)
		_refresh_inventory_list()
		inventory_list.select(index)
		_mark_dirty()


func _on_price_override_changed(value: float) -> void:
	var selected: PackedInt32Array = inventory_list.get_selected_items()
	if selected.is_empty():
		return

	var index: int = selected[0]
	if index >= 0 and index < _current_inventory.size():
		_current_inventory[index]["price_override"] = int(value)
		_refresh_inventory_list()
		inventory_list.select(index)
		_mark_dirty()


func _on_add_inventory_item() -> void:
	_show_item_picker(false)


func _on_remove_inventory_item() -> void:
	var selected: PackedInt32Array = inventory_list.get_selected_items()
	if selected.is_empty():
		return

	var index: int = selected[0]
	if index >= 0 and index < _current_inventory.size():
		_current_inventory.remove_at(index)
		_refresh_inventory_list()
		inventory_edit_container.visible = false
		_mark_dirty()


func _on_add_deal_item() -> void:
	_show_item_picker(true)


func _on_remove_deal_item() -> void:
	var selected: PackedInt32Array = deals_list.get_selected_items()
	if selected.is_empty():
		return

	var index: int = selected[0]
	if index >= 0 and index < _current_deals.size():
		_current_deals.remove_at(index)
		_refresh_deals_list()
		_mark_dirty()


var _adding_to_deals: bool = false

func _show_item_picker(for_deals: bool) -> void:
	_adding_to_deals = for_deals
	item_picker_popup.clear()

	for i in range(_items_cache.size()):
		var item: ItemData = _items_cache[i] as ItemData
		if item:
			var label: String = "%s (%dG)" % [item.item_name, item.buy_price]
			item_picker_popup.add_item(label, i)

	if item_picker_popup.item_count == 0:
		item_picker_popup.add_item("(No items available)", -1)
		item_picker_popup.set_item_disabled(0, true)

	item_picker_popup.popup_centered()


func _on_item_picker_selected(id: int) -> void:
	if id < 0 or id >= _items_cache.size():
		return

	var item: ItemData = _items_cache[id] as ItemData
	if not item:
		return

	# Get item_id from the item
	var item_id: String = _get_item_id(item)
	if item_id.is_empty():
		return

	if _adding_to_deals:
		if item_id not in _current_deals:
			_current_deals.append(item_id)
			_refresh_deals_list()
			_mark_dirty()
	else:
		# Check if already in inventory
		for entry: Dictionary in _current_inventory:
			if entry.get("item_id", "") == item_id:
				return  # Already exists

		_current_inventory.append({
			"item_id": item_id,
			"stock": -1,
			"price_override": -1
		})
		_refresh_inventory_list()
		_mark_dirty()


# =============================================================================
# HELPERS
# =============================================================================

func _refresh_caches() -> void:
	_items_cache.clear()
	_npcs_cache.clear()

	if ModLoader and ModLoader.registry:
		_items_cache = ModLoader.registry.get_all_resources("item")
		_npcs_cache = ModLoader.registry.get_all_resources("npc")


## Override: Called when dependent resource types change (via base class)
## Refreshes caches when items are created/saved/deleted in other tabs
func _on_dependencies_changed(_changed_type: String) -> void:
	_refresh_caches()


func _refresh_inventory_list() -> void:
	inventory_list.clear()

	for entry: Dictionary in _current_inventory:
		var item_id: String = entry.get("item_id", "")
		var stock: int = entry.get("stock", -1)
		var price_override: int = entry.get("price_override", -1)

		var item_name: String = _get_item_name(item_id)
		var stock_str: String = "infinite" if stock == -1 else str(stock)
		var price_str: String = "default" if price_override == -1 else "%dG" % price_override

		var label: String = "%s  [Stock: %s, Price: %s]" % [item_name, stock_str, price_str]
		inventory_list.add_item(label)


func _refresh_deals_list() -> void:
	deals_list.clear()

	for item_id: String in _current_deals:
		var item_name: String = _get_item_name(item_id)
		deals_list.add_item(item_name)


func _get_item_name(item_id: String) -> String:
	for item: Resource in _items_cache:
		var item_data: ItemData = item as ItemData
		if item_data:
			var res_id: String = _get_item_id(item_data)
			if res_id == item_id:
				return item_data.item_name
	return item_id  # Fallback to ID


func _get_item_id(item: ItemData) -> String:
	# Get ID from resource path
	if item.resource_path:
		return item.resource_path.get_file().get_basename()
	return ""


func _item_exists(item_id: String) -> bool:
	for item: Resource in _items_cache:
		var item_data: ItemData = item as ItemData
		if item_data:
			var res_id: String = _get_item_id(item_data)
			if res_id == item_id:
				return true
	return false


func _parse_flags(text: String) -> Array[String]:
	var flags: Array[String] = []
	var parts: PackedStringArray = text.split(",")
	for part: String in parts:
		var trimmed: String = part.strip_edges()
		if not trimmed.is_empty():
			flags.append(trimmed)
	return flags


## Override refresh to also refresh caches
func refresh() -> void:
	_refresh_caches()
	super.refresh()
