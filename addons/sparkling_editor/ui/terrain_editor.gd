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
var status_effect_edit: LineEdit
var status_effect_duration_spin: SpinBox

# Audio/Visual
var footstep_sound_edit: LineEdit


func _ready() -> void:
	resource_directory = "res://mods/_sandbox/data/terrain/"
	resource_type_id = "terrain"
	resource_type_name = "Terrain"
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

	# Audio/Visual section
	_add_audio_visual_section()

	# Add the button container at the end
	detail_panel.add_child(button_container)


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
	status_effect_edit.text = terrain.status_effect_on_entry
	status_effect_duration_spin.value = terrain.status_effect_duration

	# Audio/Visual
	footstep_sound_edit.text = terrain.footstep_sound

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
	terrain.status_effect_on_entry = status_effect_edit.text.strip_edges()
	terrain.status_effect_duration = int(status_effect_duration_spin.value)

	# Audio/Visual
	terrain.footstep_sound = footstep_sound_edit.text.strip_edges()


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

	# Validate status effect duration if effect is set
	if not status_effect_edit.text.strip_edges().is_empty():
		if status_effect_duration_spin.value < 1:
			errors.append("Status effect duration must be at least 1 turn")

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
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Identity"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Terrain ID
	var id_container: HBoxContainer = HBoxContainer.new()
	var id_label: Label = Label.new()
	id_label.text = "Terrain ID:"
	id_label.custom_minimum_size.x = 150
	id_label.tooltip_text = "Unique identifier used in map tiles (lowercase, no spaces)"
	id_container.add_child(id_label)

	terrain_id_edit = LineEdit.new()
	terrain_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	terrain_id_edit.placeholder_text = "e.g., deep_water, lava_flow"
	id_container.add_child(terrain_id_edit)
	section.add_child(id_container)

	# Display Name
	var name_container: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = "Display Name:"
	name_label.custom_minimum_size.x = 150
	name_label.tooltip_text = "Name shown in game UI when hovering over terrain"
	name_container.add_child(name_label)

	display_name_edit = LineEdit.new()
	display_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_name_edit.placeholder_text = "e.g., Deep Water, Lava Flow"
	name_container.add_child(display_name_edit)
	section.add_child(name_container)

	detail_panel.add_child(section)


func _add_movement_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Movement"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Movement cost: 1 = normal, 2 = half speed, 3+ = very slow. Check 'Impassable' to block entirely."
	help_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	help_label.add_theme_font_size_override("font_size", 16)
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
	walking_container.add_child(walking_cost_spin)

	impassable_walking_check = CheckBox.new()
	impassable_walking_check.text = "Impassable"
	impassable_walking_check.tooltip_text = "Walking units cannot enter at all"
	impassable_walking_check.toggled.connect(_on_impassable_toggled)
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
	floating_container.add_child(floating_cost_spin)

	impassable_floating_check = CheckBox.new()
	impassable_floating_check.text = "Impassable"
	impassable_floating_check.tooltip_text = "Floating units cannot enter at all"
	impassable_floating_check.toggled.connect(_on_impassable_toggled)
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
	flying_container.add_child(flying_cost_spin)

	impassable_flying_check = CheckBox.new()
	impassable_flying_check.text = "Impassable"
	impassable_flying_check.tooltip_text = "Flying units cannot enter (rare - anti-air zones, ceilings)"
	impassable_flying_check.toggled.connect(_on_impassable_toggled)
	flying_container.add_child(impassable_flying_check)
	section.add_child(flying_container)

	detail_panel.add_child(section)


func _add_combat_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Combat Modifiers"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Bonuses applied to units standing on this terrain during combat."
	help_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	help_label.add_theme_font_size_override("font_size", 16)
	section.add_child(help_label)

	# Defense Bonus
	var def_container: HBoxContainer = HBoxContainer.new()
	var def_label: Label = Label.new()
	def_label.text = "Defense Bonus:"
	def_label.custom_minimum_size.x = 150
	def_label.tooltip_text = "Flat bonus added to unit's defense stat (0-10 typical)"
	def_container.add_child(def_label)

	defense_bonus_spin = SpinBox.new()
	defense_bonus_spin.min_value = 0
	defense_bonus_spin.max_value = 10
	defense_bonus_spin.value = 0
	def_container.add_child(defense_bonus_spin)
	section.add_child(def_container)

	# Evasion Bonus
	var eva_container: HBoxContainer = HBoxContainer.new()
	var eva_label: Label = Label.new()
	eva_label.text = "Evasion Bonus (%):"
	eva_label.custom_minimum_size.x = 150
	eva_label.tooltip_text = "Percentage added to evasion chance (0-50% typical)"
	eva_container.add_child(eva_label)

	evasion_bonus_spin = SpinBox.new()
	evasion_bonus_spin.min_value = 0
	evasion_bonus_spin.max_value = 50
	evasion_bonus_spin.value = 0
	evasion_bonus_spin.suffix = "%"
	eva_container.add_child(evasion_bonus_spin)
	section.add_child(eva_container)

	detail_panel.add_child(section)


