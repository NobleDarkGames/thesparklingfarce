class_name InventoryPanel
extends PanelContainer

## InventoryPanel - SF2-style equipment and inventory management UI
##
## Displays one character's equipment slots and inventory in a clean layout:
##   [Character Name/Portrait]
##   Equipment: [Weapon] [Ring 1] [Ring 2] [Accessory]
##   Inventory: [Item 1] [Item 2] [Item 3] [Item 4]
##
## Supports equip/unequip flow with cursed item handling.
## Designed to be embedded in a larger party management menu.

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when any slot is clicked - parent can decide action
signal slot_clicked(slot_type: String, slot_index: int, item_id: String)

## Emitted when equipment changes successfully
signal equipment_changed(slot_id: String, old_item_id: String, new_item_id: String)

## Emitted when an equip/unequip operation fails
signal operation_failed(message: String)

## Emitted when a cursed item interaction is attempted
signal cursed_item_blocked(slot_id: String, item_id: String)

# =============================================================================
# CONSTANTS
# =============================================================================

const COLOR_PANEL_BG: Color = Color(0.12, 0.12, 0.16, 0.98)
const COLOR_PANEL_BORDER: Color = Color(0.5, 0.5, 0.6, 1.0)
const COLOR_SECTION_HEADER: Color = Color(0.7, 0.7, 0.8, 1.0)
const COLOR_CHARACTER_NAME: Color = Color(1.0, 1.0, 0.9, 1.0)
const COLOR_DESCRIPTION: Color = Color(0.6, 0.6, 0.7, 1.0)
const COLOR_VALID_TARGET: Color = Color(0.3, 0.8, 0.3, 0.5)
const COLOR_INSTRUCTION_ACTIVE: Color = Color(1.0, 1.0, 0.5, 1.0)
const COLOR_INSTRUCTION_INACTIVE: Color = Color(0.5, 0.5, 0.6, 0.8)

const SLOT_SPACING: int = 4
const SECTION_SPACING: int = 4
const PANEL_PADDING: int = 6

## Description box fixed height (enough for ~5 lines at font size 16)
## Accommodates item name + description + stat modifiers without clipping
const DESCRIPTION_HEIGHT: int = 88
## Instruction line height (comfortable for font size 16)
const INSTRUCTION_HEIGHT: int = 24

# =============================================================================
# EXPORTS
# =============================================================================

## Maximum inventory slots (default SF-style is 4)
@export var max_inventory_slots: int = 4

# =============================================================================
# STATE
# =============================================================================

## Character save data being displayed
var _save_data: CharacterSaveData = null

## Character template data (for portraits, names)
var _character_data: CharacterData = null

## Equipment slot components keyed by slot_id
var _equipment_slots: Dictionary = {}

## Inventory slot components (array)
var _inventory_slots: Array[ItemSlot] = []

## Interaction state
enum InteractionMode { NONE, SELECTING_EQUIP_TARGET }
var _interaction_mode: InteractionMode = InteractionMode.NONE
var _pending_inventory_index: int = -1
var _pending_item_id: String = ""
var _valid_target_slots: Array[String] = []

