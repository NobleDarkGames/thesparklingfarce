@tool
extends Control

## Mod.json Editor
## Visual editor for mod manifest files (mod.json)
## Supports all mod.json capabilities including total conversion features
##
## Unlike resource editors, this edits JSON files directly rather than .tres resources

# UI Components - Main layout
var mod_list: ItemList
var detail_scroll: ScrollContainer
var detail_panel: VBoxContainer
var save_button: Button

# Current state
var current_mod_path: String = ""
var current_mod_data: Dictionary = {}
var is_dirty: bool = false

# Guard to prevent false dirty state during UI population
var _updating_ui: bool = false

# Error panel
var error_panel: PanelContainer
var error_label: RichTextLabel

# Basic Info section
var id_edit: LineEdit
var name_edit: LineEdit
var version_edit: LineEdit
var author_edit: LineEdit
var description_edit: TextEdit
var godot_version_edit: LineEdit

# Load Priority section
var priority_spin: SpinBox
var priority_range_label: Label

# Dependencies section
var dependencies_container: VBoxContainer
var dependencies_list: ItemList
var add_dependency_button: Button
var remove_dependency_button: Button
var dependency_input: LineEdit

# Custom Types section
var weapon_types_edit: TextEdit
var unit_categories_edit: TextEdit
var trigger_types_edit: TextEdit
var animation_offset_types_edit: TextEdit

# Equipment Slot Layout section
var equipment_slots_container: VBoxContainer
var equipment_slots_list: ItemList
var add_slot_button: Button
var remove_slot_button: Button
var slot_id_edit: LineEdit
var slot_display_name_edit: LineEdit
var slot_accepts_types_edit: LineEdit

# Inventory Config section
var slots_per_character_spin: SpinBox
var allow_duplicates_check: CheckBox

# Party Config section
var replaces_lower_priority_check: CheckBox

# Total Conversion Mode section
var total_conversion_section: VBoxContainer
var total_conversion_check: CheckBox

# Scene Overrides section
var scene_overrides_container: VBoxContainer
var scene_overrides_list: ItemList
var add_scene_override_button: Button
var remove_scene_override_button: Button
var scene_id_edit: LineEdit
var scene_path_edit: LineEdit

# Content Paths section
var data_path_edit: LineEdit
var assets_path_edit: LineEdit

# Field Menu Options section
var field_menu_options_list: ItemList
var field_menu_option_id_edit: LineEdit
var field_menu_option_label_edit: LineEdit
var field_menu_option_scene_path_edit: LineEdit
var field_menu_option_position_dropdown: OptionButton
var field_menu_replace_all_check: CheckBox
var add_field_menu_option_button: Button
var remove_field_menu_option_button: Button

# Position options for field menu
const FIELD_MENU_POSITIONS: Array[String] = [
	"end",
	"start",
	"after_item",
	"after_magic",
	"after_search",
	"after_member"
]

# Reserved option IDs that mods cannot override
const RESERVED_FIELD_MENU_IDS: Array[String] = [
	"item",
	"magic",
	"search",
	"member"
]


func _init() -> void:
	call_deferred("_setup_ui")


func _ready() -> void:
	pass


func _setup_ui() -> void:
	# Root Control uses layout_mode = 1 with anchors in .tscn for proper TabContainer containment
	var hsplit: HSplitContainer = HSplitContainer.new()
	hsplit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hsplit.split_offset = 200
	add_child(hsplit)

	# Left side: Mod list
	var left_panel: VBoxContainer = VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var list_label: Label = Label.new()
	list_label.text = "Available Mods"
	list_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	left_panel.add_child(list_label)

	var help_label: Label = Label.new()
	help_label.text = "Select a mod to edit its settings"
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	left_panel.add_child(help_label)

	mod_list = ItemList.new()
	mod_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mod_list.custom_minimum_size = Vector2(0, 150)
	mod_list.item_selected.connect(_on_mod_selected)
	left_panel.add_child(mod_list)

	var refresh_button: Button = Button.new()
	refresh_button.text = "Refresh Mod List"
	refresh_button.pressed.connect(_refresh_mod_list)
	left_panel.add_child(refresh_button)

	hsplit.add_child(left_panel)

	# Right side: Detail panel in scroll container
	detail_scroll = ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.custom_minimum_size = Vector2(500, 0)
	# Ensure vertical scrolling works properly
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	detail_scroll.follow_focus = true

	detail_panel = VBoxContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_constant_override("separation", 8)

	var detail_label: Label = Label.new()
	detail_label.text = "Mod Settings"
	detail_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	detail_panel.add_child(detail_label)

	# Create all form sections
	_create_basic_info_section()
	_create_load_priority_section()
	_create_total_conversion_section()
	_create_dependencies_section()
	_create_custom_types_section()
	_create_equipment_slots_section()
	_create_inventory_config_section()
	_create_party_config_section()
	_create_scene_overrides_section()
	_create_field_menu_options_section()
	_create_content_paths_section()

	# Error panel (hidden by default)
	_create_error_panel()

	# Save button (with separator for visual clarity)
	var button_separator: HSeparator = HSeparator.new()
	detail_panel.add_child(button_separator)

	var button_container: HBoxContainer = HBoxContainer.new()
	save_button = Button.new()
	save_button.text = "Save mod.json"
	save_button.pressed.connect(_on_save)
	button_container.add_child(save_button)
	detail_panel.add_child(button_container)

	detail_scroll.add_child(detail_panel)
	hsplit.add_child(detail_scroll)

	# Initial refresh
	_refresh_mod_list()


