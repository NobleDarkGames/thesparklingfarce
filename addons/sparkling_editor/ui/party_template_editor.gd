@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Party Template Editor UI
## Design-time editor for PartyData resources (.tres files)
## Used for creating enemy formations, predefined party configurations, etc.

# Basic info
var party_name_edit: LineEdit
var description_edit: TextEdit
var max_size_spin: SpinBox

# Party Members
var members_container: VBoxContainer
var members_list: Array[Dictionary] = []  # Track member UI elements

# Available characters for selection
var available_characters: Array[CharacterData] = []


func _ready() -> void:
	resource_type_name = "Party"
	resource_type_id = "party"
	# Declare dependencies BEFORE super._ready() so base class can auto-subscribe
	resource_dependencies = ["character"]
	super._ready()
	_load_available_characters()


## Override: Called when dependent resource types change (via base class)
func _on_dependencies_changed(_changed_type: String) -> void:
	# Reload character dropdown when any character is created/saved/deleted
	_load_available_characters()


# ============================================================================
# UI CREATION (OVERRIDE BASE CLASS)
# ============================================================================

## Override: Create the party template editor form
func _create_detail_form() -> void:
	# Section 1: Basic Information
	_add_basic_info_section()

	# Section 2: Party Members
	_add_party_members_section()

	# Add the button container at the end (with separator for visual clarity)
	_add_button_container_to_detail_panel()


## Override: Load party data from resource into UI
func _load_resource_data() -> void:
	var party: PartyData = current_resource as PartyData
	if not party:
		return

	party_name_edit.text = party.party_name
	description_edit.text = party.description
	max_size_spin.value = party.max_size

	# Clear and rebuild members list
	_clear_members_ui()
	for member_dict: Dictionary in party.members:
		_add_member_ui(member_dict)


## Override: Save UI data to resource
func _save_resource_data() -> void:
	var party: PartyData = current_resource as PartyData
	if not party:
		return

	# Update basic info
	party.party_name = party_name_edit.text
	party.description = description_edit.text
	party.max_size = int(max_size_spin.value)

	# Update members array from UI
	party.members.clear()
	for member_ui: Dictionary in members_list:
		var character_idx: int = member_ui.character_option.selected - 1
		if character_idx < 0 or character_idx >= available_characters.size():
			continue  # Skip if no character selected

		var member_dict: Dictionary = {
			"character": available_characters[character_idx],
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
	for member_ui: Dictionary in members_list:
		if member_ui.character_option.selected > 0:
			has_valid_member = true
			break

	if not has_valid_member:
		errors.append("Party must have at least one member")

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
func _get_resource_display_name(resource: Resource) -> String:
	var party: PartyData = resource as PartyData
	if party:
		var member_count: int = party.get_member_count()
		return "%s (%d/%d)" % [party.party_name, member_count, party.max_size]
	return "Unnamed Party"


# ============================================================================
# UI SECTIONS
# ============================================================================

## Section 1: Basic Information
func _add_basic_info_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Basic Information"
	section_label.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(section_label)

	var name_label: Label = Label.new()
	name_label.text = "Party Name:"
	detail_panel.add_child(name_label)

	party_name_edit = LineEdit.new()
	party_name_edit.placeholder_text = "Enter party name"
	detail_panel.add_child(party_name_edit)

	var desc_label: Label = Label.new()
	desc_label.text = "Description:"
	detail_panel.add_child(desc_label)

	description_edit = TextEdit.new()
	description_edit.custom_minimum_size = Vector2(0, 60)
	detail_panel.add_child(description_edit)

	var max_size_label: Label = Label.new()
	max_size_label.text = "Maximum Party Size:"
	detail_panel.add_child(max_size_label)

	max_size_spin = SpinBox.new()
	max_size_spin.min_value = 1
	max_size_spin.max_value = 12
	max_size_spin.value = 8
	detail_panel.add_child(max_size_spin)

	_add_separator()


## Section 2: Party Members
func _add_party_members_section() -> void:
	var section_label: Label = Label.new()
	section_label.text = "Party Members"
	section_label.add_theme_font_size_override("font_size", 16)
	detail_panel.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Add characters to this party. Formation offsets determine spawn positions."
	help_label.add_theme_color_override("font_color", EditorThemeUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", 14)
	detail_panel.add_child(help_label)

	members_container = VBoxContainer.new()
	detail_panel.add_child(members_container)

	var add_member_button: Button = Button.new()
	add_member_button.text = "+ Add Member"
	add_member_button.pressed.connect(_on_add_member)
	detail_panel.add_child(add_member_button)

	_add_separator()


## Add a visual separator
func _add_separator() -> void:
	var separator: HSeparator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 10)
	detail_panel.add_child(separator)


# ============================================================================
# CHARACTER LOADING
# ============================================================================

## Load all available characters from ALL loaded mods
func _load_available_characters() -> void:
	available_characters.clear()

	# Get ALL characters from ModRegistry (not just active mod!)
	if ModLoader and ModLoader.registry:
		var all_characters: Array[Resource] = ModLoader.registry.get_all_resources("character")

		# Convert to typed array
		for resource: Resource in all_characters:
			var char_data: CharacterData = resource as CharacterData
			if char_data:
				available_characters.append(char_data)
	else:
		push_warning("PartyTemplateEditor: ModLoader or registry not available")

	# Update all character dropdowns if we have any members
	for member_ui: Dictionary in members_list:
		_populate_character_dropdown(member_ui.character_option)


## Populate a character dropdown with available characters (with source mod prefix)
func _populate_character_dropdown(option_button: OptionButton) -> void:
	option_button.clear()
	option_button.add_item("(Select Character)", -1)

	for character: CharacterData in available_characters:
		var display_name: String = SparklingEditorUtils.get_character_display_name(character)
		option_button.add_item(display_name)


# ============================================================================
# MEMBER UI MANAGEMENT
# ============================================================================

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

	# Select the current character if present
	if "character" in member_dict and member_dict.character:
		for i: int in range(available_characters.size()):
			if available_characters[i] == member_dict.character:
				character_option.select(i + 1)
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
	offset_hbox.add_child(offset_x_spin)

	var offset_y_spin: SpinBox = SpinBox.new()
	offset_y_spin.min_value = -5
	offset_y_spin.max_value = 10
	offset_y_spin.value = 0
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
