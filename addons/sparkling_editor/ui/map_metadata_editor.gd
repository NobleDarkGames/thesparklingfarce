@tool
extends Control

## MapMetadata Editor
## Visual editor for map configuration files (*.json in mods/*/data/maps/)
## Supports all MapMetadata properties including spawn points, connections, and type defaults
##
## Unlike resource editors, this edits JSON files directly rather than .tres resources

# UI Components - Main layout
var map_list: ItemList
var detail_scroll: ScrollContainer
var detail_panel: VBoxContainer
var save_button: Button
var create_button: Button
var delete_button: Button

# Current state
var current_map_path: String = ""
var current_map_data: Dictionary = {}
var is_dirty: bool = false
var loaded_maps: Dictionary = {}  # map_id -> path for connection dropdowns

# Error panel
var error_panel: PanelContainer
var error_label: RichTextLabel

# Basic Properties section
var map_id_edit: LineEdit
var display_name_edit: LineEdit
var map_type_dropdown: OptionButton
var apply_defaults_button: Button

# Scene Reference section
var scene_path_edit: LineEdit
var scene_picker_button: Button

# Caravan Settings section
var caravan_accessible_check: CheckBox
var caravan_visible_check: CheckBox

# Camera Settings section
var camera_zoom_spin: SpinBox

# Audio Settings section
var music_id_edit: LineEdit
var ambient_id_edit: LineEdit

# Encounter Settings section
var random_encounters_check: CheckBox
var encounter_rate_spin: SpinBox
var save_anywhere_check: CheckBox

# Spawn Points section
var spawn_points_list: ItemList
var spawn_id_edit: LineEdit
var spawn_grid_x_spin: SpinBox
var spawn_grid_y_spin: SpinBox
var spawn_facing_dropdown: OptionButton
var spawn_is_default_check: CheckBox
var spawn_is_caravan_check: CheckBox
var add_spawn_button: Button
var remove_spawn_button: Button
var update_spawn_button: Button

# Connections section
var connections_list: ItemList
var connection_trigger_id_edit: LineEdit
var connection_target_map_dropdown: OptionButton
var connection_target_spawn_edit: LineEdit
var connection_transition_dropdown: OptionButton
var connection_requires_key_edit: LineEdit
var connection_one_way_check: CheckBox
var add_connection_button: Button
var remove_connection_button: Button
var update_connection_button: Button

# Edge Connections section
var edge_north_map_dropdown: OptionButton
var edge_north_spawn_edit: LineEdit
var edge_south_map_dropdown: OptionButton
var edge_south_spawn_edit: LineEdit
var edge_east_map_dropdown: OptionButton
var edge_east_spawn_edit: LineEdit
var edge_west_map_dropdown: OptionButton
var edge_west_spawn_edit: LineEdit

# Map type enum values (matching MapMetadata.MapType)
const MAP_TYPES: Array[String] = ["TOWN", "OVERWORLD", "DUNGEON", "BATTLE", "INTERIOR"]
const FACING_DIRECTIONS: Array[String] = ["down", "up", "left", "right"]
const TRANSITION_TYPES: Array[String] = ["fade", "instant", "scroll"]


func _init() -> void:
	call_deferred("_setup_ui")


func _ready() -> void:
	pass


func _setup_ui() -> void:
	# Use full anchors to fill available space
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = 0.0
	offset_bottom = 0.0

	var hsplit: HSplitContainer = HSplitContainer.new()
	hsplit.anchor_right = 1.0
	hsplit.anchor_bottom = 1.0
	hsplit.split_offset = 220
	add_child(hsplit)

	# Left side: Map list
	var left_panel: VBoxContainer = VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var list_label: Label = Label.new()
	list_label.text = "Map Metadata Files"
	list_label.add_theme_font_size_override("font_size", 16)
	left_panel.add_child(list_label)

	var help_label: Label = Label.new()
	help_label.text = "Select a map to edit its configuration"
	help_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	help_label.add_theme_font_size_override("font_size", 11)
	left_panel.add_child(help_label)

	map_list = ItemList.new()
	map_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_list.custom_minimum_size = Vector2(0, 150)
	map_list.item_selected.connect(_on_map_selected)
	left_panel.add_child(map_list)

	var button_row: HBoxContainer = HBoxContainer.new()

	create_button = Button.new()
	create_button.text = "New Map"
	create_button.pressed.connect(_on_create_map)
	button_row.add_child(create_button)

	var refresh_button: Button = Button.new()
	refresh_button.text = "Refresh"
	refresh_button.pressed.connect(_refresh_map_list)
	button_row.add_child(refresh_button)

	left_panel.add_child(button_row)

	hsplit.add_child(left_panel)

	# Right side: Detail panel in scroll container
	detail_scroll = ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.custom_minimum_size = Vector2(550, 0)

	detail_panel = VBoxContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var detail_label: Label = Label.new()
	detail_label.text = "Map Configuration"
	detail_label.add_theme_font_size_override("font_size", 18)
	detail_panel.add_child(detail_label)

	# Create all form sections
	_create_basic_properties_section()
	_create_scene_reference_section()
	_create_caravan_settings_section()
	_create_camera_settings_section()
	_create_audio_settings_section()
	_create_encounter_settings_section()
	_create_spawn_points_section()
	_create_connections_section()
	_create_edge_connections_section()

	# Error panel (hidden by default)
	_create_error_panel()

	# Action buttons
	var action_container: HBoxContainer = HBoxContainer.new()
	action_container.add_theme_constant_override("separation", 10)

	save_button = Button.new()
	save_button.text = "Save Map Metadata"
	save_button.pressed.connect(_on_save)
	action_container.add_child(save_button)

	delete_button = Button.new()
	delete_button.text = "Delete Map"
	delete_button.pressed.connect(_on_delete)
	action_container.add_child(delete_button)

	detail_panel.add_child(action_container)

	detail_scroll.add_child(detail_panel)
	hsplit.add_child(detail_scroll)

	# Initial refresh
	_refresh_map_list()


# =============================================================================
# Section Builders
# =============================================================================

