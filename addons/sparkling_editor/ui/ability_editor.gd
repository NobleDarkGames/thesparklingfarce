@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Ability Editor UI
## Allows browsing and editing AbilityData resources

var name_edit: LineEdit
var ability_type_option: OptionButton
var target_type_option: OptionButton
var description_edit: TextEdit

# Range and Area
var min_range_spin: SpinBox
var max_range_spin: SpinBox
var area_of_effect_spin: SpinBox

# Cost
var mp_cost_spin: SpinBox
var hp_cost_spin: SpinBox

# Power
var power_spin: SpinBox
var accuracy_spin: SpinBox

# Effects
var status_effects_edit: LineEdit
var effect_duration_spin: SpinBox
var effect_chance_spin: SpinBox

# Animation and Audio
var animation_edit: LineEdit


func _ready() -> void:
	resource_type_id = "ability"
	resource_type_name = "Ability"
	# resource_directory is set dynamically via base class using ModLoader.get_active_mod()
	super._ready()


## Override: Create the ability-specific detail form
func _create_detail_form() -> void:
	# Basic info section
	_add_basic_info_section()

	# Type and targeting section
	_add_type_targeting_section()

	# Range and area section
	_add_range_area_section()

	# Cost section
	_add_cost_section()

	# Power section
	_add_power_section()

	# Effects section
	_add_effects_section()

	# Animation and audio section
	_add_animation_audio_section()

	# Add the button container at the end
	detail_panel.add_child(button_container)


## Override: Load ability data from resource into UI
func _load_resource_data() -> void:
	var ability: AbilityData = current_resource as AbilityData
	if not ability:
		return

	name_edit.text = ability.ability_name
	ability_type_option.selected = ability.ability_type
	target_type_option.selected = ability.target_type
	description_edit.text = ability.description

	# Range and area
	min_range_spin.value = ability.min_range
	max_range_spin.value = ability.max_range
	area_of_effect_spin.value = ability.area_of_effect

	# Cost
	mp_cost_spin.value = ability.mp_cost
	hp_cost_spin.value = ability.hp_cost

	# Power
	power_spin.value = ability.power
	accuracy_spin.value = ability.accuracy

	# Effects
	status_effects_edit.text = ", ".join(ability.status_effects)
	effect_duration_spin.value = ability.effect_duration
	effect_chance_spin.value = ability.effect_chance

	# Animation and audio
	animation_edit.text = ability.animation_name


## Override: Save UI data to resource
func _save_resource_data() -> void:
	var ability: AbilityData = current_resource as AbilityData
	if not ability:
		return

	# Update ability data from UI
	ability.ability_name = name_edit.text
	ability.ability_type = ability_type_option.selected
	ability.target_type = target_type_option.selected
	ability.description = description_edit.text

	# Range and area
	ability.min_range = int(min_range_spin.value)
	ability.max_range = int(max_range_spin.value)
	ability.area_of_effect = int(area_of_effect_spin.value)

	# Cost
	ability.mp_cost = int(mp_cost_spin.value)
	ability.hp_cost = int(hp_cost_spin.value)

	# Power
	ability.power = int(power_spin.value)
	ability.accuracy = int(accuracy_spin.value)

	# Effects - parse comma-separated string into array
	var effects_text: String = status_effects_edit.text.strip_edges()
	var new_effects: Array[String] = []
	if not effects_text.is_empty():
		var effect_list: PackedStringArray = effects_text.split(",")
		for effect in effect_list:
			var trimmed: String = effect.strip_edges()
			if not trimmed.is_empty():
				new_effects.append(trimmed)
	ability.status_effects = new_effects
	ability.effect_duration = int(effect_duration_spin.value)
	ability.effect_chance = int(effect_chance_spin.value)

	# Animation and audio
	ability.animation_name = animation_edit.text


