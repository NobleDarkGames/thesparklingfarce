class_name CaravanDepotPanel
extends Control

## CaravanDepotPanel - Shared party storage UI (SF2-style Caravan Depot)
##
## Displays depot contents with:
## - Scrollable grid of stored items
## - Filter by item type
## - Take items to character inventory
## - Item descriptions on hover
##
## Works alongside PartyEquipmentMenu for full inventory management.

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when panel should close
signal close_requested()

## Emitted when item is taken from depot
signal item_taken(item_id: String, character_uid: String)

## Emitted when item is stored to depot
signal item_stored(item_id: String, character_uid: String)

# =============================================================================
# CONSTANTS
# =============================================================================

const COLOR_PANEL_BG: Color = Color(0.12, 0.12, 0.16, 0.98)
const COLOR_SLOT_BG: Color = Color(0.15, 0.15, 0.2, 0.9)
const ITEMS_PER_ROW: int = 5  # 5*32 + 4*4 = 176px fits in 180px scroll width

# =============================================================================
# PRELOADS
# =============================================================================

const ItemSlotScript: GDScript = preload("res://scenes/ui/components/item_slot.gd")
const MONOGRAM_FONT: Font = preload("res://assets/fonts/monogram.ttf")

# =============================================================================
# STATE
# =============================================================================

## Current filter type (empty = show all)
var _filter_type: String = ""

## Current sort method (none, name, type, value)
var _sort_method: String = "none"

## Currently selected item in depot
var _selected_depot_item_id: String = ""

## Currently selected item in character inventory
var _selected_inventory_item_id: String = ""

## Index of selected inventory item (for removal)
var _selected_inventory_index: int = -1

## Target character for taking items
var _target_character_index: int = 0

## Party data
var _party_save_data: Array[CharacterSaveData] = []
var _party_character_data: Array[CharacterData] = []

# =============================================================================
# UI REFERENCES
# =============================================================================

var _main_container: VBoxContainer = null
var _header_bar: HBoxContainer = null
var _filter_dropdown: OptionButton = null
var _sort_dropdown: OptionButton = null
var _close_button: Button = null
var _content_split: HBoxContainer = null
var _depot_scroll: ScrollContainer = null
var _depot_grid: GridContainer = null
var _side_panel: VBoxContainer = null
var _char_dropdown: OptionButton = null
var _description_panel: PanelContainer = null
var _description_label: Label = null
var _take_button: Button = null
var _inventory_label: Label = null
var _inventory_grid: GridContainer = null
var _store_button: Button = null
var _store_all_button: Button = null
var _take_all_button: Button = null
var _item_count_label: Label = null

## Pool of ItemSlot nodes for depot display
var _slot_pool: Array[Control] = []

## Pool of ItemSlot nodes for character inventory display
var _inventory_slot_pool: Array[Control] = []

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_build_ui()
	_refresh_party_data()
	_populate_character_dropdown()
	_refresh_depot_display()
	_refresh_inventory_display()

	# Connect to StorageManager signals (guard for test environments)
	if StorageManager:
		StorageManager.depot_changed.connect(_on_depot_changed)


func _exit_tree() -> void:
	if StorageManager and StorageManager.depot_changed.is_connected(_on_depot_changed):
		StorageManager.depot_changed.disconnect(_on_depot_changed)


