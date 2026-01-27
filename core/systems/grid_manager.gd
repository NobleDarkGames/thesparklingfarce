## GridManager - Central system for tactical grid movement and pathfinding
##
## Singleton autoload that manages the tactical grid, A* pathfinding,
## movement range calculations, unit positions, and cell highlighting.
## Integrates Grid resource with TileMapLayer for complete tactical movement.
extends Node

## Reference to the current battle's Grid resource
var grid: Grid = null

## Reference to the TileMapLayer for the current battle (alias to first terrain layer for backwards compat)
var tilemap: TileMapLayer = null

## Terrain layers sorted by priority (highest z_index first)
## The first layer with a valid terrain at a cell determines that cell's terrain
var _terrain_layers: Array[TileMapLayer] = []

## A* pathfinding grid
var _astar: AStarGrid2D = null

## Dictionary tracking which cells are occupied by units: {Vector2i: Unit}
var _occupied_cells: Dictionary = {}

## Highlight layer for showing movement ranges and targets
var _highlight_layer: TileMapLayer = null

## Highlight pulse animation tween
var _highlight_tween: Tween = null

## AoE border highlight container (for SF2-style white borders)
var _aoe_border_container: Node2D = null

## AoE border visual settings
const AOE_BORDER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)  # White, slightly transparent
const AOE_BORDER_WIDTH: float = 2.0

## Pulse animation settings
const HIGHLIGHT_PULSE_MIN_ALPHA: float = 0.5
const HIGHLIGHT_PULSE_MAX_ALPHA: float = 1.0
const HIGHLIGHT_PULSE_DURATION: float = 0.6

## Terrain cost by tile type and movement type (LEGACY - kept for compatibility)
## Format: {tile_id: {MovementType: cost}}
var _terrain_costs: Dictionary = {}

## Cached terrain data for current map: {Vector2i: TerrainData}
## Populated by load_terrain_data() after map is loaded
var _cell_terrain_cache: Dictionary = {}

## Default terrain cost if not specified
const DEFAULT_TERRAIN_COST: int = 1

## Maximum terrain cost (effectively impassable)
const MAX_TERRAIN_COST: int = 99

## Default tile size (32x32 pixels) - used when no grid is set
const DEFAULT_TILE_SIZE: int = 32

## Name of the custom data layer in TileSets that stores terrain type
const TERRAIN_TYPE_LAYER_NAME: String = "terrain_type"


## Get the current tile size (from grid if available, otherwise default)
func get_tile_size() -> int:
	if grid:
		return grid.cell_size
	return DEFAULT_TILE_SIZE


## Initialize grid manager with a Grid resource and terrain layers
## Call this when starting a battle
## p_terrain_layers: Array of TileMapLayers sorted by priority (highest z_index first)
func setup_grid(p_grid: Grid, p_terrain_layers: Array[TileMapLayer]) -> void:
	if p_grid == null:
		push_error("GridManager: Cannot setup with null Grid resource")
		return

	if p_terrain_layers.is_empty():
		push_error("GridManager: Cannot setup with empty terrain layers array")
		return

	grid = p_grid
	_terrain_layers = p_terrain_layers
	tilemap = _terrain_layers[0] if _terrain_layers.size() > 0 else null  # Backwards compat alias

	# Clear previous state
	_occupied_cells.clear()
	_cell_terrain_cache.clear()

	# Initialize A* grid
	_setup_astar()

	# Load terrain data from tilemap custom data (if available)
	load_terrain_data()


## Set up the A* pathfinding grid
func _setup_astar() -> void:
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(Vector2i.ZERO, grid.grid_size)
	_astar.cell_size = Vector2(1, 1)  # Keep AStar in grid coordinates, not world coordinates
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER  # 4-directional movement only
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN

	# Update the A* grid (marks all cells as solid initially)
	_astar.update()

	# Mark all cells as walkable by default
	for x: int in range(grid.grid_size.x):
		for y: int in range(grid.grid_size.y):
			var cell: Vector2i = Vector2i(x, y)
			_astar.set_point_solid(cell, false)


## Set terrain cost for a specific tile type and movement type (LEGACY)
func set_terrain_cost(tile_id: int, movement_type: int, cost: int) -> void:
	if tile_id not in _terrain_costs:
		_terrain_costs[tile_id] = {}
	_terrain_costs[tile_id][movement_type] = cost