func _create_basic_info_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Basic Information")

	# ID (read-only after creation)
	id_edit = form.add_text_field("Mod ID:", "", "Unique identifier (cannot be changed after creation)")
	id_edit.editable = false

	# Name
	name_edit = form.add_text_field("Name:", "", "Display name for the mod")

	# Version
	version_edit = form.add_text_field("Version:", "", "Semantic version (e.g., 1.0.0)")

	# Author
	author_edit = form.add_text_field("Author:", "", "Mod author name")

	# Godot Version
	godot_version_edit = form.add_text_field("Godot Version:", "", "Compatible Godot version (e.g., 4.5)")

	# Description
	description_edit = form.add_text_area("Description:", 60, "Describe what this mod provides...")

	form.add_separator()


func _create_load_priority_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.add_section("Load Priority")
	form.add_help_text("Higher priority mods override lower priority content with matching IDs")

	# Priority field with dynamic range label - need custom row
	var priority_container: HBoxContainer = HBoxContainer.new()
	priority_container.add_theme_constant_override("separation", 8)

	priority_spin = SpinBox.new()
	priority_spin.min_value = 0
	priority_spin.max_value = 9999
	priority_spin.value = 100
	priority_spin.value_changed.connect(_on_priority_changed)
	priority_container.add_child(priority_spin)

	priority_range_label = Label.new()
	priority_range_label.text = "(User mod)"
	priority_range_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	priority_container.add_child(priority_range_label)

	form.add_labeled_control("Priority:", priority_container)

	# Range explanation
	form.add_help_text("0-99: Official content | 100-8999: User mods | 9000-9999: Total conversions")

	form.add_separator()


func _create_total_conversion_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.add_section("Total Conversion Mode")

	# Store section container for external reference (if needed)
	total_conversion_section = form.container as VBoxContainer

	total_conversion_check = CheckBox.new()
	total_conversion_check.text = "Enable Total Conversion Mode"
	total_conversion_check.tooltip_text = "When enabled, this mod completely replaces the base game.\n" + \
		"- Sets load_priority to 9000 (overrides all other mods)\n" + \
		"- Enables 'replaces_default_party' (uses your party instead of base game)"
	total_conversion_check.toggled.connect(_on_total_conversion_toggled)
	form.container.add_child(total_conversion_check)

	form.add_help_text("Total conversions create entirely new games using the platform.\nThey override or replace all base game content.")

	form.add_separator()


func _create_dependencies_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Dependencies"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_text: Label = Label.new()
	help_text.text = "Other mods that must be loaded before this one"
	help_text.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_text.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(help_text)

	dependencies_container = VBoxContainer.new()

	dependencies_list = ItemList.new()
	dependencies_list.custom_minimum_size = Vector2(0, 80)
	dependencies_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dependencies_container.add_child(dependencies_list)

	var input_row: HBoxContainer = HBoxContainer.new()

	dependency_input = LineEdit.new()
	dependency_input.placeholder_text = "Enter mod ID..."
	dependency_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_row.add_child(dependency_input)

	add_dependency_button = Button.new()
	add_dependency_button.text = "Add"
	add_dependency_button.pressed.connect(_on_add_dependency)
	input_row.add_child(add_dependency_button)

	remove_dependency_button = Button.new()
	remove_dependency_button.text = "Remove Selected"
	remove_dependency_button.pressed.connect(_on_remove_dependency)
	input_row.add_child(remove_dependency_button)

	dependencies_container.add_child(input_row)
	section.add_child(dependencies_container)

	detail_panel.add_child(section)
	SparklingEditorUtils.add_separator(detail_panel)


func _create_custom_types_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Custom Types")
	form.add_help_text("Register new enum-like values (one per line)")

	weapon_types_edit = form.add_text_area("Weapon Types:", 40, "e.g., laser, plasma, energy_blade")
	unit_categories_edit = form.add_text_area("Unit Categories:", 40, "e.g., mech, cyborg, undead")
	trigger_types_edit = form.add_text_area("Trigger Types:", 40, "e.g., puzzle, teleporter, shop")
	animation_offset_types_edit = form.add_text_area("Animation Offsets:", 40, "Custom sprite positioning")

	form.add_separator()


func _create_equipment_slots_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Equipment Slot Layout"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_text: Label = Label.new()
	help_text.text = "Define custom equipment slots (for total conversions)"
	help_text.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_text.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(help_text)

	equipment_slots_container = VBoxContainer.new()

	equipment_slots_list = ItemList.new()
	equipment_slots_list.custom_minimum_size = Vector2(0, 100)
	equipment_slots_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_slots_list.item_selected.connect(_on_equipment_slot_selected)
	equipment_slots_container.add_child(equipment_slots_list)

	# Slot editing fields
	var slot_edit_container: VBoxContainer = VBoxContainer.new()

	var id_row: HBoxContainer = HBoxContainer.new()
	var id_label: Label = Label.new()
	id_label.text = "Slot ID:"
	id_label.custom_minimum_size.x = 120
	id_row.add_child(id_label)
	slot_id_edit = LineEdit.new()
	slot_id_edit.placeholder_text = "e.g., weapon, ring_1, ring_2"
	slot_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_row.add_child(slot_id_edit)
	slot_edit_container.add_child(id_row)

	var name_row: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = "Display Name:"
	name_label.custom_minimum_size.x = 120
	name_row.add_child(name_label)
	slot_display_name_edit = LineEdit.new()
	slot_display_name_edit.placeholder_text = "e.g., Weapon, Ring 1, Ring 2"
	slot_display_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(slot_display_name_edit)
	slot_edit_container.add_child(name_row)

	var accepts_row: HBoxContainer = HBoxContainer.new()
	var accepts_label: Label = Label.new()
	accepts_label.text = "Accepts Types:"
	accepts_label.custom_minimum_size.x = 120
	accepts_row.add_child(accepts_label)
	slot_accepts_types_edit = LineEdit.new()
	slot_accepts_types_edit.placeholder_text = "e.g., sword, axe, bow (comma-separated)"
	slot_accepts_types_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accepts_row.add_child(slot_accepts_types_edit)
	slot_edit_container.add_child(accepts_row)

	equipment_slots_container.add_child(slot_edit_container)

	# Buttons
	var button_row: HBoxContainer = HBoxContainer.new()

	add_slot_button = Button.new()
	add_slot_button.text = "Add Slot"
	add_slot_button.pressed.connect(_on_add_equipment_slot)
	button_row.add_child(add_slot_button)

	remove_slot_button = Button.new()
	remove_slot_button.text = "Remove Selected"
	remove_slot_button.pressed.connect(_on_remove_equipment_slot)
	button_row.add_child(remove_slot_button)

	var update_slot_button: Button = Button.new()
	update_slot_button.text = "Update Selected"
	update_slot_button.pressed.connect(_on_update_equipment_slot)
	button_row.add_child(update_slot_button)

	equipment_slots_container.add_child(button_row)
	section.add_child(equipment_slots_container)

	detail_panel.add_child(section)
	SparklingEditorUtils.add_separator(detail_panel)


