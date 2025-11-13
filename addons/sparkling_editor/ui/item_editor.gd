@tool
extends Control

## Item Editor UI
## Allows browsing and editing ItemData resources

var item_list: ItemList
var item_detail: VBoxContainer
var current_item: ItemData

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
	_setup_ui()
	_refresh_item_list()


func _setup_ui() -> void:
	# Use size flags for proper editor panel expansion (no anchors needed)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var hsplit: HSplitContainer = HSplitContainer.new()
	hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(hsplit)

	# Left side: Item list
	var left_panel: VBoxContainer = VBoxContainer.new()
	left_panel.custom_minimum_size.x = 250

	var list_label: Label = Label.new()
	list_label.text = "Items"
	list_label.add_theme_font_size_override("font_size", 16)
	left_panel.add_child(list_label)

	var help_label: Label = Label.new()
	help_label.text = "Use Tools > Create New Item\nto get started"
	help_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	help_label.add_theme_font_size_override("font_size", 11)
	left_panel.add_child(help_label)

	item_list = ItemList.new()
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.custom_minimum_size = Vector2(200, 200)
	item_list.item_selected.connect(_on_item_selected)
	left_panel.add_child(item_list)

	var create_button: Button = Button.new()
	create_button.text = "Create New Item"
	create_button.pressed.connect(_on_create_new_item)
	left_panel.add_child(create_button)

	var refresh_button: Button = Button.new()
	refresh_button.text = "Refresh List"
	refresh_button.pressed.connect(_refresh_item_list)
	left_panel.add_child(refresh_button)

	hsplit.add_child(left_panel)

	# Right side: Item details
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	item_detail = VBoxContainer.new()
	item_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var detail_label: Label = Label.new()
	detail_label.text = "Item Details"
	detail_label.add_theme_font_size_override("font_size", 18)
	item_detail.add_child(detail_label)

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

	# Save button
	var save_button: Button = Button.new()
	save_button.text = "Save Changes"
	save_button.pressed.connect(_save_current_item)
	item_detail.add_child(save_button)

	scroll.add_child(item_detail)
	hsplit.add_child(scroll)


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

	item_detail.add_child(section)


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

	item_detail.add_child(section)


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

	item_detail.add_child(weapon_section)


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

	item_detail.add_child(consumable_section)


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

	item_detail.add_child(section)


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


func _refresh_item_list() -> void:
	item_list.clear()

	var dir: DirAccess = DirAccess.open("res://data/items/")
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var item: ItemData = load("res://data/items/" + file_name)
				if item:
					item_list.add_item(item.item_name)
					item_list.set_item_metadata(item_list.item_count - 1, "res://data/items/" + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()


func _on_item_selected(index: int) -> void:
	var path: String = item_list.get_item_metadata(index)
	current_item = load(path)
	_load_item_data()


func _load_item_data() -> void:
	if not current_item:
		return

	name_edit.text = current_item.item_name
	item_type_option.selected = current_item.item_type
	equipment_type_edit.text = current_item.equipment_type
	durability_spin.value = current_item.durability
	description_edit.text = current_item.description

	# Stat modifiers
	hp_mod_spin.value = current_item.hp_modifier
	mp_mod_spin.value = current_item.mp_modifier
	str_mod_spin.value = current_item.strength_modifier
	def_mod_spin.value = current_item.defense_modifier
	agi_mod_spin.value = current_item.agility_modifier
	int_mod_spin.value = current_item.intelligence_modifier
	luk_mod_spin.value = current_item.luck_modifier

	# Weapon properties
	attack_power_spin.value = current_item.attack_power
	attack_range_spin.value = current_item.attack_range
	hit_rate_spin.value = current_item.hit_rate
	crit_rate_spin.value = current_item.critical_rate

	# Consumable properties
	usable_battle_check.button_pressed = current_item.usable_in_battle
	usable_field_check.button_pressed = current_item.usable_on_field

	# Economy
	buy_price_spin.value = current_item.buy_price
	sell_price_spin.value = current_item.sell_price

	# Update section visibility
	_on_item_type_changed(current_item.item_type)


func _save_current_item() -> void:
	if not current_item:
		push_warning("No item selected")
		return

	# Update item data from UI
	current_item.item_name = name_edit.text
	current_item.item_type = item_type_option.selected
	current_item.equipment_type = equipment_type_edit.text
	current_item.durability = int(durability_spin.value)
	current_item.description = description_edit.text

	# Update stat modifiers
	current_item.hp_modifier = int(hp_mod_spin.value)
	current_item.mp_modifier = int(mp_mod_spin.value)
	current_item.strength_modifier = int(str_mod_spin.value)
	current_item.defense_modifier = int(def_mod_spin.value)
	current_item.agility_modifier = int(agi_mod_spin.value)
	current_item.intelligence_modifier = int(int_mod_spin.value)
	current_item.luck_modifier = int(luk_mod_spin.value)

	# Update weapon properties
	current_item.attack_power = int(attack_power_spin.value)
	current_item.attack_range = int(attack_range_spin.value)
	current_item.hit_rate = int(hit_rate_spin.value)
	current_item.critical_rate = int(crit_rate_spin.value)

	# Update consumable properties
	current_item.usable_in_battle = usable_battle_check.button_pressed
	current_item.usable_on_field = usable_field_check.button_pressed

	# Update economy
	current_item.buy_price = int(buy_price_spin.value)
	current_item.sell_price = int(sell_price_spin.value)

	# Save to file
	var path: String = item_list.get_item_metadata(item_list.get_selected_items()[0])
	var err: Error = ResourceSaver.save(current_item, path)
	if err == OK:
		print("Item saved successfully")
	else:
		push_error("Failed to save item: " + str(err))


func _on_create_new_item() -> void:
	# Create a new item
	var new_item: ItemData = ItemData.new()
	new_item.item_name = "New Item"
	new_item.item_type = ItemData.ItemType.WEAPON

	# Generate unique filename
	var timestamp: int = Time.get_unix_time_from_system()
	var filename: String = "item_%d.tres" % timestamp
	var full_path: String = "res://data/items/" + filename

	# Save the resource
	var err: Error = ResourceSaver.save(new_item, full_path)
	if err == OK:
		print("Created new item at ", full_path)
		# Force Godot to rescan filesystem and reload the resource
		EditorInterface.get_resource_filesystem().scan()
		# Wait a frame for the scan to complete, then refresh
		await get_tree().process_frame
		_refresh_item_list()
	else:
		push_error("Failed to create item: " + str(err))
