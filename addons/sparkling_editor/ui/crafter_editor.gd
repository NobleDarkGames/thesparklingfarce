@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Crafter Editor UI
## Allows creating and editing CrafterData resources with visual configuration
##
## Crafters are NPCs or locations that can perform crafting recipes.
## They have types (blacksmith, enchanter, etc.) and skill levels that
## determine which recipes they can perform.

# =============================================================================
# UI COMPONENTS
# =============================================================================

# Basic Info
var crafter_id_edit: LineEdit
var name_edit: LineEdit
var crafter_type_option: OptionButton
var crafter_type_custom_edit: LineEdit

# Capabilities
var skill_level_spin: SpinBox
var specializations_edit: LineEdit

# Location
var location_map_picker: ResourcePicker
var location_x_spin: SpinBox
var location_y_spin: SpinBox

# NPC Link
var character_picker: ResourcePicker

# Availability
var required_flags_edit: LineEdit
var forbidden_flags_edit: LineEdit

# Economy
var service_fee_spin: SpinBox

# Description
var description_edit: TextEdit


func _ready() -> void:
	resource_type_id = "crafter"
	resource_type_name = "Crafter"
	# Declare dependencies BEFORE super._ready() so base class can auto-subscribe
	resource_dependencies = ["character", "map"]
	super._ready()


## Override: Create the crafter-specific detail form
func _create_detail_form() -> void:
	_add_basic_info_section()
	_add_capabilities_section()
	_add_location_section()
	_add_npc_link_section()
	_add_availability_section()
	_add_economy_section()
	_add_description_section()

	# Add button container at end (with separator for visual clarity)
	_add_button_container_to_detail_panel()


## Override: Load crafter data from resource into UI
func _load_resource_data() -> void:
	var crafter: CrafterData = current_resource as CrafterData
	if not crafter:
		return

	_updating_ui = true

	# Basic info
	crafter_id_edit.text = _get_crafter_id_from_resource()
	name_edit.text = crafter.crafter_name

	# Crafter type
	_set_crafter_type(crafter.crafter_type)

	# Capabilities
	skill_level_spin.value = crafter.skill_level
	specializations_edit.text = ",".join(crafter.specializations)

	# Location
	if not crafter.location_map_id.is_empty():
		var map_res: MapMetadata = ModLoader.registry.get_map(crafter.location_map_id) if ModLoader and ModLoader.registry else null
		if map_res:
			location_map_picker.select_resource(map_res)
		else:
			location_map_picker.select_none()
	else:
		location_map_picker.select_none()
	location_x_spin.value = crafter.location_grid_position.x
	location_y_spin.value = crafter.location_grid_position.y

	# NPC Link
	if not crafter.character_id.is_empty():
		var char_res: CharacterData = ModLoader.registry.get_character(crafter.character_id) if ModLoader and ModLoader.registry else null
		if char_res:
			character_picker.select_resource(char_res)
		else:
			character_picker.select_none()
	else:
		character_picker.select_none()

	# Availability
	required_flags_edit.text = ",".join(crafter.required_flags)
	forbidden_flags_edit.text = ",".join(crafter.forbidden_flags)

	# Economy
	service_fee_spin.value = crafter.service_fee_modifier

	# Description
	description_edit.text = crafter.description

	_updating_ui = false


## Override: Save UI data to resource
func _save_resource_data() -> void:
	var crafter: CrafterData = current_resource as CrafterData
	if not crafter:
		return

	# Basic info
	crafter.crafter_name = name_edit.text.strip_edges()
	crafter.crafter_type = _get_crafter_type()

	# Capabilities
	crafter.skill_level = int(skill_level_spin.value)
	crafter.specializations = _parse_string_array(specializations_edit.text)

	# Location
	var selected_map: Resource = location_map_picker.get_selected_resource()
	if selected_map:
		crafter.location_map_id = selected_map.resource_path.get_file().get_basename()
	else:
		crafter.location_map_id = ""
	crafter.location_grid_position = Vector2i(int(location_x_spin.value), int(location_y_spin.value))

	# NPC Link
	var selected_char: Resource = character_picker.get_selected_resource()
	if selected_char:
		crafter.character_id = selected_char.resource_path.get_file().get_basename()
	else:
		crafter.character_id = ""

	# Availability
	crafter.required_flags = _parse_string_array(required_flags_edit.text)
	crafter.forbidden_flags = _parse_string_array(forbidden_flags_edit.text)

	# Economy
	crafter.service_fee_modifier = service_fee_spin.value

	# Description
	crafter.description = description_edit.text


