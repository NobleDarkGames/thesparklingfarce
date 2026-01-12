@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Class Editor UI
## Allows browsing and editing ClassData resources

var name_edit: LineEdit
var movement_type_option: OptionButton
var movement_range_spin: SpinBox
var promotion_level_spin: SpinBox
var promotion_resets_level_check: CheckBox
var consume_promotion_item_check: CheckBox

# Combat rates UI
var counter_rate_spin: SpinBox
var double_attack_rate_spin: SpinBox
var crit_rate_bonus_spin: SpinBox

# Promotion paths UI
var promotion_paths_container: VBoxContainer
var add_promotion_path_button: Button

# Growth rate editors
var hp_growth_slider: HSlider
var mp_growth_slider: HSlider
var str_growth_slider: HSlider
var def_growth_slider: HSlider
var agi_growth_slider: HSlider
var int_growth_slider: HSlider
var luk_growth_slider: HSlider

var weapon_types_container: VBoxContainer

# Learnable abilities UI
var learnable_abilities_container: VBoxContainer
var add_ability_button: Button


func _ready() -> void:
	resource_type_name = "Class"
	resource_type_id = "class"
	# resource_directory is set dynamically via base class using ModLoader.get_active_mod()

	# Declare dependencies BEFORE calling super._ready() so base class sets up tracking
	# - "class" for promotion class dropdown (when another class is created/modified)
	# - "ability" is handled by ResourcePicker auto-refresh
	resource_dependencies = ["class"]

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

	# Combat rates section
	_add_combat_rates_section()

	# Promotion section
	_add_promotion_section()

	# Learnable abilities section
	_add_learnable_abilities_section()

	# Add the button container at the end
	_add_button_container_to_detail_panel()


## Override: Load class data from resource into UI
func _load_resource_data() -> void:
	var class_data: ClassData = current_resource as ClassData
	if not class_data:
		return

	name_edit.text = class_data.display_name
	movement_type_option.selected = class_data.movement_type
	movement_range_spin.value = class_data.movement_range
	promotion_level_spin.value = class_data.promotion_level
	promotion_resets_level_check.button_pressed = class_data.promotion_resets_level
	consume_promotion_item_check.button_pressed = class_data.consume_promotion_item

	# Set combat rates
	counter_rate_spin.value = class_data.counter_rate
	double_attack_rate_spin.value = class_data.double_attack_rate
	crit_rate_bonus_spin.value = class_data.crit_rate_bonus

	# Set growth rates
	hp_growth_slider.value = class_data.hp_growth
	mp_growth_slider.value = class_data.mp_growth
	str_growth_slider.value = class_data.strength_growth
	def_growth_slider.value = class_data.defense_growth
	agi_growth_slider.value = class_data.agility_growth
	int_growth_slider.value = class_data.intelligence_growth
	luk_growth_slider.value = class_data.luck_growth

	# Set weapon types
	for child in weapon_types_container.get_children():
		if child is CheckBox:
			var type_name: String = child.get_meta("equipment_type")
			child.button_pressed = type_name in class_data.equippable_weapon_types

	# Load promotion paths
	_load_promotion_paths(class_data)

	# Load learnable abilities from class_abilities + ability_unlock_levels (new system)
	_load_learnable_abilities_new(class_data)


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
	class_data.promotion_resets_level = promotion_resets_level_check.button_pressed
	class_data.consume_promotion_item = consume_promotion_item_check.button_pressed

	# Update combat rates
	class_data.counter_rate = int(counter_rate_spin.value)
	class_data.double_attack_rate = int(double_attack_rate_spin.value)
	class_data.crit_rate_bonus = int(crit_rate_bonus_spin.value)

	# Update growth rates
	class_data.hp_growth = int(hp_growth_slider.value)
	class_data.mp_growth = int(mp_growth_slider.value)
	class_data.strength_growth = int(str_growth_slider.value)
	class_data.defense_growth = int(def_growth_slider.value)
	class_data.agility_growth = int(agi_growth_slider.value)
	class_data.intelligence_growth = int(int_growth_slider.value)
	class_data.luck_growth = int(luk_growth_slider.value)

	# Update weapon types - create new array to avoid read-only issues
	var new_weapon_types: Array[String] = []
	for child in weapon_types_container.get_children():
		if child is CheckBox and child.button_pressed:
			var type_name: String = child.get_meta("equipment_type")
			new_weapon_types.append(type_name)
	class_data.equippable_weapon_types = new_weapon_types

	# Update promotion paths
	_save_promotion_paths(class_data)

	# Update class_abilities and ability_unlock_levels (new system)
	_save_learnable_abilities_new(class_data)


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
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel, 150)
	form.add_section("Basic Information")
	name_edit = form.add_text_field("Class Name:", "", "Display name shown for this class. E.g., Warrior, Mage, Knight.")