## UI References (built dynamically)
var _name_label: Label = null
var _class_label: Label = null
var _portrait_rect: TextureRect = null
var _equipment_container: HBoxContainer = null
var _inventory_container: HBoxContainer = null
var _description_label: Label = null
var _description_panel: PanelContainer = null
var _instruction_label: Label = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Let panel size to content - only description has fixed height
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clip_contents = true

	# Add explicit panel padding via theme override
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = COLOR_PANEL_BG
	panel_style.border_width_bottom = 1
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_color = COLOR_PANEL_BORDER
	panel_style.content_margin_bottom = PANEL_PADDING
	panel_style.content_margin_left = PANEL_PADDING
	panel_style.content_margin_right = PANEL_PADDING
	panel_style.content_margin_top = PANEL_PADDING
	add_theme_stylebox_override("panel", panel_style)

	# Main VBox for layout - consistent spacing
	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.add_theme_constant_override("separation", SECTION_SPACING)
	main_vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(main_vbox)

	# Character info section (name/portrait/class) - compact single line, centered
	var char_info_hbox: HBoxContainer = HBoxContainer.new()
	char_info_hbox.name = "CharacterInfo"
	char_info_hbox.add_theme_constant_override("separation", 6)
	char_info_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	char_info_hbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	main_vbox.add_child(char_info_hbox)

	# Portrait (32x32 compact) - vertically centered
	_portrait_rect = TextureRect.new()
	_portrait_rect.name = "Portrait"
	_portrait_rect.custom_minimum_size = Vector2(32, 32)
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	char_info_hbox.add_child(_portrait_rect)

	# Name and class on same line - vertically centered
	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.modulate = COLOR_CHARACTER_NAME
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	char_info_hbox.add_child(_name_label)

	_class_label = Label.new()
	_class_label.name = "ClassLabel"
	_class_label.add_theme_font_size_override("font_size", 16)
	_class_label.modulate = COLOR_SECTION_HEADER
	_class_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_class_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	char_info_hbox.add_child(_class_label)

	# Equipment slots (centered, no header label - slot labels show WPN/RNG/ACC)
	_equipment_container = HBoxContainer.new()
	_equipment_container.name = "EquipmentSlots"
	_equipment_container.add_theme_constant_override("separation", SLOT_SPACING)
	_equipment_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_equipment_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	main_vbox.add_child(_equipment_container)

	# Inventory slots (centered, no header label - cleaner look)
	_inventory_container = HBoxContainer.new()
	_inventory_container.name = "InventorySlots"
	_inventory_container.add_theme_constant_override("separation", SLOT_SPACING)
	_inventory_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_inventory_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	main_vbox.add_child(_inventory_container)

	# Instruction label (no panel wrapper - just the label, comfortable height)
	_instruction_label = Label.new()
	_instruction_label.name = "InstructionLabel"
	_instruction_label.add_theme_font_size_override("font_size", 16)
	_instruction_label.modulate = COLOR_INSTRUCTION_INACTIVE
	_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_instruction_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_instruction_label.custom_minimum_size = Vector2(0, INSTRUCTION_HEIGHT)
	main_vbox.add_child(_instruction_label)

	# Item description info box (SF-style bordered panel)
	# FIXED HEIGHT - this panel must never grow or shrink at runtime
	_description_panel = PanelContainer.new()
	_description_panel.name = "DescriptionPanel"
	var desc_style: StyleBoxFlat = StyleBoxFlat.new()
	desc_style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	desc_style.border_width_bottom = 1
	desc_style.border_width_left = 1
	desc_style.border_width_right = 1
	desc_style.border_width_top = 1
	desc_style.border_color = Color(0.4, 0.4, 0.5, 0.9)
	desc_style.content_margin_bottom = 2
	desc_style.content_margin_left = 4
	desc_style.content_margin_right = 4
	desc_style.content_margin_top = 2
	_description_panel.add_theme_stylebox_override("panel", desc_style)
	# Lock to exact height - both min and max
	_description_panel.custom_minimum_size = Vector2(0, DESCRIPTION_HEIGHT)
	_description_panel.size = Vector2(0, DESCRIPTION_HEIGHT)
	# SIZE_SHRINK_BEGIN + explicit size prevents container expansion
	_description_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_description_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_description_panel.clip_contents = true
	main_vbox.add_child(_description_panel)

	_description_label = Label.new()
	_description_label.name = "DescriptionLabel"
	_description_label.add_theme_font_size_override("font_size", 16)
	_description_label.modulate = COLOR_DESCRIPTION
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# Prevent label from requesting more space than parent provides
	_description_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Clip text that overflows - essential for fixed height
	_description_label.clip_text = true
	_description_panel.add_child(_description_label)


# =============================================================================
# PUBLIC API
# =============================================================================

## Set the character to display
## @param save_data: CharacterSaveData to display and modify
func set_character(save_data: CharacterSaveData) -> void:
	_save_data = save_data
	_character_data = null

	if _save_data:
		# Load character template
		_character_data = ModLoader.registry.get_resource(
			"character",
			_save_data.character_resource_id
		) as CharacterData

	_cancel_interaction()
	_rebuild_slots()
	refresh()


## Refresh display from current save data
func refresh() -> void:
	if not _save_data:
		_clear_display()
		return

	_update_character_info()
	_update_equipment_slots()
	_update_inventory_slots()
	_update_description("")


