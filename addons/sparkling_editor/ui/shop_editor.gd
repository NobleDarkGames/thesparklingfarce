@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Shop Editor UI
## Allows creating and editing ShopData resources with visual inventory management

# =============================================================================
# UI COMPONENTS
# =============================================================================

# Basic Info
var name_id_group: NameIdFieldGroup
var shop_type_option: OptionButton

# Inventory
var inventory_container: VBoxContainer
var inventory_list: DynamicRowList
var item_picker_popup: PopupMenu

# Deals
var deals_container: VBoxContainer
var deals_list: DynamicRowList

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
var crafter_picker: ResourcePicker



func _ready() -> void:
	resource_type_id = "shop"
	resource_type_name = "Shop"
	# Declare dependencies BEFORE super._ready() so base class can auto-subscribe
	resource_dependencies = ["item", "npc", "crafter"]
	super._ready()


## Override: Create the shop-specific detail form
func _create_detail_form() -> void:
	_add_basic_info_section()
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

	# Basic info - load name/ID using component (auto-detects lock state)
	if name_id_group:
		name_id_group.set_values(shop.shop_name, shop.shop_id, true)
	if shop_type_option:
		shop_type_option.selected = shop.shop_type

	# Inventory - load into DynamicRowList
	inventory_list.load_data(shop.inventory)

	# Deals - convert Array[String] to Array[Dictionary] for DynamicRowList
	var deals_data: Array[Dictionary] = []
	for item_id: String in shop.deals_inventory:
		deals_data.append({"item_id": item_id})
	deals_list.load_data(deals_data)

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
	if crafter_picker and not shop.crafter_id.is_empty():
		var crafter_res: CrafterData = ModLoader.registry.get_crafter(shop.crafter_id) if ModLoader and ModLoader.registry else null
		if crafter_res:
			crafter_picker.select_resource(crafter_res)
		else:
			crafter_picker.select_none()
	elif crafter_picker:
		crafter_picker.select_none()

	# Update conditional visibility
	_on_shop_type_changed(shop.shop_type)


## Override: Save UI data to resource
func _save_resource_data() -> void:
	var shop: ShopData = current_resource as ShopData
	if not shop:
		return

	# Basic info
	shop.shop_id = name_id_group.get_id_value()
	shop.shop_name = name_id_group.get_name_value()
	shop.shop_type = shop_type_option.selected

	# Inventory - collect from DynamicRowList
	shop.inventory = inventory_list.get_all_data()

	# Deals - convert from Array[Dictionary] back to Array[String]
	var deals_data: Array[Dictionary] = deals_list.get_all_data()
	var deals_ids: Array[String] = []
	for entry: Dictionary in deals_data:
		var item_id: String = entry.get("item_id", "")
		if not item_id.is_empty():
			deals_ids.append(item_id)
	shop.deals_inventory = deals_ids
	shop.has_deals = not deals_ids.is_empty()

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
	if crafter_picker:
		var selected_crafter: Resource = crafter_picker.get_selected_resource()
		if selected_crafter and "crafter_id" in selected_crafter:
			shop.crafter_id = selected_crafter.crafter_id
		else:
			shop.crafter_id = ""


## Override: Validate resource before saving
func _validate_resource() -> Dictionary:
	var shop: ShopData = current_resource as ShopData
	if not shop:
		return {valid = false, errors = ["Invalid resource type"]}

	var errors: Array[String] = []

	if name_id_group.get_id_value().is_empty():
		errors.append("Shop ID cannot be empty")

	if name_id_group.get_name_value().is_empty():
		errors.append("Shop name cannot be empty")

	# Validate inventory item IDs exist
	var inventory_data: Array[Dictionary] = inventory_list.get_all_data()
	for entry: Dictionary in inventory_data:
		var item_id: String = entry.get("item_id", "")
		if not _item_exists(item_id):
			errors.append("Invalid item in inventory: '%s'" % item_id)

	# Validate deals item IDs exist
	var deals_data: Array[Dictionary] = deals_list.get_all_data()
	for entry: Dictionary in deals_data:
		var item_id: String = entry.get("item_id", "")
		if not item_id.is_empty() and not _item_exists(item_id):
			errors.append("Invalid item in deals: '%s'" % item_id)

	# Crafter validation
	if shop_type_option.selected == ShopData.ShopType.CRAFTER:
		if not crafter_picker or not crafter_picker.has_selection():
			errors.append("Crafter shops require a crafter to be selected")

	return {valid = errors.is_empty(), errors = errors}


