extends "res://scenes/ui/members/screens/members_screen_base.gd"

## CharacterDetailBase - Shared base class for character equipment/inventory screens
##
## Contains all common logic for:
## - Equipment list building and handling
## - Inventory list building and handling
## - Item action menu integration
## - Details panel updates
## - Result display
##
## Subclasses override:
## - _get_action_menu_context() -> int - Which ItemActionMenu.Context to use
## - _supports_character_cycling() -> bool - Whether L/R cycling is enabled
## - _on_initialized() - Screen-specific setup (call super._on_initialized_base())
## - _get_refresh_method_name() -> String - Name of refresh method for cycling

# =============================================================================
# STATE
# =============================================================================

## Current character identifiers
var character_uid: String = ""
var character_name: String = ""

## Equipment button references keyed by slot_id
var equipment_buttons: Dictionary[String, Button] = {}

## Inventory button references
var inventory_buttons: Array[Button] = []

## Currently focused slot/item for context
var focused_slot_id: String = ""
var focused_inventory_index: int = -1
var focused_item_id: String = ""

## Selected style for visual feedback
var _selected_style: StyleBoxFlat

## ItemActionMenu instance (shared for both inventory and equipment actions)
var _item_action_menu: Control = null

# =============================================================================
# UI REFERENCES (must be set by subclass via %NodeName)
# =============================================================================

var header_label: Label
var stats_label: Label
var cycle_hint_label: Label
var equipment_list: VBoxContainer
var inventory_list: VBoxContainer
var details_panel: PanelContainer
var item_name_label: Label
var item_desc_label: Label
var result_label: Label
var back_button: Button


# =============================================================================
# ABSTRACT METHODS (override in subclasses)
# =============================================================================

## Return the ItemActionMenu.Context enum value for inventory items
func _get_action_menu_context() -> int:
	# Default: EXPLORATION (value 1)
	return 1


## Return whether this screen supports L/R character cycling
func _supports_character_cycling() -> bool:
	return false


## Called after base initialization - override for screen-specific setup
func _on_subclass_initialized() -> void:
	pass


# =============================================================================
# BASE INITIALIZATION
# =============================================================================

func _on_initialized_base() -> void:
	_create_styles()
	_create_popups()

	# Get current character from context
	character_uid = get_current_member_uid()
	_refresh_character_display()

	# Connect back button
	back_button.pressed.connect(_on_back_pressed)
	back_button.focus_entered.connect(_on_back_focus_entered)


func _create_styles() -> void:
	_selected_style = UIUtils.create_panel_style(Color(0.3, 0.5, 0.8, 1.0), Color.TRANSPARENT, 0, 2)


func _create_popups() -> void:
	# Create ItemActionMenu (shared for both inventory and equipment actions)
	var ItemActionMenuClass: GDScript = load("res://scenes/ui/item_action_menu.gd") as GDScript
	_item_action_menu = ItemActionMenuClass.new()
	_item_action_menu.name = "ItemActionMenu"
	_item_action_menu.action_selected.connect(_on_item_action_selected)
	_item_action_menu.menu_cancelled.connect(_on_item_action_cancelled)
	add_child(_item_action_menu)


# =============================================================================
# REFRESH / REBUILD
# =============================================================================

func _refresh_character_display() -> void:
	character_uid = get_current_member_uid()

	var char_data: CharacterData = get_character_by_uid(character_uid)
	var save_data: CharacterSaveData = get_character_save_data(character_uid)

	if char_data:
		character_name = char_data.character_name
	else:
		character_name = character_uid

	# Update header
	header_label.text = character_name.to_upper()

	# Update stats (HP/MP/Level/Class)
	if save_data:
		var class_data: ClassData = save_data.get_current_class(char_data)
		var class_display: String = class_data.display_name if class_data else save_data.fallback_class_name
		stats_label.text = "Lv%d %s  HP: %d/%d  MP: %d/%d" % [
			save_data.level,
			class_display,
			save_data.current_hp, save_data.max_hp,
			save_data.current_mp, save_data.max_mp
		]
	else:
		stats_label.text = ""

	# Update cycle hint based on whether cycling is supported
	_update_cycle_hint()

	# Rebuild button lists
	_rebuild_equipment_list()
	_rebuild_inventory_list()

	# Clear details and result
	_update_details_panel("", "")
	result_label.text = ""

	# Focus first equipment button
	_focus_first_button()


