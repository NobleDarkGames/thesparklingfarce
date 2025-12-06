@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Character Editor UI
## Allows browsing and editing CharacterData resources

var name_edit: LineEdit
var class_picker: ResourcePicker  # Use ResourcePicker for cross-mod class selection
var level_spin: SpinBox
var bio_edit: TextEdit

# Battle configuration fields
var category_option: OptionButton
var is_unique_check: CheckBox
var is_hero_check: CheckBox
var default_ai_option: OptionButton

# Stat editors
var hp_spin: SpinBox
var mp_spin: SpinBox
var str_spin: SpinBox
var def_spin: SpinBox
var agi_spin: SpinBox
var int_spin: SpinBox
var luk_spin: SpinBox

# Equipment section (collapsible)
var equipment_section: CollapseSection
var equipment_pickers: Dictionary = {}  # {slot_id: ResourcePicker}
var equipment_warning_labels: Dictionary = {}  # {slot_id: Label}

var available_ai_brains: Array[AIBrain] = []
var current_filter: String = "all"  # "all", "player", "enemy", "boss", "neutral"

# Filter buttons (will be created by _setup_filter_buttons)
var filter_buttons: Dictionary = {}  # {category: Button}


func _ready() -> void:
	resource_type_name = "Character"
	resource_type_id = "character"
	# Enable undo/redo for save operations (Ctrl+Z support)
	enable_undo_redo = true
	# resource_directory is set dynamically via base class using ModLoader.get_active_mod()
	super._ready()
	_setup_filter_buttons()

	# Note: class_picker uses ResourcePicker which auto-refreshes on mod reload via EditorEventBus


## Override: Refresh the editor when mod changes or new resources are created
func _refresh_list() -> void:
	# Call parent to load all resources
	super._refresh_list()

	# Apply current filter
	_apply_filter()

	# Note: class_picker auto-refreshes via EditorEventBus mods_reloaded signal


## Override: Create the character-specific detail form
func _create_detail_form() -> void:
	# Basic info section
	_add_basic_info_section()

	# Battle configuration section
	_add_battle_configuration_section()

	# Stats section
	_add_stats_section()

	# Equipment section (starting equipment for this character)
	_add_equipment_section()

	# Add the button container at the end
	detail_panel.add_child(button_container)


## Override: Load character data from resource into UI
func _load_resource_data() -> void:
	var character: CharacterData = current_resource as CharacterData
	if not character:
		return

	name_edit.text = character.character_name
	level_spin.value = character.starting_level
	bio_edit.text = character.biography

	# Set battle configuration - find the matching category index
	var category_index: int = -1
	for i in range(category_option.item_count):
		if category_option.get_item_text(i) == character.unit_category:
			category_index = i
			break

	if category_index >= 0:
		category_option.select(category_index)
	else:
		category_option.select(0)  # Default to "player"

	is_unique_check.button_pressed = character.is_unique
	is_hero_check.button_pressed = character.is_hero

	# Set default AI brain
	if character.default_ai_brain:
		for i in range(available_ai_brains.size()):
			if available_ai_brains[i] == character.default_ai_brain:
				default_ai_option.select(i + 1)
				break
	else:
		default_ai_option.select(0)  # (None)

	# Set class using ResourcePicker
	if character.character_class:
		class_picker.select_resource(character.character_class)
	else:
		class_picker.select_none()

	# Set stats
	hp_spin.value = character.base_hp
	mp_spin.value = character.base_mp
	str_spin.value = character.base_strength
	def_spin.value = character.base_defense
	agi_spin.value = character.base_agility
	int_spin.value = character.base_intelligence
	luk_spin.value = character.base_luck

	# Load starting equipment into pickers
	_load_equipment_from_character(character)


