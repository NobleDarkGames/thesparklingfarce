class_name BattleMapOverlay
extends Control

## BattleMapOverlay - Full-screen tactical map view
##
## Displays a zoomed-out view of the entire battlefield with colored dots
## representing unit positions. SF2-authentic tactical overview.
##
## Colors:
## - Blue dots: Player units (allies)
## - Red dots: Enemy units
## - Yellow dots: Neutral units
## - Green dot: Currently active unit (pulsing)
##
## Dismissal: B button or click anywhere

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when overlay is closed
signal overlay_closed()

# =============================================================================
# CONSTANTS
# =============================================================================

const BG_COLOR: Color = Color(0.05, 0.08, 0.12, 0.95)
const BORDER_COLOR: Color = Color(0.4, 0.4, 0.5, 1.0)
const BORDER_WIDTH: int = 2

# Unit dot colors
const COLOR_PLAYER: Color = Color(0.3, 0.5, 1.0, 1.0)  # Blue
const COLOR_ENEMY: Color = Color(1.0, 0.3, 0.3, 1.0)   # Red
const COLOR_NEUTRAL: Color = Color(1.0, 0.9, 0.3, 1.0) # Yellow
const COLOR_ACTIVE: Color = Color(0.3, 1.0, 0.4, 1.0)  # Green (active unit)

# Dot sizing
const DOT_RADIUS: float = 6.0
const ACTIVE_DOT_RADIUS: float = 8.0

# Map display padding from screen edges
const MAP_PADDING: float = 32.0

# Terrain colors (simplified)
const COLOR_TERRAIN_WALKABLE: Color = Color(0.15, 0.2, 0.15, 1.0)
const COLOR_TERRAIN_BLOCKED: Color = Color(0.25, 0.2, 0.18, 1.0)
const COLOR_TERRAIN_WATER: Color = Color(0.1, 0.15, 0.3, 1.0)

# Font
const MONOGRAM_FONT: Font = preload("res://assets/fonts/monogram.ttf")
const FONT_SIZE: int = 16

# Pulse animation for active unit
const PULSE_DURATION: float = 0.8

# =============================================================================
# STATE
# =============================================================================

## Whether the overlay is currently showing
var _is_active: bool = false

## Pulse animation time
var _pulse_time: float = 0.0

## Cached unit positions for drawing
var _player_positions: Array[Vector2] = []
var _enemy_positions: Array[Vector2] = []
var _neutral_positions: Array[Vector2] = []
var _active_position: Vector2 = Vector2.ZERO
var _has_active_unit: bool = false

## Map bounds in grid coordinates
var _grid_size: Vector2i = Vector2i.ZERO

## Transform from grid to screen
var _grid_to_screen_scale: Vector2 = Vector2.ONE
var _grid_to_screen_offset: Vector2 = Vector2.ZERO

## Cached tile colors for minimap (sampled from tilemap texture)
var _tile_colors: Array[Color] = []
var _tile_colors_valid: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	visible = false
	set_process_input(false)
	set_process(false)

	# Full screen coverage
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	if not _is_active:
		return

	# Update pulse animation
	_pulse_time += delta
	queue_redraw()


func _draw() -> void:
	if not _is_active:
		return

	# Use viewport rect for full-screen overlay (get_rect() may not reflect anchor sizing)
	var rect: Rect2 = get_viewport_rect()

	# Draw background
	draw_rect(rect, BG_COLOR)

	# Draw border
	draw_rect(rect, BORDER_COLOR, false, BORDER_WIDTH)

	# Calculate map display area
	var map_rect: Rect2 = _calculate_map_rect(rect)

	# Draw map background (simple grid representation)
	_draw_map_background(map_rect)

	# Draw unit dots
	_draw_units(map_rect)

	# Draw legend
	_draw_legend(rect)

	# Draw title
	_draw_title(rect)


# =============================================================================
# PUBLIC API
# =============================================================================

## Show the map overlay
func show_overlay() -> void:
	# Gather unit data
	_gather_unit_data()

	# Get grid size from GridManager
	if GridManager and GridManager.grid:
		_grid_size = GridManager.grid.grid_size
	else:
		_grid_size = Vector2i(20, 11)  # Fallback

	# Cache tile colors from tilemap (only once per overlay open)
	_cache_tile_colors()

	_is_active = true
	_pulse_time = 0.0
	visible = true
	set_process_input(true)
	set_process(true)

	AudioManager.play_sfx("menu_open", AudioManager.SFXCategory.UI)
	queue_redraw()


## Hide the map overlay
func hide_overlay() -> void:
	_is_active = false
	visible = false
	set_process_input(false)
	set_process(false)

	AudioManager.play_sfx("menu_cancel", AudioManager.SFXCategory.UI)
	overlay_closed.emit()


## Check if overlay is active
func is_overlay_active() -> bool:
	return _is_active


# =============================================================================
# DATA GATHERING
# =============================================================================

