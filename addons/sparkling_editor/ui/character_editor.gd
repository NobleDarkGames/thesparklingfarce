@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Character Editor UI
## Allows browsing and editing CharacterData resources

var name_edit: LineEdit
var class_picker: ResourcePicker  # Use ResourcePicker for cross-mod class selection
var level_spin: SpinBox
var bio_edit: TextEdit

# Appearance pickers
var _portrait_picker: PortraitPicker
var _sprite_frames_picker: MapSpritesheetPicker  # For sprite_frames (SpriteFrames)

# Battle configuration fields
var category_option: OptionButton
var is_unique_check: CheckBox
var is_hero_check: CheckBox
var is_boss_check: CheckBox
var is_default_party_member_check: CheckBox
var default_ai_option: OptionButton

# AI Threat Configuration section
var ai_threat_section: CollapseSection
var ai_threat_modifier_slider: HSlider
var ai_threat_modifier_value_label: Label
var ai_threat_tags_container: HFlowContainer
var ai_threat_custom_tag_edit: LineEdit
var ai_threat_add_tag_button: Button
var _current_threat_tags: Array[String] = []

# Common threat tags with descriptions (for quick-add buttons)
# Note: "boss" was removed - use the is_boss checkbox instead
const COMMON_THREAT_TAGS: Dictionary = {
	"priority_target": "AI focuses this unit first",
	"avoid": "AI ignores this unit when targeting",
	"vip": "High-value target for protection (non-boss)",
	"healer": "Explicitly marks as healer (usually auto-detected)",
	"tank": "Marks as a defensive unit"
}

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

# Starting Inventory section (collapsible)
var inventory_section: CollapseSection
var inventory_list_container: VBoxContainer
var inventory_add_button: Button
var _current_inventory_items: Array[String] = []  # Item IDs

# Unique Abilities section (collapsible)
var unique_abilities_section: CollapseSection
var unique_abilities_container: VBoxContainer
var unique_abilities_add_button: Button
var _current_unique_abilities: Array[Dictionary] = []

var available_ai_behaviors: Array[AIBehaviorData] = []
var current_filter: String = "all"  # "all", "player", "enemy", "neutral"

# Filter buttons (will be created by _setup_filter_buttons)
var filter_buttons: Dictionary = {}  # {category: Button}


func _ready() -> void:
	resource_type_name = "Character"
	resource_type_id = "character"
	# resource_directory is set dynamically via base class using ModLoader.get_active_mod()

	# Declare dependencies BEFORE calling super._ready() so base class sets up tracking
	# Note: ResourcePickers auto-refresh via EditorEventBus
	# This declaration is for completeness and documents the editor's dependencies
	resource_dependencies = ["class", "ability"]

	super._ready()
	_setup_filter_buttons()


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

	# Appearance section (portraits, sprites)
	_add_appearance_section()

	# Battle configuration section
	_add_battle_configuration_section()

	# AI Threat Configuration section (for advanced AI targeting)
	_add_ai_threat_configuration_section()

	# Stats section
	_add_stats_section()

	# Equipment section (starting equipment for this character)
	_add_equipment_section()

	# Starting Inventory section (items character carries but doesn't equip)
	_add_inventory_section()

	# Unique Abilities section (character-specific abilities that bypass class restrictions)
	_add_unique_abilities_section()

	# Add the button container at the end (with separator for visual clarity)
	_add_button_container_to_detail_panel()


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
	for i: int in range(category_option.item_count):
		if category_option.get_item_text(i) == character.unit_category:
			category_index = i
			break

	if category_index >= 0:
		category_option.select(category_index)
	else:
		category_option.select(0)  # Default to "player"

	is_unique_check.button_pressed = character.is_unique
	is_hero_check.button_pressed = character.is_hero
	is_boss_check.button_pressed = character.is_boss
	is_default_party_member_check.button_pressed = character.is_default_party_member

	# Set default AI behavior
	if character.default_ai_behavior:
		for i: int in range(available_ai_behaviors.size()):
			if available_ai_behaviors[i].resource_path == character.default_ai_behavior.resource_path:
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

	# Load starting inventory items
	_load_inventory_from_character(character)

	# Load unique abilities
	_load_unique_abilities(character)

	# Load appearance assets
	_load_appearance_from_character(character)

	# Load AI threat configuration
	_load_ai_threat_configuration(character)


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
	character.is_boss = is_boss_check.button_pressed
	character.is_default_party_member = is_default_party_member_check.button_pressed

	# Update default AI behavior
	var ai_index: int = default_ai_option.selected - 1
	if ai_index >= 0 and ai_index < available_ai_behaviors.size():
		character.default_ai_behavior = available_ai_behaviors[ai_index]
	else:
		character.default_ai_behavior = null

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

	# Update starting inventory from list
	_save_inventory_to_character(character)

	# Update unique abilities from list
	_save_unique_abilities(character)

	# Update appearance assets from pickers
	_save_appearance_to_character(character)

	# Update AI threat configuration
	_save_ai_threat_configuration(character)


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
	var character: CharacterData = resource_to_check as CharacterData
	if not character:
		return []

	var references: Array[String] = []
	var char_path: String = character.resource_path

	# Check battles across all mods
	var battle_files: Array[Dictionary] = SparklingEditorUtils.scan_mods_for_files("data/battles", ".tres")
	for file_info: Dictionary in battle_files:
		var battle: BattleData = load(file_info.path) as BattleData
		if battle:
			var found_in_battle: bool = false
			for enemy: Dictionary in battle.enemies:
				var enemy_char: CharacterData = enemy.get("character") as CharacterData
				if enemy_char and enemy_char.resource_path == char_path:
					found_in_battle = true
					break
			if not found_in_battle:
				for neutral: Dictionary in battle.neutrals:
					var neutral_char: CharacterData = neutral.get("character") as CharacterData
					if neutral_char and neutral_char.resource_path == char_path:
						found_in_battle = true
						break
			if found_in_battle:
				references.append(file_info.path)

	# Check cinematics for spawn_entity commands referencing this character
	var char_id: String = char_path.get_file().get_basename()
	var cinematic_files: Array[Dictionary] = SparklingEditorUtils.scan_mods_for_files("data/cinematics", ".json")
	for file_info: Dictionary in cinematic_files:
		var json_text: String = FileAccess.get_file_as_string(file_info.path)
		# Quick check before full parse - look for character ID in JSON
		if char_id in json_text:
			references.append(file_info.path)

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
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	# Name
	var name_container: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = "Name:"
	name_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	name_container.add_child(name_label)

	name_edit = LineEdit.new()
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.max_length = 64  # Reasonable limit for UI display
	name_edit.tooltip_text = "Display name shown in menus and dialogue. Can differ from resource filename."
	name_container.add_child(name_edit)
	section.add_child(name_container)

	# Class - use ResourcePicker for cross-mod class selection
	class_picker = ResourcePicker.new()
	class_picker.resource_type = "class"
	class_picker.label_text = "Class:"
	class_picker.label_min_width = 120
	class_picker.allow_none = true
	class_picker.tooltip_text = "Determines stat growth, abilities, and equippable weapon types. E.g., Warrior, Mage, Archer."
	section.add_child(class_picker)

	# Starting Level
	var level_container: HBoxContainer = HBoxContainer.new()
	var level_label: Label = Label.new()
	level_label.text = "Starting Level:"
	level_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	level_container.add_child(level_label)

	level_spin = SpinBox.new()
	level_spin.min_value = 1
	level_spin.max_value = 99
	level_spin.value = 1
	level_spin.tooltip_text = "Level when character joins the party. Higher = stronger starting stats. Typical: 1-5 for early game, 10-20 for late joiners."
	level_container.add_child(level_spin)
	section.add_child(level_container)

	# Biography
	var bio_label: Label = Label.new()
	bio_label.text = "Biography:"
	section.add_child(bio_label)

	bio_edit = TextEdit.new()
	bio_edit.custom_minimum_size.y = 120
	bio_edit.tooltip_text = "Background story and personality description. Shown in character status screens and recruitment scenes."
	section.add_child(bio_edit)

	detail_panel.add_child(section)