## Override: Save UI data to resource
func _save_resource_data() -> void:
	var character: CharacterData = current_resource as CharacterData
	if not character:
		return

	# Update character data from UI
	character.character_name = name_edit.text
	character.starting_level = int(level_spin.value)
	character.biography = bio_edit.text

	# Update battle configuration
	var selected_category_idx: int = category_option.selected
	if selected_category_idx >= 0:
		character.unit_category = category_option.get_item_text(selected_category_idx)

	character.is_unique = is_unique_check.button_pressed
	character.is_hero = is_hero_check.button_pressed

	# Update default AI brain
	var ai_index: int = default_ai_option.selected - 1
	if ai_index >= 0 and ai_index < available_ai_brains.size():
		character.default_ai_brain = available_ai_brains[ai_index]
	else:
		character.default_ai_brain = null

	# Update class using ResourcePicker
	character.character_class = class_picker.get_selected_resource() as ClassData

	# Update stats
	character.base_hp = int(hp_spin.value)
	character.base_mp = int(mp_spin.value)
	character.base_strength = int(str_spin.value)
	character.base_defense = int(def_spin.value)
	character.base_agility = int(agi_spin.value)
	character.base_intelligence = int(int_spin.value)
	character.base_luck = int(luk_spin.value)

	# Update starting equipment from pickers
	_save_equipment_to_character(character)


## Override: Validate resource before saving
func _validate_resource() -> Dictionary:
	var character: CharacterData = current_resource as CharacterData
	if not character:
		return {valid = false, errors = ["Invalid resource type"]}

	var errors: Array[String] = []

	if character.character_name.strip_edges().is_empty():
		errors.append("Character name cannot be empty")

	if character.starting_level < 1 or character.starting_level > 99:
		errors.append("Starting level must be between 1 and 99")

	return {valid = errors.is_empty(), errors = errors}


## Override: Check for references before deletion
func _check_resource_references(resource_to_check: Resource) -> Array[String]:
	var references: Array[String] = []

	# TODO: In Phase 2+, check battles and dialogues for references to this character
	# For now, allow deletion

	return references


## Override: Create a new character with defaults
func _create_new_resource() -> Resource:
	var new_character: CharacterData = CharacterData.new()
	new_character.character_name = "New Character"
	new_character.starting_level = 1
	new_character.base_hp = 20
	new_character.base_mp = 10
	new_character.base_strength = 5
	new_character.base_defense = 5
	new_character.base_agility = 5
	new_character.base_intelligence = 5
	new_character.base_luck = 5

	return new_character


## Override: Get the display name from a character resource
func _get_resource_display_name(resource: Resource) -> String:
	var character: CharacterData = resource as CharacterData
	if character:
		return character.character_name
	return "Unnamed Character"


func _add_basic_info_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Basic Information"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Name
	var name_container: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = "Name:"
	name_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	name_container.add_child(name_label)

	name_edit = LineEdit.new()
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_container.add_child(name_edit)
	section.add_child(name_container)

	# Class - use ResourcePicker for cross-mod class selection
	class_picker = ResourcePicker.new()
	class_picker.resource_type = "class"
	class_picker.label_text = "Class:"
	class_picker.label_min_width = 120
	class_picker.allow_none = true
	section.add_child(class_picker)

	# Starting Level
	var level_container: HBoxContainer = HBoxContainer.new()
	var level_label: Label = Label.new()
	level_label.text = "Starting Level:"
	level_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	level_container.add_child(level_label)

	level_spin = SpinBox.new()
	level_spin.min_value = 1
	level_spin.max_value = 99
	level_spin.value = 1
	level_container.add_child(level_spin)
	section.add_child(level_container)

	# Biography
	var bio_label: Label = Label.new()
	bio_label.text = "Biography:"
	section.add_child(bio_label)

	bio_edit = TextEdit.new()
	bio_edit.custom_minimum_size.y = 120
	section.add_child(bio_edit)

	detail_panel.add_child(section)


