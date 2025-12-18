@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Status Effect Editor UI
## Allows browsing and editing StatusEffectData resources
## Status effects define buffs, debuffs, and conditions applied to units in battle

# =============================================================================
# IDENTITY FIELDS
# =============================================================================

var effect_id_edit: LineEdit
var display_name_edit: LineEdit
var description_edit: TextEdit

# =============================================================================
# VISUAL FIELDS
# =============================================================================

var icon_color_picker: ColorPickerButton
var popup_text_edit: LineEdit
var popup_color_picker: ColorPickerButton

# =============================================================================
# TIMING FIELDS
# =============================================================================

var trigger_timing_option: OptionButton

# =============================================================================
# SKIP TURN FIELDS
# =============================================================================

var skips_turn_check: CheckBox
var recovery_chance_spin: SpinBox
var recovery_chance_container: HBoxContainer

# =============================================================================
# DAMAGE OVER TIME FIELDS
# =============================================================================

var damage_per_turn_spin: SpinBox

# =============================================================================
# STAT MODIFIER FIELDS
# =============================================================================

var stat_modifiers_container: VBoxContainer
var stat_strength_spin: SpinBox
var stat_defense_spin: SpinBox
var stat_agility_spin: SpinBox
var stat_intelligence_spin: SpinBox
var stat_luck_spin: SpinBox
var stat_max_hp_spin: SpinBox
var stat_max_mp_spin: SpinBox

# =============================================================================
# REMOVAL CONDITION FIELDS
# =============================================================================

var removed_on_damage_check: CheckBox
var removal_on_damage_chance_spin: SpinBox
var removal_chance_container: HBoxContainer

# =============================================================================
# ACTION MODIFIER FIELDS
# =============================================================================

var action_modifier_option: OptionButton
var action_modifier_chance_spin: SpinBox
var action_modifier_chance_container: HBoxContainer


func _ready() -> void:
	resource_type_id = "status_effect"
	resource_type_name = "Status Effect"
	# resource_directory is set dynamically via base class using ModLoader.get_active_mod()
	super._ready()


## Override: Create the status effect-specific detail form
func _create_detail_form() -> void:
	# Identity section
	_add_identity_section()

	# Visual section
	_add_visual_section()

	# Timing section
	_add_timing_section()

	# Skip Turn section
	_add_skip_turn_section()

	# Damage Over Time section
	_add_damage_over_time_section()

	# Stat Modifiers section
	_add_stat_modifiers_section()

	# Removal Conditions section
	_add_removal_conditions_section()

	# Action Modifiers section
	_add_action_modifiers_section()

	# Add the button container at the end (with separator for visual clarity)
	_add_button_container_to_detail_panel()


## Override: Load status effect data from resource into UI
func _load_resource_data() -> void:
	var effect: StatusEffectData = current_resource as StatusEffectData
	if not effect:
		return

	# Identity
	effect_id_edit.text = effect.effect_id
	display_name_edit.text = effect.display_name
	description_edit.text = effect.description

	# Visual
	icon_color_picker.color = effect.icon_color
	popup_text_edit.text = effect.popup_text
	popup_color_picker.color = effect.popup_color

	# Timing
	trigger_timing_option.selected = effect.trigger_timing

	# Skip Turn
	skips_turn_check.button_pressed = effect.skips_turn
	recovery_chance_spin.value = effect.recovery_chance_per_turn
	_update_recovery_chance_visibility()

	# Damage Over Time
	damage_per_turn_spin.value = effect.damage_per_turn

	# Stat Modifiers
	_load_stat_modifiers(effect.stat_modifiers)

	# Removal Conditions
	removed_on_damage_check.button_pressed = effect.removed_on_damage
	removal_on_damage_chance_spin.value = effect.removal_on_damage_chance
	_update_removal_chance_visibility()

	# Action Modifiers
	action_modifier_option.selected = effect.action_modifier
	action_modifier_chance_spin.value = effect.action_modifier_chance
	_update_action_modifier_chance_visibility()