## Get the currently displayed character's save data
func get_save_data() -> CharacterSaveData:
	return _save_data


# =============================================================================
# SLOT MANAGEMENT
# =============================================================================

func _rebuild_slots() -> void:
	# Clear existing equipment slots
	for slot_id: String in _equipment_slots:
		var slot: ItemSlot = _equipment_slots[slot_id] as ItemSlot
		if is_instance_valid(slot):
			slot.queue_free()
	_equipment_slots.clear()

	# Clear existing inventory slots
	for slot: ItemSlot in _inventory_slots:
		if is_instance_valid(slot):
			slot.queue_free()
	_inventory_slots.clear()

	# Get equipment slot layout from registry
	var slot_layout: Array[Dictionary] = ModLoader.equipment_slot_registry.get_slots()

	# Create equipment slots
	for slot_def: Dictionary in slot_layout:
		var slot_id: String = slot_def.get("id", "")
		if slot_id.is_empty():
			continue

		var slot: ItemSlot = _create_item_slot()
		slot.name = "EquipSlot_" + slot_id
		_equipment_container.add_child(slot)
		_equipment_slots[slot_id] = slot

		# Set slot label for when empty (show abbreviated name)
		var display_name: String = slot_def.get("display_name", slot_id.capitalize())
		var abbrev: String = _abbreviate_slot_name(display_name)
		slot.set_slot_label(abbrev)

		# Connect signals with slot_id context
		var captured_slot_id: String = slot_id
		slot.clicked.connect(_on_equipment_slot_clicked.bind(captured_slot_id))
		slot.hovered.connect(_on_slot_hovered.bind("equipment", captured_slot_id))
		slot.hover_exited.connect(_on_slot_hover_exited)

	# Create inventory slots
	for i in range(max_inventory_slots):
		var slot: ItemSlot = _create_item_slot()
		slot.name = "InvSlot_%d" % i
		_inventory_container.add_child(slot)
		_inventory_slots.append(slot)

		# Connect signals with index context
		var captured_index: int = i
		slot.clicked.connect(_on_inventory_slot_clicked.bind(captured_index))
		slot.hovered.connect(_on_slot_hovered.bind("inventory", str(captured_index)))
		slot.hover_exited.connect(_on_slot_hover_exited)


func _create_item_slot() -> ItemSlot:
	var slot: ItemSlot = ItemSlot.new()
	return slot


func _update_character_info() -> void:
	if not _save_data:
		return

	# Name - prefer character data, fallback to save data
	if _character_data:
		_name_label.text = _character_data.character_name
	else:
		_name_label.text = _save_data.fallback_character_name

	# Class - get from current class
	var class_data: ClassData = _save_data.get_current_class(_character_data)
	if class_data:
		_class_label.text = "Lv%d %s" % [_save_data.level, class_data.display_name]
	else:
		_class_label.text = "Lv%d %s" % [_save_data.level, _save_data.fallback_class_name]

	# Portrait
	if _character_data and _character_data.portrait:
		_portrait_rect.texture = _character_data.portrait
	else:
		_portrait_rect.texture = null


func _update_equipment_slots() -> void:
	if not _save_data:
		return

	for slot_id: String in _equipment_slots:
		var slot: ItemSlot = _equipment_slots[slot_id] as ItemSlot
		var item_id: String = EquipmentManager.get_equipped_item_id(_save_data, slot_id)
		var is_cursed: bool = EquipmentManager.is_slot_cursed(_save_data, slot_id)
		slot.set_item(item_id, is_cursed)

		# Update selection state for valid targets
		if _interaction_mode == InteractionMode.SELECTING_EQUIP_TARGET:
			slot.set_selected(slot_id in _valid_target_slots)
		else:
			slot.set_selected(false)


func _update_inventory_slots() -> void:
	if not _save_data:
		return

	for i in range(_inventory_slots.size()):
		var slot: ItemSlot = _inventory_slots[i]
		if i < _save_data.inventory.size():
			slot.set_item(_save_data.inventory[i], false)
		else:
			slot.clear_item()

		# Highlight pending selection
		if _interaction_mode == InteractionMode.SELECTING_EQUIP_TARGET:
			slot.set_selected(i == _pending_inventory_index)
		else:
			slot.set_selected(false)


