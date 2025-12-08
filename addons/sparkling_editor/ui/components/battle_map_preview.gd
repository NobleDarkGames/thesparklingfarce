@tool
class_name BattleMapPreview
extends Control

## Battle Map Preview Component
##
## Renders a battle map scene with position markers for player spawn, enemies, and neutrals.
## Provides click-to-place functionality for positioning units visually.
##
## Usage:
##   var preview = BattleMapPreview.new()
##   preview.set_map_scene_path("res://mods/<mod_id>/maps/battle_map.tscn")
##   preview.set_player_spawn(Vector2i(2, 2))
##   preview.add_enemy_marker(0, Vector2i(10, 5))
##   preview.position_clicked.connect(_on_position_clicked)

## Emitted when user clicks on the map preview
## mode: "player_spawn", "enemy", or "neutral"
## index: For enemies/neutrals, the unit index (-1 for player spawn)
## grid_position: The clicked grid coordinate
signal position_clicked(mode: String, index: int, grid_position: Vector2i)

## Emitted when map loading completes or fails
signal map_loaded(success: bool)

# Constants for marker rendering
const MARKER_RADIUS: float = 12.0
const PLAYER_SPAWN_COLOR: Color = Color(0.2, 0.4, 1.0, 0.8)  # Blue
const ENEMY_COLOR: Color = Color(1.0, 0.2, 0.2, 0.8)  # Red
const NEUTRAL_COLOR: Color = Color(1.0, 0.9, 0.2, 0.8)  # Yellow
const MARKER_OUTLINE_COLOR: Color = Color(0.1, 0.1, 0.1, 0.9)
const GRID_LINE_COLOR: Color = Color(0.5, 0.5, 0.5, 0.3)

# Placement mode for click-to-place
enum PlacementMode { NONE, PLAYER_SPAWN, ENEMY, NEUTRAL }

# Internal state
var _current_map_path: String = ""
var _map_scene: PackedScene = null
var _map_instance: Node2D = null
var _cell_size: int = 32  # Default, updated from map scene if possible

# Position markers
var _player_spawn_position: Vector2i = Vector2i(2, 2)
var _enemy_positions: Array[Dictionary] = []  # [{index: int, position: Vector2i, label: String}]
var _neutral_positions: Array[Dictionary] = []

# Placement mode
var _placement_mode: PlacementMode = PlacementMode.NONE
var _placement_index: int = -1

# UI components
var _viewport: SubViewport
var _viewport_container: SubViewportContainer
var _marker_overlay: Control
var _loading_label: Label
var _error_label: Label
var _zoom_level: float = 0.5  # Default zoom for preview

# Display state
var _map_bounds: Rect2i = Rect2i(0, 0, 640, 360)
var _show_grid: bool = true


func _init() -> void:
	custom_minimum_size = Vector2(300, 200)


