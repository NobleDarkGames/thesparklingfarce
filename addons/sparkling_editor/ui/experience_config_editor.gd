@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Experience Config Editor UI
## Allows browsing and editing ExperienceConfig resources
## Experience configs define XP awards, leveling, promotion, and anti-spam settings

# =============================================================================
# COMBAT XP SETTINGS
# =============================================================================

var enable_formation_xp_check: CheckBox
var formation_radius_spin: SpinBox
var formation_multiplier_spin: SpinBox
var formation_cap_ratio_spin: SpinBox
var formation_catch_up_rate_spin: SpinBox
var min_damage_xp_ratio_spin: SpinBox
var kill_bonus_multiplier_spin: SpinBox
var max_xp_per_action_spin: SpinBox

# =============================================================================
# SUPPORT XP SETTINGS
# =============================================================================

var enable_enhanced_support_xp_check: CheckBox
var heal_base_xp_spin: SpinBox
var heal_ratio_multiplier_spin: SpinBox
var buff_base_xp_spin: SpinBox
var debuff_base_xp_spin: SpinBox
var support_catch_up_rate_spin: SpinBox

# =============================================================================
# ANTI-SPAM SETTINGS
# =============================================================================

var anti_spam_enabled_check: CheckBox
var spam_threshold_medium_spin: SpinBox
var spam_threshold_heavy_spin: SpinBox

# =============================================================================
# LEVELING SETTINGS
# =============================================================================

var xp_per_level_spin: SpinBox
var max_level_spin: SpinBox
var promotion_level_spin: SpinBox

# =============================================================================
# PROMOTION SETTINGS
# =============================================================================

var promotion_resets_level_check: CheckBox
var consume_promotion_item_check: CheckBox
var promotion_bonus_hp_spin: SpinBox
var promotion_bonus_mp_spin: SpinBox
var promotion_bonus_strength_spin: SpinBox
var promotion_bonus_defense_spin: SpinBox
var promotion_bonus_agility_spin: SpinBox
var promotion_bonus_intelligence_spin: SpinBox
var promotion_bonus_luck_spin: SpinBox

# =============================================================================
# ADJUTANT SYSTEM
# =============================================================================

var enable_adjutant_system_check: CheckBox
var adjutant_xp_share_spin: SpinBox
var max_adjutants_spin: SpinBox


func _ready() -> void:
	resource_type_id = "experience_config"
	resource_type_name = "Experience Config"
	super._ready()


## Override: Create the experience config-specific detail form
func _create_detail_form() -> void:
	# Combat XP Settings section
	_add_combat_xp_section()

	# Support XP Settings section
	_add_support_xp_section()

	# Anti-Spam Settings section
	_add_anti_spam_section()

	# Leveling Settings section
	_add_leveling_section()

	# Promotion Settings section
	_add_promotion_section()

	# Adjutant System section
	_add_adjutant_section()

	# Add the button container at the end
	_add_button_container_to_detail_panel()


