@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Character Editor UI
## Allows browsing and editing CharacterData resources

var name_edit: LineEdit
var uid_edit: LineEdit
var uid_copy_btn: Button
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

var current_filter: String = "all"  # "all", "player", "enemy", "neutral"

# Filter buttons (will be created by _setup_filter_buttons)
var filter_buttons: Dictionary = {}  # {category: Button}

# Note: Uses _is_loading from base class to prevent signal feedback loops during UI updates


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


## Override: Handle dependency resource changes (class or ability saved/modified)
## This invalidates stale references when a class is edited and saved
func _on_dependencies_changed(changed_type: String) -> void:
	var character: CharacterData = current_resource as CharacterData
	if not character:
		return

	if changed_type == "class" and character.character_class:
		# Get the class path from the current (possibly stale) reference
		var class_path: String = character.character_class.resource_path
		if class_path.is_empty():
			return

		# Force reload the class from disk, replacing cached version
		var fresh_class: ClassData = ResourceLoader.load(
			class_path, "", ResourceLoader.CACHE_MODE_REPLACE
		) as ClassData
		if fresh_class:
			character.character_class = fresh_class
			# Update the picker to reflect the change
			if class_picker:
				class_picker.select_resource(fresh_class)

	elif changed_type == "ability":
		# Refresh unique abilities display in case ability names/properties changed
		_load_unique_abilities(character)


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
	uid_edit.text = character.character_uid
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

	# Set default AI behavior - search dropdown by metadata
	if character.default_ai_behavior:
		var found: bool = false
		for i: int in range(default_ai_option.item_count):
			var metadata: Variant = default_ai_option.get_item_metadata(i)
			if metadata is AIBehaviorData and metadata.resource_path == character.default_ai_behavior.resource_path:
				default_ai_option.select(i)
				found = true
				break
		if not found:
			default_ai_option.select(0)  # (None)
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

	# Update default AI behavior - get from dropdown metadata
	var ai_selected: int = default_ai_option.selected
	if ai_selected > 0:
		var metadata: Variant = default_ai_option.get_item_metadata(ai_selected)
		character.default_ai_behavior = metadata as AIBehaviorData
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
	var warnings: Array[String] = []

	# Validate UI state (not resource state) since validation runs before _save_resource_data()
	var char_name: String = name_edit.text.strip_edges() if name_edit else ""
	var level: int = int(level_spin.value) if level_spin else 1
	var selected_class: ClassData = class_picker.get_selected_resource() as ClassData if class_picker else null
	var unit_cat: String = category_option.get_item_text(category_option.selected) if category_option and category_option.selected >= 0 else "player"

	if char_name.is_empty():
		errors.append("Character name cannot be empty")

	if level < 1 or level > 99:
		errors.append("Starting level must be between 1 and 99")

	# Validate class selection - required for playable characters
	if selected_class == null:
		if unit_cat == "player":
			errors.append("Player characters must have a class assigned")
		else:
			warnings.append("No class assigned - character will have no abilities or stat growth")

	return {valid = errors.is_empty(), errors = errors, warnings = warnings}


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
	new_character.base_hp = 12
	new_character.base_mp = 8
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
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Basic Information")

	name_edit = form.add_text_field("Name:", "",
		"Display name shown in menus and dialogue. Can differ from resource filename.")
	name_edit.max_length = 64  # Reasonable limit for UI display

	# Character UID (read-only, for referencing in cinematics/dialogs) - needs custom layout
	var uid_row: HBoxContainer = HBoxContainer.new()
	uid_row.add_theme_constant_override("separation", 4)

	var uid_label: Label = Label.new()
	uid_label.text = "Character UID:"
	uid_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	uid_row.add_child(uid_label)

	uid_edit = LineEdit.new()
	uid_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	uid_edit.editable = false
	uid_edit.tooltip_text = "Unique ID for referencing this character in cinematics and dialogs.\nAuto-generated and immutable. Use this instead of name for stable references."
	uid_edit.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	uid_row.add_child(uid_edit)

	uid_copy_btn = Button.new()
	uid_copy_btn.text = "Copy"
	uid_copy_btn.tooltip_text = "Copy UID to clipboard"
	uid_copy_btn.custom_minimum_size.x = 50
	uid_copy_btn.pressed.connect(_on_uid_copy_pressed)
	uid_row.add_child(uid_copy_btn)

	form.container.add_child(uid_row)

	# Class - use ResourcePicker for cross-mod class selection
	class_picker = ResourcePicker.new()
	class_picker.resource_type = "class"
	class_picker.label_text = "Class:"
	class_picker.label_min_width = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	class_picker.allow_none = true
	class_picker.tooltip_text = "Determines stat growth, abilities, and equippable weapon types. E.g., Warrior, Mage, Archer."
	class_picker.resource_selected.connect(_on_field_changed)
	form.container.add_child(class_picker)

	level_spin = form.add_number_field("Starting Level:", 1, 99, 1,
		"Level when character joins the party. Higher = stronger starting stats. Typical: 1-5 for early game, 10-20 for late joiners.")

	bio_edit = form.add_text_area("Biography:", 120,
		"Background story and personality description. Shown in character status screens and recruitment scenes.")