func _create_basic_properties_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Basic Properties"
	section_label.add_theme_font_size_override("font_size", 14)
	section.add_child(section_label)

	# Map ID
	map_id_edit = _create_line_edit_field("Map ID:", section, "Unique identifier (e.g., mod_id:map_name)")

	# Display Name
	display_name_edit = _create_line_edit_field("Display Name:", section, "Human-readable name for UI")

	# Map Type
	var type_container: HBoxContainer = HBoxContainer.new()
	var type_label: Label = Label.new()
	type_label.text = "Map Type:"
	type_label.custom_minimum_size.x = 150
	type_container.add_child(type_label)

	map_type_dropdown = OptionButton.new()
	map_type_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for map_type in MAP_TYPES:
		map_type_dropdown.add_item(map_type)
	type_container.add_child(map_type_dropdown)

	apply_defaults_button = Button.new()
	apply_defaults_button.text = "Apply Type Defaults"
	apply_defaults_button.tooltip_text = "Auto-fill settings based on map type"
	apply_defaults_button.pressed.connect(_on_apply_type_defaults)
	type_container.add_child(apply_defaults_button)

	section.add_child(type_container)

	detail_panel.add_child(section)
	_add_separator()


func _create_scene_reference_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Scene Reference"
	section_label.add_theme_font_size_override("font_size", 14)
	section.add_child(section_label)

	var path_container: HBoxContainer = HBoxContainer.new()
	var path_label: Label = Label.new()
	path_label.text = "Scene Path:"
	path_label.custom_minimum_size.x = 150
	path_container.add_child(path_label)

	scene_path_edit = LineEdit.new()
	scene_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene_path_edit.placeholder_text = "res://mods/mod_id/maps/scene.tscn"
	path_container.add_child(scene_path_edit)

	scene_picker_button = Button.new()
	scene_picker_button.text = "Browse..."
	scene_picker_button.pressed.connect(_on_browse_scene)
	path_container.add_child(scene_picker_button)

	section.add_child(path_container)

	var validation_label: Label = Label.new()
	validation_label.text = "Scene must be a .tscn file in the mods directory"
	validation_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	validation_label.add_theme_font_size_override("font_size", 11)
	section.add_child(validation_label)

	detail_panel.add_child(section)
	_add_separator()


func _create_caravan_settings_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Caravan Settings"
	section_label.add_theme_font_size_override("font_size", 14)
	section.add_child(section_label)

	var help_text: Label = Label.new()
	help_text.text = "Controls mobile HQ visibility and interaction (SF2 feature)"
	help_text.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	help_text.add_theme_font_size_override("font_size", 11)
	section.add_child(help_text)

	caravan_accessible_check = CheckBox.new()
	caravan_accessible_check.text = "Caravan Accessible (can interact with Caravan on this map)"
	section.add_child(caravan_accessible_check)

	caravan_visible_check = CheckBox.new()
	caravan_visible_check.text = "Caravan Visible (Caravan sprite appears on map)"
	section.add_child(caravan_visible_check)

	detail_panel.add_child(section)
	_add_separator()


func _create_camera_settings_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Camera Settings"
	section_label.add_theme_font_size_override("font_size", 14)
	section.add_child(section_label)

	var zoom_container: HBoxContainer = HBoxContainer.new()
	var zoom_label: Label = Label.new()
	zoom_label.text = "Camera Zoom:"
	zoom_label.custom_minimum_size.x = 150
	zoom_container.add_child(zoom_label)

	camera_zoom_spin = SpinBox.new()
	camera_zoom_spin.min_value = 0.5
	camera_zoom_spin.max_value = 2.0
	camera_zoom_spin.step = 0.05
	camera_zoom_spin.value = 1.0
	zoom_container.add_child(camera_zoom_spin)

	var zoom_hint: Label = Label.new()
	zoom_hint.text = "(1.0 recommended for pixel-perfect rendering)"
	zoom_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	zoom_hint.add_theme_font_size_override("font_size", 11)
	zoom_container.add_child(zoom_hint)

	section.add_child(zoom_container)

	detail_panel.add_child(section)
	_add_separator()


func _create_audio_settings_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Audio Settings"
	section_label.add_theme_font_size_override("font_size", 14)
	section.add_child(section_label)

	music_id_edit = _create_line_edit_field("Music ID:", section, "Background music track ID")
	ambient_id_edit = _create_line_edit_field("Ambient ID:", section, "Ambient sound effect ID")

	detail_panel.add_child(section)
	_add_separator()


func _create_encounter_settings_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Encounter Settings"
	section_label.add_theme_font_size_override("font_size", 14)
	section.add_child(section_label)

	random_encounters_check = CheckBox.new()
	random_encounters_check.text = "Random Encounters Enabled"
	random_encounters_check.toggled.connect(_on_random_encounters_toggled)
	section.add_child(random_encounters_check)

	var rate_container: HBoxContainer = HBoxContainer.new()
	var rate_label: Label = Label.new()
	rate_label.text = "Base Encounter Rate:"
	rate_label.custom_minimum_size.x = 150
	rate_container.add_child(rate_label)

	encounter_rate_spin = SpinBox.new()
	encounter_rate_spin.min_value = 0.0
	encounter_rate_spin.max_value = 1.0
	encounter_rate_spin.step = 0.01
	encounter_rate_spin.value = 0.0
	rate_container.add_child(encounter_rate_spin)

	var rate_hint: Label = Label.new()
	rate_hint.text = "(0.0 = never, 1.0 = always)"
	rate_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	rate_hint.add_theme_font_size_override("font_size", 11)
	rate_container.add_child(rate_hint)

	section.add_child(rate_container)

	save_anywhere_check = CheckBox.new()
	save_anywhere_check.text = "Save Anywhere (allow saving at any location)"
	section.add_child(save_anywhere_check)

	detail_panel.add_child(section)
	_add_separator()