## Load terrain data from the current tilemap's custom data layer
## Call this after setup_grid() to populate the terrain cache
## This reads the "terrain_type" custom data from each tile and maps it to TerrainData
func load_terrain_data() -> void:
	_cell_terrain_cache.clear()

	if not tilemap or not tilemap.tile_set:
		return

	# Cache terrain data for each cell in the grid
	# Terrain is derived from atlas source filename (e.g., grass.png -> "grass")
	# with optional per-tile override via terrain_type custom data
	for x: int in range(grid.grid_size.x):
		for y: int in range(grid.grid_size.y):
			var cell: Vector2i = Vector2i(x, y)
			var terrain_id: String = _get_terrain_id_at_cell(cell)
			if not terrain_id.is_empty():
				var terrain: TerrainData = ModLoader.terrain_registry.get_terrain(terrain_id)
				_cell_terrain_cache[cell] = terrain


## Check if a specific layer's tileset has terrain_type custom data layer (for per-tile overrides)
func _layer_has_terrain_type(layer: TileMapLayer) -> bool:
	if not layer or not layer.tile_set:
		return false

	var custom_data_count: int = layer.tile_set.get_custom_data_layers_count()
	for i: int in range(custom_data_count):
		if layer.tile_set.get_custom_data_layer_name(i) == TERRAIN_TYPE_LAYER_NAME:
			return true
	return false


## Get terrain ID for a cell by checking all terrain layers (top to bottom)
## Returns the first valid terrain found, or empty string if none.
## Tiles NOT registered in TerrainRegistry are treated as decorations and pass through.
func _get_terrain_id_at_cell(cell: Vector2i) -> String:
	for layer: TileMapLayer in _terrain_layers:
		if not layer or not layer.tile_set:
			continue

		# Check if cell has a tile in this layer
		var source_id: int = layer.get_cell_source_id(cell)
		if source_id == -1:
			continue  # No tile in this layer, check next

		# Get terrain ID from this layer's tile
		var terrain_id: String = _get_terrain_id_from_layer(layer, cell, source_id)
		if terrain_id.is_empty():
			continue

		# Check if this terrain is registered (decorations are not)
		if ModLoader.terrain_registry.has_terrain(terrain_id):
			return terrain_id
		# Else: decoration tile (not in registry), pass through to next layer

	return ""  # No terrain found in any layer


## Get terrain ID from a specific layer at a cell
## Priority: 1) Per-tile custom data override, 2) Atlas source filename
func _get_terrain_id_from_layer(layer: TileMapLayer, cell: Vector2i, source_id: int) -> String:
	# Priority 1: Check for per-tile custom data override
	var tile_data: TileData = layer.get_cell_tile_data(cell)
	if tile_data and _layer_has_terrain_type(layer):
		var terrain_type: Variant = tile_data.get_custom_data(TERRAIN_TYPE_LAYER_NAME)
		if terrain_type is String and not terrain_type.is_empty():
			return terrain_type

	# Priority 2: Derive from atlas source filename
	var source: TileSetSource = layer.tile_set.get_source(source_id)
	if source is TileSetAtlasSource:
		var atlas_source: TileSetAtlasSource = source as TileSetAtlasSource
		if atlas_source.texture:
			# "res://path/to/grass.png" -> "grass"
			var filename: String = atlas_source.texture.resource_path.get_file().get_basename()
			return filename

	return ""


## Get TerrainData at a cell (from cache, or fallback to plains)
func get_terrain_at_cell(cell: Vector2i) -> TerrainData:
	if cell in _cell_terrain_cache:
		return _cell_terrain_cache[cell]
	# Return fallback terrain (plains) for cells without terrain data
	return ModLoader.terrain_registry.get_terrain("plains")