func _add_appearance_section() -> void:
	var section: CollapseSection = CollapseSection.new()
	section.title = "Appearance"
	section.start_collapsed = false

	var help_label: Label = Label.new()
	help_label.text = "Visual assets for this character"
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	section.add_content_child(help_label)

	# Portrait Picker
	_portrait_picker = PortraitPicker.new()
	_portrait_picker.texture_selected.connect(_on_portrait_selected)
	_portrait_picker.texture_cleared.connect(_on_portrait_cleared)
	section.add_content_child(_portrait_picker)

	# Sprite Frames Picker (consolidated: used for both map and battle grid)
	_sprite_frames_picker = MapSpritesheetPicker.new()
	_sprite_frames_picker.texture_selected.connect(_on_spritesheet_selected)
	_sprite_frames_picker.texture_cleared.connect(_on_spritesheet_cleared)
	_sprite_frames_picker.sprite_frames_generated.connect(_on_sprite_frames_generated)
	section.add_content_child(_sprite_frames_picker)

	detail_panel.add_child(section)


func _add_battle_configuration_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Battle Configuration"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	# Unit Category
	var category_container: HBoxContainer = HBoxContainer.new()
	var category_label: Label = Label.new()
	category_label.text = "Unit Category:"
	category_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	category_container.add_child(category_label)

	category_option = OptionButton.new()
	category_option.tooltip_text = "Determines AI allegiance: player = controllable ally, enemy = hostile AI, boss = high-priority enemy, neutral = non-combatant."
	# Populate from registry
	var categories: Array[String] = _get_unit_categories_from_registry()
	for i: int in range(categories.size()):
		category_option.add_item(categories[i], i)
	category_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_container.add_child(category_option)
	section.add_child(category_container)

	# Is Unique
	var unique_container: HBoxContainer = HBoxContainer.new()
	var unique_label: Label = Label.new()
	unique_label.text = "Is Unique:"
	unique_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	unique_container.add_child(unique_label)

	is_unique_check = CheckBox.new()
	is_unique_check.button_pressed = true
	is_unique_check.text = "This is a unique character (not a reusable template)"
	is_unique_check.tooltip_text = "ON = named character that persists across battles (e.g., Max). OFF = generic template for spawning multiple copies (e.g., Goblin)."
	unique_container.add_child(is_unique_check)
	section.add_child(unique_container)

	# Is Hero
	var hero_container: HBoxContainer = HBoxContainer.new()
	var hero_label: Label = Label.new()
	hero_label.text = "Is Hero:"
	hero_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	hero_container.add_child(hero_label)

	is_hero_check = CheckBox.new()
	is_hero_check.button_pressed = false
	is_hero_check.text = "This is the primary Hero/protagonist (only one per party)"
	is_hero_check.tooltip_text = "The main protagonist. If this character dies, battle is lost. Only one hero per party. Enables special story triggers."
	hero_container.add_child(is_hero_check)
	section.add_child(hero_container)

	# Is Boss
	var boss_container: HBoxContainer = HBoxContainer.new()
	var boss_label: Label = Label.new()
	boss_label.text = "Is Boss:"
	boss_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	boss_container.add_child(boss_label)

	is_boss_check = CheckBox.new()
	is_boss_check.button_pressed = false
	is_boss_check.text = "This is a boss enemy (allies will protect)"
	is_boss_check.tooltip_text = "Mark as a boss enemy. Defensive AI will prioritize protecting this unit, and threat calculations are boosted."
	boss_container.add_child(is_boss_check)
	section.add_child(boss_container)

	# Is Default Party Member
	var party_member_container: HBoxContainer = HBoxContainer.new()
	var party_member_label: Label = Label.new()
	party_member_label.text = "Starting Party:"
	party_member_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	party_member_container.add_child(party_member_label)

	is_default_party_member_check = CheckBox.new()
	is_default_party_member_check.button_pressed = false
	is_default_party_member_check.text = "Include in default starting party"
	is_default_party_member_check.tooltip_text = "If ON, character joins the party at the start of a new game. Use for starting party members."
	party_member_container.add_child(is_default_party_member_check)
	section.add_child(party_member_container)

	# Default AI Behavior
	var ai_container: HBoxContainer = HBoxContainer.new()
	var ai_label: Label = Label.new()
	ai_label.text = "Default AI:"
	ai_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	ai_container.add_child(ai_label)

	default_ai_option = OptionButton.new()
	default_ai_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	default_ai_option.tooltip_text = "AI behavior when this character is an enemy. E.g., Aggressive rushes, Cautious stays back, Healer prioritizes allies."
	ai_container.add_child(default_ai_option)
	section.add_child(ai_container)

	var ai_help: Label = Label.new()
	ai_help.text = "AI used when this character is an enemy (can override in Battle Editor)"
	ai_help.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	ai_help.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(ai_help)

	detail_panel.add_child(section)

	# Load available AI behaviors after creating the dropdown
	_load_available_ai_behaviors()


