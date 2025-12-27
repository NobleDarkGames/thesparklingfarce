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
var crafter_picker: ResourcePicker

# Cached data
var _items_cache: Array[Resource] = []
var _npcs_cache: Array[Resource] = []
var _current_inventory: Array[Dictionary] = []
var _current_deals: Array[String] = []


func _ready() -> void:
	resource_type_id = "shop"
	resource_type_name = "Shop"
	# Declare dependencies BEFORE super._ready() so base class can auto-subscribe
	resource_dependencies = ["item", "npc", "crafter"]
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
		if not crafter_picker or not crafter_picker.has_selection():
			errors.append("Crafter shops require a crafter to be selected")

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
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.add_section("Basic Information")

	id_edit = form.add_text_field("Shop ID:", "e.g., my_mod_weapon_shop",
		"Unique ID for referencing this shop. Use snake_case, e.g., 'my_mod_weapon_shop'.")
	id_edit.text_changed.connect(_mark_dirty)

	name_edit = form.add_text_field("Shop Name:", "e.g., Granseal Weapon Shop",
		"Display name shown to the player in menus and when entering the shop.")
	name_edit.text_changed.connect(_mark_dirty)

	# Shop Type - custom dropdown with specific IDs
	shop_type_option = OptionButton.new()
	shop_type_option.tooltip_text = "Weapon = equipment, Item = consumables, Church = heal/revive, Crafter = forging, Special = unique."
	shop_type_option.add_item("Weapon", ShopData.ShopType.WEAPON)
	shop_type_option.add_item("Item", ShopData.ShopType.ITEM)
	shop_type_option.add_item("Church", ShopData.ShopType.CHURCH)
	shop_type_option.add_item("Crafter", ShopData.ShopType.CRAFTER)
	shop_type_option.add_item("Special", ShopData.ShopType.SPECIAL)
	shop_type_option.item_selected.connect(_on_shop_type_changed)
	form.add_labeled_control("Shop Type:", shop_type_option,
		"Weapon = equipment, Item = consumables, Church = heal/revive, Crafter = forging, Special = unique.")


func _add_presentation_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.add_section("Presentation")

	greeting_edit = form.add_text_area("Greeting Text:", 60,
		"Message displayed when player enters the shop. Multi-line supported.")
	greeting_edit.placeholder_text = "Welcome to my shop!"
	greeting_edit.text_changed.connect(_mark_dirty)

	farewell_edit = form.add_text_field("Farewell Text:", "Come again!",
		"Message displayed when player leaves the shop.")
	farewell_edit.text_changed.connect(_mark_dirty)


func _add_inventory_section() -> void:
	inventory_container = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Inventory"
	section_label.add_theme_font_size_override("font_size", 16)
	inventory_container.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Items available for purchase in this shop"
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
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
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
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
	for item_data: ItemData in _items_cache:
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
	for item_data: ItemData in _items_cache:
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
