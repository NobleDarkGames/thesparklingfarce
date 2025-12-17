@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Item Editor UI
## Allows browsing and editing ItemData resources

var name_edit: LineEdit
var icon_preview: TextureRect
var icon_path_edit: LineEdit
var icon_clear_btn: Button
var icon_file_dialog: EditorFileDialog
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
var min_attack_range_spin: SpinBox
var max_attack_range_spin: SpinBox
var hit_rate_spin: SpinBox
var crit_rate_spin: SpinBox

# Consumable properties
var consumable_section: VBoxContainer
var usable_battle_check: CheckBox
var usable_field_check: CheckBox
var effect_picker: ResourcePicker  # AbilityData picker for consumable effect

# Economy
var buy_price_spin: SpinBox
var sell_price_spin: SpinBox

# Item Management
var is_crafting_material_check: CheckBox


func _ready() -> void:
	resource_type_id = "item"
	resource_type_name = "Item"
	# resource_directory is set dynamically via base class using ModLoader.get_active_mod()
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

	# Item Management section
	_add_item_management_section()

	# Add the button container at the end (with separator for visual clarity)
	_add_button_container_to_detail_panel()


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

	# Icon
	if item.icon:
		icon_path_edit.text = item.icon.resource_path
		icon_preview.texture = item.icon
		icon_preview.tooltip_text = item.icon.resource_path
	else:
		icon_path_edit.text = ""
		icon_preview.texture = null
		icon_preview.tooltip_text = "No icon assigned"

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
	min_attack_range_spin.value = item.min_attack_range
	max_attack_range_spin.value = item.max_attack_range
	hit_rate_spin.value = item.hit_rate
	crit_rate_spin.value = item.critical_rate

	# Consumable properties
	usable_battle_check.button_pressed = item.usable_in_battle
	usable_field_check.button_pressed = item.usable_on_field

	# Effect picker
	if item.effect and item.effect is AbilityData:
		effect_picker.select_resource(item.effect)
	else:
		effect_picker.select_none()

	# Economy
	buy_price_spin.value = item.buy_price
	sell_price_spin.value = item.sell_price

	# Item Management
	if is_crafting_material_check:
		is_crafting_material_check.button_pressed = item.is_crafting_material

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

	# Update icon
	var icon_path: String = icon_path_edit.text.strip_edges()
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		item.icon = load(icon_path) as Texture2D
	else:
		item.icon = null

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
	item.min_attack_range = int(min_attack_range_spin.value)
	item.max_attack_range = int(max_attack_range_spin.value)
	item.hit_rate = int(hit_rate_spin.value)
	item.critical_rate = int(crit_rate_spin.value)

	# Update consumable properties
	item.usable_in_battle = usable_battle_check.button_pressed
	item.usable_on_field = usable_field_check.button_pressed

	# Update effect
	item.effect = effect_picker.get_selected_resource()

	# Update economy
	item.buy_price = int(buy_price_spin.value)
	item.sell_price = int(sell_price_spin.value)

	# Update item management
	if is_crafting_material_check:
		item.is_crafting_material = is_crafting_material_check.button_pressed


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

	# Check all characters across all mods for references to this item in their equipment arrays
	var character_files: Array[Dictionary] = _scan_all_mods_for_resource_type("character")
	for file_info: Dictionary in character_files:
		var character: CharacterData = load(file_info.path) as CharacterData
		if character and item_to_check in character.starting_equipment:
			references.append(file_info.path)

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
	name_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	name_container.add_child(name_label)

	name_edit = LineEdit.new()
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.tooltip_text = "Display name shown in menus and shops. E.g., Steel Sword, Healing Herb."
	name_container.add_child(name_edit)
	section.add_child(name_container)

	# Icon picker (placed right after name - icon is part of item identity)
	var icon_container: HBoxContainer = HBoxContainer.new()
	var icon_label: Label = Label.new()
	icon_label.text = "Icon:"
	icon_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	icon_container.add_child(icon_label)

	# Preview at actual game size (32x32) with border
	var preview_panel: PanelContainer = PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(36, 36)
	var preview_style: StyleBoxFlat = StyleBoxFlat.new()
	preview_style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	preview_style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	preview_style.set_border_width_all(1)
	preview_style.set_content_margin_all(2)
	preview_panel.add_theme_stylebox_override("panel", preview_style)

	icon_preview = TextureRect.new()
	icon_preview.custom_minimum_size = Vector2(32, 32)
	icon_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_panel.add_child(icon_preview)
	icon_container.add_child(preview_panel)

	# Path display (editable for power users)
	icon_path_edit = LineEdit.new()
	icon_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_path_edit.placeholder_text = "res://mods/.../assets/icons/items/sword.png"
	icon_path_edit.text_changed.connect(_on_icon_path_changed)
	icon_container.add_child(icon_path_edit)

	# Browse button
	var browse_button: Button = Button.new()
	browse_button.text = "Browse..."
	browse_button.pressed.connect(_on_browse_icon)
	icon_container.add_child(browse_button)

	# Clear button
	icon_clear_btn = Button.new()
	icon_clear_btn.text = "X"
	icon_clear_btn.tooltip_text = "Clear icon"
	icon_clear_btn.pressed.connect(_on_clear_icon)
	icon_container.add_child(icon_clear_btn)

	section.add_child(icon_container)

	# Item Type
	var type_container: HBoxContainer = HBoxContainer.new()
	var type_label: Label = Label.new()
	type_label.text = "Item Type:"
	type_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	type_container.add_child(type_label)

	item_type_option = OptionButton.new()
	item_type_option.tooltip_text = "Weapon = equippable attack. Armor = equippable defense. Accessory = ring/trinket. Consumable = one-use. Key = quest item."
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
	equip_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	equip_label.tooltip_text = "For weapons: sword, axe, bow, etc.\nFor armor: light, heavy, robe, etc."
	equip_container.add_child(equip_label)

	equipment_type_edit = LineEdit.new()
	equipment_type_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_type_edit.placeholder_text = "e.g., sword, light armor"
	equipment_type_edit.tooltip_text = "Category for class restrictions. Weapons: sword, axe, bow, staff. Armor: light, heavy, robe."
	equip_container.add_child(equipment_type_edit)
	section.add_child(equip_container)

	# Equipment Slot
	var slot_container: HBoxContainer = HBoxContainer.new()
	var slot_label: Label = Label.new()
	slot_label.text = "Equipment Slot:"
	slot_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	slot_label.tooltip_text = "Which slot this item occupies when equipped"
	slot_container.add_child(slot_label)

	equipment_slot_option = OptionButton.new()
	equipment_slot_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_slot_option.tooltip_text = "Which character slot this item occupies. Weapon = main hand. Ring/Accessory = accessory slots."
	_populate_equipment_slot_options()
	slot_container.add_child(equipment_slot_option)
	section.add_child(slot_container)

	# Help text explaining equipment type vs slot
	var equip_help: Label = Label.new()
	equip_help.text = "Type = weapon/armor category (sword, light, heavy). Slot = where equipped (main_hand, body, accessory)."
	equip_help.add_theme_color_override("font_color", EditorThemeUtils.get_help_color())
	equip_help.add_theme_font_size_override("font_size", EditorThemeUtils.HELP_FONT_SIZE)
	equip_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(equip_help)

	# Description
	var desc_label: Label = Label.new()
	desc_label.text = "Description:"
	section.add_child(desc_label)

	description_edit = TextEdit.new()
	description_edit.custom_minimum_size.y = 120
	description_edit.tooltip_text = "Flavor text shown when examining the item. Describe effects, lore, or usage hints."
	section.add_child(description_edit)

	detail_panel.add_child(section)


