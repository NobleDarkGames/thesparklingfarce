@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Item Editor UI
## Allows browsing and editing ItemData resources

var name_edit: LineEdit
var item_type_option: OptionButton
var equipment_type_edit: LineEdit
var equipment_slot_option: OptionButton
var description_edit: TextEdit

# Curse properties
var curse_section: VBoxContainer
var is_cursed_check: CheckBox
var uncurse_items_edit: LineEdit

# Stat modifiers
var hp_mod_spin: SpinBox
var mp_mod_spin: SpinBox
var str_mod_spin: SpinBox
var def_mod_spin: SpinBox
var agi_mod_spin: SpinBox
var int_mod_spin: SpinBox
var luk_mod_spin: SpinBox

# Weapon properties
var weapon_section: VBoxContainer
var attack_power_spin: SpinBox
var attack_range_spin: SpinBox
var hit_rate_spin: SpinBox
var crit_rate_spin: SpinBox

# Consumable properties
var consumable_section: VBoxContainer
var usable_battle_check: CheckBox
var usable_field_check: CheckBox

# Economy
var buy_price_spin: SpinBox
var sell_price_spin: SpinBox


func _ready() -> void:
	resource_directory = "res://mods/_sandbox/data/items/"
	resource_type_id = "item"
	resource_type_name = "Item"
	super._ready()


## Override: Create the item-specific detail form
func _create_detail_form() -> void:
	# Basic info section
	_add_basic_info_section()

	# Curse properties section (for equippable items)
	_add_curse_section()

	# Stat modifiers section
	_add_stat_modifiers_section()

	# Weapon properties section
	_add_weapon_section()

	# Consumable properties section
	_add_consumable_section()

	# Economy section
	_add_economy_section()

	# Add the button container at the end
	detail_panel.add_child(button_container)


## Override: Load item data from resource into UI
func _load_resource_data() -> void:
	var item: ItemData = current_resource as ItemData
	if not item:
		return

	name_edit.text = item.item_name
	item_type_option.selected = item.item_type
	equipment_type_edit.text = item.equipment_type
	_select_equipment_slot(item.equipment_slot)
	description_edit.text = item.description

	# Curse properties
	is_cursed_check.button_pressed = item.is_cursed
	uncurse_items_edit.text = ",".join(item.uncurse_items)

	# Stat modifiers
	hp_mod_spin.value = item.hp_modifier
	mp_mod_spin.value = item.mp_modifier
	str_mod_spin.value = item.strength_modifier
	def_mod_spin.value = item.defense_modifier
	agi_mod_spin.value = item.agility_modifier
	int_mod_spin.value = item.intelligence_modifier
	luk_mod_spin.value = item.luck_modifier

	# Weapon properties
	attack_power_spin.value = item.attack_power
	attack_range_spin.value = item.attack_range
	hit_rate_spin.value = item.hit_rate
	crit_rate_spin.value = item.critical_rate

	# Consumable properties
	usable_battle_check.button_pressed = item.usable_in_battle
	usable_field_check.button_pressed = item.usable_on_field

	# Economy
	buy_price_spin.value = item.buy_price
	sell_price_spin.value = item.sell_price

	# Update section visibility
	_on_item_type_changed(item.item_type)


## Override: Save UI data to resource
func _save_resource_data() -> void:
	var item: ItemData = current_resource as ItemData
	if not item:
		return

	# Update item data from UI
	item.item_name = name_edit.text
	item.item_type = item_type_option.selected
	item.equipment_type = equipment_type_edit.text
	item.equipment_slot = _get_selected_equipment_slot()
	item.description = description_edit.text

	# Update curse properties
	item.is_cursed = is_cursed_check.button_pressed
	item.uncurse_items = _parse_uncurse_items()

	# Update stat modifiers
	item.hp_modifier = int(hp_mod_spin.value)
	item.mp_modifier = int(mp_mod_spin.value)
	item.strength_modifier = int(str_mod_spin.value)
	item.defense_modifier = int(def_mod_spin.value)
	item.agility_modifier = int(agi_mod_spin.value)
	item.intelligence_modifier = int(int_mod_spin.value)
	item.luck_modifier = int(luk_mod_spin.value)

	# Update weapon properties
	item.attack_power = int(attack_power_spin.value)
	item.attack_range = int(attack_range_spin.value)
	item.hit_rate = int(hit_rate_spin.value)
	item.critical_rate = int(crit_rate_spin.value)

	# Update consumable properties
	item.usable_in_battle = usable_battle_check.button_pressed
	item.usable_on_field = usable_field_check.button_pressed

	# Update economy
	item.buy_price = int(buy_price_spin.value)
	item.sell_price = int(sell_price_spin.value)