func _create_spawn_points_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Spawn Points"
	section_label.add_theme_font_size_override("font_size", 14)
	section.add_child(section_label)

	var help_text: Label = Label.new()
	help_text.text = "Define where players and Caravan can spawn on this map"
	help_text.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	help_text.add_theme_font_size_override("font_size", 11)
	section.add_child(help_text)

	spawn_points_list = ItemList.new()
	spawn_points_list.custom_minimum_size = Vector2(0, 100)
	spawn_points_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spawn_points_list.item_selected.connect(_on_spawn_point_selected)
	section.add_child(spawn_points_list)

	# Spawn point editing fields
	var edit_container: VBoxContainer = VBoxContainer.new()

	spawn_id_edit = _create_line_edit_field("Spawn ID:", edit_container, "e.g., default, from_town, from_battle")

	# Grid position
	var grid_container: HBoxContainer = HBoxContainer.new()
	var grid_label: Label = Label.new()
	grid_label.text = "Grid Position:"
	grid_label.custom_minimum_size.x = 150
	grid_container.add_child(grid_label)

	var x_label: Label = Label.new()
	x_label.text = "X:"
	grid_container.add_child(x_label)

	spawn_grid_x_spin = SpinBox.new()
	spawn_grid_x_spin.min_value = 0
	spawn_grid_x_spin.max_value = 999
	spawn_grid_x_spin.custom_minimum_size.x = 70
	grid_container.add_child(spawn_grid_x_spin)

	var y_label: Label = Label.new()
	y_label.text = "Y:"
	grid_container.add_child(y_label)

	spawn_grid_y_spin = SpinBox.new()
	spawn_grid_y_spin.min_value = 0
	spawn_grid_y_spin.max_value = 999
	spawn_grid_y_spin.custom_minimum_size.x = 70
	grid_container.add_child(spawn_grid_y_spin)

	edit_container.add_child(grid_container)

	# Facing direction
	var facing_container: HBoxContainer = HBoxContainer.new()
	var facing_label: Label = Label.new()
	facing_label.text = "Facing:"
	facing_label.custom_minimum_size.x = 150
	facing_container.add_child(facing_label)

	spawn_facing_dropdown = OptionButton.new()
	for direction in FACING_DIRECTIONS:
		spawn_facing_dropdown.add_item(direction)
	facing_container.add_child(spawn_facing_dropdown)

	edit_container.add_child(facing_container)

	# Flags
	spawn_is_default_check = CheckBox.new()
	spawn_is_default_check.text = "Is Default (fallback spawn point)"
	edit_container.add_child(spawn_is_default_check)

	spawn_is_caravan_check = CheckBox.new()
	spawn_is_caravan_check.text = "Is Caravan Spawn (where Caravan appears)"
	edit_container.add_child(spawn_is_caravan_check)

	section.add_child(edit_container)

	# Buttons
	var button_row: HBoxContainer = HBoxContainer.new()

	add_spawn_button = Button.new()
	add_spawn_button.text = "Add Spawn"
	add_spawn_button.pressed.connect(_on_add_spawn_point)
	button_row.add_child(add_spawn_button)

	update_spawn_button = Button.new()
	update_spawn_button.text = "Update Selected"
	update_spawn_button.pressed.connect(_on_update_spawn_point)
	button_row.add_child(update_spawn_button)

	remove_spawn_button = Button.new()
	remove_spawn_button.text = "Remove Selected"
	remove_spawn_button.pressed.connect(_on_remove_spawn_point)
	button_row.add_child(remove_spawn_button)

	section.add_child(button_row)

	detail_panel.add_child(section)
	_add_separator()


func _create_connections_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Connections"
	section_label.add_theme_font_size_override("font_size", 14)
	section.add_child(section_label)

	var help_text: Label = Label.new()
	help_text.text = "Define doors and transitions to other maps"
	help_text.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	help_text.add_theme_font_size_override("font_size", 11)
	section.add_child(help_text)

	connections_list = ItemList.new()
	connections_list.custom_minimum_size = Vector2(0, 100)
	connections_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	connections_list.item_selected.connect(_on_connection_selected)
	section.add_child(connections_list)

	# Connection editing fields
	var edit_container: VBoxContainer = VBoxContainer.new()

	connection_trigger_id_edit = _create_line_edit_field("Trigger ID:", edit_container, "ID of the MapTrigger that activates this")

	# Target map dropdown
	var target_map_container: HBoxContainer = HBoxContainer.new()
	var target_map_label: Label = Label.new()
	target_map_label.text = "Target Map:"
	target_map_label.custom_minimum_size.x = 150
	target_map_container.add_child(target_map_label)

	connection_target_map_dropdown = OptionButton.new()
	connection_target_map_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_map_container.add_child(connection_target_map_dropdown)

	edit_container.add_child(target_map_container)

	connection_target_spawn_edit = _create_line_edit_field("Target Spawn ID:", edit_container, "Spawn point in destination map")

	# Transition type
	var transition_container: HBoxContainer = HBoxContainer.new()
	var transition_label: Label = Label.new()
	transition_label.text = "Transition Type:"
	transition_label.custom_minimum_size.x = 150
	transition_container.add_child(transition_label)

	connection_transition_dropdown = OptionButton.new()
	for trans_type in TRANSITION_TYPES:
		connection_transition_dropdown.add_item(trans_type)
	transition_container.add_child(connection_transition_dropdown)

	edit_container.add_child(transition_container)

	connection_requires_key_edit = _create_line_edit_field("Requires Key:", edit_container, "Item ID if door is locked (empty = unlocked)")

	connection_one_way_check = CheckBox.new()
	connection_one_way_check.text = "One-Way (cannot return through this connection)"
	edit_container.add_child(connection_one_way_check)

	section.add_child(edit_container)

	# Buttons
	var button_row: HBoxContainer = HBoxContainer.new()

	add_connection_button = Button.new()
	add_connection_button.text = "Add Connection"
	add_connection_button.pressed.connect(_on_add_connection)
	button_row.add_child(add_connection_button)

	update_connection_button = Button.new()
	update_connection_button.text = "Update Selected"
	update_connection_button.pressed.connect(_on_update_connection)
	button_row.add_child(update_connection_button)

	remove_connection_button = Button.new()
	remove_connection_button.text = "Remove Selected"
	remove_connection_button.pressed.connect(_on_remove_connection)
	button_row.add_child(remove_connection_button)

	section.add_child(button_row)

	detail_panel.add_child(section)
	_add_separator()