## Override: Validate resource before saving
func _validate_resource() -> Dictionary:
	var ability: AbilityData = current_resource as AbilityData
	if not ability:
		return {valid = false, errors = ["Invalid resource type"]}

	var errors: Array[String] = []

	if ability.ability_name.strip_edges().is_empty():
		errors.append("Ability name cannot be empty")

	if ability.max_range < ability.min_range:
		errors.append("Max range must be >= min range")

	if ability.min_range < 0:
		errors.append("Min range cannot be negative")

	if ability.area_of_effect < 0:
		errors.append("Area of effect cannot be negative")

	if ability.mp_cost < 0:
		errors.append("MP cost cannot be negative")

	if ability.hp_cost < 0:
		errors.append("HP cost cannot be negative")

	if ability.accuracy < 0 or ability.accuracy > 100:
		errors.append("Accuracy must be between 0 and 100")

	if ability.effect_chance < 0 or ability.effect_chance > 100:
		errors.append("Effect chance must be between 0 and 100")

	return {valid = errors.is_empty(), errors = errors}


## Override: Check for references before deletion
func _check_resource_references(resource_to_check: Resource) -> Array[String]:
	var ability_to_check: AbilityData = resource_to_check as AbilityData
	if not ability_to_check:
		return []

	var references: Array[String] = []

	# Check all classes across all mods for references in learnable_abilities
	var class_files: Array[Dictionary] = _scan_all_mods_for_resource_type("class")
	for file_info: Dictionary in class_files:
		var class_data: ClassData = load(file_info.path) as ClassData
		if class_data:
			# Check if ability is in learnable_abilities dictionary
			for level: int in class_data.learnable_abilities.keys():
				var learnable_ability: Resource = class_data.learnable_abilities[level]
				if learnable_ability == ability_to_check:
					references.append(file_info.path)
					break

	# Check all items across all mods for references in consumable_effect
	var item_files: Array[Dictionary] = _scan_all_mods_for_resource_type("item")
	for file_info: Dictionary in item_files:
		var item_data: ItemData = load(file_info.path) as ItemData
		if item_data and item_data.consumable_effect == ability_to_check:
			references.append(file_info.path)

	# TODO: In Phase 2+, check battles, character known_abilities, etc.

	return references


## Override: Create a new ability with defaults
func _create_new_resource() -> Resource:
	var new_ability: AbilityData = AbilityData.new()
	new_ability.ability_name = "New Ability"
	new_ability.ability_type = AbilityData.AbilityType.ATTACK
	new_ability.target_type = AbilityData.TargetType.SINGLE_ENEMY
	new_ability.min_range = 1
	new_ability.max_range = 1
	new_ability.power = 10
	new_ability.accuracy = 100

	return new_ability


## Override: Get the display name from an ability resource
func _get_resource_display_name(resource: Resource) -> String:
	var ability: AbilityData = resource as AbilityData
	if ability:
		return ability.ability_name
	return "Unnamed Ability"


func _add_basic_info_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Basic Information"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Name
	var name_container: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = "Ability Name:"
	name_label.custom_minimum_size.x = 150
	name_container.add_child(name_label)

	name_edit = LineEdit.new()
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_container.add_child(name_edit)
	section.add_child(name_container)

	# Description
	var desc_label: Label = Label.new()
	desc_label.text = "Description:"
	section.add_child(desc_label)

	description_edit = TextEdit.new()
	description_edit.custom_minimum_size.y = 80
	section.add_child(description_edit)

	detail_panel.add_child(section)


