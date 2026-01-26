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

# =============================================================================
# UI Components - Preview Section
# =============================================================================
var preview_label: RichTextLabel

# =============================================================================
# Cached Data
# =============================================================================
var _threat_weight_rows: Array[HBoxContainer] = []

# Guard to prevent false dirty state during UI population
var _updating_ui: bool = false


func _ready() -> void:
	resource_type_id = "ai_behavior"
	resource_type_name = "AI Behavior"
	# Dependencies for dropdown refresh
	resource_dependencies = ["ai_behavior"]
	super._ready()


## Override: Create the AI behavior-specific detail form
func _create_detail_form() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty_and_preview)

	_add_identity_section(form)
	_add_role_mode_section(form)
	_add_threat_assessment_section(form)
	_add_retreat_section(form)
	_add_ability_usage_section(form)
	_add_item_usage_section(form)
	_add_engagement_section(form)
	_add_preview_section(form)

	# Add the button container at the end (with separator for visual clarity)
	_add_button_container_to_detail_panel()


## Override: Load AI behavior data from resource into UI
func _load_resource_data() -> void:
	var behavior: AIBehaviorData = current_resource as AIBehaviorData
	if not behavior:
		return

	_updating_ui = true

	# Identity
	behavior_id_edit.text = behavior.behavior_id
	display_name_edit.text = behavior.display_name
	description_edit.text = behavior.description

	# Role & Mode
	_select_option_by_value(role_option, behavior.role)
	_select_option_by_value(mode_option, behavior.behavior_mode)

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

	# Update preview
	_update_preview()

	_updating_ui = false


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
	pass  # No dependencies to refresh


# =============================================================================
# UI Section Builders
# =============================================================================

func _add_identity_section(form: SparklingEditorUtils.FormBuilder) -> void:
	form.add_section("Identity")

	behavior_id_edit = form.add_text_field("Behavior ID:", "e.g., smart_healer",
		"Unique ID for referencing this behavior. Use snake_case, no spaces. E.g., aggressive_flanker.")

	display_name_edit = form.add_text_field("Display Name:", "e.g., Smart Healer",
		"Human-readable name shown in editor dropdowns. E.g., 'Aggressive Flanker'.")

	form.add_section_label("Description:")
	description_edit = TextEdit.new()
	description_edit.custom_minimum_size.y = 60
	description_edit.placeholder_text = "Describe what this AI behavior does..."
	description_edit.tooltip_text = "Notes for modders. Describe the tactical intent, e.g., 'Healer that conserves MP and prioritizes the boss.'"
	description_edit.text_changed.connect(_mark_dirty_and_preview)
	form.container.add_child(description_edit)


func _add_role_mode_section(form: SparklingEditorUtils.FormBuilder) -> void:
	form.add_section("Role & Mode")
	form.add_help_text("Role = WHAT the AI prioritizes. Mode = HOW it executes.")

	# Create role dropdown - populated after adding to container
	role_option = OptionButton.new()
	role_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_option.tooltip_text = "WHAT the AI prioritizes: support (healing), aggressive (damage), defensive (protect allies), tactical (debuffs)."
	role_option.item_selected.connect(_on_role_selected)
	form.add_labeled_control("Role:", role_option,
		"Tactical role: Support (heals), Aggressive (attacks), Defensive (protects), Tactical (debuffs)")

	# Create mode dropdown - populated after adding to container
	mode_option = OptionButton.new()
	mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_option.tooltip_text = "HOW the AI executes: aggressive (chase targets), cautious (hold position), opportunistic (exploit weaknesses)."
	mode_option.item_selected.connect(_on_mode_selected)
	form.add_labeled_control("Behavior Mode:", mode_option,
		"Execution style: Aggressive (chase), Cautious (hold), Opportunistic (exploit weakness)")

	# Populate dropdowns
	_populate_role_options()
	_populate_mode_options()


