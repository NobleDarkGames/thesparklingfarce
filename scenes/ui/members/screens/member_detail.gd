extends "res://scenes/ui/members/screens/members_screen_base.gd"

## MemberDetail - Character equipment and inventory management (keyboard-first)
##
## Complete redesign following Shop/Caravan button-list patterns.
## NO mouse-based InventoryPanel - uses focusable button lists instead.
##
## Layout:
##   - Character info header (name, class, HP/MP)
##   - Equipment list: "Weapon: Bronze Sword", "Ring 1: (empty)", etc.
##   - Inventory list: Each item as a button
##   - Details panel: Shows item info on focus
##   - L/R cycling: Switch between party members
##
## Actions handled via ItemActionMenu popup for consistent UX.

# =============================================================================
# CONSTANTS
# =============================================================================

const COLOR_NORMAL: Color = Color(0.8, 0.8, 0.8, 1.0)
const COLOR_SELECTED: Color = Color(1.0, 1.0, 0.3, 1.0)
const COLOR_DISABLED: Color = Color(0.5, 0.5, 0.5, 1.0)
const COLOR_EMPTY: Color = Color(0.5, 0.5, 0.6, 1.0)
const COLOR_CURSED: Color = Color(1.0, 0.3, 0.3, 1.0)
const COLOR_SUCCESS: Color = Color(0.4, 1.0, 0.4, 1.0)
const COLOR_ERROR: Color = Color(1.0, 0.4, 0.4, 1.0)

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
# UI REFERENCES
# =============================================================================

@onready var header_label: Label = %HeaderLabel
@onready var stats_label: Label = %StatsLabel
@onready var cycle_hint_label: Label = %CycleHintLabel
@onready var equipment_list: VBoxContainer = %EquipmentList
@onready var inventory_list: VBoxContainer = %InventoryList
@onready var details_panel: PanelContainer = %DetailsPanel
@onready var item_name_label: Label = %ItemNameLabel
@onready var item_desc_label: Label = %ItemDescLabel
@onready var result_label: Label = %ResultLabel
@onready var back_button: Button = %BackButton


func _on_initialized() -> void:
	_create_styles()
	_create_popups()

	# Get current character from context
	character_uid = get_current_member_uid()
	_refresh_for_current_member()

	# Connect back button
	back_button.pressed.connect(_on_back_pressed)
	back_button.focus_entered.connect(_on_back_focus_entered)


func _create_styles() -> void:
	_selected_style = StyleBoxFlat.new()
	_selected_style.bg_color = Color(0.3, 0.5, 0.8, 1.0)
	_selected_style.set_corner_radius_all(2)


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

func _refresh_for_current_member() -> void:
	character_uid = get_current_member_uid()

	var char_data: CharacterData = get_character_data(character_uid)
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

	# Update cycle hint - include all controls since parent hints are hidden
	var party_size: int = get_party_size()
	if party_size > 1:
		cycle_hint_label.text = "L/R: Switch | A: Select | B: Back"
	else:
		cycle_hint_label.text = "A: Select | B: Back"
	cycle_hint_label.visible = true

	# Rebuild button lists
	_rebuild_equipment_list()
	_rebuild_inventory_list()

	# Clear details and result
	_update_details_panel("", "")
	result_label.text = ""

	# Focus first equipment button
	_focus_first_button()


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

		# Create button
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(0, 26)
		button.focus_mode = Control.FOCUS_ALL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 16)

		# Format text: "Weapon: Bronze Sword" or "Weapon: (empty)"
		if item_id.is_empty():
			button.text = "%s: (empty)" % display_name
			button.add_theme_color_override("font_color", COLOR_EMPTY)
		else:
			var item_data: ItemData = get_item_data(item_id)
			var item_name: String = item_data.item_name if item_data else item_id
			button.text = "%s: %s" % [display_name, item_name]
			if is_cursed:
				button.add_theme_color_override("font_color", COLOR_CURSED)
				button.text += " [CURSED]"

		equipment_list.add_child(button)
		equipment_buttons[slot_id] = button

		# Connect signals with captured slot_id
		var captured_slot_id: String = slot_id
		var captured_item_id: String = item_id
		button.pressed.connect(_on_equipment_button_pressed.bind(captured_slot_id, captured_item_id))
		button.focus_entered.connect(_on_equipment_focus_entered.bind(captured_slot_id, captured_item_id))


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

		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(0, 24)
		button.focus_mode = Control.FOCUS_ALL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 16)

		if item_data:
			button.text = item_data.item_name
		else:
			button.text = item_id
			button.add_theme_color_override("font_color", COLOR_DISABLED)

		inventory_list.add_child(button)
		inventory_buttons.append(button)

		# Connect signals with captured index
		var captured_index: int = i
		var captured_item_id: String = item_id
		button.pressed.connect(_on_inventory_button_pressed.bind(captured_index, captured_item_id))
		button.focus_entered.connect(_on_inventory_focus_entered.bind(captured_index, captured_item_id))

	# Show empty slot indicator if inventory has room
	if save_data.inventory.size() < max_slots:
		var empty_slots: int = max_slots - save_data.inventory.size()
		var label: Label = Label.new()
		label.text = "(%d empty slot%s)" % [empty_slots, "s" if empty_slots > 1 else ""]
		label.add_theme_color_override("font_color", COLOR_EMPTY)
		label.add_theme_font_size_override("font_size", 16)
		inventory_list.add_child(label)

	# Handle completely empty inventory
	if save_data.inventory.is_empty():
		var label: Label = Label.new()
		label.text = "No items"
		label.add_theme_color_override("font_color", COLOR_DISABLED)
		label.add_theme_font_size_override("font_size", 16)
		inventory_list.add_child(label)


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
		# Add to inventory
		var unequipped_id: String = DictUtils.get_string(result, "unequipped_item_id", "")
		if not unequipped_id.is_empty():
			save_data.add_item_to_inventory(unequipped_id)
		_show_result("Unequipped %s" % item_name, true)
		_refresh_for_current_member()
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

		# Use ItemActionMenu's show_menu with EXPLORATION context
		var ItemActionMenuClass: Script = load("res://scenes/ui/item_action_menu.gd")
		_item_action_menu.show_menu(item_id, ItemActionMenuClass.Context.EXPLORATION, menu_pos)


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
	# If we came from equipment slot, return there
	if not focused_slot_id.is_empty() and focused_slot_id in equipment_buttons:
		var button: Button = equipment_buttons[focused_slot_id]
		if is_instance_valid(button):
			button.grab_focus()
			return

	# Otherwise return to inventory button
	if focused_inventory_index >= 0 and focused_inventory_index < inventory_buttons.size():
		var button: Button = inventory_buttons[focused_inventory_index]
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
		_refresh_for_current_member()
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

	# Get old item for swap
	var old_item_id: String = EquipmentManager.get_equipped_item_id(save_data, target_slot)

	# Equip the new item
	var result: Dictionary = EquipmentManager.equip_item(save_data, target_slot, item_id)

	if DictUtils.get_bool(result, "success", false):
		# Remove from inventory and add old item if swapped
		save_data.remove_item_from_inventory(item_id)
		var unequipped_id: String = DictUtils.get_string(result, "unequipped_item_id", "")
		if not unequipped_id.is_empty():
			save_data.add_item_to_inventory(unequipped_id)
		_show_result("Equipped %s!" % item_data.item_name, true)
		_refresh_for_current_member()
	else:
		_show_result(DictUtils.get_string(result, "error", "Unknown error"), false)