func _create_edge_connections_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Edge Connections"
	section_label.add_theme_font_size_override("font_size", 14)
	section.add_child(section_label)

	var help_text: Label = Label.new()
	help_text.text = "Seamless transitions when walking off map edges (for overworld)"
	help_text.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	help_text.add_theme_font_size_override("font_size", 11)
	section.add_child(help_text)

	# North edge
	var north_container: HBoxContainer = HBoxContainer.new()
	var north_label: Label = Label.new()
	north_label.text = "North:"
	north_label.custom_minimum_size.x = 60
	north_container.add_child(north_label)
	edge_north_map_dropdown = OptionButton.new()
	edge_north_map_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	north_container.add_child(edge_north_map_dropdown)
	var north_spawn_label: Label = Label.new()
	north_spawn_label.text = "Spawn:"
	north_container.add_child(north_spawn_label)
	edge_north_spawn_edit = LineEdit.new()
	edge_north_spawn_edit.custom_minimum_size.x = 100
	north_container.add_child(edge_north_spawn_edit)
	section.add_child(north_container)

	# South edge
	var south_container: HBoxContainer = HBoxContainer.new()
	var south_label: Label = Label.new()
	south_label.text = "South:"
	south_label.custom_minimum_size.x = 60
	south_container.add_child(south_label)
	edge_south_map_dropdown = OptionButton.new()
	edge_south_map_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	south_container.add_child(edge_south_map_dropdown)
	var south_spawn_label: Label = Label.new()
	south_spawn_label.text = "Spawn:"
	south_container.add_child(south_spawn_label)
	edge_south_spawn_edit = LineEdit.new()
	edge_south_spawn_edit.custom_minimum_size.x = 100
	south_container.add_child(edge_south_spawn_edit)
	section.add_child(south_container)

	# East edge
	var east_container: HBoxContainer = HBoxContainer.new()
	var east_label: Label = Label.new()
	east_label.text = "East:"
	east_label.custom_minimum_size.x = 60
	east_container.add_child(east_label)
	edge_east_map_dropdown = OptionButton.new()
	edge_east_map_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	east_container.add_child(edge_east_map_dropdown)
	var east_spawn_label: Label = Label.new()
	east_spawn_label.text = "Spawn:"
	east_container.add_child(east_spawn_label)
	edge_east_spawn_edit = LineEdit.new()
	edge_east_spawn_edit.custom_minimum_size.x = 100
	east_container.add_child(edge_east_spawn_edit)
	section.add_child(east_container)

	# West edge
	var west_container: HBoxContainer = HBoxContainer.new()
	var west_label: Label = Label.new()
	west_label.text = "West:"
	west_label.custom_minimum_size.x = 60
	west_container.add_child(west_label)
	edge_west_map_dropdown = OptionButton.new()
	edge_west_map_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	west_container.add_child(edge_west_map_dropdown)
	var west_spawn_label: Label = Label.new()
	west_spawn_label.text = "Spawn:"
	west_container.add_child(west_spawn_label)
	edge_west_spawn_edit = LineEdit.new()
	edge_west_spawn_edit.custom_minimum_size.x = 100
	west_container.add_child(edge_west_spawn_edit)
	section.add_child(west_container)

	detail_panel.add_child(section)
	_add_separator()


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


# =============================================================================
# Helper Functions
# =============================================================================

func _create_line_edit_field(label_text: String, parent: VBoxContainer, tooltip: String = "") -> LineEdit:
	var container: HBoxContainer = HBoxContainer.new()

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 150
	if tooltip != "":
		label.tooltip_text = tooltip
	container.add_child(label)

	var edit: LineEdit = LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tooltip != "":
		edit.tooltip_text = tooltip
	container.add_child(edit)

	parent.add_child(container)
	return edit


func _add_separator() -> void:
	var sep: HSeparator = HSeparator.new()
	sep.custom_minimum_size.y = 10
	detail_panel.add_child(sep)


# =============================================================================
# Map List Management
# =============================================================================

func _refresh_map_list() -> void:
	map_list.clear()
	loaded_maps.clear()

	var mods_dir: DirAccess = DirAccess.open("res://mods/")
	if not mods_dir:
		push_error("Cannot open mods directory")
		return

	mods_dir.list_dir_begin()
	var mod_name: String = mods_dir.get_next()

	while mod_name != "":
		if mods_dir.current_is_dir() and not mod_name.begins_with("."):
			var maps_path: String = "res://mods/%s/data/maps/" % mod_name
			_scan_maps_directory(maps_path, mod_name)
		mod_name = mods_dir.get_next()

	mods_dir.list_dir_end()

	# Update connection dropdowns with loaded maps
	_update_map_dropdowns()


func _scan_maps_directory(maps_path: String, mod_name: String) -> void:
	var maps_dir: DirAccess = DirAccess.open(maps_path)
	if not maps_dir:
		return

	maps_dir.list_dir_begin()
	var file_name: String = maps_dir.get_next()

	while file_name != "":
		if not maps_dir.current_is_dir() and file_name.ends_with(".json"):
			var full_path: String = maps_path + file_name
			var map_id: String = _load_map_id_from_file(full_path)

			if map_id.is_empty():
				map_id = file_name.get_basename()

			var display_text: String = "[%s] %s" % [mod_name, map_id]
			map_list.add_item(display_text)
			map_list.set_item_metadata(map_list.item_count - 1, full_path)

			loaded_maps[map_id] = full_path

		file_name = maps_dir.get_next()

	maps_dir.list_dir_end()


func _load_map_id_from_file(path: String) -> String:
	var json_text: String = FileAccess.get_file_as_string(path)
	if json_text.is_empty():
		return ""

	var json_data: Variant = JSON.parse_string(json_text)
	if json_data is Dictionary:
		return json_data.get("map_id", "")

	return ""


