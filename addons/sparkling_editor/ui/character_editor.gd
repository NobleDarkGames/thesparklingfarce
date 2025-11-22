@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Character Editor UI
## Allows browsing and editing CharacterData resources

var name_edit: LineEdit
var class_option: OptionButton
var level_spin: SpinBox
var bio_edit: TextEdit

# Battle configuration fields
var category_option: OptionButton
var is_unique_check: CheckBox
var default_ai_option: OptionButton

# Stat editors
var hp_spin: SpinBox
var mp_spin: SpinBox
var str_spin: SpinBox
var def_spin: SpinBox
var agi_spin: SpinBox
var int_spin: SpinBox
var luk_spin: SpinBox

# Growth rate editors
var hp_growth_slider: HSlider
var mp_growth_slider: HSlider
var str_growth_slider: HSlider
var def_growth_slider: HSlider
var agi_growth_slider: HSlider
var int_growth_slider: HSlider
var luk_growth_slider: HSlider

var available_classes: Array[ClassData] = []
var available_ai_brains: Array[AIBrain] = []
var current_filter: String = "all"  # "all", "player", "enemy", "boss", "neutral"

# Filter buttons (will be created by _setup_filter_buttons)
var filter_buttons: Dictionary = {}  # {category: Button}


func _ready() -> void:
	resource_directory = "res://data/characters/"
	resource_type_name = "Character"
	resource_type_id = "character"
	super._ready()
	_load_available_classes()
	_setup_filter_buttons()

	# Listen for class changes from other editor tabs via EditorEventBus
	if EditorEventBus:
		EditorEventBus.resource_saved.connect(_on_resource_event)
		EditorEventBus.resource_created.connect(_on_resource_event)
		EditorEventBus.resource_deleted.connect(_on_resource_deleted_event)


## Override: Refresh the editor when mod changes or new resources are created
func _refresh_list() -> void:
	# Call parent to load all resources
	super._refresh_list()

	# Apply current filter
	_apply_filter()

	# Also reload the class dropdown when refreshing
	_load_available_classes()


## Handle resource saved/created events from EditorEventBus
func _on_resource_event(res_type: String, res_id: String, resource: Resource) -> void:
	# Reload class dropdown when any class is saved or created
	if res_type == "class":
		_load_available_classes()


## Handle resource deleted events from EditorEventBus
func _on_resource_deleted_event(res_type: String, res_id: String) -> void:
	# Reload class dropdown when any class is deleted
	if res_type == "class":
		_load_available_classes()


## Override: Create the character-specific detail form
func _create_detail_form() -> void:
	# Basic info section
	_add_basic_info_section()

	# Battle configuration section
	_add_battle_configuration_section()

	# Stats section
	_add_stats_section()

	# Growth rates section
	_add_growth_rates_section()

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

	# Set battle configuration
	var category_index: int = category_option.get_item_index(character.unit_category)
	if category_index >= 0:
		category_option.select(category_index)
	else:
		category_option.select(0)  # Default to "player"

	is_unique_check.button_pressed = character.is_unique

	# Set default AI brain
	if character.default_ai_brain:
		for i in range(available_ai_brains.size()):
			if available_ai_brains[i] == character.default_ai_brain:
				default_ai_option.select(i + 1)
				break
	else:
		default_ai_option.select(0)  # (None)

	# Set class
	if character.character_class:
		for i in range(available_classes.size()):
			if available_classes[i] == character.character_class:
				class_option.selected = i + 1
				break

	# Set stats
	hp_spin.value = character.base_hp
	mp_spin.value = character.base_mp
	str_spin.value = character.base_strength
	def_spin.value = character.base_defense
	agi_spin.value = character.base_agility
	int_spin.value = character.base_intelligence
	luk_spin.value = character.base_luck

	# Set growth rates
	hp_growth_slider.value = character.hp_growth
	mp_growth_slider.value = character.mp_growth
	str_growth_slider.value = character.strength_growth
	def_growth_slider.value = character.defense_growth
	agi_growth_slider.value = character.agility_growth
	int_growth_slider.value = character.intelligence_growth
	luk_growth_slider.value = character.luck_growth


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

	# Update default AI brain
	var ai_index: int = default_ai_option.selected - 1
	if ai_index >= 0 and ai_index < available_ai_brains.size():
		character.default_ai_brain = available_ai_brains[ai_index]
	else:
		character.default_ai_brain = null

	# Update class
	var class_index: int = class_option.selected - 1
	if class_index >= 0 and class_index < available_classes.size():
		character.character_class = available_classes[class_index]
	else:
		character.character_class = null

	# Update stats
	character.base_hp = int(hp_spin.value)
	character.base_mp = int(mp_spin.value)
	character.base_strength = int(str_spin.value)
	character.base_defense = int(def_spin.value)
	character.base_agility = int(agi_spin.value)
	character.base_intelligence = int(int_spin.value)
	character.base_luck = int(luk_spin.value)

	# Update growth rates
	character.hp_growth = int(hp_growth_slider.value)
	character.mp_growth = int(mp_growth_slider.value)
	character.strength_growth = int(str_growth_slider.value)
	character.defense_growth = int(def_growth_slider.value)
	character.agility_growth = int(agi_growth_slider.value)
	character.intelligence_growth = int(int_growth_slider.value)
	character.luck_growth = int(luk_growth_slider.value)


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
	section_label.add_theme_font_size_override("font_size", 14)
	section.add_child(section_label)

	# Name
	var name_container: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = "Name:"
	name_label.custom_minimum_size.x = 120
	name_container.add_child(name_label)

	name_edit = LineEdit.new()
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_container.add_child(name_edit)
	section.add_child(name_container)

	# Class
	var class_container: HBoxContainer = HBoxContainer.new()
	var class_label: Label = Label.new()
	class_label.text = "Class:"
	class_label.custom_minimum_size.x = 120
	class_container.add_child(class_label)

	class_option = OptionButton.new()
	class_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_container.add_child(class_option)
	section.add_child(class_container)

	# Starting Level
	var level_container: HBoxContainer = HBoxContainer.new()
	var level_label: Label = Label.new()
	level_label.text = "Starting Level:"
	level_label.custom_minimum_size.x = 120
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
	bio_edit.custom_minimum_size.y = 100
	section.add_child(bio_edit)

	detail_panel.add_child(section)