func _create_inventory_config_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Inventory Configuration")

	slots_per_character_spin = form.add_number_field("Slots per Character:", 1, 99, 4,
		"Number of inventory slots each character has")

	allow_duplicates_check = form.add_standalone_checkbox("Allow duplicate items in inventory", true,
		"When enabled, characters can carry multiple copies of the same item")

	form.add_separator()


func _create_party_config_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Party Configuration")

	replaces_lower_priority_check = form.add_standalone_checkbox("Replaces lower priority party members", false,
		"When enabled, party members from lower-priority mods will be ignored")

	# Custom warning label (uses orange color for emphasis)
	var warning_label: Label = Label.new()
	warning_label.text = "Warning: When enabled, party members from lower-priority mods will be ignored.\nUse this for total conversions that provide their own starting party."
	warning_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	warning_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.container.add_child(warning_label)

	form.add_separator()


func _create_scene_overrides_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Scene Overrides"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_text: Label = Label.new()
	help_text.text = "Replace engine scenes with custom versions (for total conversions)"
	help_text.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_text.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(help_text)

	scene_overrides_container = VBoxContainer.new()

	scene_overrides_list = ItemList.new()
	scene_overrides_list.custom_minimum_size = Vector2(0, 80)
	scene_overrides_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene_overrides_list.item_selected.connect(_on_scene_override_selected)
	scene_overrides_container.add_child(scene_overrides_list)

	# Scene override input fields
	var input_container: VBoxContainer = VBoxContainer.new()

	var id_row: HBoxContainer = HBoxContainer.new()
	var id_label: Label = Label.new()
	id_label.text = "Scene ID:"
	id_label.custom_minimum_size.x = 100
	id_row.add_child(id_label)
	scene_id_edit = LineEdit.new()
	scene_id_edit.placeholder_text = "e.g., main_menu, battle_scene"
	scene_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_row.add_child(scene_id_edit)
	input_container.add_child(id_row)

	var path_row: HBoxContainer = HBoxContainer.new()
	var path_label: Label = Label.new()
	path_label.text = "Scene Path:"
	path_label.custom_minimum_size.x = 100
	path_row.add_child(path_label)
	scene_path_edit = LineEdit.new()
	scene_path_edit.placeholder_text = "Relative path (e.g., scenes/custom_menu.tscn)"
	scene_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_row.add_child(scene_path_edit)
	input_container.add_child(path_row)

	scene_overrides_container.add_child(input_container)

	# Buttons
	var button_row: HBoxContainer = HBoxContainer.new()

	add_scene_override_button = Button.new()
	add_scene_override_button.text = "Add Override"
	add_scene_override_button.pressed.connect(_on_add_scene_override)
	button_row.add_child(add_scene_override_button)

	remove_scene_override_button = Button.new()
	remove_scene_override_button.text = "Remove Selected"
	remove_scene_override_button.pressed.connect(_on_remove_scene_override)
	button_row.add_child(remove_scene_override_button)

	scene_overrides_container.add_child(button_row)
	section.add_child(scene_overrides_container)

	detail_panel.add_child(section)
	SparklingEditorUtils.add_separator(detail_panel)