func _add_type_targeting_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Type & Targeting"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Ability Type
	var type_container: HBoxContainer = HBoxContainer.new()
	var type_label: Label = Label.new()
	type_label.text = "Ability Type:"
	type_label.custom_minimum_size.x = 150
	type_container.add_child(type_label)

	ability_type_option = OptionButton.new()
	ability_type_option.add_item("Attack", AbilityData.AbilityType.ATTACK)
	ability_type_option.add_item("Heal", AbilityData.AbilityType.HEAL)
	ability_type_option.add_item("Support", AbilityData.AbilityType.SUPPORT)
	ability_type_option.add_item("Debuff", AbilityData.AbilityType.DEBUFF)
	ability_type_option.add_item("Summon", AbilityData.AbilityType.SUMMON)
	ability_type_option.add_item("Status", AbilityData.AbilityType.STATUS)
	ability_type_option.add_item("Counter", AbilityData.AbilityType.COUNTER)
	ability_type_option.add_item("Special", AbilityData.AbilityType.SPECIAL)
	ability_type_option.add_item("Custom", AbilityData.AbilityType.CUSTOM)
	type_container.add_child(ability_type_option)
	section.add_child(type_container)

	# Target Type
	var target_container: HBoxContainer = HBoxContainer.new()
	var target_label: Label = Label.new()
	target_label.text = "Target Type:"
	target_label.custom_minimum_size.x = 150
	target_container.add_child(target_label)

	target_type_option = OptionButton.new()
	target_type_option.add_item("Single Enemy", AbilityData.TargetType.SINGLE_ENEMY)
	target_type_option.add_item("Single Ally", AbilityData.TargetType.SINGLE_ALLY)
	target_type_option.add_item("Self", AbilityData.TargetType.SELF)
	target_type_option.add_item("All Enemies", AbilityData.TargetType.ALL_ENEMIES)
	target_type_option.add_item("All Allies", AbilityData.TargetType.ALL_ALLIES)
	target_type_option.add_item("Area", AbilityData.TargetType.AREA)
	target_container.add_child(target_type_option)
	section.add_child(target_container)

	detail_panel.add_child(section)


func _add_range_area_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Range & Area of Effect"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Min Range
	var min_container: HBoxContainer = HBoxContainer.new()
	var min_label: Label = Label.new()
	min_label.text = "Min Range:"
	min_label.custom_minimum_size.x = 150
	min_label.tooltip_text = "0 = self, 1 = adjacent, etc."
	min_container.add_child(min_label)

	min_range_spin = SpinBox.new()
	min_range_spin.min_value = 0
	min_range_spin.max_value = 20
	min_range_spin.value = 1
	min_container.add_child(min_range_spin)
	section.add_child(min_container)

	# Max Range
	var max_container: HBoxContainer = HBoxContainer.new()
	var max_label: Label = Label.new()
	max_label.text = "Max Range:"
	max_label.custom_minimum_size.x = 150
	max_container.add_child(max_label)

	max_range_spin = SpinBox.new()
	max_range_spin.min_value = 0
	max_range_spin.max_value = 20
	max_range_spin.value = 1
	max_container.add_child(max_range_spin)
	section.add_child(max_container)

	# Area of Effect
	var aoe_container: HBoxContainer = HBoxContainer.new()
	var aoe_label: Label = Label.new()
	aoe_label.text = "Area of Effect:"
	aoe_label.custom_minimum_size.x = 150
	aoe_label.tooltip_text = "0 = single target, 1+ = splash radius"
	aoe_container.add_child(aoe_label)

	area_of_effect_spin = SpinBox.new()
	area_of_effect_spin.min_value = 0
	area_of_effect_spin.max_value = 10
	area_of_effect_spin.value = 0
	aoe_container.add_child(area_of_effect_spin)
	section.add_child(aoe_container)

	detail_panel.add_child(section)


func _add_cost_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Cost"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# MP Cost
	var mp_container: HBoxContainer = HBoxContainer.new()
	var mp_label: Label = Label.new()
	mp_label.text = "MP Cost:"
	mp_label.custom_minimum_size.x = 150
	mp_container.add_child(mp_label)

	mp_cost_spin = SpinBox.new()
	mp_cost_spin.min_value = 0
	mp_cost_spin.max_value = 999
	mp_cost_spin.value = 0
	mp_container.add_child(mp_cost_spin)
	section.add_child(mp_container)

	# HP Cost
	var hp_container: HBoxContainer = HBoxContainer.new()
	var hp_label: Label = Label.new()
	hp_label.text = "HP Cost:"
	hp_label.custom_minimum_size.x = 150
	hp_container.add_child(hp_label)

	hp_cost_spin = SpinBox.new()
	hp_cost_spin.min_value = 0
	hp_cost_spin.max_value = 999
	hp_cost_spin.value = 0
	hp_container.add_child(hp_cost_spin)
	section.add_child(hp_container)

	detail_panel.add_child(section)