func _gather_unit_data() -> void:
	_player_positions.clear()
	_enemy_positions.clear()
	_neutral_positions.clear()
	_has_active_unit = false

	var active_unit: Unit = TurnManager.get_active_unit() if TurnManager else null

	# Gather from BattleManager
	if BattleManager:
		for unit: Unit in BattleManager.player_units:
			if unit and unit.is_alive():
				var pos: Vector2 = Vector2(unit.grid_position)
				if unit == active_unit:
					_active_position = pos
					_has_active_unit = true
				else:
					_player_positions.append(pos)

		for unit: Unit in BattleManager.enemy_units:
			if unit and unit.is_alive():
				var pos: Vector2 = Vector2(unit.grid_position)
				if unit == active_unit:
					_active_position = pos
					_has_active_unit = true
				else:
					_enemy_positions.append(pos)

		for unit: Unit in BattleManager.neutral_units:
			if unit and unit.is_alive():
				var pos: Vector2 = Vector2(unit.grid_position)
				if unit == active_unit:
					_active_position = pos
					_has_active_unit = true
				else:
					_neutral_positions.append(pos)


## Cache tile colors by sampling the tilemap texture
func _cache_tile_colors() -> void:
	_tile_colors.clear()
	_tile_colors_valid = false

	if not GridManager or not GridManager.tilemap:
		return

	var tilemap: TileMapLayer = GridManager.tilemap
	if not tilemap.tile_set:
		return

	# Pre-size the array
	var total_cells: int = _grid_size.x * _grid_size.y
	_tile_colors.resize(total_cells)

	# Get the atlas texture image for sampling
	var atlas_image: Image = null
	var tile_size: Vector2i = tilemap.tile_set.tile_size

	# Try to get the first atlas source's texture
	if tilemap.tile_set.get_source_count() > 0:
		var source_id: int = tilemap.tile_set.get_source_id(0)
		var source: TileSetSource = tilemap.tile_set.get_source(source_id)
		if source is TileSetAtlasSource:
			var atlas_source: TileSetAtlasSource = source as TileSetAtlasSource
			if atlas_source.texture:
				atlas_image = atlas_source.texture.get_image()

	# Sample each cell
	for y: int in range(_grid_size.y):
		for x: int in range(_grid_size.x):
			var cell: Vector2i = Vector2i(x, y)
			var idx: int = y * _grid_size.x + x
			var cell_color: Color = COLOR_TERRAIN_WALKABLE  # Default

			# Try to sample from tilemap
			var source_id: int = tilemap.get_cell_source_id(cell)
			if source_id >= 0 and atlas_image:
				var atlas_coords: Vector2i = tilemap.get_cell_atlas_coords(cell)
				# Sample center pixel of the tile
				var pixel_x: int = atlas_coords.x * tile_size.x + tile_size.x / 2
				var pixel_y: int = atlas_coords.y * tile_size.y + tile_size.y / 2
				if pixel_x < atlas_image.get_width() and pixel_y < atlas_image.get_height():
					cell_color = atlas_image.get_pixel(pixel_x, pixel_y)
					# Darken slightly for minimap aesthetic
					cell_color = cell_color.darkened(0.3)
			else:
				# No tile data - check if blocked
				var terrain: TerrainData = GridManager.get_terrain_at_cell(cell)
				if terrain and not terrain.is_passable(0):
					cell_color = COLOR_TERRAIN_BLOCKED

			_tile_colors[idx] = cell_color

	_tile_colors_valid = true


# =============================================================================
# DRAWING
# =============================================================================

func _calculate_map_rect(screen_rect: Rect2) -> Rect2:
	# Calculate map display area with padding
	var available_width: float = screen_rect.size.x - (MAP_PADDING * 2)
	var available_height: float = screen_rect.size.y - (MAP_PADDING * 2) - 60  # Extra space for legend/title

	# Maintain aspect ratio of grid
	var grid_aspect: float = float(_grid_size.x) / float(_grid_size.y) if _grid_size.y > 0 else 1.0
	var available_aspect: float = available_width / available_height if available_height > 0 else 1.0

	var map_width: float
	var map_height: float

	if grid_aspect > available_aspect:
		# Width constrained
		map_width = available_width
		map_height = map_width / grid_aspect
	else:
		# Height constrained
		map_height = available_height
		map_width = map_height * grid_aspect

	# Center the map
	var map_x: float = (screen_rect.size.x - map_width) / 2.0
	var map_y: float = MAP_PADDING + 30  # Below title

	return Rect2(map_x, map_y, map_width, map_height)


