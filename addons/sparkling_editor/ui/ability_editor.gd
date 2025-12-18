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

# Potency
var potency_spin: SpinBox
var accuracy_spin: SpinBox

# Effects
var status_effects_container: HBoxContainer
var status_effects_button: MenuButton
var status_effects_label: Label  # Shows current selection
var effect_duration_spin: SpinBox
var effect_chance_spin: SpinBox

# Track selected status effects
var _selected_effects: Array[String] = []

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

	# Potency section
	_add_potency_section()

	# Effects section
	_add_effects_section()

	# Animation and audio section
	_add_animation_audio_section()

	# Add the button container at the end (with separator for visual clarity)
	_add_button_container_to_detail_panel()


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

	# Potency
	potency_spin.value = ability.potency
	accuracy_spin.value = ability.accuracy

	# Effects - filter out unknown effects (stale data from old text input)
	_selected_effects = []
	for effect_id: String in ability.status_effects:
		if ModLoader and ModLoader.status_effect_registry and ModLoader.status_effect_registry.has_effect(effect_id):
			_selected_effects.append(effect_id)
		else:
			push_warning("AbilityEditor: Unknown status effect '%s' in ability '%s' - removing" % [effect_id, ability.ability_name])
	_update_status_effects_display()
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

	# Auto-generate ability_id from name if empty
	if ability.ability_id.is_empty() and not ability.ability_name.is_empty():
		ability.ability_id = ability.ability_name.to_lower().replace(" ", "_")

	# Range and area
	ability.min_range = int(min_range_spin.value)
	ability.max_range = int(max_range_spin.value)
	ability.area_of_effect = int(area_of_effect_spin.value)

	# Cost
	ability.mp_cost = int(mp_cost_spin.value)
	ability.hp_cost = int(hp_cost_spin.value)

	# Power
	ability.potency = int(potency_spin.value)
	ability.accuracy = int(accuracy_spin.value)

	# Effects - use selected effects array directly
	ability.status_effects = _selected_effects.duplicate()
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

	# Check all classes across all mods for references in class_abilities
	var class_files: Array[Dictionary] = _scan_all_mods_for_resource_type("class")
	for file_info: Dictionary in class_files:
		var class_data: ClassData = load(file_info.path) as ClassData
		if class_data:
			# Check if ability is in class_abilities array
			for class_ability: AbilityData in class_data.class_abilities:
				if class_ability == ability_to_check:
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
	new_ability.potency = 10
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
	name_edit.tooltip_text = "Display name shown in battle menus. E.g., Blaze, Heal, Bolt."
	name_container.add_child(name_edit)
	section.add_child(name_container)

	# Description
	var desc_label: Label = Label.new()
	desc_label.text = "Description:"
	section.add_child(desc_label)

	description_edit = TextEdit.new()
	description_edit.custom_minimum_size.y = 80
	description_edit.tooltip_text = "Tooltip text shown when hovering over ability in menus. Describe what it does."
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
	ability_type_option.tooltip_text = "Category for AI and UI. Attack = damage. Heal = restore HP. Support = buffs. Debuff = weaken enemies."
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
	target_type_option.tooltip_text = "Who can be targeted. Single = one target. All = entire side. Area = splash around a point."
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
	min_range_spin.tooltip_text = "Closest tile this ability can target. 0 = self only, 1 = adjacent, 2+ = ranged."
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
	max_range_spin.tooltip_text = "Farthest tile this ability can target. Typical: 1-2 melee skills, 3-5 ranged spells."
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
	area_of_effect_spin.tooltip_text = "Radius around target point. 0 = single target. 1 = 3x3 area. 2 = 5x5 area."
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
	mp_cost_spin.tooltip_text = "Magic points consumed when used. Typical: 2-5 early spells, 10-20 powerful, 30+ ultimate."
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
	hp_cost_spin.tooltip_text = "HP sacrificed to use ability. For dark magic or desperation attacks. Usually 0."
	hp_container.add_child(hp_cost_spin)
	section.add_child(hp_container)

	detail_panel.add_child(section)


func _add_potency_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Potency"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Potency
	var potency_container: HBoxContainer = HBoxContainer.new()
	var potency_label: Label = Label.new()
	potency_label.text = "Potency:"
	potency_label.custom_minimum_size.x = 150
	potency_label.tooltip_text = "Base effectiveness of the ability (damage for attacks, healing amount for heals)"
	potency_container.add_child(potency_label)

	potency_spin = SpinBox.new()
	potency_spin.min_value = 0
	potency_spin.max_value = 999
	potency_spin.value = 10
	potency_spin.tooltip_text = "Base effect strength. For damage/healing, multiplied by caster stats. Typical: 10-30 basic, 50+ powerful."
	potency_container.add_child(potency_spin)
	section.add_child(potency_container)

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
	accuracy_spin.tooltip_text = "Base hit chance percentage. 100% = always hits (most spells). 80-90% = can miss (debuffs)."
	acc_container.add_child(accuracy_spin)
	section.add_child(acc_container)

	detail_panel.add_child(section)