func _add_stat_modifiers_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Stat Modifiers"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	hp_mod_spin = _create_modifier_editor("HP:", section, "Bonus HP when equipped. Positive = more health, negative = less. Typical: +5 to +20.")
	mp_mod_spin = _create_modifier_editor("MP:", section, "Bonus MP when equipped. Useful for caster accessories. Typical: +5 to +15.")
	str_mod_spin = _create_modifier_editor("Strength:", section, "Bonus physical attack power. Weapons typically add +5 to +30.")
	def_mod_spin = _create_modifier_editor("Defense:", section, "Bonus defense. Armor typically adds +3 to +15.")
	agi_mod_spin = _create_modifier_editor("Agility:", section, "Bonus agility (speed/evasion). Some weapons may reduce this as a tradeoff.")
	int_mod_spin = _create_modifier_editor("Intelligence:", section, "Bonus magic power. Staves/tomes add to spell damage.")
	luk_mod_spin = _create_modifier_editor("Luck:", section, "Bonus luck (crits/drops). Usually small bonuses from accessories.")

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
	power_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	power_container.add_child(power_label)

	attack_power_spin = SpinBox.new()
	attack_power_spin.min_value = 0
	attack_power_spin.max_value = 999
	attack_power_spin.value = 10
	attack_power_spin.tooltip_text = "Base damage added to attacks. Typical: 5-15 early game, 20-40 mid, 50+ late game."
	power_container.add_child(attack_power_spin)
	weapon_section.add_child(power_container)

	# Min Attack Range
	var min_range_container: HBoxContainer = HBoxContainer.new()
	var min_range_label: Label = Label.new()
	min_range_label.text = "Min Attack Range:"
	min_range_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	min_range_label.tooltip_text = "Minimum attack distance. Set to 2+ for ranged weapons with dead zones (cannot hit adjacent)."
	min_range_container.add_child(min_range_label)

	min_attack_range_spin = SpinBox.new()
	min_attack_range_spin.min_value = 1
	min_attack_range_spin.max_value = 20
	min_attack_range_spin.value = 1
	min_attack_range_spin.tooltip_text = "Closest distance this weapon can hit. 1 = adjacent. 2+ = cannot hit adjacent targets (bow dead zone)."
	min_attack_range_spin.value_changed.connect(_on_min_range_changed)
	min_range_container.add_child(min_attack_range_spin)
	weapon_section.add_child(min_range_container)

	# Max Attack Range
	var max_range_container: HBoxContainer = HBoxContainer.new()
	var max_range_label: Label = Label.new()
	max_range_label.text = "Max Attack Range:"
	max_range_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	max_range_label.tooltip_text = "Maximum attack distance. Set to 1 for melee, higher for ranged weapons."
	max_range_container.add_child(max_range_label)

	max_attack_range_spin = SpinBox.new()
	max_attack_range_spin.min_value = 1
	max_attack_range_spin.max_value = 20
	max_attack_range_spin.value = 1
	max_attack_range_spin.tooltip_text = "Farthest distance this weapon can hit. 1 = melee only. 2-3 = short range. 4+ = long range."
	max_attack_range_spin.value_changed.connect(_on_max_range_changed)
	max_range_container.add_child(max_attack_range_spin)
	weapon_section.add_child(max_range_container)

	# Range presets help label
	var range_help: Label = Label.new()
	range_help.text = "Sword: 1-1 | Spear: 1-2 | Bow: 2-3 | Crossbow: 2-4"
	range_help.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	range_help.add_theme_font_size_override("font_size", 12)
	weapon_section.add_child(range_help)

	# Hit Rate
	var hit_container: HBoxContainer = HBoxContainer.new()
	var hit_label: Label = Label.new()
	hit_label.text = "Hit Rate (%):"
	hit_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	hit_container.add_child(hit_label)

	hit_rate_spin = SpinBox.new()
	hit_rate_spin.min_value = 0
	hit_rate_spin.max_value = 100
	hit_rate_spin.value = 90
	hit_rate_spin.tooltip_text = "Base accuracy percentage. 90% = reliable. 70% = inaccurate but powerful. Combined with character AGI."
	hit_container.add_child(hit_rate_spin)
	weapon_section.add_child(hit_container)

	# Critical Rate
	var crit_container: HBoxContainer = HBoxContainer.new()
	var crit_label: Label = Label.new()
	crit_label.text = "Critical Rate (%):"
	crit_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	crit_container.add_child(crit_label)

	crit_rate_spin = SpinBox.new()
	crit_rate_spin.min_value = 0
	crit_rate_spin.max_value = 100
	crit_rate_spin.value = 5
	crit_rate_spin.tooltip_text = "Chance for double damage. Typical: 5% normal, 15% for killer weapons, 25%+ for crit-focused builds."
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
	usable_battle_check.tooltip_text = "Can be used during combat. E.g., Healing Herb during a unit's turn."
	consumable_section.add_child(usable_battle_check)

	usable_field_check = CheckBox.new()
	usable_field_check.text = "Usable on Field"
	usable_field_check.tooltip_text = "Can be used from the menu outside of battle. E.g., healing items in town."
	consumable_section.add_child(usable_field_check)

	# Effect picker - allows selecting an AbilityData resource for the consumable effect
	effect_picker = ResourcePicker.new()
	effect_picker.resource_type = "ability"
	effect_picker.label_text = "Effect:"
	effect_picker.label_min_width = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	effect_picker.allow_none = true
	effect_picker.none_text = "(No Effect)"
	effect_picker.tooltip_text = "Ability that activates when used. Create abilities for healing, buffs, damage, etc."
	consumable_section.add_child(effect_picker)

	var help_label: Label = Label.new()
	help_label.text = "The ability that activates when this item is used"
	help_label.add_theme_color_override("font_color", EditorThemeUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", EditorThemeUtils.HELP_FONT_SIZE)
	consumable_section.add_child(help_label)

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
	buy_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	buy_container.add_child(buy_label)

	buy_price_spin = SpinBox.new()
	buy_price_spin.min_value = 0
	buy_price_spin.max_value = 999999
	buy_price_spin.value = 100
	buy_price_spin.tooltip_text = "Cost to purchase from shops. Set to 0 for items that cannot be bought."
	buy_container.add_child(buy_price_spin)
	section.add_child(buy_container)

	# Sell Price
	var sell_container: HBoxContainer = HBoxContainer.new()
	var sell_label: Label = Label.new()
	sell_label.text = "Sell Price:"
	sell_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	sell_container.add_child(sell_label)

	sell_price_spin = SpinBox.new()
	sell_price_spin.min_value = 0
	sell_price_spin.max_value = 999999
	sell_price_spin.value = 50
	sell_price_spin.tooltip_text = "Gold received when selling. Typically 50% of buy price. Set to 0 for unsellable items."
	sell_container.add_child(sell_price_spin)
	section.add_child(sell_container)

	detail_panel.add_child(section)


func _add_item_management_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Item Management"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Is Crafting Material checkbox
	is_crafting_material_check = CheckBox.new()
	is_crafting_material_check.text = "Is Crafting Material"
	is_crafting_material_check.tooltip_text = "Check if this item is a crafting material (mithril, dragon scales, etc.) that can be used at crafter NPCs to create equipment"
	section.add_child(is_crafting_material_check)

	var help_label: Label = Label.new()
	help_label.text = "Crafting materials can be combined at crafter NPCs to forge new equipment"
	help_label.add_theme_color_override("font_color", EditorThemeUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", EditorThemeUtils.HELP_FONT_SIZE)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(help_label)

	detail_panel.add_child(section)


func _create_modifier_editor(label_text: String, parent: VBoxContainer, tooltip: String = "") -> SpinBox:
	var container: HBoxContainer = HBoxContainer.new()

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	if not tooltip.is_empty():
		label.tooltip_text = tooltip
	container.add_child(label)

	var spin: SpinBox = SpinBox.new()
	spin.min_value = -999
	spin.max_value = 999
	spin.value = 0
	spin.allow_lesser = true
	spin.allow_greater = true
	if not tooltip.is_empty():
		spin.tooltip_text = tooltip
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
	is_cursed_check.tooltip_text = "Cursed items lock to the character. Often powerful but with drawbacks. Requires special items or church to remove."
	is_cursed_check.toggled.connect(_on_cursed_toggled)
	curse_section.add_child(is_cursed_check)

	# Uncurse Items (comma-separated list)
	var uncurse_container: HBoxContainer = HBoxContainer.new()
	var uncurse_label: Label = Label.new()
	uncurse_label.text = "Uncurse Items:"
	uncurse_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	uncurse_label.tooltip_text = "Item IDs that can remove this curse (comma-separated)"
	uncurse_container.add_child(uncurse_label)

	uncurse_items_edit = LineEdit.new()
	uncurse_items_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	uncurse_items_edit.placeholder_text = "e.g., purify_scroll, holy_water"
	uncurse_items_edit.tooltip_text = "Item IDs (comma-separated) that can remove this curse. Leave empty if only church/NPC can uncurse."
	uncurse_items_edit.editable = false  # Only enabled when cursed
	uncurse_container.add_child(uncurse_items_edit)
	curse_section.add_child(uncurse_container)

	var help_label: Label = Label.new()
	help_label.text = "Leave empty if only church service can remove curse"
	help_label.add_theme_color_override("font_color", EditorThemeUtils.get_help_color())
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


# =============================================================================
# ICON PICKER
# =============================================================================

func _on_browse_icon() -> void:
	if not icon_file_dialog:
		icon_file_dialog = EditorFileDialog.new()
		icon_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		icon_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		icon_file_dialog.filters = PackedStringArray(["*.png ; PNG Images", "*.webp ; WebP Images", "*.jpg ; JPEG Images"])
		# Safety check before connecting (prevents duplicates on plugin reload)
		if not icon_file_dialog.file_selected.is_connected(_on_icon_file_selected):
			icon_file_dialog.file_selected.connect(_on_icon_file_selected)
		add_child(icon_file_dialog)

	# Default to active mod's icon directory if available
	var default_path: String = "res://mods/"
	var active_mod_dir: String = _get_active_mod_directory()
	if not active_mod_dir.is_empty():
		var icons_dir: String = active_mod_dir.path_join("assets/icons/")
		if DirAccess.dir_exists_absolute(icons_dir):
			default_path = icons_dir
		else:
			var assets_dir: String = active_mod_dir.path_join("assets/")
			if DirAccess.dir_exists_absolute(assets_dir):
				default_path = assets_dir
			else:
				default_path = active_mod_dir

	icon_file_dialog.current_dir = default_path
	icon_file_dialog.popup_centered_ratio(0.7)


func _on_icon_file_selected(path: String) -> void:
	icon_path_edit.text = path
	_load_icon_from_path(path)


func _on_icon_path_changed(new_text: String) -> void:
	_load_icon_from_path(new_text)


func _load_icon_from_path(path: String) -> void:
	var clean_path: String = path.strip_edges()
	if clean_path.is_empty():
		icon_preview.texture = null
		icon_preview.tooltip_text = "No icon assigned"
		return

	if ResourceLoader.exists(clean_path):
		var texture: Texture2D = load(clean_path) as Texture2D
		icon_preview.texture = texture
		icon_preview.tooltip_text = clean_path

		# Warn if icon is oversized (but allow it)
		if texture and (texture.get_width() > 64 or texture.get_height() > 64):
			push_warning("Item icon '%s' is %dx%d - recommend 32x32 or smaller for crisp display" % [
				clean_path.get_file(), texture.get_width(), texture.get_height()])
	else:
		icon_preview.texture = null
		icon_preview.tooltip_text = "File not found: " + clean_path


func _on_clear_icon() -> void:
	icon_path_edit.text = ""
	icon_preview.texture = null
	icon_preview.tooltip_text = "No icon assigned"


# =============================================================================
# RANGE VALIDATION
# =============================================================================

## Ensure min_attack_range never exceeds max_attack_range
func _on_min_range_changed(value: float) -> void:
	if max_attack_range_spin and value > max_attack_range_spin.value:
		# Increase max to match min
		max_attack_range_spin.value = value


## Ensure max_attack_range is never less than min_attack_range
func _on_max_range_changed(value: float) -> void:
	if min_attack_range_spin and value < min_attack_range_spin.value:
		# Decrease min to match max
		min_attack_range_spin.value = value
