## GridManager - Central system for tactical grid movement and pathfinding
##
## Singleton autoload that manages the tactical grid, A* pathfinding,
## movement range calculations, unit positions, and cell highlighting.
## Integrates Grid resource with TileMapLayer for complete tactical movement.
extends Node

## Reference to the current battle's Grid resource
var grid: Grid = null

## Reference to the TileMapLayer for the current battle
var tilemap: TileMapLayer = null

## A* pathfinding grid
var _astar: AStarGrid2D = null

## Dictionary tracking which cells are occupied by units: {Vector2i: Unit}
var _occupied_cells: Dictionary = {}

## Highlight layer for showing movement ranges and targets
var _highlight_layer: TileMapLayer = null

## Terrain cost by tile type and movement type
## Format: {tile_id: {MovementType: cost}}
var _terrain_costs: Dictionary = {}

## Default terrain cost if not specified
const DEFAULT_TERRAIN_COST: int = 1

## Maximum terrain cost (effectively impassable)
const MAX_TERRAIN_COST: int = 99


## Initialize grid manager with a Grid resource and TileMapLayer
## Call this when starting a battle
func setup_grid(p_grid: Grid, p_tilemap: TileMapLayer) -> void:
	if p_grid == null:
		push_error("GridManager: Cannot setup with null Grid resource")
		return

	if p_tilemap == null:
		push_error("GridManager: Cannot setup with null TileMapLayer")
		return

	grid = p_grid
	tilemap = p_tilemap

	# Clear previous state
	_occupied_cells.clear()

	# Initialize A* grid
	_setup_astar()

	print("GridManager: Initialized with grid size %s, cell size %d" % [grid.grid_size, grid.cell_size])


## Set up the A* pathfinding grid
func _setup_astar() -> void:
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(Vector2i.ZERO, grid.grid_size)
	_astar.cell_size = Vector2(grid.cell_size, grid.cell_size)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER  # 4-directional movement only
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN

	# Update the A* grid (marks all cells as solid initially)
	_astar.update()

	# Mark all cells as walkable by default
	for x in range(grid.grid_size.x):
		for y in range(grid.grid_size.y):
			var cell: Vector2i = Vector2i(x, y)
			_astar.set_point_solid(cell, false)

	print("GridManager: A* grid initialized")


## Set terrain cost for a specific tile type and movement type
func set_terrain_cost(tile_id: int, movement_type: int, cost: int) -> void:
	if tile_id not in _terrain_costs:
		_terrain_costs[tile_id] = {}
	_terrain_costs[tile_id][movement_type] = cost


## Get terrain cost for a cell based on movement type
func get_terrain_cost(cell: Vector2i, movement_type: int) -> int:
	if not grid.is_within_bounds(cell):
		return MAX_TERRAIN_COST

	# Get tile data from tilemap
	var tile_data: TileData = tilemap.get_cell_tile_data(cell)
	if tile_data == null:
		return DEFAULT_TERRAIN_COST

	# Get tile ID from atlas coords
	var atlas_coords: Vector2i = tilemap.get_cell_atlas_coords(cell)
	var tile_id: int = atlas_coords.y * 1000 + atlas_coords.x  # Simple ID from coords

	# Look up terrain cost
	if tile_id in _terrain_costs and movement_type in _terrain_costs[tile_id]:
		return _terrain_costs[tile_id][movement_type]

	return DEFAULT_TERRAIN_COST


## Find path from one cell to another using A* pathfinding
## Returns Array[Vector2i] of cells in the path (including start and end)
## Returns empty array if no path exists
func find_path(from: Vector2i, to: Vector2i, movement_type: int = 0) -> Array[Vector2i]:
	if _astar == null:
		push_error("GridManager: A* not initialized. Call setup_grid() first.")
		return []

	if not grid.is_within_bounds(from):
		push_warning("GridManager: Start position %s out of bounds" % from)
		return []

	if not grid.is_within_bounds(to):
		push_warning("GridManager: End position %s out of bounds" % to)
		return []

	# Check if destination is walkable
	if is_cell_occupied(to):
		push_warning("GridManager: Destination %s is occupied" % to)
		return []

	# Temporarily update A* with terrain costs for this movement type
	_update_astar_weights(movement_type)

	# Find path using A*
	var path_packed: PackedVector2Array = _astar.get_point_path(from, to)

	# Convert to Array[Vector2i]
	var path: Array[Vector2i] = []
	for point in path_packed:
		path.append(Vector2i(point))

	return path


