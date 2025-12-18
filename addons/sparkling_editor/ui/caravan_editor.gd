@tool
extends "res://addons/sparkling_editor/ui/base_resource_editor.gd"

## Caravan Editor UI
## Allows creating and editing CaravanData resources
## Defines the mobile caravan headquarters appearance, behavior, and services

# =============================================================================
# UI COMPONENTS
# =============================================================================

# Identity fields
var caravan_id_edit: LineEdit
var display_name_edit: LineEdit

# Appearance
var wagon_sprite_path_edit: LineEdit
var wagon_sprite_picker_btn: Button
var wagon_animation_path_edit: LineEdit
var wagon_scale_x_spin: SpinBox
var wagon_scale_y_spin: SpinBox
var z_index_spin: SpinBox

# Following behavior
var follow_distance_spin: SpinBox
var follow_speed_spin: SpinBox
var use_chain_check: CheckBox
var max_history_spin: SpinBox

# Terrain restrictions
var can_cross_water_check: CheckBox
var can_enter_forest_check: CheckBox
var blocked_terrain_edit: LineEdit

# Services
var has_item_storage_check: CheckBox
var has_party_management_check: CheckBox
var has_rest_check: CheckBox
var has_shop_check: CheckBox
var has_promotion_check: CheckBox

# Interior
var interior_scene_edit: LineEdit

# Audio
var menu_open_sfx_edit: LineEdit
var menu_close_sfx_edit: LineEdit
var heal_sfx_edit: LineEdit
var ambient_sfx_edit: LineEdit


func _ready() -> void:
	resource_type_id = "caravan"
	resource_type_name = "Caravan"
	super._ready()


## Override: Create the caravan-specific detail form
func _create_detail_form() -> void:
	_add_identity_section()
	_add_appearance_section()
	_add_following_section()
	_add_terrain_section()
	_add_services_section()
	_add_interior_section()
	_add_audio_section()

	# Add the button container at the end (with separator for visual clarity)
	_add_button_container_to_detail_panel()


## Override: Load caravan data from resource into UI
func _load_resource_data() -> void:
	var caravan: CaravanData = current_resource as CaravanData
	if not caravan:
		return

	# Identity
	caravan_id_edit.text = caravan.caravan_id
	display_name_edit.text = caravan.display_name

	# Appearance
	wagon_sprite_path_edit.text = caravan.wagon_sprite.resource_path if caravan.wagon_sprite else ""
	wagon_animation_path_edit.text = caravan.wagon_animation_frames.resource_path if caravan.wagon_animation_frames else ""
	wagon_scale_x_spin.value = caravan.wagon_scale.x
	wagon_scale_y_spin.value = caravan.wagon_scale.y
	z_index_spin.value = caravan.z_index_offset

	# Following behavior
	follow_distance_spin.value = caravan.follow_distance_tiles
	follow_speed_spin.value = caravan.follow_speed
	use_chain_check.button_pressed = caravan.use_chain_following
	max_history_spin.value = caravan.max_history_size

	# Terrain restrictions
	can_cross_water_check.button_pressed = caravan.can_cross_water
	can_enter_forest_check.button_pressed = caravan.can_enter_forest
	blocked_terrain_edit.text = ",".join(caravan.blocked_terrain_types)

	# Services
	has_item_storage_check.button_pressed = caravan.has_item_storage
	has_party_management_check.button_pressed = caravan.has_party_management
	has_rest_check.button_pressed = caravan.has_rest_service
	has_shop_check.button_pressed = caravan.has_shop_service
	has_promotion_check.button_pressed = caravan.has_promotion_service

	# Interior
	interior_scene_edit.text = caravan.interior_scene_path

	# Audio
	menu_open_sfx_edit.text = caravan.menu_open_sfx
	menu_close_sfx_edit.text = caravan.menu_close_sfx
	heal_sfx_edit.text = caravan.heal_sfx
	ambient_sfx_edit.text = caravan.ambient_sfx


