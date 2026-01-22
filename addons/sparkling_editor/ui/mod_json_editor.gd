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

# Equipment Slot Layout section - uses ListEditor component
var equipment_slots_editor: ListEditor

# Inventory Config section
var slots_per_character_spin: SpinBox
var allow_duplicates_check: CheckBox

# Party Config section
var replaces_lower_priority_check: CheckBox

# Total Conversion Mode section
var total_conversion_section: VBoxContainer
var total_conversion_check: CheckBox

# Scene Overrides section - uses ListEditor component
var scene_overrides_editor: ListEditor

# Content Paths section
var data_path_edit: LineEdit
var assets_path_edit: LineEdit

# Field Menu Options section - uses ListEditor component
var field_menu_options_editor: ListEditor
var field_menu_replace_all_check: CheckBox

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
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.add_section("Dependencies")
	form.add_help_text("Other mods that must be loaded before this one")

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
	form.container.add_child(dependencies_container)

	form.add_separator()


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
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel, 120)
	form.add_section("Equipment Slot Layout")
	form.add_help_text("Define custom equipment slots (for total conversions)")

	# Use ListEditor component for master-detail pattern
	equipment_slots_editor = ListEditor.new()
	equipment_slots_editor.add_button_text = "Add Slot"
	equipment_slots_editor.remove_button_text = "Remove"
	equipment_slots_editor.update_button_text = "Update"
	equipment_slots_editor.list_min_height = 100
	equipment_slots_editor.label_width = 120
	equipment_slots_editor.empty_selection_text = "Select a slot to edit or click Add"

	# Configure callbacks
	equipment_slots_editor.detail_builder = _build_equipment_slot_detail
	equipment_slots_editor.display_formatter = _format_equipment_slot_display
	equipment_slots_editor.data_factory = func() -> Dictionary:
		return {"id": "", "display_name": "", "accepts_types": []}
	equipment_slots_editor.data_extractor = _extract_equipment_slot_data

	# Connect dirty tracking
	equipment_slots_editor.data_changed.connect(_mark_dirty)

	form.container.add_child(equipment_slots_editor)
	form.add_separator()


## Build detail fields for equipment slot editor
func _build_equipment_slot_detail(form: SparklingEditorUtils.FormBuilder, data: Dictionary) -> Dictionary:
	var fields: Dictionary = {}

	fields["id"] = form.add_text_field("Slot ID:", "e.g., weapon, ring_1, ring_2",
		"Unique identifier for this equipment slot")
	fields["id"].text = DictUtils.get_string(data, "id", "")

	fields["display_name"] = form.add_text_field("Display Name:", "e.g., Weapon, Ring 1",
		"Human-readable name shown in equipment UI")
	fields["display_name"].text = DictUtils.get_string(data, "display_name", "")

	fields["accepts_types"] = form.add_text_field("Accepts Types:", "e.g., sword, axe, bow (comma-separated)",
		"Item types that can be equipped in this slot")
	var accepts: Array = data.get("accepts_types", [])
	fields["accepts_types"].text = ", ".join(accepts) if accepts else ""

	return fields


## Format equipment slot display text for list
func _format_equipment_slot_display(data: Dictionary, _index: int) -> String:
	var slot_id: String = DictUtils.get_string(data, "id", "")
	var display_name: String = DictUtils.get_string(data, "display_name", slot_id)
	if slot_id.is_empty():
		return "(New Slot)"
	return "%s (%s)" % [display_name, slot_id]


## Extract equipment slot data from detail fields
func _extract_equipment_slot_data(fields: Dictionary) -> Dictionary:
	return {
		"id": fields["id"].text.strip_edges(),
		"display_name": fields["display_name"].text.strip_edges(),
		"accepts_types": _parse_comma_list(fields["accepts_types"].text)
	}


## Build detail fields for scene override editor
func _build_scene_override_detail(form: SparklingEditorUtils.FormBuilder, data: Dictionary) -> Dictionary:
	var fields: Dictionary = {}

	fields["id"] = form.add_text_field("Scene ID:", "e.g., main_menu, battle_scene",
		"Unique identifier for the scene being overridden")
	fields["id"].text = DictUtils.get_string(data, "id", "")

	fields["path"] = form.add_text_field("Scene Path:", "Relative path (e.g., scenes/custom_menu.tscn)",
		"Path to your custom scene file relative to mod folder")
	fields["path"].text = DictUtils.get_string(data, "path", "")

	return fields


## Format scene override display text for list
func _format_scene_override_display(data: Dictionary, _index: int) -> String:
	var scene_id: String = DictUtils.get_string(data, "id", "")
	var scene_path: String = DictUtils.get_string(data, "path", "")
	if scene_id.is_empty():
		return "(New Override)"
	return "%s -> %s" % [scene_id, scene_path]