## Override: Validate resource before saving
func _validate_resource() -> Dictionary:
	var crafter: CrafterData = current_resource as CrafterData
	if not crafter:
		return {valid = false, errors = ["Invalid resource type"]}

	var errors: Array[String] = []

	if name_edit.text.strip_edges().is_empty():
		errors.append("Crafter name cannot be empty")

	var crafter_type: String = _get_crafter_type()
	if crafter_type.is_empty():
		errors.append("Crafter type cannot be empty")

	if skill_level_spin.value < 1:
		errors.append("Skill level must be at least 1")

	if service_fee_spin.value <= 0.0:
		errors.append("Service fee modifier must be positive")

	return {valid = errors.is_empty(), errors = errors}


## Override: Create a new crafter with defaults
func _create_new_resource() -> Resource:
	var new_crafter: CrafterData = CrafterData.new()
	new_crafter.crafter_name = "New Crafter"
	new_crafter.crafter_type = "blacksmith"
	new_crafter.skill_level = 1
	# Note: specializations defaults to empty Array[String] - don't reassign
	new_crafter.location_map_id = ""
	new_crafter.location_grid_position = Vector2i.ZERO
	new_crafter.character_id = ""
	# Note: required_flags, forbidden_flags default to empty Array[String] - don't reassign
	new_crafter.service_fee_modifier = 1.0
	new_crafter.description = ""
	return new_crafter


## Override: Get the display name from a crafter resource
func _get_resource_display_name(resource: Resource) -> String:
	var crafter: CrafterData = resource as CrafterData
	if crafter:
		if not crafter.crafter_name.is_empty():
			return crafter.crafter_name
	return "Unnamed Crafter"


# =============================================================================
# UI CREATION HELPERS
# =============================================================================

