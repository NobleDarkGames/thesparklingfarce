@tool
extends Control

## CampaignData Editor
## GraphEdit-based visual editor for campaign progression
## Supports all node types with color-coding and connection visualization

# Node type colors
const NODE_COLORS: Dictionary = {
	"battle": Color(0.8, 0.3, 0.3),    # Red
	"scene": Color(0.3, 0.5, 0.8),     # Blue
	"cutscene": Color(0.8, 0.7, 0.2),  # Yellow
	"choice": Color(0.6, 0.3, 0.7),    # Purple
}

const HUB_BORDER_COLOR: Color = Color(0.3, 0.8, 0.3)  # Green
const START_NODE_COLOR: Color = Color(0.2, 0.8, 0.5)  # Teal accent

# Node types for dropdown
const NODE_TYPES: Array[String] = ["battle", "scene", "cutscene", "choice"]

# UI Components
var campaign_list: ItemList
var graph_edit: GraphEdit
var inspector_scroll: ScrollContainer
var inspector_panel: VBoxContainer
var save_button: Button
var create_button: Button
var add_node_button: Button
var delete_node_button: Button

# Metadata components
var campaign_id_edit: LineEdit
var campaign_name_edit: LineEdit
var description_edit: TextEdit
var version_edit: LineEdit
var starting_node_option: OptionButton
var default_hub_option: OptionButton

# Node inspector components
var node_id_edit: LineEdit
var node_name_edit: LineEdit
var node_type_option: OptionButton
var resource_id_edit: LineEdit
var scene_path_edit: LineEdit
var on_victory_option: OptionButton
var on_defeat_option: OptionButton
var on_complete_option: OptionButton
var is_hub_check: CheckBox
var is_chapter_boundary_check: CheckBox
var allow_egress_check: CheckBox
var retain_xp_check: CheckBox
var repeatable_check: CheckBox
var defeat_penalty_spin: SpinBox
var pre_cinematic_edit: LineEdit
var post_cinematic_edit: LineEdit

# Error panel
var error_panel: PanelContainer
var error_label: RichTextLabel

# Current state
var current_campaign_path: String = ""
var current_campaign_data: Dictionary = {}
var selected_node_id: String = ""
var graph_nodes: Dictionary = {}  # node_id -> GraphNode

# Track if we're updating UI to prevent recursive updates
var _updating_ui: bool = false


func _ready() -> void:
	_setup_ui()
	_refresh_campaign_list()


func _setup_ui() -> void:
	var main_hsplit: HSplitContainer = HSplitContainer.new()
	main_hsplit.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_hsplit)

	# Left panel - Campaign list
	var left_panel: VBoxContainer = VBoxContainer.new()
	left_panel.custom_minimum_size.x = 220
	main_hsplit.add_child(left_panel)

	var list_label: Label = Label.new()
	list_label.text = "Campaigns"
	list_label.add_theme_font_size_override("font_size", 16)
	left_panel.add_child(list_label)

	campaign_list = ItemList.new()
	campaign_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	campaign_list.item_selected.connect(_on_campaign_selected)
	left_panel.add_child(campaign_list)

	var btn_row: HBoxContainer = HBoxContainer.new()
	left_panel.add_child(btn_row)

	create_button = Button.new()
	create_button.text = "New"
	create_button.pressed.connect(_on_create_new)
	btn_row.add_child(create_button)

	var refresh_btn: Button = Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_refresh_campaign_list)
	btn_row.add_child(refresh_btn)

	# Center - Main content split (graph + inspector)
	var center_vsplit: VSplitContainer = VSplitContainer.new()
	center_vsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hsplit.add_child(center_vsplit)

	# Top area - Metadata + Graph
	var top_section: VBoxContainer = VBoxContainer.new()
	top_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_vsplit.add_child(top_section)

	_setup_metadata_section(top_section)
	_setup_graph_section(top_section)

	# Bottom area - Node Inspector
	_setup_inspector_section(center_vsplit)


