@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Class Editor UI
## Allows browsing and editing ClassData resources

var name_edit: LineEdit
var movement_type_option: OptionButton
var movement_range_spin: SpinBox
var promotion_level_spin: SpinBox
var promotion_class_option: OptionButton

# Growth rate editors
var hp_growth_slider: HSlider
var mp_growth_slider: HSlider
var str_growth_slider: HSlider
var def_growth_slider: HSlider
var agi_growth_slider: HSlider
var int_growth_slider: HSlider
var luk_growth_slider: HSlider

var weapon_types_container: VBoxContainer
var armor_types_container: VBoxContainer

# Learnable abilities UI
var learnable_abilities_container: VBoxContainer
var add_ability_button: Button


func _ready() -> void:
	resource_type_name = "Class"
	resource_type_id = "class"
	# resource_directory is set dynamically via base class using ModLoader.get_active_mod()
	super._ready()


## Override: Create the class-specific detail form
func _create_detail_form() -> void:
	# Basic info section
	_add_basic_info_section()

	# Movement section
	_add_movement_section()

	# Growth rates section
	_add_growth_rates_section()

	# Equipment section
	_add_equipment_section()

	# Promotion section
	_add_promotion_section()

	# Learnable abilities section
	_add_learnable_abilities_section()

	# Add the button container at the end
	detail_panel.add_child(button_container)


## Override: Load class data from resource into UI
func _load_resource_data() -> void:
	var class_data: ClassData = current_resource as ClassData
	if not class_data:
		return

	name_edit.text = class_data.display_name
	movement_type_option.selected = class_data.movement_type
	movement_range_spin.value = class_data.movement_range
	promotion_level_spin.value = class_data.promotion_level

	# Set growth rates
	hp_growth_slider.value = class_data.hp_growth
	mp_growth_slider.value = class_data.mp_growth
	str_growth_slider.value = class_data.strength_growth
	def_growth_slider.value = class_data.defense_growth
	agi_growth_slider.value = class_data.agility_growth
	int_growth_slider.value = class_data.intelligence_growth
	luk_growth_slider.value = class_data.luck_growth

	# Update promotion class options first
	_update_promotion_options()

	# Set promotion class
	if class_data.promotion_class:
		for i in range(available_resources.size()):
			if available_resources[i] == class_data.promotion_class:
				promotion_class_option.selected = i + 1
				break
	else:
		promotion_class_option.selected = 0

	# Set weapon types
	for child in weapon_types_container.get_children():
		if child is CheckBox:
			var type_name: String = child.get_meta("equipment_type")
			child.button_pressed = type_name in class_data.equippable_weapon_types

	# Set armor types
	for child in armor_types_container.get_children():
		if child is CheckBox:
			var type_name: String = child.get_meta("equipment_type")
			child.button_pressed = type_name in class_data.equippable_armor_types

	# Load learnable abilities
	_load_learnable_abilities(class_data.learnable_abilities)


## Override: Save UI data to resource
func _save_resource_data() -> void:
	var class_data: ClassData = current_resource as ClassData
	if not class_data:
		return

	# Update class data from UI
	class_data.display_name = name_edit.text
	class_data.movement_type = movement_type_option.selected
	class_data.movement_range = int(movement_range_spin.value)
	class_data.promotion_level = int(promotion_level_spin.value)

	# Update growth rates
	class_data.hp_growth = int(hp_growth_slider.value)
	class_data.mp_growth = int(mp_growth_slider.value)
	class_data.strength_growth = int(str_growth_slider.value)
	class_data.defense_growth = int(def_growth_slider.value)
	class_data.agility_growth = int(agi_growth_slider.value)
	class_data.intelligence_growth = int(int_growth_slider.value)
	class_data.luck_growth = int(luk_growth_slider.value)

	# Update promotion class
	var promo_index: int = promotion_class_option.selected - 1
	if promo_index >= 0 and promo_index < available_resources.size():
		class_data.promotion_class = available_resources[promo_index] as ClassData
	else:
		class_data.promotion_class = null

	# Update weapon types - create new array to avoid read-only issues
	var new_weapon_types: Array[String] = []
	for child in weapon_types_container.get_children():
		if child is CheckBox and child.button_pressed:
			var type_name: String = child.get_meta("equipment_type")
			new_weapon_types.append(type_name)
	class_data.equippable_weapon_types = new_weapon_types

	# Update armor types - create new array to avoid read-only issues
	var new_armor_types: Array[String] = []
	for child in armor_types_container.get_children():
		if child is CheckBox and child.button_pressed:
			var type_name: String = child.get_meta("equipment_type")
			new_armor_types.append(type_name)
	class_data.equippable_armor_types = new_armor_types

	# Update learnable abilities
	class_data.learnable_abilities = _collect_learnable_abilities()