func _add_battle_configuration_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Battle Configuration"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Unit Category
	var category_container: HBoxContainer = HBoxContainer.new()
	var category_label: Label = Label.new()
	category_label.text = "Unit Category:"
	category_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	category_container.add_child(category_label)

	category_option = OptionButton.new()
	# Populate from registry
	var categories: Array[String] = _get_unit_categories_from_registry()
	for i in range(categories.size()):
		category_option.add_item(categories[i], i)
	category_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_container.add_child(category_option)
	section.add_child(category_container)

	# Is Unique
	var unique_container: HBoxContainer = HBoxContainer.new()
	var unique_label: Label = Label.new()
	unique_label.text = "Is Unique:"
	unique_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	unique_container.add_child(unique_label)

	is_unique_check = CheckBox.new()
	is_unique_check.button_pressed = true
	is_unique_check.text = "This is a unique character (not a reusable template)"
	unique_container.add_child(is_unique_check)
	section.add_child(unique_container)

	# Is Hero
	var hero_container: HBoxContainer = HBoxContainer.new()
	var hero_label: Label = Label.new()
	hero_label.text = "Is Hero:"
	hero_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	hero_container.add_child(hero_label)

	is_hero_check = CheckBox.new()
	is_hero_check.button_pressed = false
	is_hero_check.text = "This is the primary Hero/protagonist (only one per party)"
	hero_container.add_child(is_hero_check)
	section.add_child(hero_container)

	# Default AI Brain
	var ai_container: HBoxContainer = HBoxContainer.new()
	var ai_label: Label = Label.new()
	ai_label.text = "Default AI:"
	ai_label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	ai_container.add_child(ai_label)

	default_ai_option = OptionButton.new()
	default_ai_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ai_container.add_child(default_ai_option)
	section.add_child(ai_container)

	var ai_help: Label = Label.new()
	ai_help.text = "AI used when this character is an enemy (can override in Battle Editor)"
	ai_help.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	ai_help.add_theme_font_size_override("font_size", 16)
	section.add_child(ai_help)

	detail_panel.add_child(section)

	# Load available AI brains after creating the dropdown
	_load_available_ai_brains()


func _add_stats_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Base Stats"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	hp_spin = _create_stat_editor("HP:", section)
	mp_spin = _create_stat_editor("MP:", section)
	str_spin = _create_stat_editor("Strength:", section)
	def_spin = _create_stat_editor("Defense:", section)
	agi_spin = _create_stat_editor("Agility:", section)
	int_spin = _create_stat_editor("Intelligence:", section)
	luk_spin = _create_stat_editor("Luck:", section)

	detail_panel.add_child(section)


func _create_stat_editor(label_text: String, parent: VBoxContainer) -> SpinBox:
	var container: HBoxContainer = HBoxContainer.new()

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = EditorThemeUtils.DEFAULT_LABEL_WIDTH
	container.add_child(label)

	var spin: SpinBox = SpinBox.new()
	spin.min_value = 1
	spin.max_value = 999
	spin.value = 10
	container.add_child(spin)

	parent.add_child(container)
	return spin


func _load_available_ai_brains() -> void:
	available_ai_brains.clear()
	default_ai_option.clear()
	default_ai_option.add_item("(None)", 0)

	# Use the AI Brain Registry for discovery (supports mod.json declarations + auto-discovery)
	if ModLoader and ModLoader.ai_brain_registry:
		var brains: Array[Dictionary] = ModLoader.ai_brain_registry.get_all_brains()
		for brain_info: Dictionary in brains:
			var instance: Resource = ModLoader.ai_brain_registry.get_brain_instance(brain_info.get("id", ""))
			if instance:
				var ai_brain: AIBrain = instance as AIBrain
				if ai_brain:
					available_ai_brains.append(ai_brain)
					var display_name: String = brain_info.get("display_name", "Unknown")
					default_ai_option.add_item(display_name, available_ai_brains.size())


func _setup_filter_buttons() -> void:
	# Find the resource_list from base class to insert buttons before it
	if not resource_list:
		return

	var list_parent: VBoxContainer = resource_list.get_parent() as VBoxContainer
	if not list_parent:
		return

	var list_index: int = resource_list.get_index()

	# Create filter button container
	var filter_container: HBoxContainer = HBoxContainer.new()
	filter_container.add_theme_constant_override("separation", 4)

	# Create filter buttons - get categories from registry
	var unit_categories: Array[String] = _get_unit_categories_from_registry()
	var categories: Array[String] = ["all"]
	categories.append_array(unit_categories)

	for category in categories:
		var btn: Button = Button.new()
		# Generate button text: "all" -> "All", "player" -> "Players", etc.
		if category == "all":
			btn.text = "All"
		else:
			btn.text = category.capitalize() + "s"  # Pluralize for filter buttons
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_filter_changed.bind(category))
		filter_container.add_child(btn)
		filter_buttons[category] = btn

	# Set "all" as default selected
	filter_buttons["all"].button_pressed = true

	# Insert before the resource list
	list_parent.add_child(filter_container)
	list_parent.move_child(filter_container, list_index)