func _add_ai_threat_configuration_section() -> void:
	ai_threat_section = CollapseSection.new()
	ai_threat_section.title = "AI Threat Configuration"
	ai_threat_section.start_collapsed = true

	var help_label: Label = Label.new()
	help_label.text = "Advanced settings for AI targeting behavior"
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	ai_threat_section.add_content_child(help_label)

	# Threat Modifier with slider and preset buttons
	var modifier_container: VBoxContainer = VBoxContainer.new()

	var modifier_header: HBoxContainer = HBoxContainer.new()
	var modifier_label: Label = Label.new()
	modifier_label.text = "Threat Modifier:"
	modifier_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	modifier_label.tooltip_text = "Multiplier for AI threat calculations. Higher = AI prioritizes protecting/attacking this unit more."
	modifier_header.add_child(modifier_label)

	ai_threat_modifier_value_label = Label.new()
	ai_threat_modifier_value_label.text = "1.0"
	ai_threat_modifier_value_label.custom_minimum_size.x = 40
	modifier_header.add_child(ai_threat_modifier_value_label)
	modifier_container.add_child(modifier_header)

	# Slider
	var slider_container: HBoxContainer = HBoxContainer.new()
	ai_threat_modifier_slider = HSlider.new()
	ai_threat_modifier_slider.min_value = 0.0
	ai_threat_modifier_slider.max_value = 5.0
	ai_threat_modifier_slider.step = 0.1
	ai_threat_modifier_slider.value = 1.0
	ai_threat_modifier_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ai_threat_modifier_slider.custom_minimum_size.x = 200
	ai_threat_modifier_slider.tooltip_text = "Multiplier for AI targeting priority. 0.5 = low priority, 1.0 = normal, 2.0+ = high priority target."
	ai_threat_modifier_slider.value_changed.connect(_on_threat_modifier_changed)
	slider_container.add_child(ai_threat_modifier_slider)
	modifier_container.add_child(slider_container)

	# Preset buttons
	var preset_container: HBoxContainer = HBoxContainer.new()
	preset_container.add_theme_constant_override("separation", 4)

	var preset_label: Label = Label.new()
	preset_label.text = "Presets:"
	preset_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	preset_container.add_child(preset_label)

	var presets: Array[Dictionary] = [
		{"label": "Fodder (0.5)", "value": 0.5, "tooltip": "Enemies deprioritize this unit"},
		{"label": "Normal (1.0)", "value": 1.0, "tooltip": "Default threat level"},
		{"label": "Elite (1.5)", "value": 1.5, "tooltip": "Slightly higher priority"},
		{"label": "Boss (2.0)", "value": 2.0, "tooltip": "High priority protection/targeting"},
		{"label": "VIP (3.0)", "value": 3.0, "tooltip": "Maximum priority"}
	]

	for preset: Dictionary in presets:
		var btn: Button = Button.new()
		btn.text = preset.label
		btn.tooltip_text = preset.tooltip
		btn.pressed.connect(_on_threat_modifier_preset.bind(preset.value))
		preset_container.add_child(btn)

	modifier_container.add_child(preset_container)
	ai_threat_section.add_content_child(modifier_container)

	# Separator
	var sep: HSeparator = HSeparator.new()
	ai_threat_section.add_content_child(sep)

	# Threat Tags section
	var tags_header: Label = Label.new()
	tags_header.text = "Threat Tags:"
	tags_header.tooltip_text = "Tags that modify AI targeting behavior"
	ai_threat_section.add_content_child(tags_header)

	var tags_help: Label = Label.new()
	tags_help.text = "Click to add common tags, or type custom tags below"
	tags_help.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	tags_help.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	ai_threat_section.add_content_child(tags_help)

	# Quick-add buttons for common tags
	var quick_tags_container: HFlowContainer = HFlowContainer.new()
	quick_tags_container.add_theme_constant_override("h_separation", 4)
	quick_tags_container.add_theme_constant_override("v_separation", 4)

	for tag: String in COMMON_THREAT_TAGS.keys():
		var btn: Button = Button.new()
		btn.text = "+ " + tag
		btn.tooltip_text = COMMON_THREAT_TAGS[tag]
		btn.pressed.connect(_on_add_threat_tag.bind(tag))
		quick_tags_container.add_child(btn)

	ai_threat_section.add_content_child(quick_tags_container)

	# Current tags display
	var current_tags_label: Label = Label.new()
	current_tags_label.text = "Active Tags:"
	ai_threat_section.add_content_child(current_tags_label)

	ai_threat_tags_container = HFlowContainer.new()
	ai_threat_tags_container.add_theme_constant_override("h_separation", 4)
	ai_threat_tags_container.add_theme_constant_override("v_separation", 4)
	ai_threat_section.add_content_child(ai_threat_tags_container)

	# Custom tag input
	var custom_tag_container: HBoxContainer = HBoxContainer.new()
	var custom_label: Label = Label.new()
	custom_label.text = "Custom Tag:"
	custom_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	custom_tag_container.add_child(custom_label)

	ai_threat_custom_tag_edit = LineEdit.new()
	ai_threat_custom_tag_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ai_threat_custom_tag_edit.placeholder_text = "e.g., flanker, glass_cannon"
	ai_threat_custom_tag_edit.tooltip_text = "Add custom tags for mod-specific AI behaviors. Use snake_case format."
	ai_threat_custom_tag_edit.text_submitted.connect(_on_custom_tag_submitted)
	custom_tag_container.add_child(ai_threat_custom_tag_edit)

	ai_threat_add_tag_button = Button.new()
	ai_threat_add_tag_button.text = "Add"
	ai_threat_add_tag_button.pressed.connect(_on_add_custom_tag_pressed)
	custom_tag_container.add_child(ai_threat_add_tag_button)

	ai_threat_section.add_content_child(custom_tag_container)

	detail_panel.add_child(ai_threat_section)