func _setup_metadata_section(parent: VBoxContainer) -> void:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)

	var header: Label = Label.new()
	header.text = "Campaign Metadata"
	header.add_theme_font_size_override("font_size", 16)
	section.add_child(header)

	# Error panel
	_setup_error_panel(section)

	# Row 1: ID, Name
	var row1: HBoxContainer = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)

	var id_label: Label = Label.new()
	id_label.text = "ID:"
	id_label.custom_minimum_size.x = 60
	row1.add_child(id_label)

	campaign_id_edit = LineEdit.new()
	campaign_id_edit.custom_minimum_size.x = 150
	campaign_id_edit.placeholder_text = "mod_id:campaign_id"
	row1.add_child(campaign_id_edit)

	var name_label: Label = Label.new()
	name_label.text = "Name:"
	name_label.custom_minimum_size.x = 50
	row1.add_child(name_label)

	campaign_name_edit = LineEdit.new()
	campaign_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(campaign_name_edit)

	var ver_label: Label = Label.new()
	ver_label.text = "Version:"
	ver_label.custom_minimum_size.x = 55
	row1.add_child(ver_label)

	version_edit = LineEdit.new()
	version_edit.custom_minimum_size.x = 80
	version_edit.text = "1.0.0"
	row1.add_child(version_edit)

	section.add_child(row1)

	# Row 2: Start Node, Default Hub
	var row2: HBoxContainer = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)

	var start_label: Label = Label.new()
	start_label.text = "Start:"
	start_label.custom_minimum_size.x = 60
	row2.add_child(start_label)

	starting_node_option = OptionButton.new()
	starting_node_option.custom_minimum_size.x = 150
	starting_node_option.item_selected.connect(_on_starting_node_changed)
	row2.add_child(starting_node_option)

	var hub_label: Label = Label.new()
	hub_label.text = "Default Hub:"
	hub_label.custom_minimum_size.x = 80
	row2.add_child(hub_label)

	default_hub_option = OptionButton.new()
	default_hub_option.custom_minimum_size.x = 150
	default_hub_option.item_selected.connect(_on_default_hub_changed)
	row2.add_child(default_hub_option)

	# Save button
	save_button = Button.new()
	save_button.text = "Save Campaign"
	save_button.pressed.connect(_on_save)
	row2.add_child(save_button)

	section.add_child(row2)

	parent.add_child(section)