## Override: Create a new shop with defaults
func _create_new_resource() -> Resource:
	var new_shop: ShopData = ShopData.new()
	new_shop.shop_id = "new_shop_%d" % Time.get_unix_time_from_system()
	new_shop.shop_name = "New Shop"
	new_shop.shop_type = ShopData.ShopType.ITEM
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
	var section: VBoxContainer = SparklingEditorUtils.create_section("Basic Information", detail_panel)

	# Name/ID using reusable component
	name_id_group = NameIdFieldGroup.new()
	name_id_group.name_label = "Shop Name:"
	name_id_group.id_label = "Shop ID:"
	name_id_group.name_placeholder = "e.g., Granseal Weapon Shop"
	name_id_group.id_placeholder = "(auto-generated from name)"
	name_id_group.name_tooltip = "Display name shown to the player in menus and when entering the shop."
	name_id_group.id_tooltip = "Unique ID for referencing this shop in NPCs and scripts. Auto-generates from name."
	name_id_group.label_width = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	name_id_group.value_changed.connect(_on_name_id_changed)
	section.add_child(name_id_group)

	# Shop Type - custom dropdown with specific IDs
	var type_row: HBoxContainer = SparklingEditorUtils.create_field_row("Shop Type:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	shop_type_option = OptionButton.new()
	shop_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_type_option.tooltip_text = "Weapon = equipment, Item = consumables, Church = heal/revive, Crafter = forging, Special = unique."
	shop_type_option.add_item("Weapon", ShopData.ShopType.WEAPON)
	shop_type_option.add_item("Item", ShopData.ShopType.ITEM)
	shop_type_option.add_item("Church", ShopData.ShopType.CHURCH)
	shop_type_option.add_item("Crafter", ShopData.ShopType.CRAFTER)
	shop_type_option.add_item("Special", ShopData.ShopType.SPECIAL)
	shop_type_option.item_selected.connect(_on_shop_type_changed)
	type_row.add_child(shop_type_option)


func _add_inventory_section() -> void:
	inventory_container = VBoxContainer.new()

	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(inventory_container)
	form.add_section_label("Inventory")
	form.add_help_text("Items available for purchase in this shop")

	# Use DynamicRowList for inventory management
	inventory_list = DynamicRowList.new()
	inventory_list.add_button_text = "Add Item..."
	inventory_list.add_button_tooltip = "Add an item to this shop's inventory."
	inventory_list.use_scroll_container = true
	inventory_list.scroll_min_height = 150
	inventory_list.row_factory = _create_inventory_row
	inventory_list.data_extractor = _extract_inventory_data
	inventory_list.data_changed.connect(_on_inventory_data_changed)
	inventory_container.add_child(inventory_list)

	# Item picker popup (still needed for "Add Item..." button behavior)
	item_picker_popup = PopupMenu.new()
	item_picker_popup.id_pressed.connect(_on_item_picker_selected)
	add_child(item_picker_popup)

	detail_panel.add_child(inventory_container)


func _add_deals_section() -> void:
	deals_container = VBoxContainer.new()

	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(deals_container)
	form.add_section_label("Deals (Discounted Items)")
	form.add_help_text("Items shown in the 'Deals' menu with discount applied")

	# Use DynamicRowList for deals management
	deals_list = DynamicRowList.new()
	deals_list.add_button_text = "Add Deal Item..."
	deals_list.add_button_tooltip = "Add an item to the deals/discount list."
	deals_list.use_scroll_container = false
	deals_list.row_factory = _create_deal_row
	deals_list.data_extractor = _extract_deal_data
	deals_list.data_changed.connect(_on_deal_data_changed)
	deals_container.add_child(deals_list)

	detail_panel.add_child(deals_container)


func _add_economy_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Economy")

	buy_multiplier_spin = form.add_float_field("Buy Multiplier:", 0.1, 2.0, 0.05, 1.0,
		"Multiplier on item buy prices. 1.0 = normal, 1.5 = 50% markup, 0.8 = 20% discount.")

	sell_multiplier_spin = form.add_float_field("Sell Multiplier:", 0.1, 2.0, 0.05, 1.0,
		"Multiplier on item sell prices. 1.0 = normal, 0.5 = pay half value, 1.2 = generous buyer.")

	deals_discount_spin = form.add_float_field("Deals Discount:", 0.1, 1.0, 0.05, 0.75,
		"Price multiplier for deal items. 0.75 = 25% off, 0.5 = half price, 1.0 = no discount.")


func _add_availability_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Availability (Story Flags)")

	required_flags_edit = form.add_text_field("Required Flags:", "e.g., chapter_2_started, rescued_princess",
		"Comma-separated story flags. ALL must be set for shop to appear. Empty = always available.")

	forbidden_flags_edit = form.add_text_field("Forbidden Flags:", "e.g., shop_destroyed",
		"Comma-separated story flags. If ANY is set, shop becomes unavailable. Use for destroyed/closed shops.")


func _add_features_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Features")

	can_sell_check = form.add_standalone_checkbox("Can Sell Items (shop buys from player)", true,
		"If enabled, players can sell their items to this shop for gold.")

	can_store_check = form.add_standalone_checkbox("Can Store to Caravan", true,
		"If enabled, players can transfer items to the Caravan storage from this shop.")

	can_sell_caravan_check = form.add_standalone_checkbox("Can Sell from Caravan Storage", true,
		"If enabled, players can sell items directly from Caravan storage without moving them first.")


func _add_church_section() -> void:
	# Church section uses a VBoxContainer directly since it's conditional (visibility toggled)
	church_section = VBoxContainer.new()
	detail_panel.add_child(church_section)

	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(church_section)
	form.on_change(_mark_dirty)
	form.add_section_label("Church Services")

	heal_cost_spin = form.add_number_field("Heal Cost:", 0, 9999, 0,
		"Gold cost to fully heal one character. 0 = free healing (classic Shining Force style).")

	revive_base_spin = form.add_number_field("Revive Base Cost:", 0, 9999, 200,
		"Base gold cost to revive a fallen character. Final cost = base + (level x multiplier).")

	revive_mult_spin = form.add_float_field("Revive Level Mult:", 0.0, 100.0, 0.5, 10.0,
		"Gold per character level added to revival cost. Example: 10 means level 20 adds 200G.")

	uncurse_cost_spin = form.add_number_field("Uncurse Cost:", 0, 9999, 500,
		"Gold cost to remove a curse from equipped item. Cursed items cannot be unequipped otherwise.")

	form.add_help_text("Example: Level 10 revival = 200 + (10 x 10) = 300 G")


func _add_crafter_section() -> void:
	# Crafter section uses a VBoxContainer directly since it's conditional (visibility toggled)
	crafter_section = VBoxContainer.new()
	detail_panel.add_child(crafter_section)

	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(crafter_section)
	form.add_section_label("Crafter Integration")

	crafter_picker = ResourcePicker.new()
	crafter_picker.resource_type = "crafter"
	crafter_picker.label_text = "Crafter:"
	crafter_picker.label_min_width = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	crafter_picker.allow_none = false
	crafter_picker.tooltip_text = "The CrafterData resource that defines available recipes. Required for Crafter-type shops."
	crafter_picker.resource_selected.connect(_on_crafter_selected)
	crafter_section.add_child(crafter_picker)


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


func _on_crafter_selected(_metadata: Dictionary) -> void:
	_mark_dirty()


## =============================================================================
## INVENTORY - DynamicRowList Factory/Extractor Pattern
## =============================================================================

## Row factory for inventory items - creates the UI for an inventory row
func _create_inventory_row(data: Dictionary, row: HBoxContainer) -> void:
	var item_id: String = data.get("item_id", "")
	var stock: int = data.get("stock", -1)
	var price_override: int = data.get("price_override", -1)

	# Item picker
	var item_picker: ResourcePicker = ResourcePicker.new()
	item_picker.name = "ItemPicker"
	item_picker.resource_type = "item"
	item_picker.allow_none = true
	item_picker.none_text = "(Select Item)"
	item_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_picker.tooltip_text = "Select an item to sell in this shop."
	row.add_child(item_picker)

	# Stock spinbox
	var stock_label: Label = Label.new()
	stock_label.text = "Stock:"
	row.add_child(stock_label)

	var stock_spin: SpinBox = SpinBox.new()
	stock_spin.name = "StockSpin"
	stock_spin.min_value = -1
	stock_spin.max_value = 999
	stock_spin.value = stock
	stock_spin.custom_minimum_size.x = 60
	stock_spin.tooltip_text = "-1 = infinite stock"
	row.add_child(stock_spin)

	# Price override spinbox
	var price_label: Label = Label.new()
	price_label.text = "Price:"
	row.add_child(price_label)

	var price_spin: SpinBox = SpinBox.new()
	price_spin.name = "PriceSpin"
	price_spin.min_value = -1
	price_spin.max_value = 999999
	price_spin.value = price_override
	price_spin.custom_minimum_size.x = 70
	price_spin.tooltip_text = "-1 = use item's buy_price"
	row.add_child(price_spin)

	# Set item if provided (deferred to ensure picker is ready)
	if not item_id.is_empty():
		var item_res: ItemData = ModLoader.registry.get_item(item_id) if ModLoader and ModLoader.registry else null
		if item_res:
			item_picker.call_deferred("select_resource", item_res)


## Data extractor for inventory items - extracts data from an inventory row
func _extract_inventory_data(row: HBoxContainer) -> Dictionary:
	var item_picker: ResourcePicker = row.get_node_or_null("ItemPicker") as ResourcePicker
	var stock_spin: SpinBox = row.get_node_or_null("StockSpin") as SpinBox
	var price_spin: SpinBox = row.get_node_or_null("PriceSpin") as SpinBox

	if not item_picker:
		return {}

	var item: ItemData = item_picker.get_selected_resource() as ItemData
	if not item:
		return {}  # Skip rows with no item selected

	var item_id: String = _get_item_id(item)
	if item_id.is_empty():
		return {}

	return {
		"item_id": item_id,
		"stock": int(stock_spin.value) if stock_spin else -1,
		"price_override": int(price_spin.value) if price_spin else -1
	}


## Called when inventory data changes via DynamicRowList
func _on_inventory_data_changed() -> void:
	_mark_dirty()


## =============================================================================
## DEALS - DynamicRowList Factory/Extractor Pattern
## =============================================================================

## Row factory for deal items - creates the UI for a deal row
func _create_deal_row(data: Dictionary, row: HBoxContainer) -> void:
	var item_id: String = data.get("item_id", "")

	# Item picker
	var item_picker: ResourcePicker = ResourcePicker.new()
	item_picker.name = "ItemPicker"
	item_picker.resource_type = "item"
	item_picker.allow_none = true
	item_picker.none_text = "(Select Item)"
	item_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_picker.tooltip_text = "Select an item for the deals/discount list."
	row.add_child(item_picker)

	# Set item if provided (deferred to ensure picker is ready)
	if not item_id.is_empty():
		var item_res: ItemData = ModLoader.registry.get_item(item_id) if ModLoader and ModLoader.registry else null
		if item_res:
			item_picker.call_deferred("select_resource", item_res)


## Data extractor for deal items - extracts data from a deal row
func _extract_deal_data(row: HBoxContainer) -> Dictionary:
	var item_picker: ResourcePicker = row.get_node_or_null("ItemPicker") as ResourcePicker

	if not item_picker:
		return {}

	var item: ItemData = item_picker.get_selected_resource() as ItemData
	if not item:
		return {}  # Skip rows with no item selected

	var item_id: String = _get_item_id(item)
	if item_id.is_empty():
		return {}

	return {"item_id": item_id}


## Called when deal data changes via DynamicRowList
func _on_deal_data_changed() -> void:
	_mark_dirty()


## =============================================================================
## LEGACY ITEM PICKER POPUP (for backward compatibility)
## =============================================================================

var _adding_to_deals: bool = false
var _picker_items: Array[Resource] = []  # Temporary for popup selection

func _on_item_picker_selected(id: int) -> void:
	if id < 0 or id >= _picker_items.size():
		return

	var item: ItemData = _picker_items[id] as ItemData
	if not item:
		return

	# Get item_id from the item
	var item_id: String = _get_item_id(item)
	if item_id.is_empty():
		return

	# This is no longer used since we switched to DynamicRowList
	# The row factory handles adding items via ResourcePicker
	pass


# =============================================================================
# HELPERS
# =============================================================================

## Override: Called when dependent resource types change (via base class)
## Refresh ResourcePickers in DynamicRowList rows when items change
func _on_dependencies_changed(_changed_type: String) -> void:
	# Refresh inventory item pickers
	if inventory_list:
		for row: HBoxContainer in inventory_list.get_all_rows():
			var item_picker: ResourcePicker = row.get_node_or_null("ItemPicker") as ResourcePicker
			if item_picker:
				item_picker.refresh()

	# Refresh deal item pickers
	if deals_list:
		for row: HBoxContainer in deals_list.get_all_rows():
			var item_picker: ResourcePicker = row.get_node_or_null("ItemPicker") as ResourcePicker
			if item_picker:
				item_picker.refresh()


func _get_item_name(item_id: String) -> String:
	# Query registry directly for item name
	if ModLoader and ModLoader.registry:
		var item: ItemData = ModLoader.registry.get_item(item_id)
		if item:
			return item.item_name
	return item_id  # Fallback to ID


func _get_item_id(item: ItemData) -> String:
	# Get ID from resource path
	if item.resource_path:
		return item.resource_path.get_file().get_basename()
	return ""


func _item_exists(item_id: String) -> bool:
	# Query registry directly
	if ModLoader and ModLoader.registry:
		return ModLoader.registry.has_resource("item", item_id)
	return false


func _parse_flags(text: String) -> Array[String]:
	var flags: Array[String] = []
	var parts: PackedStringArray = text.split(",")
	for part: String in parts:
		var trimmed: String = part.strip_edges()
		if not trimmed.is_empty():
			flags.append(trimmed)
	return flags


## Override refresh - no local cache, but refresh ResourcePickers
func refresh() -> void:
	if crafter_picker:
		crafter_picker.refresh()
	super.refresh()


## Called when name or ID changes in the NameIdFieldGroup
func _on_name_id_changed(_values: Dictionary) -> void:
	_mark_dirty()