func _add_effects_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Status Effects"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Status Effects picker
	var effects_header: Label = Label.new()
	effects_header.text = "Effects:"
	section.add_child(effects_header)

	status_effects_container = HBoxContainer.new()

	status_effects_button = MenuButton.new()
	status_effects_button.text = "Select Effects..."
	status_effects_button.tooltip_text = "Choose status effects to apply when this ability hits."
	status_effects_button.flat = false
	status_effects_button.get_popup().hide_on_checkable_item_selection = false
	status_effects_button.get_popup().index_pressed.connect(_on_status_effect_toggled)
	status_effects_container.add_child(status_effects_button)

	status_effects_label = Label.new()
	status_effects_label.text = "(none)"
	status_effects_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	status_effects_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_effects_container.add_child(status_effects_label)

	section.add_child(status_effects_container)

	# Populate the dropdown lazily when opened (registry may not be ready on startup)
	status_effects_button.get_popup().about_to_popup.connect(_populate_status_effects_menu)

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
	effect_duration_spin.tooltip_text = "How many turns the status effect lasts. Typical: 2-3 short, 5 medium, 10+ long-lasting."
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
	effect_chance_spin.tooltip_text = "Probability that status effect applies on hit. 100% = guaranteed. 30-50% = unreliable debuff."
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
	animation_edit.tooltip_text = "[NOT YET IMPLEMENTED] Animation key to play when ability is used. Field exists for future spell animation system."
	anim_container.add_child(animation_edit)
	section.add_child(anim_container)

	var note_label: Label = Label.new()
	note_label.text = "[STUB] Animation/audio fields exist but are not yet processed by the spell system"
	note_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	note_label.add_theme_font_size_override("font_size", 12)
	section.add_child(note_label)

	detail_panel.add_child(section)


# =============================================================================
# STATUS EFFECT PICKER HELPERS
# =============================================================================

## Populate the status effects dropdown from registry
func _populate_status_effects_menu() -> void:
	var popup: PopupMenu = status_effects_button.get_popup()
	popup.clear()

	# Get all registered status effects
	if not ModLoader or not ModLoader.status_effect_registry:
		popup.add_item("(Registry not available)")
		popup.set_item_disabled(0, true)
		return

	var effect_ids: Array[String] = ModLoader.status_effect_registry.get_all_effect_ids()

	if effect_ids.is_empty():
		popup.add_item("(No status effects registered)")
		popup.set_item_disabled(0, true)
		return

	for effect_id: String in effect_ids:
		var effect: StatusEffectData = ModLoader.status_effect_registry.get_effect(effect_id)
		var display_text: String = effect.display_name if effect and not effect.display_name.is_empty() else effect_id.capitalize()

		popup.add_check_item(display_text)
		var idx: int = popup.item_count - 1
		popup.set_item_metadata(idx, effect_id)

		# Check if this effect is currently selected
		if effect_id in _selected_effects:
			popup.set_item_checked(idx, true)


## Handle status effect checkbox toggle
func _on_status_effect_toggled(index: int) -> void:
	var popup: PopupMenu = status_effects_button.get_popup()
	var effect_id: String = popup.get_item_metadata(index)

	if effect_id.is_empty():
		return

	var is_checked: bool = popup.is_item_checked(index)

	if is_checked:
		# Unchecking - remove from selection
		_selected_effects.erase(effect_id)
		popup.set_item_checked(index, false)
	else:
		# Checking - add to selection
		if effect_id not in _selected_effects:
			_selected_effects.append(effect_id)
		popup.set_item_checked(index, true)

	_update_status_effects_display()


## Update the label showing currently selected effects
func _update_status_effects_display() -> void:
	# Also refresh checkboxes in menu
	_refresh_menu_checkboxes()

	if _selected_effects.is_empty():
		status_effects_label.text = "(none)"
		status_effects_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	else:
		# Build display string with display names
		var display_names: Array[String] = []
		for effect_id: String in _selected_effects:
			var display_name: String = effect_id.capitalize()
			if ModLoader and ModLoader.status_effect_registry:
				display_name = ModLoader.status_effect_registry.get_display_name(effect_id)
			display_names.append(display_name)
		status_effects_label.text = ", ".join(display_names)
		status_effects_label.remove_theme_color_override("font_color")


## Refresh menu checkboxes to match current selection
func _refresh_menu_checkboxes() -> void:
	var popup: PopupMenu = status_effects_button.get_popup()
	for i: int in range(popup.item_count):
		var effect_id: String = popup.get_item_metadata(i)
		if not effect_id.is_empty():
			popup.set_item_checked(i, effect_id in _selected_effects)