## Override: Save UI data to resource
func _save_resource_data() -> void:
	var caravan: CaravanData = current_resource as CaravanData
	if not caravan:
		return

	# Identity
	caravan.caravan_id = caravan_id_edit.text.strip_edges()
	caravan.display_name = display_name_edit.text.strip_edges()

	# Appearance
	var sprite_path: String = wagon_sprite_path_edit.text.strip_edges()
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		caravan.wagon_sprite = load(sprite_path) as Texture2D
	else:
		caravan.wagon_sprite = null

	var anim_path: String = wagon_animation_path_edit.text.strip_edges()
	if not anim_path.is_empty() and ResourceLoader.exists(anim_path):
		caravan.wagon_animation_frames = load(anim_path) as SpriteFrames
	else:
		caravan.wagon_animation_frames = null

	caravan.wagon_scale = Vector2(wagon_scale_x_spin.value, wagon_scale_y_spin.value)
	caravan.z_index_offset = int(z_index_spin.value)

	# Following behavior
	caravan.follow_distance_tiles = int(follow_distance_spin.value)
	caravan.follow_speed = follow_speed_spin.value
	caravan.use_chain_following = use_chain_check.button_pressed
	caravan.max_history_size = int(max_history_spin.value)

	# Terrain restrictions
	caravan.can_cross_water = can_cross_water_check.button_pressed
	caravan.can_enter_forest = can_enter_forest_check.button_pressed
	caravan.blocked_terrain_types = _parse_terrain_list(blocked_terrain_edit.text)

	# Services
	caravan.has_item_storage = has_item_storage_check.button_pressed
	caravan.has_party_management = has_party_management_check.button_pressed
	caravan.has_rest_service = has_rest_check.button_pressed
	caravan.has_shop_service = has_shop_check.button_pressed
	caravan.has_promotion_service = has_promotion_check.button_pressed

	# Interior
	caravan.interior_scene_path = interior_scene_edit.text.strip_edges()

	# Audio
	caravan.menu_open_sfx = menu_open_sfx_edit.text.strip_edges()
	caravan.menu_close_sfx = menu_close_sfx_edit.text.strip_edges()
	caravan.heal_sfx = heal_sfx_edit.text.strip_edges()
	caravan.ambient_sfx = ambient_sfx_edit.text.strip_edges()


## Override: Validate resource before saving
func _validate_resource() -> Dictionary:
	var caravan: CaravanData = current_resource as CaravanData
	if not caravan:
		return {valid = false, errors = ["Invalid resource type"]}

	var errors: Array[String] = []

	# Validate caravan_id
	var caravan_id: String = caravan_id_edit.text.strip_edges()
	if caravan_id.is_empty():
		errors.append("Caravan ID cannot be empty")
	elif caravan_id.contains(" "):
		errors.append("Caravan ID cannot contain spaces")

	# Validate display_name
	if display_name_edit.text.strip_edges().is_empty():
		errors.append("Display name cannot be empty")

	# Validate follow distance
	if follow_distance_spin.value < 1:
		errors.append("Follow distance must be at least 1 tile")

	# Validate follow speed
	if follow_speed_spin.value <= 0:
		errors.append("Follow speed must be positive")

	# Validate max history size
	if max_history_spin.value < follow_distance_spin.value:
		errors.append("Max history size should be >= follow distance")

	# Validate wagon sprite if path provided
	var sprite_path: String = wagon_sprite_path_edit.text.strip_edges()
	if not sprite_path.is_empty() and not ResourceLoader.exists(sprite_path):
		errors.append("Wagon sprite path does not exist: " + sprite_path)

	# Validate animation frames path if provided
	var anim_path: String = wagon_animation_path_edit.text.strip_edges()
	if not anim_path.is_empty() and not ResourceLoader.exists(anim_path):
		errors.append("Animation frames path does not exist: " + anim_path)

	# Validate interior scene path if provided
	var interior_path: String = interior_scene_edit.text.strip_edges()
	if not interior_path.is_empty() and not ResourceLoader.exists(interior_path):
		errors.append("Interior scene path does not exist: " + interior_path)

	return {valid = errors.is_empty(), errors = errors}


## Override: Check for references before deletion
func _check_resource_references(_resource_to_check: Resource) -> Array[String]:
	# Caravans could be referenced by campaigns or save files
	# For now, return empty - caravan deletion is typically safe
	return []