func _add_movement_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel, 150)
	form.add_section("Movement")

	# Movement Type - custom dropdown with enum IDs
	movement_type_option = OptionButton.new()
	movement_type_option.add_item("Walking", ClassData.MovementType.WALKING)
	movement_type_option.add_item("Flying", ClassData.MovementType.FLYING)
	movement_type_option.add_item("Floating", ClassData.MovementType.FLOATING)
	movement_type_option.add_item("Swimming", ClassData.MovementType.SWIMMING)
	movement_type_option.add_item("Custom", ClassData.MovementType.CUSTOM)
	form.add_labeled_control("Movement Type:", movement_type_option, "How terrain affects movement. Walking = blocked by water/cliffs. Flying = ignores all terrain. Floating = ignores ground hazards.")

	movement_range_spin = form.add_number_field("Movement Range:", 1, 20, 4, "Tiles this class can move per turn. Typical: 4-5 infantry, 6-7 cavalry, 5-6 flying.")


func _add_equipment_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel, 150)
	form.add_section("Equipment Restrictions")
	form.add_help_text("Which weapon types this class can equip. Check all that apply.")

	# Dynamic checkbox list from registry
	weapon_types_container = VBoxContainer.new()
	var weapon_types: Array[String] = _get_weapon_types_from_registry()
	_add_equipment_type_checkboxes(weapon_types_container, weapon_types)
	form.container.add_child(weapon_types_container)


func _add_combat_rates_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel, 150)
	form.add_section("Combat Rates (%)")
	form.add_help_text("SF2-authentic combat rates. 25 = 1/4 (25%), 12 = 1/8 (~12.5%), 6 = 1/16 (~6%), 3 = 1/32 (~3%)")

	counter_rate_spin = form.add_number_field("Counter Rate:", 0, 50, 12, "Chance to counterattack when attacked. SF2 classes: 3, 6, 12, or 25.")
	double_attack_rate_spin = form.add_number_field("Double Attack Rate:", 0, 50, 6, "Chance for second attack in same turn. SF2 classes: 3, 6, 12, or 25.")
	crit_rate_bonus_spin = form.add_number_field("Crit Rate Bonus:", 0, 50, 0, "Bonus to critical hit chance. Added to base calculation.")


## Get weapon types from ModLoader's equipment registry (with fallback)
func _get_weapon_types_from_registry() -> Array[String]:
	if ModLoader and ModLoader.equipment_registry:
		return ModLoader.equipment_registry.get_weapon_types()
	# Fallback to defaults if registry not available
	return ["sword", "axe", "lance", "bow", "staff", "tome"]


func _add_equipment_type_checkboxes(parent: VBoxContainer, types: Array[String]) -> void:
	for type_name in types:
		var checkbox: CheckBox = CheckBox.new()
		checkbox.text = type_name.capitalize()
		checkbox.set_meta("equipment_type", type_name)
		parent.add_child(checkbox)


