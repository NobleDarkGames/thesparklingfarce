@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Item Editor UI
## Allows browsing and editing ItemData resources

var name_edit: LineEdit
var item_type_option: OptionButton
var equipment_type_edit: LineEdit
var durability_spin: SpinBox
var description_edit: TextEdit

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
	resource_directory = "res://data/items/"
	resource_type_name = "Item"
	super._ready()


## Override: Create the item-specific detail form
func _create_detail_form() -> void:
	# Basic info section
	_add_basic_info_section()

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
	durability_spin.value = item.durability
	description_edit.text = item.description

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
	item.durability = int(durability_spin.value)
	item.description = description_edit.text

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
	var dir: DirAccess = DirAccess.open("res://data/characters/")
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var character: CharacterData = load("res://data/characters/" + file_name)
				if character:
					if item_to_check in character.starting_equipment:
						references.append("res://data/characters/" + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

	# TODO: In Phase 2+, also check shop inventories, treasure chests, etc.

	return references


## Override: Create a new item with defaults
func _create_new_resource() -> Resource:
	var new_item: ItemData = ItemData.new()
	new_item.item_name = "New Item"
	new_item.item_type = ItemData.ItemType.WEAPON
	new_item.durability = -1
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
	section_label.add_theme_font_size_override("font_size", 14)
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

	# Durability
	var dur_container: HBoxContainer = HBoxContainer.new()
	var dur_label: Label = Label.new()
	dur_label.text = "Durability:"
	dur_label.custom_minimum_size.x = 150
	dur_label.tooltip_text = "Number of uses (-1 for unlimited)"
	dur_container.add_child(dur_label)

	durability_spin = SpinBox.new()
	durability_spin.min_value = -1
	durability_spin.max_value = 999
	durability_spin.value = -1
	dur_container.add_child(durability_spin)
	section.add_child(dur_container)

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
	section_label.add_theme_font_size_override("font_size", 14)
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
	section_label.add_theme_font_size_override("font_size", 14)
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
	section_label.add_theme_font_size_override("font_size", 14)
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
	section_label.add_theme_font_size_override("font_size", 14)
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