func _on_threat_modifier_changed(value: float) -> void:
	ai_threat_modifier_value_label.text = "%.1f" % value
	_mark_dirty()


func _on_threat_modifier_preset(value: float) -> void:
	ai_threat_modifier_slider.value = value
	ai_threat_modifier_value_label.text = "%.1f" % value
	_mark_dirty()


func _on_add_threat_tag(tag: String) -> void:
	if tag not in _current_threat_tags:
		_current_threat_tags.append(tag)
		_refresh_threat_tags_display()
		_mark_dirty()


func _on_remove_threat_tag(tag: String) -> void:
	_current_threat_tags.erase(tag)
	_refresh_threat_tags_display()
	_mark_dirty()


func _on_custom_tag_submitted(tag: String) -> void:
	_add_custom_tag(tag)


func _on_add_custom_tag_pressed() -> void:
	_add_custom_tag(ai_threat_custom_tag_edit.text)


func _add_custom_tag(tag: String) -> void:
	var clean_tag: String = tag.strip_edges().to_lower().replace(" ", "_")
	if clean_tag.is_empty():
		return
	if clean_tag not in _current_threat_tags:
		_current_threat_tags.append(clean_tag)
		_refresh_threat_tags_display()
		_mark_dirty()
	ai_threat_custom_tag_edit.text = ""


func _refresh_threat_tags_display() -> void:
	# Clear existing tag buttons
	for child: Node in ai_threat_tags_container.get_children():
		child.queue_free()

	if _current_threat_tags.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "(No tags)"
		empty_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
		ai_threat_tags_container.add_child(empty_label)
		return

	# Create pill-style buttons for each tag
	for tag: String in _current_threat_tags:
		var tag_btn: Button = Button.new()
		tag_btn.text = tag + " x"
		tag_btn.tooltip_text = "Click to remove this tag"
		if tag in COMMON_THREAT_TAGS:
			tag_btn.tooltip_text = COMMON_THREAT_TAGS[tag] + "\nClick to remove"
		tag_btn.pressed.connect(_on_remove_threat_tag.bind(tag))
		ai_threat_tags_container.add_child(tag_btn)