## Extract scene override data from detail fields
func _extract_scene_override_data(fields: Dictionary) -> Dictionary:
	return {
		"id": fields["id"].text.strip_edges(),
		"path": fields["path"].text.strip_edges()
	}


## Build detail fields for field menu option editor
func _build_field_menu_option_detail(form: SparklingEditorUtils.FormBuilder, data: Dictionary) -> Dictionary:
	var fields: Dictionary = {}

	fields["id"] = form.add_text_field("Option ID:", "e.g., bestiary, quest_log",
		"Unique identifier for this option (lowercase, underscores)")
	fields["id"].text = DictUtils.get_string(data, "id", "")

	fields["label"] = form.add_text_field("Label:", "e.g., Bestiary, Quests",
		"Display text shown in the menu")
	fields["label"].text = DictUtils.get_string(data, "label", "")

	fields["scene_path"] = form.add_text_field("Scene Path:", "scenes/ui/my_panel.tscn",
		"Relative path to the scene file (from mod folder)")
	fields["scene_path"].text = DictUtils.get_string(data, "scene_path", "")

	# Position dropdown
	fields["position"] = form.add_dropdown("Position:", [
		{"label": "End (after Member)", "id": 0},
		{"label": "Start (before Item)", "id": 1},
		{"label": "After Item", "id": 2},
		{"label": "After Magic", "id": 3},
		{"label": "After Search", "id": 4},
		{"label": "After Member", "id": 5},
	], "Where to insert this option in the menu")

	# Set position dropdown based on data
	var position: String = DictUtils.get_string(data, "position", "end")
	var position_index: int = FIELD_MENU_POSITIONS.find(position)
	if position_index >= 0:
		fields["position"].select(position_index)
	else:
		fields["position"].select(0)  # Default to "end"

	return fields


## Format field menu option display text for list
func _format_field_menu_option_display(data: Dictionary, _index: int) -> String:
	var option_id: String = DictUtils.get_string(data, "id", "")
	var option_label: String = DictUtils.get_string(data, "label", "")
	var position: String = DictUtils.get_string(data, "position", "end")
	if option_id.is_empty():
		return "(New Option)"
	return "%s (%s) [%s]" % [option_label, option_id, position]


## Extract field menu option data from detail fields
func _extract_field_menu_option_data(fields: Dictionary) -> Dictionary:
	var position_index: int = fields["position"].selected
	var position: String = FIELD_MENU_POSITIONS[position_index] if position_index >= 0 else "end"

	return {
		"id": fields["id"].text.strip_edges().to_lower(),
		"label": fields["label"].text.strip_edges(),
		"scene_path": fields["scene_path"].text.strip_edges(),
		"position": position
	}


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
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel, 100)
	form.add_section("Scene Overrides")
	form.add_help_text("Replace engine scenes with custom versions (for total conversions)")

	# Use ListEditor component for master-detail pattern
	scene_overrides_editor = ListEditor.new()
	scene_overrides_editor.add_button_text = "Add Override"
	scene_overrides_editor.remove_button_text = "Remove"
	scene_overrides_editor.update_button_text = "Update"
	scene_overrides_editor.list_min_height = 80
	scene_overrides_editor.label_width = 100
	scene_overrides_editor.empty_selection_text = "Select an override to edit or click Add"

	# Configure callbacks
	scene_overrides_editor.detail_builder = _build_scene_override_detail
	scene_overrides_editor.display_formatter = _format_scene_override_display
	scene_overrides_editor.data_factory = func() -> Dictionary:
		return {"id": "", "path": ""}
	scene_overrides_editor.data_extractor = _extract_scene_override_data

	# Connect dirty tracking
	scene_overrides_editor.data_changed.connect(_mark_dirty)

	form.container.add_child(scene_overrides_editor)
	form.add_separator()