func _update_map_dropdowns() -> void:
	# Clear and repopulate all map selection dropdowns
	var dropdowns: Array[OptionButton] = [
		connection_target_map_dropdown,
		edge_north_map_dropdown,
		edge_south_map_dropdown,
		edge_east_map_dropdown,
		edge_west_map_dropdown
	]

	for dropdown in dropdowns:
		if dropdown:
			dropdown.clear()
			dropdown.add_item("(None)")
			for map_id in loaded_maps.keys():
				dropdown.add_item(map_id)


# =============================================================================
# Map Selection and Loading
# =============================================================================

func _on_map_selected(index: int) -> void:
	var path: String = map_list.get_item_metadata(index)
	_load_map_json(path)


func _load_map_json(path: String) -> void:
	current_map_path = path

	var json_text: String = FileAccess.get_file_as_string(path)
	if json_text.is_empty():
		_show_errors(["Failed to read map JSON file"])
		return

	var json_data: Variant = JSON.parse_string(json_text)
	if not json_data is Dictionary:
		_show_errors(["Invalid JSON format in map file"])
		return

	current_map_data = json_data
	_populate_ui_from_data()
	_hide_errors()
	is_dirty = false


func _populate_ui_from_data() -> void:
	# Basic properties
	map_id_edit.text = current_map_data.get("map_id", "")
	display_name_edit.text = current_map_data.get("display_name", "")

	var map_type_str: String = current_map_data.get("map_type", "TOWN")
	var type_index: int = MAP_TYPES.find(map_type_str.to_upper())
	if type_index >= 0:
		map_type_dropdown.select(type_index)

	# Scene reference
	scene_path_edit.text = current_map_data.get("scene_path", "")

	# Caravan settings
	caravan_accessible_check.button_pressed = current_map_data.get("caravan_accessible", false)
	caravan_visible_check.button_pressed = current_map_data.get("caravan_visible", false)

	# Camera settings
	camera_zoom_spin.value = current_map_data.get("camera_zoom", 1.0)

	# Audio settings
	music_id_edit.text = current_map_data.get("music_id", "")
	ambient_id_edit.text = current_map_data.get("ambient_id", "")

	# Encounter settings
	random_encounters_check.button_pressed = current_map_data.get("random_encounters_enabled", false)
	encounter_rate_spin.value = current_map_data.get("base_encounter_rate", 0.0)
	save_anywhere_check.button_pressed = current_map_data.get("save_anywhere", true)
	_on_random_encounters_toggled(random_encounters_check.button_pressed)

	# Spawn points
	_populate_spawn_points()

	# Connections
	_populate_connections()

	# Edge connections
	_populate_edge_connections()


func _populate_spawn_points() -> void:
	spawn_points_list.clear()

	var spawn_points: Dictionary = current_map_data.get("spawn_points", {})
	for spawn_id in spawn_points.keys():
		var spawn_data: Dictionary = spawn_points[spawn_id]
		var grid_pos: Array = spawn_data.get("grid_position", [0, 0])
		var facing: String = spawn_data.get("facing", "down")
		var is_default: bool = spawn_data.get("is_default", false)
		var is_caravan: bool = spawn_data.get("is_caravan_spawn", false)

		var display_text: String = "%s (%d, %d) %s" % [spawn_id, grid_pos[0], grid_pos[1], facing]
		if is_default:
			display_text += " [default]"
		if is_caravan:
			display_text += " [caravan]"

		spawn_points_list.add_item(display_text)
		spawn_points_list.set_item_metadata(spawn_points_list.item_count - 1, {
			"id": spawn_id,
			"data": spawn_data
		})


func _populate_connections() -> void:
	connections_list.clear()

	var connections: Array = current_map_data.get("connections", [])
	for connection in connections:
		if connection is Dictionary:
			var trigger_id: String = connection.get("trigger_id", "")
			var target_map: String = connection.get("target_map_id", "")
			var target_spawn: String = connection.get("target_spawn_id", "")

			var display_text: String = "%s -> %s:%s" % [trigger_id, target_map, target_spawn]
			connections_list.add_item(display_text)
			connections_list.set_item_metadata(connections_list.item_count - 1, connection)


func _populate_edge_connections() -> void:
	var edge_connections: Dictionary = current_map_data.get("edge_connections", {})

	_set_edge_dropdown_value(edge_north_map_dropdown, edge_north_spawn_edit, edge_connections.get("north", {}))
	_set_edge_dropdown_value(edge_south_map_dropdown, edge_south_spawn_edit, edge_connections.get("south", {}))
	_set_edge_dropdown_value(edge_east_map_dropdown, edge_east_spawn_edit, edge_connections.get("east", {}))
	_set_edge_dropdown_value(edge_west_map_dropdown, edge_west_spawn_edit, edge_connections.get("west", {}))


func _set_edge_dropdown_value(dropdown: OptionButton, spawn_edit: LineEdit, edge_data: Dictionary) -> void:
	var target_map: String = edge_data.get("target_map_id", "")
	var target_spawn: String = edge_data.get("target_spawn_id", "")

	spawn_edit.text = target_spawn

	if target_map.is_empty():
		dropdown.select(0)  # (None)
	else:
		for i in range(dropdown.item_count):
			if dropdown.get_item_text(i) == target_map:
				dropdown.select(i)
				return
		dropdown.select(0)


# =============================================================================
# Data Collection
# =============================================================================