func _add_promotion_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel, 150)
	form.add_section("Class Promotion")

	promotion_level_spin = form.add_number_field("Promotion Level:", 1, 99, 10, "Minimum level required to promote. Typical: 10-20. Set to 99 if class cannot promote.")

	# Standalone checkboxes for promotion settings
	promotion_resets_level_check = form.add_standalone_checkbox("Reset Level on Promotion (SF2 Style)", false, "If checked, level resets to 1 on promotion. If unchecked, level continues from current value.")
	consume_promotion_item_check = form.add_standalone_checkbox("Consume Promotion Items", false, "Whether promotion items are consumed when used. Applies to all paths that require items.")

	# Promotion Paths subsection - keep manual construction for dynamic row-based UI
	form.add_section_label("Promotion Paths:")
	form.add_help_text("Each path leads to a different promoted class. Optionally require an item.")

	# Scrollable container for promotion paths
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.y = 100
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	promotion_paths_container = VBoxContainer.new()
	promotion_paths_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(promotion_paths_container)
	form.container.add_child(scroll)

	# Add Path button
	add_promotion_path_button = Button.new()
	add_promotion_path_button.text = "Add Promotion Path"
	add_promotion_path_button.tooltip_text = "Add a new promotion path. Each path can lead to a different class."
	add_promotion_path_button.pressed.connect(_on_add_promotion_path)
	form.container.add_child(add_promotion_path_button)


## Load promotion paths from ClassData into UI
func _load_promotion_paths(class_data: ClassData) -> void:
	# Clear existing rows
	for child in promotion_paths_container.get_children():
		child.queue_free()

	# Add a row for each promotion path
	for path: PromotionPath in class_data.get_promotion_path_resources():
		_add_promotion_path_row(path.target_class, path.required_item, path.path_name)


## Save promotion paths from UI to ClassData
func _save_promotion_paths(class_data: ClassData) -> void:
	var new_paths: Array[PromotionPath] = []

	for child in promotion_paths_container.get_children():
		if child is HBoxContainer:
			var class_picker: ResourcePicker = child.get_node_or_null("ClassPicker")
			var item_picker: ResourcePicker = child.get_node_or_null("ItemPicker")
			var name_edit_node: LineEdit = child.get_node_or_null("PathNameEdit")

			if class_picker:
				var target_class: ClassData = class_picker.get_selected_resource() as ClassData
				if target_class:
					var path: PromotionPath = PromotionPath.new()
					path.target_class = target_class
					if item_picker:
						path.required_item = item_picker.get_selected_resource() as ItemData
					if name_edit_node:
						path.path_name = name_edit_node.text.strip_edges()
					new_paths.append(path)

	class_data.promotion_paths = new_paths


## Add a single promotion path row to the UI
func _add_promotion_path_row(target_class: ClassData = null, required_item: ItemData = null, path_name: String = "") -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Target class picker
	var class_label: Label = Label.new()
	class_label.text = "Class:"
	row.add_child(class_label)

	var class_picker: ResourcePicker = ResourcePicker.new()
	class_picker.name = "ClassPicker"
	class_picker.resource_type = "class"
	class_picker.allow_none = false
	class_picker.none_text = "(Select Class)"
	class_picker.custom_minimum_size.x = 180
	class_picker.tooltip_text = "The target class for this promotion path."
	row.add_child(class_picker)

	# Required item picker (optional)
	var item_label: Label = Label.new()
	item_label.text = "Requires:"
	row.add_child(item_label)

	var item_picker: ResourcePicker = ResourcePicker.new()
	item_picker.name = "ItemPicker"
	item_picker.resource_type = "item"
	item_picker.allow_none = true
	item_picker.none_text = "(No item required)"
	item_picker.custom_minimum_size.x = 150
	item_picker.tooltip_text = "Optional item required to unlock this path. Leave empty for always-available paths."
	row.add_child(item_picker)

	# Optional path name
	var name_label: Label = Label.new()
	name_label.text = "Name:"
	name_label.tooltip_text = "Optional custom name (shown in promotion UI)"
	row.add_child(name_label)

	var name_edit_field: LineEdit = LineEdit.new()
	name_edit_field.name = "PathNameEdit"
	name_edit_field.placeholder_text = "(auto)"
	name_edit_field.custom_minimum_size.x = 100
	name_edit_field.tooltip_text = "Optional custom name for this path. If empty, uses the target class name."
	name_edit_field.text = path_name
	row.add_child(name_edit_field)

	# Remove button
	var remove_btn: Button = Button.new()
	remove_btn.text = "X"
	remove_btn.tooltip_text = "Remove this promotion path"
	remove_btn.custom_minimum_size.x = 30
	remove_btn.pressed.connect(_on_remove_promotion_path.bind(row))
	row.add_child(remove_btn)

	promotion_paths_container.add_child(row)

	# Select the resources after adding to tree
	if target_class:
		class_picker.call_deferred("select_resource", target_class)
	if required_item:
		item_picker.call_deferred("select_resource", required_item)


