@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## AI Brain Editor UI
## Allows browsing and editing AIBehaviorData resources
## Creates sophisticated AI behaviors WITHOUT requiring code

# =============================================================================
# UI Components - Identity Section
# =============================================================================
var behavior_id_edit: LineEdit
var display_name_edit: LineEdit
var description_edit: TextEdit

# =============================================================================
# UI Components - Role & Mode Section
# =============================================================================
var role_option: OptionButton
var mode_option: OptionButton
var base_behavior_picker: OptionButton

# =============================================================================
# UI Components - Threat Assessment Section
# =============================================================================
var threat_weights_container: VBoxContainer
var add_threat_weight_button: Button
var ignore_protagonist_check: CheckBox

# =============================================================================
# UI Components - Retreat Section
# =============================================================================
var retreat_enabled_check: CheckBox
var retreat_threshold_spin: SpinBox
var retreat_when_outnumbered_check: CheckBox
var seek_healer_check: CheckBox

# =============================================================================
# UI Components - Ability Usage Section
# =============================================================================
var aoe_minimum_targets_spin: SpinBox
var conserve_mp_check: CheckBox
var prioritize_boss_heals_check: CheckBox
var use_status_effects_check: CheckBox
var preferred_effects_edit: LineEdit

# =============================================================================
# UI Components - Item Usage Section
# =============================================================================
var use_healing_items_check: CheckBox
var use_attack_items_check: CheckBox
var use_buff_items_check: CheckBox

# =============================================================================
# UI Components - Engagement Section
# =============================================================================
var alert_range_spin: SpinBox
var engagement_range_spin: SpinBox
var seek_terrain_check: CheckBox
var max_idle_turns_spin: SpinBox

# =============================================================================
# UI Components - Preview Section
# =============================================================================
var preview_label: RichTextLabel

# =============================================================================
# Cached Data
# =============================================================================
var _available_behaviors: Array[Resource] = []
var _threat_weight_rows: Array[HBoxContainer] = []


func _ready() -> void:
	resource_type_id = "ai_behavior"
	resource_type_name = "AI Behavior"
	# Dependencies for dropdown refresh
	resource_dependencies = ["ai_behavior"]
	super._ready()


## Override: Create the AI behavior-specific detail form
func _create_detail_form() -> void:
	_add_identity_section()
	_add_role_mode_section()
	_add_threat_assessment_section()
	_add_retreat_section()
	_add_ability_usage_section()
	_add_item_usage_section()
	_add_engagement_section()
	_add_preview_section()

	# Add the button container at the end (with separator for visual clarity)
	_add_button_container_to_detail_panel()

	# Initial cache load
	_refresh_behavior_cache()


## Override: Load AI behavior data from resource into UI
func _load_resource_data() -> void:
	var behavior: AIBehaviorData = current_resource as AIBehaviorData
	if not behavior:
		return

	# Identity
	behavior_id_edit.text = behavior.behavior_id
	display_name_edit.text = behavior.display_name
	description_edit.text = behavior.description

	# Role & Mode
	_select_option_by_value(role_option, behavior.role)
	_select_option_by_value(mode_option, behavior.behavior_mode)
	_select_base_behavior(behavior.base_behavior)

	# Threat Assessment
	ignore_protagonist_check.button_pressed = behavior.ignore_protagonist_priority
	_load_threat_weights(behavior.threat_weights)

	# Retreat
	retreat_enabled_check.button_pressed = behavior.retreat_enabled
	retreat_threshold_spin.value = behavior.retreat_hp_threshold
	retreat_when_outnumbered_check.button_pressed = behavior.retreat_when_outnumbered
	seek_healer_check.button_pressed = behavior.seek_healer_when_wounded

	# Ability Usage
	aoe_minimum_targets_spin.value = behavior.aoe_minimum_targets
	conserve_mp_check.button_pressed = behavior.conserve_mp_on_heals
	prioritize_boss_heals_check.button_pressed = behavior.prioritize_boss_heals
	use_status_effects_check.button_pressed = behavior.use_status_effects
	preferred_effects_edit.text = ", ".join(behavior.preferred_status_effects)

	# Item Usage
	use_healing_items_check.button_pressed = behavior.use_healing_items
	use_attack_items_check.button_pressed = behavior.use_attack_items
	use_buff_items_check.button_pressed = behavior.use_buff_items

	# Engagement
	alert_range_spin.value = behavior.alert_range
	engagement_range_spin.value = behavior.engagement_range
	seek_terrain_check.button_pressed = behavior.seek_terrain_advantage
	max_idle_turns_spin.value = behavior.max_idle_turns

	# Update preview
	_update_preview()


