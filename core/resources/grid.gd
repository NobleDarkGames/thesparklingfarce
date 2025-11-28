## Grid resource for tactical RPG battles
##
## Handles coordinate conversion between grid cells and world positions,
## grid boundary checking, and provides utility functions for tactical movement.
## This is designed as a shared resource rather than a singleton to allow
## different battle maps to have different grid configurations.
class_name Grid
extends Resource

## Size of the grid in cells (width x height)
@export var grid_size: Vector2i = Vector2i(20, 11)

## Size of each cell in pixels
@export var cell_size: int = 32

## Half cell size cached for performance (used for centering)
var _half_cell_size: int


func _init() -> void:
	_update_cache()


## Called when resource is loaded or properties change
func _validate_property(property: Dictionary) -> void:
	_update_cache()


## Update cached values
func _update_cache() -> void:
	_half_cell_size = cell_size / 2


## Convert grid coordinates to world position (centered in cell)
## Example: cell (0, 0) -> world position (16, 16) for 32px cells
func map_to_local(grid_position: Vector2i) -> Vector2:
	return Vector2(grid_position * cell_size) + Vector2.ONE * _half_cell_size


## Convert world position to grid coordinates
## Example: world position (20, 20) -> cell (0, 0) for 32px cells
func local_to_map(world_position: Vector2) -> Vector2i:
	return Vector2i(world_position / cell_size)


## Check if grid coordinates are within grid bounds
func is_within_bounds(grid_position: Vector2i) -> bool:
	return (grid_position.x >= 0 and grid_position.x < grid_size.x and
			grid_position.y >= 0 and grid_position.y < grid_size.y)


## Get grid bounds as Rect2i in grid coordinates
func get_grid_bounds() -> Rect2i:
	return Rect2i(Vector2i.ZERO, grid_size)


## Get world bounds as Rect2i in pixels
func get_world_bounds() -> Rect2i:
	return Rect2i(Vector2i.ZERO, grid_size * cell_size)


## Convert grid coordinates to 1D array index
## Useful for pathfinding algorithms like AStar
func grid_to_index(grid_position: Vector2i) -> int:
	return grid_position.y * grid_size.x + grid_position.x


## Convert 1D array index to grid coordinates
## Inverse of grid_to_index()
func index_to_grid(index: int) -> Vector2i:
	return Vector2i(index % grid_size.x, index / grid_size.x)


## Get Manhattan distance between two grid positions
## Used for movement range calculations
func get_manhattan_distance(from: Vector2i, to: Vector2i) -> int:
	return abs(to.x - from.x) + abs(to.y - from.y)


## Get all grid positions within range of a cell
## Returns array of Vector2i within manhattan_distance <= radius
func get_cells_in_range(center: Vector2i, radius: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []

	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var cell: Vector2i = center + Vector2i(x, y)
			if get_manhattan_distance(center, cell) <= radius and is_within_bounds(cell):
				cells.append(cell)

	return cells


## Get neighboring cells (4-directional: up, down, left, right)
func get_neighbors(grid_position: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var directions: Array[Vector2i] = [
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i.LEFT,
		Vector2i.RIGHT
	]

	for direction in directions:
		var neighbor: Vector2i = grid_position + direction
		if is_within_bounds(neighbor):
			neighbors.append(neighbor)

	return neighbors


## Get total number of cells in grid
func get_cell_count() -> int:
	return grid_size.x * grid_size.y


## Clamp grid position to grid bounds
func clamp_to_bounds(grid_position: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(grid_position.x, 0, grid_size.x - 1),
		clampi(grid_position.y, 0, grid_size.y - 1)
	)