func _add_power_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Power"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Power
	var power_container: HBoxContainer = HBoxContainer.new()
	var power_label: Label = Label.new()
	power_label.text = "Power:"
	power_label.custom_minimum_size.x = 150
	power_label.tooltip_text = "Base effectiveness of the ability"
	power_container.add_child(power_label)

	power_spin = SpinBox.new()
	power_spin.min_value = 0
	power_spin.max_value = 999
	power_spin.value = 10
	power_container.add_child(power_spin)
	section.add_child(power_container)

	# Accuracy
	var acc_container: HBoxContainer = HBoxContainer.new()
	var acc_label: Label = Label.new()
	acc_label.text = "Accuracy (%):"
	acc_label.custom_minimum_size.x = 150
	acc_container.add_child(acc_label)

	accuracy_spin = SpinBox.new()
	accuracy_spin.min_value = 0
	accuracy_spin.max_value = 100
	accuracy_spin.value = 100
	acc_container.add_child(accuracy_spin)
	section.add_child(acc_container)

	detail_panel.add_child(section)


func _add_effects_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Status Effects"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Status Effects (comma-separated)
	var effects_label: Label = Label.new()
	effects_label.text = "Effects (comma-separated):"
	section.add_child(effects_label)

	status_effects_edit = LineEdit.new()
	status_effects_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_effects_edit.placeholder_text = "e.g., poison, attack_up, paralysis"
	section.add_child(status_effects_edit)

	# Effect Duration
	var duration_container: HBoxContainer = HBoxContainer.new()
	var duration_label: Label = Label.new()
	duration_label.text = "Effect Duration (turns):"
	duration_label.custom_minimum_size.x = 150
	duration_container.add_child(duration_label)

	effect_duration_spin = SpinBox.new()
	effect_duration_spin.min_value = 1
	effect_duration_spin.max_value = 99
	effect_duration_spin.value = 3
	duration_container.add_child(effect_duration_spin)
	section.add_child(duration_container)

	# Effect Chance
	var chance_container: HBoxContainer = HBoxContainer.new()
	var chance_label: Label = Label.new()
	chance_label.text = "Effect Chance (%):"
	chance_label.custom_minimum_size.x = 150
	chance_container.add_child(chance_label)

	effect_chance_spin = SpinBox.new()
	effect_chance_spin.min_value = 0
	effect_chance_spin.max_value = 100
	effect_chance_spin.value = 100
	chance_container.add_child(effect_chance_spin)
	section.add_child(chance_container)

	detail_panel.add_child(section)


func _add_animation_audio_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Animation & Audio"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Animation Name
	var anim_container: HBoxContainer = HBoxContainer.new()
	var anim_label: Label = Label.new()
	anim_label.text = "Animation Name:"
	anim_label.custom_minimum_size.x = 150
	anim_container.add_child(anim_label)

	animation_edit = LineEdit.new()
	animation_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	animation_edit.placeholder_text = "e.g., slash, heal_sparkle"
	anim_container.add_child(animation_edit)
	section.add_child(anim_container)

	var note_label: Label = Label.new()
	note_label.text = "Note: Sound/particle effects can be assigned in the Inspector"
	note_label.add_theme_color_override("font_color", EditorThemeUtils.get_help_color())
	note_label.add_theme_font_size_override("font_size", 16)
	section.add_child(note_label)

	detail_panel.add_child(section)