func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	# Main container with border
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_right", 2)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	# Header with controls
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)

	var title: Label = Label.new()
	title.text = "Map Preview"
	title.add_theme_font_size_override("font_size", 16)
	header.add_child(title)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var grid_check: CheckBox = CheckBox.new()
	grid_check.text = "Grid"
	grid_check.button_pressed = _show_grid
	grid_check.toggled.connect(_on_grid_toggled)
	header.add_child(grid_check)

	vbox.add_child(header)

	# SubViewport container for map rendering
	_viewport_container = SubViewportContainer.new()
	_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport_container.stretch = true
	_viewport_container.custom_minimum_size = Vector2(280, 180)
	vbox.add_child(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_viewport.transparent_bg = false
	_viewport.gui_disable_input = true
	_viewport_container.add_child(_viewport)

	# Marker overlay (rendered on top of the viewport texture)
	_marker_overlay = Control.new()
	_marker_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marker_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_marker_overlay.gui_input.connect(_on_overlay_gui_input)
	_viewport_container.add_child(_marker_overlay)

	# Custom draw for markers
	_marker_overlay.draw.connect(_draw_markers)

	# Loading indicator
	_loading_label = Label.new()
	_loading_label.text = "Select a map..."
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_loading_label.add_theme_color_override("font_color", EditorThemeUtils.get_help_color())
	_viewport_container.add_child(_loading_label)

	# Error label (hidden by default)
	_error_label = Label.new()
	_error_label.visible = false
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_error_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_error_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_viewport_container.add_child(_error_label)


## Set the map scene to preview
func set_map_scene_path(path: String) -> void:
	if path == _current_map_path:
		return

	_current_map_path = path
	_load_map_scene()


## Set the map scene directly from a PackedScene
func set_map_scene(scene: PackedScene) -> void:
	if scene == null:
		clear_map()
		return

	_map_scene = scene
	_current_map_path = scene.resource_path if scene else ""
	_instantiate_map()


## Clear the current map preview
func clear_map() -> void:
	_current_map_path = ""
	_map_scene = null

	if _map_instance and is_instance_valid(_map_instance):
		_map_instance.queue_free()
		_map_instance = null

	_loading_label.text = "Select a map..."
	_loading_label.visible = true
	_error_label.visible = false
	_marker_overlay.queue_redraw()


## Set player spawn position
func set_player_spawn(position: Vector2i) -> void:
	_player_spawn_position = position
	_marker_overlay.queue_redraw()


## Clear all enemy markers and set new ones
func set_enemy_positions(enemies: Array[Dictionary]) -> void:
	_enemy_positions.clear()
	for i in range(enemies.size()):
		var enemy: Dictionary = enemies[i]
		if "position" in enemy:
			_enemy_positions.append({
				"index": i,
				"position": enemy.position as Vector2i,
				"label": str(i + 1)
			})
	_marker_overlay.queue_redraw()


## Add or update a single enemy marker
func set_enemy_position(index: int, position: Vector2i) -> void:
	# Find existing or add new
	var found: bool = false
	for entry in _enemy_positions:
		if entry.index == index:
			entry.position = position
			found = true
			break

	if not found:
		_enemy_positions.append({
			"index": index,
			"position": position,
			"label": str(index + 1)
		})

	_marker_overlay.queue_redraw()


## Remove an enemy marker
func remove_enemy_marker(index: int) -> void:
	for i in range(_enemy_positions.size() - 1, -1, -1):
		if _enemy_positions[i].index == index:
			_enemy_positions.remove_at(i)
			break
	_marker_overlay.queue_redraw()


## Clear all enemy markers
func clear_enemy_markers() -> void:
	_enemy_positions.clear()
	_marker_overlay.queue_redraw()


## Set neutral unit positions
func set_neutral_positions(neutrals: Array[Dictionary]) -> void:
	_neutral_positions.clear()
	for i in range(neutrals.size()):
		var neutral: Dictionary = neutrals[i]
		if "position" in neutral:
			_neutral_positions.append({
				"index": i,
				"position": neutral.position as Vector2i,
				"label": "N" + str(i + 1)
			})
	_marker_overlay.queue_redraw()


## Add or update a single neutral marker
func set_neutral_position(index: int, position: Vector2i) -> void:
	var found: bool = false
	for entry in _neutral_positions:
		if entry.index == index:
			entry.position = position
			found = true
			break

	if not found:
		_neutral_positions.append({
			"index": index,
			"position": position,
			"label": "N" + str(index + 1)
		})

	_marker_overlay.queue_redraw()


## Remove a neutral marker
func remove_neutral_marker(index: int) -> void:
	for i in range(_neutral_positions.size() - 1, -1, -1):
		if _neutral_positions[i].index == index:
			_neutral_positions.remove_at(i)
			break
	_marker_overlay.queue_redraw()


## Clear all neutral markers
func clear_neutral_markers() -> void:
	_neutral_positions.clear()
	_marker_overlay.queue_redraw()


## Enter placement mode - next click will set a position
func start_placement(mode: String, index: int = -1) -> void:
	match mode:
		"player_spawn":
			_placement_mode = PlacementMode.PLAYER_SPAWN
			_placement_index = -1
		"enemy":
			_placement_mode = PlacementMode.ENEMY
			_placement_index = index
		"neutral":
			_placement_mode = PlacementMode.NEUTRAL
			_placement_index = index
		_:
			_placement_mode = PlacementMode.NONE
			_placement_index = -1

	# Update cursor
	if _placement_mode != PlacementMode.NONE:
		_marker_overlay.mouse_default_cursor_shape = Control.CURSOR_CROSS
	else:
		_marker_overlay.mouse_default_cursor_shape = Control.CURSOR_ARROW


## Cancel placement mode
func cancel_placement() -> void:
	_placement_mode = PlacementMode.NONE
	_placement_index = -1
	_marker_overlay.mouse_default_cursor_shape = Control.CURSOR_ARROW


## Check if in placement mode
func is_placing() -> bool:
	return _placement_mode != PlacementMode.NONE


## Set zoom level (0.25 to 2.0)
func set_zoom(level: float) -> void:
	_zoom_level = clampf(level, 0.25, 2.0)
	_update_viewport_camera()
	_marker_overlay.queue_redraw()


## Toggle grid visibility
func set_show_grid(show: bool) -> void:
	_show_grid = show
	_marker_overlay.queue_redraw()


# Private Methods

func _load_map_scene() -> void:
	if _current_map_path.is_empty():
		clear_map()
		return

	_loading_label.text = "Loading..."
	_loading_label.visible = true
	_error_label.visible = false

	# Check if file exists
	if not FileAccess.file_exists(_current_map_path):
		_show_error("Map file not found:\n" + _current_map_path.get_file())
		map_loaded.emit(false)
		return

	# Load the scene
	_map_scene = load(_current_map_path) as PackedScene
	if _map_scene == null:
		_show_error("Failed to load map scene")
		map_loaded.emit(false)
		return

	_instantiate_map()


func _instantiate_map() -> void:
	# Clear existing instance
	if _map_instance and is_instance_valid(_map_instance):
		_map_instance.queue_free()
		_map_instance = null

	if _map_scene == null:
		_show_error("No map scene loaded")
		map_loaded.emit(false)
		return

	# Instantiate the scene
	_map_instance = _map_scene.instantiate() as Node2D
	if _map_instance == null:
		_show_error("Failed to instantiate map")
		map_loaded.emit(false)
		return

	# Add to viewport
	_viewport.add_child(_map_instance)

	# Find TileMapLayer(s) and extract info
	_extract_map_info()

	# Update viewport rendering
	_update_viewport_camera()

	# Trigger a render
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	# Hide loading, show success
	_loading_label.visible = false
	_error_label.visible = false
	_marker_overlay.queue_redraw()

	map_loaded.emit(true)


func _extract_map_info() -> void:
	if not _map_instance:
		return

	# Try to find TileMapLayer and extract cell size and bounds
	var tilemap: TileMapLayer = _find_tilemap_layer(_map_instance)
	if tilemap:
		var tileset: TileSet = tilemap.tile_set
		if tileset:
			_cell_size = tileset.tile_size.x  # Assume square tiles

		# Calculate map bounds from used tiles
		var used_rect: Rect2i = tilemap.get_used_rect()
		if used_rect.size.x > 0 and used_rect.size.y > 0:
			_map_bounds = Rect2i(
				used_rect.position * _cell_size,
				used_rect.size * _cell_size
			)
		else:
			# Fallback to default
			_map_bounds = Rect2i(0, 0, 640, 360)

	# Try to get Grid resource if available
	var grid: Grid = _find_grid_resource(_map_instance)
	if grid:
		_cell_size = grid.cell_size


func _find_tilemap_layer(node: Node) -> TileMapLayer:
	# First check immediate children
	for child: Node in node.get_children():
		if child is TileMapLayer:
			return child as TileMapLayer

	# Check one level deeper (Map/GroundLayer pattern)
	for child: Node in node.get_children():
		if child.name == "Map":
			for grandchild: Node in child.get_children():
				if grandchild is TileMapLayer:
					return grandchild as TileMapLayer

	# Recursive search as fallback
	for child: Node in node.get_children():
		var result: TileMapLayer = _find_tilemap_layer(child)
		if result:
			return result

	return null


func _find_grid_resource(node: Node) -> Grid:
	# Check if node has a grid property
	if "grid" in node and node.grid is Grid:
		return node.grid as Grid

	# Check children
	for child: Node in node.get_children():
		var result: Grid = _find_grid_resource(child)
		if result:
			return result

	return null


func _update_viewport_camera() -> void:
	if not _map_instance:
		return

	# Find or create camera
	var camera: Camera2D = null
	for child: Node in _viewport.get_children():
		if child is Camera2D:
			camera = child as Camera2D
			break

	if not camera:
		camera = Camera2D.new()
		camera.name = "PreviewCamera"
		_viewport.add_child(camera)

	# Center camera on map
	camera.position = Vector2(_map_bounds.position) + Vector2(_map_bounds.size) / 2.0
	camera.zoom = Vector2(_zoom_level, _zoom_level)
	camera.enabled = true

	# Adjust viewport size to match map aspect ratio (roughly)
	var target_size: Vector2i = Vector2i(
		int(_map_bounds.size.x * _zoom_level),
		int(_map_bounds.size.y * _zoom_level)
	)
	# Clamp to reasonable size
	target_size.x = clampi(target_size.x, 320, 1280)
	target_size.y = clampi(target_size.y, 180, 720)
	_viewport.size = target_size


func _show_error(message: String) -> void:
	_loading_label.visible = false
	_error_label.text = message
	_error_label.visible = true


func _on_grid_toggled(pressed: bool) -> void:
	set_show_grid(pressed)


func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_handle_click(mouse_event.position)


func _handle_click(screen_pos: Vector2) -> void:
	if not _map_instance:
		return

	# Convert screen position to grid position
	var grid_pos: Vector2i = _screen_to_grid(screen_pos)

	# Emit signal based on placement mode
	match _placement_mode:
		PlacementMode.PLAYER_SPAWN:
			position_clicked.emit("player_spawn", -1, grid_pos)
		PlacementMode.ENEMY:
			position_clicked.emit("enemy", _placement_index, grid_pos)
		PlacementMode.NEUTRAL:
			position_clicked.emit("neutral", _placement_index, grid_pos)
		PlacementMode.NONE:
			# Even without placement mode, emit for potential use
			position_clicked.emit("none", -1, grid_pos)

	# Exit placement mode after click
	cancel_placement()


func _screen_to_grid(screen_pos: Vector2) -> Vector2i:
	if not _marker_overlay:
		return Vector2i.ZERO

	# Get the overlay size
	var overlay_size: Vector2 = _marker_overlay.size

	# Scale factor from overlay to viewport
	var viewport_size: Vector2 = Vector2(_viewport.size)
	var scale_x: float = viewport_size.x / overlay_size.x
	var scale_y: float = viewport_size.y / overlay_size.y

	# Find camera position and zoom
	var camera_pos: Vector2 = Vector2(_map_bounds.position) + Vector2(_map_bounds.size) / 2.0
	var camera_zoom: Vector2 = Vector2(_zoom_level, _zoom_level)

	# Convert screen position to world position
	var viewport_pos: Vector2 = screen_pos * Vector2(scale_x, scale_y)
	var world_pos: Vector2 = camera_pos + (viewport_pos - viewport_size / 2.0) / camera_zoom

	# Convert world position to grid
	var grid_x: int = int(world_pos.x / _cell_size)
	var grid_y: int = int(world_pos.y / _cell_size)

	return Vector2i(maxi(0, grid_x), maxi(0, grid_y))


func _grid_to_screen(grid_pos: Vector2i) -> Vector2:
	if not _marker_overlay:
		return Vector2.ZERO

	# Get the overlay size
	var overlay_size: Vector2 = _marker_overlay.size

	# Scale factor from viewport to overlay
	var viewport_size: Vector2 = Vector2(_viewport.size)
	var scale_x: float = overlay_size.x / viewport_size.x
	var scale_y: float = overlay_size.y / viewport_size.y

	# Find camera position and zoom
	var camera_pos: Vector2 = Vector2(_map_bounds.position) + Vector2(_map_bounds.size) / 2.0
	var camera_zoom: Vector2 = Vector2(_zoom_level, _zoom_level)

	# World position (center of cell)
	var world_pos: Vector2 = Vector2(grid_pos) * _cell_size + Vector2(_cell_size, _cell_size) / 2.0

	# Convert to viewport position
	var viewport_pos: Vector2 = (world_pos - camera_pos) * camera_zoom + viewport_size / 2.0

	# Convert to screen/overlay position
	var screen_pos: Vector2 = viewport_pos * Vector2(scale_x, scale_y)

	return screen_pos


func _draw_markers() -> void:
	if not _marker_overlay:
		return

	var overlay: Control = _marker_overlay

	# Draw grid if enabled
	if _show_grid and _map_instance:
		_draw_grid(overlay)

	# Draw player spawn marker (blue)
	var spawn_screen: Vector2 = _grid_to_screen(_player_spawn_position)
	_draw_marker(overlay, spawn_screen, PLAYER_SPAWN_COLOR, "P")

	# Draw enemy markers (red)
	for enemy_data: Dictionary in _enemy_positions:
		var pos: Vector2i = enemy_data.position
		var label: String = enemy_data.label
		var enemy_screen: Vector2 = _grid_to_screen(pos)
		_draw_marker(overlay, enemy_screen, ENEMY_COLOR, label)

	# Draw neutral markers (yellow)
	for neutral_data: Dictionary in _neutral_positions:
		var pos: Vector2i = neutral_data.position
		var label: String = neutral_data.label
		var neutral_screen: Vector2 = _grid_to_screen(pos)
		_draw_marker(overlay, neutral_screen, NEUTRAL_COLOR, label)

	# Draw placement indicator if in placement mode
	if _placement_mode != PlacementMode.NONE:
		var mode_color: Color
		match _placement_mode:
			PlacementMode.PLAYER_SPAWN:
				mode_color = PLAYER_SPAWN_COLOR
			PlacementMode.ENEMY:
				mode_color = ENEMY_COLOR
			PlacementMode.NEUTRAL:
				mode_color = NEUTRAL_COLOR
			_:
				mode_color = Color.WHITE

		# Draw pulsing hint at bottom
		var hint_text: String = "Click to place"
		overlay.draw_string(
			ThemeDB.fallback_font,
			Vector2(8, overlay.size.y - 8),
			hint_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			mode_color
		)


func _draw_grid(overlay: Control) -> void:
	if _map_bounds.size.x <= 0 or _map_bounds.size.y <= 0:
		return

	# Calculate visible grid range
	var grid_start: Vector2i = Vector2i(
		int(_map_bounds.position.x / _cell_size),
		int(_map_bounds.position.y / _cell_size)
	)
	var grid_end: Vector2i = Vector2i(
		int((_map_bounds.position.x + _map_bounds.size.x) / _cell_size) + 1,
		int((_map_bounds.position.y + _map_bounds.size.y) / _cell_size) + 1
	)

	# Draw vertical lines
	for x in range(grid_start.x, grid_end.x + 1):
		var start_screen: Vector2 = _grid_to_screen(Vector2i(x, grid_start.y)) - Vector2(_cell_size / 2.0, _cell_size / 2.0) * _zoom_level
		var end_screen: Vector2 = _grid_to_screen(Vector2i(x, grid_end.y)) - Vector2(_cell_size / 2.0, _cell_size / 2.0) * _zoom_level
		overlay.draw_line(start_screen, end_screen, GRID_LINE_COLOR, 1.0)

	# Draw horizontal lines
	for y in range(grid_start.y, grid_end.y + 1):
		var start_screen: Vector2 = _grid_to_screen(Vector2i(grid_start.x, y)) - Vector2(_cell_size / 2.0, _cell_size / 2.0) * _zoom_level
		var end_screen: Vector2 = _grid_to_screen(Vector2i(grid_end.x, y)) - Vector2(_cell_size / 2.0, _cell_size / 2.0) * _zoom_level
		overlay.draw_line(start_screen, end_screen, GRID_LINE_COLOR, 1.0)


func _draw_marker(overlay: Control, position: Vector2, color: Color, label: String) -> void:
	# Check if position is within visible area
	if position.x < -MARKER_RADIUS or position.x > overlay.size.x + MARKER_RADIUS:
		return
	if position.y < -MARKER_RADIUS or position.y > overlay.size.y + MARKER_RADIUS:
		return

	# Draw outline
	overlay.draw_circle(position, MARKER_RADIUS + 2, MARKER_OUTLINE_COLOR)

	# Draw filled circle
	overlay.draw_circle(position, MARKER_RADIUS, color)

	# Draw label
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 10
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos: Vector2 = position - text_size / 2.0 + Vector2(0, font_size / 3.0)

	overlay.draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


## Update markers to match viewport resizing
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if _marker_overlay:
			_marker_overlay.queue_redraw()
