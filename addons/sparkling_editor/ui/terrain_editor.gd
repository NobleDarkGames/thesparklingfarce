@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Terrain Editor UI
## Allows browsing and editing TerrainData resources
## Terrain types define movement costs and combat modifiers for battle map tiles

# Identity fields
var terrain_id_edit: LineEdit
var display_name_edit: LineEdit

# Movement costs
var walking_cost_spin: SpinBox
var floating_cost_spin: SpinBox
var flying_cost_spin: SpinBox

# Impassable flags
var impassable_walking_check: CheckBox
var impassable_floating_check: CheckBox
var impassable_flying_check: CheckBox

# Combat modifiers
var defense_bonus_spin: SpinBox
var evasion_bonus_spin: SpinBox

# Turn effects
var damage_per_turn_spin: SpinBox
var healing_per_turn_spin: SpinBox


func _ready() -> void:
	resource_type_id = "terrain"
	resource_type_name = "Terrain"
	# resource_directory is set dynamically via base class using ModLoader.get_active_mod()
	super._ready()


## Override: Create the terrain-specific detail form
func _create_detail_form() -> void:
	# Identity section
	_add_identity_section()

	# Movement section
	_add_movement_section()

	# Combat modifiers section
	_add_combat_section()

	# Turn effects section
	_add_turn_effects_section()

	# Add the button container at the end (with separator for visual clarity)
	_add_button_container_to_detail_panel()


## Override: Load terrain data from resource into UI
func _load_resource_data() -> void:
	var terrain: TerrainData = current_resource as TerrainData
	if not terrain:
		return

	# Identity
	terrain_id_edit.text = terrain.terrain_id
	display_name_edit.text = terrain.display_name

	# Movement costs
	walking_cost_spin.value = terrain.movement_cost_walking
	floating_cost_spin.value = terrain.movement_cost_floating
	flying_cost_spin.value = terrain.movement_cost_flying

	# Impassable flags
	impassable_walking_check.button_pressed = terrain.impassable_walking
	impassable_floating_check.button_pressed = terrain.impassable_floating
	impassable_flying_check.button_pressed = terrain.impassable_flying

	# Combat modifiers
	defense_bonus_spin.value = terrain.defense_bonus
	evasion_bonus_spin.value = terrain.evasion_bonus

	# Turn effects
	damage_per_turn_spin.value = terrain.damage_per_turn
	healing_per_turn_spin.value = terrain.healing_per_turn

	# Update impassable visual feedback
	_update_impassable_visual_feedback()


## Override: Save UI data to resource
func _save_resource_data() -> void:
	var terrain: TerrainData = current_resource as TerrainData
	if not terrain:
		return

	# Identity
	terrain.terrain_id = terrain_id_edit.text.strip_edges().to_lower()
	terrain.display_name = display_name_edit.text.strip_edges()

	# Movement costs
	terrain.movement_cost_walking = int(walking_cost_spin.value)
	terrain.movement_cost_floating = int(floating_cost_spin.value)
	terrain.movement_cost_flying = int(flying_cost_spin.value)

	# Impassable flags
	terrain.impassable_walking = impassable_walking_check.button_pressed
	terrain.impassable_floating = impassable_floating_check.button_pressed
	terrain.impassable_flying = impassable_flying_check.button_pressed

	# Combat modifiers
	terrain.defense_bonus = int(defense_bonus_spin.value)
	terrain.evasion_bonus = int(evasion_bonus_spin.value)

	# Turn effects
	terrain.damage_per_turn = int(damage_per_turn_spin.value)
	terrain.healing_per_turn = int(healing_per_turn_spin.value)