## Override: Save UI data to resource
func _save_resource_data() -> void:
	var effect: StatusEffectData = current_resource as StatusEffectData
	if not effect:
		return

	# Identity
	effect.effect_id = effect_id_edit.text.strip_edges().to_lower().replace(" ", "_")
	effect.display_name = display_name_edit.text.strip_edges()
	effect.description = description_edit.text

	# Visual
	effect.icon_color = icon_color_picker.color
	effect.popup_text = popup_text_edit.text.strip_edges()
	effect.popup_color = popup_color_picker.color

	# Timing
	effect.trigger_timing = trigger_timing_option.selected as StatusEffectData.TriggerTiming

	# Skip Turn
	effect.skips_turn = skips_turn_check.button_pressed
	effect.recovery_chance_per_turn = int(recovery_chance_spin.value)

	# Damage Over Time
	effect.damage_per_turn = int(damage_per_turn_spin.value)

	# Stat Modifiers
	effect.stat_modifiers = _collect_stat_modifiers()

	# Removal Conditions
	effect.removed_on_damage = removed_on_damage_check.button_pressed
	effect.removal_on_damage_chance = int(removal_on_damage_chance_spin.value)

	# Action Modifiers
	effect.action_modifier = action_modifier_option.selected as StatusEffectData.ActionModifier
	effect.action_modifier_chance = int(action_modifier_chance_spin.value)


## Override: Validate resource before saving
func _validate_resource() -> Dictionary:
	var effect: StatusEffectData = current_resource as StatusEffectData
	if not effect:
		return {valid = false, errors = ["Invalid resource type"]}

	var errors: Array[String] = []

	# Validate effect_id
	var effect_id: String = effect_id_edit.text.strip_edges()
	if effect_id.is_empty():
		errors.append("Effect ID cannot be empty")
	elif effect_id.contains(" "):
		errors.append("Effect ID cannot contain spaces (use underscores)")

	# Validate display_name
	if display_name_edit.text.strip_edges().is_empty():
		errors.append("Display name cannot be empty")

	# Validate recovery chance
	if skips_turn_check.button_pressed:
		if recovery_chance_spin.value < 0 or recovery_chance_spin.value > 100:
			errors.append("Recovery chance must be between 0 and 100")

	# Validate removal chance
	if removed_on_damage_check.button_pressed:
		if removal_on_damage_chance_spin.value < 0 or removal_on_damage_chance_spin.value > 100:
			errors.append("Removal chance must be between 0 and 100")

	# Validate action modifier chance
	if action_modifier_option.selected != StatusEffectData.ActionModifier.NONE:
		if action_modifier_chance_spin.value < 0 or action_modifier_chance_spin.value > 100:
			errors.append("Action modifier chance must be between 0 and 100")

	return {valid = errors.is_empty(), errors = errors}


## Override: Check for references before deletion
func _check_resource_references(_resource_to_check: Resource) -> Array[String]:
	# Status effects are referenced by abilities via status_effects array
	# This would require scanning all abilities
	# For now, return empty - status effect deletion should prompt manual check
	# TODO: Add ability scanning in future if needed
	return []


## Override: Create a new status effect with defaults
func _create_new_resource() -> Resource:
	var new_effect: StatusEffectData = StatusEffectData.new()
	new_effect.effect_id = "new_effect"
	new_effect.display_name = "New Status Effect"
	new_effect.description = "A new status effect."
	new_effect.icon_color = Color.WHITE
	new_effect.popup_color = Color.WHITE
	new_effect.trigger_timing = StatusEffectData.TriggerTiming.TURN_START
	new_effect.skips_turn = false
	new_effect.recovery_chance_per_turn = 0
	new_effect.damage_per_turn = 0
	new_effect.stat_modifiers = {}
	new_effect.removed_on_damage = false
	new_effect.removal_on_damage_chance = 100
	new_effect.action_modifier = StatusEffectData.ActionModifier.NONE
	new_effect.action_modifier_chance = 100

	return new_effect


## Override: Get the display name from a status effect resource
func _get_resource_display_name(resource: Resource) -> String:
	var effect: StatusEffectData = resource as StatusEffectData
	if effect:
		if effect.display_name.is_empty():
			return effect.effect_id
		return effect.display_name
	return "Unnamed Effect"


# =============================================================================
# SECTION BUILDERS
# =============================================================================

