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

## Colors - use centralized UIColors class (unique depot colors stay local)
const COLOR_PANEL_BG: Color = Color(0.12, 0.12, 0.16, 0.98)  ## Slightly different from UIColors.PANEL_BG
const COLOR_SLOT_BG: Color = Color(0.15, 0.15, 0.2, 0.9)  ## Unique depot slot bg
const COLOR_BORDER: Color = Color(0.5, 0.5, 0.6, 1.0)  ## Unique depot border
const COLOR_DESC_BG: Color = Color(0.08, 0.08, 0.12, 0.95)  ## Unique desc panel bg
const COLOR_DESC_BORDER: Color = Color(0.4, 0.4, 0.5, 0.9)  ## Unique desc border
const ITEMS_PER_ROW: int = 5  # 5*32 + 4*4 = 176px fits in 180px scroll width
const DEFAULT_MAX_INVENTORY_SLOTS: int = 4

# =============================================================================
# PRELOADS
# =============================================================================

const ItemSlotScript = preload("res://scenes/ui/components/item_slot.gd")

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
# HELPERS
# =============================================================================

## Get max inventory slots from ModLoader config or default
func _get_max_inventory_slots() -> int:
	if ModLoader and ModLoader.inventory_config:
		return ModLoader.inventory_config.get_max_slots()
	return DEFAULT_MAX_INVENTORY_SLOTS


## Get the currently selected character's save data, or null if invalid
func _get_selected_save_data() -> CharacterSaveData:
	if _party_save_data.is_empty():
		return null
	var target_index: int = _char_dropdown.get_selected_id()
	if target_index < 0 or target_index >= _party_save_data.size():
		return null
	return _party_save_data[target_index]


## Get the currently selected character's data, or null if invalid
func _get_selected_character_data() -> CharacterData:
	if _party_character_data.is_empty():
		return null
	var target_index: int = _char_dropdown.get_selected_id()
	if target_index < 0 or target_index >= _party_character_data.size():
		return null
	return _party_character_data[target_index]


## Clear selection state on all depot slots
func _clear_depot_selection() -> void:
	for slot: Control in _depot_grid.get_children():
		slot.set_selected(false)


## Clear selection state on all inventory slots
func _clear_inventory_selection() -> void:
	for slot: Control in _inventory_grid.get_children():
		slot.set_selected(false)


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

	var panel_style: StyleBoxFlat = UIUtils.create_panel_style(COLOR_PANEL_BG, COLOR_BORDER, 1)
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
	UIUtils.apply_monogram_style(title_label, 16)
	_header_bar.add_child(title_label)

	# Spacer
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_bar.add_child(spacer)

	# Filter dropdown
	var filter_label: Label = Label.new()
	filter_label.text = "Filter:"
	UIUtils.apply_monogram_style(filter_label, 16)
	_header_bar.add_child(filter_label)

	_filter_dropdown = OptionButton.new()
	UIUtils.apply_monogram_style(_filter_dropdown, 16)
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
	UIUtils.apply_monogram_style(sort_label, 16)
	_header_bar.add_child(sort_label)

	_sort_dropdown = OptionButton.new()
	UIUtils.apply_monogram_style(_sort_dropdown, 16)
	_sort_dropdown.custom_minimum_size = Vector2(52, 16)
	_sort_dropdown.add_item("--", 0)
	_sort_dropdown.add_item("Name", 1)
	_sort_dropdown.add_item("Type", 2)
	_sort_dropdown.add_item("Value", 3)
	_sort_dropdown.item_selected.connect(_on_sort_changed)
	_header_bar.add_child(_sort_dropdown)

	_close_button = Button.new()
	_close_button.text = "X"
	UIUtils.apply_monogram_style(_close_button, 16)
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
	UIUtils.apply_monogram_style(char_label, 16)
	_side_panel.add_child(char_label)

	_char_dropdown = OptionButton.new()
	UIUtils.apply_monogram_style(_char_dropdown, 16)
	_char_dropdown.custom_minimum_size = Vector2(80, 16)
	_char_dropdown.item_selected.connect(_on_character_changed)
	_side_panel.add_child(_char_dropdown)

	# Description panel
	_description_panel = PanelContainer.new()
	_description_panel.name = "DescriptionPanel"
	_description_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var desc_style: StyleBoxFlat = UIUtils.create_panel_style(COLOR_DESC_BG, COLOR_DESC_BORDER, 1)
	desc_style.content_margin_bottom = 2
	desc_style.content_margin_left = 2
	desc_style.content_margin_right = 2
	desc_style.content_margin_top = 2
	_description_panel.add_theme_stylebox_override("panel", desc_style)
	_side_panel.add_child(_description_panel)

	_description_label = Label.new()
	UIUtils.apply_monogram_style(_description_label, 16)
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.modulate = UIColors.SECTION_HEADER
	_description_label.text = "Select an item..."
	_description_panel.add_child(_description_label)

	# Take button
	_take_button = Button.new()
	_take_button.text = "Take"
	UIUtils.apply_monogram_style(_take_button, 16)
	_take_button.custom_minimum_size = Vector2(48, 16)
	_take_button.disabled = true
	_take_button.pressed.connect(_on_take_pressed)
	_side_panel.add_child(_take_button)

	# Character inventory section
	_inventory_label = Label.new()
	_inventory_label.text = "Inventory:"
	UIUtils.apply_monogram_style(_inventory_label, 16)
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
	UIUtils.apply_monogram_style(_store_button, 16)
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
	UIUtils.apply_monogram_style(_store_all_button, 16)
	_store_all_button.custom_minimum_size = Vector2(56, 16)
	_store_all_button.pressed.connect(_on_store_all_pressed)
	bottom_bar.add_child(_store_all_button)

	# Take All (filtered) button
	_take_all_button = Button.new()
	_take_all_button.text = "Take All"
	_take_all_button.tooltip_text = "Take all items (filtered)"
	UIUtils.apply_monogram_style(_take_all_button, 16)
	_take_all_button.custom_minimum_size = Vector2(52, 16)
	_take_all_button.pressed.connect(_on_take_all_pressed)
	bottom_bar.add_child(_take_all_button)

	# Spacer
	var bottom_spacer: Control = Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_bar.add_child(bottom_spacer)

	# Item count
	_item_count_label = Label.new()
	UIUtils.apply_monogram_style(_item_count_label, 16)
	_item_count_label.modulate = UIColors.TEXT_SUBDUED
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
	var max_slots: int = _get_max_inventory_slots()
	for i: int in range(_party_character_data.size()):
		var character: CharacterData = _party_character_data[i]
		var save_data: CharacterSaveData = _party_save_data[i]
		var slots_used: int = save_data.inventory.size()
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
			var item_data: ItemData = ModLoader.registry.get_item(item_id)
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
	var a_data: ItemData = ModLoader.registry.get_item(a_id)
	var b_data: ItemData = ModLoader.registry.get_item(b_id)

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

	var save_data: CharacterSaveData = _get_selected_save_data()
	if not save_data:
		_take_button.disabled = true
		_take_button.text = "No party" if _party_save_data.is_empty() else "Take"
		return

	var is_full: bool = save_data.inventory.size() >= _get_max_inventory_slots()
	_take_button.disabled = is_full
	_take_button.text = "Full" if is_full else "Take"