func _update_cycle_hint() -> void:
	var can_cycle: bool = _supports_character_cycling() and get_party_size() > 1
	cycle_hint_label.text = "L/R: Switch | A: Select | B: Back" if can_cycle else "A: Select | B: Back"
	cycle_hint_label.visible = true


func _create_list_button(height: int = 26) -> Button:
	## Helper to create a styled list button
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(0, height)
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 16)
	return button


func _rebuild_equipment_list() -> void:
	# Clear existing
	for child: Node in equipment_list.get_children():
		child.queue_free()
	equipment_buttons.clear()

	var save_data: CharacterSaveData = get_character_save_data(character_uid)
	if not save_data:
		return

	# Get equipment slots from registry
	var slot_layout: Array[Dictionary] = ModLoader.equipment_slot_registry.get_slots()

	for slot_def: Dictionary in slot_layout:
		var slot_id: String = DictUtils.get_string(slot_def, "id", "")
		var display_name: String = DictUtils.get_string(slot_def, "display_name", slot_id.capitalize())
		if slot_id.is_empty():
			continue

		# Get equipped item for this slot
		var item_id: String = EquipmentManager.get_equipped_item_id(save_data, slot_id)
		var is_cursed: bool = EquipmentManager.is_slot_cursed(save_data, slot_id)

		var button: Button = _create_list_button(26)

		# Format text: "Weapon: Bronze Sword" or "Weapon: (empty)"
		if item_id.is_empty():
			button.text = "%s: (empty)" % display_name
			button.add_theme_color_override("font_color", UIColors.ITEM_EMPTY)
		else:
			var item_data: ItemData = get_item_data(item_id)
			var item_name: String = item_data.item_name if item_data else item_id
			button.text = "%s: %s" % [display_name, item_name]
			if is_cursed:
				button.add_theme_color_override("font_color", UIColors.ITEM_CURSED)
				button.text += " [CURSED]"

		equipment_list.add_child(button)
		equipment_buttons[slot_id] = button

		# Connect signals with captured slot_id
		button.pressed.connect(_on_equipment_button_pressed.bind(slot_id, item_id))
		button.focus_entered.connect(_on_equipment_focus_entered.bind(slot_id, item_id))


func _create_info_label(text: String, color: Color) -> Label:
	## Helper to create a styled info label
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 16)
	return label


func _rebuild_inventory_list() -> void:
	# Clear existing
	for child: Node in inventory_list.get_children():
		child.queue_free()
	inventory_buttons.clear()

	var save_data: CharacterSaveData = get_character_save_data(character_uid)
	if not save_data:
		return

	var max_slots: int = get_max_inventory_slots()

	# Add buttons for each inventory item
	for i: int in range(save_data.inventory.size()):
		var item_id: String = save_data.inventory[i]
		var item_data: ItemData = get_item_data(item_id)

		var button: Button = _create_list_button(24)

		if item_data:
			button.text = item_data.item_name
		else:
			button.text = item_id
			button.add_theme_color_override("font_color", UIColors.MENU_DISABLED)

		inventory_list.add_child(button)
		inventory_buttons.append(button)

		# Connect signals with captured index
		button.pressed.connect(_on_inventory_button_pressed.bind(i, item_id))
		button.focus_entered.connect(_on_inventory_focus_entered.bind(i, item_id))

	# Show empty slot indicator if inventory has room
	var empty_slots: int = max_slots - save_data.inventory.size()
	if empty_slots > 0:
		var plural: String = "s" if empty_slots > 1 else ""
		inventory_list.add_child(_create_info_label("(%d empty slot%s)" % [empty_slots, plural], UIColors.ITEM_EMPTY))

	# Handle completely empty inventory
	if save_data.inventory.is_empty():
		inventory_list.add_child(_create_info_label("No items", UIColors.MENU_DISABLED))