func _add_identity_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Identity"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	# Effect ID
	var id_container: HBoxContainer = HBoxContainer.new()
	var id_label: Label = Label.new()
	id_label.text = "Effect ID:"
	id_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	id_label.tooltip_text = "Unique identifier used in code (lowercase, underscores)"
	id_container.add_child(id_label)

	effect_id_edit = LineEdit.new()
	effect_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_id_edit.placeholder_text = "e.g., poison, sleep, attack_up"
	effect_id_edit.tooltip_text = "Unique identifier for this effect. Use lowercase with underscores."
	effect_id_edit.text_changed.connect(_on_field_changed)
	id_container.add_child(effect_id_edit)
	section.add_child(id_container)

	# Display Name
	var name_container: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = "Display Name:"
	name_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	name_label.tooltip_text = "Name shown in game UI"
	name_container.add_child(name_label)

	display_name_edit = LineEdit.new()
	display_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_name_edit.placeholder_text = "e.g., Poisoned, Asleep, Attack Up"
	display_name_edit.tooltip_text = "The name displayed to players in battle UI."
	display_name_edit.text_changed.connect(_on_field_changed)
	name_container.add_child(display_name_edit)
	section.add_child(name_container)

	# Description
	var desc_label: Label = Label.new()
	desc_label.text = "Description:"
	desc_label.tooltip_text = "Help text explaining the effect"
	section.add_child(desc_label)

	description_edit = TextEdit.new()
	description_edit.custom_minimum_size.y = 60
	description_edit.tooltip_text = "Detailed description shown in help screens and tooltips."
	description_edit.text_changed.connect(_on_field_changed)
	section.add_child(description_edit)

	detail_panel.add_child(section)


func _add_visual_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Visual Display"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Configure how the status effect appears in the UI."
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	section.add_child(help_label)

	# Icon Color
	var icon_container: HBoxContainer = HBoxContainer.new()
	var icon_label: Label = Label.new()
	icon_label.text = "Icon Color:"
	icon_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	icon_label.tooltip_text = "Color tint for the status icon in UI"
	icon_container.add_child(icon_label)

	icon_color_picker = ColorPickerButton.new()
	icon_color_picker.custom_minimum_size = Vector2(80, 0)
	icon_color_picker.color = Color.WHITE
	icon_color_picker.tooltip_text = "The color used for the status effect icon in the battle UI."
	icon_color_picker.color_changed.connect(_on_color_changed)
	icon_container.add_child(icon_color_picker)
	section.add_child(icon_container)

	# Popup Text
	var popup_container: HBoxContainer = HBoxContainer.new()
	var popup_label: Label = Label.new()
	popup_label.text = "Popup Text:"
	popup_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	popup_label.tooltip_text = "Text shown when effect triggers (optional)"
	popup_container.add_child(popup_label)

	popup_text_edit = LineEdit.new()
	popup_text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_text_edit.placeholder_text = "(uses display name if empty)"
	popup_text_edit.tooltip_text = "Custom text to display when the effect triggers. Leave empty to use display name."
	popup_text_edit.text_changed.connect(_on_field_changed)
	popup_container.add_child(popup_text_edit)
	section.add_child(popup_container)

	# Popup Color
	var popup_color_container: HBoxContainer = HBoxContainer.new()
	var popup_color_label: Label = Label.new()
	popup_color_label.text = "Popup Color:"
	popup_color_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	popup_color_label.tooltip_text = "Color for the popup text"
	popup_color_container.add_child(popup_color_label)

	popup_color_picker = ColorPickerButton.new()
	popup_color_picker.custom_minimum_size = Vector2(80, 0)
	popup_color_picker.color = Color.WHITE
	popup_color_picker.tooltip_text = "Color of the floating text when this effect triggers."
	popup_color_picker.color_changed.connect(_on_color_changed)
	popup_color_container.add_child(popup_color_picker)
	section.add_child(popup_color_container)

	detail_panel.add_child(section)


