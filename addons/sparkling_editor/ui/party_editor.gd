@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Party Editor UI
## Editor for PartyData resources - enemy formations, predefined party configurations, etc.
## For runtime save slot editing, use the Save Slot Editor.

# ============================================================================
# PARTY DATA EDITOR
# ============================================================================

# Basic info
var party_name_edit: LineEdit
var description_edit: TextEdit
var max_size_spin: SpinBox

# Party Members
var members_container: VBoxContainer
var members_list: Array[Dictionary] = []  # Track member UI elements

# No local character cache - query registry directly via dropdowns

# Flag to prevent signal feedback loops during UI updates
var _updating_ui: bool = false

# ============================================================================
# PHASE 7: DEFAULT PARTY WORKFLOW
# ============================================================================

# "Set as Default Starting Party" button
var set_default_party_button: Button

# Badge tracking - which parties are referenced by default configs
var default_party_ids: Array[String] = []
var active_default_party_id: String = ""


func _ready() -> void:
	resource_type_name = "Party"
	resource_type_id = "party"
	# Declare dependencies BEFORE super._ready() so base class can auto-subscribe
	resource_dependencies = ["character", "new_game_config"]
	super._ready()
	_load_default_party_info()


## Override: Called when dependent resource types change (via base class)
func _on_dependencies_changed(changed_type: String) -> void:
	# Refresh character dropdowns when characters change (query registry fresh)
	if changed_type == "character":
		for member_ui: Dictionary in members_list:
			_populate_character_dropdown(member_ui.character_option)
	# Refresh default party info when configs change
	if changed_type == "new_game_config":
		_load_default_party_info()
		_apply_filter()  # Refresh list to update badges


# ============================================================================
# UI CREATION (OVERRIDE BASE CLASS)
# ============================================================================

## Override: Create the party editor form
func _create_detail_form() -> void:
	# Section 1: Basic Information
	_add_basic_info_section()

	# Section 2: Party Members
	_add_party_members_section()

	# Add the button container at the end
	_add_button_container_to_detail_panel()


# ============================================================================
# PARTY EDITOR FUNCTIONALITY
# ============================================================================

## Override: Load party data from resource into UI
func _load_resource_data() -> void:
	var party: PartyData = current_resource as PartyData
	if not party:
		return

	_updating_ui = true

	party_name_edit.text = party.party_name
	description_edit.text = party.description
	max_size_spin.value = party.max_size

	# Clear and rebuild members list
	_clear_members_ui()
	for member_dict: Dictionary in party.members:
		_add_member_ui(member_dict)

	_updating_ui = false


## Override: Save UI data to resource
func _save_resource_data() -> void:
	var party: PartyData = current_resource as PartyData
	if not party:
		return

	# Update basic info
	party.party_name = party_name_edit.text
	party.description = description_edit.text
	party.max_size = int(max_size_spin.value)

	# Update members array from UI - get character from dropdown metadata
	party.members.clear()
	for member_ui: Dictionary in members_list:
		var option: OptionButton = member_ui.character_option
		var selected_idx: int = option.selected
		if selected_idx <= 0:
			continue  # Skip if "(Select Character)" or invalid

		var character: CharacterData = option.get_item_metadata(selected_idx) as CharacterData
		if not character:
			continue

		var member_dict: Dictionary = {
			"character": character,
			"formation_offset": Vector2i(
				int(member_ui.offset_x_spin.value),
				int(member_ui.offset_y_spin.value)
			)
		}
		party.members.append(member_dict)


## Override: Validate resource before saving
func _validate_resource() -> Dictionary:
	var errors: Array[String] = []

	if party_name_edit.text.strip_edges().is_empty():
		errors.append("Party name cannot be empty")

	# Validate that at least one member is selected
	var has_valid_member: bool = false
	var empty_slots: int = 0
	for member_ui: Dictionary in members_list:
		if member_ui.character_option.selected > 0:
			has_valid_member = true
		else:
			empty_slots += 1

	if not has_valid_member:
		errors.append("Party must have at least one member")

	# Warn about empty slots that will be removed on save
	if empty_slots > 0 and has_valid_member:
		push_warning("PartyEditor: %d member slot(s) have no character selected and will be removed on save" % empty_slots)

	return {
		"valid": errors.is_empty(),
		"errors": errors
	}


## Override: Create a new party with defaults
func _create_new_resource() -> Resource:
	var party: PartyData = PartyData.new()
	party.party_name = "New Party"
	party.description = ""
	party.max_size = 8
	party.members = []
	return party