func _collect_data_from_ui() -> void:
	# Basic properties
	current_map_data["map_id"] = map_id_edit.text
	current_map_data["display_name"] = display_name_edit.text
	current_map_data["map_type"] = MAP_TYPES[map_type_dropdown.selected]

	# Scene reference
	current_map_data["scene_path"] = scene_path_edit.text

	# Caravan settings
	current_map_data["caravan_accessible"] = caravan_accessible_check.button_pressed
	current_map_data["caravan_visible"] = caravan_visible_check.button_pressed

	# Camera settings
	current_map_data["camera_zoom"] = camera_zoom_spin.value

	# Audio settings
	current_map_data["music_id"] = music_id_edit.text
	current_map_data["ambient_id"] = ambient_id_edit.text

	# Encounter settings
	current_map_data["random_encounters_enabled"] = random_encounters_check.button_pressed
	current_map_data["base_encounter_rate"] = encounter_rate_spin.value
	current_map_data["save_anywhere"] = save_anywhere_check.button_pressed

	# Spawn points (already stored in list metadata during editing)
	var spawn_points: Dictionary = {}
	for i in range(spawn_points_list.item_count):
		var metadata: Dictionary = spawn_points_list.get_item_metadata(i)
		var spawn_id: String = metadata.get("id", "")
		var spawn_data: Dictionary = metadata.get("data", {})
		if not spawn_id.is_empty():
			spawn_points[spawn_id] = spawn_data
	current_map_data["spawn_points"] = spawn_points

	# Connections (already stored in list metadata during editing)
	var connections: Array = []
	for i in range(connections_list.item_count):
		var connection: Dictionary = connections_list.get_item_metadata(i)
		if connection is Dictionary:
			connections.append(connection)
	current_map_data["connections"] = connections

	# Edge connections
	var edge_connections: Dictionary = {}
	_collect_edge_connection(edge_connections, "north", edge_north_map_dropdown, edge_north_spawn_edit)
	_collect_edge_connection(edge_connections, "south", edge_south_map_dropdown, edge_south_spawn_edit)
	_collect_edge_connection(edge_connections, "east", edge_east_map_dropdown, edge_east_spawn_edit)
	_collect_edge_connection(edge_connections, "west", edge_west_map_dropdown, edge_west_spawn_edit)
	current_map_data["edge_connections"] = edge_connections


func _collect_edge_connection(edge_connections: Dictionary, direction: String, dropdown: OptionButton, spawn_edit: LineEdit) -> void:
	if dropdown.selected > 0:  # Not "(None)"
		var target_map: String = dropdown.get_item_text(dropdown.selected)
		var target_spawn: String = spawn_edit.text.strip_edges()
		if not target_map.is_empty():
			edge_connections[direction] = {
				"target_map_id": target_map,
				"target_spawn_id": target_spawn,
				"overlap_tiles": 1
			}


# =============================================================================
# Save and Delete Operations
# =============================================================================

func _on_save() -> void:
	if current_map_path.is_empty():
		_show_errors(["No map selected"])
		return

	# Validate
	var errors: Array[String] = _validate_map_data()
	if errors.size() > 0:
		_show_errors(errors)
		return

	# Collect data from UI
	_collect_data_from_ui()

	# Write to file
	var json_text: String = JSON.stringify(current_map_data, "\t")
	var file: FileAccess = FileAccess.open(current_map_path, FileAccess.WRITE)
	if not file:
		_show_errors(["Failed to open file for writing: " + current_map_path])
		return

	file.store_string(json_text)
	file.close()

	_hide_errors()
	is_dirty = false

	# Refresh map list to show updated info
	_refresh_map_list()

	# Notify that a map was saved (not mods_reloaded - that's for mod manifest changes)
	var event_bus: Node = get_node_or_null("/root/EditorEventBus")
	if event_bus:
		var map_id: String = current_map_data.get("map_id", "")
		event_bus.resource_saved.emit("map", map_id, null)


func _on_delete() -> void:
	if current_map_path.is_empty():
		_show_errors(["No map selected"])
		return

	# Delete the file
	var err: Error = DirAccess.remove_absolute(current_map_path)
	if err != OK:
		_show_errors(["Failed to delete map file: " + error_string(err)])
		return

	current_map_path = ""
	current_map_data = {}
	_clear_ui()
	_refresh_map_list()
	_hide_errors()


func _on_create_map() -> void:
	# Determine active mod path
	var active_mod_id: String = "_sandbox"
	if ModLoader:
		var active_mod: ModManifest = ModLoader.get_active_mod()
		if active_mod:
			active_mod_id = active_mod.mod_id

	# Generate unique map ID
	var timestamp: int = int(Time.get_unix_time_from_system())
	var new_map_id: String = "%s:new_map_%d" % [active_mod_id, timestamp]

	# Create default map data
	var new_map_data: Dictionary = {
		"map_id": new_map_id,
		"display_name": "New Map",
		"map_type": "TOWN",
		"caravan_accessible": false,
		"caravan_visible": false,
		"camera_zoom": 1.0,
		"scene_path": "",
		"spawn_points": {
			"default": {
				"grid_position": [5, 5],
				"facing": "down",
				"is_default": true
			}
		},
		"connections": [],
		"edge_connections": {},
		"music_id": "",
		"ambient_id": "",
		"random_encounters_enabled": false,
		"base_encounter_rate": 0.0,
		"save_anywhere": true
	}

	# Create maps directory if needed
	var maps_dir: String = "res://mods/%s/data/maps/" % active_mod_id
	if not DirAccess.dir_exists_absolute(maps_dir):
		var err: Error = DirAccess.make_dir_recursive_absolute(maps_dir)
		if err != OK:
			_show_errors(["Failed to create maps directory: " + error_string(err)])
			return

	# Save new map file
	var file_name: String = "new_map_%d.json" % timestamp
	var file_path: String = maps_dir + file_name

	var json_text: String = JSON.stringify(new_map_data, "\t")
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		_show_errors(["Failed to create new map file"])
		return

	file.store_string(json_text)
	file.close()

	# Refresh and select new map
	_refresh_map_list()

	# Find and select the new map
	for i in range(map_list.item_count):
		var path: String = map_list.get_item_metadata(i)
		if path == file_path:
			map_list.select(i)
			_on_map_selected(i)
			break

	_hide_errors()