func _add_timing_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Trigger Timing"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "When does this effect's behavior activate?"
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	section.add_child(help_label)

	# Trigger Timing
	var timing_container: HBoxContainer = HBoxContainer.new()
	var timing_label: Label = Label.new()
	timing_label.text = "Timing:"
	timing_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	timing_container.add_child(timing_label)

	trigger_timing_option = OptionButton.new()
	trigger_timing_option.tooltip_text = "When this effect processes each turn"
	trigger_timing_option.add_item("Turn Start", StatusEffectData.TriggerTiming.TURN_START)
	trigger_timing_option.add_item("Turn End", StatusEffectData.TriggerTiming.TURN_END)
	trigger_timing_option.add_item("On Damage", StatusEffectData.TriggerTiming.ON_DAMAGE)
	trigger_timing_option.add_item("On Action", StatusEffectData.TriggerTiming.ON_ACTION)
	trigger_timing_option.add_item("Passive", StatusEffectData.TriggerTiming.PASSIVE)
	trigger_timing_option.item_selected.connect(_on_option_selected)
	timing_container.add_child(trigger_timing_option)
	section.add_child(timing_container)

	var timing_help: Label = Label.new()
	timing_help.text = "Turn Start: Poison damage, paralysis checks\nTurn End: After action processing\nOn Damage: When unit takes damage\nOn Action: When unit tries to act\nPassive: Always active (stat modifiers)"
	timing_help.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	timing_help.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	timing_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(timing_help)

	detail_panel.add_child(section)


func _add_skip_turn_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Skip Turn Effects"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "For effects like Sleep, Stun, or Paralysis that prevent action."
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	section.add_child(help_label)

	# Skips Turn checkbox
	var skip_container: HBoxContainer = HBoxContainer.new()
	skips_turn_check = CheckBox.new()
	skips_turn_check.text = "Unit Cannot Act"
	skips_turn_check.tooltip_text = "If checked, the affected unit loses their turn while this effect is active."
	skips_turn_check.toggled.connect(_on_skips_turn_toggled)
	skip_container.add_child(skips_turn_check)
	section.add_child(skip_container)

	# Recovery Chance
	recovery_chance_container = HBoxContainer.new()
	var recovery_label: Label = Label.new()
	recovery_label.text = "Recovery Chance (%):"
	recovery_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	recovery_label.tooltip_text = "Chance to recover at the start of each turn"
	recovery_chance_container.add_child(recovery_label)

	recovery_chance_spin = SpinBox.new()
	recovery_chance_spin.min_value = 0
	recovery_chance_spin.max_value = 100
	recovery_chance_spin.value = 0
	recovery_chance_spin.suffix = "%"
	recovery_chance_spin.tooltip_text = "0% = never recover naturally, 25% = paralysis-style, 100% = always recover after 1 turn."
	recovery_chance_spin.value_changed.connect(_on_spin_changed)
	recovery_chance_container.add_child(recovery_chance_spin)
	section.add_child(recovery_chance_container)

	detail_panel.add_child(section)


func _add_damage_over_time_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Damage/Healing Over Time"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "HP change applied when the effect triggers."
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	section.add_child(help_label)

	# Damage per Turn
	var damage_container: HBoxContainer = HBoxContainer.new()
	var damage_label: Label = Label.new()
	damage_label.text = "HP Change/Turn:"
	damage_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	damage_label.tooltip_text = "Positive = damage (poison), Negative = healing (regen)"
	damage_container.add_child(damage_label)

	damage_per_turn_spin = SpinBox.new()
	damage_per_turn_spin.min_value = -99
	damage_per_turn_spin.max_value = 99
	damage_per_turn_spin.value = 0
	damage_per_turn_spin.tooltip_text = "Positive values deal damage (Poison: 5-10). Negative values restore HP (Regen: -5 to -10)."
	damage_per_turn_spin.value_changed.connect(_on_spin_changed)
	damage_container.add_child(damage_per_turn_spin)

	var damage_note: Label = Label.new()
	damage_note.text = "  (+ = damage, - = heal)"
	damage_note.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	damage_container.add_child(damage_note)
	section.add_child(damage_container)

	detail_panel.add_child(section)