func _build_ui() -> void:
	# Full screen semi-transparent background
	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.0, 0.0, 0.0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Main panel (centered) - sized for 640x360 viewport
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "MainPanel"
	panel.custom_minimum_size = Vector2(300, 280)
	panel.size = panel.custom_minimum_size
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = COLOR_PANEL_BG
	panel_style.border_width_bottom = 1
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_color = Color(0.5, 0.5, 0.6, 1.0)
	panel_style.content_margin_bottom = 4
	panel_style.content_margin_left = 4
	panel_style.content_margin_right = 4
	panel_style.content_margin_top = 4
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	# Main VBox layout
	_main_container = VBoxContainer.new()
	_main_container.name = "MainVBox"
	_main_container.add_theme_constant_override("separation", 2)
	panel.add_child(_main_container)

	# Header bar
	_header_bar = HBoxContainer.new()
	_header_bar.name = "HeaderBar"
	_header_bar.add_theme_constant_override("separation", 4)
	_main_container.add_child(_header_bar)

	var title_label: Label = Label.new()
	title_label.text = "CARAVAN DEPOT"
	title_label.add_theme_font_override("font", MONOGRAM_FONT)
	title_label.add_theme_font_size_override("font_size", 16)
	_header_bar.add_child(title_label)

	# Spacer
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_bar.add_child(spacer)

	# Filter dropdown
	var filter_label: Label = Label.new()
	filter_label.text = "Filter:"
	filter_label.add_theme_font_override("font", MONOGRAM_FONT)
	filter_label.add_theme_font_size_override("font_size", 16)
	_header_bar.add_child(filter_label)

	_filter_dropdown = OptionButton.new()
	_filter_dropdown.add_theme_font_override("font", MONOGRAM_FONT)
	_filter_dropdown.add_theme_font_size_override("font_size", 16)
	_filter_dropdown.custom_minimum_size = Vector2(64, 16)
	_filter_dropdown.add_item("All", 0)
	_filter_dropdown.add_item("Weapons", 1)
	_filter_dropdown.add_item("Armor", 2)
	_filter_dropdown.add_item("Accessories", 3)
	_filter_dropdown.add_item("Consumables", 4)
	_filter_dropdown.item_selected.connect(_on_filter_changed)
	_header_bar.add_child(_filter_dropdown)

	# Sort dropdown
	var sort_label: Label = Label.new()
	sort_label.text = "Sort:"
	sort_label.add_theme_font_override("font", MONOGRAM_FONT)
	sort_label.add_theme_font_size_override("font_size", 16)
	_header_bar.add_child(sort_label)

	_sort_dropdown = OptionButton.new()
	_sort_dropdown.add_theme_font_override("font", MONOGRAM_FONT)
	_sort_dropdown.add_theme_font_size_override("font_size", 16)
	_sort_dropdown.custom_minimum_size = Vector2(52, 16)
	_sort_dropdown.add_item("--", 0)
	_sort_dropdown.add_item("Name", 1)
	_sort_dropdown.add_item("Type", 2)
	_sort_dropdown.add_item("Value", 3)
	_sort_dropdown.item_selected.connect(_on_sort_changed)
	_header_bar.add_child(_sort_dropdown)

	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.add_theme_font_override("font", MONOGRAM_FONT)
	_close_button.add_theme_font_size_override("font_size", 16)
	_close_button.custom_minimum_size = Vector2(16, 16)
	_close_button.pressed.connect(_on_close_pressed)
	_header_bar.add_child(_close_button)

	# Content split (depot grid + side panel)
	_content_split = HBoxContainer.new()
	_content_split.name = "ContentSplit"
	_content_split.add_theme_constant_override("separation", 4)
	_content_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_container.add_child(_content_split)

	# Depot scroll container
	_depot_scroll = ScrollContainer.new()
	_depot_scroll.name = "DepotScroll"
	_depot_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_depot_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_depot_scroll.custom_minimum_size = Vector2(180, 120)
	_content_split.add_child(_depot_scroll)

	# Depot grid
	_depot_grid = GridContainer.new()
	_depot_grid.name = "DepotGrid"
	_depot_grid.columns = ITEMS_PER_ROW
	_depot_grid.add_theme_constant_override("h_separation", 4)
	_depot_grid.add_theme_constant_override("v_separation", 4)
	_depot_scroll.add_child(_depot_grid)

	# Side panel
	_side_panel = VBoxContainer.new()
	_side_panel.name = "SidePanel"
	_side_panel.add_theme_constant_override("separation", 2)
	_side_panel.custom_minimum_size = Vector2(90, 0)
	_content_split.add_child(_side_panel)

	# Character dropdown
	var char_label: Label = Label.new()
	char_label.text = "Give to:"
	char_label.add_theme_font_override("font", MONOGRAM_FONT)
	char_label.add_theme_font_size_override("font_size", 16)
	_side_panel.add_child(char_label)

	_char_dropdown = OptionButton.new()
	_char_dropdown.add_theme_font_override("font", MONOGRAM_FONT)
	_char_dropdown.add_theme_font_size_override("font_size", 16)
	_char_dropdown.custom_minimum_size = Vector2(80, 16)
	_char_dropdown.item_selected.connect(_on_character_changed)
	_side_panel.add_child(_char_dropdown)

	# Description panel
	_description_panel = PanelContainer.new()
	_description_panel.name = "DescriptionPanel"
	_description_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var desc_style: StyleBoxFlat = StyleBoxFlat.new()
	desc_style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	desc_style.border_width_bottom = 1
	desc_style.border_width_left = 1
	desc_style.border_width_right = 1
	desc_style.border_width_top = 1
	desc_style.border_color = Color(0.4, 0.4, 0.5, 0.9)
	desc_style.content_margin_bottom = 2
	desc_style.content_margin_left = 2
	desc_style.content_margin_right = 2
	desc_style.content_margin_top = 2
	_description_panel.add_theme_stylebox_override("panel", desc_style)
	_side_panel.add_child(_description_panel)

	_description_label = Label.new()
	_description_label.add_theme_font_override("font", MONOGRAM_FONT)
	_description_label.add_theme_font_size_override("font_size", 16)
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.modulate = Color(0.7, 0.7, 0.8, 1.0)
	_description_label.text = "Select an item..."
	_description_panel.add_child(_description_label)

	# Take button
	_take_button = Button.new()
	_take_button.text = "Take"
	_take_button.add_theme_font_override("font", MONOGRAM_FONT)
	_take_button.add_theme_font_size_override("font_size", 16)
	_take_button.custom_minimum_size = Vector2(48, 16)
	_take_button.disabled = true
	_take_button.pressed.connect(_on_take_pressed)
	_side_panel.add_child(_take_button)

	# Character inventory section
	_inventory_label = Label.new()
	_inventory_label.text = "Inventory:"
	_inventory_label.add_theme_font_override("font", MONOGRAM_FONT)
	_inventory_label.add_theme_font_size_override("font_size", 16)
	_side_panel.add_child(_inventory_label)

	# Inventory grid (2x2 layout to fit in side panel)
	_inventory_grid = GridContainer.new()
	_inventory_grid.name = "InventoryGrid"
	_inventory_grid.columns = 2
	_inventory_grid.add_theme_constant_override("h_separation", 2)
	_inventory_grid.add_theme_constant_override("v_separation", 2)
	_side_panel.add_child(_inventory_grid)

	# Store button
	_store_button = Button.new()
	_store_button.text = "Store"
	_store_button.add_theme_font_override("font", MONOGRAM_FONT)
	_store_button.add_theme_font_size_override("font_size", 16)
	_store_button.custom_minimum_size = Vector2(48, 16)
	_store_button.disabled = true
	_store_button.pressed.connect(_on_store_pressed)
	_side_panel.add_child(_store_button)

	# Bottom bar with batch operations and item count
	var bottom_bar: HBoxContainer = HBoxContainer.new()
	bottom_bar.add_theme_constant_override("separation", 8)
	_main_container.add_child(bottom_bar)

	# Store All Consumables button
	_store_all_button = Button.new()
	_store_all_button.text = "Store All"
	_store_all_button.tooltip_text = "Store all consumables from party"
	_store_all_button.add_theme_font_override("font", MONOGRAM_FONT)
	_store_all_button.add_theme_font_size_override("font_size", 16)
	_store_all_button.custom_minimum_size = Vector2(56, 16)
	_store_all_button.pressed.connect(_on_store_all_pressed)
	bottom_bar.add_child(_store_all_button)

	# Take All (filtered) button
	_take_all_button = Button.new()
	_take_all_button.text = "Take All"
	_take_all_button.tooltip_text = "Take all items (filtered)"
	_take_all_button.add_theme_font_override("font", MONOGRAM_FONT)
	_take_all_button.add_theme_font_size_override("font_size", 16)
	_take_all_button.custom_minimum_size = Vector2(52, 16)
	_take_all_button.pressed.connect(_on_take_all_pressed)
	bottom_bar.add_child(_take_all_button)

	# Spacer
	var bottom_spacer: Control = Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_bar.add_child(bottom_spacer)

	# Item count
	_item_count_label = Label.new()
	_item_count_label.add_theme_font_override("font", MONOGRAM_FONT)
	_item_count_label.add_theme_font_size_override("font_size", 16)
	_item_count_label.modulate = Color(0.5, 0.5, 0.6, 1.0)
	_item_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom_bar.add_child(_item_count_label)