func _clear_display() -> void:
	_name_label.text = ""
	_class_label.text = ""
	_portrait_rect.texture = null
	_update_description("")
	_update_instruction("")

	for slot_id: String in _equipment_slots:
		var slot: ItemSlot = _equipment_slots[slot_id] as ItemSlot
		slot.clear_item()

	for slot: ItemSlot in _inventory_slots:
		slot.clear_item()


func _update_description(text: String) -> void:
	_description_label.text = text


func _update_instruction(text: String) -> void:
	_instruction_label.text = text
	# Dynamic prominence: highlight when showing active instruction
	if text.is_empty():
		_instruction_label.modulate = COLOR_INSTRUCTION_INACTIVE
	else:
		_instruction_label.modulate = COLOR_INSTRUCTION_ACTIVE


# =============================================================================
# INTERACTION HANDLING
# =============================================================================

func _on_equipment_slot_clicked(item_id: String, slot_id: String) -> void:
	if not _save_data:
		return

	# If we're selecting an equip target, try to equip
	if _interaction_mode == InteractionMode.SELECTING_EQUIP_TARGET:
		if slot_id in _valid_target_slots:
			_try_equip_to_slot(slot_id)
		else:
			# Clicked invalid slot - cancel
			_cancel_interaction()
		return

	# Normal click on equipment slot
	slot_clicked.emit("equipment", 0, item_id)

	if item_id.is_empty():
		# Empty equipment slot - nothing to do
		_update_instruction("")
		return

	# Check if item is cursed
	if EquipmentManager.is_slot_cursed(_save_data, slot_id):
		_update_instruction("This item is cursed!")
		cursed_item_blocked.emit(slot_id, item_id)
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		return

	# Try to unequip
	_try_unequip_from_slot(slot_id)


func _on_inventory_slot_clicked(item_id: String, index: int) -> void:
	if not _save_data:
		return

	# If we're selecting an equip target, cancel (clicked inventory instead)
	if _interaction_mode == InteractionMode.SELECTING_EQUIP_TARGET:
		if index == _pending_inventory_index:
			# Clicked same slot - cancel interaction
			_cancel_interaction()
		else:
			# Clicked different inventory slot - switch to that item
			_cancel_interaction()
			# Recursively handle the new click
			_on_inventory_slot_clicked(item_id, index)
		return

	# Normal click on inventory slot
	slot_clicked.emit("inventory", index, item_id)

	if item_id.is_empty():
		_update_instruction("")
		return

	# Check if item is equippable
	var item_data: ItemData = ModLoader.registry.get_resource("item", item_id) as ItemData
	if not item_data:
		return

	if not item_data.is_equippable():
		_update_instruction("Cannot equip this item")
		return

	# Start equip target selection
	_start_equip_selection(index, item_id, item_data)


func _start_equip_selection(inv_index: int, item_id: String, item_data: ItemData) -> void:
	_interaction_mode = InteractionMode.SELECTING_EQUIP_TARGET
	_pending_inventory_index = inv_index
	_pending_item_id = item_id

	# Find valid equipment slots for this item type
	_valid_target_slots = item_data.get_valid_slots()

	# Filter out slots with cursed items
	var filtered_slots: Array[String] = []
	for slot_id: String in _valid_target_slots:
		if not EquipmentManager.is_slot_cursed(_save_data, slot_id):
			filtered_slots.append(slot_id)
	_valid_target_slots = filtered_slots

	if _valid_target_slots.is_empty():
		_update_instruction("No valid slots available (blocked by curse?)")
		_cancel_interaction()
		return

	_update_instruction("Select equipment slot...")
	_update_equipment_slots()
	_update_inventory_slots()
	AudioManager.play_sfx("menu_confirm", AudioManager.SFXCategory.UI)