## Override: Save UI data to resource
func _save_resource_data() -> void:
	var behavior: AIBehaviorData = current_resource as AIBehaviorData
	if not behavior:
		return

	# Identity
	behavior.behavior_id = behavior_id_edit.text.strip_edges()
	behavior.display_name = display_name_edit.text.strip_edges()
	behavior.description = description_edit.text.strip_edges()

	# Role & Mode
	behavior.role = _get_selected_role()
	behavior.behavior_mode = _get_selected_mode()
	behavior.base_behavior = _get_selected_base_behavior()

	# Threat Assessment
	behavior.ignore_protagonist_priority = ignore_protagonist_check.button_pressed
	behavior.threat_weights = _collect_threat_weights()

	# Retreat
	behavior.retreat_enabled = retreat_enabled_check.button_pressed
	behavior.retreat_hp_threshold = int(retreat_threshold_spin.value)
	behavior.retreat_when_outnumbered = retreat_when_outnumbered_check.button_pressed
	behavior.seek_healer_when_wounded = seek_healer_check.button_pressed

	# Ability Usage
	behavior.aoe_minimum_targets = int(aoe_minimum_targets_spin.value)
	behavior.conserve_mp_on_heals = conserve_mp_check.button_pressed
	behavior.prioritize_boss_heals = prioritize_boss_heals_check.button_pressed
	behavior.use_status_effects = use_status_effects_check.button_pressed
	var effects_text: String = preferred_effects_edit.text.strip_edges()
	var new_effects: Array[String] = []
	if not effects_text.is_empty():
		var effect_list: PackedStringArray = effects_text.split(",")
		for effect: String in effect_list:
			var trimmed: String = effect.strip_edges()
			if not trimmed.is_empty():
				new_effects.append(trimmed)
	behavior.preferred_status_effects = new_effects

	# Item Usage
	behavior.use_healing_items = use_healing_items_check.button_pressed
	behavior.use_attack_items = use_attack_items_check.button_pressed
	behavior.use_buff_items = use_buff_items_check.button_pressed

	# Engagement
	behavior.alert_range = int(alert_range_spin.value)
	behavior.engagement_range = int(engagement_range_spin.value)
	behavior.seek_terrain_advantage = seek_terrain_check.button_pressed
	behavior.max_idle_turns = int(max_idle_turns_spin.value)


## Override: Validate resource before saving
func _validate_resource() -> Dictionary:
	var behavior: AIBehaviorData = current_resource as AIBehaviorData
	if not behavior:
		return {valid = false, errors = ["Invalid resource type"]}

	var errors: Array[String] = []

	# Validate behavior_id
	var bid: String = behavior_id_edit.text.strip_edges()
	if bid.is_empty():
		errors.append("Behavior ID cannot be empty")
	elif " " in bid:
		errors.append("Behavior ID cannot contain spaces (use underscores)")

	# Validate display name
	if display_name_edit.text.strip_edges().is_empty():
		errors.append("Display name cannot be empty")

	# Validate ranges
	if int(engagement_range_spin.value) > int(alert_range_spin.value):
		errors.append("Engagement range cannot exceed alert range")

	# Check for circular inheritance
	var base: AIBehaviorData = _get_selected_base_behavior()
	if base == behavior:
		errors.append("Behavior cannot inherit from itself")
	elif base and _would_create_circular_inheritance(behavior, base):
		errors.append("This would create circular inheritance")

	return {valid = errors.is_empty(), errors = errors}


## Override: Create a new AI behavior with defaults
func _create_new_resource() -> Resource:
	var new_behavior: AIBehaviorData = AIBehaviorData.new()
	new_behavior.behavior_id = "new_behavior"
	new_behavior.display_name = "New AI Behavior"
	new_behavior.description = "A custom AI behavior"
	new_behavior.role = "aggressive"
	new_behavior.behavior_mode = "aggressive"
	return new_behavior


## Override: Get the display name from an AI behavior resource
func _get_resource_display_name(resource: Resource) -> String:
	var behavior: AIBehaviorData = resource as AIBehaviorData
	if behavior:
		if not behavior.display_name.is_empty():
			return behavior.display_name
		if not behavior.behavior_id.is_empty():
			return behavior.behavior_id
	return "Unnamed Behavior"