# =============================================================================
# CHARACTER INVENTORY DISPLAY
# =============================================================================

func _refresh_inventory_display() -> void:
	# Clear grid first
	for child: Node in _inventory_grid.get_children():
		_inventory_grid.remove_child(child)

	var save_data: CharacterSaveData = _get_selected_save_data()
	if not save_data:
		_update_store_button()
		return

	var inventory: Array[String] = save_data.inventory
	var max_slots: int = _get_max_inventory_slots()

	# Ensure enough slots in pool
	while _inventory_slot_pool.size() < max_slots:
		var slot: Control = ItemSlotScript.new()
		# NOTE: clicked signal is connected per-slot below with index capture
		slot.hovered.connect(_on_slot_hovered)
		slot.hover_exited.connect(_on_slot_hover_exited)
		_inventory_slot_pool.append(slot)

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
	_selected_inventory_item_id = ""  # Deselect inventory item
	_selected_inventory_index = -1

	# Update selection visuals
	for slot: Control in _depot_grid.get_children():
		slot.set_selected(slot.item_id == item_id)
	_clear_inventory_selection()

	_update_take_button()
	_update_store_button()
	AudioManager.play_sfx("menu_hover", AudioManager.SFXCategory.UI)


## Handler for inventory slot clicks with index already known (fixes duplicate item bug)
func _on_inventory_slot_clicked_at_index(item_id: String, slot_index: int) -> void:
	if item_id.is_empty():
		return  # Don't select empty slots

	var save_data: CharacterSaveData = _get_selected_save_data()
	if not save_data:
		return

	# Validate the slot index
	if slot_index < 0 or slot_index >= save_data.inventory.size():
		return

	_selected_inventory_item_id = item_id
	_selected_inventory_index = slot_index
	_selected_depot_item_id = ""  # Deselect depot item

	# Update selection visuals
	_clear_depot_selection()
	for i: int in range(_inventory_grid.get_child_count()):
		var slot: Control = _inventory_grid.get_child(i) as Control
		if slot:
			slot.set_selected(i == slot_index)

	_update_take_button()
	_update_store_button()
	AudioManager.play_sfx("menu_hover", AudioManager.SFXCategory.UI)


func _on_slot_hovered(item_id: String) -> void:
	if item_id.is_empty():
		_description_label.text = "Empty"
		return

	var item_data: ItemData = ModLoader.registry.get_item(item_id)
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

	var save_data: CharacterSaveData = _get_selected_save_data()
	var character: CharacterData = _get_selected_character_data()
	if not save_data or not character:
		return

	# Remove from depot
	if not StorageManager.remove_from_depot(_selected_depot_item_id):
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		return

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


func _on_store_pressed() -> void:
	if _selected_inventory_item_id.is_empty() or _selected_inventory_index < 0:
		return

	var save_data: CharacterSaveData = _get_selected_save_data()
	var character: CharacterData = _get_selected_character_data()
	if not save_data or not character:
		return

	# Remove from character inventory (uses item_id, not index)
	if not save_data.remove_item_from_inventory(_selected_inventory_item_id):
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		_description_label.text = "Failed to remove item!"
		return

	# Add to depot
	StorageManager.add_to_depot(_selected_inventory_item_id)
	AudioManager.play_sfx("menu_confirm", AudioManager.SFXCategory.UI)
	item_stored.emit(_selected_inventory_item_id, character.character_uid)
	_description_label.text = "Item stored!"
	_selected_inventory_item_id = ""
	_selected_inventory_index = -1
	_refresh_inventory_display()
	_populate_character_dropdown()


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
	var save_data: CharacterSaveData = _get_selected_save_data()
	if not save_data:
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		return

	# Find all consumables in inventory
	var items_to_store: Array[String] = []
	for item_id: String in save_data.inventory:
		var item_data: ItemData = ModLoader.registry.get_item(item_id)
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
	var save_data: CharacterSaveData = _get_selected_save_data()
	if not save_data:
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		return

	var items_to_take: Array[String] = _get_filtered_items()
	if items_to_take.is_empty():
		_description_label.text = "Nothing to take"
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		return

	var max_slots: int = _get_max_inventory_slots()

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