## Called when "Add Promotion Path" button is pressed
func _on_add_promotion_path() -> void:
	_add_promotion_path_row(null, null, "")


## Called when a remove button is pressed on a promotion path row
func _on_remove_promotion_path(row: HBoxContainer) -> void:
	row.queue_free()


func _add_growth_rates_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel, 120)
	form.add_section("Growth Rates (%) - Shining Force Style")
	form.add_help_text("Growth rates determine stat increases on level up. Set per class, not per character.")

	# Use custom growth editor for slider+value display (FormBuilder doesn't have this widget)
	var section: VBoxContainer = form.container as VBoxContainer
	hp_growth_slider = _create_growth_editor("HP Growth:", section, "Chance to gain +1 HP on level up. 50% = average, 80%+ = tanky class.")
	mp_growth_slider = _create_growth_editor("MP Growth:", section, "Chance to gain +1 MP on level up. 0% for melee, 60-80% for spellcasters.")
	str_growth_slider = _create_growth_editor("STR Growth:", section, "Chance to gain +1 Strength on level up. High for fighters, low for mages.")
	def_growth_slider = _create_growth_editor("DEF Growth:", section, "Chance to gain +1 Defense on level up. High for tanks, low for glass cannons.")
	agi_growth_slider = _create_growth_editor("AGI Growth:", section, "Chance to gain +1 Agility on level up. High for scouts and assassins.")
	int_growth_slider = _create_growth_editor("INT Growth:", section, "Chance to gain +1 Intelligence on level up. High for mages and healers.")
	luk_growth_slider = _create_growth_editor("LUK Growth:", section, "Chance to gain +1 Luck on level up. Affects crits and rare drops.")


func _create_growth_editor(label_text: String, parent: VBoxContainer, tooltip: String = "") -> HSlider:
	var container: HBoxContainer = HBoxContainer.new()

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	if not tooltip.is_empty():
		label.tooltip_text = tooltip
	container.add_child(label)

	var slider: HSlider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 200
	slider.value = 80
	slider.step = 5
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not tooltip.is_empty():
		slider.tooltip_text = tooltip
	container.add_child(slider)

	var value_label: Label = Label.new()
	value_label.text = "80%"
	value_label.custom_minimum_size.x = 50
	slider.value_changed.connect(func(value: float) -> void: value_label.text = str(int(value)) + "%")
	container.add_child(value_label)

	parent.add_child(container)
	return slider


func _add_learnable_abilities_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel, 150)
	form.add_section("Learnable Abilities")
	form.add_help_text("Abilities this class learns at specific levels.")

	# Scrollable container for the ability list (dynamic row-based UI)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.y = 120
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	learnable_abilities_container = VBoxContainer.new()
	learnable_abilities_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(learnable_abilities_container)
	form.container.add_child(scroll)

	# Add Ability button
	add_ability_button = Button.new()
	add_ability_button.text = "Add Ability"
	add_ability_button.tooltip_text = "Add a new ability that characters of this class will learn."
	add_ability_button.pressed.connect(_on_add_learnable_ability)
	form.container.add_child(add_ability_button)