## Override: Load experience config data from resource into UI
func _load_resource_data() -> void:
	var config: ExperienceConfig = current_resource as ExperienceConfig
	if not config:
		return

	# Combat XP Settings
	enable_formation_xp_check.button_pressed = config.enable_formation_xp
	formation_radius_spin.value = config.formation_radius
	formation_multiplier_spin.value = config.formation_multiplier
	formation_cap_ratio_spin.value = config.formation_cap_ratio
	formation_catch_up_rate_spin.value = config.formation_catch_up_rate
	min_damage_xp_ratio_spin.value = config.min_damage_xp_ratio
	kill_bonus_multiplier_spin.value = config.kill_bonus_multiplier
	max_xp_per_action_spin.value = config.max_xp_per_action

	# Support XP Settings
	enable_enhanced_support_xp_check.button_pressed = config.enable_enhanced_support_xp
	heal_base_xp_spin.value = config.heal_base_xp
	heal_ratio_multiplier_spin.value = config.heal_ratio_multiplier
	buff_base_xp_spin.value = config.buff_base_xp
	debuff_base_xp_spin.value = config.debuff_base_xp
	support_catch_up_rate_spin.value = config.support_catch_up_rate

	# Anti-Spam Settings
	anti_spam_enabled_check.button_pressed = config.anti_spam_enabled
	spam_threshold_medium_spin.value = config.spam_threshold_medium
	spam_threshold_heavy_spin.value = config.spam_threshold_heavy

	# Leveling Settings
	xp_per_level_spin.value = config.xp_per_level
	max_level_spin.value = config.max_level
	promotion_level_spin.value = config.promotion_level

	# Promotion Settings
	promotion_resets_level_check.button_pressed = config.promotion_resets_level
	consume_promotion_item_check.button_pressed = config.consume_promotion_item
	promotion_bonus_hp_spin.value = config.promotion_bonus_hp
	promotion_bonus_mp_spin.value = config.promotion_bonus_mp
	promotion_bonus_strength_spin.value = config.promotion_bonus_strength
	promotion_bonus_defense_spin.value = config.promotion_bonus_defense
	promotion_bonus_agility_spin.value = config.promotion_bonus_agility
	promotion_bonus_intelligence_spin.value = config.promotion_bonus_intelligence
	promotion_bonus_luck_spin.value = config.promotion_bonus_luck

	# Adjutant System
	enable_adjutant_system_check.button_pressed = config.enable_adjutant_system
	adjutant_xp_share_spin.value = config.adjutant_xp_share
	max_adjutants_spin.value = config.max_adjutants

	# Update visual feedback for toggle states
	_update_formation_xp_visual_feedback()
	_update_support_xp_visual_feedback()
	_update_anti_spam_visual_feedback()
	_update_adjutant_visual_feedback()


## Override: Save UI data to resource
func _save_resource_data() -> void:
	var config: ExperienceConfig = current_resource as ExperienceConfig
	if not config:
		return

	# Combat XP Settings
	config.enable_formation_xp = enable_formation_xp_check.button_pressed
	config.formation_radius = int(formation_radius_spin.value)
	config.formation_multiplier = formation_multiplier_spin.value
	config.formation_cap_ratio = formation_cap_ratio_spin.value
	config.formation_catch_up_rate = formation_catch_up_rate_spin.value
	config.min_damage_xp_ratio = min_damage_xp_ratio_spin.value
	config.kill_bonus_multiplier = kill_bonus_multiplier_spin.value
	config.max_xp_per_action = int(max_xp_per_action_spin.value)

	# Support XP Settings
	config.enable_enhanced_support_xp = enable_enhanced_support_xp_check.button_pressed
	config.heal_base_xp = int(heal_base_xp_spin.value)
	config.heal_ratio_multiplier = int(heal_ratio_multiplier_spin.value)
	config.buff_base_xp = int(buff_base_xp_spin.value)
	config.debuff_base_xp = int(debuff_base_xp_spin.value)
	config.support_catch_up_rate = support_catch_up_rate_spin.value

	# Anti-Spam Settings
	config.anti_spam_enabled = anti_spam_enabled_check.button_pressed
	config.spam_threshold_medium = int(spam_threshold_medium_spin.value)
	config.spam_threshold_heavy = int(spam_threshold_heavy_spin.value)

	# Leveling Settings
	config.xp_per_level = int(xp_per_level_spin.value)
	config.max_level = int(max_level_spin.value)
	config.promotion_level = int(promotion_level_spin.value)

	# Promotion Settings
	config.promotion_resets_level = promotion_resets_level_check.button_pressed
	config.consume_promotion_item = consume_promotion_item_check.button_pressed
	config.promotion_bonus_hp = int(promotion_bonus_hp_spin.value)
	config.promotion_bonus_mp = int(promotion_bonus_mp_spin.value)
	config.promotion_bonus_strength = int(promotion_bonus_strength_spin.value)
	config.promotion_bonus_defense = int(promotion_bonus_defense_spin.value)
	config.promotion_bonus_agility = int(promotion_bonus_agility_spin.value)
	config.promotion_bonus_intelligence = int(promotion_bonus_intelligence_spin.value)
	config.promotion_bonus_luck = int(promotion_bonus_luck_spin.value)

	# Adjutant System
	config.enable_adjutant_system = enable_adjutant_system_check.button_pressed
	config.adjutant_xp_share = adjutant_xp_share_spin.value
	config.max_adjutants = int(max_adjutants_spin.value)