func _add_basic_info_section() -> void:
	var section: VBoxContainer = SparklingEditorUtils.create_section("Basic Information", detail_panel)

	# Crafter Name
	var name_row: HBoxContainer = SparklingEditorUtils.create_field_row("Crafter Name:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	name_edit = LineEdit.new()
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.placeholder_text = "e.g., Master Blacksmith"
	name_edit.tooltip_text = "Display name for this crafter. Used in shop menus and dialogue."
	name_edit.text_changed.connect(_on_name_changed)
	name_row.add_child(name_edit)

	# Crafter ID (read-only, derived from filename)
	var id_row: HBoxContainer = SparklingEditorUtils.create_field_row("Crafter ID:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	crafter_id_edit = LineEdit.new()
	crafter_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crafter_id_edit.placeholder_text = "(from filename)"
	crafter_id_edit.tooltip_text = "Unique ID derived from filename. Rename file to change ID."
	crafter_id_edit.editable = false
	id_row.add_child(crafter_id_edit)

	# Crafter Type
	var type_row: HBoxContainer = SparklingEditorUtils.create_field_row("Crafter Type:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	crafter_type_option = OptionButton.new()
	crafter_type_option.tooltip_text = "Type determines which recipes this crafter can perform. Must match recipe requirements."
	for crafter_type: String in SparklingEditorUtils.CRAFTER_TYPES:
		crafter_type_option.add_item(crafter_type)
	crafter_type_option.item_selected.connect(_on_crafter_type_selected)
	type_row.add_child(crafter_type_option)

	crafter_type_custom_edit = LineEdit.new()
	crafter_type_custom_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crafter_type_custom_edit.placeholder_text = "custom_type"
	crafter_type_custom_edit.tooltip_text = "Enter a custom crafter type. Must match recipe requirements exactly."
	crafter_type_custom_edit.visible = false
	crafter_type_custom_edit.text_changed.connect(_mark_dirty)
	type_row.add_child(crafter_type_custom_edit)

	SparklingEditorUtils.create_help_label("Type must match recipe requirements (e.g., 'blacksmith' for weapon forging)", section)


func _add_capabilities_section() -> void:
	var section: VBoxContainer = SparklingEditorUtils.create_section("Capabilities", detail_panel)

	# Skill Level
	var skill_row: HBoxContainer = SparklingEditorUtils.create_field_row("Skill Level:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	skill_level_spin = SpinBox.new()
	skill_level_spin.min_value = 1
	skill_level_spin.max_value = 99
	skill_level_spin.value = 1
	skill_level_spin.tooltip_text = "Crafter's skill level. Must meet or exceed recipe requirements to craft."
	skill_level_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	skill_row.add_child(skill_level_spin)

	SparklingEditorUtils.create_help_label("Higher skill = access to more advanced recipes", section)

	# Specializations
	var spec_row: HBoxContainer = SparklingEditorUtils.create_field_row("Specializations:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	specializations_edit = LineEdit.new()
	specializations_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	specializations_edit.placeholder_text = "e.g., swords, fire, mithril"
	specializations_edit.tooltip_text = "Comma-separated specialization categories. May provide bonuses for matching recipes."
	specializations_edit.text_changed.connect(_mark_dirty)
	spec_row.add_child(specializations_edit)

	SparklingEditorUtils.create_help_label("Optional expertise areas for potential crafting bonuses", section)


func _add_location_section() -> void:
	var section: VBoxContainer = SparklingEditorUtils.create_section("Location", detail_panel)

	# Map picker
	location_map_picker = ResourcePicker.new()
	location_map_picker.resource_type = "map"
	location_map_picker.label_text = "Map:"
	location_map_picker.label_min_width = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	location_map_picker.allow_none = true
	location_map_picker.none_text = "(No specific location)"
	location_map_picker.tooltip_text = "Which map this crafter is located on (for lookup/fast travel)."
	location_map_picker.resource_selected.connect(_on_map_selected)
	section.add_child(location_map_picker)

	# Grid position
	var pos_row: HBoxContainer = SparklingEditorUtils.create_field_row("Grid Position:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)

	var x_label: Label = Label.new()
	x_label.text = "X:"
	pos_row.add_child(x_label)

	location_x_spin = SpinBox.new()
	location_x_spin.min_value = -999
	location_x_spin.max_value = 999
	location_x_spin.value = 0
	location_x_spin.custom_minimum_size.x = 70
	location_x_spin.tooltip_text = "X grid coordinate on the map"
	location_x_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	pos_row.add_child(location_x_spin)

	var y_label: Label = Label.new()
	y_label.text = "Y:"
	pos_row.add_child(y_label)

	location_y_spin = SpinBox.new()
	location_y_spin.min_value = -999
	location_y_spin.max_value = 999
	location_y_spin.value = 0
	location_y_spin.custom_minimum_size.x = 70
	location_y_spin.tooltip_text = "Y grid coordinate on the map"
	location_y_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	pos_row.add_child(location_y_spin)

	SparklingEditorUtils.create_help_label("Optional: Location for map markers and fast travel", section)


func _add_npc_link_section() -> void:
	var section: VBoxContainer = SparklingEditorUtils.create_section("NPC Link", detail_panel)

	character_picker = ResourcePicker.new()
	character_picker.resource_type = "character"
	character_picker.label_text = "Character:"
	character_picker.label_min_width = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	character_picker.allow_none = true
	character_picker.none_text = "(No linked character)"
	character_picker.tooltip_text = "Optional CharacterData for portrait/dialogue. Leave empty for anonymous crafters."
	character_picker.resource_selected.connect(_on_character_selected)
	section.add_child(character_picker)

	SparklingEditorUtils.create_help_label("Link to a character for portrait and dialogue in the crafting UI", section)


func _add_availability_section() -> void:
	var section: VBoxContainer = SparklingEditorUtils.create_section("Availability", detail_panel)

	# Required flags
	var req_row: HBoxContainer = SparklingEditorUtils.create_field_row("Required Flags:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	required_flags_edit = LineEdit.new()
	required_flags_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	required_flags_edit.placeholder_text = "e.g., chapter_2_started, unlocked_forge"
	required_flags_edit.tooltip_text = "Comma-separated flags. ALL must be set for crafter to be available."
	required_flags_edit.text_changed.connect(_mark_dirty)
	req_row.add_child(required_flags_edit)

	# Forbidden flags
	var forb_row: HBoxContainer = SparklingEditorUtils.create_field_row("Forbidden Flags:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	forbidden_flags_edit = LineEdit.new()
	forbidden_flags_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forbidden_flags_edit.placeholder_text = "e.g., forge_destroyed"
	forbidden_flags_edit.tooltip_text = "Comma-separated flags. If ANY is set, crafter becomes unavailable."
	forbidden_flags_edit.text_changed.connect(_mark_dirty)
	forb_row.add_child(forbidden_flags_edit)

	SparklingEditorUtils.create_help_label("Control when this crafter appears in the game world", section)


func _add_economy_section() -> void:
	var section: VBoxContainer = SparklingEditorUtils.create_section("Economy", detail_panel)

	var fee_row: HBoxContainer = SparklingEditorUtils.create_field_row("Service Fee Modifier:", SparklingEditorUtils.DEFAULT_LABEL_WIDTH, section)
	service_fee_spin = SpinBox.new()
	service_fee_spin.min_value = 0.1
	service_fee_spin.max_value = 5.0
	service_fee_spin.step = 0.05
	service_fee_spin.value = 1.0
	service_fee_spin.tooltip_text = "Multiplier on recipe gold costs. 1.0 = normal, 0.8 = discount, 1.5 = premium."
	service_fee_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	fee_row.add_child(service_fee_spin)

	SparklingEditorUtils.create_help_label("1.0 = normal prices, lower = discount, higher = premium", section)


func _add_description_section() -> void:
	var section: VBoxContainer = SparklingEditorUtils.create_section("Description", detail_panel)

	description_edit = TextEdit.new()
	description_edit.custom_minimum_size.y = 80
	description_edit.placeholder_text = "A master blacksmith who specializes in mithril weapons..."
	description_edit.tooltip_text = "Flavor text describing this crafter. Shown in menus and dialogue."
	description_edit.text_changed.connect(_mark_dirty)
	section.add_child(description_edit)


# =============================================================================
# EVENT HANDLERS
# =============================================================================

func _on_name_changed(_new_text: String) -> void:
	if _updating_ui:
		return
	_mark_dirty()


func _on_crafter_type_selected(index: int) -> void:
	if _updating_ui:
		return
	# Show/hide custom type field
	crafter_type_custom_edit.visible = (index == 0)  # "(Custom)" is index 0
	_mark_dirty()


func _on_map_selected(_metadata: Dictionary) -> void:
	if _updating_ui:
		return
	_mark_dirty()


func _on_character_selected(_metadata: Dictionary) -> void:
	if _updating_ui:
		return
	_mark_dirty()


# =============================================================================
# HELPERS
# =============================================================================

func _get_crafter_id_from_resource() -> String:
	if current_resource and not current_resource.resource_path.is_empty():
		return current_resource.resource_path.get_file().get_basename()
	return ""


func _get_crafter_type() -> String:
	var index: int = crafter_type_option.selected
	if index == 0:  # "(Custom)"
		return crafter_type_custom_edit.text.strip_edges()
	elif index > 0 and index < SparklingEditorUtils.CRAFTER_TYPES.size():
		return SparklingEditorUtils.CRAFTER_TYPES[index]
	return ""


func _set_crafter_type(crafter_type: String) -> void:
	# Check if it's a predefined type
	var type_index: int = SparklingEditorUtils.CRAFTER_TYPES.find(crafter_type)
	if type_index > 0:  # Found and not "(Custom)"
		crafter_type_option.select(type_index)
		crafter_type_custom_edit.visible = false
		crafter_type_custom_edit.text = ""
	else:
		# Custom type
		crafter_type_option.select(0)  # "(Custom)"
		crafter_type_custom_edit.visible = true
		crafter_type_custom_edit.text = crafter_type


func _parse_string_array(text: String) -> Array[String]:
	var result: Array[String] = []
	var parts: PackedStringArray = text.split(",")
	for part: String in parts:
		var trimmed: String = part.strip_edges()
		if not trimmed.is_empty():
			result.append(trimmed)
	return result


## Override: Called when dependent resource types change (via base class)
func _on_dependencies_changed(_changed_type: String) -> void:
	# Refresh pickers when characters or maps change
	if location_map_picker:
		location_map_picker.refresh()
	if character_picker:
		character_picker.refresh()


## Override refresh to also refresh pickers
func refresh() -> void:
	if location_map_picker:
		location_map_picker.refresh()
	if character_picker:
		character_picker.refresh()
	super.refresh()