func _add_threat_assessment_section(form: SparklingEditorUtils.FormBuilder) -> void:
	form.add_section("Threat Assessment")
	form.add_help_text("Higher weights = higher priority targets. 1.0 = normal.")

	# Threat weights container (managed separately for dynamic rows)
	threat_weights_container = VBoxContainer.new()
	form.container.add_child(threat_weights_container)

	# Add button
	add_threat_weight_button = Button.new()
	add_threat_weight_button.text = "+ Add Threat Weight"
	add_threat_weight_button.pressed.connect(_on_add_threat_weight)
	form.container.add_child(add_threat_weight_button)

	# Ignore protagonist checkbox
	ignore_protagonist_check = form.add_standalone_checkbox(
		"Ignore protagonist priority (avoids obsessive hero targeting)", false,
		"[NOT YET IMPLEMENTED] Intended: When ON, AI does not prioritize the hero. Prevents 'everyone attacks Max' syndrome.")


func _add_retreat_section(form: SparklingEditorUtils.FormBuilder) -> void:
	form.add_section("Retreat & Self-Preservation")

	retreat_enabled_check = form.add_standalone_checkbox(
		"Enable retreat behavior", false,
		"When ON, unit will try to escape when wounded. Off = fights to the death.")

	retreat_threshold_spin = form.add_number_field("Retreat HP %:", 0, 100, 30,
		"HP percentage that triggers retreat. 30% = retreat when badly hurt. 50% = cautious.")

	retreat_when_outnumbered_check = form.add_standalone_checkbox(
		"Retreat when outnumbered", false,
		"Unit retreats if surrounded by more enemies than allies. Makes units self-preserving.")

	seek_healer_check = form.add_standalone_checkbox(
		"Move toward healers when wounded", false,
		"Wounded units position themselves near friendly healers for support. Smart for melee units.")


func _add_ability_usage_section(form: SparklingEditorUtils.FormBuilder) -> void:
	form.add_section("Ability Usage (Spells)")

	aoe_minimum_targets_spin = form.add_number_field("AoE Min Targets:", 1, 5, 2,
		"Only cast AoE spells if at least this many enemies are in range. 2 = efficient, 1 = aggressive.")

	conserve_mp_check = form.add_standalone_checkbox(
		"Conserve MP on heals (use lower-level spells when sufficient)", false,
		"Use Heal 1 instead of Heal 2 when target only needs small heal. Saves MP for emergencies.")

	prioritize_boss_heals_check = form.add_standalone_checkbox(
		"Prioritize healing boss/leader units", false,
		"Healers focus on boss units even if other allies are more wounded. Protects key targets.")

	use_status_effects_check = form.add_standalone_checkbox(
		"Use debuff/status effect abilities", false,
		"AI will cast sleep, poison, slow, etc. When OFF, AI only uses direct damage/healing.")

	preferred_effects_edit = form.add_text_field("Preferred Effects:",
		"e.g., poison, sleep (comma-separated)",
		"Status effects this AI prefers to cast. Leave empty for no preference.")


func _add_item_usage_section(form: SparklingEditorUtils.FormBuilder) -> void:
	form.add_section("Item Usage")

	use_healing_items_check = form.add_standalone_checkbox(
		"Use healing items when wounded", false,
		"AI will consume healing herbs, potions when HP is low. Good for boss units.")

	use_attack_items_check = form.add_standalone_checkbox(
		"Use attack items (bombs, thrown weapons)", false,
		"AI will throw bombs, use attack scrolls if in inventory. Makes encounters more dangerous.")

	use_buff_items_check = form.add_standalone_checkbox(
		"Use buff items on self or allies", false,
		"AI will use power rings, speed boots, and other buff items on self or nearby allies before combat. Prioritizes unbuffed units and bosses.")