## Get terrain cost for a cell based on movement type
## Now uses TerrainData system with proper movement type handling
func get_terrain_cost(cell: Vector2i, movement_type: int) -> int:
	if grid == null:
		push_error("GridManager: Grid not initialized. Call setup_grid() first.")
		return MAX_TERRAIN_COST

	if not grid.is_within_bounds(cell):
		return MAX_TERRAIN_COST

	# If no tilemap or tileset, return default cost (for test scenes with visual grid)
	if not tilemap or not tilemap.tile_set:
		return DEFAULT_TERRAIN_COST

	# If tileset has no sources, return default cost (empty tileset in test scenes)
	if tilemap.tile_set.get_source_count() == 0:
		return DEFAULT_TERRAIN_COST

	# Use new TerrainData system if terrain cache is populated
	if not _cell_terrain_cache.is_empty():
		var terrain: TerrainData = get_terrain_at_cell(cell)
		return terrain.get_movement_cost(movement_type)

	# LEGACY FALLBACK: Old tile ID-based system (for backwards compatibility)
	var tile_data: TileData = tilemap.get_cell_tile_data(cell)
	if tile_data == null:
		return DEFAULT_TERRAIN_COST

	# Get tile ID from atlas coords
	var atlas_coords: Vector2i = tilemap.get_cell_atlas_coords(cell)
	var tile_id: int = atlas_coords.y * 1000 + atlas_coords.x  # Simple ID from coords

	# Look up terrain cost from legacy system
	if tile_id in _terrain_costs:
		var costs_val: Variant = _terrain_costs.get(tile_id)
		if not costs_val is Dictionary:
			return DEFAULT_TERRAIN_COST
		var tile_costs: Dictionary = costs_val
		if movement_type in tile_costs:
			var cost: int = int(tile_costs[movement_type])
			return cost

	return DEFAULT_TERRAIN_COST


## Find path from one cell to another using A* pathfinding
## Returns Array[Vector2i] of cells in the path (including start and end)
## Returns empty array if no path exists
## mover_faction: Faction of the moving unit - allows passing through allies
func find_path(from: Vector2i, to: Vector2i, movement_type: int = 0, mover_faction: String = "") -> Array[Vector2i]:
	if _astar == null:
		push_error("GridManager: A* not initialized. Call setup_grid() first.")
		return []

	if not grid.is_within_bounds(from):
		push_warning("GridManager: Start position %s out of bounds" % from)
		return []

	if not grid.is_within_bounds(to):
		push_warning("GridManager: End position %s out of bounds" % to)
		return []

	# Check if destination is walkable (cannot end on ANY occupied cell, even allies)
	if is_cell_occupied(to):
		push_warning("GridManager: Destination %s is occupied" % to)
		return []

	# Temporarily update A* with terrain costs for this movement type
	# Pass faction to allow passing through allies
	_update_astar_weights(movement_type, mover_faction)

	# Find path using A*
	var path_packed: PackedVector2Array = _astar.get_point_path(from, to)

	# Convert to Array[Vector2i]
	var path: Array[Vector2i] = []
	for point: Vector2 in path_packed:
		path.append(Vector2i(point))

	return path


## Expand waypoints into a complete path (Phase 3: cinematics refactor)
## Converts sparse waypoints [A, C, F] into complete path [A, B, C, D, E, F]
## using pathfinding between each waypoint pair.
##
## waypoints: Array of Vector2i grid positions to visit in order
## movement_type: Movement type for terrain costs (default 0)
## start_pos: Starting position (if Vector2i(-1, -1), uses first waypoint as start)
##
## Returns: Array[Vector2i] complete path, or empty array if any segment fails
func expand_waypoint_path(waypoints: Array[Vector2i], movement_type: int = 0, start_pos: Vector2i = Vector2i(-1, -1)) -> Array[Vector2i]:
	if _astar == null:
		push_error("GridManager: A* not initialized. Call setup_grid() first.")
		return []

	if waypoints.is_empty():
		push_warning("GridManager: Cannot expand empty waypoints array")
		return []

	var complete_path: Array[Vector2i] = []
	var current_pos: Vector2i = start_pos if start_pos != Vector2i(-1, -1) else waypoints[0]
	complete_path.append(current_pos)

	for waypoint: Vector2i in waypoints:
		if waypoint == current_pos:
			continue

		var segment_path: Array[Vector2i] = find_path(current_pos, waypoint, movement_type)
		if segment_path.is_empty():
			push_error("GridManager: No path found from %s to %s during waypoint expansion" % [current_pos, waypoint])
			return []

		# Append segment excluding first point (already in path)
		complete_path.append_array(segment_path.slice(1))
		current_pos = waypoint

	return complete_path