## Override: Get display name from resource
## Phase 7.3: Shows [ACTIVE DEFAULT] badge for the party that will be used at game start
func _get_resource_display_name(resource: Resource) -> String:
	var party: PartyData = resource as PartyData
	if party:
		var member_count: int = party.get_member_count()
		var base_name: String = "%s (%d/%d)" % [party.party_name, member_count, party.max_size]

		# Phase 7.3: Add badge if this is the active default starting party
		var party_id: String = resource.resource_path.get_file().get_basename()
		if party_id == active_default_party_id:
			return base_name + " [ACTIVE DEFAULT]"
		elif party_id in default_party_ids:
			return base_name + " [DEFAULT]"

		return base_name
	return "Unnamed Party"


## Section 1: Basic Information
func _add_basic_info_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Basic Information"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	detail_panel.add_child(section_label)

	var name_label: Label = Label.new()
	name_label.text = "Party Name:"
	detail_panel.add_child(name_label)

	party_name_edit = LineEdit.new()
	party_name_edit.max_length = 64  # Reasonable limit for UI display
	party_name_edit.placeholder_text = "Enter party name"
	party_name_edit.tooltip_text = "Display name for this party template. E.g., 'Starting Party', 'Boss Squad'."
	detail_panel.add_child(party_name_edit)

	var desc_label: Label = Label.new()
	desc_label.text = "Description:"
	detail_panel.add_child(desc_label)

	description_edit = TextEdit.new()
	description_edit.custom_minimum_size = Vector2(0, 60)
	description_edit.tooltip_text = "Optional notes about when/how this party is used. For modder reference."
	detail_panel.add_child(description_edit)

	var max_size_label: Label = Label.new()
	max_size_label.text = "Maximum Party Size:"
	detail_panel.add_child(max_size_label)

	max_size_spin = SpinBox.new()
	max_size_spin.min_value = 1
	max_size_spin.max_value = 12
	max_size_spin.value = 8
	max_size_spin.tooltip_text = "Maximum members allowed in this party. Typical: 8 for Shining Force style, 12 for larger battles."
	detail_panel.add_child(max_size_spin)

	_add_separator_to_panel(detail_panel)


## Section 2: Party Members
func _add_party_members_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Party Members"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	detail_panel.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Add characters to this party. Formation offsets determine spawn positions."
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	detail_panel.add_child(help_label)

	members_container = VBoxContainer.new()
	detail_panel.add_child(members_container)

	var add_member_button: Button = Button.new()
	add_member_button.text = "+ Add Member"
	add_member_button.tooltip_text = "Add a character slot to this party template."
	add_member_button.pressed.connect(_on_add_member)
	detail_panel.add_child(add_member_button)

	_add_separator_to_panel(detail_panel)

	# Phase 7.2: "Set as Default Starting Party" button
	_add_default_party_section()


## Populate a character dropdown with available characters - queries registry directly
func _populate_character_dropdown(option_button: OptionButton) -> void:
	# Save current selection if any
	var current_character: CharacterData = null
	if option_button.selected > 0:
		current_character = option_button.get_item_metadata(option_button.selected) as CharacterData

	option_button.clear()
	option_button.add_item("(Select Character)", -1)

	# Query registry fresh each time
	if ModLoader and ModLoader.registry:
		var all_characters: Array[Resource] = ModLoader.registry.get_all_resources("character")
		var idx: int = 1
		for char_data: CharacterData in all_characters:
			if char_data:
				var display_name: String = SparklingEditorUtils.get_character_display_name(char_data)
				option_button.add_item(display_name, idx - 1)
				option_button.set_item_metadata(idx, char_data)
				# Restore selection if this was the previously selected character
				if current_character and char_data.resource_path == current_character.resource_path:
					option_button.select(idx)
				idx += 1


## Add a new member UI element
func _on_add_member() -> void:
	_add_member_ui({})