## Override: Create a new caravan with defaults
func _create_new_resource() -> Resource:
	var new_caravan: CaravanData = CaravanData.new()
	new_caravan.caravan_id = "new_caravan"
	new_caravan.display_name = "New Caravan"
	new_caravan.follow_distance_tiles = 3
	new_caravan.follow_speed = 96.0
	new_caravan.use_chain_following = true
	new_caravan.max_history_size = 20
	new_caravan.wagon_scale = Vector2.ONE
	new_caravan.can_cross_water = true
	new_caravan.can_enter_forest = false
	new_caravan.blocked_terrain_types = ["mountain", "deep_water", "wall"]
	new_caravan.has_item_storage = true
	new_caravan.has_party_management = true
	new_caravan.has_rest_service = true
	new_caravan.has_shop_service = false
	new_caravan.has_promotion_service = false

	return new_caravan


## Override: Get the display name from a caravan resource
func _get_resource_display_name(resource: Resource) -> String:
	var caravan: CaravanData = resource as CaravanData
	if caravan:
		if caravan.display_name.is_empty():
			return caravan.caravan_id
		return caravan.display_name
	return "Unnamed Caravan"


# =============================================================================
# UI CREATION HELPERS
# =============================================================================

func _add_identity_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Identity"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	# Caravan ID
	var id_container: HBoxContainer = HBoxContainer.new()
	var id_label: Label = Label.new()
	id_label.text = "Caravan ID:"
	id_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	id_label.tooltip_text = "Unique identifier (namespaced: 'mod_id:caravan_id')"
	id_container.add_child(id_label)

	caravan_id_edit = LineEdit.new()
	caravan_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caravan_id_edit.placeholder_text = "e.g., base_game:default_caravan"
	caravan_id_edit.text_changed.connect(_mark_dirty)
	id_container.add_child(caravan_id_edit)
	section.add_child(id_container)

	# Display Name
	var name_container: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = "Display Name:"
	name_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	name_label.tooltip_text = "Name shown in UI (e.g., 'Caravan Headquarters')"
	name_container.add_child(name_label)

	display_name_edit = LineEdit.new()
	display_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_name_edit.placeholder_text = "e.g., Caravan Headquarters"
	display_name_edit.text_changed.connect(_mark_dirty)
	name_container.add_child(display_name_edit)
	section.add_child(name_container)

	detail_panel.add_child(section)


func _add_appearance_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Appearance"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Visual appearance of the caravan wagon on the overworld"
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	section.add_child(help_label)

	# Wagon Sprite
	var sprite_container: HBoxContainer = HBoxContainer.new()
	var sprite_label: Label = Label.new()
	sprite_label.text = "Wagon Sprite:"
	sprite_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	sprite_label.tooltip_text = "Main wagon texture (single frame or idle state)"
	sprite_container.add_child(sprite_label)

	wagon_sprite_path_edit = LineEdit.new()
	wagon_sprite_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wagon_sprite_path_edit.placeholder_text = "res://path/to/wagon.png"
	wagon_sprite_path_edit.text_changed.connect(_mark_dirty)
	sprite_container.add_child(wagon_sprite_path_edit)

	wagon_sprite_picker_btn = Button.new()
	wagon_sprite_picker_btn.text = "..."
	wagon_sprite_picker_btn.tooltip_text = "Browse for texture file"
	wagon_sprite_picker_btn.pressed.connect(_on_browse_wagon_sprite)
	sprite_container.add_child(wagon_sprite_picker_btn)
	section.add_child(sprite_container)

	# Animation Frames
	var anim_container: HBoxContainer = HBoxContainer.new()
	var anim_label: Label = Label.new()
	anim_label.text = "Animation Frames:"
	anim_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	anim_label.tooltip_text = "SpriteFrames for directional movement (optional)"
	anim_container.add_child(anim_label)

	wagon_animation_path_edit = LineEdit.new()
	wagon_animation_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wagon_animation_path_edit.placeholder_text = "res://path/to/wagon_animations.tres (optional)"
	wagon_animation_path_edit.text_changed.connect(_mark_dirty)
	anim_container.add_child(wagon_animation_path_edit)
	section.add_child(anim_container)

	# Scale
	var scale_container: HBoxContainer = HBoxContainer.new()
	var scale_label: Label = Label.new()
	scale_label.text = "Scale:"
	scale_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	scale_label.tooltip_text = "Scale factor for the wagon sprite"
	scale_container.add_child(scale_label)

	var x_label: Label = Label.new()
	x_label.text = "X:"
	scale_container.add_child(x_label)

	wagon_scale_x_spin = SpinBox.new()
	wagon_scale_x_spin.min_value = 0.1
	wagon_scale_x_spin.max_value = 10.0
	wagon_scale_x_spin.step = 0.1
	wagon_scale_x_spin.value = 1.0
	wagon_scale_x_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	scale_container.add_child(wagon_scale_x_spin)

	var y_label: Label = Label.new()
	y_label.text = "Y:"
	scale_container.add_child(y_label)

	wagon_scale_y_spin = SpinBox.new()
	wagon_scale_y_spin.min_value = 0.1
	wagon_scale_y_spin.max_value = 10.0
	wagon_scale_y_spin.step = 0.1
	wagon_scale_y_spin.value = 1.0
	wagon_scale_y_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	scale_container.add_child(wagon_scale_y_spin)
	section.add_child(scale_container)

	# Z-Index Offset
	var z_container: HBoxContainer = HBoxContainer.new()
	var z_label: Label = Label.new()
	z_label.text = "Z-Index Offset:"
	z_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	z_label.tooltip_text = "Rendering order offset (higher = in front)"
	z_container.add_child(z_label)

	z_index_spin = SpinBox.new()
	z_index_spin.min_value = -100
	z_index_spin.max_value = 100
	z_index_spin.value = 0
	z_index_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	z_container.add_child(z_index_spin)
	section.add_child(z_container)

	detail_panel.add_child(section)


