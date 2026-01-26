@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Status Effect Editor UI
## Allows browsing and editing StatusEffectData resources
## Status effects define buffs, debuffs, and conditions applied to units in battle

# =============================================================================
# IDENTITY FIELDS
# =============================================================================

var name_id_group: NameIdFieldGroup
var description_edit: TextEdit

# =============================================================================
# VISUAL FIELDS
# =============================================================================

var popup_text_edit: LineEdit
var popup_color_picker: ColorPickerButton

# =============================================================================
# TIMING FIELDS
# =============================================================================

var duration_spin: SpinBox
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

# Guard to prevent false dirty state during UI population
var _updating_ui: bool = false


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

	_updating_ui = true

	# Identity (auto-detects lock state)
	name_id_group.set_values(effect.display_name, effect.effect_id, true)
	description_edit.text = effect.description

	# Visual
	popup_text_edit.text = effect.popup_text
	popup_color_picker.color = effect.popup_color

	# Timing
	duration_spin.value = effect.duration
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

	_updating_ui = false


## Override: Save UI data to resource
func _save_resource_data() -> void:
	var effect: StatusEffectData = current_resource as StatusEffectData
	if not effect:
		return

	# Identity
	effect.effect_id = name_id_group.get_id_value()
	effect.display_name = name_id_group.get_name_value()
	effect.description = description_edit.text

	# Visual
	effect.popup_text = popup_text_edit.text.strip_edges()
	effect.popup_color = popup_color_picker.color

	# Timing
	effect.duration = int(duration_spin.value)
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
	var effect_id: String = name_id_group.get_id_value()
	if effect_id.is_empty():
		errors.append("Effect ID cannot be empty")
	elif effect_id.contains(" "):
		errors.append("Effect ID cannot contain spaces (use underscores)")

	# Validate display_name
	if name_id_group.get_name_value().is_empty():
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
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Identity")

	# Name/ID using reusable component
	name_id_group = NameIdFieldGroup.new()
	name_id_group.name_label = "Display Name:"
	name_id_group.id_label = "Effect ID:"
	name_id_group.name_placeholder = "e.g., Poisoned, Asleep, Attack Up"
	name_id_group.id_placeholder = "e.g., poison, sleep, attack_up"
	name_id_group.name_tooltip = "The name displayed to players in battle UI"
	name_id_group.id_tooltip = "Unique identifier for this effect. Use lowercase with underscores."
	name_id_group.label_width = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	name_id_group.value_changed.connect(_on_name_id_changed)
	form.container.add_child(name_id_group)

	description_edit = form.add_text_area("Description:", 60,
		"Detailed description shown in help screens and tooltips.")


func _add_visual_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Visual Display")
	form.add_help_text("Configure how the status effect appears in the UI.")

	popup_text_edit = form.add_text_field("Popup Text:", "(uses display name if empty)",
		"Custom text to display when the effect triggers. Leave empty to use display name.")

	# Popup Color - custom control
	popup_color_picker = ColorPickerButton.new()
	popup_color_picker.custom_minimum_size = Vector2(80, 0)
	popup_color_picker.color = Color.WHITE
	popup_color_picker.tooltip_text = "Color of the floating text when this effect triggers."
	popup_color_picker.color_changed.connect(_on_color_changed)
	form.add_labeled_control("Popup Color:", popup_color_picker,
		"Color of the floating text when this effect triggers.")


func _add_timing_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Timing")

	duration_spin = form.add_number_field("Duration (turns):", 0, 99, 3,
		"How many turns this effect lasts. 0 = until removed by other means (damage, cure, etc).")

	trigger_timing_option = form.add_dropdown("Timing:", [
		{"label": "Turn Start", "id": StatusEffectData.TriggerTiming.TURN_START},
		{"label": "Turn End", "id": StatusEffectData.TriggerTiming.TURN_END},
		{"label": "On Damage", "id": StatusEffectData.TriggerTiming.ON_DAMAGE},
		{"label": "On Action", "id": StatusEffectData.TriggerTiming.ON_ACTION},
		{"label": "Passive", "id": StatusEffectData.TriggerTiming.PASSIVE},
	], "When this effect processes each turn")
	trigger_timing_option.item_selected.connect(_on_option_selected)

	form.add_help_text("Turn Start: Poison damage, paralysis checks\nTurn End: After action processing\nOn Damage: When unit takes damage\nOn Action: When unit tries to act\nPassive: Always active (stat modifiers)")


func _add_skip_turn_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Skip Turn Effects")
	form.add_help_text("For effects like Sleep, Stun, or Paralysis that prevent action.")

	skips_turn_check = form.add_standalone_checkbox("Unit Cannot Act", false,
		"If checked, the affected unit loses their turn while this effect is active.")
	skips_turn_check.toggled.connect(_on_skips_turn_toggled)

	# Recovery Chance - needs visibility control so use wrapper container
	recovery_chance_container = HBoxContainer.new()
	recovery_chance_spin = SpinBox.new()
	recovery_chance_spin.min_value = 0
	recovery_chance_spin.max_value = 100
	recovery_chance_spin.value = 0
	recovery_chance_spin.suffix = "%"
	recovery_chance_spin.tooltip_text = "0% = never recover naturally, 25% = paralysis-style, 100% = always recover after 1 turn."
	recovery_chance_spin.value_changed.connect(_on_spin_changed)

	var recovery_label: Label = Label.new()
	recovery_label.text = "Recovery Chance (%):"
	recovery_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	recovery_chance_container.add_child(recovery_label)
	recovery_chance_container.add_child(recovery_chance_spin)
	form.container.add_child(recovery_chance_container)