## Get all cells within movement range of a starting position
## Takes into account movement type and terrain costs
## mover_faction: Faction of the moving unit ("player", "enemy", "neutral")
##                Units can pass through allies but not enemies
## Returns Array[Vector2i] of reachable cells (excludes occupied cells - can't end on allies)
func get_walkable_cells(from: Vector2i, movement_range: int, movement_type: int = 0, mover_faction: String = "") -> Array[Vector2i]:
	if _astar == null:
		push_error("GridManager: A* not initialized. Call setup_grid() first.")
		return []

	if not grid.is_within_bounds(from):
		push_warning("GridManager: Start position %s out of bounds" % from)
		return []

	var reachable: Array[Vector2i] = []
	var visited: Dictionary = {}  # {Vector2i: movement_cost}
	var queue: Array = []  # Array of {cell: Vector2i, cost: int}

	# Start with origin
	queue.append({"cell": from, "cost": 0})
	visited[from] = 0

	# Flood fill with movement cost
	while queue.size() > 0:
		var current: Dictionary = queue.pop_front()
		var current_cell: Vector2i = current.cell
		var current_cost: int = current.cost

		# Get neighbors
		var neighbors: Array[Vector2i] = grid.get_neighbors(current_cell)

		for neighbor: Vector2i in neighbors:
			# Check occupancy - can pass through allies, blocked by enemies
			if is_cell_occupied(neighbor) and neighbor != from:
				var occupant: Unit = get_unit_at_cell(neighbor)
				# Block if occupant is an enemy (different faction)
				# Allow pass-through if same faction (ally)
				if occupant and mover_faction != "" and occupant.faction != mover_faction:
					continue

			# Get terrain cost for this cell
			var terrain_cost: int = get_terrain_cost(neighbor, movement_type)

			# Skip if impassable
			if terrain_cost >= MAX_TERRAIN_COST:
				continue

			# Calculate total cost to reach this neighbor
			var new_cost: int = current_cost + terrain_cost

			# Skip if too far
			if new_cost > movement_range:
				continue

			# Skip if already visited with lower cost
			if neighbor in visited and visited[neighbor] <= new_cost:
				continue

			# Mark as visited and add to queue
			visited[neighbor] = new_cost
			queue.append({"cell": neighbor, "cost": new_cost})

			# Add to reachable cells (exclude starting position AND occupied cells)
			# Even allies - you can pass through them but not stop on them
			if neighbor != from and not is_cell_occupied(neighbor):
				reachable.append(neighbor)

	return reachable


## Update A* grid weights based on movement type
## NOTE: This iterates the entire grid (O(width * height)) on each pathfinding call.
## For current grid sizes (10x10 to 20x11), this is acceptable performance.
## Future optimization: Cache A* weights per movement type, invalidate only on occupation changes.
## mover_faction: Faction of the moving unit - allows passing through allies
func _update_astar_weights(movement_type: int, mover_faction: String = "") -> void:
	for x: int in range(grid.grid_size.x):
		for y: int in range(grid.grid_size.y):
			var cell: Vector2i = Vector2i(x, y)
			var terrain_cost: int = get_terrain_cost(cell, movement_type)

			# Set as solid if impassable
			if terrain_cost >= MAX_TERRAIN_COST:
				_astar.set_point_solid(cell, true)
			# Check occupation - allies are passable, enemies are solid
			elif is_cell_occupied(cell):
				var occupant: Unit = get_unit_at_cell(cell)
				# If we have faction info, allow passing through allies
				if occupant and mover_faction != "" and occupant.faction == mover_faction:
					# Ally - can pass through
					_astar.set_point_solid(cell, false)
					_astar.set_point_weight_scale(cell, float(terrain_cost))
				else:
					# Enemy or unknown - blocked
					_astar.set_point_solid(cell, true)
			else:
				_astar.set_point_solid(cell, false)
				_astar.set_point_weight_scale(cell, float(terrain_cost))


## Mark a cell as occupied by a unit
func set_cell_occupied(cell: Vector2i, unit: Unit) -> void:
	if not grid.is_within_bounds(cell):
		push_warning("GridManager: Cannot occupy cell %s (out of bounds)" % cell)
		return

	_occupied_cells[cell] = unit


## Mark a cell as unoccupied
func clear_cell_occupied(cell: Vector2i) -> void:
	_occupied_cells.erase(cell)


## Check if a cell is occupied by a unit
func is_cell_occupied(cell: Vector2i) -> bool:
	return cell in _occupied_cells


## Get the unit occupying a cell (or null if empty)
func get_unit_at_cell(cell: Vector2i) -> Unit:
	if cell in _occupied_cells:
		return _occupied_cells[cell]
	return null