func _setup_error_panel(parent: VBoxContainer) -> void:
	error_panel = PanelContainer.new()
	error_panel.visible = false

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.1, 0.1, 0.9)
	style.border_color = Color(0.8, 0.2, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	error_panel.add_theme_stylebox_override("panel", style)

	error_label = RichTextLabel.new()
	error_label.bbcode_enabled = true
	error_label.fit_content = true
	error_label.scroll_active = false
	error_panel.add_child(error_label)

	parent.add_child(error_panel)


func _setup_graph_section(parent: VBoxContainer) -> void:
	var graph_header: HBoxContainer = HBoxContainer.new()
	graph_header.add_theme_constant_override("separation", 10)

	var graph_label: Label = Label.new()
	graph_label.text = "Campaign Flow"
	graph_label.add_theme_font_size_override("font_size", 16)
	graph_header.add_child(graph_label)

	add_node_button = Button.new()
	add_node_button.text = "+ Add Node"
	add_node_button.pressed.connect(_on_add_node)
	graph_header.add_child(add_node_button)

	delete_node_button = Button.new()
	delete_node_button.text = "- Delete Node"
	delete_node_button.pressed.connect(_on_delete_node)
	graph_header.add_child(delete_node_button)

	parent.add_child(graph_header)

	graph_edit = GraphEdit.new()
	graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_edit.custom_minimum_size.y = 300
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	graph_edit.node_selected.connect(_on_graph_node_selected)
	graph_edit.node_deselected.connect(_on_graph_node_deselected)

	# Enable snapping
	graph_edit.snapping_enabled = true
	graph_edit.snapping_distance = 20

	parent.add_child(graph_edit)


func _setup_inspector_section(parent: VSplitContainer) -> void:
	inspector_scroll = ScrollContainer.new()
	inspector_scroll.custom_minimum_size.y = 200
	inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	inspector_panel = VBoxContainer.new()
	inspector_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_panel.add_theme_constant_override("separation", 6)
	inspector_scroll.add_child(inspector_panel)

	var header: Label = Label.new()
	header.text = "Node Inspector"
	header.add_theme_font_size_override("font_size", 16)
	inspector_panel.add_child(header)

	var sep: HSeparator = HSeparator.new()
	inspector_panel.add_child(sep)

	# Basic info row
	var basic_row: HBoxContainer = HBoxContainer.new()
	basic_row.add_theme_constant_override("separation", 10)

	var nid_label: Label = Label.new()
	nid_label.text = "Node ID:"
	nid_label.custom_minimum_size.x = 65
	basic_row.add_child(nid_label)

	node_id_edit = LineEdit.new()
	node_id_edit.custom_minimum_size.x = 120
	node_id_edit.text_changed.connect(_on_node_id_changed)
	basic_row.add_child(node_id_edit)

	var nname_label: Label = Label.new()
	nname_label.text = "Name:"
	nname_label.custom_minimum_size.x = 50
	basic_row.add_child(nname_label)

	node_name_edit = LineEdit.new()
	node_name_edit.custom_minimum_size.x = 150
	node_name_edit.text_changed.connect(_on_node_name_changed)
	basic_row.add_child(node_name_edit)

	var ntype_label: Label = Label.new()
	ntype_label.text = "Type:"
	ntype_label.custom_minimum_size.x = 40
	basic_row.add_child(ntype_label)

	node_type_option = OptionButton.new()
	for t: String in NODE_TYPES:
		node_type_option.add_item(t)
	node_type_option.item_selected.connect(_on_node_type_changed)
	basic_row.add_child(node_type_option)

	inspector_panel.add_child(basic_row)

	# Resource row
	var res_row: HBoxContainer = HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 10)

	var resid_label: Label = Label.new()
	resid_label.text = "Resource ID:"
	resid_label.custom_minimum_size.x = 80
	res_row.add_child(resid_label)

	resource_id_edit = LineEdit.new()
	resource_id_edit.custom_minimum_size.x = 150
	resource_id_edit.placeholder_text = "BattleData/CinematicData ID"
	resource_id_edit.text_changed.connect(_on_resource_id_changed)
	res_row.add_child(resource_id_edit)

	var spath_label: Label = Label.new()
	spath_label.text = "Scene Path:"
	spath_label.custom_minimum_size.x = 75
	res_row.add_child(spath_label)

	scene_path_edit = LineEdit.new()
	scene_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene_path_edit.placeholder_text = "res://mods/..."
	scene_path_edit.text_changed.connect(_on_scene_path_changed)
	res_row.add_child(scene_path_edit)

	inspector_panel.add_child(res_row)

	# Transitions row
	var trans_row: HBoxContainer = HBoxContainer.new()
	trans_row.add_theme_constant_override("separation", 10)

	var vic_label: Label = Label.new()
	vic_label.text = "On Victory:"
	vic_label.custom_minimum_size.x = 75
	trans_row.add_child(vic_label)

	on_victory_option = OptionButton.new()
	on_victory_option.custom_minimum_size.x = 120
	on_victory_option.item_selected.connect(_on_victory_target_changed)
	trans_row.add_child(on_victory_option)

	var def_label: Label = Label.new()
	def_label.text = "On Defeat:"
	def_label.custom_minimum_size.x = 70
	trans_row.add_child(def_label)

	on_defeat_option = OptionButton.new()
	on_defeat_option.custom_minimum_size.x = 120
	on_defeat_option.item_selected.connect(_on_defeat_target_changed)
	trans_row.add_child(on_defeat_option)

	var comp_label: Label = Label.new()
	comp_label.text = "On Complete:"
	comp_label.custom_minimum_size.x = 85
	trans_row.add_child(comp_label)

	on_complete_option = OptionButton.new()
	on_complete_option.custom_minimum_size.x = 120
	on_complete_option.item_selected.connect(_on_complete_target_changed)
	trans_row.add_child(on_complete_option)

	inspector_panel.add_child(trans_row)

	# Flags row
	var flags_row: HBoxContainer = HBoxContainer.new()
	flags_row.add_theme_constant_override("separation", 15)

	is_hub_check = CheckBox.new()
	is_hub_check.text = "Is Hub"
	is_hub_check.toggled.connect(_on_is_hub_toggled)
	flags_row.add_child(is_hub_check)

	is_chapter_boundary_check = CheckBox.new()
	is_chapter_boundary_check.text = "Chapter Boundary"
	is_chapter_boundary_check.toggled.connect(_on_chapter_boundary_toggled)
	flags_row.add_child(is_chapter_boundary_check)

	allow_egress_check = CheckBox.new()
	allow_egress_check.text = "Allow Egress"
	allow_egress_check.button_pressed = true
	allow_egress_check.toggled.connect(_on_allow_egress_toggled)
	flags_row.add_child(allow_egress_check)

	retain_xp_check = CheckBox.new()
	retain_xp_check.text = "Retain XP on Defeat"
	retain_xp_check.button_pressed = true
	retain_xp_check.toggled.connect(_on_retain_xp_toggled)
	flags_row.add_child(retain_xp_check)

	repeatable_check = CheckBox.new()
	repeatable_check.text = "Repeatable"
	repeatable_check.toggled.connect(_on_repeatable_toggled)
	flags_row.add_child(repeatable_check)

	inspector_panel.add_child(flags_row)

	# Battle penalty + cinematics row
	var misc_row: HBoxContainer = HBoxContainer.new()
	misc_row.add_theme_constant_override("separation", 10)

	var penalty_label: Label = Label.new()
	penalty_label.text = "Defeat Gold Penalty:"
	penalty_label.custom_minimum_size.x = 120
	misc_row.add_child(penalty_label)

	defeat_penalty_spin = SpinBox.new()
	defeat_penalty_spin.min_value = 0.0
	defeat_penalty_spin.max_value = 1.0
	defeat_penalty_spin.step = 0.05
	defeat_penalty_spin.value = 0.5
	defeat_penalty_spin.value_changed.connect(_on_defeat_penalty_changed)
	misc_row.add_child(defeat_penalty_spin)

	var pre_cine_label: Label = Label.new()
	pre_cine_label.text = "Pre-Cinematic:"
	pre_cine_label.custom_minimum_size.x = 90
	misc_row.add_child(pre_cine_label)

	pre_cinematic_edit = LineEdit.new()
	pre_cinematic_edit.custom_minimum_size.x = 100
	pre_cinematic_edit.text_changed.connect(_on_pre_cinematic_changed)
	misc_row.add_child(pre_cinematic_edit)

	var post_cine_label: Label = Label.new()
	post_cine_label.text = "Post-Cinematic:"
	post_cine_label.custom_minimum_size.x = 95
	misc_row.add_child(post_cine_label)

	post_cinematic_edit = LineEdit.new()
	post_cinematic_edit.custom_minimum_size.x = 100
	post_cinematic_edit.text_changed.connect(_on_post_cinematic_changed)
	misc_row.add_child(post_cinematic_edit)

	inspector_panel.add_child(misc_row)

	parent.add_child(inspector_scroll)