## Get all cells within movement range of a starting position
## Takes into account movement type and terrain costs
## Returns Array[Vector2i] of reachable cells
func get_walkable_cells(from: Vector2i, movement_range: int, movement_type: int = 0) -> Array[Vector2i]:
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

		for neighbor in neighbors:
			# Skip if occupied (unless it's the starting cell)
			if is_cell_occupied(neighbor) and neighbor != from:
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

			# Add to reachable cells (exclude starting position)
			if neighbor != from:
				reachable.append(neighbor)

	return reachable


## Update A* grid weights based on movement type
func _update_astar_weights(movement_type: int) -> void:
	for x in range(grid.grid_size.x):
		for y in range(grid.grid_size.y):
			var cell: Vector2i = Vector2i(x, y)
			var terrain_cost: int = get_terrain_cost(cell, movement_type)

			# Set as solid if impassable or occupied
			if terrain_cost >= MAX_TERRAIN_COST or is_cell_occupied(cell):
				_astar.set_point_solid(cell, true)
			else:
				_astar.set_point_solid(cell, false)
				_astar.set_point_weight_scale(cell, float(terrain_cost))


## Mark a cell as occupied by a unit
func set_cell_occupied(cell: Vector2i, unit: Node) -> void:
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
func get_unit_at_cell(cell: Vector2i) -> Node:
	if cell in _occupied_cells:
		return _occupied_cells[cell]
	return null


## Move a unit from one cell to another (updates occupation tracking)
func move_unit(unit: Node, from: Vector2i, to: Vector2i) -> void:
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
	print("GridManager: Highlight layer set")


## Highlight cells with a specific color (for movement range, attack range, etc.)
## Colors: 0 = movement (blue), 1 = attack (red), 2 = target (yellow)
func highlight_cells(cells: Array[Vector2i], color_type: int = 0) -> void:
	if _highlight_layer == null:
		push_warning("GridManager: No highlight layer set. Call set_highlight_layer() first.")
		return

	for cell in cells:
		if grid.is_within_bounds(cell):
			# Use atlas_coords to represent different colors
			# This assumes your tileset has highlight tiles at different positions
			var atlas_coords: Vector2i = Vector2i(color_type, 0)
			_highlight_layer.set_cell(cell, 0, atlas_coords)


## Clear all cell highlights
func clear_highlights() -> void:
	if _highlight_layer == null:
		return

	_highlight_layer.clear()


## Clear the entire grid state (call when exiting battle)
func clear_grid() -> void:
	grid = null
	tilemap = null
	_astar = null
	_occupied_cells.clear()
	_terrain_costs.clear()
	_highlight_layer = null

	print("GridManager: Grid cleared")


## Get distance between two cells (Manhattan distance)
func get_distance(from: Vector2i, to: Vector2i) -> int:
	return grid.get_manhattan_distance(from, to)


## Get all cells within a certain range (for AOE abilities)
func get_cells_in_range(center: Vector2i, range: int) -> Array[Vector2i]:
	return grid.get_cells_in_range(center, range)


## Check if cell is within grid bounds
func is_within_bounds(cell: Vector2i) -> bool:
	return grid.is_within_bounds(cell)


## Convert grid cell to world position
func cell_to_world(cell: Vector2i) -> Vector2:
	return grid.map_to_local(cell)


## Convert world position to grid cell
func world_to_cell(world_pos: Vector2) -> Vector2i:
	return grid.local_to_map(world_pos)