## Move a unit from one cell to another (updates occupation tracking)
func move_unit(unit: Unit, from: Vector2i, to: Vector2i) -> void:
	if not grid.is_within_bounds(to):
		push_error("GridManager: Cannot move unit to %s (out of bounds)" % to)
		return

	if is_cell_occupied(to):
		push_error("GridManager: Cannot move unit to %s (occupied)" % to)
		return

	# Clear old position
	clear_cell_occupied(from)

	# Set new position
	set_cell_occupied(to, unit)


## Set the highlight layer for visual feedback
func set_highlight_layer(layer: TileMapLayer) -> void:
	_highlight_layer = layer


## Highlight constants for tile source IDs
const HIGHLIGHT_BLUE: int = 0    # Movement range
const HIGHLIGHT_RED: int = 1     # Attack range
const HIGHLIGHT_YELLOW: int = 2  # Target selection
const HIGHLIGHT_GREEN: int = 3   # Current position (SF2-style direct movement)

## Highlight cells with a specific color (for movement range, attack range, etc.)
## Colors: 0 = movement (blue), 1 = attack (red), 2 = target (yellow)
## pulse: Whether to animate the highlights with a gentle pulse effect
func highlight_cells(cells: Array[Vector2i], color_type: int = 0, pulse: bool = true) -> void:
	if _highlight_layer == null:
		push_warning("GridManager: No highlight layer set. Call set_highlight_layer() first.")
		return

	for cell: Vector2i in cells:
		if grid.is_within_bounds(cell):
			# Use source_id to select the correct colored tile
			# source_id corresponds to: 0=blue, 1=red, 2=yellow
			_highlight_layer.set_cell(cell, color_type, Vector2i(0, 0))

	# Start pulse animation if requested
	if pulse and cells.size() > 0:
		_start_highlight_pulse()


## Show movement range (blue tiles)
## Highlights all walkable cells from a position in blue.
## mover_faction: Faction of the moving unit - allows passing through allies
func show_movement_range(from: Vector2i, movement_range: int, movement_type: int, mover_faction: String = "") -> void:
	clear_highlights()
	var walkable_cells: Array[Vector2i] = get_walkable_cells(from, movement_range, movement_type, mover_faction)
	highlight_cells(walkable_cells, HIGHLIGHT_BLUE)


## Show attack range (red tiles)
## Highlights all cells within attack range in red.
## DEPRECATED: Use show_attack_range_band() for new code that supports min/max range
func show_attack_range(from: Vector2i, weapon_range: int) -> void:
	# Delegate to range band method with min_range=1 for backwards compatibility
	show_attack_range_band(from, 1, weapon_range)


## Show attack range band (red tiles) with min/max range support
## Highlights cells within the range band, excluding dead zone (distance < min_range)
## Example: min_range=2, max_range=3 shows cells at distance 2 and 3, not distance 1
func show_attack_range_band(from: Vector2i, min_range: int, max_range: int) -> void:
	if _highlight_layer == null:
		push_warning("GridManager: Cannot show attack range - no highlight layer set")
		return

	var attack_cells: Array[Vector2i] = grid.get_cells_in_range_band(from, min_range, max_range)
	attack_cells = attack_cells.filter(func(cell: Vector2i) -> bool: return cell != from)
	highlight_cells(attack_cells, HIGHLIGHT_RED)


## Highlight specific target cells (yellow tiles)
## Highlights specific cells as valid targets in yellow.
func highlight_targets(target_cells: Array[Vector2i]) -> void:
	highlight_cells(target_cells, HIGHLIGHT_YELLOW)


## Show AoE borders around cells (SF2-style white outlines)
## Uses white rectangular borders instead of filled tiles for better visibility
func show_aoe_borders(cells: Array[Vector2i]) -> void:
	# Clear existing borders first
	clear_aoe_borders()

	if cells.is_empty():
		return

	# Create container if needed
	if _aoe_border_container == null:
		_aoe_border_container = Node2D.new()
		_aoe_border_container.name = "AoEBorderContainer"
		_aoe_border_container.z_index = 10  # Above tiles, below units

	# Add to scene if not already - use highlight layer's parent as the container
	if not _aoe_border_container.get_parent() and _highlight_layer:
		var parent: Node = _highlight_layer.get_parent()
		if parent:
			parent.add_child(_aoe_border_container)

	# Get tile size
	var tile_size: int = grid.cell_size if grid else DEFAULT_TILE_SIZE

	# Create border rectangles for each cell
	for cell: Vector2i in cells:
		if not grid or grid.is_within_bounds(cell):
			var border: ReferenceRect = ReferenceRect.new()
			border.position = Vector2(cell.x * tile_size, cell.y * tile_size)
			border.size = Vector2(tile_size, tile_size)
			border.border_color = AOE_BORDER_COLOR
			border.border_width = AOE_BORDER_WIDTH
			border.editor_only = false
			_aoe_border_container.add_child(border)