func _add_following_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Following Behavior"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "How the caravan follows the party on overworld maps"
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	section.add_child(help_label)

	# Follow Distance
	var dist_container: HBoxContainer = HBoxContainer.new()
	var dist_label: Label = Label.new()
	dist_label.text = "Follow Distance:"
	dist_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	dist_label.tooltip_text = "Tiles behind the last party member (SF2 default: 2-3)"
	dist_container.add_child(dist_label)

	follow_distance_spin = SpinBox.new()
	follow_distance_spin.min_value = 1
	follow_distance_spin.max_value = 10
	follow_distance_spin.value = 3
	follow_distance_spin.suffix = " tiles"
	follow_distance_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	dist_container.add_child(follow_distance_spin)
	section.add_child(dist_container)

	# Follow Speed
	var speed_container: HBoxContainer = HBoxContainer.new()
	var speed_label: Label = Label.new()
	speed_label.text = "Follow Speed:"
	speed_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	speed_label.tooltip_text = "Movement speed in pixels per second"
	speed_container.add_child(speed_label)

	follow_speed_spin = SpinBox.new()
	follow_speed_spin.min_value = 16.0
	follow_speed_spin.max_value = 512.0
	follow_speed_spin.step = 8.0
	follow_speed_spin.value = 96.0
	follow_speed_spin.suffix = " px/s"
	follow_speed_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	speed_container.add_child(follow_speed_spin)
	section.add_child(speed_container)

	# Chain Following
	use_chain_check = CheckBox.new()
	use_chain_check.text = "Use Chain Following (SF2-Authentic)"
	use_chain_check.tooltip_text = "Follow breadcrumb trail instead of direct pathfinding"
	use_chain_check.button_pressed = true
	use_chain_check.toggled.connect(func(_pressed: bool) -> void: _mark_dirty())
	section.add_child(use_chain_check)

	# Max History Size
	var history_container: HBoxContainer = HBoxContainer.new()
	var history_label: Label = Label.new()
	history_label.text = "Max History Size:"
	history_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	history_label.tooltip_text = "Maximum tiles of movement history to maintain"
	history_container.add_child(history_label)

	max_history_spin = SpinBox.new()
	max_history_spin.min_value = 5
	max_history_spin.max_value = 100
	max_history_spin.value = 20
	max_history_spin.suffix = " tiles"
	max_history_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	history_container.add_child(max_history_spin)
	section.add_child(history_container)

	detail_panel.add_child(section)