func _add_stats_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Base Stats"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	hp_spin = _create_stat_editor("HP:", section, "Hit Points - how much damage the character can take before falling. Typical: 15-25 for mages, 25-40 for warriors.")
	mp_spin = _create_stat_editor("MP:", section, "Magic Points - resource for casting spells and abilities. Typical: 0 for melee, 15-30 for casters.")
	str_spin = _create_stat_editor("Strength:", section, "Physical attack power. Higher = more damage with weapons. Typical: 3-6 for casters, 6-10 for fighters.")
	def_spin = _create_stat_editor("Defense:", section, "Physical damage reduction. Higher = less damage taken from attacks. Typical: 3-5 for mages, 6-10 for tanks.")
	agi_spin = _create_stat_editor("Agility:", section, "Turn order and evasion. Higher = acts first, harder to hit. Also affects movement range.")
	int_spin = _create_stat_editor("Intelligence:", section, "Magic attack power and MP growth. Higher = stronger spells. Typical: 6-10 for mages, 2-4 for fighters.")
	luk_spin = _create_stat_editor("Luck:", section, "Critical hit chance and rare drop rates. Subtle but useful. Typical: 3-7 for most characters.")

	detail_panel.add_child(section)


func _create_stat_editor(label_text: String, parent: VBoxContainer, tooltip: String = "") -> SpinBox:
	var container: HBoxContainer = HBoxContainer.new()

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	if not tooltip.is_empty():
		label.tooltip_text = tooltip
	container.add_child(label)

	var spin: SpinBox = SpinBox.new()
	spin.min_value = 1
	spin.max_value = 999
	spin.value = 10
	if not tooltip.is_empty():
		spin.tooltip_text = tooltip
	container.add_child(spin)

	parent.add_child(container)
	return spin


func _load_available_ai_behaviors() -> void:
	available_ai_behaviors.clear()
	default_ai_option.clear()
	default_ai_option.add_item("(None)", 0)

	# Use ModLoader registry for ai_behavior resources (same as Battle Editor)
	if ModLoader and ModLoader.registry:
		var behaviors: Array[Resource] = ModLoader.registry.get_all_resources("ai_behavior")
		for resource: Resource in behaviors:
			var ai_behavior: AIBehaviorData = resource as AIBehaviorData
			if ai_behavior:
				available_ai_behaviors.append(ai_behavior)
				var display_name: String = ai_behavior.display_name if ai_behavior.display_name else ai_behavior.behavior_id.capitalize()
				default_ai_option.add_item(display_name, available_ai_behaviors.size())


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

	for category: String in categories:
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
	for btn_category: Variant in filter_buttons.keys():
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

	# Use all_resources to maintain index alignment with all_resource_source_mods
	for i: int in range(all_resources.size()):
		var character: CharacterData = all_resources[i] as CharacterData
		if not character:
			continue

		# Check if matches current filter
		var matches_filter: bool = (current_filter == "all") or (character.unit_category == current_filter)

		if matches_filter:
			# Get source mod for this resource (same as base class)
			var source_mod: String = all_resource_source_mods[i] if i < all_resource_source_mods.size() else ""
			var display_name: String = _get_resource_display_name(character)

			# Format: [mod_id] Resource Name (matches base class format)
			var list_text: String = "[%s] %s" % [source_mod, display_name] if not source_mod.is_empty() else display_name
			resource_list.add_item(list_text)

			# Store the original resource path so we can find the right resource
			var original_path: String = all_resource_paths[i] if i < all_resource_paths.size() else character.resource_path
			resource_list.set_item_metadata(resource_list.item_count - 1, original_path)

			# Restore selection if this was the previously selected item
			if original_path == selected_path:
				resource_list.select(resource_list.item_count - 1)


## Get unit categories from ModLoader's unit category registry (with fallback)
func _get_unit_categories_from_registry() -> Array[String]:
	if ModLoader and ModLoader.unit_category_registry:
		return ModLoader.unit_category_registry.get_categories()
	# Fallback to defaults if registry not available
	return ["player", "enemy", "neutral"]


## Add the starting equipment section with pickers for each slot (collapsible)
func _add_equipment_section() -> void:
	equipment_section = CollapseSection.new()
	equipment_section.title = "Starting Equipment"
	equipment_section.start_collapsed = false

	var help_label: Label = Label.new()
	help_label.text = "Equipment the character starts with when recruited"
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", 14)
	equipment_section.add_content_child(help_label)

	# Get available equipment slots from registry
	var slots: Array[Dictionary] = _get_equipment_slots()

	equipment_pickers.clear()
	equipment_warning_labels.clear()

	for slot: Dictionary in slots:
		var slot_id: String = DictUtils.get_string(slot, "id", "")
		var display_name: String = DictUtils.get_string(slot, "display_name", slot_id.capitalize())
		var accepts_types: Array = DictUtils.get_array(slot, "accepts_types", [])

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


# =============================================================================
# STARTING INVENTORY SECTION
# =============================================================================

## Add the starting inventory section with an item list and add button
func _add_inventory_section() -> void:
	inventory_section = CollapseSection.new()
	inventory_section.title = "Starting Inventory"
	inventory_section.start_collapsed = true

	var help_label: Label = Label.new()
	help_label.text = "Items the character carries (not equipped) when recruited"
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	inventory_section.add_content_child(help_label)

	# Container for the list of inventory items
	inventory_list_container = VBoxContainer.new()
	inventory_list_container.add_theme_constant_override("separation", 4)
	inventory_section.add_content_child(inventory_list_container)

	# Add Item button
	var button_container: HBoxContainer = HBoxContainer.new()
	inventory_add_button = Button.new()
	inventory_add_button.text = "+ Add Item"
	inventory_add_button.tooltip_text = "Add an item to the character's starting inventory"
	inventory_add_button.pressed.connect(_on_inventory_add_pressed)
	button_container.add_child(inventory_add_button)
	inventory_section.add_content_child(button_container)

	detail_panel.add_child(inventory_section)