func _focus_first_button() -> void:
	# Defer to ensure buttons are ready
	await get_tree().process_frame
	if not is_instance_valid(self):
		return

	# Try equipment buttons first
	for slot_id: String in equipment_buttons.keys():
		var button: Button = equipment_buttons.get(slot_id)
		if is_instance_valid(button):
			button.grab_focus()
			return

	# Then inventory buttons
	if inventory_buttons.size() > 0 and is_instance_valid(inventory_buttons[0]):
		inventory_buttons[0].grab_focus()
		return

	# Finally back button
	if is_instance_valid(back_button):
		back_button.grab_focus()


# =============================================================================
# EQUIPMENT HANDLING
# =============================================================================

func _on_equipment_focus_entered(slot_id: String, item_id: String) -> void:
	focused_slot_id = slot_id
	focused_inventory_index = -1
	focused_item_id = item_id

	if item_id.is_empty():
		var display_name: String = ModLoader.equipment_slot_registry.get_slot_display_name(slot_id)
		_update_details_panel(display_name, "No item equipped")
	else:
		_update_item_details(item_id)

	play_sfx("cursor_move")


func _on_equipment_button_pressed(slot_id: String, item_id: String) -> void:
	if item_id.is_empty():
		# Empty slot - could show "Equip from inventory" flow, for now just beep
		_show_result("No item to unequip", false)
		return

	# Check if cursed
	var save_data: CharacterSaveData = get_character_save_data(character_uid)
	if save_data and EquipmentManager.is_slot_cursed(save_data, slot_id):
		_show_result("This item is cursed!", false)
		return

	# Show ItemActionMenu with EQUIPMENT_SLOT context near the button
	focused_slot_id = slot_id
	focused_item_id = item_id
	var button: Button = equipment_buttons.get(slot_id)
	if button:
		var button_rect: Rect2 = button.get_global_rect()
		var menu_pos: Vector2 = Vector2(button_rect.end.x + 4, button_rect.position.y)
		# Use EQUIPMENT_SLOT context (value 2 in ItemActionMenu.Context enum)
		_item_action_menu.show_menu(item_id, 2, menu_pos)


func _try_unequip(slot_id: String) -> void:
	var save_data: CharacterSaveData = get_character_save_data(character_uid)
	if not save_data:
		_show_result("Error: No character data", false)
		return

	# Check inventory space
	var max_slots: int = get_max_inventory_slots()
	if save_data.inventory.size() >= max_slots:
		_show_result("Inventory full!", false)
		return

	# Get item name before unequipping
	var item_id: String = EquipmentManager.get_equipped_item_id(save_data, slot_id)
	var item_data: ItemData = get_item_data(item_id)
	var item_name: String = item_data.item_name if item_data else item_id

	# Unequip
	var result: Dictionary = EquipmentManager.unequip_item(save_data, slot_id)

	if DictUtils.get_bool(result, "success", false):
		_show_result("Unequipped %s" % item_name, true)
		_refresh_character_display()
	else:
		_show_result(DictUtils.get_string(result, "error", "Unknown error"), false)


# =============================================================================
# INVENTORY HANDLING
# =============================================================================

func _on_inventory_focus_entered(index: int, item_id: String) -> void:
	focused_slot_id = ""
	focused_inventory_index = index
	focused_item_id = item_id
	_update_item_details(item_id)
	play_sfx("cursor_move")


func _on_inventory_button_pressed(index: int, item_id: String) -> void:
	focused_slot_id = ""  # Clear equipment context
	focused_inventory_index = index
	focused_item_id = item_id

	# Show item action menu
	if inventory_buttons.size() > index:
		var button: Button = inventory_buttons[index]
		var button_rect: Rect2 = button.get_global_rect()
		var menu_pos: Vector2 = Vector2(button_rect.end.x + 4, button_rect.position.y)

		# Use subclass-defined context
		_item_action_menu.show_menu(item_id, _get_action_menu_context(), menu_pos)


func _on_item_action_selected(action: String, item_id: String) -> void:
	match action:
		"use":
			_handle_use_action(item_id)
		"equip":
			_handle_equip_action(item_id)
		"unequip":
			_try_unequip(focused_slot_id)
		"give":
			_handle_give_action(item_id)
		"drop":
			_handle_drop_action(item_id)
		"info":
			_handle_info_action(item_id)

	# Return focus to source button (inventory or equipment)
	_return_focus_to_source()


