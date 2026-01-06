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
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.add_section("Basic Information")

	# Name
	name_edit = form.add_text_field("Item Name:", "",
		"Display name shown in menus and shops. E.g., Steel Sword, Healing Herb.")
	name_edit.max_length = 64

	# Icon picker (custom composite control)
	var icon_container: HBoxContainer = HBoxContainer.new()

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

	form.add_labeled_control("Icon:", icon_container, "Item icon displayed in menus and inventory")

	# Item Type
	item_type_option = OptionButton.new()
	item_type_option.add_item("Weapon", ItemData.ItemType.WEAPON)
	item_type_option.add_item("Accessory", ItemData.ItemType.ACCESSORY)
	item_type_option.add_item("Consumable", ItemData.ItemType.CONSUMABLE)
	item_type_option.add_item("Key Item", ItemData.ItemType.KEY_ITEM)
	item_type_option.item_selected.connect(_on_item_type_changed)
	form.add_labeled_control("Item Type:", item_type_option,
		"Weapon = equippable attack. Accessory = ring/trinket (SF2-authentic). Consumable = one-use. Key = quest item.")

	# Equipment Type
	equipment_type_edit = form.add_text_field("Equipment Type:", "e.g., sword, ring",
		"Category for class restrictions. Weapons: sword, axe, bow, staff. Accessories: ring, amulet.")

	# Equipment Slot
	equipment_slot_option = OptionButton.new()
	equipment_slot_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_populate_equipment_slot_options()
	form.add_labeled_control("Equipment Slot:", equipment_slot_option,
		"Which character slot this item occupies. Weapon = main hand. Ring/Accessory = accessory slots.")

	form.add_help_text("Type = weapon/accessory category (sword, ring). Slot = where equipped (weapon, ring_1, ring_2).")

	# Description
	description_edit = form.add_text_area("Description:", 120,
		"Flavor text shown when examining the item. Describe effects, lore, or usage hints.")


func _add_stat_modifiers_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.add_section("Stat Modifiers")

	hp_mod_spin = form.add_number_field("HP:", -999, 999, 0,
		"Bonus HP when equipped. Positive = more health, negative = less. Typical: +5 to +20.")
	mp_mod_spin = form.add_number_field("MP:", -999, 999, 0,
		"Bonus MP when equipped. Useful for caster accessories. Typical: +5 to +15.")
	str_mod_spin = form.add_number_field("Strength:", -999, 999, 0,
		"Bonus physical attack power. Weapons typically add +5 to +30.")
	def_mod_spin = form.add_number_field("Defense:", -999, 999, 0,
		"Bonus defense. Armor typically adds +3 to +15.")
	agi_mod_spin = form.add_number_field("Agility:", -999, 999, 0,
		"Bonus agility (speed/evasion). Some weapons may reduce this as a tradeoff.")
	int_mod_spin = form.add_number_field("Intelligence:", -999, 999, 0,
		"Bonus magic power. Staves/tomes add to spell damage.")
	luk_mod_spin = form.add_number_field("Luck:", -999, 999, 0,
		"Bonus luck (crits/drops). Usually small bonuses from accessories.")


func _add_weapon_section() -> void:
	weapon_section = VBoxContainer.new()
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(weapon_section)
	form.add_section("Weapon Properties")

	attack_power_spin = form.add_number_field("Attack Power:", 0, 999, 10,
		"Base damage added to attacks. Typical: 5-15 early game, 20-40 mid, 50+ late game.")

	min_attack_range_spin = form.add_number_field("Min Attack Range:", 1, 20, 1,
		"Closest distance this weapon can hit. 1 = adjacent. 2+ = cannot hit adjacent targets (bow dead zone).")
	min_attack_range_spin.value_changed.connect(_on_min_range_changed)

	max_attack_range_spin = form.add_number_field("Max Attack Range:", 1, 20, 1,
		"Farthest distance this weapon can hit. 1 = melee only. 2-3 = short range. 4+ = long range.")
	max_attack_range_spin.value_changed.connect(_on_max_range_changed)

	form.add_help_text("Sword: 1-1 | Spear: 1-2 | Bow: 2-3 | Crossbow: 2-4")

	hit_rate_spin = form.add_number_field("Hit Rate (%):", 0, 100, 90,
		"Base accuracy percentage. 90% = reliable. 70% = inaccurate but powerful. Combined with character AGI.")

	crit_rate_spin = form.add_number_field("Critical Rate (%):", 0, 100, 5,
		"Chance for double damage. Typical: 5% normal, 15% for killer weapons, 25%+ for crit-focused builds.")

	detail_panel.add_child(weapon_section)