func _add_stat_modifiers_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Stat Modifiers"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Stat bonuses/penalties applied while the effect is active. Leave at 0 for no change."
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(help_label)

	stat_modifiers_container = VBoxContainer.new()

	# Create spin boxes for each stat
	stat_strength_spin = _create_stat_spin("Strength:", "strength")
	stat_modifiers_container.add_child(stat_strength_spin.get_parent())

	stat_defense_spin = _create_stat_spin("Defense:", "defense")
	stat_modifiers_container.add_child(stat_defense_spin.get_parent())

	stat_agility_spin = _create_stat_spin("Agility:", "agility")
	stat_modifiers_container.add_child(stat_agility_spin.get_parent())

	stat_intelligence_spin = _create_stat_spin("Intelligence:", "intelligence")
	stat_modifiers_container.add_child(stat_intelligence_spin.get_parent())

	stat_luck_spin = _create_stat_spin("Luck:", "luck")
	stat_modifiers_container.add_child(stat_luck_spin.get_parent())

	stat_max_hp_spin = _create_stat_spin("Max HP:", "max_hp")
	stat_modifiers_container.add_child(stat_max_hp_spin.get_parent())

	stat_max_mp_spin = _create_stat_spin("Max MP:", "max_mp")
	stat_modifiers_container.add_child(stat_max_mp_spin.get_parent())

	section.add_child(stat_modifiers_container)

	detail_panel.add_child(section)


func _create_stat_spin(label_text: String, stat_name: String) -> SpinBox:
	var container: HBoxContainer = HBoxContainer.new()

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	container.add_child(label)

	var spin: SpinBox = SpinBox.new()
	spin.min_value = -50
	spin.max_value = 50
	spin.value = 0
	spin.tooltip_text = "Bonus/penalty to %s while effect is active. Positive = buff, Negative = debuff." % stat_name
	spin.set_meta("stat_name", stat_name)
	spin.value_changed.connect(_on_spin_changed)
	container.add_child(spin)

	return spin


func _add_removal_conditions_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Removal Conditions"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "When should this effect be removed early?"
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	section.add_child(help_label)

	# Removed on Damage checkbox
	var remove_container: HBoxContainer = HBoxContainer.new()
	removed_on_damage_check = CheckBox.new()
	removed_on_damage_check.text = "Remove When Damaged"
	removed_on_damage_check.tooltip_text = "Effect is removed when the unit takes damage (like Sleep waking on hit)."
	removed_on_damage_check.toggled.connect(_on_removed_on_damage_toggled)
	remove_container.add_child(removed_on_damage_check)
	section.add_child(remove_container)

	# Removal Chance
	removal_chance_container = HBoxContainer.new()
	var removal_label: Label = Label.new()
	removal_label.text = "Removal Chance (%):"
	removal_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	removal_label.tooltip_text = "Chance to remove when damaged"
	removal_chance_container.add_child(removal_label)

	removal_on_damage_chance_spin = SpinBox.new()
	removal_on_damage_chance_spin.min_value = 0
	removal_on_damage_chance_spin.max_value = 100
	removal_on_damage_chance_spin.value = 100
	removal_on_damage_chance_spin.suffix = "%"
	removal_on_damage_chance_spin.tooltip_text = "100% = always wake up, 50% = 50% chance to wake."
	removal_on_damage_chance_spin.value_changed.connect(_on_spin_changed)
	removal_chance_container.add_child(removal_on_damage_chance_spin)
	section.add_child(removal_chance_container)

	detail_panel.add_child(section)