## Load starting inventory from CharacterData into the list
func _load_inventory_from_character(character: CharacterData) -> void:
	_current_inventory_items.clear()

	if character and not character.starting_inventory.is_empty():
		for item_id: String in character.starting_inventory:
			_current_inventory_items.append(item_id)

	_refresh_inventory_list_display()


## Save starting inventory from list to CharacterData
func _save_inventory_to_character(character: CharacterData) -> void:
	var new_inventory: Array[String] = []
	for item_id: String in _current_inventory_items:
		new_inventory.append(item_id)
	character.starting_inventory = new_inventory


## Handle Add Item button press - opens a ResourcePicker dialog
func _on_inventory_add_pressed() -> void:
	# Create a popup dialog with a ResourcePicker
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Add Inventory Item"
	dialog.min_size = Vector2(400, 100)

	var picker: ResourcePicker = ResourcePicker.new()
	picker.resource_type = "item"
	picker.label_text = "Item:"
	picker.label_min_width = 60
	picker.allow_none = false

	dialog.add_child(picker)

	# Store reference for the confirmation callback
	dialog.set_meta("picker", picker)

	dialog.confirmed.connect(_on_inventory_add_confirmed.bind(dialog))
	dialog.canceled.connect(dialog.queue_free)

	# Add to editor and show
	EditorInterface.popup_dialog_centered(dialog)


## Handle confirmation of adding an inventory item
func _on_inventory_add_confirmed(dialog: AcceptDialog) -> void:
	var picker_val: Variant = dialog.get_meta("picker")
	var picker: ResourcePicker = picker_val if picker_val is ResourcePicker else null
	if picker and picker.has_selection():
		var item_val: Resource = picker.get_selected_resource()
		var item: ItemData = item_val if item_val is ItemData else null
		if item:
			# Extract item_id from resource path (filename without extension)
			var item_id: String = item.resource_path.get_file().get_basename()
			if item_id not in _current_inventory_items:
				_current_inventory_items.append(item_id)
				_refresh_inventory_list_display()
				_mark_dirty()

	dialog.queue_free()


## Handle removing an item from the inventory list
func _on_inventory_remove_item(item_id: String) -> void:
	_current_inventory_items.erase(item_id)
	_refresh_inventory_list_display()
	_mark_dirty()


## Refresh the visual display of the inventory item list
func _refresh_inventory_list_display() -> void:
	# Clear existing items
	for child: Node in inventory_list_container.get_children():
		child.queue_free()

	if _current_inventory_items.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "(No items)"
		empty_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
		inventory_list_container.add_child(empty_label)
		return

	# Create a row for each item
	for item_id: String in _current_inventory_items:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		# Try to get item display name from registry
		var display_name: String = item_id
		var item: ItemData = null
		if ModLoader and ModLoader.registry:
			item = ModLoader.registry.get_item(item_id)
			if item:
				display_name = item.item_name if not item.item_name.is_empty() else item_id

		# Item icon (if available)
		if item and item.icon:
			var icon_rect: TextureRect = TextureRect.new()
			icon_rect.texture = item.icon
			icon_rect.custom_minimum_size = Vector2(24, 24)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(icon_rect)

		# Item name label
		var name_label: Label = Label.new()
		name_label.text = display_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if item:
			# Add item type to tooltip
			var type_name: String = ItemData.ItemType.keys()[item.item_type]
			name_label.tooltip_text = "%s (%s)" % [item_id, type_name]
		else:
			name_label.tooltip_text = item_id
			name_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))  # Orange for missing
		row.add_child(name_label)

		# Remove button
		var remove_btn: Button = Button.new()
		remove_btn.text = "x"
		remove_btn.tooltip_text = "Remove from inventory"
		remove_btn.custom_minimum_size.x = 24
		remove_btn.pressed.connect(_on_inventory_remove_item.bind(item_id))
		row.add_child(remove_btn)

		inventory_list_container.add_child(row)


# =============================================================================
# APPEARANCE SECTION METHODS
# =============================================================================

## Load appearance assets from CharacterData into the pickers
func _load_appearance_from_character(character: CharacterData) -> void:
	# Portrait
	if character.portrait:
		_portrait_picker.set_texture_path(character.portrait.resource_path)
	else:
		_portrait_picker.clear()

	# Sprite Frames (consolidated: used for both map and battle grid)
	if character.sprite_frames:
		# Try to load from the SpriteFrames resource
		# The MapSpritesheetPicker needs the source spritesheet path
		# We can try to reconstruct it from the SpriteFrames if it was saved with metadata
		_load_sprite_frames_from_character(character.sprite_frames)
	else:
		_sprite_frames_picker.clear()