func _add_battle_configuration_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Battle Configuration"
	section_label.add_theme_font_size_override("font_size", 14)
	section.add_child(section_label)

	# Unit Category
	var category_container: HBoxContainer = HBoxContainer.new()
	var category_label: Label = Label.new()
	category_label.text = "Unit Category:"
	category_label.custom_minimum_size.x = 120
	category_container.add_child(category_label)

	category_option = OptionButton.new()
	category_option.add_item("player", 0)
	category_option.add_item("enemy", 1)
	category_option.add_item("boss", 2)
	category_option.add_item("neutral", 3)
	category_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_container.add_child(category_option)
	section.add_child(category_container)

	# Is Unique
	var unique_container: HBoxContainer = HBoxContainer.new()
	var unique_label: Label = Label.new()
	unique_label.text = "Is Unique:"
	unique_label.custom_minimum_size.x = 120
	unique_container.add_child(unique_label)

	is_unique_check = CheckBox.new()
	is_unique_check.button_pressed = true
	is_unique_check.text = "This is a unique character (not a reusable template)"
	unique_container.add_child(is_unique_check)
	section.add_child(unique_container)

	# Default AI Brain
	var ai_container: HBoxContainer = HBoxContainer.new()
	var ai_label: Label = Label.new()
	ai_label.text = "Default AI:"
	ai_label.custom_minimum_size.x = 120
	ai_container.add_child(ai_label)

	default_ai_option = OptionButton.new()
	default_ai_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ai_container.add_child(default_ai_option)
	section.add_child(ai_container)

	var ai_help: Label = Label.new()
	ai_help.text = "AI used when this character is an enemy (can override in Battle Editor)"
	ai_help.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	ai_help.add_theme_font_size_override("font_size", 10)
	section.add_child(ai_help)

	detail_panel.add_child(section)

	# Load available AI brains after creating the dropdown
	_load_available_ai_brains()


func _add_stats_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Base Stats"
	section_label.add_theme_font_size_override("font_size", 14)
	section.add_child(section_label)

	hp_spin = _create_stat_editor("HP:", section)
	mp_spin = _create_stat_editor("MP:", section)
	str_spin = _create_stat_editor("Strength:", section)
	def_spin = _create_stat_editor("Defense:", section)
	agi_spin = _create_stat_editor("Agility:", section)
	int_spin = _create_stat_editor("Intelligence:", section)
	luk_spin = _create_stat_editor("Luck:", section)

	detail_panel.add_child(section)