## Public refresh method for standard editor interface
func refresh() -> void:
	_refresh_campaign_list()


func _refresh_campaign_list() -> void:
	campaign_list.clear()

	var mods_dir: DirAccess = DirAccess.open("res://mods/")
	if not mods_dir:
		return

	mods_dir.list_dir_begin()
	var mod_name: String = mods_dir.get_next()

	while mod_name != "":
		if mods_dir.current_is_dir() and not mod_name.begins_with("."):
			var camp_path: String = "res://mods/%s/data/campaigns/" % mod_name
			var camp_dir: DirAccess = DirAccess.open(camp_path)

			if camp_dir:
				camp_dir.list_dir_begin()
				var file_name: String = camp_dir.get_next()

				while file_name != "":
					if file_name.ends_with(".json"):
						var display: String = "[%s] %s" % [mod_name, file_name.get_basename()]
						var full_path: String = camp_path + file_name
						campaign_list.add_item(display)
						campaign_list.set_item_metadata(campaign_list.item_count - 1, full_path)
					file_name = camp_dir.get_next()

				camp_dir.list_dir_end()

		mod_name = mods_dir.get_next()

	mods_dir.list_dir_end()


func _on_campaign_selected(index: int) -> void:
	var path: String = campaign_list.get_item_metadata(index)
	_load_campaign(path)