# =============================================================================
# PARTY DATA
# =============================================================================

func _refresh_party_data() -> void:
	_party_save_data.clear()
	_party_character_data.clear()

	for character: CharacterData in PartyManager.party_members:
		var uid: String = character.character_uid
		var save_data: CharacterSaveData = PartyManager.get_member_save_data(uid)
		if save_data:
			_party_save_data.append(save_data)
			_party_character_data.append(character)


func _populate_character_dropdown() -> void:
	_char_dropdown.clear()
	for i: int in range(_party_character_data.size()):
		var character: CharacterData = _party_character_data[i]
		var save_data: CharacterSaveData = _party_save_data[i]
		var slots_used: int = save_data.inventory.size()
		var max_slots: int = 4
		if ModLoader and ModLoader.inventory_config:
			max_slots = ModLoader.inventory_config.get_max_slots()
		_char_dropdown.add_item("%s (%d/%d)" % [character.character_name, slots_used, max_slots], i)


# =============================================================================
# DEPOT DISPLAY
# =============================================================================

func _refresh_depot_display() -> void:
	if not StorageManager:
		_item_count_label.text = "Depot unavailable"
		return

	# Get filtered depot contents
	var items: Array[String] = _get_filtered_items()

	# Update item count
	var total: int = StorageManager.get_depot_size()
	var filtered: int = items.size()
	if _filter_type.is_empty():
		_item_count_label.text = "%d items in depot" % total
	else:
		_item_count_label.text = "%d/%d items (filtered)" % [filtered, total]

	# Ensure enough slots in pool
	while _slot_pool.size() < items.size():
		var slot: Control = ItemSlotScript.new()
		slot.clicked.connect(_on_slot_clicked)
		slot.hovered.connect(_on_slot_hovered)
		slot.hover_exited.connect(_on_slot_hover_exited)
		_slot_pool.append(slot)

	# Clear grid
	for child: Node in _depot_grid.get_children():
		_depot_grid.remove_child(child)

	# Add slots for items
	for i: int in range(items.size()):
		var item_id: String = items[i]
		var slot: Control = _slot_pool[i]
		slot.set_item(item_id, false)
		slot.set_selected(item_id == _selected_depot_item_id)
		_depot_grid.add_child(slot)

	# Update take button state
	_update_take_button()