func _create_field_menu_options_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Field Menu Options"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_text: Label = Label.new()
	help_text.text = "Add custom options to the exploration field menu (e.g., Bestiary, Quest Log)"
	help_text.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_text.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	help_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(help_text)

	# Replace all checkbox (for total conversions)
	field_menu_replace_all_check = CheckBox.new()
	field_menu_replace_all_check.text = "Replace all base options (total conversion)"
	field_menu_replace_all_check.tooltip_text = "When enabled, removes base Item/Magic/Search/Member options.\nUse this only for total conversions that provide their own field menu."
	field_menu_replace_all_check.toggled.connect(_on_field_menu_replace_all_toggled)
	section.add_child(field_menu_replace_all_check)

	# Options list
	field_menu_options_list = ItemList.new()
	field_menu_options_list.custom_minimum_size = Vector2(0, 80)
	field_menu_options_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_menu_options_list.item_selected.connect(_on_field_menu_option_selected)
	section.add_child(field_menu_options_list)

	# Input fields container
	var input_container: VBoxContainer = VBoxContainer.new()

	# Option ID
	var id_row: HBoxContainer = HBoxContainer.new()
	var id_label: Label = Label.new()
	id_label.text = "Option ID:"
	id_label.custom_minimum_size.x = 100
	id_row.add_child(id_label)
	field_menu_option_id_edit = LineEdit.new()
	field_menu_option_id_edit.placeholder_text = "e.g., bestiary, quest_log"
	field_menu_option_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_menu_option_id_edit.tooltip_text = "Unique identifier for this option (lowercase, underscores)"
	id_row.add_child(field_menu_option_id_edit)
	input_container.add_child(id_row)

	# Label
	var label_row: HBoxContainer = HBoxContainer.new()
	var label_label: Label = Label.new()
	label_label.text = "Label:"
	label_label.custom_minimum_size.x = 100
	label_row.add_child(label_label)
	field_menu_option_label_edit = LineEdit.new()
	field_menu_option_label_edit.placeholder_text = "e.g., Bestiary, Quests"
	field_menu_option_label_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_menu_option_label_edit.tooltip_text = "Display text shown in the menu"
	label_row.add_child(field_menu_option_label_edit)
	input_container.add_child(label_row)

	# Scene Path with browse button
	var path_row: HBoxContainer = HBoxContainer.new()
	var path_label: Label = Label.new()
	path_label.text = "Scene Path:"
	path_label.custom_minimum_size.x = 100
	path_row.add_child(path_label)
	field_menu_option_scene_path_edit = LineEdit.new()
	field_menu_option_scene_path_edit.placeholder_text = "scenes/ui/my_panel.tscn"
	field_menu_option_scene_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_menu_option_scene_path_edit.tooltip_text = "Relative path to the scene file (from mod folder)"
	path_row.add_child(field_menu_option_scene_path_edit)
	input_container.add_child(path_row)

	# Position dropdown
	var position_row: HBoxContainer = HBoxContainer.new()
	var position_label: Label = Label.new()
	position_label.text = "Position:"
	position_label.custom_minimum_size.x = 100
	position_row.add_child(position_label)
	field_menu_option_position_dropdown = OptionButton.new()
	field_menu_option_position_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_menu_option_position_dropdown.tooltip_text = "Where to insert this option in the menu"
	# Populate position options with display-friendly labels
	field_menu_option_position_dropdown.add_item("End (after Member)", 0)
	field_menu_option_position_dropdown.add_item("Start (before Item)", 1)
	field_menu_option_position_dropdown.add_item("After Item", 2)
	field_menu_option_position_dropdown.add_item("After Magic", 3)
	field_menu_option_position_dropdown.add_item("After Search", 4)
	field_menu_option_position_dropdown.add_item("After Member", 5)
	position_row.add_child(field_menu_option_position_dropdown)
	input_container.add_child(position_row)

	section.add_child(input_container)

	# Buttons
	var button_row: HBoxContainer = HBoxContainer.new()

	add_field_menu_option_button = Button.new()
	add_field_menu_option_button.text = "Add Option"
	add_field_menu_option_button.pressed.connect(_on_add_field_menu_option)
	button_row.add_child(add_field_menu_option_button)

	remove_field_menu_option_button = Button.new()
	remove_field_menu_option_button.text = "Remove Selected"
	remove_field_menu_option_button.pressed.connect(_on_remove_field_menu_option)
	button_row.add_child(remove_field_menu_option_button)

	var update_button: Button = Button.new()
	update_button.text = "Update Selected"
	update_button.pressed.connect(_on_update_field_menu_option)
	button_row.add_child(update_button)

	section.add_child(button_row)

	detail_panel.add_child(section)
	SparklingEditorUtils.add_separator(detail_panel)


func _create_content_paths_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Content Paths")
	form.add_help_text("Relative paths within the mod folder")

	data_path_edit = form.add_text_field("Data Path:", "data/",
		"Resource files (default: data/)")

	assets_path_edit = form.add_text_field("Assets Path:", "assets/",
		"Art and audio (default: assets/)")


func _create_error_panel() -> void:
	error_panel = PanelContainer.new()
	error_panel.visible = false

	var error_style: StyleBoxFlat = StyleBoxFlat.new()
	error_style.bg_color = Color(0.6, 0.15, 0.15, 0.95)
	error_style.border_width_left = 3
	error_style.border_width_right = 3
	error_style.border_width_top = 3
	error_style.border_width_bottom = 3
	error_style.border_color = Color(0.9, 0.3, 0.3, 1.0)
	error_style.corner_radius_top_left = 4
	error_style.corner_radius_top_right = 4
	error_style.corner_radius_bottom_left = 4
	error_style.corner_radius_bottom_right = 4
	error_style.content_margin_left = 8
	error_style.content_margin_right = 8
	error_style.content_margin_top = 6
	error_style.content_margin_bottom = 6
	error_panel.add_theme_stylebox_override("panel", error_style)

	error_label = RichTextLabel.new()
	error_label.bbcode_enabled = true
	error_label.fit_content = true
	error_label.custom_minimum_size = Vector2(0, 40)
	error_label.scroll_active = false
	error_panel.add_child(error_label)

	detail_panel.add_child(error_panel)


## Public refresh method for standard editor interface
func refresh() -> void:
	_refresh_mod_list()


## Refresh the list of available mods
func _refresh_mod_list() -> void:
	mod_list.clear()

	var mods_dir: DirAccess = DirAccess.open("res://mods/")
	if not mods_dir:
		push_error("Cannot open mods directory")
		return

	mods_dir.list_dir_begin()
	var folder_name: String = mods_dir.get_next()

	while folder_name != "":
		if mods_dir.current_is_dir() and not folder_name.begins_with("."):
			var mod_json_path: String = "res://mods/%s/mod.json" % folder_name
			if FileAccess.file_exists(mod_json_path):
				# Load mod name from JSON
				var json_text: String = FileAccess.get_file_as_string(mod_json_path)
				var json_data: Variant = JSON.parse_string(json_text)
				if json_data is Dictionary:
					var json_dict: Dictionary = json_data
					var display_name: String = DictUtils.get_string(json_dict, "name", folder_name)
					mod_list.add_item(display_name)
					mod_list.set_item_metadata(mod_list.item_count - 1, mod_json_path)
		folder_name = mods_dir.get_next()

	mods_dir.list_dir_end()


## Called when a mod is selected from the list
func _on_mod_selected(index: int) -> void:
	var path: String = mod_list.get_item_metadata(index)
	_load_mod_json(path)