func _add_appearance_section() -> void:
	var section: CollapseSection = CollapseSection.new()
	section.title = "Appearance"
	section.start_collapsed = false

	# Use FormBuilder within the collapse section content
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(section.get_content_container())
	form.on_change(_mark_dirty)
	form.add_help_text("Visual assets for this character")

	# Portrait Picker
	_portrait_picker = PortraitPicker.new()
	_portrait_picker.texture_selected.connect(_on_portrait_selected)
	_portrait_picker.texture_cleared.connect(_on_portrait_cleared)
	form.container.add_child(_portrait_picker)

	# Sprite Frames Picker (consolidated: used for both map and battle grid)
	_sprite_frames_picker = MapSpritesheetPicker.new()
	_sprite_frames_picker.texture_selected.connect(_on_spritesheet_selected)
	_sprite_frames_picker.texture_cleared.connect(_on_spritesheet_cleared)
	_sprite_frames_picker.sprite_frames_generated.connect(_on_sprite_frames_generated)
	form.container.add_child(_sprite_frames_picker)

	detail_panel.add_child(section)


func _add_battle_configuration_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Battle Configuration")

	# Unit Category - need to populate dynamically from registry
	category_option = OptionButton.new()
	category_option.tooltip_text = "Determines AI allegiance: player = controllable ally, enemy = hostile AI, boss = high-priority enemy, neutral = non-combatant."
	var categories: Array[String] = _get_unit_categories_from_registry()
	for i: int in range(categories.size()):
		category_option.add_item(categories[i], i)
	category_option.item_selected.connect(_on_field_changed)
	form.add_labeled_control("Unit Category:", category_option,
		"Determines AI allegiance: player = controllable ally, enemy = hostile AI, boss = high-priority enemy, neutral = non-combatant.")

	is_unique_check = form.add_checkbox("Is Unique:", "This is a unique character (not a reusable template)", true,
		"ON = named character that persists across battles (e.g., Max). OFF = generic template for spawning multiple copies (e.g., Goblin).")

	is_hero_check = form.add_checkbox("Is Hero:", "This is the primary Hero/protagonist (only one per party)", false,
		"The main protagonist. If this character dies, battle is lost. Only one hero per party. Enables special story triggers.")

	is_boss_check = form.add_checkbox("Is Boss:", "This is a boss enemy (allies will protect)", false,
		"Mark as a boss enemy. Defensive AI will prioritize protecting this unit, and threat calculations are boosted.")

	is_default_party_member_check = form.add_checkbox("Starting Party:", "Include in default starting party", false,
		"If ON, character joins the party at the start of a new game. Use for starting party members.")

	# Default AI Behavior - need to populate dynamically
	default_ai_option = OptionButton.new()
	default_ai_option.tooltip_text = "AI behavior when this character is an enemy. E.g., Aggressive rushes, Cautious stays back, Healer prioritizes allies."
	default_ai_option.item_selected.connect(_on_field_changed)
	form.add_labeled_control("Default AI:", default_ai_option,
		"AI behavior when this character is an enemy. E.g., Aggressive rushes, Cautious stays back, Healer prioritizes allies.")

	form.add_help_text("AI used when this character is an enemy (can override in Battle Editor)")

	# Load available AI behaviors after creating the dropdown
	_load_available_ai_behaviors()