## Override: Validate resource before saving
func _validate_resource() -> Dictionary:
	var terrain: TerrainData = current_resource as TerrainData
	if not terrain:
		return {valid = false, errors = ["Invalid resource type"]}

	var errors: Array[String] = []

	# Validate terrain_id
	var terrain_id: String = terrain_id_edit.text.strip_edges()
	if terrain_id.is_empty():
		errors.append("Terrain ID cannot be empty")
	elif terrain_id.contains(" "):
		errors.append("Terrain ID cannot contain spaces (use underscores)")
	elif not terrain_id.is_valid_identifier():
		errors.append("Terrain ID must be a valid identifier (letters, numbers, underscores)")

	# Validate display_name
	if display_name_edit.text.strip_edges().is_empty():
		errors.append("Display name cannot be empty")

	# Validate movement costs
	if walking_cost_spin.value < 1:
		errors.append("Walking movement cost must be at least 1")
	if floating_cost_spin.value < 1:
		errors.append("Floating movement cost must be at least 1")
	if flying_cost_spin.value < 1:
		errors.append("Flying movement cost must be at least 1")

	# Validate combat bonuses
	if defense_bonus_spin.value < 0:
		errors.append("Defense bonus cannot be negative")
	if evasion_bonus_spin.value < 0 or evasion_bonus_spin.value > 100:
		errors.append("Evasion bonus must be between 0 and 100")

	return {valid = errors.is_empty(), errors = errors}


## Override: Check for references before deletion
func _check_resource_references(_resource_to_check: Resource) -> Array[String]:
	# Terrain is referenced by TileSets and map configurations
	# This would require scanning TileSet resources and map metadata
	# For now, return empty - terrain deletion is typically safe
	# TODO: Add TileSet scanning in future if needed
	return []


## Override: Create a new terrain with defaults
func _create_new_resource() -> Resource:
	var new_terrain: TerrainData = TerrainData.new()
	new_terrain.terrain_id = "new_terrain"
	new_terrain.display_name = "New Terrain"
	new_terrain.movement_cost_walking = 1
	new_terrain.movement_cost_floating = 1
	new_terrain.movement_cost_flying = 1
	new_terrain.defense_bonus = 0
	new_terrain.evasion_bonus = 0

	return new_terrain


## Override: Get the display name from a terrain resource
func _get_resource_display_name(resource: Resource) -> String:
	var terrain: TerrainData = resource as TerrainData
	if terrain:
		if terrain.display_name.is_empty():
			return terrain.terrain_id
		return terrain.display_name
	return "Unnamed Terrain"


func _add_identity_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Identity")

	terrain_id_edit = form.add_text_field("Terrain ID:", "e.g., deep_water, lava_flow",
		"Unique identifier used in map tiles (lowercase, no spaces)")

	display_name_edit = form.add_text_field("Display Name:", "e.g., Deep Water, Lava Flow",
		"Name shown in game UI when hovering over terrain")