func _on_item_action_cancelled() -> void:
	_return_focus_to_source()


func _return_focus_to_source() -> void:
	var button: Button = null

	# Determine which button to return focus to
	if not focused_slot_id.is_empty() and focused_slot_id in equipment_buttons:
		button = equipment_buttons[focused_slot_id]
	elif focused_inventory_index >= 0 and focused_inventory_index < inventory_buttons.size():
		button = inventory_buttons[focused_inventory_index]

	if is_instance_valid(button):
		button.grab_focus()


func _handle_use_action(item_id: String) -> void:
	var item_data: ItemData = get_item_data(item_id)
	if not item_data:
		_show_result("Unknown item!", false)
		return

	if not item_data.is_usable_on_field():
		_show_result("Cannot use this item here!", false)
		return

	# Apply to current character
	var save_data: CharacterSaveData = get_character_save_data(character_uid)
	var result: Dictionary = _apply_item_effect(item_data, save_data)

	if DictUtils.get_bool(result, "success", false):
		save_data.remove_item_from_inventory(item_id)
		_show_result(DictUtils.get_string(result, "message", ""), true)
		_refresh_character_display()
	else:
		_show_result(DictUtils.get_string(result, "message", "Unknown error"), false)


func _handle_equip_action(item_id: String) -> void:
	var item_data: ItemData = get_item_data(item_id)
	if not item_data or not item_data.is_equippable():
		_show_result("Cannot equip this item!", false)
		return

	var save_data: CharacterSaveData = get_character_save_data(character_uid)
	if not save_data:
		_show_result("Error: No character data", false)
		return

	# Find valid slots for this item
	var valid_slots: Array[String] = item_data.get_valid_slots()

	# Filter out cursed slots
	var available_slots: Array[String] = []
	for slot_id: String in valid_slots:
		if not EquipmentManager.is_slot_cursed(save_data, slot_id):
			available_slots.append(slot_id)

	if available_slots.is_empty():
		_show_result("No valid equipment slot available!", false)
		return

	# For simplicity, equip to first available slot
	# A more complete implementation would let player choose if multiple slots
	var target_slot: String = available_slots[0]

	# Equip the new item
	var result: Dictionary = EquipmentManager.equip_item(save_data, target_slot, item_id)

	if DictUtils.get_bool(result, "success", false):
		_show_result("Equipped %s!" % item_data.item_name, true)
		_refresh_character_display()
	else:
		_show_result(DictUtils.get_string(result, "error", "Unknown error"), false)


func _handle_give_action(item_id: String) -> void:
	# Default: not supported (override in subclass if needed)
	_show_result("Give is not available here!", false)


func _handle_drop_action(item_id: String) -> void:
	var item_data: ItemData = get_item_data(item_id)
	if not item_data:
		_show_result("Unknown item!", false)
		return

	if not item_data.can_be_dropped:
		_show_result("This item cannot be dropped!", false)
		return

	var save_data: CharacterSaveData = get_character_save_data(character_uid)
	if save_data and save_data.remove_item_from_inventory(item_id):
		_show_result("Dropped %s" % item_data.item_name, true)
		_refresh_character_display()
	else:
		_show_result("Failed to drop item", false)


func _handle_info_action(item_id: String) -> void:
	# Show detailed info in details panel (already shown on focus)
	_update_item_details(item_id)
	_show_result("", true)  # Clear any previous result


func _apply_item_effect(item: ItemData, target: CharacterSaveData) -> Dictionary:
	## Apply consumable item effect to a character
	if not item.effect:
		return {"success": false, "message": "Item has no effect!"}

	var ability: AbilityData = item.effect as AbilityData
	if not ability:
		return {"success": false, "message": "Invalid item effect!"}

	match ability.ability_type:
		AbilityData.AbilityType.HEAL:
			if target.current_hp >= target.max_hp:
				return {"success": false, "message": "%s is already at full HP!" % character_name}

			var heal_amount: int = ability.potency
			var old_hp: int = target.current_hp
			target.current_hp = mini(target.current_hp + heal_amount, target.max_hp)
			var actual_heal: int = target.current_hp - old_hp
			return {"success": true, "message": "%s recovered %d HP!" % [character_name, actual_heal]}

		AbilityData.AbilityType.SUPPORT:
			return {"success": true, "message": "Used on %s!" % character_name}

		_:
			return {"success": false, "message": "Cannot use this item!"}