func _add_action_modifiers_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Action Modifiers"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "How does this effect modify the unit's actions?"
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	section.add_child(help_label)

	# Action Modifier Type
	var modifier_container: HBoxContainer = HBoxContainer.new()
	var modifier_label: Label = Label.new()
	modifier_label.text = "Modifier Type:"
	modifier_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	modifier_container.add_child(modifier_label)

	action_modifier_option = OptionButton.new()
	action_modifier_option.tooltip_text = "How actions are modified"
	action_modifier_option.add_item("None", StatusEffectData.ActionModifier.NONE)
	action_modifier_option.add_item("Random Target", StatusEffectData.ActionModifier.RANDOM_TARGET)
	action_modifier_option.add_item("Attack Allies", StatusEffectData.ActionModifier.ATTACK_ALLIES)
	action_modifier_option.add_item("Cannot Use Magic", StatusEffectData.ActionModifier.CANNOT_USE_MAGIC)
	action_modifier_option.add_item("Cannot Use Items", StatusEffectData.ActionModifier.CANNOT_USE_ITEMS)
	action_modifier_option.item_selected.connect(_on_action_modifier_selected)
	modifier_container.add_child(action_modifier_option)
	section.add_child(modifier_container)

	# Action Modifier Chance
	action_modifier_chance_container = HBoxContainer.new()
	var chance_label: Label = Label.new()
	chance_label.text = "Modifier Chance (%):"
	chance_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	chance_label.tooltip_text = "Chance the modifier applies each turn"
	action_modifier_chance_container.add_child(chance_label)

	action_modifier_chance_spin = SpinBox.new()
	action_modifier_chance_spin.min_value = 0
	action_modifier_chance_spin.max_value = 100
	action_modifier_chance_spin.value = 100
	action_modifier_chance_spin.suffix = "%"
	action_modifier_chance_spin.tooltip_text = "100% = always confused, 50% = sometimes acts normally."
	action_modifier_chance_spin.value_changed.connect(_on_spin_changed)
	action_modifier_chance_container.add_child(action_modifier_chance_spin)
	section.add_child(action_modifier_chance_container)

	var modifier_help: Label = Label.new()
	modifier_help.text = "None: Normal actions\nRandom Target: Confusion - hits random unit\nAttack Allies: Berserk/Charm - forced to attack allies\nCannot Use Magic: Silence effect\nCannot Use Items: Item restriction"
	modifier_help.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	modifier_help.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	modifier_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(modifier_help)

	detail_panel.add_child(section)


# =============================================================================
# STAT MODIFIER HELPERS
# =============================================================================

func _load_stat_modifiers(modifiers: Dictionary) -> void:
	stat_strength_spin.value = modifiers.get("strength", 0)
	stat_defense_spin.value = modifiers.get("defense", 0)
	stat_agility_spin.value = modifiers.get("agility", 0)
	stat_intelligence_spin.value = modifiers.get("intelligence", 0)
	stat_luck_spin.value = modifiers.get("luck", 0)
	stat_max_hp_spin.value = modifiers.get("max_hp", 0)
	stat_max_mp_spin.value = modifiers.get("max_mp", 0)


func _collect_stat_modifiers() -> Dictionary:
	var modifiers: Dictionary = {}

	# Only include non-zero values
	if int(stat_strength_spin.value) != 0:
		modifiers["strength"] = int(stat_strength_spin.value)
	if int(stat_defense_spin.value) != 0:
		modifiers["defense"] = int(stat_defense_spin.value)
	if int(stat_agility_spin.value) != 0:
		modifiers["agility"] = int(stat_agility_spin.value)
	if int(stat_intelligence_spin.value) != 0:
		modifiers["intelligence"] = int(stat_intelligence_spin.value)
	if int(stat_luck_spin.value) != 0:
		modifiers["luck"] = int(stat_luck_spin.value)
	if int(stat_max_hp_spin.value) != 0:
		modifiers["max_hp"] = int(stat_max_hp_spin.value)
	if int(stat_max_mp_spin.value) != 0:
		modifiers["max_mp"] = int(stat_max_mp_spin.value)

	return modifiers


# =============================================================================
# VISIBILITY HELPERS
# =============================================================================

func _update_recovery_chance_visibility() -> void:
	if recovery_chance_container:
		recovery_chance_container.visible = skips_turn_check.button_pressed


func _update_removal_chance_visibility() -> void:
	if removal_chance_container:
		removal_chance_container.visible = removed_on_damage_check.button_pressed


func _update_action_modifier_chance_visibility() -> void:
	if action_modifier_chance_container:
		action_modifier_chance_container.visible = action_modifier_option.selected != StatusEffectData.ActionModifier.NONE


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_field_changed(_new_text: String = "") -> void:
	_mark_dirty()


func _on_color_changed(_new_color: Color) -> void:
	_mark_dirty()


func _on_spin_changed(_new_value: float) -> void:
	_mark_dirty()


func _on_option_selected(_index: int) -> void:
	_mark_dirty()


func _on_skips_turn_toggled(_pressed: bool) -> void:
	_update_recovery_chance_visibility()
	_mark_dirty()


func _on_removed_on_damage_toggled(_pressed: bool) -> void:
	_update_removal_chance_visibility()
	_mark_dirty()


func _on_action_modifier_selected(_index: int) -> void:
	_update_action_modifier_chance_visibility()
	_mark_dirty()
