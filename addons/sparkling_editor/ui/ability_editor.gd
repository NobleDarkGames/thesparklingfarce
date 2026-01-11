@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Ability Editor UI
## Allows browsing and editing AbilityData resources

var name_edit: LineEdit
var ability_id_edit: LineEdit
var ability_id_lock_btn: Button
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
var effect_chance_spin: SpinBox

# Track selected status effects
var _selected_effects: Array[String] = []

# Track if ID should auto-generate from name
var _id_is_locked: bool = false

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
	ability_id_edit.text = ability.ability_id

	# Determine if ID is locked (custom ID different from auto-generated)
	var expected_auto_id: String = SparklingEditorUtils.generate_id_from_name(ability.ability_name)
	_id_is_locked = (ability.ability_id != expected_auto_id) and not ability.ability_id.is_empty()
	_update_lock_button()

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
	ability.ability_id = ability_id_edit.text.strip_edges()
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
	ability.potency = int(potency_spin.value)
	ability.accuracy = int(accuracy_spin.value)

	# Effects - use selected effects array directly
	ability.status_effects = _selected_effects.duplicate()
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
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.add_section("Basic Information")

	name_edit = form.add_text_field("Ability Name:", "",
		"Display name shown in battle menus. E.g., Blaze, Heal, Bolt.")
	name_edit.text_changed.connect(_on_name_changed)

	# Ability ID row with lock button
	var id_container: HBoxContainer = HBoxContainer.new()
	id_container.add_theme_constant_override("separation", 4)

	ability_id_edit = LineEdit.new()
	ability_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ability_id_edit.placeholder_text = "(auto-generated from name)"
	ability_id_edit.tooltip_text = "Unique ID for referencing this ability in scripts. Auto-generates from name."
	ability_id_edit.text_changed.connect(_on_id_manually_changed)
	id_container.add_child(ability_id_edit)

	ability_id_lock_btn = Button.new()
	ability_id_lock_btn.text = "Lock"
	ability_id_lock_btn.tooltip_text = "Click to lock ID and prevent auto-generation"
	ability_id_lock_btn.custom_minimum_size.x = 60
	ability_id_lock_btn.pressed.connect(_on_id_lock_toggled)
	id_container.add_child(ability_id_lock_btn)

	form.add_labeled_control("Ability ID:", id_container,
		"Unique ID for referencing this ability. Auto-generates from name. Click lock to set custom ID.")

	description_edit = form.add_text_area("Description:", 80,
		"Tooltip text shown when hovering over ability in menus. Describe what it does.")


func _add_type_targeting_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.add_section("Type & Targeting")

	# Ability Type - custom dropdown with specific IDs
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
	form.add_labeled_control("Ability Type:", ability_type_option,
		"Category for AI and UI. Attack = damage. Heal = restore HP. Support = buffs. Debuff = weaken enemies.")

	# Target Type - custom dropdown with specific IDs
	target_type_option = OptionButton.new()
	target_type_option.tooltip_text = "Who can be targeted. Single = one target. All = entire side. Area = splash around a point."
	target_type_option.add_item("Single Enemy", AbilityData.TargetType.SINGLE_ENEMY)
	target_type_option.add_item("Single Ally", AbilityData.TargetType.SINGLE_ALLY)
	target_type_option.add_item("Self", AbilityData.TargetType.SELF)
	target_type_option.add_item("All Enemies", AbilityData.TargetType.ALL_ENEMIES)
	target_type_option.add_item("All Allies", AbilityData.TargetType.ALL_ALLIES)
	target_type_option.add_item("Area", AbilityData.TargetType.AREA)
	form.add_labeled_control("Target Type:", target_type_option,
		"Who can be targeted. Single = one target. All = entire side. Area = splash around a point.")


func _add_range_area_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.add_section("Range & Area of Effect")

	min_range_spin = form.add_number_field("Min Range:", 0, 20, 1,
		"Closest tile this ability can target. 0 = self only, 1 = adjacent, 2+ = ranged.")

	max_range_spin = form.add_number_field("Max Range:", 0, 20, 1,
		"Farthest tile this ability can target. Typical: 1-2 melee skills, 3-5 ranged spells.")

	area_of_effect_spin = form.add_number_field("Area of Effect:", 0, 10, 0,
		"Radius around target point. 0 = single target. 1 = 3x3 area. 2 = 5x5 area.")


func _add_cost_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.add_section("Cost")

	mp_cost_spin = form.add_number_field("MP Cost:", 0, 999, 0,
		"Magic points consumed when used. Typical: 2-5 early spells, 10-20 powerful, 30+ ultimate.")

	hp_cost_spin = form.add_number_field("HP Cost:", 0, 999, 0,
		"HP sacrificed to use ability. For dark magic or desperation attacks. Usually 0.")


func _add_potency_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.add_section("Potency")

	potency_spin = form.add_number_field("Potency:", 0, 999, 10,
		"Base effect strength. For damage/healing, multiplied by caster stats. Typical: 10-30 basic, 50+ powerful.")

	accuracy_spin = form.add_number_field("Accuracy (%):", 0, 100, 100,
		"Base hit chance percentage. 100% = always hits (most spells). 80-90% = can miss (debuffs).")


func _add_effects_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.add_section("Status Effects")

	# Status Effects picker - custom control with MenuButton + Label
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

	form.add_labeled_control("Effects:", status_effects_container,
		"Choose status effects to apply when this ability hits.")

	# Populate the dropdown lazily when opened (registry may not be ready on startup)
	status_effects_button.get_popup().about_to_popup.connect(_populate_status_effects_menu)

	effect_chance_spin = form.add_number_field("Effect Chance (%):", 0, 100, 100,
		"Probability that status effect applies on hit. 100% = guaranteed. 30-50% = unreliable debuff.")


func _add_animation_audio_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.add_section("Animation & Audio")

	animation_edit = form.add_text_field("Animation Name:", "e.g., slash, heal_sparkle",
		"[NOT YET IMPLEMENTED] Animation key to play when ability is used. Field exists for future spell animation system.")

	form.add_help_text("[STUB] Animation/audio fields exist but are not yet processed by the spell system")


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


# =============================================================================
# ID AUTO-GENERATION HANDLERS
# =============================================================================

## Called when the ability name changes - auto-generates ID if not locked
func _on_name_changed(new_name: String) -> void:
	if not _id_is_locked:
		ability_id_edit.text = SparklingEditorUtils.generate_id_from_name(new_name)
	_mark_dirty()


## Called when the ID field is manually edited
func _on_id_manually_changed(_text: String) -> void:
	# If user is editing the ID field directly, lock it
	if not _id_is_locked and ability_id_edit.has_focus():
		_id_is_locked = true
		_update_lock_button()
	_mark_dirty()


## Called when the lock/unlock button is pressed
func _on_id_lock_toggled() -> void:
	_id_is_locked = not _id_is_locked
	_update_lock_button()
	# If unlocking, regenerate the ID from current name
	if not _id_is_locked:
		ability_id_edit.text = SparklingEditorUtils.generate_id_from_name(name_edit.text)
	_mark_dirty()


## Update the lock button text and tooltip based on lock state
func _update_lock_button() -> void:
	ability_id_lock_btn.text = "Unlock" if _id_is_locked else "Lock"
	ability_id_lock_btn.tooltip_text = "ID is locked. Click to unlock and auto-generate." if _id_is_locked else "Click to lock ID and prevent auto-generation"