func _get_filtered_items() -> Array[String]:
	var all_items: Array[String] = StorageManager.get_depot_contents()
	var result: Array[String] = []

	# Apply filter
	if _filter_type.is_empty():
		result = all_items.duplicate()
	else:
		for item_id: String in all_items:
			var item_data: ItemData = ModLoader.registry.get_resource("item", item_id) as ItemData
			if item_data:
				var type_name: String = ItemData.ItemType.keys()[item_data.item_type].to_lower()
				if type_name == _filter_type:
					result.append(item_id)

	# Apply sort
	if _sort_method != "none" and result.size() > 1:
		result.sort_custom(_sort_items)

	return result


## Comparison function for sorting items
func _sort_items(a_id: String, b_id: String) -> bool:
	var a_data: ItemData = ModLoader.registry.get_resource("item", a_id) as ItemData
	var b_data: ItemData = ModLoader.registry.get_resource("item", b_id) as ItemData

	# Handle missing data
	if not a_data:
		return false
	if not b_data:
		return true

	match _sort_method:
		"name":
			return a_data.item_name.to_lower() < b_data.item_name.to_lower()
		"type":
			# Sort by type, then name within type
			if a_data.item_type != b_data.item_type:
				return a_data.item_type < b_data.item_type
			return a_data.item_name.to_lower() < b_data.item_name.to_lower()
		"value":
			# Sort by value descending (most valuable first), then name
			if a_data.buy_price != b_data.buy_price:
				return a_data.buy_price > b_data.buy_price
			return a_data.item_name.to_lower() < b_data.item_name.to_lower()
		_:
			return false