## Override: Validate resource before saving
func _validate_resource() -> Dictionary:
	var config: ExperienceConfig = current_resource as ExperienceConfig
	if not config:
		return {valid = false, errors = ["Invalid resource type"]}

	var errors: Array[String] = []

	# Validate XP per level
	if xp_per_level_spin.value < 1:
		errors.append("XP per level must be at least 1")

	# Validate max level
	if max_level_spin.value < 1:
		errors.append("Max level must be at least 1")

	# Validate promotion level is <= max level
	if promotion_level_spin.value > max_level_spin.value:
		errors.append("Promotion level cannot exceed max level")

	# Validate anti-spam thresholds
	if spam_threshold_medium_spin.value >= spam_threshold_heavy_spin.value:
		errors.append("Medium spam threshold must be less than heavy threshold")

	# Validate adjutant settings if enabled
	if enable_adjutant_system_check.button_pressed:
		if max_adjutants_spin.value < 1:
			errors.append("Max adjutants must be at least 1 when adjutant system is enabled")

	return {valid = errors.is_empty(), errors = errors}


## Override: Check for references before deletion
func _check_resource_references(_resource_to_check: Resource) -> Array[String]:
	# ExperienceConfig is typically referenced by campaigns or NewGameConfig
	# For now, return empty - experience config deletion is typically safe
	return []


## Override: Create a new experience config with defaults
func _create_new_resource() -> Resource:
	var new_config: ExperienceConfig = ExperienceConfig.new()
	# Defaults are already set in the resource class
	return new_config


## Override: Get the display name from an experience config resource
func _get_resource_display_name(resource: Resource) -> String:
	# ExperienceConfig doesn't have a name field, use the filename
	if resource and resource.resource_path:
		return resource.resource_path.get_file().get_basename().capitalize().replace("_", " ")
	return "Unnamed Config"


# =============================================================================
# SECTION BUILDERS
# =============================================================================