func _add_terrain_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Terrain Restrictions"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Where the caravan can and cannot travel"
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	section.add_child(help_label)

	# Can Cross Water
	can_cross_water_check = CheckBox.new()
	can_cross_water_check.text = "Can Cross Water (ferries, bridges)"
	can_cross_water_check.tooltip_text = "Allow the caravan to use water crossings"
	can_cross_water_check.button_pressed = true
	can_cross_water_check.toggled.connect(func(_pressed: bool) -> void: _mark_dirty())
	section.add_child(can_cross_water_check)

	# Can Enter Forest
	can_enter_forest_check = CheckBox.new()
	can_enter_forest_check.text = "Can Enter Forest"
	can_enter_forest_check.tooltip_text = "Allow the caravan to enter forest tiles"
	can_enter_forest_check.button_pressed = false
	can_enter_forest_check.toggled.connect(func(_pressed: bool) -> void: _mark_dirty())
	section.add_child(can_enter_forest_check)

	# Blocked Terrain Types
	var blocked_container: HBoxContainer = HBoxContainer.new()
	var blocked_label: Label = Label.new()
	blocked_label.text = "Blocked Terrain:"
	blocked_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	blocked_label.tooltip_text = "Terrain types the caravan cannot traverse (comma-separated)"
	blocked_container.add_child(blocked_label)

	blocked_terrain_edit = LineEdit.new()
	blocked_terrain_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blocked_terrain_edit.placeholder_text = "mountain, deep_water, wall"
	blocked_terrain_edit.text_changed.connect(_mark_dirty)
	blocked_container.add_child(blocked_terrain_edit)
	section.add_child(blocked_container)

	detail_panel.add_child(section)


func _add_services_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Services Available"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Features offered by this caravan to the player"
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	section.add_child(help_label)

	# Item Storage
	has_item_storage_check = CheckBox.new()
	has_item_storage_check.text = "Item Storage (SF2's Depot)"
	has_item_storage_check.tooltip_text = "Enable storing items in the caravan"
	has_item_storage_check.button_pressed = true
	has_item_storage_check.toggled.connect(func(_pressed: bool) -> void: _mark_dirty())
	section.add_child(has_item_storage_check)

	# Party Management
	has_party_management_check = CheckBox.new()
	has_party_management_check.text = "Party Management"
	has_party_management_check.tooltip_text = "Enable swapping active/reserve members"
	has_party_management_check.button_pressed = true
	has_party_management_check.toggled.connect(func(_pressed: bool) -> void: _mark_dirty())
	section.add_child(has_party_management_check)

	# Rest Service
	has_rest_check = CheckBox.new()
	has_rest_check.text = "Rest Service (heal all party members)"
	has_rest_check.tooltip_text = "Enable free full heal for the party"
	has_rest_check.button_pressed = true
	has_rest_check.toggled.connect(func(_pressed: bool) -> void: _mark_dirty())
	section.add_child(has_rest_check)

	# Shop Service
	has_shop_check = CheckBox.new()
	has_shop_check.text = "Shop Service (typically false for base game)"
	has_shop_check.tooltip_text = "Enable buy/sell items inside the caravan"
	has_shop_check.button_pressed = false
	has_shop_check.toggled.connect(func(_pressed: bool) -> void: _mark_dirty())
	section.add_child(has_shop_check)

	# Promotion Service
	has_promotion_check = CheckBox.new()
	has_promotion_check.text = "Promotion Service (class promotion)"
	has_promotion_check.tooltip_text = "Enable class promotion inside the caravan"
	has_promotion_check.button_pressed = false
	has_promotion_check.toggled.connect(func(_pressed: bool) -> void: _mark_dirty())
	section.add_child(has_promotion_check)

	detail_panel.add_child(section)


func _add_interior_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Interior (Future)"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	var help_label: Label = Label.new()
	help_label.text = "Optional walkable interior scene (leave empty for standard menu)"
	help_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	help_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	section.add_child(help_label)

	# Interior Scene Path
	var interior_container: HBoxContainer = HBoxContainer.new()
	var interior_label: Label = Label.new()
	interior_label.text = "Interior Scene:"
	interior_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	interior_label.tooltip_text = "Path to a walkable interior scene (.tscn)"
	interior_container.add_child(interior_label)

	interior_scene_edit = LineEdit.new()
	interior_scene_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interior_scene_edit.placeholder_text = "res://path/to/interior.tscn (optional)"
	interior_scene_edit.text_changed.connect(_mark_dirty)
	interior_container.add_child(interior_scene_edit)
	section.add_child(interior_container)

	var note_label: Label = Label.new()
	note_label.text = "Note: Interior NPCs can be configured in the Godot Inspector"
	note_label.add_theme_color_override("font_color", SparklingEditorUtils.get_help_color())
	note_label.add_theme_font_size_override("font_size", SparklingEditorUtils.HELP_FONT_SIZE)
	section.add_child(note_label)

	detail_panel.add_child(section)