func _try_equip_to_slot(slot_id: String) -> void:
	if not _save_data or _pending_item_id.is_empty():
		_cancel_interaction()
		return

	# Call EquipmentManager to handle the equip
	var result: Dictionary = EquipmentManager.equip_item(
		_save_data,
		slot_id,
		_pending_item_id
	)

	if result.success:
		# Move old item to inventory (if any)
		var old_item_id: String = result.unequipped_item_id
		if not old_item_id.is_empty():
			# Replace the inventory slot with the old item
			if _pending_inventory_index < _save_data.inventory.size():
				_save_data.inventory[_pending_inventory_index] = old_item_id
			else:
				_save_data.add_item_to_inventory(old_item_id)
		else:
			# Remove the item from inventory
			if _pending_inventory_index < _save_data.inventory.size():
				_save_data.inventory.remove_at(_pending_inventory_index)

		AudioManager.play_sfx("menu_confirm", AudioManager.SFXCategory.UI)
		equipment_changed.emit(slot_id, old_item_id, _pending_item_id)
		_update_instruction("Equipped!")
	else:
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		operation_failed.emit(result.error)
		_update_instruction(result.error)

	_cancel_interaction()
	refresh()


func _try_unequip_from_slot(slot_id: String) -> void:
	if not _save_data:
		return

	var old_item_id: String = EquipmentManager.get_equipped_item_id(_save_data, slot_id)

	# Check if inventory has room
	if _save_data.inventory.size() >= max_inventory_slots:
		_update_instruction("Inventory full!")
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		operation_failed.emit("Inventory full")
		return

	# Call EquipmentManager to handle the unequip
	var result: Dictionary = EquipmentManager.unequip_item(_save_data, slot_id)

	if result.success:
		# Add unequipped item to inventory
		if not result.unequipped_item_id.is_empty():
			_save_data.add_item_to_inventory(result.unequipped_item_id)

		AudioManager.play_sfx("menu_confirm", AudioManager.SFXCategory.UI)
		equipment_changed.emit(slot_id, old_item_id, "")
		_update_instruction("Unequipped")
	else:
		AudioManager.play_sfx("menu_error", AudioManager.SFXCategory.UI)
		operation_failed.emit(result.error)
		_update_instruction(result.error)

	refresh()


func _cancel_interaction() -> void:
	_interaction_mode = InteractionMode.NONE
	_pending_inventory_index = -1
	_pending_item_id = ""
	_valid_target_slots.clear()
	_update_instruction("")
	_update_equipment_slots()
	_update_inventory_slots()


# =============================================================================
# HOVER HANDLING
# =============================================================================

func _on_slot_hovered(item_id: String, slot_type: String, slot_key: String) -> void:
	if item_id.is_empty():
		# Show slot type name for empty slots
		if slot_type == "equipment":
			var display_name: String = ModLoader.equipment_slot_registry.get_slot_display_name(slot_key)
			_update_description(display_name + " (empty)")
		else:
			_update_description("Empty")
		return

	# Get item data and show description
	var item_data: ItemData = ModLoader.registry.get_resource("item", item_id) as ItemData
	if item_data:
		var desc: String = item_data.item_name
		if not item_data.description.is_empty():
			desc += "\n" + item_data.description

		# Add stats summary for equipment
		if item_data.is_equippable():
			var stats_text: String = _format_item_stats(item_data)
			if not stats_text.is_empty():
				desc += "\n" + stats_text

		_update_description(desc)
	else:
		_update_description("Unknown item: " + item_id)


func _on_slot_hover_exited() -> void:
	_update_description("")


func _format_item_stats(item: ItemData) -> String:
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

	if parts.is_empty():
		return ""

	return ", ".join(parts)


func _abbreviate_slot_name(name: String) -> String:
	## Abbreviate slot names to fit in small 48x48 slots
	## "Weapon" -> "WPN", "Ring 1" -> "RNG1", "Accessory" -> "ACC"
	match name.to_lower():
		"weapon":
			return "WPN"
		"ring 1":
			return "RNG1"
		"ring 2":
			return "RNG2"
		"accessory":
			return "ACC"
		_:
			# For custom slot names, take first 3-4 chars
			if name.length() <= 4:
				return name.to_upper()
			return name.substr(0, 4).to_upper()


# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Cancel key cancels current interaction
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("sf_cancel"):
		if _interaction_mode != InteractionMode.NONE:
			_cancel_interaction()
			AudioManager.play_sfx("menu_cancel", AudioManager.SFXCategory.UI)
			get_viewport().set_input_as_handled()
