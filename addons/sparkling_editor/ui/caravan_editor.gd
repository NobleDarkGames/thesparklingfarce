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
	var form: SparklingEditorUtils.FormBuilder = SparklingEditorUtils.create_form(detail_panel)
	form.on_change(_mark_dirty)

	_add_identity_section(form)
	_add_appearance_section(form)
	_add_following_section(form)
	_add_terrain_section(form)
	_add_services_section(form)
	_add_interior_section(form)
	_add_audio_section(form)

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

func _add_identity_section(form: SparklingEditorUtils.FormBuilder) -> void:
	form.add_section("Identity")

	caravan_id_edit = form.add_text_field("Caravan ID:", "e.g., base_game:default_caravan",
		"Unique identifier (namespaced: 'mod_id:caravan_id')")

	display_name_edit = form.add_text_field("Display Name:", "e.g., Caravan Headquarters",
		"Name shown in UI")


func _add_appearance_section(form: SparklingEditorUtils.FormBuilder) -> void:
	form.add_section("Appearance")
	form.add_help_text("Visual appearance of the caravan wagon on the overworld")

	# Wagon Sprite with browse button
	var sprite_row: HBoxContainer = HBoxContainer.new()
	sprite_row.add_theme_constant_override("separation", 8)

	wagon_sprite_path_edit = LineEdit.new()
	wagon_sprite_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wagon_sprite_path_edit.placeholder_text = "res://path/to/wagon.png"
	wagon_sprite_path_edit.text_changed.connect(func(_t: String) -> void: _mark_dirty())
	sprite_row.add_child(wagon_sprite_path_edit)

	wagon_sprite_picker_btn = Button.new()
	wagon_sprite_picker_btn.text = "..."
	wagon_sprite_picker_btn.tooltip_text = "Browse for texture file"
	wagon_sprite_picker_btn.pressed.connect(_on_browse_wagon_sprite)
	sprite_row.add_child(wagon_sprite_picker_btn)

	form.add_labeled_control("Wagon Sprite:", sprite_row,
		"Main wagon texture (single frame or idle state)")

	wagon_animation_path_edit = form.add_text_field("Animation Frames:",
		"res://path/to/wagon_animations.tres (optional)",
		"SpriteFrames for directional movement (optional)")

	# Scale fields (custom row with X/Y labels)
	var scale_row: HBoxContainer = HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 8)

	var x_label: Label = Label.new()
	x_label.text = "X:"
	scale_row.add_child(x_label)

	wagon_scale_x_spin = SpinBox.new()
	wagon_scale_x_spin.min_value = 0.1
	wagon_scale_x_spin.max_value = 10.0
	wagon_scale_x_spin.step = 0.1
	wagon_scale_x_spin.value = 1.0
	wagon_scale_x_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	scale_row.add_child(wagon_scale_x_spin)

	var y_label: Label = Label.new()
	y_label.text = "Y:"
	scale_row.add_child(y_label)

	wagon_scale_y_spin = SpinBox.new()
	wagon_scale_y_spin.min_value = 0.1
	wagon_scale_y_spin.max_value = 10.0
	wagon_scale_y_spin.step = 0.1
	wagon_scale_y_spin.value = 1.0
	wagon_scale_y_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	scale_row.add_child(wagon_scale_y_spin)

	form.add_labeled_control("Scale:", scale_row, "Scale factor for the wagon sprite")

	z_index_spin = form.add_number_field("Z-Index Offset:", -100, 100, 0,
		"Rendering order offset (higher = in front)")


func _add_following_section(form: SparklingEditorUtils.FormBuilder) -> void:
	form.add_section("Following Behavior")
	form.add_help_text("How the caravan follows the party on overworld maps")

	follow_distance_spin = form.add_number_field("Follow Distance:", 1, 10, 3,
		"Tiles behind the last party member (SF2 default: 2-3)")
	follow_distance_spin.suffix = " tiles"

	follow_speed_spin = form.add_number_field("Follow Speed:", 16.0, 512.0, 96.0,
		"Movement speed in pixels per second", 8.0)
	follow_speed_spin.suffix = " px/s"

	use_chain_check = form.add_standalone_checkbox("Use Chain Following (SF2-Authentic)", true,
		"Follow breadcrumb trail instead of direct pathfinding")

	max_history_spin = form.add_number_field("Max History Size:", 5, 100, 20,
		"Maximum tiles of movement history to maintain")
	max_history_spin.suffix = " tiles"


func _add_terrain_section(form: SparklingEditorUtils.FormBuilder) -> void:
	form.add_section("Terrain Restrictions")
	form.add_help_text("Where the caravan can and cannot travel")

	can_cross_water_check = form.add_standalone_checkbox("Can Cross Water (ferries, bridges)", true,
		"Allow the caravan to use water crossings")

	can_enter_forest_check = form.add_standalone_checkbox("Can Enter Forest", false,
		"Allow the caravan to enter forest tiles")

	blocked_terrain_edit = form.add_text_field("Blocked Terrain:", "mountain, deep_water, wall",
		"Terrain types the caravan cannot traverse (comma-separated)")


func _add_services_section(form: SparklingEditorUtils.FormBuilder) -> void:
	form.add_section("Services Available")
	form.add_help_text("Features offered by this caravan to the player")

	has_item_storage_check = form.add_standalone_checkbox("Item Storage (SF2's Depot)", true,
		"Enable storing items in the caravan")

	has_party_management_check = form.add_standalone_checkbox("Party Management", true,
		"Enable swapping active/reserve members")

	has_rest_check = form.add_standalone_checkbox("Rest Service (heal all party members)", true,
		"Enable free full heal for the party")

	has_shop_check = form.add_standalone_checkbox("Shop Service (typically false for base game)", false,
		"Enable buy/sell items inside the caravan")

	has_promotion_check = form.add_standalone_checkbox("Promotion Service (class promotion)", false,
		"Enable class promotion inside the caravan")


func _add_interior_section(form: SparklingEditorUtils.FormBuilder) -> void:
	form.add_section("Interior (Future)")
	form.add_help_text("Optional walkable interior scene (leave empty for standard menu)")

	interior_scene_edit = form.add_text_field("Interior Scene:",
		"res://path/to/interior.tscn (optional)",
		"Path to a walkable interior scene (.tscn)")

	form.add_help_text("Note: Interior NPCs can be configured in the Godot Inspector")


func _add_audio_section(form: SparklingEditorUtils.FormBuilder) -> void:
	form.add_section("Audio")

	menu_open_sfx_edit = form.add_text_field("Menu Open SFX:", "e.g., caravan_open",
		"Sound when opening the caravan menu")

	menu_close_sfx_edit = form.add_text_field("Menu Close SFX:", "e.g., caravan_close",
		"Sound when closing the caravan menu")

	heal_sfx_edit = form.add_text_field("Heal/Rest SFX:", "e.g., heal_jingle",
		"Sound when using the rest service")

	ambient_sfx_edit = form.add_text_field("Ambient SFX:", "e.g., campfire_crackle (optional)",
		"Ambient sound while menu is open (optional)")


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
	# Free dialog when closed (file selected, canceled, or X button)
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible:
			dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered_ratio(0.7)


## Handle wagon sprite file selection
func _on_wagon_sprite_selected(path: String) -> void:
	wagon_sprite_path_edit.text = path
	_mark_dirty()