func _load_campaign(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		_show_errors(["Failed to open: " + path])
		return

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var err: Error = json.parse(json_text)
	if err != OK:
		_show_errors(["JSON parse error: " + json.get_error_message()])
		return

	current_campaign_path = path
	current_campaign_data = json.data
	_populate_form()
	_rebuild_graph()
	_hide_errors()


func _populate_form() -> void:
	_updating_ui = true

	campaign_id_edit.text = current_campaign_data.get("campaign_id", "")
	campaign_name_edit.text = current_campaign_data.get("campaign_name", "")
	# Note: description_edit not in compact UI, skip assignment
	version_edit.text = current_campaign_data.get("campaign_version", "1.0.0")

	_update_node_dropdowns()

	_updating_ui = false


func _update_node_dropdowns() -> void:
	var nodes: Array = current_campaign_data.get("nodes", [])
	var starting_id: String = current_campaign_data.get("starting_node_id", "")
	var hub_id: String = current_campaign_data.get("default_hub_id", "")

	# Update starting node dropdown
	starting_node_option.clear()
	starting_node_option.add_item("(None)", -1)

	# Update default hub dropdown
	default_hub_option.clear()
	default_hub_option.add_item("(None)", -1)

	# Update transition dropdowns
	on_victory_option.clear()
	on_victory_option.add_item("(None)", -1)
	on_defeat_option.clear()
	on_defeat_option.add_item("(None)", -1)
	on_complete_option.clear()
	on_complete_option.add_item("(None)", -1)

	var starting_index: int = 0
	var hub_index: int = 0

	for i in range(nodes.size()):
		var node: Dictionary = nodes[i]
		var node_id: String = node.get("node_id", "")
		var display: String = node.get("display_name", node_id)

		starting_node_option.add_item(display, i)
		starting_node_option.set_item_metadata(i + 1, node_id)

		default_hub_option.add_item(display, i)
		default_hub_option.set_item_metadata(i + 1, node_id)

		on_victory_option.add_item(display, i)
		on_victory_option.set_item_metadata(i + 1, node_id)

		on_defeat_option.add_item(display, i)
		on_defeat_option.set_item_metadata(i + 1, node_id)

		on_complete_option.add_item(display, i)
		on_complete_option.set_item_metadata(i + 1, node_id)

		if node_id == starting_id:
			starting_index = i + 1
		if node_id == hub_id:
			hub_index = i + 1

	starting_node_option.select(starting_index)
	default_hub_option.select(hub_index)


func _rebuild_graph() -> void:
	# Clear existing graph
	for child in graph_edit.get_children():
		if child is GraphNode:
			child.queue_free()
	graph_nodes.clear()
	graph_edit.clear_connections()

	var nodes: Array = current_campaign_data.get("nodes", [])
	var starting_id: String = current_campaign_data.get("starting_node_id", "")

	# Create graph nodes
	for i in range(nodes.size()):
		var node_data: Dictionary = nodes[i]
		var graph_node: GraphNode = _create_graph_node(node_data, i, starting_id)
		graph_edit.add_child(graph_node)
		graph_nodes[node_data.get("node_id", "")] = graph_node

	# Create connections after all nodes exist
	call_deferred("_create_connections")


func _create_graph_node(node_data: Dictionary, index: int, starting_id: String) -> GraphNode:
	var graph_node: GraphNode = GraphNode.new()
	var node_id: String = node_data.get("node_id", "node_%d" % index)
	var node_type: String = node_data.get("node_type", "scene")
	var display_name: String = node_data.get("display_name", node_id)
	var is_hub: bool = node_data.get("is_hub", false)
	var is_start: bool = (node_id == starting_id)

	graph_node.name = node_id
	graph_node.title = display_name

	# Position from stored data or auto-layout
	var pos_x: float = node_data.get("_editor_pos_x", index % 4 * 200)
	var pos_y: float = node_data.get("_editor_pos_y", int(index / 4) * 150)
	graph_node.position_offset = Vector2(pos_x, pos_y)

	# Color based on type
	var base_color: Color = NODE_COLORS.get(node_type, Color(0.5, 0.5, 0.5))

	# Create custom stylebox
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = base_color
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)

	# Hub nodes get green border
	if is_hub:
		style.border_color = HUB_BORDER_COLOR
		style.set_border_width_all(3)

	# Start node gets special indicator
	if is_start:
		style.border_color = START_NODE_COLOR
		style.set_border_width_all(4)

	graph_node.add_theme_stylebox_override("panel", style)

	# Add type label
	var type_label: Label = Label.new()
	type_label.text = node_type.to_upper()
	type_label.add_theme_font_size_override("font_size", 16)
	type_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	graph_node.add_child(type_label)

	# Add ID label
	var id_label: Label = Label.new()
	id_label.text = "ID: " + node_id
	id_label.add_theme_font_size_override("font_size", 16)
	id_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	graph_node.add_child(id_label)

	# Configure slots based on node type
	# Input slot (left) - any node can receive connections
	graph_node.set_slot(0, true, 0, Color.WHITE, false, 0, Color.WHITE)

	# Output slots (right) based on type
	if node_type == "battle":
		# Battles have victory, defeat, complete outputs
		graph_node.set_slot(1, false, 0, Color.WHITE, true, 0, Color(0.3, 0.8, 0.3))  # Victory (green)
		var defeat_slot: Label = Label.new()
		defeat_slot.text = ""
		graph_node.add_child(defeat_slot)
		graph_node.set_slot(2, false, 0, Color.WHITE, true, 1, Color(0.8, 0.3, 0.3))  # Defeat (red)
	else:
		# Other nodes just have on_complete
		graph_node.set_slot(1, false, 0, Color.WHITE, true, 0, Color.WHITE)

	# Store node data reference
	graph_node.set_meta("node_data", node_data)
	graph_node.set_meta("node_index", index)

	# Connect position change
	graph_node.position_offset_changed.connect(_on_node_position_changed.bind(node_id))

	return graph_node


func _create_connections() -> void:
	var nodes: Array = current_campaign_data.get("nodes", [])

	for node_data: Dictionary in nodes:
		var from_id: String = node_data.get("node_id", "")
		var node_type: String = node_data.get("node_type", "scene")

		if from_id not in graph_nodes:
			continue

		# Port indices are sequential per side (0, 1, 2...), not slot indices
		# Battle nodes: port 0 = victory, port 1 = defeat
		# Other nodes: port 0 = on_complete
		if node_type == "battle":
			# Victory connection (right port 0)
			var victory_target: String = node_data.get("on_victory", "")
			if not victory_target.is_empty() and victory_target in graph_nodes:
				graph_edit.connect_node(from_id, 0, victory_target, 0)

			# Defeat connection (right port 1)
			var defeat_target: String = node_data.get("on_defeat", "")
			if not defeat_target.is_empty() and defeat_target in graph_nodes:
				graph_edit.connect_node(from_id, 1, defeat_target, 0)
		else:
			# on_complete connection (right port 0)
			var complete_target: String = node_data.get("on_complete", "")
			if not complete_target.is_empty() and complete_target in graph_nodes:
				graph_edit.connect_node(from_id, 0, complete_target, 0)