func _add_movement_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Movement"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Movement cost: 1 = normal, 2 = half speed, 3+ = very slow. Check 'Impassable' to block entirely."
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(help_label)

	# Walking
	var walking_container: HBoxContainer = HBoxContainer.new()
	var walking_label: Label = Label.new()
	walking_label.text = "Walking Cost:"
	walking_label.custom_minimum_size.x = 150
	walking_label.tooltip_text = "Movement cost for ground infantry and cavalry"
	walking_container.add_child(walking_label)

	walking_cost_spin = SpinBox.new()
	walking_cost_spin.min_value = 1
	walking_cost_spin.max_value = 99
	walking_cost_spin.value = 1
	walking_cost_spin.tooltip_text = "1 = normal, 2 = half speed, 3+ = very slow"
	walking_cost_spin.value_changed.connect(_on_field_changed)
	walking_container.add_child(walking_cost_spin)

	impassable_walking_check = CheckBox.new()
	impassable_walking_check.text = "Impassable"
	impassable_walking_check.tooltip_text = "Walking units cannot enter at all"
	impassable_walking_check.toggled.connect(_on_impassable_toggled)
	impassable_walking_check.toggled.connect(_on_field_changed)
	walking_container.add_child(impassable_walking_check)
	section.add_child(walking_container)

	# Floating
	var floating_container: HBoxContainer = HBoxContainer.new()
	var floating_label: Label = Label.new()
	floating_label.text = "Floating Cost:"
	floating_label.custom_minimum_size.x = 150
	floating_label.tooltip_text = "Movement cost for hover/levitating units"
	floating_container.add_child(floating_label)

	floating_cost_spin = SpinBox.new()
	floating_cost_spin.min_value = 1
	floating_cost_spin.max_value = 99
	floating_cost_spin.value = 1
	floating_cost_spin.value_changed.connect(_on_field_changed)
	floating_container.add_child(floating_cost_spin)

	impassable_floating_check = CheckBox.new()
	impassable_floating_check.text = "Impassable"
	impassable_floating_check.tooltip_text = "Floating units cannot enter at all"
	impassable_floating_check.toggled.connect(_on_impassable_toggled)
	impassable_floating_check.toggled.connect(_on_field_changed)
	floating_container.add_child(impassable_floating_check)
	section.add_child(floating_container)

	# Flying
	var flying_container: HBoxContainer = HBoxContainer.new()
	var flying_label: Label = Label.new()
	flying_label.text = "Flying Cost:"
	flying_label.custom_minimum_size.x = 150
	flying_label.tooltip_text = "Movement cost for flying units (usually 1)"
	flying_container.add_child(flying_label)

	flying_cost_spin = SpinBox.new()
	flying_cost_spin.min_value = 1
	flying_cost_spin.max_value = 99
	flying_cost_spin.value = 1
	flying_cost_spin.value_changed.connect(_on_field_changed)
	flying_container.add_child(flying_cost_spin)

	impassable_flying_check = CheckBox.new()
	impassable_flying_check.text = "Impassable"
	impassable_flying_check.tooltip_text = "Flying units cannot enter (rare - anti-air zones, ceilings)"
	impassable_flying_check.toggled.connect(_on_impassable_toggled)
	impassable_flying_check.toggled.connect(_on_field_changed)
	flying_container.add_child(impassable_flying_check)
	section.add_child(flying_container)

	detail_panel.add_child(section)


func _add_combat_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Combat Modifiers")
	form.add_help_text("Bonuses applied to units standing on this terrain during combat.")

	defense_bonus_spin = form.add_number_field("Defense Bonus:", 0, 10, 0,
		"Flat bonus added to unit's defense stat (0-10 typical)")

	evasion_bonus_spin = form.add_number_field("Evasion Bonus (%):", 0, 50, 0,
		"Percentage added to evasion chance (0-50% typical)")
	evasion_bonus_spin.suffix = "%"


func _add_turn_effects_section() -> void:
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)
	form.add_section("Turn Effects")
	form.add_help_text("Effects applied at the start of each turn for units on this terrain.")

	damage_per_turn_spin = form.add_number_field("Damage per Turn:", 0, 99, 0,
		"HP lost at start of turn (for lava, poison swamp, etc.)")

	healing_per_turn_spin = form.add_number_field("Healing per Turn:", 0, 99, 0,
		"HP restored at start of turn (for sacred ground, healing tiles)")


## Called when any manually-connected field changes to mark dirty
func _on_field_changed(_value: Variant = null) -> void:
	_mark_dirty()


## Update visual feedback when impassable checkboxes are toggled
func _on_impassable_toggled(_pressed: bool) -> void:
	_update_impassable_visual_feedback()


## Dim cost spinboxes when the corresponding impassable flag is set
func _update_impassable_visual_feedback() -> void:
	var dim_color: Color = Color(0.5, 0.5, 0.5, 0.7)
	var normal_color: Color = Color(1, 1, 1, 1)

	if impassable_walking_check and walking_cost_spin:
		walking_cost_spin.modulate = dim_color if impassable_walking_check.button_pressed else normal_color
		walking_cost_spin.editable = not impassable_walking_check.button_pressed

	if impassable_floating_check and floating_cost_spin:
		floating_cost_spin.modulate = dim_color if impassable_floating_check.button_pressed else normal_color
		floating_cost_spin.editable = not impassable_floating_check.button_pressed

	if impassable_flying_check and flying_cost_spin:
		flying_cost_spin.modulate = dim_color if impassable_flying_check.button_pressed else normal_color
		flying_cost_spin.editable = not impassable_flying_check.button_pressed