## Try to load sprite frames information from an existing SpriteFrames resource
func _load_sprite_frames_from_character(sprite_frames: SpriteFrames) -> void:
	# Clear picker first
	_sprite_frames_picker.clear()

	if not sprite_frames:
		return

	# Get the SpriteFrames path (may be empty if saved as SubResource)
	var frames_path: String = sprite_frames.resource_path

	# Try to extract the source spritesheet path from one of the animations
	# The atlas texture's atlas property should point to the original spritesheet
	var spritesheet_path: String = ""

	for anim_name: String in sprite_frames.get_animation_names():
		if sprite_frames.get_frame_count(anim_name) > 0:
			var frame_texture: Texture2D = sprite_frames.get_frame_texture(anim_name, 0)
			if frame_texture is AtlasTexture:
				var atlas: AtlasTexture = frame_texture as AtlasTexture
				if atlas.atlas:
					spritesheet_path = atlas.atlas.resource_path
					break

	# If we found the source spritesheet, load it into the picker
	if not spritesheet_path.is_empty():
		_sprite_frames_picker.set_sprite_frames_path(spritesheet_path, frames_path)
		# Also store the existing SpriteFrames so it's preserved on save
		_sprite_frames_picker.set_existing_sprite_frames(sprite_frames)


## Save appearance assets from pickers to CharacterData
func _save_appearance_to_character(character: CharacterData) -> void:
	# Portrait
	character.portrait = _portrait_picker.get_texture()

	# Sprite Frames (consolidated: used for both map and battle grid)
	# IMPORTANT: SpriteFrames must have a valid resource_path to be saved as ExtResource.
	# If no path, Godot embeds it as SubResource (duplicating data in character file).
	if _sprite_frames_picker.has_generated_sprite_frames():
		var sprite_frames: SpriteFrames = _sprite_frames_picker.get_generated_sprite_frames()
		# Ensure sprite_frames is saved to disk (not embedded as SubResource)
		if sprite_frames and sprite_frames.resource_path.is_empty():
			var output_path: String = _generate_sprite_frames_path(character)
			if _sprite_frames_picker.generate_sprite_frames(output_path):
				# Use in-memory reference (avoids Godot resource cache returning stale data)
				sprite_frames = _sprite_frames_picker.get_generated_sprite_frames()
		character.sprite_frames = sprite_frames
	elif _sprite_frames_picker.is_valid() and _sprite_frames_picker.get_texture() != null:
		# Valid spritesheet selected but no SpriteFrames generated yet
		# Auto-generate SpriteFrames when saving
		var output_path: String = _generate_sprite_frames_path(character)
		if _sprite_frames_picker.generate_sprite_frames(output_path):
			# Use in-memory reference (avoids Godot resource cache returning stale data)
			character.sprite_frames = _sprite_frames_picker.get_generated_sprite_frames()
	else:
		# No valid spritesheet - clear the sprite_frames if picker is empty
		if _sprite_frames_picker.get_texture_path().is_empty():
			character.sprite_frames = null


## Generate an appropriate output path for SpriteFrames based on character resource path
func _generate_sprite_frames_path(character: CharacterData) -> String:
	# Get the character's resource path to determine the mod
	var char_path: String = character.resource_path
	if char_path.is_empty():
		# New unsaved character - use active mod
		var active_mod: ModManifest = ModLoader.get_active_mod() if ModLoader else null
		if active_mod:
			return "res://mods/%s/data/sprite_frames/character_sprite_frames.tres" % active_mod.mod_id
		return "res://mods/_sandbox/data/sprite_frames/character_sprite_frames.tres"

	# Extract mod name from character path (e.g., res://mods/_sandbox/data/characters/hero.tres)
	var path_parts: PackedStringArray = char_path.split("/")
	var mod_name: String = "_sandbox"
	for i: int in range(path_parts.size()):
		if path_parts[i] == "mods" and i + 1 < path_parts.size():
			mod_name = path_parts[i + 1]
			break

	# Generate a unique name based on the character filename
	var char_filename: String = char_path.get_file().get_basename()
	return "res://mods/%s/data/sprite_frames/%s_map_sprites.tres" % [mod_name, char_filename]


# =============================================================================
# APPEARANCE SIGNAL HANDLERS
# =============================================================================

func _on_portrait_selected(_path: String, _texture: Texture2D) -> void:
	_mark_dirty()


func _on_portrait_cleared() -> void:
	_mark_dirty()


func _on_spritesheet_selected(_path: String, _texture: Texture2D) -> void:
	_mark_dirty()


func _on_spritesheet_cleared() -> void:
	_mark_dirty()


func _on_sprite_frames_generated(sprite_frames: SpriteFrames) -> void:
	_mark_dirty()
	if sprite_frames:
		_show_success_message("SpriteFrames generated successfully")


# =============================================================================
# AI THREAT CONFIGURATION METHODS
# =============================================================================

## Load AI threat configuration from CharacterData into the UI
func _load_ai_threat_configuration(character: CharacterData) -> void:
	# Load threat modifier (with fallback for characters without the field)
	var threat_modifier: float = 1.0
	if "ai_threat_modifier" in character:
		threat_modifier = character.ai_threat_modifier
	ai_threat_modifier_slider.value = threat_modifier
	ai_threat_modifier_value_label.text = "%.1f" % threat_modifier

	# Load threat tags (with fallback for characters without the field)
	_current_threat_tags.clear()
	if "ai_threat_tags" in character:
		for tag: String in character.ai_threat_tags:
			_current_threat_tags.append(tag)

	_refresh_threat_tags_display()


