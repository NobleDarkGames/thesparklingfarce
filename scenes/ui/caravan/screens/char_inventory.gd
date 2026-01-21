extends "res://scenes/ui/caravan/screens/caravan_screen_base.gd"

## CharInventory - Browse character inventory and store items to depot
##
## Used in STORE mode: Shows selected character's items, allows storing to depot

## Item slot button references
var item_buttons: Array[Button] = []

## Currently selected inventory index
var selected_index: int = -1

## Character data
var character_uid: String = ""
var character_name: String = ""

@onready var header_label: Label = %HeaderLabel
@onready var item_grid: GridContainer = %ItemGrid
@onready var item_name_label: Label = %ItemNameLabel
@onready var item_desc_label: Label = %ItemDescLabel
@onready var store_button: Button = %StoreButton
@onready var store_all_button: Button = %StoreAllButton
@onready var back_button: Button = %BackButton
@onready var result_label: Label = %ResultLabel


func _on_initialized() -> void:
	# Get character from context
	if context:
		character_uid = context.selected_character_uid

	# Get character name
	var char_data: CharacterData = get_character_data(character_uid)
	if char_data:
		character_name = char_data.character_name
	else:
		character_name = character_uid

	header_label.text = "%s'S INVENTORY" % character_name.to_upper()

	_populate_inventory_grid()
	_update_details_panel(-1)

	# Connect buttons
	store_button.pressed.connect(_on_store_pressed)
	store_all_button.pressed.connect(_on_store_all_pressed)
	back_button.pressed.connect(_on_back_pressed)

	store_button.disabled = true
	result_label.text = ""


func _populate_inventory_grid() -> void:
	_clear_container(item_grid)
	item_buttons.clear()
	selected_index = -1

	var inventory: Array[String] = get_character_inventory(character_uid)
	var max_slots: int = get_max_inventory_slots()

	# Create buttons for each inventory slot
	for i: int in range(max_slots):
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(120, 40)
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_size_override("font_size", 16)

		if i < inventory.size():
			var item_id: String = inventory[i]
			var item_data: ItemData = get_item_data(item_id)
			if item_data:
				button.text = item_data.item_name
			else:
				button.text = item_id
			button.pressed.connect(_on_item_pressed.bind(i))
			button.focus_entered.connect(_on_item_focus_entered.bind(i))
		else:
			button.text = "- Empty -"
			button.disabled = true
			button.add_theme_color_override("font_color", UIColors.MENU_DISABLED)

		item_grid.add_child(button)
		item_buttons.append(button)

	# Update store all button
	var consumable_count: int = _count_consumables()
	if consumable_count > 0:
		store_all_button.text = "STORE ALL CONSUMABLES (%d)" % consumable_count
		store_all_button.disabled = false
	else:
		store_all_button.text = "STORE ALL CONSUMABLES"
		store_all_button.disabled = true

	# Focus first enabled button
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	_focus_first_enabled()


func _focus_first_enabled() -> void:
	_focus_first_in_list(item_buttons)
	# If all slots are empty, focus back button
	if item_buttons.is_empty() or item_buttons.all(func(b: Button) -> bool: return b.disabled):
		if is_instance_valid(back_button):
			back_button.grab_focus()


func _count_consumables() -> int:
	var count: int = 0
	var inventory: Array[String] = get_character_inventory(character_uid)
	for item_id: String in inventory:
		var item_data: ItemData = get_item_data(item_id)
		if item_data and item_data.item_type == ItemData.ItemType.CONSUMABLE:
			count += 1
	return count


func _on_item_focus_entered(index: int) -> void:
	_update_details_panel(index)
	play_sfx("cursor_move")


func _on_item_pressed(index: int) -> void:
	selected_index = index

	# Update visual selection
	for i: int in range(item_buttons.size()):
		var btn: Button = item_buttons[i]
		if btn.disabled:
			continue
		if i == selected_index:
			btn.add_theme_color_override("font_color", UIColors.MENU_SELECTED)
		else:
			btn.add_theme_color_override("font_color", UIColors.MENU_NORMAL)

	# Enable store button and auto-focus for consistent confirm flow
	store_button.disabled = false
	store_button.grab_focus()

	play_sfx("menu_select")