## Override: Validate resource before saving
func _validate_resource() -> Dictionary:
	var item: ItemData = current_resource as ItemData
	if not item:
		return {valid = false, errors = ["Invalid resource type"]}

	var errors: Array[String] = []

	if item.item_name.strip_edges().is_empty():
		errors.append("Item name cannot be empty")

	if item.buy_price < 0:
		errors.append("Buy price cannot be negative")

	if item.sell_price < 0:
		errors.append("Sell price cannot be negative")

	return {valid = errors.is_empty(), errors = errors}


## Override: Check for references before deletion
func _check_resource_references(resource_to_check: Resource) -> Array[String]:
	var item_to_check: ItemData = resource_to_check as ItemData
	if not item_to_check:
		return []

	var references: Array[String] = []

	# Check all characters for references to this item in their equipment arrays
	var dir: DirAccess = DirAccess.open("res://mods/_sandbox/data/characters/")
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var character: CharacterData = load("res://mods/_sandbox/data/characters/" + file_name)
				if character:
					if item_to_check in character.starting_equipment:
						references.append("res://mods/_sandbox/data/characters/" + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

	# TODO: In Phase 2+, also check shop inventories, treasure chests, etc.

	return references


## Override: Create a new item with defaults
func _create_new_resource() -> Resource:
	var new_item: ItemData = ItemData.new()
	new_item.item_name = "New Item"
	new_item.item_type = ItemData.ItemType.WEAPON
	new_item.equipment_slot = "weapon"
	new_item.is_cursed = false
	new_item.buy_price = 100
	new_item.sell_price = 50

	return new_item


## Override: Get the display name from an item resource
func _get_resource_display_name(resource: Resource) -> String:
	var item: ItemData = resource as ItemData
	if item:
		return item.item_name
	return "Unnamed Item"


func _add_basic_info_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Basic Information"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Name
	var name_container: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = "Item Name:"
	name_label.custom_minimum_size.x = 150
	name_container.add_child(name_label)

	name_edit = LineEdit.new()
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_container.add_child(name_edit)
	section.add_child(name_container)

	# Item Type
	var type_container: HBoxContainer = HBoxContainer.new()
	var type_label: Label = Label.new()
	type_label.text = "Item Type:"
	type_label.custom_minimum_size.x = 150
	type_container.add_child(type_label)

	item_type_option = OptionButton.new()
	item_type_option.add_item("Weapon", ItemData.ItemType.WEAPON)
	item_type_option.add_item("Armor", ItemData.ItemType.ARMOR)
	item_type_option.add_item("Accessory", ItemData.ItemType.ACCESSORY)
	item_type_option.add_item("Consumable", ItemData.ItemType.CONSUMABLE)
	item_type_option.add_item("Key Item", ItemData.ItemType.KEY_ITEM)
	item_type_option.item_selected.connect(_on_item_type_changed)
	type_container.add_child(item_type_option)
	section.add_child(type_container)

	# Equipment Type
	var equip_container: HBoxContainer = HBoxContainer.new()
	var equip_label: Label = Label.new()
	equip_label.text = "Equipment Type:"
	equip_label.custom_minimum_size.x = 150
	equip_label.tooltip_text = "For weapons: sword, axe, bow, etc.\nFor armor: light, heavy, robe, etc."
	equip_container.add_child(equip_label)

	equipment_type_edit = LineEdit.new()
	equipment_type_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_type_edit.placeholder_text = "e.g., sword, light armor"
	equip_container.add_child(equipment_type_edit)
	section.add_child(equip_container)

	# Equipment Slot
	var slot_container: HBoxContainer = HBoxContainer.new()
	var slot_label: Label = Label.new()
	slot_label.text = "Equipment Slot:"
	slot_label.custom_minimum_size.x = 150
	slot_label.tooltip_text = "Which slot this item occupies when equipped"
	slot_container.add_child(slot_label)

	equipment_slot_option = OptionButton.new()
	equipment_slot_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_populate_equipment_slot_options()
	slot_container.add_child(equipment_slot_option)
	section.add_child(slot_container)

	# Description
	var desc_label: Label = Label.new()
	desc_label.text = "Description:"
	section.add_child(desc_label)

	description_edit = TextEdit.new()
	description_edit.custom_minimum_size.y = 80
	section.add_child(description_edit)

	detail_panel.add_child(section)


func _add_stat_modifiers_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Stat Modifiers"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	hp_mod_spin = _create_modifier_editor("HP:", section)
	mp_mod_spin = _create_modifier_editor("MP:", section)
	str_mod_spin = _create_modifier_editor("Strength:", section)
	def_mod_spin = _create_modifier_editor("Defense:", section)
	agi_mod_spin = _create_modifier_editor("Agility:", section)
	int_mod_spin = _create_modifier_editor("Intelligence:", section)
	luk_mod_spin = _create_modifier_editor("Luck:", section)

	detail_panel.add_child(section)


func _add_weapon_section() -> void:
	weapon_section = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Weapon Properties"
	section_label.add_theme_font_size_override("font_size", 16)
	weapon_section.add_child(section_label)

	# Attack Power
	var power_container: HBoxContainer = HBoxContainer.new()
	var power_label: Label = Label.new()
	power_label.text = "Attack Power:"
	power_label.custom_minimum_size.x = 150
	power_container.add_child(power_label)

	attack_power_spin = SpinBox.new()
	attack_power_spin.min_value = 0
	attack_power_spin.max_value = 999
	attack_power_spin.value = 10
	power_container.add_child(attack_power_spin)
	weapon_section.add_child(power_container)

	# Attack Range
	var range_container: HBoxContainer = HBoxContainer.new()
	var range_label: Label = Label.new()
	range_label.text = "Attack Range:"
	range_label.custom_minimum_size.x = 150
	range_container.add_child(range_label)

	attack_range_spin = SpinBox.new()
	attack_range_spin.min_value = 1
	attack_range_spin.max_value = 20
	attack_range_spin.value = 1
	range_container.add_child(attack_range_spin)
	weapon_section.add_child(range_container)

	# Hit Rate
	var hit_container: HBoxContainer = HBoxContainer.new()
	var hit_label: Label = Label.new()
	hit_label.text = "Hit Rate (%):"
	hit_label.custom_minimum_size.x = 150
	hit_container.add_child(hit_label)

	hit_rate_spin = SpinBox.new()
	hit_rate_spin.min_value = 0
	hit_rate_spin.max_value = 100
	hit_rate_spin.value = 90
	hit_container.add_child(hit_rate_spin)
	weapon_section.add_child(hit_container)

	# Critical Rate
	var crit_container: HBoxContainer = HBoxContainer.new()
	var crit_label: Label = Label.new()
	crit_label.text = "Critical Rate (%):"
	crit_label.custom_minimum_size.x = 150
	crit_container.add_child(crit_label)

	crit_rate_spin = SpinBox.new()
	crit_rate_spin.min_value = 0
	crit_rate_spin.max_value = 100
	crit_rate_spin.value = 5
	crit_container.add_child(crit_rate_spin)
	weapon_section.add_child(crit_container)

	detail_panel.add_child(weapon_section)


func _add_consumable_section() -> void:
	consumable_section = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Consumable Properties"
	section_label.add_theme_font_size_override("font_size", 16)
	consumable_section.add_child(section_label)

	usable_battle_check = CheckBox.new()
	usable_battle_check.text = "Usable in Battle"
	consumable_section.add_child(usable_battle_check)

	usable_field_check = CheckBox.new()
	usable_field_check.text = "Usable on Field"
	consumable_section.add_child(usable_field_check)

	var note_label: Label = Label.new()
	note_label.text = "Note: Assign AbilityData effect in the Inspector"
	note_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	consumable_section.add_child(note_label)

	detail_panel.add_child(consumable_section)


func _add_economy_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Economy"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Buy Price
	var buy_container: HBoxContainer = HBoxContainer.new()
	var buy_label: Label = Label.new()
	buy_label.text = "Buy Price:"
	buy_label.custom_minimum_size.x = 150
	buy_container.add_child(buy_label)

	buy_price_spin = SpinBox.new()
	buy_price_spin.min_value = 0
	buy_price_spin.max_value = 999999
	buy_price_spin.value = 100
	buy_container.add_child(buy_price_spin)
	section.add_child(buy_container)

	# Sell Price
	var sell_container: HBoxContainer = HBoxContainer.new()
	var sell_label: Label = Label.new()
	sell_label.text = "Sell Price:"
	sell_label.custom_minimum_size.x = 150
	sell_container.add_child(sell_label)

	sell_price_spin = SpinBox.new()
	sell_price_spin.min_value = 0
	sell_price_spin.max_value = 999999
	sell_price_spin.value = 50
	sell_container.add_child(sell_price_spin)
	section.add_child(sell_container)

	detail_panel.add_child(section)


func _create_modifier_editor(label_text: String, parent: VBoxContainer) -> SpinBox:
	var container: HBoxContainer = HBoxContainer.new()

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 150
	container.add_child(label)

	var spin: SpinBox = SpinBox.new()
	spin.min_value = -999
	spin.max_value = 999
	spin.value = 0
	spin.allow_lesser = true
	spin.allow_greater = true
	container.add_child(spin)

	parent.add_child(container)
	return spin


func _on_item_type_changed(index: int) -> void:
	# Show/hide sections based on item type
	var item_type: ItemData.ItemType = index

	weapon_section.visible = (item_type == ItemData.ItemType.WEAPON)
	consumable_section.visible = (item_type == ItemData.ItemType.CONSUMABLE)

	# Curse section visible for equippable items (weapons, armor, accessories)
	var is_equippable: bool = (
		item_type == ItemData.ItemType.WEAPON or
		item_type == ItemData.ItemType.ARMOR or
		item_type == ItemData.ItemType.ACCESSORY
	)
	curse_section.visible = is_equippable


func _add_curse_section() -> void:
	curse_section = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Curse Properties"
	section_label.add_theme_font_size_override("font_size", 16)
	curse_section.add_child(section_label)

	# Is Cursed checkbox
	is_cursed_check = CheckBox.new()
	is_cursed_check.text = "Is Cursed (cannot be unequipped normally)"
	is_cursed_check.button_pressed = false
	is_cursed_check.toggled.connect(_on_cursed_toggled)
	curse_section.add_child(is_cursed_check)

	# Uncurse Items (comma-separated list)
	var uncurse_container: HBoxContainer = HBoxContainer.new()
	var uncurse_label: Label = Label.new()
	uncurse_label.text = "Uncurse Items:"
	uncurse_label.custom_minimum_size.x = 150
	uncurse_label.tooltip_text = "Item IDs that can remove this curse (comma-separated)"
	uncurse_container.add_child(uncurse_label)

	uncurse_items_edit = LineEdit.new()
	uncurse_items_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	uncurse_items_edit.placeholder_text = "e.g., purify_scroll, holy_water"
	uncurse_items_edit.editable = false  # Only enabled when cursed
	uncurse_container.add_child(uncurse_items_edit)
	curse_section.add_child(uncurse_container)

	var help_label: Label = Label.new()
	help_label.text = "Leave empty if only church service can remove curse"
	help_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	help_label.add_theme_font_size_override("font_size", 14)
	curse_section.add_child(help_label)

	detail_panel.add_child(curse_section)


func _on_cursed_toggled(pressed: bool) -> void:
	# Enable/disable uncurse items field based on curse state
	uncurse_items_edit.editable = pressed
	if not pressed:
		uncurse_items_edit.text = ""


func _populate_equipment_slot_options() -> void:
	equipment_slot_option.clear()

	# Try to get slots from ModLoader registry
	var slots: Array[Dictionary] = []
	if ModLoader and ModLoader.equipment_slot_registry:
		slots = ModLoader.equipment_slot_registry.get_slots()
	else:
		# Fallback to default SF-style slots
		slots = [
			{"id": "weapon", "display_name": "Weapon"},
			{"id": "ring_1", "display_name": "Ring 1"},
			{"id": "ring_2", "display_name": "Ring 2"},
			{"id": "accessory", "display_name": "Accessory"}
		]

	for slot: Dictionary in slots:
		var slot_id: String = slot.get("id", "")
		var display_name: String = slot.get("display_name", slot_id.capitalize())
		equipment_slot_option.add_item(display_name)
		equipment_slot_option.set_item_metadata(equipment_slot_option.item_count - 1, slot_id)


func _select_equipment_slot(slot_id: String) -> void:
	for i in range(equipment_slot_option.item_count):
		if equipment_slot_option.get_item_metadata(i) == slot_id:
			equipment_slot_option.select(i)
			return
	# Default to first item if not found
	if equipment_slot_option.item_count > 0:
		equipment_slot_option.select(0)


func _get_selected_equipment_slot() -> String:
	var selected: int = equipment_slot_option.selected
	if selected >= 0:
		return equipment_slot_option.get_item_metadata(selected)
	return "weapon"


func _parse_uncurse_items() -> Array[String]:
	var items: Array[String] = []
	var text: String = uncurse_items_edit.text.strip_edges()
	if text.is_empty():
		return items

	var parts: PackedStringArray = text.split(",")
	for part: String in parts:
		var trimmed: String = part.strip_edges()
		if not trimmed.is_empty():
			items.append(trimmed)
	return items