## Load learnable abilities from NEW system (class_abilities + ability_unlock_levels)
## The new system stores abilities in class_abilities array, with unlock levels in ability_unlock_levels dict
func _load_learnable_abilities_new(class_data: ClassData) -> void:
	# Clear existing rows
	for child in learnable_abilities_container.get_children():
		child.queue_free()

	# Build level -> ability mapping from the new system
	var abilities_by_level: Dictionary = {}  # level -> AbilityData

	for ability: AbilityData in class_data.class_abilities:
		if ability == null:
			continue

		# Get unlock level from ability_unlock_levels dict (keyed by ability_id)
		var unlock_level: int = 1  # Default to level 1
		if ability.ability_id in class_data.ability_unlock_levels:
			unlock_level = class_data.ability_unlock_levels[ability.ability_id]

		# Store by level (if multiple abilities at same level, we'll handle that)
		if unlock_level not in abilities_by_level:
			abilities_by_level[unlock_level] = ability
		else:
			# Multiple abilities at same level - add row anyway
			# (the UI will show duplicate warning)
			_add_ability_row(unlock_level, ability)
			continue

	# Sort levels for consistent display order
	var levels: Array = abilities_by_level.keys()
	levels.sort()

	for level: int in levels:
		var ability: AbilityData = abilities_by_level[level]
		_add_ability_row(level, ability)


## Save learnable abilities to NEW system (class_abilities + ability_unlock_levels)
func _save_learnable_abilities_new(class_data: ClassData) -> void:
	var new_class_abilities: Array[AbilityData] = []
	var new_unlock_levels: Dictionary = {}  # ability_id -> level

	for child in learnable_abilities_container.get_children():
		if child is HBoxContainer:
			var level_spin: SpinBox = child.get_node_or_null("LevelSpin")
			var picker: ResourcePicker = child.get_node_or_null("AbilityPicker")

			if level_spin and picker:
				var level: int = int(level_spin.value)
				var ability: AbilityData = picker.get_selected_resource() as AbilityData

				if ability:
					# Add to class_abilities if not already present
					var already_added: bool = false
					for existing: AbilityData in new_class_abilities:
						if existing and existing.ability_id == ability.ability_id:
							already_added = true
							break

					if not already_added:
						new_class_abilities.append(ability)

					# Set unlock level (use ability_id as key)
					new_unlock_levels[ability.ability_id] = level

	class_data.class_abilities = new_class_abilities
	class_data.ability_unlock_levels = new_unlock_levels


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
	level_spin.tooltip_text = "Level at which this ability is learned. Characters gain access when they reach this level."
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
	picker.tooltip_text = "Select the spell or skill this class learns at the specified level."
	row.add_child(picker)

	# Duplicate warning icon/label (hidden by default)
	var warning_label: Label = Label.new()
	warning_label.name = "DuplicateWarning"
	warning_label.text = "!"
	warning_label.tooltip_text = "Another ability is already set for this level"
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	warning_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
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
	# Single pass: collect levels and warning labels together
	var level_counts: Dictionary = {}  # level -> count
	var row_data: Array = []  # Array of {level: int, warning: Label}

	for child in learnable_abilities_container.get_children():
		if not is_instance_valid(child) or not child is HBoxContainer:
			continue
		var level_spin: SpinBox = child.get_node_or_null("LevelSpin")
		var warning_label: Label = child.get_node_or_null("DuplicateWarning")
		if not level_spin or not warning_label:
			continue

		var level: int = int(level_spin.value)
		level_counts[level] = level_counts.get(level, 0) + 1
		row_data.append({"level": level, "warning": warning_label})

	# Update warnings using collected data (no second iteration over children)
	for entry: Dictionary in row_data:
		var is_duplicate: bool = level_counts.get(entry["level"], 0) > 1
		entry["warning"].visible = is_duplicate