## Save AI threat configuration from UI to CharacterData
func _save_ai_threat_configuration(character: CharacterData) -> void:
	# Save threat modifier
	if "ai_threat_modifier" in character:
		character.ai_threat_modifier = ai_threat_modifier_slider.value

	# Save threat tags
	if "ai_threat_tags" in character:
		var new_tags: Array[String] = []
		for tag: String in _current_threat_tags:
			new_tags.append(tag)
		character.ai_threat_tags = new_tags


# =============================================================================
# UNIQUE ABILITIES SECTION
# =============================================================================

## Add the unique abilities section with an ability list and add button
func _add_unique_abilities_section() -> void:
	unique_abilities_section = CollapseSection.new()
	unique_abilities_section.title = "Unique Abilities"
	unique_abilities_section.start_collapsed = true

	var help_label: Label = Label.new()
	help_label.text = "Character-specific abilities that bypass class restrictions"
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	unique_abilities_section.add_content_child(help_label)

	# Container for the list of unique abilities
	unique_abilities_container = VBoxContainer.new()
	unique_abilities_container.add_theme_constant_override("separation", 4)
	unique_abilities_section.add_content_child(unique_abilities_container)

	# Add Unique Ability button
	var button_container: HBoxContainer = HBoxContainer.new()
	unique_abilities_add_button = Button.new()
	unique_abilities_add_button.text = "+ Add Unique Ability"
	unique_abilities_add_button.tooltip_text = "Add a character-specific ability that bypasses class restrictions"
	unique_abilities_add_button.pressed.connect(_on_add_unique_ability)
	button_container.add_child(unique_abilities_add_button)
	unique_abilities_section.add_content_child(button_container)

	detail_panel.add_child(unique_abilities_section)


## Load unique abilities from CharacterData into the list
func _load_unique_abilities(character: CharacterData) -> void:
	_current_unique_abilities.clear()

	if character and not character.unique_abilities.is_empty():
		for ability: AbilityData in character.unique_abilities:
			if ability:
				_current_unique_abilities.append({"ability": ability})

	_refresh_unique_abilities_display()


## Save unique abilities from list to CharacterData
func _save_unique_abilities(character: CharacterData) -> void:
	var new_unique_abilities: Array[AbilityData] = []
	for ability_dict: Dictionary in _current_unique_abilities:
		var ability: AbilityData = ability_dict.get("ability", null) as AbilityData
		if ability:
			new_unique_abilities.append(ability)
	character.unique_abilities = new_unique_abilities


## Handle Add Unique Ability button press - opens a ResourcePicker dialog
func _on_add_unique_ability() -> void:
	# Create a popup dialog with a ResourcePicker
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Add Unique Ability"
	dialog.min_size = Vector2(400, 100)

	var picker: ResourcePicker = ResourcePicker.new()
	picker.resource_type = "ability"
	picker.label_text = "Ability:"
	picker.label_min_width = 60
	picker.allow_none = false

	dialog.add_child(picker)

	# Store reference for the confirmation callback
	dialog.set_meta("picker", picker)

	dialog.confirmed.connect(_on_add_unique_ability_confirmed.bind(dialog))
	dialog.canceled.connect(dialog.queue_free)

	# Add to editor and show
	EditorInterface.popup_dialog_centered(dialog)


## Handle confirmation of adding a unique ability
func _on_add_unique_ability_confirmed(dialog: AcceptDialog) -> void:
	var picker: ResourcePicker = dialog.get_meta("picker") as ResourcePicker
	if not picker:
		dialog.queue_free()
		return

	var ability: AbilityData = picker.get_selected_resource() as AbilityData
	dialog.queue_free()

	if not ability:
		return

	# Check if already added
	for existing_dict: Dictionary in _current_unique_abilities:
		var existing_ability: AbilityData = existing_dict.get("ability", null) as AbilityData
		if existing_ability and existing_ability.ability_id == ability.ability_id:
			_show_error_message("Ability already added")
			return

	# Add the ability
	_current_unique_abilities.append({"ability": ability})
	_refresh_unique_abilities_display()
	_mark_dirty()


## Remove a unique ability from the list
func _on_remove_unique_ability(ability_dict: Dictionary) -> void:
	_current_unique_abilities.erase(ability_dict)
	_refresh_unique_abilities_display()
	_mark_dirty()


## Refresh the display of unique abilities
func _refresh_unique_abilities_display() -> void:
	# Clear existing rows
	for child: Node in unique_abilities_container.get_children():
		child.queue_free()

	if _current_unique_abilities.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "(No unique abilities)"
		empty_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
		unique_abilities_container.add_child(empty_label)
		return

	# Create a row for each ability
	for ability_dict: Dictionary in _current_unique_abilities:
		var ability: AbilityData = ability_dict.get("ability", null) as AbilityData
		if not ability:
			continue

		var row: HBoxContainer = HBoxContainer.new()

		# Ability name
		var name_label: Label = Label.new()
		name_label.text = ability.display_name if ability.display_name else ability.ability_id.capitalize()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.tooltip_text = ability.ability_id
		row.add_child(name_label)

		# Remove button
		var remove_btn: Button = Button.new()
		remove_btn.text = "x"
		remove_btn.tooltip_text = "Remove unique ability"
		remove_btn.custom_minimum_size.x = 24
		remove_btn.pressed.connect(_on_remove_unique_ability.bind(ability_dict))
		row.add_child(remove_btn)

		unique_abilities_container.add_child(row)