## Add a member UI row (for existing or new member)
func _add_member_ui(member_dict: Dictionary) -> void:
	var member_panel: PanelContainer = PanelContainer.new()
	var member_vbox: VBoxContainer = VBoxContainer.new()
	member_panel.add_child(member_vbox)

	# Character selector
	var char_label: Label = Label.new()
	char_label.text = "Character:"
	member_vbox.add_child(char_label)

	var character_option: OptionButton = OptionButton.new()
	_populate_character_dropdown(character_option)

	# Select the current character if present - search by metadata
	if "character" in member_dict and member_dict.character:
		var target_path: String = member_dict.character.resource_path
		for i: int in range(character_option.item_count):
			var metadata: Variant = character_option.get_item_metadata(i)
			if metadata is CharacterData and metadata.resource_path == target_path:
				character_option.select(i)
				break

	member_vbox.add_child(character_option)

	# Formation offset
	var offset_label: Label = Label.new()
	offset_label.text = "Formation Offset (X, Y):"
	member_vbox.add_child(offset_label)

	var offset_hbox: HBoxContainer = HBoxContainer.new()
	member_vbox.add_child(offset_hbox)

	var offset_x_spin: SpinBox = SpinBox.new()
	offset_x_spin.min_value = -5
	offset_x_spin.max_value = 10
	offset_x_spin.value = 0
	offset_x_spin.tooltip_text = "X offset from party spawn point. 0 = center. Negative = left, positive = right."
	offset_hbox.add_child(offset_x_spin)

	var offset_y_spin: SpinBox = SpinBox.new()
	offset_y_spin.min_value = -5
	offset_y_spin.max_value = 10
	offset_y_spin.value = 0
	offset_y_spin.tooltip_text = "Y offset from party spawn point. 0 = center. Negative = up, positive = down."
	offset_hbox.add_child(offset_y_spin)

	# Set current formation offset if present
	if "formation_offset" in member_dict:
		var offset: Vector2i = member_dict.formation_offset
		offset_x_spin.value = offset.x
		offset_y_spin.value = offset.y

	# Remove button
	var remove_button: Button = Button.new()
	remove_button.text = "Remove Member"
	member_vbox.add_child(remove_button)

	# Store UI references
	var member_ui: Dictionary = {
		"panel": member_panel,
		"character_option": character_option,
		"offset_x_spin": offset_x_spin,
		"offset_y_spin": offset_y_spin,
		"remove_button": remove_button
	}

	# Connect remove button
	remove_button.pressed.connect(_on_remove_member.bind(member_ui))

	members_list.append(member_ui)
	members_container.add_child(member_panel)


## Remove a member from the UI
func _on_remove_member(member_ui: Dictionary) -> void:
	var index: int = members_list.find(member_ui)
	if index >= 0:
		members_list.remove_at(index)
		member_ui.panel.queue_free()


## Clear all member UI elements
func _clear_members_ui() -> void:
	for member_ui: Dictionary in members_list:
		member_ui.panel.queue_free()
	members_list.clear()


## Add a visual separator
func _add_separator_to_panel(panel: Control) -> void:
	var separator: HSeparator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 10)
	panel.add_child(separator)


# ============================================================================
# PHASE 7: DEFAULT PARTY WORKFLOW
# ============================================================================

## Add the "Set as Default Starting Party" section to Template Parties tab
func _add_default_party_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "New Game Configuration"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	detail_panel.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Configure this party as the default starting party for new games in your mod."
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_panel.add_child(help_label)

	set_default_party_button = Button.new()
	set_default_party_button.text = "Set as Default Starting Party"
	set_default_party_button.tooltip_text = "Set this party as the starting party for new games in your mod's NewGameConfigData"
	set_default_party_button.pressed.connect(_on_set_default_party)
	detail_panel.add_child(set_default_party_button)

	_add_separator_to_panel(detail_panel)


## Load information about which parties are set as defaults in configs
func _load_default_party_info() -> void:
	default_party_ids.clear()
	active_default_party_id = ""

	if not ModLoader or not ModLoader.registry:
		return

	# Get all NewGameConfigData resources
	var all_configs: Array[Resource] = ModLoader.registry.get_all_resources("new_game_config")

	# Track the highest priority default config
	var highest_priority: int = -1
	var highest_priority_party_id: String = ""

	for resource: Resource in all_configs:
		var ngc: NewGameConfigData = resource as NewGameConfigData
		if not ngc:
			push_warning("PartyEditor: Skipping non-NewGameConfigData resource: %s" % resource.resource_path)
			continue

		if ngc.starting_party_id.is_empty():
			continue

		# Track all configs that reference parties
		if ngc.starting_party_id not in default_party_ids:
			default_party_ids.append(ngc.starting_party_id)

		# Find the active default (highest priority mod with is_default = true)
		if ngc.is_default:
			var source_mod: String = ModLoader.registry.get_resource_source(ngc.config_id)
			var mod_manifest: ModManifest = ModLoader.get_mod(source_mod) if source_mod else null
			var priority: int = mod_manifest.load_priority if mod_manifest else 0

			if priority > highest_priority:
				highest_priority = priority
				highest_priority_party_id = ngc.starting_party_id

	active_default_party_id = highest_priority_party_id