func _on_graph_node_selected(node: Node) -> void:
	if node is GraphNode:
		selected_node_id = node.name
		_populate_node_inspector()


func _on_graph_node_deselected(node: Node) -> void:
	selected_node_id = ""
	_clear_node_inspector()


func _populate_node_inspector() -> void:
	if selected_node_id.is_empty():
		return

	_updating_ui = true

	var node_data: Dictionary = _get_node_data(selected_node_id)
	if node_data.is_empty():
		_updating_ui = false
		return

	node_id_edit.text = node_data.get("node_id", "")
	node_name_edit.text = node_data.get("display_name", "")

	var node_type: String = node_data.get("node_type", "scene")
	for i in range(NODE_TYPES.size()):
		if NODE_TYPES[i] == node_type:
			node_type_option.select(i)
			break

	resource_id_edit.text = node_data.get("resource_id", "")
	scene_path_edit.text = node_data.get("scene_path", "")

	# Update transition dropdowns with current selection
	_select_transition_target(on_victory_option, node_data.get("on_victory", ""))
	_select_transition_target(on_defeat_option, node_data.get("on_defeat", ""))
	_select_transition_target(on_complete_option, node_data.get("on_complete", ""))

	is_hub_check.button_pressed = node_data.get("is_hub", false)
	is_chapter_boundary_check.button_pressed = node_data.get("is_chapter_boundary", false)
	allow_egress_check.button_pressed = node_data.get("allow_egress", true)
	retain_xp_check.button_pressed = node_data.get("retain_xp_on_defeat", true)
	repeatable_check.button_pressed = node_data.get("repeatable", false)
	defeat_penalty_spin.value = node_data.get("defeat_gold_penalty", 0.5)

	pre_cinematic_edit.text = node_data.get("pre_cinematic_id", "")
	post_cinematic_edit.text = node_data.get("post_cinematic_id", "")

	_updating_ui = false


func _select_transition_target(option: OptionButton, target_id: String) -> void:
	if target_id.is_empty():
		option.select(0)
		return

	for i in range(1, option.item_count):
		if option.get_item_metadata(i) == target_id:
			option.select(i)
			return

	option.select(0)


func _clear_node_inspector() -> void:
	_updating_ui = true
	node_id_edit.text = ""
	node_name_edit.text = ""
	node_type_option.select(0)
	resource_id_edit.text = ""
	scene_path_edit.text = ""
	on_victory_option.select(0)
	on_defeat_option.select(0)
	on_complete_option.select(0)
	is_hub_check.button_pressed = false
	is_chapter_boundary_check.button_pressed = false
	allow_egress_check.button_pressed = true
	retain_xp_check.button_pressed = true
	repeatable_check.button_pressed = false
	defeat_penalty_spin.value = 0.5
	pre_cinematic_edit.text = ""
	post_cinematic_edit.text = ""
	_updating_ui = false


func _get_node_data(node_id: String) -> Dictionary:
	var nodes: Array = current_campaign_data.get("nodes", [])
	for node: Dictionary in nodes:
		if node.get("node_id", "") == node_id:
			return node
	return {}


func _get_node_index(node_id: String) -> int:
	var nodes: Array = current_campaign_data.get("nodes", [])
	for i in range(nodes.size()):
		if nodes[i].get("node_id", "") == node_id:
			return i
	return -1


func _update_node_data(node_id: String, key: String, value: Variant) -> void:
	if _updating_ui:
		return

	var index: int = _get_node_index(node_id)
	if index < 0:
		return

	var nodes: Array = current_campaign_data.get("nodes", [])
	nodes[index][key] = value


# Node inspector change handlers
func _on_node_id_changed(new_text: String) -> void:
	if _updating_ui or selected_node_id.is_empty():
		return

	var old_id: String = selected_node_id
	_update_node_data(old_id, "node_id", new_text)

	# Update graph node name
	if old_id in graph_nodes:
		var gn: GraphNode = graph_nodes[old_id]
		gn.name = new_text
		graph_nodes.erase(old_id)
		graph_nodes[new_text] = gn

	selected_node_id = new_text
	_update_node_dropdowns()


func _on_node_name_changed(new_text: String) -> void:
	_update_node_data(selected_node_id, "display_name", new_text)
	if selected_node_id in graph_nodes:
		graph_nodes[selected_node_id].title = new_text
	_update_node_dropdowns()


func _on_node_type_changed(index: int) -> void:
	if _updating_ui:
		return
	var new_type: String = NODE_TYPES[index]
	_update_node_data(selected_node_id, "node_type", new_type)
	_rebuild_graph()  # Rebuild to update colors and slots