func _update_take_button() -> void:
	if _selected_depot_item_id.is_empty():
		_take_button.disabled = true
		_take_button.text = "Take"
		return

	if _party_save_data.is_empty():
		_take_button.disabled = true
		_take_button.text = "No party"
		return

	var target_index: int = _char_dropdown.get_selected_id()
	if target_index < 0 or target_index >= _party_save_data.size():
		_take_button.disabled = true
		return

	var save_data: CharacterSaveData = _party_save_data[target_index]
	var max_slots: int = 4
	if ModLoader and ModLoader.inventory_config:
		max_slots = ModLoader.inventory_config.get_max_slots()

	if save_data.inventory.size() >= max_slots:
		_take_button.disabled = true
		_take_button.text = "Full"
	else:
		_take_button.disabled = false
		_take_button.text = "Take"


# =============================================================================
# CHARACTER INVENTORY DISPLAY
# =============================================================================

func _refresh_inventory_display() -> void:
	if _party_save_data.is_empty():
		# Clear grid
		for child: Node in _inventory_grid.get_children():
			_inventory_grid.remove_child(child)
		_update_store_button()
		return

	var target_index: int = _char_dropdown.get_selected_id()
	if target_index < 0 or target_index >= _party_save_data.size():
		return

	var save_data: CharacterSaveData = _party_save_data[target_index]
	var inventory: Array[String] = save_data.inventory

	# Ensure enough slots in pool
	var max_slots: int = 4
	if ModLoader and ModLoader.inventory_config:
		max_slots = ModLoader.inventory_config.get_max_slots()

	while _inventory_slot_pool.size() < max_slots:
		var slot: Control = ItemSlotScript.new()
		# NOTE: clicked signal is connected per-slot below with index capture
		slot.hovered.connect(_on_slot_hovered)
		slot.hover_exited.connect(_on_slot_hover_exited)
		_inventory_slot_pool.append(slot)

	# Clear grid
	for child: Node in _inventory_grid.get_children():
		_inventory_grid.remove_child(child)

	# Add slots for inventory items (show empty slots too)
	for i: int in range(max_slots):
		var slot: Control = _inventory_slot_pool[i]

		# Disconnect old clicked connection and reconnect with current index
		if slot.clicked.is_connected(_on_inventory_slot_clicked_at_index):
			slot.clicked.disconnect(_on_inventory_slot_clicked_at_index)
		var slot_index: int = i  # Capture index
		slot.clicked.connect(_on_inventory_slot_clicked_at_index.bind(slot_index))

		if i < inventory.size():
			var item_id: String = inventory[i]
			slot.set_item(item_id, false)
			slot.set_selected(i == _selected_inventory_index)
		else:
			slot.set_item("", false)
			slot.set_selected(false)
		_inventory_grid.add_child(slot)

	_update_store_button()


func _update_store_button() -> void:
	if _selected_inventory_item_id.is_empty():
		_store_button.disabled = true
		_store_button.text = "Store"
		return

	_store_button.disabled = false
	_store_button.text = "Store"


# =============================================================================
# EVENT HANDLERS
# =============================================================================

func _on_depot_changed() -> void:
	_refresh_party_data()
	_refresh_depot_display()
	_populate_character_dropdown()
	_refresh_inventory_display()


func _on_filter_changed(index: int) -> void:
	match index:
		0: _filter_type = ""
		1: _filter_type = "weapon"
		2: _filter_type = "armor"
		3: _filter_type = "accessory"
		4: _filter_type = "consumable"

	_selected_depot_item_id = ""
	_refresh_depot_display()
	AudioManager.play_sfx("menu_hover", AudioManager.SFXCategory.UI)