func _add_consumable_section() -> void:
	consumable_section = VBoxContainer.new()
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(consumable_section)
	form.add_section("Consumable Properties")

	usable_battle_check = form.add_standalone_checkbox("Usable in Battle", false,
		"Can be used during combat. E.g., Healing Herb during a unit's turn.")

	usable_field_check = form.add_standalone_checkbox("Usable on Field", false,
		"Can be used from the menu outside of battle. E.g., healing items in town.")

	# Effect picker - allows selecting an AbilityData resource for the consumable effect
	effect_picker = ResourcePicker.new()
	effect_picker.resource_type = "ability"
	effect_picker.label_text = "Effect:"
	effect_picker.label_min_width = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	effect_picker.allow_none = true
	effect_picker.none_text = "(No Effect)"
	form.add_labeled_control("", effect_picker,
		"Ability that activates when used. Create abilities for healing, buffs, damage, etc.")

	form.add_help_text("The ability that activates when this item is used")

	detail_panel.add_child(consumable_section)


func _add_economy_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.add_section("Economy")

	buy_price_spin = form.add_number_field("Buy Price:", 0, 999999, 100,
		"Cost to purchase from shops. Set to 0 for items that cannot be bought.")

	sell_price_spin = form.add_number_field("Sell Price:", 0, 999999, 50,
		"Gold received when selling. Typically 50% of buy price. Set to 0 for unsellable items.")


func _add_item_management_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.add_section("Item Management")

	is_crafting_material_check = form.add_standalone_checkbox("Is Crafting Material", false,
		"Check if this item is a crafting material (mithril, dragon scales, etc.) that can be used at crafter NPCs to create equipment")

	form.add_help_text("Crafting materials can be combined at crafter NPCs to forge new equipment")


func _on_item_type_changed(index: int) -> void:
	# Show/hide sections based on item type
	var item_type: ItemData.ItemType = index

	weapon_section.visible = (item_type == ItemData.ItemType.WEAPON)
	consumable_section.visible = (item_type == ItemData.ItemType.CONSUMABLE)

	# Curse section visible for equippable items (weapons, accessories)
	var is_equippable: bool = (
		item_type == ItemData.ItemType.WEAPON or
		item_type == ItemData.ItemType.ACCESSORY
	)
	curse_section.visible = is_equippable


func _add_curse_section() -> void:
	curse_section = VBoxContainer.new()
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(curse_section)
	form.add_section("Curse Properties")

	is_cursed_check = form.add_standalone_checkbox("Is Cursed (cannot be unequipped normally)", false,
		"Cursed items lock to the character. Often powerful but with drawbacks. Requires special items or church to remove.")
	is_cursed_check.toggled.connect(_on_cursed_toggled)

	uncurse_items_edit = form.add_text_field("Uncurse Items:", "e.g., purify_scroll, holy_water",
		"Item IDs (comma-separated) that can remove this curse. Leave empty if only church/NPC can uncurse.")
	uncurse_items_edit.editable = false  # Only enabled when cursed

	form.add_help_text("Leave empty if only church service can remove curse")

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
		var slot_id: String = DictUtils.get_string(slot, "id", "")
		var display_name: String = DictUtils.get_string(slot, "display_name", slot_id.capitalize())
		equipment_slot_option.add_item(display_name)
		equipment_slot_option.set_item_metadata(equipment_slot_option.item_count - 1, slot_id)


func _select_equipment_slot(slot_id: String) -> void:
	for i: int in range(equipment_slot_option.item_count):
		if equipment_slot_option.get_item_metadata(i) == slot_id:
			equipment_slot_option.select(i)
			return
	# Default to first item if not found
	if equipment_slot_option.item_count > 0:
		equipment_slot_option.select(0)


func _get_selected_equipment_slot() -> String:
	var selected: int = equipment_slot_option.selected
	if selected >= 0:
		var metadata: Variant = equipment_slot_option.get_item_metadata(selected)
		if metadata is String:
			return metadata
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
