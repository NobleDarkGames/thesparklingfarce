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

# Extracted sections (see components/sections/)
var _ai_threat_section: AIThreatConfigSection
var _equipment_section: StartingEquipmentSection
var _inventory_section: StartingInventorySection
var _unique_abilities_section: UniqueAbilitiesSection

# Stat editors
var hp_spin: SpinBox
var mp_spin: SpinBox
var str_spin: SpinBox
var def_spin: SpinBox
var agi_spin: SpinBox
var int_spin: SpinBox
var luk_spin: SpinBox

var current_filter: String = "all"  # "all", "player", "enemy", "neutral"

# Filter buttons (will be created by _setup_filter_buttons)
var filter_buttons: Dictionary = {}  # {category: Button}

# Note: Uses _updating_ui from base class to prevent signal feedback loops during UI updates


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
		if _unique_abilities_section:
			_unique_abilities_section.load_data()


## Override: Create the character-specific detail form
func _create_detail_form() -> void:
	# Basic info section
	_add_basic_info_section()

	# Appearance section (portraits, sprites)
	_add_appearance_section()

	# Battle configuration section
	_add_battle_configuration_section()

	# AI Threat Configuration section (extracted to component)
	_ai_threat_section = AIThreatConfigSection.new(_mark_dirty, _get_current_resource)
	_ai_threat_section.build_ui(detail_panel)

	# Stats section
	_add_stats_section()

	# Equipment section (extracted to component)
	_equipment_section = StartingEquipmentSection.new(_mark_dirty, _get_current_resource)
	_equipment_section.build_ui(detail_panel)

	# Starting Inventory section (extracted to component)
	_inventory_section = StartingInventorySection.new(_mark_dirty, _get_current_resource, _show_resource_picker_dialog)
	_inventory_section.build_ui(detail_panel)

	# Unique Abilities section (extracted to component)
	_unique_abilities_section = UniqueAbilitiesSection.new(_mark_dirty, _get_current_resource, _show_resource_picker_dialog, _show_error_message)
	_unique_abilities_section.build_ui(detail_panel)

	# Add the button container at the end (with separator for visual clarity)
	_add_button_container_to_detail_panel()


## Helper to get the current resource (used by extracted sections)
func _get_current_resource() -> Resource:
	return current_resource


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

	# Load appearance assets
	_load_appearance_from_character(character)

	# Load extracted sections
	if _ai_threat_section:
		_ai_threat_section.load_data()
	if _equipment_section:
		_equipment_section.load_data()
	if _inventory_section:
		_inventory_section.load_data()
	if _unique_abilities_section:
		_unique_abilities_section.load_data()


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

	# Update appearance assets from pickers
	_save_appearance_to_character(character)

	# Save extracted sections
	if _ai_threat_section:
		_ai_threat_section.save_data()
	if _equipment_section:
		_equipment_section.save_data()
	if _inventory_section:
		_inventory_section.save_data()
	if _unique_abilities_section:
		_unique_abilities_section.save_data()


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
	SparklingEditorUtils.populate_ai_behavior_dropdown(default_ai_option)


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