## Handle "Set as Default Starting Party" button press
func _on_set_default_party() -> void:
	if not current_resource:
		_show_error("No party selected")
		return

	var party: PartyData = current_resource as PartyData
	if not party:
		_show_error("Invalid party resource")
		return

	if not ModLoader:
		_show_error("ModLoader not available")
		return

	var active_mod: ModManifest = ModLoader.get_active_mod()
	if not active_mod:
		_show_error("No active mod selected")
		return

	# Get the party's ID (filename)
	var party_id: String = current_resource.resource_path.get_file().get_basename()

	# Find or create the mod's default NewGameConfigData
	var config: NewGameConfigData = _get_or_create_default_config(active_mod)
	if not config:
		_show_error("Failed to get or create default config")
		return

	# Update the config
	config.starting_party_id = party_id
	config.is_default = true

	# Save the config
	var config_path: String = config.resource_path
	if config_path.is_empty():
		# New config - need to save to a file
		var config_dir: String = "res://mods/%s/data/new_game_configs/" % active_mod.mod_id
		# Ensure directory exists
		DirAccess.make_dir_recursive_absolute(config_dir)
		config_path = config_dir.path_join("default_config.tres")

	var err: Error = ResourceSaver.save(config, config_path)
	if err == OK:
		# Update registry
		var config_id: String = config_path.get_file().get_basename()
		if ModLoader.registry:
			ModLoader.registry.register_resource(config, "new_game_config", config_id, active_mod.mod_id)

		# Notify other editors
		var event_bus: Node = get_node_or_null("/root/EditorEventBus")
		if event_bus:
			event_bus.notify_resource_saved("new_game_config", config_path, config)

		# Refresh our default party info
		_load_default_party_info()
		_apply_filter()  # Refresh list to update badges

		_show_success_message("Party '%s' set as default starting party!" % party.party_name)
	else:
		_show_error("Failed to save config: " + error_string(err))


## Get or create the default NewGameConfigData for the active mod
func _get_or_create_default_config(active_mod: ModManifest) -> NewGameConfigData:
	var config_dir: String = "res://mods/%s/data/new_game_configs/" % active_mod.mod_id

	# First, look for an existing default config in this mod
	var dir: DirAccess = DirAccess.open(config_dir)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var full_path: String = config_dir.path_join(file_name)
				var resource: Resource = load(full_path)
				if resource is NewGameConfigData:
					var config: NewGameConfigData = resource as NewGameConfigData
					if config.is_default:
						# Found existing default - use it
						return config
			file_name = dir.get_next()
		dir.list_dir_end()

	# No existing default found - look for any config to use
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var full_path: String = config_dir.path_join(file_name)
				var resource: Resource = load(full_path)
				if resource is NewGameConfigData:
					# Use this config and make it default
					return resource as NewGameConfigData
			file_name = dir.get_next()
		dir.list_dir_end()

	# No configs exist - create a new one
	var config: NewGameConfigData = NewGameConfigData.new()
	config.config_id = "default"
	config.config_name = active_mod.mod_name + " Default"
	config.config_description = "Default starting configuration for " + active_mod.mod_name
	config.is_default = true
	config.starting_location_label = "Prologue"
	config.starting_gold = 0
	config.starting_depot_items = []
	config.starting_story_flags = {}
	config.caravan_unlocked = false

	return config


## Show success message (wrapper for base class)
func _show_success_message(message: String) -> void:
	# If we have the error panel, use it with success styling
	if error_panel and error_label:
		var success_color: Color = SparklingEditorUtils.get_success_color()
		error_label.text = "[color=#%s][b]Success:[/b] %s[/color]" % [success_color.to_html(false), message]

		# Apply success panel style
		var success_style: StyleBoxFlat = SparklingEditorUtils.create_success_panel_style()
		error_panel.add_theme_stylebox_override("panel", success_style)

		# Insert error panel just before button_container
		_position_error_panel_before_buttons()

		error_panel.show()

		# Auto-dismiss after 3 seconds
		var tween: Tween = create_tween()
		tween.tween_interval(3.0)
		tween.tween_callback(_hide_success_panel)


## Hide success panel and restore error styling
func _hide_success_panel() -> void:
	if error_panel:
		error_panel.hide()
	if error_label:
		error_label.text = ""

	# Restore error styling for next use
	if error_panel:
		var error_style: StyleBoxFlat = SparklingEditorUtils.create_error_panel_style()
		error_panel.add_theme_stylebox_override("panel", error_style)


## Show a single error message
func _show_error(message: String) -> void:
	push_error("PartyEditor: " + message)
	_show_errors([message])