func _add_growth_rates_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Growth Rates (%)"
	section_label.add_theme_font_size_override("font_size", 14)
	section.add_child(section_label)

	hp_growth_slider = _create_growth_editor("HP Growth:", section)
	mp_growth_slider = _create_growth_editor("MP Growth:", section)
	str_growth_slider = _create_growth_editor("STR Growth:", section)
	def_growth_slider = _create_growth_editor("DEF Growth:", section)
	agi_growth_slider = _create_growth_editor("AGI Growth:", section)
	int_growth_slider = _create_growth_editor("INT Growth:", section)
	luk_growth_slider = _create_growth_editor("LUK Growth:", section)

	detail_panel.add_child(section)


func _create_stat_editor(label_text: String, parent: VBoxContainer) -> SpinBox:
	var container: HBoxContainer = HBoxContainer.new()

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	container.add_child(label)

	var spin: SpinBox = SpinBox.new()
	spin.min_value = 1
	spin.max_value = 999
	spin.value = 10
	container.add_child(spin)

	parent.add_child(container)
	return spin


func _create_growth_editor(label_text: String, parent: VBoxContainer) -> HSlider:
	var container: HBoxContainer = HBoxContainer.new()

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	container.add_child(label)

	var slider: HSlider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.value = 50
	slider.step = 5
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(slider)

	var value_label: Label = Label.new()
	value_label.text = "50%"
	value_label.custom_minimum_size.x = 50
	slider.value_changed.connect(func(value: float) -> void: value_label.text = str(int(value)) + "%")
	container.add_child(value_label)

	parent.add_child(container)
	return slider


func _load_available_classes() -> void:
	available_classes.clear()
	class_option.clear()
	class_option.add_item("(None)", 0)

	# Use ModLoader to get the correct directory for the active mod
	var class_dir: String = ""
	if ModLoader:
		var active_mod: ModManifest = ModLoader.get_active_mod()
		if active_mod:
			var resource_dirs: Dictionary = ModLoader.get_resource_directories(active_mod.mod_id)
			if "class" in resource_dirs:
				class_dir = resource_dirs["class"]

	# Fallback to legacy path if ModLoader unavailable
	if class_dir == "":
		class_dir = "res://data/classes/"

	var dir: DirAccess = DirAccess.open(class_dir)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var class_data: ClassData = load(class_dir.path_join(file_name))
				if class_data:
					available_classes.append(class_data)
					class_option.add_item(class_data.display_name, available_classes.size())
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		push_warning("Character Editor: Could not open class directory: " + class_dir)


func _load_available_ai_brains() -> void:
	available_ai_brains.clear()
	default_ai_option.clear()
	default_ai_option.add_item("(None)", 0)

	# Scan for AI brain files in mods
	var ai_dirs: Array[String] = [
		"res://mods/base_game/ai_brains/",
		"res://mods/_base_game/ai_brains/",
		"res://core/ai/"  # Future location for built-in AI
	]

	for ai_dir in ai_dirs:
		var dir: DirAccess = DirAccess.open(ai_dir)
		if dir:
			dir.list_dir_begin()
			var file_name: String = dir.get_next()
			while file_name != "":
				if file_name.ends_with(".gd") and not file_name.begins_with("."):
					var ai_script: GDScript = load(ai_dir.path_join(file_name))
					if ai_script:
						# Create an instance to get the class name/type
						var ai_instance: AIBrain = ai_script.new()
						if ai_instance:
							var display_name: String = file_name.get_basename().replace("ai_", "").capitalize()
							available_ai_brains.append(ai_instance)
							default_ai_option.add_item(display_name, available_ai_brains.size())
				file_name = dir.get_next()
			dir.list_dir_end()


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

	# Create filter buttons
	var categories: Array[String] = ["all", "player", "enemy", "boss", "neutral"]
	var button_texts: Dictionary = {
		"all": "All",
		"player": "Players",
		"enemy": "Enemies",
		"boss": "Bosses",
		"neutral": "Neutrals"
	}

	for category in categories:
		var btn: Button = Button.new()
		btn.text = button_texts[category]
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
	if current_filter == "all":
		# Show all items
		for i in range(resource_list.item_count):
			resource_list.set_item_disabled(i, false)
		return

	# Filter based on category
	for i in range(resource_list.item_count):
		var path: String = resource_list.get_item_metadata(i)
		var character: CharacterData = load(path) as CharacterData

		if character:
			var should_show: bool = (character.unit_category == current_filter)
			resource_list.set_item_disabled(i, not should_show)

			# Hide disabled items by making them invisible
			if not should_show:
				# Add a prefix to visually hide (Godot doesn't have native hide for ItemList items)
				# Instead, we'll use a different approach: only show matching items
				pass