func _on_resource_id_changed(new_text: String) -> void:
	_update_node_data(selected_node_id, "resource_id", new_text)


func _on_scene_path_changed(new_text: String) -> void:
	_update_node_data(selected_node_id, "scene_path", new_text)


func _on_victory_target_changed(index: int) -> void:
	if _updating_ui:
		return
	var target: String = "" if index == 0 else on_victory_option.get_item_metadata(index)
	_update_node_data(selected_node_id, "on_victory", target)
	_rebuild_graph()


func _on_defeat_target_changed(index: int) -> void:
	if _updating_ui:
		return
	var target: String = "" if index == 0 else on_defeat_option.get_item_metadata(index)
	_update_node_data(selected_node_id, "on_defeat", target)
	_rebuild_graph()


func _on_complete_target_changed(index: int) -> void:
	if _updating_ui:
		return
	var target: String = "" if index == 0 else on_complete_option.get_item_metadata(index)
	_update_node_data(selected_node_id, "on_complete", target)
	_rebuild_graph()


func _on_is_hub_toggled(pressed: bool) -> void:
	_update_node_data(selected_node_id, "is_hub", pressed)
	_rebuild_graph()


func _on_chapter_boundary_toggled(pressed: bool) -> void:
	_update_node_data(selected_node_id, "is_chapter_boundary", pressed)


func _on_allow_egress_toggled(pressed: bool) -> void:
	_update_node_data(selected_node_id, "allow_egress", pressed)


func _on_retain_xp_toggled(pressed: bool) -> void:
	_update_node_data(selected_node_id, "retain_xp_on_defeat", pressed)


func _on_repeatable_toggled(pressed: bool) -> void:
	_update_node_data(selected_node_id, "repeatable", pressed)


func _on_defeat_penalty_changed(value: float) -> void:
	_update_node_data(selected_node_id, "defeat_gold_penalty", value)


func _on_pre_cinematic_changed(new_text: String) -> void:
	_update_node_data(selected_node_id, "pre_cinematic_id", new_text)


func _on_post_cinematic_changed(new_text: String) -> void:
	_update_node_data(selected_node_id, "post_cinematic_id", new_text)


func _on_starting_node_changed(index: int) -> void:
	if _updating_ui:
		return
	var node_id: String = "" if index == 0 else starting_node_option.get_item_metadata(index)
	current_campaign_data["starting_node_id"] = node_id
	_rebuild_graph()


func _on_default_hub_changed(index: int) -> void:
	if _updating_ui:
		return
	var node_id: String = "" if index == 0 else default_hub_option.get_item_metadata(index)
	current_campaign_data["default_hub_id"] = node_id


func _on_node_position_changed(node_id: String) -> void:
	if node_id not in graph_nodes:
		return
	var gn: GraphNode = graph_nodes[node_id]
	var index: int = _get_node_index(node_id)
	if index >= 0:
		var nodes: Array = current_campaign_data.get("nodes", [])
		nodes[index]["_editor_pos_x"] = gn.position_offset.x
		nodes[index]["_editor_pos_y"] = gn.position_offset.y


func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	# Determine which transition type based on from_port (port indices, not slot indices)
	# Battle nodes: port 0 = victory, port 1 = defeat
	# Other nodes: port 0 = on_complete
	var from_data: Dictionary = _get_node_data(String(from_node))
	var node_type: String = from_data.get("node_type", "scene")

	var target_id: String = String(to_node)

	if node_type == "battle":
		if from_port == 0:  # Victory (port 0)
			_update_node_data(String(from_node), "on_victory", target_id)
		elif from_port == 1:  # Defeat (port 1)
			_update_node_data(String(from_node), "on_defeat", target_id)
	else:
		# on_complete (port 0)
		_update_node_data(String(from_node), "on_complete", target_id)

	graph_edit.connect_node(from_node, from_port, to_node, to_port)
	_update_node_dropdowns()
	_populate_node_inspector()


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	# Port indices: Battle nodes use port 0 = victory, port 1 = defeat
	# Other nodes use port 0 = on_complete
	var from_data: Dictionary = _get_node_data(String(from_node))
	var node_type: String = from_data.get("node_type", "scene")

	if node_type == "battle":
		if from_port == 0:
			_update_node_data(String(from_node), "on_victory", "")
		elif from_port == 1:
			_update_node_data(String(from_node), "on_defeat", "")
	else:
		_update_node_data(String(from_node), "on_complete", "")

	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	_update_node_dropdowns()
	_populate_node_inspector()