func _add_ai_threat_configuration_section() -> void:
	ai_threat_section = CollapseSection.new()
	ai_threat_section.title = "AI Threat Configuration"
	ai_threat_section.start_collapsed = true

	var content: VBoxContainer = ai_threat_section.get_content_container()
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(content)
	form.on_change(_mark_dirty)
	form.add_help_text("Advanced settings for AI targeting behavior")

	# Threat Modifier with slider and preset buttons - needs custom layout
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
	content.add_child(modifier_container)

	form.add_separator()

	# Threat Tags section
	form.add_section_label("Threat Tags:")
	form.add_help_text("Click to add common tags, or type custom tags below")

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

	content.add_child(quick_tags_container)

	# Current tags display
	var current_tags_label: Label = Label.new()
	current_tags_label.text = "Active Tags:"
	content.add_child(current_tags_label)

	ai_threat_tags_container = HFlowContainer.new()
	ai_threat_tags_container.add_theme_constant_override("h_separation", 4)
	ai_threat_tags_container.add_theme_constant_override("v_separation", 4)
	content.add_child(ai_threat_tags_container)

	# Custom tag input
	ai_threat_custom_tag_edit = LineEdit.new()
	ai_threat_custom_tag_edit.placeholder_text = "e.g., flanker, glass_cannon"
	ai_threat_custom_tag_edit.tooltip_text = "Add custom tags for mod-specific AI behaviors. Use snake_case format."
	ai_threat_custom_tag_edit.text_submitted.connect(_on_custom_tag_submitted)

	var custom_tag_row: HBoxContainer = HBoxContainer.new()
	custom_tag_row.add_theme_constant_override("separation", 8)

	var custom_label: Label = Label.new()
	custom_label.text = "Custom Tag:"
	custom_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	custom_tag_row.add_child(custom_label)

	ai_threat_custom_tag_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_tag_row.add_child(ai_threat_custom_tag_edit)

	ai_threat_add_tag_button = Button.new()
	ai_threat_add_tag_button.text = "Add"
	ai_threat_add_tag_button.pressed.connect(_on_add_custom_tag_pressed)
	custom_tag_row.add_child(ai_threat_add_tag_button)

	content.add_child(custom_tag_row)

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
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Base Stats")

	hp_spin = form.add_number_field("HP:", 1, 999, 10,
		"Hit Points - how much damage the character can take before falling. Typical: 15-25 for mages, 25-40 for warriors.")
	mp_spin = form.add_number_field("MP:", 1, 999, 10,
		"Magic Points - resource for casting spells and abilities. Typical: 0 for melee, 15-30 for casters.")
	str_spin = form.add_number_field("Strength:", 1, 999, 10,
		"Physical attack power. Higher = more damage with weapons. Typical: 3-6 for casters, 6-10 for fighters.")
	def_spin = form.add_number_field("Defense:", 1, 999, 10,
		"Physical damage reduction. Higher = less damage taken from attacks. Typical: 3-5 for mages, 6-10 for tanks.")
	agi_spin = form.add_number_field("Agility:", 1, 999, 10,
		"Turn order and evasion. Higher = acts first, harder to hit. Also affects movement range.")
	int_spin = form.add_number_field("Intelligence:", 1, 999, 10,
		"Magic attack power and MP growth. Higher = stronger spells. Typical: 6-10 for mages, 2-4 for fighters.")
	luk_spin = form.add_number_field("Luck:", 1, 999, 10,
		"Critical hit chance and rare drop rates. Subtle but useful. Typical: 3-7 for most characters.")