func _on_filter_changed(category: String) -> void:
	# Deselect all other buttons
	for btn_category in filter_buttons.keys():
		filter_buttons[btn_category].button_pressed = (btn_category == category)

	# Update current filter
	current_filter = category

	# Apply filter to the list
	_apply_filter()


func _apply_filter() -> void:
	# Store currently selected path to restore selection after filter
	var selected_path: String = ""
	var selected_items: PackedInt32Array = resource_list.get_selected_items()
	if selected_items.size() > 0:
		selected_path = resource_list.get_item_metadata(selected_items[0])

	# Clear and rebuild list with only matching items
	resource_list.clear()

	for i in range(available_resources.size()):
		var character: CharacterData = available_resources[i] as CharacterData
		if not character:
			continue

		# Check if matches current filter
		var matches_filter: bool = (current_filter == "all") or (character.unit_category == current_filter)

		if matches_filter:
			resource_list.add_item(_get_resource_display_name(character))
			# Store the original resource index so we can find the right resource
			var original_path: String = character.resource_path
			resource_list.set_item_metadata(resource_list.item_count - 1, original_path)

			# Restore selection if this was the previously selected item
			if original_path == selected_path:
				resource_list.select(resource_list.item_count - 1)


## Get unit categories from ModLoader's unit category registry (with fallback)
func _get_unit_categories_from_registry() -> Array[String]:
	if ModLoader and ModLoader.unit_category_registry:
		return ModLoader.unit_category_registry.get_categories()
	# Fallback to defaults if registry not available
	return ["player", "enemy", "boss", "neutral"]


## Add the starting equipment section with pickers for each slot (collapsible)
func _add_equipment_section() -> void:
	equipment_section = CollapseSection.new()
	equipment_section.title = "Starting Equipment"
	equipment_section.start_collapsed = false

	var help_label: Label = Label.new()
	help_label.text = "Equipment the character starts with when recruited"
	help_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	help_label.add_theme_font_size_override("font_size", 14)
	equipment_section.add_content_child(help_label)

	# Get available equipment slots from registry
	var slots: Array[Dictionary] = _get_equipment_slots()

	equipment_pickers.clear()
	equipment_warning_labels.clear()

	for slot: Dictionary in slots:
		var slot_id: String = slot.get("id", "")
		var display_name: String = slot.get("display_name", slot_id.capitalize())
		var accepts_types: Array = slot.get("accepts_types", [])

		# Create a container for each slot
		var slot_container: VBoxContainer = VBoxContainer.new()

		# Create the picker
		var picker: ResourcePicker = ResourcePicker.new()
		picker.resource_type = "item"
		picker.label_text = display_name + ":"
		picker.label_min_width = 120
		picker.allow_none = true
		picker.none_text = "(Empty)"

		# Filter items to only show compatible types for this slot
		# Note: Use helper function to properly capture accepts_types by value
		picker.filter_function = _create_equipment_filter(accepts_types)

		picker.resource_selected.connect(_on_equipment_selected.bind(slot_id))
		slot_container.add_child(picker)
		equipment_pickers[slot_id] = picker

		# Add warning label (hidden by default)
		var warning: Label = Label.new()
		warning.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		warning.add_theme_font_size_override("font_size", 12)
		warning.visible = false
		slot_container.add_child(warning)
		equipment_warning_labels[slot_id] = warning

		equipment_section.add_content_child(slot_container)

	detail_panel.add_child(equipment_section)


## Create an equipment filter function that properly captures types by value
## This avoids the closure capture-by-reference bug in GDScript
func _create_equipment_filter(types: Array) -> Callable:
	return func(resource: Resource) -> bool:
		var item: ItemData = resource as ItemData
		if not item:
			return false
		# Check if item type is compatible with this slot using wildcard matching
		var eq_type: String = item.equipment_type.to_lower()
		# Use EquipmentTypeRegistry for wildcard matching (e.g., "weapon:*" matches "sword")
		if ModLoader and ModLoader.equipment_type_registry:
			for accept_type: Variant in types:
				if ModLoader.equipment_type_registry.matches_accept_type(eq_type, str(accept_type)):
					return true
			return false
		# Fallback: direct match only
		return eq_type in types