func _handle_give_action(item_id: String) -> void:
	# Enter GIVE mode and go to recipient selection
	if context:
		context.set_give_mode(character_uid, item_id)
	play_sfx("menu_select")
	push_screen("give_recipient_select")


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
		_refresh_for_current_member()
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
	match item.item_type:
		ItemData.ItemType.WEAPON:
			if not item.equipment_type.is_empty():
				return "Weapon (%s)" % item.equipment_type.capitalize()
			return "Weapon"
		ItemData.ItemType.ACCESSORY:
			if not item.equipment_type.is_empty():
				return "Accessory (%s)" % item.equipment_type.capitalize()
			return "Accessory"
		ItemData.ItemType.CONSUMABLE:
			return "Consumable"
		ItemData.ItemType.KEY_ITEM:
			return "Key Item"
		_:
			return ""


func _get_item_stats_string(item: ItemData) -> String:
	var parts: Array[String] = []

	if item.attack_power > 0:
		parts.append("ATK +%d" % item.attack_power)
	if item.defense_modifier != 0:
		parts.append("DEF %+d" % item.defense_modifier)
	if item.strength_modifier != 0:
		parts.append("STR %+d" % item.strength_modifier)
	if item.agility_modifier != 0:
		parts.append("AGI %+d" % item.agility_modifier)
	if item.intelligence_modifier != 0:
		parts.append("INT %+d" % item.intelligence_modifier)
	if item.hp_modifier != 0:
		parts.append("HP %+d" % item.hp_modifier)
	if item.mp_modifier != 0:
		parts.append("MP %+d" % item.mp_modifier)

	return "  ".join(parts)


# =============================================================================
# RESULT DISPLAY
# =============================================================================

func _show_result(message: String, success: bool) -> void:
	result_label.text = message
	if success:
		result_label.add_theme_color_override("font_color", COLOR_SUCCESS)
		if not message.is_empty():
			play_sfx("menu_confirm")
	else:
		result_label.add_theme_color_override("font_color", COLOR_ERROR)
		if not message.is_empty():
			play_sfx("menu_error")


# =============================================================================
# L/R CHARACTER CYCLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Don't process L/R if a popup is open
	if _item_action_menu and _item_action_menu.is_menu_active():
		return

	# L/R bumpers - CRITICAL SF2 pattern for character cycling
	# Check if shoulder actions exist before using them (may not be mapped)
	var left_shoulder: bool = InputMap.has_action("sf_left_shoulder") and event.is_action_pressed("sf_left_shoulder")
	var right_shoulder: bool = InputMap.has_action("sf_right_shoulder") and event.is_action_pressed("sf_right_shoulder")

	if left_shoulder or event.is_action_pressed("ui_page_up"):
		_cycle_to_previous_member()
		get_viewport().set_input_as_handled()
	elif right_shoulder or event.is_action_pressed("ui_page_down"):
		_cycle_to_next_member()
		get_viewport().set_input_as_handled()
	else:
		# Let base class handle ui_cancel/sf_cancel for back navigation
		super._input(event)


func _cycle_to_previous_member() -> void:
	if get_party_size() <= 1:
		return
	cycle_member(-1)
	_refresh_for_current_member()
	play_sfx("cursor_move")


func _cycle_to_next_member() -> void:
	if get_party_size() <= 1:
		return
	cycle_member(1)
	_refresh_for_current_member()
	play_sfx("cursor_move")


# =============================================================================
# NAVIGATION
# =============================================================================

func _on_back_pressed() -> void:
	go_back()


func _on_back_focus_entered() -> void:
	focused_slot_id = ""
	focused_inventory_index = -1
	focused_item_id = ""
	_update_details_panel("", "Return to member list")
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