func _load_available_ai_behaviors() -> void:
	default_ai_option.clear()
	default_ai_option.add_item("(None)", 0)

	# Query registry fresh each time - no local cache
	if ModLoader and ModLoader.registry:
		var behaviors: Array[Resource] = ModLoader.registry.get_all_resources("ai_behavior")
		var index: int = 0
		for resource: Resource in behaviors:
			var ai_behavior: AIBehaviorData = resource as AIBehaviorData
			if ai_behavior:
				var behavior_id: String = ai_behavior.behavior_id if not ai_behavior.behavior_id.is_empty() else ai_behavior.resource_path.get_file().get_basename()
				var display_name: String = ai_behavior.display_name if ai_behavior.display_name else behavior_id.capitalize()
				var label: String = SparklingEditorUtils.get_display_with_mod_by_id("ai_behavior", behavior_id, display_name)
				default_ai_option.add_item(label, index)
				default_ai_option.set_item_metadata(default_ai_option.item_count - 1, ai_behavior)
				index += 1


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

	var content: VBoxContainer = equipment_section.get_content_container()
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(content)
	form.on_change(_mark_dirty)
	form.add_help_text("Equipment the character starts with when recruited")

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
		picker.label_min_width = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
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
		warning.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
		warning.visible = false
		slot_container.add_child(warning)
		equipment_warning_labels[slot_id] = warning

		content.add_child(slot_container)

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
	# Check registry for category-based inference
	if ModLoader and ModLoader.equipment_type_registry:
		var category: String = ModLoader.equipment_type_registry.get_category(lower_type)
		if category == "weapon":
			return "weapon"
		elif category == "accessory":
			if lower_type == "ring":
				return "ring_1"
			return "accessory"
	# Fallback matching EquipmentTypeRegistry.init_defaults()
	match lower_type:
		"sword", "axe", "spear", "bow", "staff", "knife":
			return "weapon"
		"ring":
			return "ring_1"
		"accessory":
			return "accessory"
		_:
			return "weapon"


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

	var content: VBoxContainer = inventory_section.get_content_container()
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(content)
	form.on_change(_mark_dirty)
	form.add_help_text("Items the character carries (not equipped) when recruited")

	# Container for the list of inventory items
	inventory_list_container = VBoxContainer.new()
	inventory_list_container.add_theme_constant_override("separation", 4)
	content.add_child(inventory_list_container)

	# Add Item button
	var button_container: HBoxContainer = HBoxContainer.new()
	inventory_add_button = Button.new()
	inventory_add_button.text = "+ Add Item"
	inventory_add_button.tooltip_text = "Add an item to the character's starting inventory"
	inventory_add_button.pressed.connect(_on_inventory_add_pressed)
	button_container.add_child(inventory_add_button)
	content.add_child(button_container)

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
	_show_resource_picker_dialog("Add Inventory Item", "item", "Item:", _on_inventory_item_selected)


## Handle selection of an inventory item from the dialog
func _on_inventory_item_selected(resource: Resource) -> void:
	var item: ItemData = resource as ItemData
	if not item:
		return

	# Extract item_id from resource path (filename without extension)
	var item_id: String = item.resource_path.get_file().get_basename()
	if item_id not in _current_inventory_items:
		_current_inventory_items.append(item_id)
		_refresh_inventory_list_display()
		_mark_dirty()


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
	_sprite_frames_picker.load_from_sprite_frames(character.sprite_frames)


## Save appearance assets from pickers to CharacterData
func _save_appearance_to_character(character: CharacterData) -> void:
	# Portrait
	character.portrait = _portrait_picker.get_texture()

	# Sprite Frames (consolidated: used for both map and battle grid)
	var output_path: String = _generate_sprite_frames_path(character)
	character.sprite_frames = _sprite_frames_picker.get_or_generate_sprite_frames(output_path)


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
# SIGNAL HANDLERS
# =============================================================================

## Called when the UID copy button is pressed
func _on_uid_copy_pressed() -> void:
	DisplayServer.clipboard_set(uid_edit.text)
	# Brief visual feedback
	var original_text: String = uid_copy_btn.text
	uid_copy_btn.text = "Copied!"
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(uid_copy_btn):
		uid_copy_btn.text = original_text


## Appearance signal handlers - delegate to _mark_dirty via _on_field_changed
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

	var content: VBoxContainer = unique_abilities_section.get_content_container()
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(content)
	form.on_change(_mark_dirty)
	form.add_help_text("Character-specific abilities that bypass class restrictions")

	# Container for the list of unique abilities
	unique_abilities_container = VBoxContainer.new()
	unique_abilities_container.add_theme_constant_override("separation", 4)
	content.add_child(unique_abilities_container)

	# Add Unique Ability button
	var button_container: HBoxContainer = HBoxContainer.new()
	unique_abilities_add_button = Button.new()
	unique_abilities_add_button.text = "+ Add Unique Ability"
	unique_abilities_add_button.tooltip_text = "Add a character-specific ability that bypasses class restrictions"
	unique_abilities_add_button.pressed.connect(_on_add_unique_ability)
	button_container.add_child(unique_abilities_add_button)
	content.add_child(button_container)

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
	_show_resource_picker_dialog("Add Unique Ability", "ability", "Ability:", _on_unique_ability_selected)


## Handle selection of a unique ability from the dialog
func _on_unique_ability_selected(resource: Resource) -> void:
	var ability: AbilityData = resource as AbilityData
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