## Override: Called when dependent resources change
func _on_dependencies_changed(_changed_type: String) -> void:
	_refresh_behavior_cache()
	if base_behavior_picker:
		_populate_base_behavior_picker()


# =============================================================================
# UI Section Builders
# =============================================================================

func _add_identity_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Identity"
	section_label.add_theme_font_size_override("font_size", EditorThemeUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	# Behavior ID
	var id_container: HBoxContainer = HBoxContainer.new()
	var id_label: Label = Label.new()
	id_label.text = "Behavior ID:"
	id_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	id_label.tooltip_text = "Unique identifier used in BattleData references (no spaces)"
	id_container.add_child(id_label)

	behavior_id_edit = LineEdit.new()
	behavior_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	behavior_id_edit.placeholder_text = "e.g., smart_healer"
	behavior_id_edit.text_changed.connect(_on_field_changed)
	id_container.add_child(behavior_id_edit)
	section.add_child(id_container)

	# Display Name
	var name_container: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = "Display Name:"
	name_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	name_container.add_child(name_label)

	display_name_edit = LineEdit.new()
	display_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_name_edit.placeholder_text = "e.g., Smart Healer"
	display_name_edit.text_changed.connect(_on_field_changed)
	name_container.add_child(display_name_edit)
	section.add_child(name_container)

	# Description
	var desc_label: Label = Label.new()
	desc_label.text = "Description:"
	section.add_child(desc_label)

	description_edit = TextEdit.new()
	description_edit.custom_minimum_size.y = 60
	description_edit.placeholder_text = "Describe what this AI behavior does..."
	description_edit.text_changed.connect(_on_field_changed)
	section.add_child(description_edit)

	detail_panel.add_child(section)


func _add_role_mode_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Role & Mode"
	section_label.add_theme_font_size_override("font_size", EditorThemeUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Role = WHAT the AI prioritizes. Mode = HOW it executes."
	help_label.add_theme_color_override("font_color", EditorThemeUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", EditorThemeUtils.HELP_FONT_SIZE)
	section.add_child(help_label)

	# Role
	var role_container: HBoxContainer = HBoxContainer.new()
	var role_label: Label = Label.new()
	role_label.text = "Role:"
	role_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	role_label.tooltip_text = "Tactical role: Support (heals), Aggressive (attacks), Defensive (protects), Tactical (debuffs)"
	role_container.add_child(role_label)

	role_option = OptionButton.new()
	role_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_option.item_selected.connect(_on_role_selected)
	role_container.add_child(role_option)
	section.add_child(role_container)

	# Mode
	var mode_container: HBoxContainer = HBoxContainer.new()
	var mode_label: Label = Label.new()
	mode_label.text = "Behavior Mode:"
	mode_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	mode_label.tooltip_text = "Execution style: Aggressive (chase), Cautious (hold), Opportunistic (exploit weakness)"
	mode_container.add_child(mode_label)

	mode_option = OptionButton.new()
	mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_option.item_selected.connect(_on_mode_selected)
	mode_container.add_child(mode_option)
	section.add_child(mode_container)

	# Base Behavior (Inheritance)
	var base_container: HBoxContainer = HBoxContainer.new()
	var base_label: Label = Label.new()
	base_label.text = "Inherits From:"
	base_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	base_label.tooltip_text = "Optional base behavior to inherit settings from"
	base_container.add_child(base_label)

	base_behavior_picker = OptionButton.new()
	base_behavior_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	base_behavior_picker.item_selected.connect(_on_base_behavior_selected)
	base_container.add_child(base_behavior_picker)
	section.add_child(base_container)

	# Populate dropdowns
	_populate_role_options()
	_populate_mode_options()
	_populate_base_behavior_picker()

	detail_panel.add_child(section)


func _add_threat_assessment_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Threat Assessment"
	section_label.add_theme_font_size_override("font_size", EditorThemeUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Higher weights = higher priority targets. 1.0 = normal."
	help_label.add_theme_color_override("font_color", EditorThemeUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", EditorThemeUtils.HELP_FONT_SIZE)
	section.add_child(help_label)

	# Threat weights container
	threat_weights_container = VBoxContainer.new()
	section.add_child(threat_weights_container)

	# Add button
	add_threat_weight_button = Button.new()
	add_threat_weight_button.text = "+ Add Threat Weight"
	add_threat_weight_button.pressed.connect(_on_add_threat_weight)
	section.add_child(add_threat_weight_button)

	# Ignore protagonist checkbox
	ignore_protagonist_check = CheckBox.new()
	ignore_protagonist_check.text = "Ignore protagonist priority (avoids obsessive hero targeting)"
	ignore_protagonist_check.toggled.connect(_on_checkbox_toggled)
	section.add_child(ignore_protagonist_check)

	detail_panel.add_child(section)


func _add_retreat_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Retreat & Self-Preservation"
	section_label.add_theme_font_size_override("font_size", EditorThemeUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	# Enable retreat
	retreat_enabled_check = CheckBox.new()
	retreat_enabled_check.text = "Enable retreat behavior"
	retreat_enabled_check.toggled.connect(_on_checkbox_toggled)
	section.add_child(retreat_enabled_check)

	# Retreat threshold
	var threshold_container: HBoxContainer = HBoxContainer.new()
	var threshold_label: Label = Label.new()
	threshold_label.text = "Retreat HP %:"
	threshold_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	threshold_container.add_child(threshold_label)

	retreat_threshold_spin = SpinBox.new()
	retreat_threshold_spin.min_value = 0
	retreat_threshold_spin.max_value = 100
	retreat_threshold_spin.value = 30
	retreat_threshold_spin.value_changed.connect(_on_spin_changed)
	threshold_container.add_child(retreat_threshold_spin)
	section.add_child(threshold_container)

	# Outnumbered retreat
	retreat_when_outnumbered_check = CheckBox.new()
	retreat_when_outnumbered_check.text = "Retreat when outnumbered"
	retreat_when_outnumbered_check.toggled.connect(_on_checkbox_toggled)
	section.add_child(retreat_when_outnumbered_check)

	# Seek healer
	seek_healer_check = CheckBox.new()
	seek_healer_check.text = "Move toward healers when wounded"
	seek_healer_check.toggled.connect(_on_checkbox_toggled)
	section.add_child(seek_healer_check)

	detail_panel.add_child(section)


func _add_ability_usage_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Ability Usage (Spells)"
	section_label.add_theme_font_size_override("font_size", EditorThemeUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	# AoE minimum targets
	var aoe_container: HBoxContainer = HBoxContainer.new()
	var aoe_label: Label = Label.new()
	aoe_label.text = "AoE Min Targets:"
	aoe_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	aoe_label.tooltip_text = "Minimum enemies in area before using AoE spells"
	aoe_container.add_child(aoe_label)

	aoe_minimum_targets_spin = SpinBox.new()
	aoe_minimum_targets_spin.min_value = 1
	aoe_minimum_targets_spin.max_value = 5
	aoe_minimum_targets_spin.value = 2
	aoe_minimum_targets_spin.value_changed.connect(_on_spin_changed)
	aoe_container.add_child(aoe_minimum_targets_spin)
	section.add_child(aoe_container)

	# Conserve MP
	conserve_mp_check = CheckBox.new()
	conserve_mp_check.text = "Conserve MP on heals (use lower-level spells when sufficient)"
	conserve_mp_check.toggled.connect(_on_checkbox_toggled)
	section.add_child(conserve_mp_check)

	# Boss heal priority
	prioritize_boss_heals_check = CheckBox.new()
	prioritize_boss_heals_check.text = "Prioritize healing boss/leader units"
	prioritize_boss_heals_check.toggled.connect(_on_checkbox_toggled)
	section.add_child(prioritize_boss_heals_check)

	# Status effects
	use_status_effects_check = CheckBox.new()
	use_status_effects_check.text = "Use debuff/status effect abilities"
	use_status_effects_check.toggled.connect(_on_checkbox_toggled)
	section.add_child(use_status_effects_check)

	# Preferred effects
	var effects_container: HBoxContainer = HBoxContainer.new()
	var effects_label: Label = Label.new()
	effects_label.text = "Preferred Effects:"
	effects_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	effects_container.add_child(effects_label)

	preferred_effects_edit = LineEdit.new()
	preferred_effects_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preferred_effects_edit.placeholder_text = "e.g., poison, sleep (comma-separated)"
	preferred_effects_edit.text_changed.connect(_on_field_changed)
	effects_container.add_child(preferred_effects_edit)
	section.add_child(effects_container)

	detail_panel.add_child(section)


func _add_item_usage_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Item Usage"
	section_label.add_theme_font_size_override("font_size", EditorThemeUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	use_healing_items_check = CheckBox.new()
	use_healing_items_check.text = "Use healing items when wounded"
	use_healing_items_check.toggled.connect(_on_checkbox_toggled)
	section.add_child(use_healing_items_check)

	use_attack_items_check = CheckBox.new()
	use_attack_items_check.text = "Use attack items (bombs, thrown weapons)"
	use_attack_items_check.toggled.connect(_on_checkbox_toggled)
	section.add_child(use_attack_items_check)

	use_buff_items_check = CheckBox.new()
	use_buff_items_check.text = "Use buff items on self or allies"
	use_buff_items_check.toggled.connect(_on_checkbox_toggled)
	section.add_child(use_buff_items_check)

	detail_panel.add_child(section)


func _add_engagement_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Engagement Rules"
	section_label.add_theme_font_size_override("font_size", EditorThemeUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	# Alert range
	var alert_container: HBoxContainer = HBoxContainer.new()
	var alert_label: Label = Label.new()
	alert_label.text = "Alert Range:"
	alert_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	alert_label.tooltip_text = "Distance at which unit becomes aware of enemies"
	alert_container.add_child(alert_label)

	alert_range_spin = SpinBox.new()
	alert_range_spin.min_value = 0
	alert_range_spin.max_value = 20
	alert_range_spin.value = 8
	alert_range_spin.value_changed.connect(_on_spin_changed)
	alert_container.add_child(alert_range_spin)
	section.add_child(alert_container)

	# Engagement range
	var engage_container: HBoxContainer = HBoxContainer.new()
	var engage_label: Label = Label.new()
	engage_label.text = "Engagement Range:"
	engage_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	engage_label.tooltip_text = "Distance at which unit actively pursues enemies"
	engage_container.add_child(engage_label)

	engagement_range_spin = SpinBox.new()
	engagement_range_spin.min_value = 0
	engagement_range_spin.max_value = 20
	engagement_range_spin.value = 5
	engagement_range_spin.value_changed.connect(_on_spin_changed)
	engage_container.add_child(engagement_range_spin)
	section.add_child(engage_container)

	# Terrain advantage
	seek_terrain_check = CheckBox.new()
	seek_terrain_check.text = "Seek terrain advantage (defense bonuses)"
	seek_terrain_check.toggled.connect(_on_checkbox_toggled)
	section.add_child(seek_terrain_check)

	# Max idle turns
	var idle_container: HBoxContainer = HBoxContainer.new()
	var idle_label: Label = Label.new()
	idle_label.text = "Max Idle Turns:"
	idle_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	idle_label.tooltip_text = "Turns waiting before becoming aggressive (0 = stay passive)"
	idle_container.add_child(idle_label)

	max_idle_turns_spin = SpinBox.new()
	max_idle_turns_spin.min_value = 0
	max_idle_turns_spin.max_value = 99
	max_idle_turns_spin.value = 0
	max_idle_turns_spin.value_changed.connect(_on_spin_changed)
	idle_container.add_child(max_idle_turns_spin)
	section.add_child(idle_container)

	detail_panel.add_child(section)


func _add_preview_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Behavior Preview"
	section_label.add_theme_font_size_override("font_size", EditorThemeUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var preview_panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = EditorThemeUtils.create_info_panel_style()
	preview_panel.add_theme_stylebox_override("panel", style)

	preview_label = RichTextLabel.new()
	preview_label.bbcode_enabled = true
	preview_label.fit_content = true
	preview_label.custom_minimum_size = Vector2(0, 80)
	preview_label.scroll_active = false
	preview_panel.add_child(preview_label)

	section.add_child(preview_panel)
	detail_panel.add_child(section)


# =============================================================================
# Dropdown Populators
# =============================================================================

func _populate_role_options() -> void:
	role_option.clear()
	role_option.add_item("(Inherit from base)", 0)
	role_option.set_item_metadata(0, "")

	# Get roles from registry
	if ModLoader and ModLoader.ai_role_registry:
		var roles: Array[Dictionary] = ModLoader.ai_role_registry.get_all_roles()
		for i: int in range(roles.size()):
			var role: Dictionary = roles[i]
			var display: String = role.get("display_name", role.get("id", "unknown"))
			role_option.add_item(display, i + 1)
			role_option.set_item_metadata(i + 1, role.get("id", ""))
			role_option.set_item_tooltip(i + 1, role.get("description", ""))


func _populate_mode_options() -> void:
	mode_option.clear()
	mode_option.add_item("(Inherit from base)", 0)
	mode_option.set_item_metadata(0, "")

	# Get modes from registry
	if ModLoader and ModLoader.ai_mode_registry:
		var modes: Array[Dictionary] = ModLoader.ai_mode_registry.get_all_modes()
		for i: int in range(modes.size()):
			var mode: Dictionary = modes[i]
			var display: String = mode.get("display_name", mode.get("id", "unknown"))
			mode_option.add_item(display, i + 1)
			mode_option.set_item_metadata(i + 1, mode.get("id", ""))
			mode_option.set_item_tooltip(i + 1, mode.get("description", ""))


func _populate_base_behavior_picker() -> void:
	base_behavior_picker.clear()
	base_behavior_picker.add_item("(None)", 0)
	base_behavior_picker.set_item_metadata(0, null)

	_refresh_behavior_cache()

	for i: int in range(_available_behaviors.size()):
		var behavior: AIBehaviorData = _available_behaviors[i] as AIBehaviorData
		if behavior:
			var display: String = behavior.display_name if not behavior.display_name.is_empty() else behavior.behavior_id
			base_behavior_picker.add_item(display, i + 1)
			base_behavior_picker.set_item_metadata(i + 1, behavior)


func _refresh_behavior_cache() -> void:
	_available_behaviors.clear()
	if ModLoader and ModLoader.registry:
		var all_behaviors: Array[Resource] = ModLoader.registry.get_all_resources("ai_behavior")
		for res: Resource in all_behaviors:
			_available_behaviors.append(res)


# =============================================================================
# Selection Helpers
# =============================================================================

func _select_option_by_value(option_button: OptionButton, value: String) -> void:
	for i: int in range(option_button.item_count):
		if option_button.get_item_metadata(i) == value:
			option_button.select(i)
			return
	# Default to first item (inherit) if not found
	option_button.select(0)


func _select_base_behavior(base: AIBehaviorData) -> void:
	if not base:
		base_behavior_picker.select(0)
		return

	for i: int in range(base_behavior_picker.item_count):
		var meta: Variant = base_behavior_picker.get_item_metadata(i)
		if meta == base:
			base_behavior_picker.select(i)
			return

	# Not found - select none
	base_behavior_picker.select(0)


func _get_selected_role() -> String:
	var idx: int = role_option.selected
	if idx >= 0:
		return str(role_option.get_item_metadata(idx))
	return ""


func _get_selected_mode() -> String:
	var idx: int = mode_option.selected
	if idx >= 0:
		return str(mode_option.get_item_metadata(idx))
	return ""


func _get_selected_base_behavior() -> AIBehaviorData:
	var idx: int = base_behavior_picker.selected
	if idx > 0:  # 0 is "None"
		return base_behavior_picker.get_item_metadata(idx) as AIBehaviorData
	return null


# =============================================================================
# Threat Weight Management
# =============================================================================

func _load_threat_weights(weights: Dictionary) -> void:
	# Clear existing rows
	for row: HBoxContainer in _threat_weight_rows:
		row.queue_free()
	_threat_weight_rows.clear()

	# Add rows for each weight
	for key: String in weights.keys():
		_add_threat_weight_row(key, weights[key])

	# Add default weights if empty
	if weights.is_empty():
		_add_threat_weight_row("wounded_target", 1.0)
		_add_threat_weight_row("healer", 1.0)
		_add_threat_weight_row("damage_dealer", 1.0)
		_add_threat_weight_row("proximity", 1.0)


func _add_threat_weight_row(key: String = "", value: float = 1.0) -> void:
	var row: HBoxContainer = HBoxContainer.new()

	var key_edit: LineEdit = LineEdit.new()
	key_edit.text = key
	key_edit.placeholder_text = "factor_name"
	key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_edit.text_changed.connect(_on_threat_weight_changed)
	row.add_child(key_edit)

	var value_spin: SpinBox = SpinBox.new()
	value_spin.min_value = 0.0
	value_spin.max_value = 5.0
	value_spin.step = 0.1
	value_spin.value = value
	value_spin.custom_minimum_size.x = 70
	value_spin.value_changed.connect(_on_threat_weight_value_changed)
	row.add_child(value_spin)

	var remove_btn: Button = Button.new()
	remove_btn.text = "X"
	remove_btn.tooltip_text = "Remove this threat weight"
	remove_btn.pressed.connect(_on_remove_threat_weight.bind(row))
	row.add_child(remove_btn)

	threat_weights_container.add_child(row)
	_threat_weight_rows.append(row)


func _collect_threat_weights() -> Dictionary:
	var weights: Dictionary = {}
	for row: HBoxContainer in _threat_weight_rows:
		var children: Array[Node] = row.get_children()
		if children.size() >= 2:
			var key_edit: LineEdit = children[0] as LineEdit
			var value_spin: SpinBox = children[1] as SpinBox
			if key_edit and value_spin:
				var key: String = key_edit.text.strip_edges()
				if not key.is_empty():
					weights[key] = value_spin.value
	return weights


func _on_add_threat_weight() -> void:
	_add_threat_weight_row()
	_mark_dirty()


func _on_remove_threat_weight(row: HBoxContainer) -> void:
	var idx: int = _threat_weight_rows.find(row)
	if idx >= 0:
		_threat_weight_rows.remove_at(idx)
	row.queue_free()
	_mark_dirty()


func _on_threat_weight_changed(_new_text: String) -> void:
	_mark_dirty()
	_update_preview()


func _on_threat_weight_value_changed(_new_value: float) -> void:
	_mark_dirty()
	_update_preview()


# =============================================================================
# Event Handlers
# =============================================================================

func _on_field_changed(_new_text: String = "") -> void:
	_mark_dirty()
	_update_preview()


func _on_checkbox_toggled(_pressed: bool) -> void:
	_mark_dirty()
	_update_preview()


func _on_spin_changed(_new_value: float) -> void:
	_mark_dirty()
	_update_preview()


func _on_role_selected(_index: int) -> void:
	_mark_dirty()
	_update_preview()


func _on_mode_selected(_index: int) -> void:
	_mark_dirty()
	_update_preview()


func _on_base_behavior_selected(_index: int) -> void:
	_mark_dirty()
	_update_preview()


# =============================================================================
# Preview Generation
# =============================================================================

func _update_preview() -> void:
	if not preview_label:
		return

	var lines: Array[String] = []

	# Role and Mode
	var role: String = _get_selected_role()
	var mode: String = _get_selected_mode()
	var base: AIBehaviorData = _get_selected_base_behavior()

	var effective_role: String = role if not role.is_empty() else (base.get_effective_role() if base else "aggressive")
	var effective_mode: String = mode if not mode.is_empty() else (base.get_effective_mode() if base else "aggressive")

	lines.append("[b]Role:[/b] %s | [b]Mode:[/b] %s" % [effective_role.capitalize(), effective_mode.capitalize()])

	# Retreat behavior
	if retreat_enabled_check.button_pressed:
		lines.append("[b]Retreat:[/b] At %d%% HP" % int(retreat_threshold_spin.value))
	else:
		lines.append("[b]Retreat:[/b] Disabled")

	# Key behaviors
	var behaviors: Array[String] = []
	if conserve_mp_check.button_pressed:
		behaviors.append("conserves MP")
	if prioritize_boss_heals_check.button_pressed:
		behaviors.append("prioritizes boss heals")
	if use_status_effects_check.button_pressed:
		behaviors.append("uses debuffs")
	if seek_terrain_check.button_pressed:
		behaviors.append("seeks terrain advantage")

	if not behaviors.is_empty():
		lines.append("[b]Traits:[/b] " + ", ".join(behaviors))

	# Inheritance
	if base:
		lines.append("[b]Inherits from:[/b] " + (base.display_name if not base.display_name.is_empty() else base.behavior_id))

	preview_label.text = "\n".join(lines)


# =============================================================================
# Validation Helpers
# =============================================================================

func _would_create_circular_inheritance(behavior: AIBehaviorData, new_base: AIBehaviorData) -> bool:
	# Check if new_base eventually points back to behavior
	var visited: Array[AIBehaviorData] = []
	var current: AIBehaviorData = new_base

	while current != null:
		if current == behavior:
			return true
		if current in visited:
			return true  # Already a cycle in the base chain
		visited.append(current)
		current = current.base_behavior

	return false