## Load mod.json file and populate UI
func _load_mod_json(path: String) -> void:
	current_mod_path = path

	var json_text: String = FileAccess.get_file_as_string(path)
	if json_text.is_empty():
		_show_errors(["Failed to read mod.json file"])
		return

	var json_data: Variant = JSON.parse_string(json_text)
	if not json_data is Dictionary:
		_show_errors(["Invalid JSON format in mod.json"])
		return

	current_mod_data = json_data
	_populate_ui_from_data()
	_hide_errors()
	is_dirty = false


## Populate all UI fields from current_mod_data
func _populate_ui_from_data() -> void:
	_updating_ui = true

	# Basic info
	id_edit.text = current_mod_data.get("id", "")
	name_edit.text = current_mod_data.get("name", "")
	version_edit.text = current_mod_data.get("version", "1.0.0")
	author_edit.text = current_mod_data.get("author", "")
	description_edit.text = current_mod_data.get("description", "")
	godot_version_edit.text = current_mod_data.get("godot_version", "4.5")

	# Load priority
	priority_spin.value = current_mod_data.get("load_priority", 100)
	_on_priority_changed(priority_spin.value)

	# Total conversion mode (check if priority >= 9000)
	var is_total_conversion: bool = priority_spin.value >= 9000
	total_conversion_check.set_pressed_no_signal(is_total_conversion)

	# Dependencies
	dependencies_list.clear()
	var deps: Array = current_mod_data.get("dependencies", [])
	for dep: Variant in deps:
		dependencies_list.add_item(str(dep))

	# Custom types
	var custom_types: Dictionary = current_mod_data.get("custom_types", {})
	weapon_types_edit.text = _array_to_lines(custom_types.get("weapon_types", []))
	unit_categories_edit.text = _array_to_lines(custom_types.get("unit_categories", []))
	trigger_types_edit.text = _array_to_lines(custom_types.get("trigger_types", []))
	animation_offset_types_edit.text = _array_to_lines(custom_types.get("animation_offset_types", []))

	# Equipment slot layout
	equipment_slots_list.clear()
	var slots: Array = current_mod_data.get("equipment_slot_layout", [])
	for slot: Variant in slots:
		if slot is Dictionary:
			var slot_dict: Dictionary = slot
			var slot_id: String = DictUtils.get_string(slot_dict, "id", "")
			var slot_name: String = DictUtils.get_string(slot_dict, "display_name", slot_id)
			equipment_slots_list.add_item("%s (%s)" % [slot_name, slot_id])
			equipment_slots_list.set_item_metadata(equipment_slots_list.item_count - 1, slot_dict)

	# Inventory config
	var inv_config: Dictionary = current_mod_data.get("inventory_config", {})
	slots_per_character_spin.value = inv_config.get("slots_per_character", 4)
	allow_duplicates_check.button_pressed = inv_config.get("allow_duplicates", true)

	# Party config
	var party_config: Dictionary = current_mod_data.get("party_config", {})
	replaces_lower_priority_check.button_pressed = party_config.get("replaces_lower_priority", false)

	# Scene overrides
	scene_overrides_list.clear()
	var scenes: Dictionary = current_mod_data.get("scenes", {})
	for scene_id: String in scenes:
		var scene_path: String = scenes[scene_id]
		scene_overrides_list.add_item("%s -> %s" % [scene_id, scene_path])
		scene_overrides_list.set_item_metadata(scene_overrides_list.item_count - 1, {
			"id": scene_id,
			"path": scene_path
		})

	# Content paths
	var content: Dictionary = current_mod_data.get("content", {})
	data_path_edit.text = content.get("data_path", "data/")
	assets_path_edit.text = content.get("assets_path", "assets/")

	# Field menu options
	field_menu_options_list.clear()
	var field_menu_opts: Dictionary = current_mod_data.get("field_menu_options", {})
	field_menu_replace_all_check.set_pressed_no_signal(field_menu_opts.get("_replace_all", false))
	for option_id: String in field_menu_opts.keys():
		if option_id.begins_with("_"):
			continue  # Skip meta keys like _replace_all
		var opt_data: Variant = field_menu_opts[option_id]
		if opt_data is Dictionary:
			var opt_dict: Dictionary = opt_data
			var label_text: String = DictUtils.get_string(opt_dict, "label", option_id)
			var position_text: String = DictUtils.get_string(opt_dict, "position", "end")
			field_menu_options_list.add_item("%s (%s) [%s]" % [label_text, option_id, position_text])
			field_menu_options_list.set_item_metadata(field_menu_options_list.item_count - 1, {
				"id": option_id,
				"label": label_text,
				"scene_path": opt_dict.get("scene_path", ""),
				"position": position_text
			})

	_updating_ui = false