func _add_damage_over_time_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Damage/Healing Over Time")
	form.add_help_text("HP change applied when the effect triggers.")

	damage_per_turn_spin = form.add_number_field("HP Change/Turn:", -99, 99, 0,
		"Positive values deal damage (Poison: 5-10). Negative values restore HP (Regen: -5 to -10).")
	form.add_help_text("(+ = damage, - = heal)")


func _add_stat_modifiers_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Stat Modifiers")
	form.add_help_text("Stat bonuses/penalties applied while the effect is active. Leave at 0 for no change.")

	stat_modifiers_container = VBoxContainer.new()

	# Create spin boxes for each stat using helper
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

	form.container.add_child(stat_modifiers_container)


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
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Removal Conditions")
	form.add_help_text("When should this effect be removed early?")

	removed_on_damage_check = form.add_standalone_checkbox("Remove When Damaged", false,
		"Effect is removed when the unit takes damage (like Sleep waking on hit).")
	removed_on_damage_check.toggled.connect(_on_removed_on_damage_toggled)

	# Removal Chance - needs visibility control so use wrapper container
	removal_chance_container = HBoxContainer.new()
	removal_on_damage_chance_spin = SpinBox.new()
	removal_on_damage_chance_spin.min_value = 0
	removal_on_damage_chance_spin.max_value = 100
	removal_on_damage_chance_spin.value = 100
	removal_on_damage_chance_spin.suffix = "%"
	removal_on_damage_chance_spin.tooltip_text = "100% = always wake up, 50% = 50% chance to wake."
	removal_on_damage_chance_spin.value_changed.connect(_on_spin_changed)

	var removal_label: Label = Label.new()
	removal_label.text = "Removal Chance (%):"
	removal_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	removal_chance_container.add_child(removal_label)
	removal_chance_container.add_child(removal_on_damage_chance_spin)
	form.container.add_child(removal_chance_container)


func _add_action_modifiers_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Action Modifiers")
	form.add_help_text("How does this effect modify the unit's actions?")

	action_modifier_option = form.add_dropdown("Modifier Type:", [
		{"label": "None", "id": StatusEffectData.ActionModifier.NONE},
		{"label": "Random Target", "id": StatusEffectData.ActionModifier.RANDOM_TARGET},
		{"label": "Attack Allies", "id": StatusEffectData.ActionModifier.ATTACK_ALLIES},
		{"label": "Cannot Use Magic", "id": StatusEffectData.ActionModifier.CANNOT_USE_MAGIC},
		{"label": "Cannot Use Items", "id": StatusEffectData.ActionModifier.CANNOT_USE_ITEMS},
	], "How actions are modified")
	action_modifier_option.item_selected.connect(_on_action_modifier_selected)

	# Action Modifier Chance - needs visibility control so use wrapper container
	action_modifier_chance_container = HBoxContainer.new()
	action_modifier_chance_spin = SpinBox.new()
	action_modifier_chance_spin.min_value = 0
	action_modifier_chance_spin.max_value = 100
	action_modifier_chance_spin.value = 100
	action_modifier_chance_spin.suffix = "%"
	action_modifier_chance_spin.tooltip_text = "100% = always confused, 50% = sometimes acts normally."
	action_modifier_chance_spin.value_changed.connect(_on_spin_changed)

	var chance_label: Label = Label.new()
	chance_label.text = "Modifier Chance (%):"
	chance_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	action_modifier_chance_container.add_child(chance_label)
	action_modifier_chance_container.add_child(action_modifier_chance_spin)
	form.container.add_child(action_modifier_chance_container)

	form.add_help_text("None: Normal actions\nRandom Target: Confusion - hits random unit\nAttack Allies: Berserk/Charm - forced to attack allies\nCannot Use Magic: Silence effect\nCannot Use Items: Item restriction")


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

func _on_field_changed(_value: Variant = null) -> void:
	if _updating_ui:
		return
	_mark_dirty()


func _on_name_id_changed(_values: Dictionary) -> void:
	if _updating_ui:
		return
	_mark_dirty()


func _on_color_changed(_new_color: Color) -> void:
	if _updating_ui:
		return
	_mark_dirty()


func _on_spin_changed(_new_value: float) -> void:
	if _updating_ui:
		return
	_mark_dirty()


func _on_option_selected(_index: int) -> void:
	if _updating_ui:
		return
	_mark_dirty()


func _on_skips_turn_toggled(_pressed: bool) -> void:
	_update_recovery_chance_visibility()
	if _updating_ui:
		return
	_mark_dirty()


func _on_removed_on_damage_toggled(_pressed: bool) -> void:
	_update_removal_chance_visibility()
	if _updating_ui:
		return
	_mark_dirty()


func _on_action_modifier_selected(_index: int) -> void:
	_update_action_modifier_chance_visibility()
	if _updating_ui:
		return
	_mark_dirty()