## Override: Validate resource before saving
func _validate_resource() -> Dictionary:
	var class_data: ClassData = current_resource as ClassData
	if not class_data:
		return {valid = false, errors = ["Invalid resource type"]}

	var errors: Array[String] = []

	if class_data.display_name.strip_edges().is_empty():
		errors.append("Class name cannot be empty")

	if class_data.movement_range < 1 or class_data.movement_range > 20:
		errors.append("Movement range must be between 1 and 20")

	return {valid = errors.is_empty(), errors = errors}


## Override: Check for references before deletion
func _check_resource_references(resource_to_check: Resource) -> Array[String]:
	var class_to_check: ClassData = resource_to_check as ClassData
	if not class_to_check:
		return []

	var references: Array[String] = []

	# Check all characters across all mods for references to this class
	var character_files: Array[Dictionary] = _scan_all_mods_for_resource_type("character")
	for file_info: Dictionary in character_files:
		var character: CharacterData = load(file_info.path) as CharacterData
		if character and character.character_class == class_to_check:
			references.append(file_info.path)

	# TODO: In Phase 2+, also check battles, dialogues, etc.

	return references


## Override: Create a new class with defaults
func _create_new_resource() -> Resource:
	var new_class: ClassData = ClassData.new()
	new_class.display_name = "New Class"
	new_class.movement_range = 4
	new_class.movement_type = ClassData.MovementType.WALKING
	new_class.promotion_level = 10

	return new_class


## Override: Get the display name from a class resource
func _get_resource_display_name(resource: Resource) -> String:
	var class_data: ClassData = resource as ClassData
	if class_data:
		return class_data.display_name
	return "Unnamed Class"


func _add_basic_info_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Basic Information"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Name
	var name_container: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = "Class Name:"
	name_label.custom_minimum_size.x = 150
	name_container.add_child(name_label)

	name_edit = LineEdit.new()
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_container.add_child(name_edit)
	section.add_child(name_container)

	detail_panel.add_child(section)


func _add_movement_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Movement"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Movement Type
	var type_container: HBoxContainer = HBoxContainer.new()
	var type_label: Label = Label.new()
	type_label.text = "Movement Type:"
	type_label.custom_minimum_size.x = 150
	type_container.add_child(type_label)

	movement_type_option = OptionButton.new()
	movement_type_option.add_item("Walking", ClassData.MovementType.WALKING)
	movement_type_option.add_item("Flying", ClassData.MovementType.FLYING)
	movement_type_option.add_item("Floating", ClassData.MovementType.FLOATING)
	type_container.add_child(movement_type_option)
	section.add_child(type_container)

	# Movement Range
	var range_container: HBoxContainer = HBoxContainer.new()
	var range_label: Label = Label.new()
	range_label.text = "Movement Range:"
	range_label.custom_minimum_size.x = 150
	range_container.add_child(range_label)

	movement_range_spin = SpinBox.new()
	movement_range_spin.min_value = 1
	movement_range_spin.max_value = 20
	movement_range_spin.value = 4
	range_container.add_child(movement_range_spin)
	section.add_child(range_container)

	detail_panel.add_child(section)


func _add_equipment_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Equipment Restrictions"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Weapon Types - get from registry or use defaults
	var weapon_label: Label = Label.new()
	weapon_label.text = "Equippable Weapon Types:"
	section.add_child(weapon_label)

	weapon_types_container = VBoxContainer.new()
	var weapon_types: Array[String] = _get_weapon_types_from_registry()
	_add_equipment_type_checkboxes(weapon_types_container, weapon_types)
	section.add_child(weapon_types_container)

	# Armor Types - get from registry or use defaults
	var armor_label: Label = Label.new()
	armor_label.text = "Equippable Armor Types:"
	section.add_child(armor_label)

	armor_types_container = VBoxContainer.new()
	var armor_types: Array[String] = _get_armor_types_from_registry()
	_add_equipment_type_checkboxes(armor_types_container, armor_types)
	section.add_child(armor_types_container)

	detail_panel.add_child(section)


## Get weapon types from ModLoader's equipment registry (with fallback)
func _get_weapon_types_from_registry() -> Array[String]:
	if ModLoader and ModLoader.equipment_registry:
		return ModLoader.equipment_registry.get_weapon_types()
	# Fallback to defaults if registry not available
	return ["sword", "axe", "lance", "bow", "staff", "tome"]