func _on_sort_changed(index: int) -> void:
	match index:
		0: _sort_method = "none"
		1: _sort_method = "name"
		2: _sort_method = "type"
		3: _sort_method = "value"

	_refresh_depot_display()
	AudioManager.play_sfx("menu_hover", AudioManager.SFXCategory.UI)


func _on_slot_clicked(item_id: String) -> void:
	_selected_depot_item_id = item_id
	# Deselect inventory item when depot item is selected
	_selected_inventory_item_id = ""
	_selected_inventory_index = -1

	# Update selection visuals
	for slot: Control in _depot_grid.get_children():
		slot.set_selected(slot.item_id == item_id)
	for slot: Control in _inventory_grid.get_children():
		slot.set_selected(false)

	_update_take_button()
	_update_store_button()
	AudioManager.play_sfx("menu_hover", AudioManager.SFXCategory.UI)


## Handler for inventory slot clicks with index already known (fixes duplicate item bug)
func _on_inventory_slot_clicked_at_index(item_id: String, slot_index: int) -> void:
	if item_id.is_empty():
		return  # Don't select empty slots

	# Validate the character selection
	var target_index: int = _char_dropdown.get_selected_id()
	if target_index < 0 or target_index >= _party_save_data.size():
		return

	var save_data: CharacterSaveData = _party_save_data[target_index]
	var inventory: Array[String] = save_data.inventory

	# Validate the slot index
	if slot_index < 0 or slot_index >= inventory.size():
		return

	_selected_inventory_item_id = item_id
	_selected_inventory_index = slot_index
	# Deselect depot item when inventory item is selected
	_selected_depot_item_id = ""

	# Update selection visuals
	for slot: Control in _depot_grid.get_children():
		slot.set_selected(false)
	for i: int in range(_inventory_grid.get_child_count()):
		var child: Node = _inventory_grid.get_child(i)
		var slot: Control = child if child is Control else null
		if slot:
			slot.set_selected(i == slot_index)

	_update_take_button()
	_update_store_button()
	AudioManager.play_sfx("menu_hover", AudioManager.SFXCategory.UI)


func _on_slot_hovered(item_id: String) -> void:
	if item_id.is_empty():
		_description_label.text = "Empty"
		return

	var item_data: ItemData = ModLoader.registry.get_resource("item", item_id) as ItemData
	if item_data:
		var desc: String = item_data.item_name
		if not item_data.description.is_empty():
			desc += "\n" + item_data.description
		_description_label.text = desc
	else:
		_description_label.text = "Unknown: " + item_id


func _on_slot_hover_exited() -> void:
	if _selected_depot_item_id.is_empty():
		_description_label.text = "Select an item..."
	else:
		_on_slot_hovered(_selected_depot_item_id)


func _on_take_pressed() -> void:
	if _selected_depot_item_id.is_empty():
		return

	var target_index: int = _char_dropdown.get_selected_id()
	if target_index < 0 or target_index >= _party_save_data.size():
		return

	var save_data: CharacterSaveData = _party_save_data[target_index]
	var character: CharacterData = _party_character_data[target_index]

	# Remove from depot
	if StorageManager.remove_from_depot(_selected_depot_item_id):
		# Add to character inventory
		if save_data.add_item_to_inventory(_selected_depot_item_id):
			AudioManager.play_sfx("menu_confirm", AudioManager.SFXCategory.UI)
			item_taken.emit(_selected_depot_item_id, character.character_uid)
			_selected_depot_item_id = ""
			_description_label.text = "Item taken!"
			_refresh_inventory_display()
		else:
			# Rollback - put back in depot
			StorageManager.add_to_depot(_selected_depot_item_id)
			AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
			_description_label.text = "Inventory full!"
	else:
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)