func _add_turn_effects_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Turn Effects"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Effects applied at the start of each turn for units on this terrain."
	help_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	help_label.add_theme_font_size_override("font_size", 16)
	section.add_child(help_label)

	# Damage per Turn
	var dmg_container: HBoxContainer = HBoxContainer.new()
	var dmg_label: Label = Label.new()
	dmg_label.text = "Damage per Turn:"
	dmg_label.custom_minimum_size.x = 150
	dmg_label.tooltip_text = "HP lost at start of turn (for lava, poison swamp, etc.)"
	dmg_container.add_child(dmg_label)

	damage_per_turn_spin = SpinBox.new()
	damage_per_turn_spin.min_value = 0
	damage_per_turn_spin.max_value = 99
	damage_per_turn_spin.value = 0
	dmg_container.add_child(damage_per_turn_spin)
	section.add_child(dmg_container)

	# Healing per Turn
	var heal_container: HBoxContainer = HBoxContainer.new()
	var heal_label: Label = Label.new()
	heal_label.text = "Healing per Turn:"
	heal_label.custom_minimum_size.x = 150
	heal_label.tooltip_text = "HP restored at start of turn (for sacred ground, healing tiles)"
	heal_container.add_child(heal_label)

	healing_per_turn_spin = SpinBox.new()
	healing_per_turn_spin.min_value = 0
	healing_per_turn_spin.max_value = 99
	healing_per_turn_spin.value = 0
	heal_container.add_child(healing_per_turn_spin)

	var heal_note: Label = Label.new()
	heal_note.text = "(Deferred)"
	heal_note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	heal_note.tooltip_text = "This feature exists but may not be fully implemented yet"
	heal_container.add_child(heal_note)
	section.add_child(heal_container)

	# Status Effect on Entry
	var status_container: HBoxContainer = HBoxContainer.new()
	var status_label: Label = Label.new()
	status_label.text = "Status Effect:"
	status_label.custom_minimum_size.x = 150
	status_label.tooltip_text = "Status effect applied when entering this terrain"
	status_container.add_child(status_label)

	status_effect_edit = LineEdit.new()
	status_effect_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_effect_edit.placeholder_text = "e.g., poison, slow"
	status_container.add_child(status_effect_edit)

	var status_note: Label = Label.new()
	status_note.text = "(Deferred)"
	status_note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	status_note.tooltip_text = "This feature exists but may not be fully implemented yet"
	status_container.add_child(status_note)
	section.add_child(status_container)

	# Status Effect Duration
	var duration_container: HBoxContainer = HBoxContainer.new()
	var duration_label: Label = Label.new()
	duration_label.text = "Effect Duration:"
	duration_label.custom_minimum_size.x = 150
	duration_label.tooltip_text = "How many turns the status effect lasts"
	duration_container.add_child(duration_label)

	status_effect_duration_spin = SpinBox.new()
	status_effect_duration_spin.min_value = 1
	status_effect_duration_spin.max_value = 10
	status_effect_duration_spin.value = 1
	status_effect_duration_spin.suffix = " turns"
	duration_container.add_child(status_effect_duration_spin)
	section.add_child(duration_container)

	detail_panel.add_child(section)


func _add_audio_visual_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Audio & Visual"
	section_label.add_theme_font_size_override("font_size", 16)
	section.add_child(section_label)

	# Footstep Sound
	var sound_container: HBoxContainer = HBoxContainer.new()
	var sound_label: Label = Label.new()
	sound_label.text = "Footstep Sound:"
	sound_label.custom_minimum_size.x = 150
	sound_label.tooltip_text = "Sound effect ID when walking on this terrain"
	sound_container.add_child(sound_label)

	footstep_sound_edit = LineEdit.new()
	footstep_sound_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footstep_sound_edit.placeholder_text = "e.g., grass_step, metal_clang"
	sound_container.add_child(footstep_sound_edit)

	var sound_note: Label = Label.new()
	sound_note.text = "(Deferred)"
	sound_note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	sound_note.tooltip_text = "This feature exists but may not be fully implemented yet"
	sound_container.add_child(sound_note)
	section.add_child(sound_container)

	var note_label: Label = Label.new()
	note_label.text = "Note: Walk particle and icon can be assigned in the Godot Inspector"
	note_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	note_label.add_theme_font_size_override("font_size", 16)
	section.add_child(note_label)

	detail_panel.add_child(section)


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