## Collect all UI data into current_mod_data
func _collect_data_from_ui() -> void:
	# Basic info
	current_mod_data["id"] = id_edit.text
	current_mod_data["name"] = name_edit.text
	current_mod_data["version"] = version_edit.text
	current_mod_data["author"] = author_edit.text
	current_mod_data["description"] = description_edit.text
	current_mod_data["godot_version"] = godot_version_edit.text

	# Load priority
	current_mod_data["load_priority"] = int(priority_spin.value)

	# Dependencies
	var deps: Array = []
	for i: int in range(dependencies_list.item_count):
		deps.append(dependencies_list.get_item_text(i))
	current_mod_data["dependencies"] = deps

	# Custom types (only include non-empty)
	var custom_types: Dictionary = {}
	var weapon_types: Array = _lines_to_array(weapon_types_edit.text)
	var unit_categories: Array = _lines_to_array(unit_categories_edit.text)
	var trigger_types: Array = _lines_to_array(trigger_types_edit.text)
	var animation_offsets: Array = _lines_to_array(animation_offset_types_edit.text)

	if weapon_types.size() > 0:
		custom_types["weapon_types"] = weapon_types
	if unit_categories.size() > 0:
		custom_types["unit_categories"] = unit_categories
	if trigger_types.size() > 0:
		custom_types["trigger_types"] = trigger_types
	if animation_offsets.size() > 0:
		custom_types["animation_offset_types"] = animation_offsets

	if custom_types.size() > 0:
		current_mod_data["custom_types"] = custom_types
	elif "custom_types" in current_mod_data:
		current_mod_data.erase("custom_types")

	# Equipment slot layout
	var slots: Array = []
	for i: int in range(equipment_slots_list.item_count):
		var slot_data: Variant = equipment_slots_list.get_item_metadata(i)
		if slot_data is Dictionary:
			slots.append(slot_data as Dictionary)
	if slots.size() > 0:
		current_mod_data["equipment_slot_layout"] = slots
	elif "equipment_slot_layout" in current_mod_data:
		current_mod_data.erase("equipment_slot_layout")

	# Inventory config
	var inv_config: Dictionary = {
		"slots_per_character": int(slots_per_character_spin.value),
		"allow_duplicates": allow_duplicates_check.button_pressed
	}
	current_mod_data["inventory_config"] = inv_config

	# Party config (only include if non-default)
	if replaces_lower_priority_check.button_pressed:
		current_mod_data["party_config"] = {
			"replaces_lower_priority": true
		}
	elif "party_config" in current_mod_data:
		current_mod_data.erase("party_config")

	# Scene overrides
	var scenes: Dictionary = {}
	for i: int in range(scene_overrides_list.item_count):
		var override_data: Variant = scene_overrides_list.get_item_metadata(i)
		if override_data is Dictionary:
			var override_dict: Dictionary = override_data as Dictionary
			scenes[override_dict.get("id", "")] = override_dict.get("path", "")
	if scenes.size() > 0:
		current_mod_data["scenes"] = scenes
	elif "scenes" in current_mod_data:
		current_mod_data.erase("scenes")

	# Content paths
	current_mod_data["content"] = {
		"data_path": data_path_edit.text,
		"assets_path": assets_path_edit.text
	}

	# Field menu options
	var field_menu_opts: Dictionary = {}
	if field_menu_replace_all_check.button_pressed:
		field_menu_opts["_replace_all"] = true
	for i: int in range(field_menu_options_list.item_count):
		var opt_data: Variant = field_menu_options_list.get_item_metadata(i)
		if opt_data is Dictionary:
			var opt_dict: Dictionary = opt_data as Dictionary
			var option_id: String = DictUtils.get_string(opt_dict, "id", "")
			if not option_id.is_empty():
				field_menu_opts[option_id] = {
					"label": DictUtils.get_string(opt_dict, "label", option_id),
					"scene_path": DictUtils.get_string(opt_dict, "scene_path", ""),
					"position": DictUtils.get_string(opt_dict, "position", "end")
				}
	if field_menu_opts.size() > 0:
		current_mod_data["field_menu_options"] = field_menu_opts
	elif "field_menu_options" in current_mod_data:
		current_mod_data.erase("field_menu_options")


## Save current mod data to JSON file
func _on_save() -> void:
	if current_mod_path.is_empty():
		_show_errors(["No mod selected"])
		return

	# Validate
	var errors: Array[String] = _validate_mod_data()
	if errors.size() > 0:
		_show_errors(errors)
		return

	# Collect data from UI
	_collect_data_from_ui()

	# Write to file
	var json_text: String = JSON.stringify(current_mod_data, "\t")
	var file: FileAccess = FileAccess.open(current_mod_path, FileAccess.WRITE)
	if not file:
		_show_errors(["Failed to open file for writing: " + current_mod_path])
		return

	file.store_string(json_text)
	file.close()

	_hide_errors()
	is_dirty = false

	# Refresh mod list to show updated name if changed
	_refresh_mod_list()

	# Notify via EditorEventBus if available
	var event_bus: Node = get_node_or_null("/root/EditorEventBus")
	if event_bus:
		event_bus.mods_reloaded.emit()


## Validate mod data before saving
func _validate_mod_data() -> Array[String]:
	var errors: Array[String] = []

	if name_edit.text.strip_edges().is_empty():
		errors.append("Mod name cannot be empty")

	if version_edit.text.strip_edges().is_empty():
		errors.append("Version cannot be empty")

	return errors


## Convert array to newline-separated text
func _array_to_lines(arr: Array) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for item: Variant in arr:
		lines.append(str(item))
	return "\n".join(lines)


## Convert newline-separated text to array
func _lines_to_array(text: String) -> Array:
	var arr: Array = []
	var lines: PackedStringArray = text.split("\n")
	for line: String in lines:
		var trimmed: String = line.strip_edges()
		if not trimmed.is_empty():
			arr.append(trimmed)
	return arr


## Update priority range label based on current value
func _on_priority_changed(value: float) -> void:
	var priority: int = int(value)
	if priority < 100:
		priority_range_label.text = "(Official content)"
		priority_range_label.add_theme_color_override("font_color", Color(0.3, 0.6, 0.9))
	elif priority < 9000:
		priority_range_label.text = "(User mod)"
		priority_range_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	else:
		priority_range_label.text = "(Total conversion)"
		priority_range_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))


## Add a dependency to the list
func _on_add_dependency() -> void:
	var dep_id: String = dependency_input.text.strip_edges()
	if dep_id.is_empty():
		return

	# Check for duplicates
	for i: int in range(dependencies_list.item_count):
		if dependencies_list.get_item_text(i) == dep_id:
			return

	dependencies_list.add_item(dep_id)
	dependency_input.text = ""
	is_dirty = true


## Remove selected dependency
func _on_remove_dependency() -> void:
	var selected: PackedInt32Array = dependencies_list.get_selected_items()
	if selected.size() > 0:
		dependencies_list.remove_item(selected[0])
		is_dirty = true