func _create_field_menu_options_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel, 100)
	form.add_section("Field Menu Options")
	form.add_help_text("Add custom options to the exploration field menu (e.g., Bestiary, Quest Log)")

	field_menu_replace_all_check = form.add_standalone_checkbox(
		"Replace all base options (total conversion)", false,
		"When enabled, removes base Item/Magic/Search/Member options.\nUse this only for total conversions that provide their own field menu.")
	field_menu_replace_all_check.toggled.connect(_on_field_menu_replace_all_toggled)

	# Use ListEditor component for master-detail pattern
	field_menu_options_editor = ListEditor.new()
	field_menu_options_editor.add_button_text = "Add Option"
	field_menu_options_editor.remove_button_text = "Remove"
	field_menu_options_editor.update_button_text = "Update"
	field_menu_options_editor.list_min_height = 80
	field_menu_options_editor.label_width = 100
	field_menu_options_editor.empty_selection_text = "Select an option to edit or click Add"

	# Configure callbacks
	field_menu_options_editor.detail_builder = _build_field_menu_option_detail
	field_menu_options_editor.display_formatter = _format_field_menu_option_display
	field_menu_options_editor.data_factory = func() -> Dictionary:
		return {"id": "", "label": "", "scene_path": "", "position": "end"}
	field_menu_options_editor.data_extractor = _extract_field_menu_option_data

	# Connect dirty tracking
	field_menu_options_editor.data_changed.connect(_mark_dirty)

	form.container.add_child(field_menu_options_editor)
	form.add_separator()


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

	# Equipment slot layout - use ListEditor
	var slots: Array = current_mod_data.get("equipment_slot_layout", [])
	equipment_slots_editor.load_data(slots)

	# Inventory config
	var inv_config: Dictionary = current_mod_data.get("inventory_config", {})
	slots_per_character_spin.value = inv_config.get("slots_per_character", 4)
	allow_duplicates_check.button_pressed = inv_config.get("allow_duplicates", true)

	# Party config
	var party_config: Dictionary = current_mod_data.get("party_config", {})
	replaces_lower_priority_check.button_pressed = party_config.get("replaces_lower_priority", false)

	# Scene overrides - convert Dictionary to Array for ListEditor
	var scenes: Dictionary = current_mod_data.get("scenes", {})
	var scenes_array: Array = []
	for scene_id: String in scenes:
		scenes_array.append({"id": scene_id, "path": scenes[scene_id]})
	scene_overrides_editor.load_data(scenes_array)

	# Content paths
	var content: Dictionary = current_mod_data.get("content", {})
	data_path_edit.text = content.get("data_path", "data/")
	assets_path_edit.text = content.get("assets_path", "assets/")

	# Field menu options - convert Dictionary to Array for ListEditor
	var field_menu_opts: Dictionary = current_mod_data.get("field_menu_options", {})
	field_menu_replace_all_check.set_pressed_no_signal(field_menu_opts.get("_replace_all", false))
	var options_array: Array = []
	for option_id: String in field_menu_opts.keys():
		if option_id.begins_with("_"):
			continue  # Skip meta keys like _replace_all
		var opt_data: Variant = field_menu_opts[option_id]
		if opt_data is Dictionary:
			var opt_dict: Dictionary = opt_data
			options_array.append({
				"id": option_id,
				"label": DictUtils.get_string(opt_dict, "label", option_id),
				"scene_path": DictUtils.get_string(opt_dict, "scene_path", ""),
				"position": DictUtils.get_string(opt_dict, "position", "end")
			})
	field_menu_options_editor.load_data(options_array)

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

	# Equipment slot layout - collect from ListEditor
	var slots: Array[Dictionary] = equipment_slots_editor.get_all_data()
	# Filter out empty slots (no ID)
	var valid_slots: Array = []
	for slot: Dictionary in slots:
		if not DictUtils.get_string(slot, "id", "").is_empty():
			valid_slots.append(slot)
	if valid_slots.size() > 0:
		current_mod_data["equipment_slot_layout"] = valid_slots
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

	# Scene overrides - collect from ListEditor and convert to Dictionary
	var scenes_data: Array[Dictionary] = scene_overrides_editor.get_all_data()
	var scenes: Dictionary = {}
	for override: Dictionary in scenes_data:
		var scene_id: String = DictUtils.get_string(override, "id", "")
		if not scene_id.is_empty():
			scenes[scene_id] = DictUtils.get_string(override, "path", "")
	if scenes.size() > 0:
		current_mod_data["scenes"] = scenes
	elif "scenes" in current_mod_data:
		current_mod_data.erase("scenes")

	# Content paths
	current_mod_data["content"] = {
		"data_path": data_path_edit.text,
		"assets_path": assets_path_edit.text
	}

	# Field menu options - collect from ListEditor and convert to Dictionary
	var options_data: Array[Dictionary] = field_menu_options_editor.get_all_data()
	var field_menu_opts: Dictionary = {}
	if field_menu_replace_all_check.button_pressed:
		field_menu_opts["_replace_all"] = true
	for option: Dictionary in options_data:
		var option_id: String = DictUtils.get_string(option, "id", "")
		if not option_id.is_empty():
			field_menu_opts[option_id] = {
				"label": DictUtils.get_string(option, "label", option_id),
				"scene_path": DictUtils.get_string(option, "scene_path", ""),
				"position": DictUtils.get_string(option, "position", "end")
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

## Mark as dirty when any field changes (accepts optional parameter for signal compatibility)
func _mark_dirty(_value: Variant = null) -> void:
	if _updating_ui:
		return
	is_dirty = true