func _add_combat_xp_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Combat XP Settings"
	section_label.add_theme_font_size_override("font_size", EditorThemeUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Configure how XP is awarded during combat for attacks, kills, and formation bonuses."
	help_label.add_theme_color_override("font_color", EditorThemeUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", EditorThemeUtils.HELP_FONT_SIZE)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(help_label)

	# Enable Formation XP
	enable_formation_xp_check = CheckBox.new()
	enable_formation_xp_check.text = "Enable Formation XP"
	enable_formation_xp_check.tooltip_text = "Award XP to nearby allies when a unit attacks (rewards tactical positioning)"
	enable_formation_xp_check.toggled.connect(_on_formation_xp_toggled)
	section.add_child(enable_formation_xp_check)

	# Formation Radius
	var radius_container: HBoxContainer = _create_spin_row(
		"Formation Radius:",
		"Radius in grid cells for formation XP (allies within this distance get XP)",
		1, 10, 1
	)
	formation_radius_spin = radius_container.get_child(1) as SpinBox
	formation_radius_spin.suffix = " cells"
	section.add_child(radius_container)

	# Formation Multiplier
	var mult_container: HBoxContainer = _create_spin_row(
		"Formation Multiplier:",
		"XP multiplier per ally (0.15 = 15% of base XP per nearby ally)",
		0.0, 1.0, 0.01
	)
	formation_multiplier_spin = mult_container.get_child(1) as SpinBox
	section.add_child(mult_container)

	# Formation Cap Ratio
	var cap_container: HBoxContainer = _create_spin_row(
		"Formation Cap:",
		"Cap formation XP at this percentage of attacker's actual XP",
		0.0, 1.0, 0.05
	)
	formation_cap_ratio_spin = cap_container.get_child(1) as SpinBox
	section.add_child(cap_container)

	# Formation Catch-up Rate
	var catchup_container: HBoxContainer = _create_spin_row(
		"Catch-up Rate:",
		"Bonus/penalty per level difference from party average",
		0.0, 0.5, 0.01
	)
	formation_catch_up_rate_spin = catchup_container.get_child(1) as SpinBox
	section.add_child(catchup_container)

	# Min Damage XP Ratio
	var min_dmg_container: HBoxContainer = _create_spin_row(
		"Min Damage XP Ratio:",
		"Minimum XP for any successful attack (as ratio of base XP)",
		0.0, 0.5, 0.01
	)
	min_damage_xp_ratio_spin = min_dmg_container.get_child(1) as SpinBox
	section.add_child(min_dmg_container)

	# Kill Bonus Multiplier
	var kill_container: HBoxContainer = _create_spin_row(
		"Kill Bonus Multiplier:",
		"XP bonus for landing the killing blow (0.5 = 50% of base XP added)",
		0.0, 2.0, 0.1
	)
	kill_bonus_multiplier_spin = kill_container.get_child(1) as SpinBox
	section.add_child(kill_container)

	# Max XP Per Action
	var max_xp_container: HBoxContainer = _create_spin_row(
		"Max XP Per Action:",
		"Maximum XP that can be awarded per single action",
		1, 100, 1
	)
	max_xp_per_action_spin = max_xp_container.get_child(1) as SpinBox
	max_xp_per_action_spin.suffix = " XP"
	section.add_child(max_xp_container)

	detail_panel.add_child(section)

	# Add separator
	var sep: HSeparator = HSeparator.new()
	detail_panel.add_child(sep)


func _add_support_xp_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Support XP Settings"
	section_label.add_theme_font_size_override("font_size", EditorThemeUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Configure XP awards for healing, buffs, and debuffs."
	help_label.add_theme_color_override("font_color", EditorThemeUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", EditorThemeUtils.HELP_FONT_SIZE)
	section.add_child(help_label)

	# Enable Enhanced Support XP
	enable_enhanced_support_xp_check = CheckBox.new()
	enable_enhanced_support_xp_check.text = "Enable Enhanced Support XP"
	enable_enhanced_support_xp_check.tooltip_text = "Award bonus XP for healing, buffs, and debuffs"
	enable_enhanced_support_xp_check.toggled.connect(_on_support_xp_toggled)
	section.add_child(enable_enhanced_support_xp_check)

	# Heal Base XP
	var heal_base_container: HBoxContainer = _create_spin_row(
		"Heal Base XP:",
		"Base XP awarded for healing (before HP ratio bonus)",
		0, 50, 1
	)
	heal_base_xp_spin = heal_base_container.get_child(1) as SpinBox
	heal_base_xp_spin.suffix = " XP"
	section.add_child(heal_base_container)

	# Heal Ratio Multiplier
	var heal_ratio_container: HBoxContainer = _create_spin_row(
		"Heal Ratio Multiplier:",
		"Multiplier for healing XP based on HP restored (value * HP restored / Max HP)",
		0, 50, 1
	)
	heal_ratio_multiplier_spin = heal_ratio_container.get_child(1) as SpinBox
	section.add_child(heal_ratio_container)

	# Buff Base XP
	var buff_container: HBoxContainer = _create_spin_row(
		"Buff Base XP:",
		"Base XP awarded for casting buff spells",
		0, 50, 1
	)
	buff_base_xp_spin = buff_container.get_child(1) as SpinBox
	buff_base_xp_spin.suffix = " XP"
	section.add_child(buff_container)

	# Debuff Base XP
	var debuff_container: HBoxContainer = _create_spin_row(
		"Debuff Base XP:",
		"Base XP awarded for casting debuff spells",
		0, 50, 1
	)
	debuff_base_xp_spin = debuff_container.get_child(1) as SpinBox
	debuff_base_xp_spin.suffix = " XP"
	section.add_child(debuff_container)

	# Support Catch-up Rate
	var support_catchup_container: HBoxContainer = _create_spin_row(
		"Support Catch-up Rate:",
		"Bonus per level the supporter is behind the target",
		0.0, 0.5, 0.01
	)
	support_catch_up_rate_spin = support_catchup_container.get_child(1) as SpinBox
	section.add_child(support_catchup_container)

	detail_panel.add_child(section)

	# Add separator
	var sep: HSeparator = HSeparator.new()
	detail_panel.add_child(sep)


func _add_anti_spam_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Anti-Spam Settings"
	section_label.add_theme_font_size_override("font_size", EditorThemeUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Prevent XP farming by reducing rewards for repeated actions in the same battle."
	help_label.add_theme_color_override("font_color", EditorThemeUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", EditorThemeUtils.HELP_FONT_SIZE)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(help_label)

	# Enable Anti-Spam
	anti_spam_enabled_check = CheckBox.new()
	anti_spam_enabled_check.text = "Enable Diminishing Returns"
	anti_spam_enabled_check.tooltip_text = "Enable XP reduction for repeated actions in the same battle"
	anti_spam_enabled_check.toggled.connect(_on_anti_spam_toggled)
	section.add_child(anti_spam_enabled_check)

	# Medium Threshold
	var medium_container: HBoxContainer = _create_spin_row(
		"Medium Threshold:",
		"Number of uses before XP reduction to 60%",
		1, 20, 1
	)
	spam_threshold_medium_spin = medium_container.get_child(1) as SpinBox
	spam_threshold_medium_spin.suffix = " uses"
	section.add_child(medium_container)

	# Heavy Threshold
	var heavy_container: HBoxContainer = _create_spin_row(
		"Heavy Threshold:",
		"Number of uses before XP reduction to 30%",
		1, 20, 1
	)
	spam_threshold_heavy_spin = heavy_container.get_child(1) as SpinBox
	spam_threshold_heavy_spin.suffix = " uses"
	section.add_child(heavy_container)

	detail_panel.add_child(section)

	# Add separator
	var sep: HSeparator = HSeparator.new()
	detail_panel.add_child(sep)


func _add_leveling_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Leveling Settings"
	section_label.add_theme_font_size_override("font_size", EditorThemeUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Core leveling parameters that define character progression."
	help_label.add_theme_color_override("font_color", EditorThemeUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", EditorThemeUtils.HELP_FONT_SIZE)
	section.add_child(help_label)

	# XP Per Level
	var xp_container: HBoxContainer = _create_spin_row(
		"XP Per Level:",
		"Experience points required per level (100 = classic, lower = faster leveling)",
		1, 1000, 1
	)
	xp_per_level_spin = xp_container.get_child(1) as SpinBox
	xp_per_level_spin.suffix = " XP"
	section.add_child(xp_container)

	# Max Level
	var max_container: HBoxContainer = _create_spin_row(
		"Max Level:",
		"Maximum level characters can reach",
		1, 99, 1
	)
	max_level_spin = max_container.get_child(1) as SpinBox
	section.add_child(max_container)

	# Promotion Level
	var promo_container: HBoxContainer = _create_spin_row(
		"Promotion Level:",
		"Minimum level at which units can promote to advanced classes",
		1, 50, 1
	)
	promotion_level_spin = promo_container.get_child(1) as SpinBox
	section.add_child(promo_container)

	detail_panel.add_child(section)

	# Add separator
	var sep: HSeparator = HSeparator.new()
	detail_panel.add_child(sep)


func _add_promotion_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Promotion Settings"
	section_label.add_theme_font_size_override("font_size", EditorThemeUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Configure class promotion behavior and stat bonuses awarded on promotion."
	help_label.add_theme_color_override("font_color", EditorThemeUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", EditorThemeUtils.HELP_FONT_SIZE)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(help_label)

	# Promotion Resets Level
	promotion_resets_level_check = CheckBox.new()
	promotion_resets_level_check.text = "Reset Level on Promotion (SF2 Style)"
	promotion_resets_level_check.tooltip_text = "If checked, level resets to 1 on promotion. If unchecked, level continues."
	promotion_resets_level_check.toggled.connect(_on_checkbox_toggled)
	section.add_child(promotion_resets_level_check)

	# Consume Promotion Item
	consume_promotion_item_check = CheckBox.new()
	consume_promotion_item_check.text = "Consume Promotion Items"
	consume_promotion_item_check.tooltip_text = "Whether special promotion items are consumed on use"
	consume_promotion_item_check.toggled.connect(_on_checkbox_toggled)
	section.add_child(consume_promotion_item_check)

	# Promotion Bonuses Header
	var bonus_label: Label = Label.new()
	bonus_label.text = "Promotion Stat Bonuses:"
	bonus_label.add_theme_color_override("font_color", EditorThemeUtils.get_help_color())
	section.add_child(bonus_label)

	# HP Bonus
	var hp_container: HBoxContainer = _create_spin_row("HP:", "Flat HP bonus applied when promoting", 0, 20, 1)
	promotion_bonus_hp_spin = hp_container.get_child(1) as SpinBox
	section.add_child(hp_container)

	# MP Bonus
	var mp_container: HBoxContainer = _create_spin_row("MP:", "Flat MP bonus applied when promoting", 0, 10, 1)
	promotion_bonus_mp_spin = mp_container.get_child(1) as SpinBox
	section.add_child(mp_container)

	# Strength Bonus
	var str_container: HBoxContainer = _create_spin_row("Strength:", "Flat Strength bonus applied when promoting", 0, 5, 1)
	promotion_bonus_strength_spin = str_container.get_child(1) as SpinBox
	section.add_child(str_container)

	# Defense Bonus
	var def_container: HBoxContainer = _create_spin_row("Defense:", "Flat Defense bonus applied when promoting", 0, 5, 1)
	promotion_bonus_defense_spin = def_container.get_child(1) as SpinBox
	section.add_child(def_container)

	# Agility Bonus
	var agi_container: HBoxContainer = _create_spin_row("Agility:", "Flat Agility bonus applied when promoting", 0, 5, 1)
	promotion_bonus_agility_spin = agi_container.get_child(1) as SpinBox
	section.add_child(agi_container)

	# Intelligence Bonus
	var int_container: HBoxContainer = _create_spin_row("Intelligence:", "Flat Intelligence bonus applied when promoting", 0, 5, 1)
	promotion_bonus_intelligence_spin = int_container.get_child(1) as SpinBox
	section.add_child(int_container)

	# Luck Bonus
	var luck_container: HBoxContainer = _create_spin_row("Luck:", "Flat Luck bonus applied when promoting", 0, 5, 1)
	promotion_bonus_luck_spin = luck_container.get_child(1) as SpinBox
	section.add_child(luck_container)

	detail_panel.add_child(section)

	# Add separator
	var sep: HSeparator = HSeparator.new()
	detail_panel.add_child(sep)


func _add_adjutant_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Adjutant System"
	section_label.add_theme_font_size_override("font_size", EditorThemeUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Skeleton for future implementation. Adjutants are reserve units that gain XP while not deployed."
	help_label.add_theme_color_override("font_color", EditorThemeUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", EditorThemeUtils.HELP_FONT_SIZE)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(help_label)

	# Enable Adjutant System
	enable_adjutant_system_check = CheckBox.new()
	enable_adjutant_system_check.text = "Enable Adjutant System"
	enable_adjutant_system_check.tooltip_text = "Allow units to gain XP while not deployed"
	enable_adjutant_system_check.toggled.connect(_on_adjutant_toggled)
	section.add_child(enable_adjutant_system_check)

	# Deferred note
	var deferred_label: Label = Label.new()
	deferred_label.text = "(Feature skeleton - not fully implemented)"
	deferred_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	section.add_child(deferred_label)

	# Adjutant XP Share
	var share_container: HBoxContainer = _create_spin_row(
		"XP Share:",
		"Percentage of XP shared with adjutants (0.5 = 50%)",
		0.0, 1.0, 0.05
	)
	adjutant_xp_share_spin = share_container.get_child(1) as SpinBox
	section.add_child(share_container)

	# Max Adjutants
	var max_container: HBoxContainer = _create_spin_row(
		"Max Adjutants:",
		"Maximum number of adjutants per deployed unit",
		1, 5, 1
	)
	max_adjutants_spin = max_container.get_child(1) as SpinBox
	section.add_child(max_container)

	detail_panel.add_child(section)


# =============================================================================
# UI HELPER METHODS
# =============================================================================

## Create a standard spin box row with label
func _create_spin_row(label_text: String, tooltip: String, min_val: float, max_val: float, step: float) -> HBoxContainer:
	var container: HBoxContainer = HBoxContainer.new()

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	label.tooltip_text = tooltip
	container.add_child(label)

	var spin: SpinBox = SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = step
	spin.tooltip_text = tooltip
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(_on_value_changed)
	container.add_child(spin)

	return container


## Called when any value changes - mark dirty
func _on_value_changed(_value: float) -> void:
	_mark_dirty()


## Called when any simple checkbox is toggled - mark dirty
func _on_checkbox_toggled(_pressed: bool) -> void:
	_mark_dirty()


# =============================================================================
# VISUAL FEEDBACK CALLBACKS
# =============================================================================

func _on_formation_xp_toggled(_pressed: bool) -> void:
	_update_formation_xp_visual_feedback()
	_mark_dirty()


func _update_formation_xp_visual_feedback() -> void:
	var enabled: bool = enable_formation_xp_check.button_pressed if enable_formation_xp_check else false
	var dim_color: Color = Color(0.5, 0.5, 0.5, 0.7)
	var normal_color: Color = Color(1, 1, 1, 1)

	if formation_radius_spin:
		formation_radius_spin.modulate = normal_color if enabled else dim_color
		formation_radius_spin.editable = enabled
	if formation_multiplier_spin:
		formation_multiplier_spin.modulate = normal_color if enabled else dim_color
		formation_multiplier_spin.editable = enabled
	if formation_cap_ratio_spin:
		formation_cap_ratio_spin.modulate = normal_color if enabled else dim_color
		formation_cap_ratio_spin.editable = enabled
	if formation_catch_up_rate_spin:
		formation_catch_up_rate_spin.modulate = normal_color if enabled else dim_color
		formation_catch_up_rate_spin.editable = enabled


func _on_support_xp_toggled(_pressed: bool) -> void:
	_update_support_xp_visual_feedback()
	_mark_dirty()


func _update_support_xp_visual_feedback() -> void:
	var enabled: bool = enable_enhanced_support_xp_check.button_pressed if enable_enhanced_support_xp_check else false
	var dim_color: Color = Color(0.5, 0.5, 0.5, 0.7)
	var normal_color: Color = Color(1, 1, 1, 1)

	if heal_base_xp_spin:
		heal_base_xp_spin.modulate = normal_color if enabled else dim_color
		heal_base_xp_spin.editable = enabled
	if heal_ratio_multiplier_spin:
		heal_ratio_multiplier_spin.modulate = normal_color if enabled else dim_color
		heal_ratio_multiplier_spin.editable = enabled
	if buff_base_xp_spin:
		buff_base_xp_spin.modulate = normal_color if enabled else dim_color
		buff_base_xp_spin.editable = enabled
	if debuff_base_xp_spin:
		debuff_base_xp_spin.modulate = normal_color if enabled else dim_color
		debuff_base_xp_spin.editable = enabled
	if support_catch_up_rate_spin:
		support_catch_up_rate_spin.modulate = normal_color if enabled else dim_color
		support_catch_up_rate_spin.editable = enabled


func _on_anti_spam_toggled(_pressed: bool) -> void:
	_update_anti_spam_visual_feedback()
	_mark_dirty()


func _update_anti_spam_visual_feedback() -> void:
	var enabled: bool = anti_spam_enabled_check.button_pressed if anti_spam_enabled_check else false
	var dim_color: Color = Color(0.5, 0.5, 0.5, 0.7)
	var normal_color: Color = Color(1, 1, 1, 1)

	if spam_threshold_medium_spin:
		spam_threshold_medium_spin.modulate = normal_color if enabled else dim_color
		spam_threshold_medium_spin.editable = enabled
	if spam_threshold_heavy_spin:
		spam_threshold_heavy_spin.modulate = normal_color if enabled else dim_color
		spam_threshold_heavy_spin.editable = enabled


func _on_adjutant_toggled(_pressed: bool) -> void:
	_update_adjutant_visual_feedback()
	_mark_dirty()


func _update_adjutant_visual_feedback() -> void:
	var enabled: bool = enable_adjutant_system_check.button_pressed if enable_adjutant_system_check else false
	var dim_color: Color = Color(0.5, 0.5, 0.5, 0.7)
	var normal_color: Color = Color(1, 1, 1, 1)

	if adjutant_xp_share_spin:
		adjutant_xp_share_spin.modulate = normal_color if enabled else dim_color
		adjutant_xp_share_spin.editable = enabled
	if max_adjutants_spin:
		max_adjutants_spin.modulate = normal_color if enabled else dim_color
		max_adjutants_spin.editable = enabled