## Add a new equipment slot
func _on_add_equipment_slot() -> void:
	var slot_id: String = slot_id_edit.text.strip_edges()
	if slot_id.is_empty():
		_show_errors(["Slot ID cannot be empty"])
		return

	var slot_data: Dictionary = {
		"id": slot_id,
		"display_name": slot_display_name_edit.text.strip_edges(),
		"accepts_types": _parse_comma_list(slot_accepts_types_edit.text)
	}

	equipment_slots_list.add_item("%s (%s)" % [slot_data["display_name"], slot_id])
	equipment_slots_list.set_item_metadata(equipment_slots_list.item_count - 1, slot_data)

	# Clear inputs
	slot_id_edit.text = ""
	slot_display_name_edit.text = ""
	slot_accepts_types_edit.text = ""
	is_dirty = true
	_hide_errors()


## Remove selected equipment slot
func _on_remove_equipment_slot() -> void:
	var selected: PackedInt32Array = equipment_slots_list.get_selected_items()
	if selected.size() > 0:
		equipment_slots_list.remove_item(selected[0])
		is_dirty = true


## Update selected equipment slot with current field values
func _on_update_equipment_slot() -> void:
	var selected: PackedInt32Array = equipment_slots_list.get_selected_items()
	if selected.size() == 0:
		_show_errors(["No slot selected"])
		return

	var slot_id: String = slot_id_edit.text.strip_edges()
	if slot_id.is_empty():
		_show_errors(["Slot ID cannot be empty"])
		return

	var slot_data: Dictionary = {
		"id": slot_id,
		"display_name": slot_display_name_edit.text.strip_edges(),
		"accepts_types": _parse_comma_list(slot_accepts_types_edit.text)
	}

	var index: int = selected[0]
	equipment_slots_list.set_item_text(index, "%s (%s)" % [slot_data["display_name"], slot_id])
	equipment_slots_list.set_item_metadata(index, slot_data)
	is_dirty = true
	_hide_errors()


## Load selected slot data into edit fields
func _on_equipment_slot_selected(index: int) -> void:
	var slot_data: Variant = equipment_slots_list.get_item_metadata(index)
	if slot_data is Dictionary:
		var slot_dict: Dictionary = slot_data as Dictionary
		slot_id_edit.text = slot_dict.get("id", "")
		slot_display_name_edit.text = slot_dict.get("display_name", "")
		var accepts: Array = slot_dict.get("accepts_types", [])
		slot_accepts_types_edit.text = ", ".join(accepts)


## Add a scene override
func _on_add_scene_override() -> void:
	var scene_id: String = scene_id_edit.text.strip_edges()
	var scene_path: String = scene_path_edit.text.strip_edges()

	if scene_id.is_empty():
		_show_errors(["Scene ID cannot be empty"])
		return

	if scene_path.is_empty():
		_show_errors(["Scene path cannot be empty"])
		return

	# Check for duplicate IDs
	for i: int in range(scene_overrides_list.item_count):
		var existing: Variant = scene_overrides_list.get_item_metadata(i)
		if existing is Dictionary:
			var existing_dict: Dictionary = existing as Dictionary
			if existing_dict.get("id", "") == scene_id:
				_show_errors(["Scene ID '%s' already exists" % scene_id])
				return

	var override_data: Dictionary = {
		"id": scene_id,
		"path": scene_path
	}

	scene_overrides_list.add_item("%s -> %s" % [scene_id, scene_path])
	scene_overrides_list.set_item_metadata(scene_overrides_list.item_count - 1, override_data)

	scene_id_edit.text = ""
	scene_path_edit.text = ""
	is_dirty = true
	_hide_errors()


## Remove selected scene override
func _on_remove_scene_override() -> void:
	var selected: PackedInt32Array = scene_overrides_list.get_selected_items()
	if selected.size() > 0:
		scene_overrides_list.remove_item(selected[0])
		is_dirty = true


## Load selected scene override into edit fields
func _on_scene_override_selected(index: int) -> void:
	var override_data: Variant = scene_overrides_list.get_item_metadata(index)
	if override_data is Dictionary:
		var override_dict: Dictionary = override_data as Dictionary
		scene_id_edit.text = override_dict.get("id", "")
		scene_path_edit.text = override_dict.get("path", "")


# =============================================================================
# Field Menu Options Handlers
# =============================================================================

## Add a field menu option
func _on_add_field_menu_option() -> void:
	var option_id: String = field_menu_option_id_edit.text.strip_edges().to_lower()
	var option_label: String = field_menu_option_label_edit.text.strip_edges()
	var scene_path: String = field_menu_option_scene_path_edit.text.strip_edges()
	var position_index: int = field_menu_option_position_dropdown.selected
	var position: String = FIELD_MENU_POSITIONS[position_index] if position_index >= 0 else "end"

	# Validation
	if option_id.is_empty():
		_show_errors(["Option ID cannot be empty"])
		return

	if option_label.is_empty():
		_show_errors(["Label cannot be empty"])
		return

	if scene_path.is_empty():
		_show_errors(["Scene path cannot be empty"])
		return

	# Check for reserved IDs
	if option_id in RESERVED_FIELD_MENU_IDS:
		_show_errors(["'%s' is a reserved option ID. Base options cannot be overridden.\nReserved IDs: %s" % [option_id, ", ".join(RESERVED_FIELD_MENU_IDS)]])
		return

	# Check for duplicate IDs
	for i: int in range(field_menu_options_list.item_count):
		var existing: Variant = field_menu_options_list.get_item_metadata(i)
		if existing is Dictionary:
			var existing_dict: Dictionary = existing as Dictionary
			if existing_dict.get("id", "") == option_id:
				_show_errors(["Option ID '%s' already exists" % option_id])
				return

	# Validate scene path exists (warning, not blocking)
	var mod_dir: String = current_mod_path.get_base_dir()
	var full_scene_path: String = mod_dir.path_join(scene_path)
	if not FileAccess.file_exists(full_scene_path) and not ResourceLoader.exists(full_scene_path):
		# Show warning but allow adding
		push_warning("Field menu option scene not found: %s" % full_scene_path)

	var opt_data: Dictionary = {
		"id": option_id,
		"label": option_label,
		"scene_path": scene_path,
		"position": position
	}

	field_menu_options_list.add_item("%s (%s) [%s]" % [option_label, option_id, position])
	field_menu_options_list.set_item_metadata(field_menu_options_list.item_count - 1, opt_data)

	# Clear inputs
	field_menu_option_id_edit.text = ""
	field_menu_option_label_edit.text = ""
	field_menu_option_scene_path_edit.text = ""
	field_menu_option_position_dropdown.select(0)  # Reset to "end"
	is_dirty = true
	_hide_errors()