func _on_add_node() -> void:
	if "nodes" not in current_campaign_data:
		current_campaign_data["nodes"] = []

	var nodes: Array = current_campaign_data["nodes"]
	var new_index: int = nodes.size()
	var new_id: String = "node_%d" % new_index

	var new_node: Dictionary = {
		"node_id": new_id,
		"display_name": "New Node",
		"node_type": "scene",
		"_editor_pos_x": (new_index % 4) * 200,
		"_editor_pos_y": int(new_index / 4) * 150
	}

	nodes.append(new_node)
	_update_node_dropdowns()
	_rebuild_graph()


func _on_delete_node() -> void:
	if selected_node_id.is_empty():
		return

	var index: int = _get_node_index(selected_node_id)
	if index < 0:
		return

	var nodes: Array = current_campaign_data.get("nodes", [])

	# Remove references to this node from other nodes
	for node: Dictionary in nodes:
		if node.get("on_victory", "") == selected_node_id:
			node["on_victory"] = ""
		if node.get("on_defeat", "") == selected_node_id:
			node["on_defeat"] = ""
		if node.get("on_complete", "") == selected_node_id:
			node["on_complete"] = ""

	# Clear starting/hub if pointing to deleted node
	if current_campaign_data.get("starting_node_id", "") == selected_node_id:
		current_campaign_data["starting_node_id"] = ""
	if current_campaign_data.get("default_hub_id", "") == selected_node_id:
		current_campaign_data["default_hub_id"] = ""

	nodes.remove_at(index)
	selected_node_id = ""
	_clear_node_inspector()
	_update_node_dropdowns()
	_rebuild_graph()


func _on_create_new() -> void:
	if not ModLoader:
		_show_errors(["ModLoader not available"])
		return

	var active_mod: ModManifest = ModLoader.get_active_mod()
	if not active_mod:
		_show_errors(["No active mod selected"])
		return

	current_campaign_data = {
		"campaign_id": "%s:new_campaign" % active_mod.mod_id,
		"campaign_name": "New Campaign",
		"campaign_description": "",
		"campaign_version": "1.0.0",
		"starting_node_id": "",
		"default_hub_id": "",
		"initial_flags": {},
		"chapters": [],
		"nodes": []
	}

	var camp_dir: String = "res://mods/%s/data/campaigns/" % active_mod.mod_id
	var dir: DirAccess = DirAccess.open("res://mods/%s/data/" % active_mod.mod_id)
	if dir and not dir.dir_exists("campaigns"):
		dir.make_dir("campaigns")

	current_campaign_path = camp_dir + "new_campaign.json"
	_populate_form()
	_rebuild_graph()
	_hide_errors()


func _on_save() -> void:
	if current_campaign_path.is_empty():
		_show_errors(["No campaign loaded"])
		return

	_collect_metadata_from_ui()

	var errors: Array[String] = _validate()
	if errors.size() > 0:
		_show_errors(errors)
		return

	var json_text: String = JSON.stringify(current_campaign_data, "\t")
	var file: FileAccess = FileAccess.open(current_campaign_path, FileAccess.WRITE)
	if not file:
		_show_errors(["Failed to write: " + current_campaign_path])
		return

	file.store_string(json_text)
	file.close()

	_hide_errors()
	_refresh_campaign_list()

	# Notify that a campaign was saved (not mods_reloaded - that's for mod manifest changes)
	var event_bus: Node = get_node_or_null("/root/EditorEventBus")
	if event_bus:
		var campaign_id: String = current_campaign_data.get("campaign_id", "")
		event_bus.resource_saved.emit("campaign", campaign_id, null)


func _collect_metadata_from_ui() -> void:
	current_campaign_data["campaign_id"] = campaign_id_edit.text.strip_edges()
	current_campaign_data["campaign_name"] = campaign_name_edit.text.strip_edges()
	current_campaign_data["campaign_version"] = version_edit.text.strip_edges()


func _validate() -> Array[String]:
	var errors: Array[String] = []

	if current_campaign_data.get("campaign_id", "").is_empty():
		errors.append("Campaign ID is required")
	if current_campaign_data.get("campaign_name", "").is_empty():
		errors.append("Campaign name is required")

	var nodes: Array = current_campaign_data.get("nodes", [])
	if nodes.size() > 0 and current_campaign_data.get("starting_node_id", "").is_empty():
		errors.append("Starting node is required when nodes exist")

	# Check for duplicate node IDs
	var seen_ids: Dictionary = {}
	for node: Dictionary in nodes:
		var nid: String = node.get("node_id", "")
		if nid in seen_ids:
			errors.append("Duplicate node ID: " + nid)
		seen_ids[nid] = true

	return errors


func _show_errors(errors: Array[String]) -> void:
	error_label.text = "[color=white]" + "\n".join(errors) + "[/color]"
	error_panel.visible = true


func _hide_errors() -> void:
	error_panel.visible = false