func _add_engagement_section(form: SparklingEditorUtils.FormBuilder) -> void:
	form.add_section("Engagement Rules")

	alert_range_spin = form.add_number_field("Alert Range:", 0, 20, 8,
		"Distance at which unit notices enemies. 0 = never alert unless attacked. 8 = typical. 15+ = very aware.")

	engagement_range_spin = form.add_number_field("Engagement Range:", 0, 20, 5,
		"Distance at which unit will move toward enemies. Lower = holds position. Must be <= alert range.")

	seek_terrain_check = form.add_standalone_checkbox(
		"Seek terrain advantage (defense bonuses)", false,
		"AI prefers tiles with defense/evasion bonuses when moving to attack. Makes enemies tactically smarter.")


func _add_preview_section(form: SparklingEditorUtils.FormBuilder) -> void:
	form.add_section("Behavior Preview")

	var preview_panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = SparklingEditorUtils.create_info_panel_style()
	preview_panel.add_theme_stylebox_override("panel", style)

	preview_label = RichTextLabel.new()
	preview_label.bbcode_enabled = true
	preview_label.fit_content = true
	preview_label.custom_minimum_size = Vector2(0, 80)
	preview_label.scroll_active = false
	preview_panel.add_child(preview_label)

	form.container.add_child(preview_panel)


# =============================================================================
# Dropdown Populators
# =============================================================================

func _populate_role_options() -> void:
	role_option.clear()

	# Built-in roles (hardcoded - ConfigurableAIBrain implements these directly)
	var roles: Array[Dictionary] = [
		{"id": "aggressive", "display_name": "Aggressive", "description": "Standard attack priority - pursue and attack enemies"},
		{"id": "support", "display_name": "Support", "description": "Prioritize healing allies before attacking"},
		{"id": "defensive", "display_name": "Defensive", "description": "Protect high-value allies (bodyguard behavior)"},
		{"id": "tactical", "display_name": "Tactical", "description": "Prioritize debuffs and status effects"}
	]
	for i: int in range(roles.size()):
		var role: Dictionary = roles[i]
		var display: String = role.get("display_name", role.get("id", "unknown"))
		role_option.add_item(display, i)
		role_option.set_item_metadata(i, role.get("id", ""))
		role_option.set_item_tooltip(i, role.get("description", ""))


func _populate_mode_options() -> void:
	mode_option.clear()

	# Get modes from registry
	if ModLoader and ModLoader.ai_mode_registry:
		var modes: Array[Dictionary] = ModLoader.ai_mode_registry.get_all_modes()
		for i: int in range(modes.size()):
			var mode: Dictionary = modes[i]
			var display: String = mode.get("display_name", mode.get("id", "unknown"))
			mode_option.add_item(display, i)
			mode_option.set_item_metadata(i, mode.get("id", ""))
			mode_option.set_item_tooltip(i, mode.get("description", ""))


# =============================================================================
# Selection Helpers
# =============================================================================

func _select_option_by_value(option_button: OptionButton, value: String) -> void:
	for i: int in range(option_button.item_count):
		if option_button.get_item_metadata(i) == value:
			option_button.select(i)
			return
	# Default to first item if not found
	option_button.select(0)


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
	if _updating_ui:
		return
	_mark_dirty()
	_update_preview()


func _on_threat_weight_value_changed(_new_value: float) -> void:
	if _updating_ui:
		return
	_mark_dirty()
	_update_preview()


# =============================================================================
# Event Handlers
# =============================================================================

## Combined callback for FormBuilder on_change - marks dirty and updates preview
func _mark_dirty_and_preview() -> void:
	if _updating_ui:
		return
	_mark_dirty()
	_update_preview()


func _on_role_selected(_index: int) -> void:
	if _updating_ui:
		return
	_mark_dirty()
	_update_preview()


func _on_mode_selected(_index: int) -> void:
	if _updating_ui:
		return
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

	# Use defaults if not selected
	var display_role: String = role if not role.is_empty() else "aggressive"
	var display_mode: String = mode if not mode.is_empty() else "aggressive"

	lines.append("[b]Role:[/b] %s | [b]Mode:[/b] %s" % [display_role.capitalize(), display_mode.capitalize()])

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

	preview_label.text = "\n".join(lines)
