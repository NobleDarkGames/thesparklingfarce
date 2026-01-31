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

# Unit dot colors - use centralized UIColors class (unique active color stays local)
const COLOR_ACTIVE: Color = Color(0.3, 1.0, 0.4, 1.0)  # Green (active unit) - unique

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

	if not BattleManager:
		return

	var active_unit: Unit = TurnManager.get_active_unit() if TurnManager else null

	_gather_unit_positions(BattleManager.player_units, _player_positions, active_unit)
	_gather_unit_positions(BattleManager.enemy_units, _enemy_positions, active_unit)
	_gather_unit_positions(BattleManager.neutral_units, _neutral_positions, active_unit)


## Gather positions from a unit array into a target positions array
func _gather_unit_positions(units: Array, target: Array[Vector2], active_unit: Unit) -> void:
	for unit: Unit in units:
		if not unit or not unit.is_alive():
			continue

		var pos: Vector2 = Vector2(unit.grid_position)
		if unit == active_unit:
			_active_position = pos
			_has_active_unit = true
		else:
			target.append(pos)


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
	var cell_size: Vector2 = _get_cell_size(map_rect)

	# Draw unit groups
	_draw_unit_dots(_player_positions, UIColors.FACTION_ALLY, map_rect, cell_size)
	_draw_unit_dots(_enemy_positions, UIColors.FACTION_ENEMY, map_rect, cell_size)
	_draw_unit_dots(_neutral_positions, UIColors.FACTION_NEUTRAL, map_rect, cell_size)

	# Draw active unit with pulse effect
	if _has_active_unit:
		var screen_pos: Vector2 = _grid_to_screen(_active_position, map_rect, cell_size)
		var pulse: float = (sin(_pulse_time * TAU / PULSE_DURATION) + 1.0) / 2.0
		var radius: float = DOT_RADIUS + (ACTIVE_DOT_RADIUS - DOT_RADIUS) * pulse
		draw_circle(screen_pos, radius, COLOR_ACTIVE.lightened(pulse * 0.3))


## Get cell size for the map rect
func _get_cell_size(map_rect: Rect2) -> Vector2:
	return Vector2(
		map_rect.size.x / float(_grid_size.x) if _grid_size.x > 0 else 1.0,
		map_rect.size.y / float(_grid_size.y) if _grid_size.y > 0 else 1.0
	)


## Convert grid position to screen position
func _grid_to_screen(grid_pos: Vector2, map_rect: Rect2, cell_size: Vector2) -> Vector2:
	return Vector2(
		map_rect.position.x + (grid_pos.x + 0.5) * cell_size.x,
		map_rect.position.y + (grid_pos.y + 0.5) * cell_size.y
	)


## Draw dots for a group of unit positions
func _draw_unit_dots(positions: Array[Vector2], color: Color, map_rect: Rect2, cell_size: Vector2) -> void:
	for pos: Vector2 in positions:
		draw_circle(_grid_to_screen(pos, map_rect, cell_size), DOT_RADIUS, color)


## Legend items: [color, label]
const LEGEND_ITEMS: Array = [
	[UIColors.FACTION_ALLY, "Ally"],
	[UIColors.FACTION_ENEMY, "Enemy"],
	[UIColors.FACTION_NEUTRAL, "Neutral"],
	[COLOR_ACTIVE, "Active"],
]
const LEGEND_SPACING: float = 80.0


func _draw_legend(screen_rect: Rect2) -> void:
	var legend_y: float = screen_rect.size.y - MAP_PADDING - 10

	for i: int in range(LEGEND_ITEMS.size()):
		var x: float = MAP_PADDING + i * LEGEND_SPACING
		var color: Color = LEGEND_ITEMS[i][0]
		var label: String = LEGEND_ITEMS[i][1]

		draw_circle(Vector2(x, legend_y), 5.0, color)
		draw_string(MONOGRAM_FONT, Vector2(x + 10, legend_y + 4), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)


const TITLE_FONT_SIZE: int = 24
const INSTRUCTION_COLOR: Color = Color(0.6, 0.6, 0.6, 1.0)


func _draw_title(screen_rect: Rect2) -> void:
	var center_x: float = screen_rect.size.x / 2.0

	draw_string(MONOGRAM_FONT, Vector2(center_x, MAP_PADDING), "TACTICAL MAP",
		HORIZONTAL_ALIGNMENT_CENTER, -1, TITLE_FONT_SIZE, Color.WHITE)

	draw_string(MONOGRAM_FONT, Vector2(center_x, screen_rect.size.y - 8),
		"Press B or click to close", HORIZONTAL_ALIGNMENT_CENTER, -1, FONT_SIZE, INSTRUCTION_COLOR)


# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if not _is_active:
		return

	# Any interaction closes the overlay
	var should_close: bool = false

	if event is InputEventMouseButton and event.pressed:
		should_close = true
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("sf_cancel"):
		should_close = true
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("sf_confirm"):
		should_close = true

	if should_close:
		hide_overlay()
		get_viewport().set_input_as_handled()