func _clear_ui() -> void:
	map_id_edit.text = ""
	display_name_edit.text = ""
	map_type_dropdown.select(0)
	scene_path_edit.text = ""
	caravan_accessible_check.button_pressed = false
	caravan_visible_check.button_pressed = false
	camera_zoom_spin.value = 1.0
	music_id_edit.text = ""
	ambient_id_edit.text = ""
	random_encounters_check.button_pressed = false
	encounter_rate_spin.value = 0.0
	save_anywhere_check.button_pressed = true
	spawn_points_list.clear()
	connections_list.clear()
	edge_north_map_dropdown.select(0)
	edge_north_spawn_edit.text = ""
	edge_south_map_dropdown.select(0)
	edge_south_spawn_edit.text = ""
	edge_east_map_dropdown.select(0)
	edge_east_spawn_edit.text = ""
	edge_west_map_dropdown.select(0)
	edge_west_spawn_edit.text = ""


# =============================================================================
# Validation
# =============================================================================

func _validate_map_data() -> Array[String]:
	var errors: Array[String] = []

	if map_id_edit.text.strip_edges().is_empty():
		errors.append("Map ID cannot be empty")

	if display_name_edit.text.strip_edges().is_empty():
		errors.append("Display name cannot be empty")

	var scene_path: String = scene_path_edit.text.strip_edges()
	if not scene_path.is_empty():
		if not scene_path.ends_with(".tscn"):
			errors.append("Scene path must be a .tscn file")
		elif not FileAccess.file_exists(scene_path):
			errors.append("Scene file does not exist: " + scene_path)

	if spawn_points_list.item_count == 0:
		errors.append("At least one spawn point is required")

	# Check Caravan consistency
	if caravan_visible_check.button_pressed and not caravan_accessible_check.button_pressed:
		errors.append("Caravan visible requires Caravan accessible")

	return errors


# =============================================================================
# Event Handlers - Type Defaults
# =============================================================================

func _on_apply_type_defaults() -> void:
	var type_index: int = map_type_dropdown.selected
	var map_type: String = MAP_TYPES[type_index]

	match map_type:
		"TOWN":
			caravan_visible_check.button_pressed = false
			caravan_accessible_check.button_pressed = false
			camera_zoom_spin.value = 1.0
			random_encounters_check.button_pressed = false
			encounter_rate_spin.value = 0.0
			save_anywhere_check.button_pressed = true
		"OVERWORLD":
			caravan_visible_check.button_pressed = true
			caravan_accessible_check.button_pressed = true
			camera_zoom_spin.value = 1.0
			random_encounters_check.button_pressed = true
			encounter_rate_spin.value = 0.1
			save_anywhere_check.button_pressed = true
		"DUNGEON":
			caravan_visible_check.button_pressed = false
			caravan_accessible_check.button_pressed = false
			camera_zoom_spin.value = 1.0
			random_encounters_check.button_pressed = true
			encounter_rate_spin.value = 0.15
			save_anywhere_check.button_pressed = false
		"INTERIOR":
			caravan_visible_check.button_pressed = false
			caravan_accessible_check.button_pressed = false
			camera_zoom_spin.value = 1.0
			random_encounters_check.button_pressed = false
			encounter_rate_spin.value = 0.0
			save_anywhere_check.button_pressed = true
		"BATTLE":
			caravan_visible_check.button_pressed = false
			caravan_accessible_check.button_pressed = false
			camera_zoom_spin.value = 1.0
			random_encounters_check.button_pressed = false
			encounter_rate_spin.value = 0.0
			save_anywhere_check.button_pressed = false

	_on_random_encounters_toggled(random_encounters_check.button_pressed)
	is_dirty = true


func _on_random_encounters_toggled(enabled: bool) -> void:
	encounter_rate_spin.editable = enabled


func _on_browse_scene() -> void:
	# In editor context, we cannot easily launch a file dialog
	# Instead, show a hint about where to find scenes
	_show_errors(["Browse not available in plugin context. Enter the scene path manually.\nFormat: res://mods/<mod_id>/maps/<scene_name>.tscn"])


# =============================================================================
# Spawn Point Handlers
# =============================================================================

func _on_spawn_point_selected(index: int) -> void:
	var metadata: Dictionary = spawn_points_list.get_item_metadata(index)
	var spawn_data: Dictionary = metadata.get("data", {})

	spawn_id_edit.text = metadata.get("id", "")

	var grid_pos: Array = spawn_data.get("grid_position", [0, 0])
	spawn_grid_x_spin.value = grid_pos[0] if grid_pos.size() > 0 else 0
	spawn_grid_y_spin.value = grid_pos[1] if grid_pos.size() > 1 else 0

	var facing: String = spawn_data.get("facing", "down")
	var facing_index: int = FACING_DIRECTIONS.find(facing)
	if facing_index >= 0:
		spawn_facing_dropdown.select(facing_index)

	spawn_is_default_check.button_pressed = spawn_data.get("is_default", false)
	spawn_is_caravan_check.button_pressed = spawn_data.get("is_caravan_spawn", false)


func _on_add_spawn_point() -> void:
	var spawn_id: String = spawn_id_edit.text.strip_edges()
	if spawn_id.is_empty():
		_show_errors(["Spawn ID cannot be empty"])
		return

	# Check for duplicate ID
	for i in range(spawn_points_list.item_count):
		var metadata: Dictionary = spawn_points_list.get_item_metadata(i)
		if metadata.get("id", "") == spawn_id:
			_show_errors(["Spawn ID '%s' already exists" % spawn_id])
			return

	var spawn_data: Dictionary = _build_spawn_data()
	var display_text: String = _build_spawn_display_text(spawn_id, spawn_data)

	spawn_points_list.add_item(display_text)
	spawn_points_list.set_item_metadata(spawn_points_list.item_count - 1, {
		"id": spawn_id,
		"data": spawn_data
	})

	_clear_spawn_fields()
	is_dirty = true
	_hide_errors()


func _on_update_spawn_point() -> void:
	var selected: PackedInt32Array = spawn_points_list.get_selected_items()
	if selected.size() == 0:
		_show_errors(["No spawn point selected"])
		return

	var spawn_id: String = spawn_id_edit.text.strip_edges()
	if spawn_id.is_empty():
		_show_errors(["Spawn ID cannot be empty"])
		return

	var spawn_data: Dictionary = _build_spawn_data()
	var display_text: String = _build_spawn_display_text(spawn_id, spawn_data)

	var index: int = selected[0]
	spawn_points_list.set_item_text(index, display_text)
	spawn_points_list.set_item_metadata(index, {
		"id": spawn_id,
		"data": spawn_data
	})

	is_dirty = true
	_hide_errors()