func _add_audio_section() -> void:
	var section: VBoxContainer = VBoxContainer.new()

	var section_label: Label = Label.new()
	section_label.text = "Audio"
	section_label.add_theme_font_size_override("font_size", SparklingEditorUtils.SECTION_FONT_SIZE)
	section.add_child(section_label)

	# Menu Open SFX
	var open_container: HBoxContainer = HBoxContainer.new()
	var open_label: Label = Label.new()
	open_label.text = "Menu Open SFX:"
	open_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	open_label.tooltip_text = "Sound when opening the caravan menu"
	open_container.add_child(open_label)

	menu_open_sfx_edit = LineEdit.new()
	menu_open_sfx_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_open_sfx_edit.placeholder_text = "e.g., caravan_open"
	menu_open_sfx_edit.text_changed.connect(_mark_dirty)
	open_container.add_child(menu_open_sfx_edit)
	section.add_child(open_container)

	# Menu Close SFX
	var close_container: HBoxContainer = HBoxContainer.new()
	var close_label: Label = Label.new()
	close_label.text = "Menu Close SFX:"
	close_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	close_label.tooltip_text = "Sound when closing the caravan menu"
	close_container.add_child(close_label)

	menu_close_sfx_edit = LineEdit.new()
	menu_close_sfx_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_close_sfx_edit.placeholder_text = "e.g., caravan_close"
	menu_close_sfx_edit.text_changed.connect(_mark_dirty)
	close_container.add_child(menu_close_sfx_edit)
	section.add_child(close_container)

	# Heal SFX
	var heal_container: HBoxContainer = HBoxContainer.new()
	var heal_label: Label = Label.new()
	heal_label.text = "Heal/Rest SFX:"
	heal_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	heal_label.tooltip_text = "Sound when using the rest service"
	heal_container.add_child(heal_label)

	heal_sfx_edit = LineEdit.new()
	heal_sfx_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heal_sfx_edit.placeholder_text = "e.g., heal_jingle"
	heal_sfx_edit.text_changed.connect(_mark_dirty)
	heal_container.add_child(heal_sfx_edit)
	section.add_child(heal_container)

	# Ambient SFX
	var ambient_container: HBoxContainer = HBoxContainer.new()
	var ambient_label: Label = Label.new()
	ambient_label.text = "Ambient SFX:"
	ambient_label.custom_minimum_size.x = SparklingEditorUtils.DEFAULT_LABEL_WIDTH
	ambient_label.tooltip_text = "Ambient sound while menu is open (optional)"
	ambient_container.add_child(ambient_label)

	ambient_sfx_edit = LineEdit.new()
	ambient_sfx_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ambient_sfx_edit.placeholder_text = "e.g., campfire_crackle (optional)"
	ambient_sfx_edit.text_changed.connect(_mark_dirty)
	ambient_container.add_child(ambient_sfx_edit)
	section.add_child(ambient_container)

	detail_panel.add_child(section)


# =============================================================================
# HELPERS
# =============================================================================

## Parse comma-separated terrain types into an array
func _parse_terrain_list(text: String) -> Array[String]:
	var types: Array[String] = []
	var parts: PackedStringArray = text.split(",")
	for part: String in parts:
		var trimmed: String = part.strip_edges().to_lower()
		if not trimmed.is_empty():
			types.append(trimmed)
	return types


## Open file browser for wagon sprite
func _on_browse_wagon_sprite() -> void:
	var dialog: EditorFileDialog = EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.png", "PNG Images")
	dialog.add_filter("*.jpg,*.jpeg", "JPEG Images")
	dialog.add_filter("*.webp", "WebP Images")
	dialog.add_filter("*.svg", "SVG Images")
	dialog.file_selected.connect(_on_wagon_sprite_selected)
	add_child(dialog)
	dialog.popup_centered_ratio(0.7)


## Handle wagon sprite file selection
func _on_wagon_sprite_selected(path: String) -> void:
	wagon_sprite_path_edit.text = path
	_mark_dirty()