## Get armor types from ModLoader's equipment registry (with fallback)
func _get_armor_types_from_registry() -> Array[String]:
	if ModLoader and ModLoader.equipment_registry:
		return ModLoader.equipment_registry.get_armor_types()
	# Fallback to defaults if registry not available
	return ["light", "heavy", "robe", "shield"]


func _add_equipment_type_checkboxes(parent: VBoxContainer, types: Array[String]) -> void:
	for type_name in types:
		var checkbox: CheckBox = CheckBox.new()
		checkbox.text = type_name.capitalize()
		checkbox.set_meta("equipment_type", type_name)
		parent.add_child(checkbox)


func _add_promotion_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Class Promotion"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Promotion Level
	var level_container: HBoxContainer = HBoxContainer.new()
	var level_label: Label = Label.new()
	level_label.text = "Promotion Level:"
	level_label.custom_minimum_size.x = 150
	level_container.add_child(level_label)

	promotion_level_spin = SpinBox.new()
	promotion_level_spin.min_value = 1
	promotion_level_spin.max_value = 99
	promotion_level_spin.value = 10
	level_container.add_child(promotion_level_spin)
	section.add_child(level_container)

	# Promotion Class
	var class_container: HBoxContainer = HBoxContainer.new()
	var class_label: Label = Label.new()
	class_label.text = "Promotes To:"
	class_label.custom_minimum_size.x = 150
	class_container.add_child(class_label)

	promotion_class_option = OptionButton.new()
	promotion_class_option.add_item("(None)", 0)
	class_container.add_child(promotion_class_option)
	section.add_child(class_container)

	detail_panel.add_child(section)


func _update_promotion_options() -> void:
	promotion_class_option.clear()
	promotion_class_option.add_item("(None)", 0)

	for i in range(available_resources.size()):
		var class_data: ClassData = available_resources[i] as ClassData
		if class_data:
			promotion_class_option.add_item(class_data.display_name, i + 1)


func _add_growth_rates_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Growth Rates (%) - Shining Force Style"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Growth rates determine stat increases on level up. Set per class, not per character."
	help_label.add_theme_font_size_override("font_size", 16)
	help_label.modulate = Color(0.8, 0.8, 0.8, 1.0)
	section.add_child(help_label)

	hp_growth_slider = _create_growth_editor("HP Growth:", section)
	mp_growth_slider = _create_growth_editor("MP Growth:", section)
	str_growth_slider = _create_growth_editor("STR Growth:", section)
	def_growth_slider = _create_growth_editor("DEF Growth:", section)
	agi_growth_slider = _create_growth_editor("AGI Growth:", section)
	int_growth_slider = _create_growth_editor("INT Growth:", section)
	luk_growth_slider = _create_growth_editor("LUK Growth:", section)

	detail_panel.add_child(section)


func _create_growth_editor(label_text: String, parent: VBoxContainer) -> HSlider:
	var container: HBoxContainer = HBoxContainer.new()

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	container.add_child(label)

	var slider: HSlider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.value = 50
	slider.step = 5
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(slider)

	var value_label: Label = Label.new()
	value_label.text = "50%"
	value_label.custom_minimum_size.x = 50
	slider.value_changed.connect(func(value: float) -> void: value_label.text = str(int(value)) + "%")
	container.add_child(value_label)

	parent.add_child(container)
	return slider


func _add_learnable_abilities_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Learnable Abilities"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Abilities this class learns at specific levels."
	help_label.add_theme_font_size_override("font_size", 16)
	help_label.modulate = Color(0.8, 0.8, 0.8, 1.0)
	section.add_child(help_label)

	# Scrollable container for the ability list
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.y = 120
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	learnable_abilities_container = VBoxContainer.new()
	learnable_abilities_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(learnable_abilities_container)
	section.add_child(scroll)

	# Add Ability button
	add_ability_button = Button.new()
	add_ability_button.text = "Add Ability"
	add_ability_button.pressed.connect(_on_add_learnable_ability)
	section.add_child(add_ability_button)

	detail_panel.add_child(section)


## Load learnable abilities from dictionary into UI
func _load_learnable_abilities(abilities_dict: Dictionary) -> void:
	# Clear existing rows
	for child in learnable_abilities_container.get_children():
		child.queue_free()

	# Sort levels for consistent display order
	var levels: Array = abilities_dict.keys()
	levels.sort()

	for level: int in levels:
		var ability: Resource = abilities_dict[level]
		_add_ability_row(level, ability)