## Clear AoE border highlights
func clear_aoe_borders() -> void:
	if _aoe_border_container:
		for child: Node in _aoe_border_container.get_children():
			child.queue_free()


## Clear all cell highlights
func clear_highlights() -> void:
	# Stop pulse animation
	_stop_highlight_pulse()

	# Clear AoE borders
	clear_aoe_borders()

	if _highlight_layer == null:
		return

	_highlight_layer.clear()
	_highlight_layer.modulate.a = 1.0  # Reset alpha


## Start pulsing the highlight layer (gentle alpha oscillation)
func _start_highlight_pulse() -> void:
	if _highlight_layer == null:
		return

	# Kill existing tween
	if _highlight_tween and _highlight_tween.is_valid():
		_highlight_tween.kill()

	# Create looping pulse animation
	_highlight_tween = create_tween()
	_highlight_tween.set_loops()

	_highlight_tween.tween_property(
		_highlight_layer,
		"modulate:a",
		HIGHLIGHT_PULSE_MIN_ALPHA,
		HIGHLIGHT_PULSE_DURATION / 2.0
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	_highlight_tween.tween_property(
		_highlight_layer,
		"modulate:a",
		HIGHLIGHT_PULSE_MAX_ALPHA,
		HIGHLIGHT_PULSE_DURATION / 2.0
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


## Stop pulsing the highlight layer
func _stop_highlight_pulse() -> void:
	if _highlight_tween and _highlight_tween.is_valid():
		_highlight_tween.kill()
		_highlight_tween = null

	if _highlight_layer:
		_highlight_layer.modulate.a = 1.0


## Clear the entire grid state (call when exiting battle)
func clear_grid() -> void:
	# Stop highlight pulse animation
	_stop_highlight_pulse()

	# Clean up AoE border container (free the Node2D and all its children)
	if _aoe_border_container:
		_aoe_border_container.queue_free()
		_aoe_border_container = null

	grid = null
	tilemap = null
	_terrain_layers.clear()
	_astar = null
	_occupied_cells.clear()
	_terrain_costs.clear()
	_cell_terrain_cache.clear()
	_highlight_layer = null


## Get distance between two cells (Manhattan distance)
func get_distance(from: Vector2i, to: Vector2i) -> int:
	if grid == null:
		push_error("GridManager: Grid not initialized. Call setup_grid() first.")
		return 9999
	return grid.get_manhattan_distance(from, to)


## Get all cells within a certain range (for AOE abilities)
func get_cells_in_range(center: Vector2i, p_range: int) -> Array[Vector2i]:
	if grid == null:
		push_error("GridManager: Grid not initialized. Call setup_grid() first.")
		return []
	return grid.get_cells_in_range(center, p_range)


## Get all cells within a range band (min to max distance)
## Used for weapons with dead zones (e.g., bows that cannot hit adjacent enemies)
func get_cells_in_range_band(center: Vector2i, min_range: int, max_range: int) -> Array[Vector2i]:
	if grid == null:
		push_error("GridManager: Grid not initialized. Call setup_grid() first.")
		return []
	return grid.get_cells_in_range_band(center, min_range, max_range)


## Check if cell is within grid bounds
func is_within_bounds(cell: Vector2i) -> bool:
	if grid:
		return grid.is_within_bounds(cell)
	else:
		# Fallback: allow any cell (no bounds checking without a grid)
		return true


## Convert grid cell to world position
func cell_to_world(cell: Vector2i) -> Vector2:
	if grid:
		return grid.map_to_local(cell)
	else:
		# Fallback: use default tile size for simple conversion
		@warning_ignore("integer_division")
		return Vector2(cell * DEFAULT_TILE_SIZE) + Vector2.ONE * (DEFAULT_TILE_SIZE / 2)


## Convert world position to grid cell
func world_to_cell(world_pos: Vector2) -> Vector2i:
	if grid:
		return grid.local_to_map(world_pos)
	else:
		# Fallback: use default tile size for simple conversion
		# Use floori to correctly handle negative coordinates
		return Vector2i(floori(world_pos.x / DEFAULT_TILE_SIZE), floori(world_pos.y / DEFAULT_TILE_SIZE))