func _draw_map_background(map_rect: Rect2) -> void:
	# Draw grid background using cached tile colors
	var cell_width: float = map_rect.size.x / float(_grid_size.x) if _grid_size.x > 0 else 1.0
	var cell_height: float = map_rect.size.y / float(_grid_size.y) if _grid_size.y > 0 else 1.0

	# Draw cells using cached colors from tilemap
	for y: int in range(_grid_size.y):
		for x: int in range(_grid_size.x):
			var cell_rect: Rect2 = Rect2(
				map_rect.position.x + x * cell_width,
				map_rect.position.y + y * cell_height,
				cell_width,
				cell_height
			)

			# Get cached color or fall back to default
			var idx: int = y * _grid_size.x + x
			var cell_color: Color = COLOR_TERRAIN_WALKABLE

			if _tile_colors_valid and idx < _tile_colors.size():
				cell_color = _tile_colors[idx]
			else:
				# Fallback: check terrain passability
				var cell: Vector2i = Vector2i(x, y)
				if GridManager:
					var terrain: TerrainData = GridManager.get_terrain_at_cell(cell)
					if terrain and not terrain.is_passable(0):
						cell_color = COLOR_TERRAIN_BLOCKED

			# Slight checkerboard effect for visual interest
			if (x + y) % 2 == 0:
				cell_color = cell_color.lightened(0.05)

			draw_rect(cell_rect, cell_color)

	# Draw map border
	draw_rect(map_rect, BORDER_COLOR, false, 1)


func _draw_units(map_rect: Rect2) -> void:
	var cell_width: float = map_rect.size.x / float(_grid_size.x) if _grid_size.x > 0 else 1.0
	var cell_height: float = map_rect.size.y / float(_grid_size.y) if _grid_size.y > 0 else 1.0

	# Helper to convert grid pos to screen pos
	var grid_to_screen: Callable = func(grid_pos: Vector2) -> Vector2:
		return Vector2(
			map_rect.position.x + (grid_pos.x + 0.5) * cell_width,
			map_rect.position.y + (grid_pos.y + 0.5) * cell_height
		)

	# Draw player units
	for pos: Vector2 in _player_positions:
		var screen_pos: Vector2 = grid_to_screen.call(pos)
		draw_circle(screen_pos, DOT_RADIUS, COLOR_PLAYER)

	# Draw enemy units
	for pos: Vector2 in _enemy_positions:
		var screen_pos: Vector2 = grid_to_screen.call(pos)
		draw_circle(screen_pos, DOT_RADIUS, COLOR_ENEMY)

	# Draw neutral units
	for pos: Vector2 in _neutral_positions:
		var screen_pos: Vector2 = grid_to_screen.call(pos)
		draw_circle(screen_pos, DOT_RADIUS, COLOR_NEUTRAL)

	# Draw active unit (pulsing)
	if _has_active_unit:
		var screen_pos: Vector2 = grid_to_screen.call(_active_position)

		# Pulse effect
		var pulse: float = (sin(_pulse_time * TAU / PULSE_DURATION) + 1.0) / 2.0
		var radius: float = DOT_RADIUS + (ACTIVE_DOT_RADIUS - DOT_RADIUS) * pulse
		var color: Color = COLOR_ACTIVE.lightened(pulse * 0.3)

		draw_circle(screen_pos, radius, color)


func _draw_legend(screen_rect: Rect2) -> void:
	var legend_y: float = screen_rect.size.y - MAP_PADDING - 10
	var legend_x: float = MAP_PADDING

	var items: Array[Dictionary] = [
		{"color": COLOR_PLAYER, "label": "Ally"},
		{"color": COLOR_ENEMY, "label": "Enemy"},
		{"color": COLOR_NEUTRAL, "label": "Neutral"},
		{"color": COLOR_ACTIVE, "label": "Active"},
	]

	var spacing: float = 80.0

	for i: int in range(items.size()):
		var item: Dictionary = items[i]
		var x: float = legend_x + i * spacing
		var color: Color = item.get("color", Color.WHITE) as Color
		var label: String = DictUtils.get_string(item, "label", "")

		# Draw dot
		draw_circle(Vector2(x, legend_y), 5.0, color)

		# Draw label
		draw_string(
			MONOGRAM_FONT,
			Vector2(x + 10, legend_y + 4),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			FONT_SIZE,
			Color.WHITE
		)


func _draw_title(screen_rect: Rect2) -> void:
	var title: String = "TACTICAL MAP"
	var title_pos: Vector2 = Vector2(screen_rect.size.x / 2.0, MAP_PADDING)

	draw_string(
		MONOGRAM_FONT,
		title_pos,
		title,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		24,  # Monogram requires multiples of 8
		Color.WHITE
	)

	# Draw dismiss instruction
	var instruction: String = "Press B or click to close"
	var instruction_pos: Vector2 = Vector2(screen_rect.size.x / 2.0, screen_rect.size.y - 8)

	draw_string(
		MONOGRAM_FONT,
		instruction_pos,
		instruction,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		FONT_SIZE,  # Monogram requires multiples of 8 (16)
		Color(0.6, 0.6, 0.6, 1.0)
	)


# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if not _is_active:
		return

	# Any mouse click closes overlay
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed:
			hide_overlay()
			get_viewport().set_input_as_handled()
			return

	# Cancel/B button closes overlay
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("sf_cancel"):
		hide_overlay()
		get_viewport().set_input_as_handled()
		return

	# Accept also closes (just viewing)
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("sf_confirm"):
		hide_overlay()
		get_viewport().set_input_as_handled()
		return