func _on_store_pressed() -> void:
	if _selected_inventory_item_id.is_empty() or _selected_inventory_index < 0:
		return

	var target_index: int = _char_dropdown.get_selected_id()
	if target_index < 0 or target_index >= _party_save_data.size():
		return

	var save_data: CharacterSaveData = _party_save_data[target_index]
	var character: CharacterData = _party_character_data[target_index]

	# Remove from character inventory (uses item_id, not index)
	if save_data.remove_item_from_inventory(_selected_inventory_item_id):
		# Add to depot
		StorageManager.add_to_depot(_selected_inventory_item_id)
		AudioManager.play_sfx("menu_confirm", AudioManager.SFXCategory.UI)
		item_stored.emit(_selected_inventory_item_id, character.character_uid)
		_description_label.text = "Item stored!"
		_selected_inventory_item_id = ""
		_selected_inventory_index = -1
		_refresh_inventory_display()
		_populate_character_dropdown()
	else:
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		_description_label.text = "Failed to remove item!"


func _on_character_changed(_index: int) -> void:
	# Reset selections when character changes
	_selected_inventory_item_id = ""
	_selected_inventory_index = -1
	_refresh_inventory_display()
	_update_take_button()
	AudioManager.play_sfx("menu_hover", AudioManager.SFXCategory.UI)


func _on_close_pressed() -> void:
	close_requested.emit()
	AudioManager.play_sfx("menu_cancel", AudioManager.SFXCategory.UI)


func _on_store_all_pressed() -> void:
	## Store all consumables from the selected character's inventory
	if _party_save_data.is_empty():
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		return

	var target_index: int = _char_dropdown.get_selected_id()
	if target_index < 0 or target_index >= _party_save_data.size():
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		return

	var save_data: CharacterSaveData = _party_save_data[target_index]
	var items_to_store: Array[String] = []

	# Find all consumables in inventory
	for item_id: String in save_data.inventory:
		var item_data: ItemData = ModLoader.registry.get_resource("item", item_id) as ItemData
		if item_data and item_data.item_type == ItemData.ItemType.CONSUMABLE:
			items_to_store.append(item_id)

	if items_to_store.is_empty():
		_description_label.text = "No consumables"
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		return

	# Store each consumable
	var stored_count: int = 0
	for item_id: String in items_to_store:
		if save_data.remove_item_from_inventory(item_id):
			StorageManager.add_to_depot(item_id)
			stored_count += 1

	if stored_count > 0:
		_description_label.text = "Stored %d items" % stored_count
		AudioManager.play_sfx("menu_confirm", AudioManager.SFXCategory.UI)
		_refresh_inventory_display()
		_populate_character_dropdown()
	else:
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)


func _on_take_all_pressed() -> void:
	## Take all filtered items from depot (as many as will fit)
	if _party_save_data.is_empty():
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		return

	var target_index: int = _char_dropdown.get_selected_id()
	if target_index < 0 or target_index >= _party_save_data.size():
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		return

	var save_data: CharacterSaveData = _party_save_data[target_index]
	var max_slots: int = 4
	if ModLoader and ModLoader.inventory_config:
		max_slots = ModLoader.inventory_config.get_max_slots()

	var items_to_take: Array[String] = _get_filtered_items()
	if items_to_take.is_empty():
		_description_label.text = "Nothing to take"
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		return

	# Take items until inventory is full
	var taken_count: int = 0
	for item_id: String in items_to_take:
		if save_data.inventory.size() >= max_slots:
			break  # Inventory full

		if StorageManager.remove_from_depot(item_id):
			if save_data.add_item_to_inventory(item_id):
				taken_count += 1
			else:
				# Rollback
				StorageManager.add_to_depot(item_id)
				break

	if taken_count > 0:
		_description_label.text = "Took %d items" % taken_count
		AudioManager.play_sfx("menu_confirm", AudioManager.SFXCategory.UI)
		_selected_depot_item_id = ""
		_refresh_inventory_display()
		_populate_character_dropdown()
	else:
		_description_label.text = "Inventory full"
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)


# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("sf_cancel"):
		close_requested.emit()
		AudioManager.play_sfx("menu_cancel", AudioManager.SFXCategory.UI)
		get_viewport().set_input_as_handled()


# =============================================================================
# PUBLIC API
# =============================================================================

## Refresh display with current depot contents
func refresh() -> void:
	_refresh_party_data()
	_populate_character_dropdown()
	_refresh_depot_display()
	_refresh_inventory_display()