## Collect learnable abilities from UI into dictionary
func _collect_learnable_abilities() -> Dictionary:
	var result: Dictionary = {}

	for child in learnable_abilities_container.get_children():
		if child is HBoxContainer:
			var level_spin: SpinBox = child.get_node_or_null("LevelSpin")
			var picker: ResourcePicker = child.get_node_or_null("AbilityPicker")

			if level_spin and picker:
				var level: int = int(level_spin.value)
				var ability: Resource = picker.get_selected_resource()

				# Only add if ability is selected and level is not duplicate
				if ability and level not in result:
					result[level] = ability

	return result


## Add a single ability row to the UI
func _add_ability_row(level: int = 1, ability: Resource = null) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Level label
	var level_label: Label = Label.new()
	level_label.text = "Level"
	row.add_child(level_label)

	# Level spinbox
	var level_spin: SpinBox = SpinBox.new()
	level_spin.name = "LevelSpin"
	level_spin.min_value = 1
	level_spin.max_value = 99
	level_spin.value = level
	level_spin.custom_minimum_size.x = 70
	level_spin.value_changed.connect(_on_ability_level_changed.bind(row))
	row.add_child(level_spin)

	# "learns" label
	var learns_label: Label = Label.new()
	learns_label.text = "learns"
	row.add_child(learns_label)

	# Ability picker
	var picker: ResourcePicker = ResourcePicker.new()
	picker.name = "AbilityPicker"
	picker.resource_type = "ability"
	picker.allow_none = true
	picker.none_text = "(Select Ability)"
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(picker)

	# Duplicate warning icon/label (hidden by default)
	var warning_label: Label = Label.new()
	warning_label.name = "DuplicateWarning"
	warning_label.text = "!"
	warning_label.tooltip_text = "Another ability is already set for this level"
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	warning_label.add_theme_font_size_override("font_size", 16)
	warning_label.visible = false
	row.add_child(warning_label)

	# Remove button
	var remove_btn: Button = Button.new()
	remove_btn.text = "X"
	remove_btn.tooltip_text = "Remove this ability"
	remove_btn.custom_minimum_size.x = 30
	remove_btn.pressed.connect(_on_remove_ability_row.bind(row))
	row.add_child(remove_btn)

	learnable_abilities_container.add_child(row)

	# Select the ability after adding to tree (picker needs to be in tree to refresh)
	if ability:
		picker.call_deferred("select_resource", ability)

	# Check for duplicates after adding
	call_deferred("_check_duplicate_levels")


## Called when "Add Ability" button is pressed
func _on_add_learnable_ability() -> void:
	# Find the next available level (highest current + 1, or 1 if empty)
	var max_level: int = 0
	for child in learnable_abilities_container.get_children():
		if child is HBoxContainer:
			var level_spin: SpinBox = child.get_node_or_null("LevelSpin")
			if level_spin:
				max_level = max(max_level, int(level_spin.value))

	_add_ability_row(max_level + 1, null)


## Called when a remove button is pressed
func _on_remove_ability_row(row: HBoxContainer) -> void:
	row.queue_free()
	# Re-check duplicates after removal
	call_deferred("_check_duplicate_levels")


## Called when a level spinner value changes
func _on_ability_level_changed(_new_value: float, _row: HBoxContainer) -> void:
	_check_duplicate_levels()


## Check all ability rows for duplicate levels and show/hide warnings
func _check_duplicate_levels() -> void:
	# Collect all levels and their rows
	var level_counts: Dictionary = {}  # level -> Array[HBoxContainer]

	for child in learnable_abilities_container.get_children():
		if not is_instance_valid(child) or not child is HBoxContainer:
			continue
		var level_spin: SpinBox = child.get_node_or_null("LevelSpin")
		if not level_spin:
			continue

		var level: int = int(level_spin.value)
		if level not in level_counts:
			level_counts[level] = []
		level_counts[level].append(child)

	# Update warnings for all rows
	for child in learnable_abilities_container.get_children():
		if not is_instance_valid(child) or not child is HBoxContainer:
			continue
		var level_spin: SpinBox = child.get_node_or_null("LevelSpin")
		var warning_label: Label = child.get_node_or_null("DuplicateWarning")
		if not level_spin or not warning_label:
			continue

		var level: int = int(level_spin.value)
		var is_duplicate: bool = level in level_counts and level_counts[level].size() > 1
		warning_label.visible = is_duplicate