# =============================================================================
# DETAILS PANEL
# =============================================================================

func _update_details_panel(title: String, description: String) -> void:
	item_name_label.text = title
	item_desc_label.text = description


func _update_item_details(item_id: String) -> void:
	if item_id.is_empty():
		_update_details_panel("", "")
		return

	var item_data: ItemData = get_item_data(item_id)
	if not item_data:
		_update_details_panel("Unknown Item", item_id)
		return

	# Build description with stats
	var desc_lines: Array[String] = []

	# Item type
	var type_str: String = _get_item_type_string(item_data)
	if not type_str.is_empty():
		desc_lines.append(type_str)

	# Stats
	var stats_str: String = _get_item_stats_string(item_data)
	if not stats_str.is_empty():
		desc_lines.append(stats_str)

	# Description
	if not item_data.description.is_empty():
		desc_lines.append(item_data.description)

	# Cursed warning
	if item_data.is_cursed:
		desc_lines.append("[!] CURSED - Cannot be removed!")

	_update_details_panel(item_data.item_name.to_upper(), "\n".join(desc_lines))


func _get_item_type_string(item: ItemData) -> String:
	var base_name: String = ""
	var show_subtype: bool = false

	match item.item_type:
		ItemData.ItemType.WEAPON:
			base_name = "Weapon"
			show_subtype = true
		ItemData.ItemType.ACCESSORY:
			base_name = "Accessory"
			show_subtype = true
		ItemData.ItemType.CONSUMABLE:
			return "Consumable"
		ItemData.ItemType.KEY_ITEM:
			return "Key Item"
		_:
			return ""

	if show_subtype and not item.equipment_type.is_empty():
		return "%s (%s)" % [base_name, item.equipment_type.capitalize()]
	return base_name


func _get_item_stats_string(item: ItemData) -> String:
	var parts: Array[String] = []

	# Stat display pairs: [value, label, use_plus_format]
	var stats: Array = [
		[item.attack_power, "ATK", false],
		[item.defense_modifier, "DEF", true],
		[item.strength_modifier, "STR", true],
		[item.agility_modifier, "AGI", true],
		[item.intelligence_modifier, "INT", true],
		[item.hp_modifier, "HP", true],
		[item.mp_modifier, "MP", true],
	]

	for stat: Array in stats:
		var value: int = stat[0]
		var label: String = stat[1]
		var use_plus: bool = stat[2]
		if value != 0:
			var format: String = "%s %+d" if use_plus else "%s +%d"
			parts.append(format % [label, value])

	return "  ".join(parts)


# =============================================================================
# RESULT DISPLAY
# =============================================================================

func _show_result(message: String, success: bool) -> void:
	result_label.text = message
	if success:
		result_label.add_theme_color_override("font_color", UIColors.RESULT_SUCCESS)
		if not message.is_empty():
			play_sfx("menu_confirm")
	else:
		result_label.add_theme_color_override("font_color", UIColors.RESULT_ERROR)
		if not message.is_empty():
			play_sfx("menu_error")


# =============================================================================
# NAVIGATION
# =============================================================================

func _on_back_pressed() -> void:
	go_back()


func _on_back_focus_entered() -> void:
	focused_slot_id = ""
	focused_inventory_index = -1
	focused_item_id = ""
	_update_details_panel("", "Return to previous screen")
	play_sfx("cursor_move")


func _on_screen_exit() -> void:
	# Clean up button connections
	if is_instance_valid(back_button) and back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.disconnect(_on_back_pressed)

	# Clean up item action menu
	if _item_action_menu:
		if _item_action_menu.action_selected.is_connected(_on_item_action_selected):
			_item_action_menu.action_selected.disconnect(_on_item_action_selected)
		if _item_action_menu.menu_cancelled.is_connected(_on_item_action_cancelled):
			_item_action_menu.menu_cancelled.disconnect(_on_item_action_cancelled)