## Get equipment slots from registry with fallback
func _get_equipment_slots() -> Array[Dictionary]:
	if ModLoader and ModLoader.equipment_slot_registry:
		return ModLoader.equipment_slot_registry.get_slots()
	# Fallback to default SF-style slots (should match EquipmentSlotRegistry.DEFAULT_SLOTS)
	# Uses category wildcards - requires EquipmentTypeRegistry to be populated
	return [
		{"id": "weapon", "display_name": "Weapon", "accepts_types": ["weapon:*"]},
		{"id": "ring_1", "display_name": "Ring 1", "accepts_types": ["accessory:*"]},
		{"id": "ring_2", "display_name": "Ring 2", "accepts_types": ["accessory:*"]},
		{"id": "accessory", "display_name": "Accessory", "accepts_types": ["accessory:*"]}
	]


## Load starting equipment from CharacterData into pickers
func _load_equipment_from_character(character: CharacterData) -> void:
	# Clear all pickers first
	for slot_id: String in equipment_pickers.keys():
		var picker: ResourcePicker = equipment_pickers[slot_id]
		picker.select_none()
		_clear_equipment_warning(slot_id)

	if not character or character.starting_equipment.is_empty():
		return

	# Map items to their slots
	for item: ItemData in character.starting_equipment:
		if not item:
			continue

		var slot_id: String = item.equipment_slot
		if slot_id.is_empty():
			# Try to infer slot from equipment type
			slot_id = _infer_slot_from_type(item.equipment_type)

		if slot_id in equipment_pickers:
			var picker: ResourcePicker = equipment_pickers[slot_id]
			picker.select_resource(item)

			# Validate class restrictions
			_validate_equipment_for_class(slot_id, item, character)


## Infer equipment slot from equipment type
func _infer_slot_from_type(equipment_type: String) -> String:
	var lower_type: String = equipment_type.to_lower()
	match lower_type:
		"weapon", "sword", "axe", "lance", "bow", "staff", "tome":
			return "weapon"
		"ring":
			return "ring_1"  # Default to first ring slot
		"accessory":
			return "accessory"
		_:
			return "weapon"  # Default fallback


## Save equipment from pickers to CharacterData
func _save_equipment_to_character(character: CharacterData) -> void:
	# Create a new array to avoid read-only state from duplicated resources
	var new_equipment: Array[ItemData] = []

	for slot_id: String in equipment_pickers.keys():
		var picker: ResourcePicker = equipment_pickers[slot_id]
		var item: ItemData = picker.get_selected_resource() as ItemData
		if item:
			new_equipment.append(item)

	character.starting_equipment = new_equipment


## Handle equipment selection change
func _on_equipment_selected(metadata: Dictionary, slot_id: String) -> void:
	var item: ItemData = metadata.get("resource", null) as ItemData

	if item:
		var character: CharacterData = current_resource as CharacterData
		if character:
			_validate_equipment_for_class(slot_id, item, character)
	else:
		_clear_equipment_warning(slot_id)


## Validate that equipment can be used by the character's class
func _validate_equipment_for_class(slot_id: String, item: ItemData, character: CharacterData) -> void:
	_clear_equipment_warning(slot_id)

	if not item or not character:
		return

	var class_data: ClassData = character.character_class
	if not class_data:
		return

	# Check weapon type restrictions
	if item.item_type == ItemData.ItemType.WEAPON:
		if not class_data.equippable_weapon_types.is_empty():
			var item_weapon_type: String = item.equipment_type.to_lower()
			var can_equip: bool = false
			for allowed_type: String in class_data.equippable_weapon_types:
				if allowed_type.to_lower() == item_weapon_type:
					can_equip = true
					break
			if not can_equip:
				_show_equipment_warning(
					slot_id,
					"Warning: %s cannot equip %s weapons" % [class_data.display_name, item.equipment_type]
				)
				return

	# Check if item is cursed
	if item.is_cursed:
		_show_equipment_warning(slot_id, "Note: This is a cursed item")


## Show a warning message for an equipment slot
func _show_equipment_warning(slot_id: String, message: String) -> void:
	if slot_id in equipment_warning_labels:
		var label: Label = equipment_warning_labels[slot_id]
		label.text = message
		label.visible = true


## Clear the warning for an equipment slot
func _clear_equipment_warning(slot_id: String) -> void:
	if slot_id in equipment_warning_labels:
		var label: Label = equipment_warning_labels[slot_id]
		label.text = ""
		label.visible = false