## Remove selected field menu option
func _on_remove_field_menu_option() -> void:
	var selected: PackedInt32Array = field_menu_options_list.get_selected_items()
	if selected.size() > 0:
		field_menu_options_list.remove_item(selected[0])
		is_dirty = true


## Update selected field menu option with current field values
func _on_update_field_menu_option() -> void:
	var selected: PackedInt32Array = field_menu_options_list.get_selected_items()
	if selected.size() == 0:
		_show_errors(["No option selected"])
		return

	var option_id: String = field_menu_option_id_edit.text.strip_edges().to_lower()
	var option_label: String = field_menu_option_label_edit.text.strip_edges()
	var scene_path: String = field_menu_option_scene_path_edit.text.strip_edges()
	var position_index: int = field_menu_option_position_dropdown.selected
	var position: String = FIELD_MENU_POSITIONS[position_index] if position_index >= 0 else "end"

	# Validation
	if option_id.is_empty():
		_show_errors(["Option ID cannot be empty"])
		return

	if option_label.is_empty():
		_show_errors(["Label cannot be empty"])
		return

	if scene_path.is_empty():
		_show_errors(["Scene path cannot be empty"])
		return

	# Check for reserved IDs
	if option_id in RESERVED_FIELD_MENU_IDS:
		_show_errors(["'%s' is a reserved option ID. Base options cannot be overridden.\nReserved IDs: %s" % [option_id, ", ".join(RESERVED_FIELD_MENU_IDS)]])
		return

	# Check for duplicate IDs (excluding the currently selected item)
	var selected_index: int = selected[0]
	for i: int in range(field_menu_options_list.item_count):
		if i == selected_index:
			continue
		var existing: Variant = field_menu_options_list.get_item_metadata(i)
		if existing is Dictionary:
			var existing_dict: Dictionary = existing as Dictionary
			if existing_dict.get("id", "") == option_id:
				_show_errors(["Option ID '%s' already exists" % option_id])
				return

	var opt_data: Dictionary = {
		"id": option_id,
		"label": option_label,
		"scene_path": scene_path,
		"position": position
	}

	field_menu_options_list.set_item_text(selected_index, "%s (%s) [%s]" % [option_label, option_id, position])
	field_menu_options_list.set_item_metadata(selected_index, opt_data)
	is_dirty = true
	_hide_errors()


## Load selected field menu option into edit fields
func _on_field_menu_option_selected(index: int) -> void:
	var opt_data: Variant = field_menu_options_list.get_item_metadata(index)
	if opt_data is Dictionary:
		var opt_dict: Dictionary = opt_data
		field_menu_option_id_edit.text = DictUtils.get_string(opt_dict, "id", "")
		field_menu_option_label_edit.text = DictUtils.get_string(opt_dict, "label", "")
		field_menu_option_scene_path_edit.text = DictUtils.get_string(opt_dict, "scene_path", "")

		# Set position dropdown
		var position: String = DictUtils.get_string(opt_dict, "position", "end")
		var position_index: int = FIELD_MENU_POSITIONS.find(position)
		if position_index >= 0:
			field_menu_option_position_dropdown.select(position_index)
		else:
			field_menu_option_position_dropdown.select(0)  # Default to "end"


## Called when replace all checkbox is toggled
func _on_field_menu_replace_all_toggled(_pressed: bool) -> void:
	is_dirty = true


## Parse comma-separated list into array
func _parse_comma_list(text: String) -> Array:
	var arr: Array = []
	var parts: PackedStringArray = text.split(",")
	for part: String in parts:
		var trimmed: String = part.strip_edges()
		if not trimmed.is_empty():
			arr.append(trimmed)
	return arr


## Show error messages
func _show_errors(errors: Array) -> void:
	var error_text: String = "[b]Error:[/b]\n"
	for error: Variant in errors:
		error_text += "* " + str(error) + "\n"
	error_label.text = error_text
	error_panel.show()

	# Brief pulse animation
	var tween: Tween = create_tween()
	tween.tween_property(error_panel, "modulate:a", 0.6, 0.15)
	tween.tween_property(error_panel, "modulate:a", 1.0, 0.15)


## Hide error panel
func _hide_errors() -> void:
	error_panel.hide()
	error_label.text = ""


# =============================================================================
# Total Conversion Mode Handlers
# =============================================================================

## Called when Total Conversion Mode checkbox is toggled
func _on_total_conversion_toggled(pressed: bool) -> void:
	if pressed:
		# Set total conversion priority
		priority_spin.value = 9000

		# Enable replaces_lower_priority
		replaces_lower_priority_check.button_pressed = true

		is_dirty = true
	else:
		# Reset to user mod priority
		if priority_spin.value >= 9000:
			priority_spin.value = 100


# =============================================================================
# Dirty Tracking
# =============================================================================

## Mark as dirty when LineEdit text changes (takes String parameter)
func _mark_dirty_on_text_change(_new_text: String) -> void:
	if _updating_ui:
		return
	is_dirty = true


## Mark as dirty when TextEdit text changes (no parameter)
func _mark_dirty() -> void:
	if _updating_ui:
		return
	is_dirty = true