func _on_remove_spawn_point() -> void:
	var selected: PackedInt32Array = spawn_points_list.get_selected_items()
	if selected.size() > 0:
		spawn_points_list.remove_item(selected[0])
		_clear_spawn_fields()
		is_dirty = true


func _build_spawn_data() -> Dictionary:
	return {
		"grid_position": [int(spawn_grid_x_spin.value), int(spawn_grid_y_spin.value)],
		"facing": FACING_DIRECTIONS[spawn_facing_dropdown.selected],
		"is_default": spawn_is_default_check.button_pressed,
		"is_caravan_spawn": spawn_is_caravan_check.button_pressed
	}


func _build_spawn_display_text(spawn_id: String, spawn_data: Dictionary) -> String:
	var grid_pos: Array = spawn_data.get("grid_position", [0, 0])
	var facing: String = spawn_data.get("facing", "down")
	var is_default: bool = spawn_data.get("is_default", false)
	var is_caravan: bool = spawn_data.get("is_caravan_spawn", false)

	var display_text: String = "%s (%d, %d) %s" % [spawn_id, grid_pos[0], grid_pos[1], facing]
	if is_default:
		display_text += " [default]"
	if is_caravan:
		display_text += " [caravan]"

	return display_text


func _clear_spawn_fields() -> void:
	spawn_id_edit.text = ""
	spawn_grid_x_spin.value = 0
	spawn_grid_y_spin.value = 0
	spawn_facing_dropdown.select(0)
	spawn_is_default_check.button_pressed = false
	spawn_is_caravan_check.button_pressed = false


# =============================================================================
# Connection Handlers
# =============================================================================

func _on_connection_selected(index: int) -> void:
	var connection: Dictionary = connections_list.get_item_metadata(index)

	connection_trigger_id_edit.text = connection.get("trigger_id", "")

	var target_map: String = connection.get("target_map_id", "")
	_select_dropdown_by_text(connection_target_map_dropdown, target_map)

	connection_target_spawn_edit.text = connection.get("target_spawn_id", "")

	var transition_type: String = connection.get("transition_type", "fade")
	var trans_index: int = TRANSITION_TYPES.find(transition_type)
	if trans_index >= 0:
		connection_transition_dropdown.select(trans_index)

	connection_requires_key_edit.text = connection.get("requires_key", "")
	connection_one_way_check.button_pressed = connection.get("one_way", false)


func _on_add_connection() -> void:
	var trigger_id: String = connection_trigger_id_edit.text.strip_edges()
	if trigger_id.is_empty():
		_show_errors(["Trigger ID cannot be empty"])
		return

	var connection: Dictionary = _build_connection_data()
	var display_text: String = "%s -> %s:%s" % [
		connection.get("trigger_id", ""),
		connection.get("target_map_id", ""),
		connection.get("target_spawn_id", "")
	]

	connections_list.add_item(display_text)
	connections_list.set_item_metadata(connections_list.item_count - 1, connection)

	_clear_connection_fields()
	is_dirty = true
	_hide_errors()


func _on_update_connection() -> void:
	var selected: PackedInt32Array = connections_list.get_selected_items()
	if selected.size() == 0:
		_show_errors(["No connection selected"])
		return

	var trigger_id: String = connection_trigger_id_edit.text.strip_edges()
	if trigger_id.is_empty():
		_show_errors(["Trigger ID cannot be empty"])
		return

	var connection: Dictionary = _build_connection_data()
	var display_text: String = "%s -> %s:%s" % [
		connection.get("trigger_id", ""),
		connection.get("target_map_id", ""),
		connection.get("target_spawn_id", "")
	]

	var index: int = selected[0]
	connections_list.set_item_text(index, display_text)
	connections_list.set_item_metadata(index, connection)

	is_dirty = true
	_hide_errors()


func _on_remove_connection() -> void:
	var selected: PackedInt32Array = connections_list.get_selected_items()
	if selected.size() > 0:
		connections_list.remove_item(selected[0])
		_clear_connection_fields()
		is_dirty = true


func _build_connection_data() -> Dictionary:
	var target_map: String = ""
	if connection_target_map_dropdown.selected > 0:
		target_map = connection_target_map_dropdown.get_item_text(connection_target_map_dropdown.selected)

	return {
		"trigger_id": connection_trigger_id_edit.text.strip_edges(),
		"target_map_id": target_map,
		"target_spawn_id": connection_target_spawn_edit.text.strip_edges(),
		"transition_type": TRANSITION_TYPES[connection_transition_dropdown.selected],
		"requires_key": connection_requires_key_edit.text.strip_edges(),
		"one_way": connection_one_way_check.button_pressed
	}


func _clear_connection_fields() -> void:
	connection_trigger_id_edit.text = ""
	connection_target_map_dropdown.select(0)
	connection_target_spawn_edit.text = ""
	connection_transition_dropdown.select(0)
	connection_requires_key_edit.text = ""
	connection_one_way_check.button_pressed = false


func _select_dropdown_by_text(dropdown: OptionButton, text: String) -> void:
	if text.is_empty():
		dropdown.select(0)
		return

	for i in range(dropdown.item_count):
		if dropdown.get_item_text(i) == text:
			dropdown.select(i)
			return

	dropdown.select(0)


# =============================================================================
# Error Display
# =============================================================================

func _show_errors(errors: Array) -> void:
	var error_text: String = "[b]Error:[/b]\n"
	for error in errors:
		error_text += "* " + str(error) + "\n"
	error_label.text = error_text
	error_panel.show()

	# Brief pulse animation
	var tween: Tween = create_tween()
	tween.tween_property(error_panel, "modulate:a", 0.6, 0.15)
	tween.tween_property(error_panel, "modulate:a", 1.0, 0.15)


func _hide_errors() -> void:
	error_panel.hide()
	error_label.text = ""