func _update_details_panel(index: int) -> void:
	if index < 0:
		item_name_label.text = "Select an item"
		item_desc_label.text = "Choose an item to store in the depot"
		return

	var inventory: Array[String] = get_character_inventory(character_uid)
	if index >= inventory.size():
		item_name_label.text = "Empty"
		item_desc_label.text = ""
		return

	var item_id: String = inventory[index]
	var item_data: ItemData = get_item_data(item_id)

	if item_data:
		item_name_label.text = item_data.item_name.to_upper()
		var desc_lines: Array[String] = []
		if not item_data.description.is_empty():
			desc_lines.append(item_data.description)
		if item_data.item_type == ItemData.ItemType.WEAPON and item_data.attack_power > 0:
			desc_lines.append("AT: %d" % item_data.attack_power)
		if item_data.defense_modifier > 0:
			desc_lines.append("DF: %d" % item_data.defense_modifier)
		item_desc_label.text = "\n".join(desc_lines) if desc_lines.size() > 0 else ""
	else:
		item_name_label.text = item_id
		item_desc_label.text = "Unknown item"


func _on_store_pressed() -> void:
	if selected_index < 0:
		return

	var inventory: Array[String] = get_character_inventory(character_uid)
	if selected_index >= inventory.size():
		return

	var item_id: String = inventory[selected_index]
	_store_item(item_id)


func _store_item(item_id: String) -> bool:
	## Store a single item from character to depot
	var save_data: CharacterSaveData = PartyManager.get_member_save_data(character_uid)
	if not save_data:
		_show_result("Character not found!", false)
		return false

	if not save_data.remove_item_from_inventory(item_id):
		_show_result("Failed to remove item!", false)
		return false

	StorageManager.add_to_depot(item_id)

	var item_data: ItemData = get_item_data(item_id)
	var item_name: String = item_data.item_name if item_data else item_id
	_show_result("%s stored!" % item_name, true)
	play_sfx("menu_confirm")

	# Refresh
	selected_index = -1
	store_button.disabled = true
	_populate_inventory_grid()

	return true


func _on_store_all_pressed() -> void:
	## Store all consumables from character to depot
	var inventory: Array[String] = get_character_inventory(character_uid)
	var items_to_store: Array[String] = []

	for item_id: String in inventory:
		var item_data: ItemData = get_item_data(item_id)
		if item_data and item_data.item_type == ItemData.ItemType.CONSUMABLE:
			items_to_store.append(item_id)

	if items_to_store.is_empty():
		_show_result("No consumables!", false)
		return

	var stored_count: int = 0
	var save_data: CharacterSaveData = PartyManager.get_member_save_data(character_uid)
	if not save_data:
		_show_result("Character not found!", false)
		return

	for item_id: String in items_to_store:
		if save_data.remove_item_from_inventory(item_id):
			StorageManager.add_to_depot(item_id)
			stored_count += 1

	if stored_count > 0:
		_show_result("Stored %d consumables!" % stored_count, true)
		play_sfx("menu_confirm")
		selected_index = -1
		store_button.disabled = true
		_populate_inventory_grid()
	else:
		_show_result("Failed to store items!", false)


func _show_result(message: String, success: bool) -> void:
	_show_result_on_label(result_label, message, success)


func _on_back_pressed() -> void:
	go_back()


func _on_screen_exit() -> void:
	if is_instance_valid(store_button) and store_button.pressed.is_connected(_on_store_pressed):
		store_button.pressed.disconnect(_on_store_pressed)
	if is_instance_valid(store_all_button) and store_all_button.pressed.is_connected(_on_store_all_pressed):
		store_all_button.pressed.disconnect(_on_store_all_pressed)
	if is_instance_valid(back_button) and back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.disconnect(_on_back_pressed)
